// deno test marktguru_test.ts — Mapping-Logik (Port von _to_offer & Co.)
import { assertEquals } from "jsr:@std/assert@1";
import { categorize, formatUnit, mapMgCategories, toOffer, validity } from "./marktguru.ts";

const base = {
  product: { name: "Vollmilch 3,5%" },
  price: 0.99,
  validityDates: [{ from: "2026-07-19T22:00:00Z", to: "2026-07-25T21:59:59Z" }],
};

Deno.test("Basis-Mapping", () => {
  const o = toOffer({ ...base }, "Lidl")!;
  assertEquals(o.market, "Lidl");
  assertEquals(o.product, "Vollmilch 3,5%");
  assertEquals(o.price, 0.99);
  assertEquals(o.loyaltyPrice, null);
  assertEquals(o.category, "Milchprodukte");
  assertEquals(o.emoji, "🥛");
  assertEquals(o.source, "marktguru");
  // UTC 22:00 → Berlin (Sommerzeit +2) = Folgetag
  assertEquals(o.valid_from, "2026-07-20");
  assertEquals(o.valid_until, "2026-07-25");
});

Deno.test("Ungültige Preise/Namen → null", () => {
  assertEquals(toOffer({ ...base, price: 0 }, "Lidl"), null);
  assertEquals(toOffer({ ...base, price: 20000 }, "Lidl"), null);
  assertEquals(toOffer({ ...base, price: "1,99" }, "Lidl"), null);
  assertEquals(toOffer({ ...base, product: { name: "  " } }, "Lidl"), null);
});

Deno.test("Brand-Prefix", () => {
  const o = toOffer({ ...base, brand: { name: "Milbona" } }, "Lidl")!;
  assertEquals(o.product, "Milbona Vollmilch 3,5%");
  assertEquals(o.brand, "Milbona");
});

Deno.test("Brand schon im Namen → kein Doppel-Prefix", () => {
  const o = toOffer(
    { ...base, product: { name: "Milbona Vollmilch" }, brand: { name: "Milbona" } },
    "Lidl",
  )!;
  assertEquals(o.product, "Milbona Vollmilch");
});

Deno.test("nobrand-Platzhalter wird ignoriert", () => {
  const o = toOffer({ ...base, brand: { name: "thisisnobrand123" } }, "Lidl")!;
  assertEquals(o.product, "Vollmilch 3,5%");
  assertEquals(o.brand, null);
});

Deno.test("Loyalty: price ist Kartenpreis, oldPrice wird Anzeigepreis", () => {
  const o = toOffer(
    { ...base, price: 1.11, oldPrice: 1.49, requiresLoyalityMembership: true },
    "Rewe",
  )!;
  assertEquals(o.price, 1.49);
  assertEquals(o.loyaltyPrice, 1.11);
  assertEquals(o.regular_price, 1.49);
});

Deno.test("Loyalty ohne oldPrice: price bleibt Anzeigepreis", () => {
  const o = toOffer({ ...base, price: 1.11, requiresLoyalityMembership: true }, "Rewe")!;
  assertEquals(o.price, 1.11);
  assertEquals(o.loyaltyPrice, 1.11);
});

Deno.test("Normal-/Grundpreis-Felder", () => {
  const o = toOffer(
    { ...base, oldPrice: 1.49, referencePrice: 1.98, unit: { shortName: "l" }, volume: 0.5 },
    "Lidl",
  )!;
  assertEquals(o.regular_price, 1.49);
  assertEquals(o.base_price, 1.98);
  assertEquals(o.base_unit, "l");
});

Deno.test("Unit-Formatierung", () => {
  assertEquals(formatUnit({ volume: 0.25, unit: { shortName: "kg" } }), "250g");
  assertEquals(formatUnit({ volume: 0.5, unit: { shortName: "l" } }), "500ml");
  assertEquals(formatUnit({ volume: 1.5, unit: { shortName: "l" } }), "1.5l");
  assertEquals(formatUnit({ volume: 2, unit: { shortName: "kg" } }), "2kg");
  assertEquals(formatUnit({ volume: 0.33, unit: { shortName: "l" }, quantity: 6 }), "6 x 330ml");
  assertEquals(formatUnit({}), "Stück");
  assertEquals(formatUnit({ volume: 1 }), "Stück");
});

Deno.test("MG-Kategorie hat Vorrang vor Keyword-Fallback", () => {
  const o = toOffer(
    { ...base, product: { name: "Kirschtomatensauce" }, categories: [{ name: "Saucen & Gewürze" }] },
    "Edeka",
  )!;
  assertEquals(o.category, "Vorrat"); // via MG "sauce", nicht "Obst & Gemüse" via "tomate"
});

Deno.test("mapMgCategories: leer/unbekannt → null", () => {
  assertEquals(mapMgCategories([]), null);
  assertEquals(mapMgCategories([{ name: "Elektronik" }]), null);
  assertEquals(mapMgCategories([{ name: "Tiefkühlkost" }]), "Tiefkühl");
});

Deno.test("categorize-Fallback", () => {
  assertEquals(categorize("Schokoriegel"), ["Süßwaren", "🍫"]);
  assertEquals(categorize("Unbekanntes Dings"), ["Sonstiges", "🛒"]);
});

Deno.test("validity: fehlende Daten", () => {
  assertEquals(validity({}), [null, null]);
  assertEquals(validity({ validityDates: [{}] }), [null, null]);
  assertEquals(validity({ validityDates: [{ from: "kaputt" }] }), [null, null]);
});

Deno.test("Winterzeit-Konvertierung (+1)", () => {
  const [from] = validity({ validityDates: [{ from: "2026-01-04T23:00:00Z" }] });
  assertEquals(from, "2026-01-05");
});
