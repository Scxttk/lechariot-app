#!/usr/bin/env python3
"""Wie viele von Bring!s Artikeln bekommen bei uns ein gezeichnetes Zeichen?

**Die Zahl, die ich sechs Runden lang falsch berichtet habe.** „226 Zeichen von
750 Artikeln" vergleicht zwei verschiedene Dinge: Bring! zeichnet je *Artikel*,
wir je *Begriff*, und ein Begriff deckt mehrere Artikel ab — `römersalat` trägt
Kopf-, Eisberg-, Feldsalat und Rucola. Wer die Zeichen zählt, misst den Aufwand;
wer die abgedeckten Artikel zählt, misst das Ergebnis.

    python3 tools/artikelzeichen-stand.py

Liest `docs/bring-katalog.txt` (die aus der Bildschirmaufnahme abgeschriebenen
Namen), löst jeden über `matching-woerterbuch.json` auf und sieht in
`ItemGlyphs.swift` nach, ob der Begriff gezeichnet ist.
"""
import json, os, re, sys

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Namen, die die Texterkennung aus Kopfzeilen, Marken und abgeschnittenen
# Zeilen aufgelesen hat. Sie stehen hier und nicht in der Katalogdatei, damit
# die Abschrift unangetastet bleibt.
RAUSCHEN = {
    "2 Artikel", "5 Artikel", "7 Artikel", "Anders", "16 COFFEE PADS", "Von A-Z",
    "Anderer La-", "Artikel anhand der Kategorien.", "Listen", "Inspiration",
    "Bring!", "Dr. Oetker", "Ferrero Rocher", "Pringles", "Frosta", "Lego Set",
    "La Mia Familia", "Vielen Dank", "our users", "iii", "Suprema", "Piccolini",
    "SENSEO® Pads", "VITALS", "Koawach", "CHOCOLATE", "Kiri", "MüllerMilch",
    "Actimel", "ARABICA", "-TONNO-", "-W-", "Kinder Joy", "mix", "schi Getränk",
    "cker", "kel", "zeltes", "chen", "len", "ten", "RUN", "keulensteaks",
    "die ROSTOCKER", "Lucky Bamboo", "enseo", "Light", "Creme", "Snacks", "Dose",
    "Magarine", "Khaki", "Getränke", "Gemüse", "Riegel", "Pure\"",
    "Vegane Chunks", "Veganes Gyros", "Mett für Igel", "Mettigel",
    "Hitchis Kratzeis", "Kartoffeln Mal", "blätter", "kerne", "Fussili",
    "Spirelli", "Knöpfli", "Kovertüre", "NATRON", "Brokkr", "Creme Bruehle",
    "Erdbeeren oder", "Körnerbrot \"das", "Röschen triologie", "baby®", "ben",
    "mittel", "ner", "schmuck", "sen (10€)", "spray", "tel", "ter", "www", "zen",
    "corny hafer schoko", "PROPANE", "Spezi kasten", "Frosch", "Frosch Baby",
    "Fleckenzwerg", "Scrub Mommy", "True Fruits", "Choco Fresh", "Dinoschnitzel",
    "Fertige Kuchensnacks", "Vegane Schoko", "DIP", "Grill", "Papier",
    "Kräuter", "Blumen", "Pflanzen", "Töpfe", "Spieße", "Reiniger", "Putzmittel",
    "Süssigkeiten", "Zigaretten", "Giesskanne",
}


def normalisiert(text):
    """Beide Seiten gleich behandeln — sonst zählt der Bogen Treffer als Lücke.

    Der erste Anlauf normalisierte nur den Bring!-Namen und verglich ihn gegen
    die **rohen** Wörterbucheinträge. „WC-Reiniger" wurde damit zu
    „wcreiniger" und traf den Eintrag „wc-reiniger" nicht mehr — als Lücke
    gezählt, obwohl der Begriff da war.
    """
    return re.sub(r"[^a-zäöü ]", "", text.lower().replace("ß", "ss")).strip()


def main():
    katalog = [z.strip() for z in open(os.path.join(WURZEL, "docs/bring-katalog.txt"))]
    artikel = [a for a in katalog
               if a and a not in RAUSCHEN and not re.match(r"^\d", a) and len(a) > 2]

    woerterbuch = json.load(open(os.path.join(
        WURZEL, "ios/LeChariot/Resources/matching-woerterbuch.json")))["begriffe"]
    # **Dieselbe Wahl wie `ItemGlyphTerm.beste(aus:für:)`.** Der erste Anlauf
    # nahm per `setdefault` den Begriff, der zufällig zuerst kam; die App nahm
    # den alphabetisch ersten. Zwei Regeln für dieselbe Frage, und keine davon
    # meinte etwas. Jetzt beide: Heißt der Begriff wie das Wort, ist er es;
    # sonst gewinnt der mit den wenigsten Synonymen (der feinere), bei
    # Gleichstand der alphabetisch erste.
    synonyme = {b: len(e.get("exact") or []) + 1 for b, e in woerterbuch.items()}
    kandidaten = {}
    for begriff, eintrag in woerterbuch.items():
        for wort in (eintrag.get("exact") or []) + [begriff]:
            kandidaten.setdefault(normalisiert(wort), set()).add(begriff)

    wort_zu_begriff = {
        wort: (wort if wort in {normalisiert(b) for b in menge} and wort in woerterbuch
               else min(menge, key=lambda b: (synonyme[b], b)))
        for wort, menge in kandidaten.items()
    }

    quelle = open(os.path.join(WURZEL, "ios/LeChariot/DesignSystem/ItemGlyphs.swift")).read()
    gezeichnet = set(re.findall(r'^\s*"([^"]+)": \{ p in', quelle, re.M))

    def begriff_von(name):
        """Dieselbe Leiter wie `ItemGlyphTerm`: **erst die ganze Wendung**, dann
        die Wörter — und unter den Wörtern gewinnt das letzte.

        Der erste Anlauf sah nur das letzte Wort an und meldete „BBQ Sauce" als
        Lücke, obwohl `grillsauce` genau diese Wendung führt. Ein Messbogen,
        der anders auflöst als die App, misst die App nicht.
        """
        k = normalisiert(name)
        for kandidat in (k, k.rstrip("n"), k + "n"):
            if kandidat in wort_zu_begriff:
                return wort_zu_begriff[kandidat]
        worte = k.split()
        for wort in reversed(worte):
            for kandidat in (wort, wort.rstrip("n"), wort + "n"):
                if kandidat in wort_zu_begriff:
                    return wort_zu_begriff[kandidat]
        return None

    mit_begriff = [a for a in artikel if begriff_von(a)]
    mit_zeichen = [a for a in mit_begriff if begriff_von(a) in gezeichnet]

    print(f"Bring!-Artikel (Rauschen abgezogen)  {len(artikel):4d}")
    print(f"  lösen auf einen Begriff auf        {len(mit_begriff):4d}  "
          f"({len(mit_begriff) / len(artikel):.0%})")
    print(f"  bekommen ein gezeichnetes Zeichen  {len(mit_zeichen):4d}  "
          f"({len(mit_zeichen) / len(artikel):.0%})")
    print(f"\nunsere Zeichen: {len(gezeichnet)}")

    if "--offen" in sys.argv:
        offen = sorted(a for a in artikel if a not in set(mit_zeichen))
        print(f"\n== ohne Zeichen ({len(offen)}) ==")
        print(", ".join(offen))


if __name__ == "__main__":
    main()
