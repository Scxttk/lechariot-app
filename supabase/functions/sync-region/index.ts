// Smart Shop – Edge Function sync-region
// POST {"zip": "04626"} → synct die Angebote der Region via Marktguru,
// wenn der Cache (regions.last_synced) älter als 24h oder leer ist.
// {"force": true} erzwingt den Sync (für den täglichen Cron).

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { MarktguruClient, type Offer } from "./marktguru.ts";

const CACHE_TTL_MS = 24 * 60 * 60 * 1000;
const BATCH_SIZE = 100;

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST erwartet" }, 405);

  let zip = "", force = false;
  try {
    const body = await req.json();
    zip = String(body.zip ?? "").trim();
    force = body.force === true;
  } catch {
    return json({ error: "Ungültiger JSON-Body" }, 400);
  }
  if (!/^\d{5}$/.test(zip)) return json({ error: "zip muss eine 5-stellige PLZ sein" }, 400);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Cache-Check + Claim gegen parallele Syncs: last_synced sofort setzen,
  // aber nur wenn älter als TTL (bzw. force). Verliert dieser Request das
  // Rennen, meldet er cached zurück.
  const cutoff = new Date(Date.now() - CACHE_TTL_MS).toISOString();
  const now = new Date().toISOString();

  const { data: existing, error: selErr } = await supabase
    .from("regions").select("plz, last_synced").eq("plz", zip).maybeSingle();
  if (selErr) return json({ error: `regions-Abfrage: ${selErr.message}` }, 500);

  const offerCount = async () => {
    const { count } = await supabase
      .from("offers").select("id", { count: "exact", head: true }).eq("region", zip);
    return count ?? 0;
  };

  if (!existing) {
    const { error } = await supabase.from("regions").insert({ plz: zip, last_synced: now });
    // Unique-Verletzung → parallel angelegt, dessen Sync läuft bereits
    if (error) return json({ cached: true, zip, count: await offerCount() });
  } else if (!force && existing.last_synced && existing.last_synced > cutoff) {
    return json({ cached: true, zip, count: await offerCount() });
  } else {
    let claim = supabase.from("regions").update({ last_synced: now }).eq("plz", zip);
    if (!force) claim = claim.or(`last_synced.is.null,last_synced.lt.${cutoff}`);
    const { data: claimed, error } = await claim.select();
    if (error) return json({ error: `regions-Claim: ${error.message}` }, 500);
    if (!claimed?.length) return json({ cached: true, zip, count: await offerCount() });
  }

  // Marktguru-Sync
  const client = new MarktguruClient(zip);
  const failed: string[] = [];
  let total = 0;
  let markets = 0;

  try {
    await client.loadKeys();
    const retailers = await client.resolveRetailers();
    markets = Object.keys(retailers).length;

    for (const [name, retailerId] of Object.entries(retailers)) {
      try {
        const offers = await client.fetchOffers(name, retailerId);
        if (!offers.length) {
          failed.push(`${name} (0 Angebote)`);
          continue;
        }
        total += await upload(supabase, offers, name, zip);
        // `markets` (Filialen für den Wunschmarkt-Picker) befüllt die
        // Filial-Pipeline im smartshop-Repo – hier nicht anfassen
      } catch (e) {
        failed.push(`${name} (${(e as Error).message})`);
      }
    }
  } catch (e) {
    // Kompletter Fehlschlag: Claim zurücknehmen, damit der nächste Aufruf erneut synct
    await supabase.from("regions").update({ last_synced: existing?.last_synced ?? null }).eq("plz", zip);
    return json({ error: `Marktguru-Sync fehlgeschlagen: ${(e as Error).message}` }, 502);
  }

  return json({ cached: false, zip, markets, count: total, failed });
});

// Upload wie scraper/supabase_uploader.py: alte Einträge des Markts (ältere
// valid_from) in dieser Region löschen, dann Upsert in Batches.
async function upload(
  // deno-lint-ignore no-explicit-any
  supabase: SupabaseClient<any, "public", "public", any, any>,
  offers: Offer[],
  market: string,
  zip: string,
): Promise<number> {
  const validFroms = offers.map((o) => o.valid_from).filter((v): v is string => !!v);
  if (validFroms.length) {
    const current = validFroms.reduce((a, b) => (a > b ? a : b));
    const { error } = await supabase
      // Nur eigene (Marktguru-)Zeilen aufräumen — Daten anderer Quellen
      // (smartshop-rust) dürfen von diesem Dev-Werkzeug nie gelöscht werden
      .from("offers").delete().eq("source", "marktguru")
      .eq("market", market).eq("region", zip).lt("valid_from", current);
    if (error) throw new Error(`Delete: ${error.message}`);
  }

  // Duplikate innerhalb des Batches entfernen (Upsert-Konfliktschlüssel)
  const seen = new Set<string>();
  const rows: Record<string, unknown>[] = [];
  for (const o of offers) {
    const key = `${o.market}|${o.product}|${o.valid_from}`;
    if (seen.has(key)) continue;
    seen.add(key);
    rows.push({ ...o, region: zip });
  }

  let upserted = 0;
  for (let i = 0; i < rows.length; i += BATCH_SIZE) {
    const batch = rows.slice(i, i + BATCH_SIZE);
    const { error } = await supabase
      .from("offers")
      .upsert(batch, { onConflict: "market,product,valid_from,region" });
    if (error) throw new Error(`Upsert: ${error.message}`);
    upserted += batch.length;
  }
  return upserted;
}
