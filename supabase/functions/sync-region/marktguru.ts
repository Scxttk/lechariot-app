// Smart Shop – Marktguru-Client (Deno-Port von scraper/marktguru_client.py)
// Keys werden zur Laufzeit aus dem HTML der Marktguru-Homepage extrahiert,
// Retailer-IDs über die filters.retailers der Suchantwort aufgelöst.

const HOMEPAGE = "https://www.marktguru.de";
const API_BASE = "https://api.marktguru.de/api/v1";
const PAGE_SIZE = 500; // API-Maximum pro Request
const PROBE_QUERIES = ["milch", "brot", "butter", "apfel"]; // zum Auflösen der Retailer-IDs

const USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
  "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

export interface Offer {
  market: string;
  product: string;
  price: number;
  loyaltyPrice: number | null;
  unit: string;
  category: string | null;
  emoji: string | null;
  valid_from: string | null;
  valid_until: string | null;
  regular_price: number | null;
  base_price: number | null;
  base_unit: string | null;
  brand: string | null;
  source: string;
}

// Marktguru-Kategoriename (lowercase, contains-Match, Reihenfolge = Priorität)
// → App-Kategorie. Identisch zu MG_CATEGORY_MAP in marktguru_client.py.
const MG_CATEGORY_MAP: [string, string][] = [
  ["tiefkühl", "Tiefkühl"], ["frost", "Tiefkühl"], ["eiscreme", "Tiefkühl"], ["speiseeis", "Tiefkühl"],
  ["obst", "Obst & Gemüse"], ["gemüse", "Obst & Gemüse"], ["früchte", "Obst & Gemüse"],
  ["salat", "Obst & Gemüse"], ["kartoffel", "Obst & Gemüse"],
  ["milch", "Milchprodukte"], ["käse", "Milchprodukte"], ["butter", "Milchprodukte"],
  ["joghurt", "Milchprodukte"], ["quark", "Milchprodukte"], ["sahne", "Milchprodukte"],
  ["molkerei", "Milchprodukte"], ["eier", "Milchprodukte"],
  ["fleisch", "Fleisch & Wurst"], ["wurst", "Fleisch & Wurst"], ["schinken", "Fleisch & Wurst"],
  ["geflügel", "Fleisch & Wurst"], ["fisch", "Fleisch & Wurst"], ["grill", "Fleisch & Wurst"],
  ["brot", "Backwaren"], ["backware", "Backwaren"], ["gebäck", "Backwaren"], ["brötchen", "Backwaren"],
  ["bier", "Getränke"], ["wein", "Getränke"], ["sekt", "Getränke"], ["spirituosen", "Getränke"],
  ["saft", "Getränke"], ["wasser", "Getränke"], ["kaffee", "Getränke"], ["tee", "Getränke"],
  ["getränk", "Getränke"], ["limonade", "Getränke"], ["energy", "Getränke"],
  ["süßigkeit", "Süßwaren"], ["süßware", "Süßwaren"], ["schokolade", "Süßwaren"],
  ["snack", "Süßwaren"], ["chips", "Süßwaren"], ["keks", "Süßwaren"], ["bonbon", "Süßwaren"],
  ["drogerie", "Drogerie"], ["pflege", "Drogerie"], ["hygiene", "Drogerie"],
  ["waschmittel", "Drogerie"], ["putz", "Drogerie"], ["reinig", "Drogerie"], ["kosmetik", "Drogerie"],
  ["konserve", "Vorrat"], ["nudel", "Vorrat"], ["pasta", "Vorrat"], ["reis", "Vorrat"],
  ["öl", "Vorrat"], ["essig", "Vorrat"], ["gewürz", "Vorrat"], ["sauce", "Vorrat"], ["soße", "Vorrat"],
  ["müsli", "Vorrat"], ["cerealien", "Vorrat"], ["backzutat", "Vorrat"], ["brotaufstrich", "Vorrat"],
];

// Keyword-Fallback über den Produktnamen (identisch zu scrapers/categorizer.py)
const CATEGORIES: Record<string, string[]> = {
  "Fleisch & Wurst": [
    "hack", "fleisch", "steak", "wurst", "schinken", "speck", "salami",
    "bratwurst", "schnitzel", "huhn", "hähnchen", "pute", "lachs", "fisch",
    "garnelen", "thunfisch", "hering", "forelle", "rind", "schwein",
  ],
  "Obst & Gemüse": [
    "apfel", "banane", "tomate", "karotte", "salat", "gurke", "paprika",
    "zwiebel", "kartoffel", "zucchini", "brokkoli", "spinat", "erdbeere",
    "traube", "orange", "zitrone", "kiwi", "mango", "melone", "birne",
    "kirsche", "pfirsich", "pflaume", "obst", "gemüse", "ananas",
    "beere", "nektarine", "avocado", "zwetschge", "aprikose", "radieschen",
    "kohlrabi", "aubergine", "champignon", "pilz", "lauch", "sellerie",
  ],
  "Milchprodukte": [
    "milch", "butter", "käse", "joghurt", "quark", "sahne", "schmand",
    "frischkäse", "mozzarella", "gouda", "edam", "brie", "camembert",
    "kefir", "skyr", "rahm",
  ],
  "Getränke": [
    "wasser", "saft", "cola", "bier", "wein", "sekt", "limo", "limonade",
    "kaffee", "tee", "kakao", "smoothie", "energy", "fanta", "sprite",
    "mineralwasser", "sprudel",
  ],
  "Vorrat": [
    "nudel", "pasta", "reis", "mehl", "zucker", "öl", "essig", "salz",
    "pfeffer", "gewürz", "soße", "sauce", "senf", "ketchup", "mayo",
    "mayonnaise", "konserve", "dose", "suppe", "brühe", "linse", "bohne",
    "erbse", "mais", "tomaten", "passata",
  ],
  "Backwaren": [
    "brot", "brötchen", "toast", "croissant", "baguette", "semmel",
    "laugenbrezel", "brezel", "kuchen", "torte", "muffin", "gebäck",
    "keks", "waffel",
  ],
  "Tiefkühl": [
    "tiefkühl", "gefroren", "tk ", "pizza", "pommes", "fischstäbchen",
    "eis", "speiseeis", "eisbecher",
  ],
  "Drogerie": [
    "shampoo", "duschgel", "zahnpasta", "waschmittel", "spülmittel",
    "deodorant", "deo", "seife", "klopapier", "toilettenpapier",
    "taschentuch", "windel", "rasierer",
  ],
  "Süßwaren": [
    "schokolade", "schoko", "gummibär", "bonbon", "chips", "snack",
    "popcorn", "nuss", "mandel", "erdnuss", "praline", "riegel",
    "müsliriegel", "kaugummi",
  ],
};

const EMOJI_MAP: Record<string, string> = {
  "Fleisch & Wurst": "🥩",
  "Obst & Gemüse": "🥦",
  "Milchprodukte": "🥛",
  "Getränke": "🥤",
  "Vorrat": "🥫",
  "Backwaren": "🍞",
  "Tiefkühl": "🧊",
  "Drogerie": "🧴",
  "Süßwaren": "🍫",
  "Sonstiges": "🛒",
};

// Marktguru-Name (lowercase, contains-Match) → App-Marktname
const KNOWN_RETAILERS: [string, string][] = [
  ["lidl", "Lidl"],
  ["rewe", "Rewe"],
  ["edeka", "Edeka"],
  ["kaufland", "Kaufland"],
  ["penny", "Penny"],
  ["netto", "Netto"],
  ["aldi süd", "Aldi Süd"],
  ["aldi nord", "Aldi Nord"],
];

export function categorize(name: string): [string, string] {
  const lower = name.toLowerCase();
  for (const [cat, keywords] of Object.entries(CATEGORIES)) {
    if (keywords.some((kw) => lower.includes(kw))) return [cat, EMOJI_MAP[cat]];
  }
  return ["Sonstiges", "🛒"];
}

export function mapMgCategories(mgCategories: { name?: string }[]): string | null {
  const names = mgCategories.map((c) => (c.name ?? "").toLowerCase()).join(" ");
  if (!names.trim()) return null;
  for (const [keyword, appCat] of MG_CATEGORY_MAP) {
    if (names.includes(keyword)) return appCat;
  }
  return null;
}

// UTC-Zeitstempel → lokales Datum (Europe/Berlin) als YYYY-MM-DD
function toLocalDate(iso: string | null | undefined): string | null {
  if (!iso) return null;
  const dt = new Date(iso);
  if (isNaN(dt.getTime())) return null;
  // en-CA formatiert als YYYY-MM-DD
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Berlin" }).format(dt);
}

export function validity(item: Record<string, unknown>): [string | null, string | null] {
  const dates = (item.validityDates ?? []) as { from?: string; to?: string }[];
  if (!dates.length) return [null, null];
  return [toLocalDate(dates[0].from), toLocalDate(dates[0].to)];
}

// Kompakte Zahl ohne überflüssige Nullen, wie Pythons %g
function g(n: number): string {
  return String(parseFloat(n.toPrecision(6)));
}

export function formatUnit(item: Record<string, unknown>): string {
  const volume = item.volume as number | undefined;
  const short = (((item.unit as { shortName?: string } | undefined)?.shortName) ?? "").trim();
  if (!volume || !short) return "Stück";
  let text: string;
  if (short === "kg" && volume < 1) text = `${g(volume * 1000)}g`;
  else if (short === "l" && volume < 1) text = `${g(volume * 1000)}ml`;
  else text = `${g(volume)}${short}`;
  const quantity = (item.quantity as number | undefined) || 1;
  return quantity > 1 ? `${g(quantity)} x ${text}` : text;
}

// Mapping exakt wie MarktguruClient._to_offer
export function toOffer(item: Record<string, unknown>, market: string): Offer | null {
  const price = item.price;
  let product = (((item.product as { name?: string } | undefined)?.name) ?? "").trim();
  if (!product || typeof price !== "number" || !(price > 0 && price < 10_000)) return null;

  const brand = (((item.brand as { name?: string } | undefined)?.name) ?? "").trim();
  // Marktguru nutzt "thisisnobrand123" als Platzhalter für markenlose Produkte
  const isNoBrand = brand.toLowerCase().includes("nobrand");
  if (brand && !isNoBrand && !product.toLowerCase().includes(brand.toLowerCase())) {
    product = `${brand} ${product}`;
  }

  const [validFrom, validUntil] = validity(item);
  // Marktguru-Kategorie hat Vorrang, Keyword-Matching über den Namen als Fallback
  const [kwCategory, emoji] = categorize(product);
  const category = mapMgCategories((item.categories ?? []) as { name?: string }[]) ?? kwCategory;

  // Bei Kundenkarten-Angeboten ist `price` der Karten-Preis
  const oldPrice = item.oldPrice as number | undefined;
  const loyalty = item.requiresLoyalityMembership ? price : null;
  const displayPrice = loyalty && oldPrice ? oldPrice : price;

  const referencePrice = item.referencePrice as number | undefined;
  return {
    market,
    product,
    price: displayPrice,
    loyaltyPrice: loyalty,
    unit: formatUnit(item),
    category,
    emoji,
    valid_from: validFrom,
    valid_until: validUntil,
    regular_price: oldPrice ?? null,
    base_price: referencePrice ?? null,
    base_unit: ((item.unit as { shortName?: string } | undefined)?.shortName) ?? null,
    brand: brand && !isNoBrand ? brand : null,
    source: "marktguru",
  };
}

export class MarktguruClient {
  private headers: Record<string, string> = {
    "User-Agent": USER_AGENT,
    Accept: "application/json",
  };

  constructor(private zip: string) {}

  // API- und Client-Key aus dem HTML der Marktguru-Homepage extrahieren
  async loadKeys(): Promise<void> {
    const resp = await fetch(HOMEPAGE, { headers: this.headers });
    if (!resp.ok) throw new Error(`Marktguru-Homepage: HTTP ${resp.status}`);
    const html = await resp.text();
    const apiKey = html.match(/"apiKey"\s*:\s*"([^"]+)"/);
    const clientKey = html.match(/"clientKey"\s*:\s*"([^"]+)"/);
    if (!apiKey || !clientKey) {
      throw new Error("Marktguru-Keys nicht im Homepage-HTML gefunden – Layout geändert?");
    }
    this.headers["x-apikey"] = apiKey[1];
    this.headers["x-clientkey"] = clientKey[1];
  }

  private async get(path: string, params: Record<string, string>): Promise<Record<string, unknown>> {
    const url = new URL(`${API_BASE}/${path}`);
    url.searchParams.set("as", "web");
    for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
    const resp = await fetch(url, { headers: this.headers });
    if (!resp.ok) throw new Error(`Marktguru ${path}: HTTP ${resp.status}`);
    return await resp.json();
  }

  // Für diese PLZ verfügbare Lebensmittel-Retailer: {App-Marktname: retailerId}
  // (kein öffentlicher Listen-Endpoint; IDs stehen in filters.retailers der Suchantwort)
  async resolveRetailers(): Promise<Record<string, number>> {
    const found: Record<string, number> = {};
    for (const q of PROBE_QUERIES) {
      const data = await this.get("offers/search", {
        limit: "1", offset: "0", q, zipCode: this.zip,
      });
      const retailers = ((data.filters as Record<string, unknown> | undefined)?.retailers ??
        []) as { id: number; name: string }[];
      for (const r of retailers) {
        const lower = r.name.toLowerCase();
        for (const [key, appName] of KNOWN_RETAILERS) {
          if (lower.includes(key) && !(appName in found)) found[appName] = r.id;
        }
      }
    }
    return found;
  }

  // Alle Angebote eines Retailers laden (paginiert) und auf Offer mappen
  async fetchOffers(appName: string, retailerId: number, maxOffers = PAGE_SIZE): Promise<Offer[]> {
    const raw: Record<string, unknown>[] = [];
    let offset = 0;
    while (offset < maxOffers) {
      const limit = Math.min(PAGE_SIZE, maxOffers - offset);
      const data = await this.get("offers", {
        limit: String(limit), offset: String(offset),
        zipCode: this.zip, advertiserId: String(retailerId),
      });
      const page = (data.results ?? []) as Record<string, unknown>[];
      raw.push(...page);
      offset += page.length;
      if (page.length < limit || offset >= ((data.totalResults as number) ?? 0)) break;
    }

    const offers: Offer[] = [];
    const seen = new Set<string>();
    for (const item of raw) {
      const offer = toOffer(item, appName);
      if (!offer) continue;
      const key = `${offer.product.toLowerCase()}|${offer.price}`;
      if (seen.has(key)) continue;
      seen.add(key);
      offers.push(offer);
    }
    return offers;
  }
}
