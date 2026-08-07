import SwiftUI

/// **Der Zeichensatz für die einzelnen Artikel** — einer je Wörterbuchbegriff,
/// nicht mehr einer je Kategorie.
///
/// Schritt 3 von L-3 im [[Le Chariot Liste-Konzept]]. Schritt 2 gab jeder der
/// fünfzehn Kategorien eine eigene Zeichnung (`CategoryGlyph`), und für die
/// Zeile mit Abschnittskopf reichte das. **Im Raster reicht es nicht:** Wenn
/// jede Kachel ihr eigenes Zeichen trägt, stehen Erdbeeren, Bananen, Tomaten,
/// Zwiebeln und Salat nebeneinander — und alle fünf zeigen denselben Apfel.
///
/// **Die Arbeitsliste ist das Wörterbuch, nicht der Katalog eines Ladens.**
/// Gezeichnet werden die Begriffe aus `matching-woerterbuch.json` — genau das
/// Vokabular, auf das der Zuordner einen getippten Artikel ohnehin abbildet.
/// Ein eigener Warenkatalog wäre die dritte Stelle, an der Warenkunde gepflegt
/// wird (siehe `ShoppingSections`).
///
/// **Formeln im Code, wie beim Kategoriesatz und beim App-Icon.** Achtzig
/// SVGs im Bundle wären achtzig Dateien, die niemand mehr anfasst; hier ist
/// jede Kurve eine Zeile, die man ändern kann. Der Stift, das Einheitsquadrat
/// und die Strichstärke kommen unverändert aus `CategoryGlyphs.swift` — ein
/// zweites DSL daneben wäre der Anfang zweier Zeichenstile.
///
/// **Diese Datei kennt nur SwiftUI und den Kategoriesatz.** Keine Modelle,
/// kein Wörterbuch, kein Bundle: `tools/zeichensatz.swift` übersetzt sie ohne
/// App-Ziel, und genau das macht die Runde Zeichnen–Ansehen zwei Sekunden
/// lang statt zwei Minuten. Die Auflösung Artikeltext → Begriff steht deshalb
/// nebenan in `ItemGlyphTerm`.
enum ItemGlyph {

    typealias Rezept = (inout Pen) -> Void

    /// Die Zeichnung dieses Begriffs, oder `nil` für einen, für den es hier
    /// keine gibt — dann greift das Kategoriezeichen, statt dass ein
    /// erfundenes Bild das Falsche behauptet.
    static func drawing(for term: String, in rect: CGRect) -> CategoryGlyph.Drawing? {
        guard let recipe = recipes[term] else { return nil }
        var pen = Pen(rect: rect)
        recipe(&pen)
        return CategoryGlyph.Drawing(stroke: pen.stroke, fill: pen.fill)
    }

    /// Nur für Tests und den Prüfbogen: alle Begriffe mit einer Zeichnung.
    static var drawnTerms: [String] { recipes.keys.sorted() }

    /// **Die benannten Ausnahmen.** Begriffe des Wörterbuchs, für die es keinen
    /// ehrlichen Gegenstand gibt — Warengruppen, keine Dinge. Sie stehen hier
    /// namentlich, damit ein *neuer* Begriff ohne Zeichnung im Test auffällt,
    /// statt still auf das Kategoriezeichen durchzufallen.
    ///
    /// - `soßen` ist Ketchup **und** Mayo **und** Senf **und** Dressing: eine
    ///   Quetschflasche behauptet eins davon.
    /// - `gewürze` ist Pfeffer, Curry, Kräuter — eine Mühle wäre bei 13 pt
    ///   ohnehin der Salzstreuer von nebenan.
    /// - `fertiggericht`, `protein/fitness`, `windeln/hygiene` sind Regale.
    ///
    /// `konserven` und `schoten/hülsen` standen zunächst auch hier und sind
    /// **wieder heruntergekommen**: Ihre Synonyme sind Mais, Kidneybohnen,
    /// Linsen, Tomatenmark bzw. Kaiserschoten, Zuckerschoten, Edamame. Dose
    /// und Schote benennen genau das.
    static let withoutDrawing: Set<String> = [
        "soßen", "gewürze", "fertiggericht", "protein/fitness", "windeln/hygiene",
    ]

    /// **In Blöcken statt in einem Wörterbuch.** Achtzig Rezepte in einem
    /// Literal bringen den Typprüfer zum Stehen; nach Gängen getrennt bleibt
    /// jeder Block auch beim Lesen die Runde durch den Laden.
    private static let recipes: [String: Rezept] = {
        var alle: [String: Rezept] = [:]
        for teil in [obstUndGemuese, molkereiUndBackwaren, fleischUndFisch,
                     vorratUndGetraenke] {
            alle.merge(teil) { erstes, _ in erstes }
        }
        return alle
    }()

    // MARK: - Obst & Gemüse

    private static let obstUndGemuese: [String: Rezept] = [

        // Apfel mit Kerbe, Stiel, Blatt links. Dasselbe Motiv wie beim
        // Kategoriezeichen, und das ist kein Versehen: Ein Apfel ist ein
        // Apfel. Das Blatt liegt hier links und der Bauch ist runder, damit
        // die beiden nebeneinander nicht wie ein Doppel wirken.
        "äpfel": { p in
            p.begin(p.at(0.50, 0.30))
            p.bow(p.at(0.14, 0.56), p.at(0.32, 0.16), p.at(0.14, 0.32))
            p.bow(p.at(0.50, 0.94), p.at(0.14, 0.80), p.at(0.30, 0.94))
            p.bow(p.at(0.86, 0.56), p.at(0.70, 0.94), p.at(0.86, 0.80))
            p.bow(p.at(0.50, 0.30), p.at(0.86, 0.32), p.at(0.68, 0.16))
            p.close()
            p.line([p.at(0.52, 0.28), p.at(0.56, 0.10)])
            p.begin(p.at(0.52, 0.18))
            p.bow(p.at(0.22, 0.14), p.at(0.42, 0.08), p.at(0.26, 0.04))
            p.bow(p.at(0.52, 0.18), p.at(0.22, 0.22), p.at(0.38, 0.22))
        },

        // Banane: Außenbogen, Innenbogen, kurzer Stiel am linken Ende. Der
        // Stiel ist das, was die Sichel von einem Mond unterscheidet.
        "bananen": { p in
            p.begin(p.at(0.14, 0.34))
            p.bow(p.at(0.88, 0.42), p.at(0.20, 0.94), p.at(0.74, 0.90))
            p.bow(p.at(0.14, 0.34), p.at(0.68, 0.66), p.at(0.28, 0.60))
            p.close()
            p.line([p.at(0.14, 0.34), p.at(0.09, 0.20)])
        },

        // Zitrone: bauchiges Oval, schräg gelegt, mit einem Zipfel an **beiden**
        // Enden. Der erste Entwurf war schlanker und hatte nur einen Zipfel —
        // auf dem Prüfbogen ein **Blatt**. Die Zipfel sind es, die aus einer
        // Linsenform eine Zitrone machen.
        "zitronen": { p in
            p.begin(p.at(0.16, 0.64))
            p.bow(p.at(0.84, 0.36), p.at(0.20, 0.26), p.at(0.60, 0.14))
            p.bow(p.at(0.16, 0.64), p.at(0.80, 0.86), p.at(0.40, 0.86))
            p.close()
            p.line([p.at(0.17, 0.63), p.at(0.08, 0.74)])
            p.line([p.at(0.83, 0.37), p.at(0.92, 0.26)])
        },

        // Orange: runder Körper, ein Blatt flach obenauf, kurzer Stiel. Ohne
        // Kerbe — die ist beim Apfel und trennt die beiden.
        "orangen": { p in
            p.circle(p.at(0.50, 0.60), 0.33)
            p.line([p.at(0.50, 0.27), p.at(0.50, 0.14)])
            p.begin(p.at(0.50, 0.20))
            p.bow(p.at(0.84, 0.14), p.at(0.58, 0.10), p.at(0.76, 0.06))
            p.bow(p.at(0.50, 0.20), p.at(0.84, 0.22), p.at(0.66, 0.22))
        },

        // Erdbeere für alle Beeren: Herzkörper, Kelchblätter, zwei Kerne.
        // Himbeere und Heidelbeere sind bei 13 pt nicht voneinander zu
        // unterscheiden — die Erdbeere ist die Beere, die eine Silhouette hat.
        "beeren": { p in
            p.begin(p.at(0.50, 0.36))
            p.bow(p.at(0.16, 0.50), p.at(0.28, 0.30), p.at(0.16, 0.36))
            p.bow(p.at(0.50, 0.94), p.at(0.16, 0.72), p.at(0.32, 0.88))
            p.bow(p.at(0.84, 0.50), p.at(0.68, 0.88), p.at(0.84, 0.72))
            p.bow(p.at(0.50, 0.36), p.at(0.84, 0.36), p.at(0.72, 0.30))
            p.close()
            p.line([p.at(0.22, 0.30), p.at(0.50, 0.44), p.at(0.78, 0.30)])
            p.line([p.at(0.50, 0.44), p.at(0.50, 0.14)])
            p.dot(p.at(0.40, 0.60), 0.048)
            p.dot(p.at(0.60, 0.70), 0.048)
        },

        // Traube: sechs Beeren als Dreieck, Stiel, Blatt. Gefüllt, weil ein
        // Ring von drei Pixeln ein Punkt ist (dieselbe Rechnung wie bei der
        // Pfote).
        "trauben": { p in
            for (x, y) in [(0.28, 0.50), (0.50, 0.50), (0.72, 0.50),
                           (0.39, 0.70), (0.61, 0.70), (0.50, 0.89)] {
                p.dot(p.at(CGFloat(x), CGFloat(y)), 0.103)
            }
            p.line([p.at(0.50, 0.38), p.at(0.50, 0.16)])
            p.begin(p.at(0.50, 0.22))
            p.bow(p.at(0.84, 0.16), p.at(0.58, 0.12), p.at(0.76, 0.08))
            p.bow(p.at(0.50, 0.22), p.at(0.84, 0.24), p.at(0.66, 0.24))
        },

        // Melonenspalte: Schnittkante oben, Schale unten, Fruchtlinie, Kerne.
        "melone": { p in
            p.begin(p.at(0.06, 0.32))
            p.to(p.at(0.94, 0.32))
            p.bow(p.at(0.06, 0.32), p.at(0.94, 0.96), p.at(0.06, 0.96))
            p.close()
            p.begin(p.at(0.16, 0.38))
            p.bow(p.at(0.84, 0.38), p.at(0.18, 0.84), p.at(0.82, 0.84))
            p.dot(p.at(0.36, 0.50), 0.045)
            p.dot(p.at(0.50, 0.58), 0.045)
            p.dot(p.at(0.64, 0.50), 0.045)
        },

        // Pfirsich: runder Körper mit Naht und Blatt. Die Naht ist alles, was
        // ihn von der Orange trennt — ohne sie sind es zwei Kreise.
        "pfirsich": { p in
            p.circle(p.at(0.50, 0.60), 0.33)
            p.begin(p.at(0.50, 0.28))
            p.bow(p.at(0.44, 0.92), p.at(0.38, 0.46), p.at(0.40, 0.72))
            p.line([p.at(0.52, 0.28), p.at(0.56, 0.14)])
            p.begin(p.at(0.54, 0.20))
            p.bow(p.at(0.86, 0.16), p.at(0.62, 0.10), p.at(0.80, 0.08))
            p.bow(p.at(0.54, 0.20), p.at(0.86, 0.24), p.at(0.70, 0.24))
        },

        // Halbe Avocado: Umriss, Fruchtfleischkante, Kern. Die einzige
        // Zeichnung des Satzes, die man an ihrer Mitte erkennt.
        "avocado": { p in
            p.begin(p.at(0.50, 0.06))
            p.bow(p.at(0.18, 0.58), p.at(0.32, 0.10), p.at(0.18, 0.36))
            p.bow(p.at(0.50, 0.94), p.at(0.18, 0.80), p.at(0.32, 0.94))
            p.bow(p.at(0.82, 0.58), p.at(0.68, 0.94), p.at(0.82, 0.80))
            p.bow(p.at(0.50, 0.06), p.at(0.82, 0.36), p.at(0.68, 0.10))
            p.close()
            p.begin(p.at(0.50, 0.20))
            p.bow(p.at(0.29, 0.59), p.at(0.38, 0.23), p.at(0.29, 0.43))
            p.bow(p.at(0.50, 0.85), p.at(0.29, 0.74), p.at(0.38, 0.85))
            p.bow(p.at(0.71, 0.59), p.at(0.62, 0.85), p.at(0.71, 0.74))
            p.bow(p.at(0.50, 0.20), p.at(0.71, 0.43), p.at(0.62, 0.23))
            p.close()
            p.dot(p.at(0.50, 0.62), 0.145)
        },

        // Obstschale für den Sammelbegriff: runde Schale, Rand, zwei Früchte
        // und ein Blatt. Ein Apfel stünde hier für Kiwi, Ananas und Mango mit
        // — die Schale sagt „Obst", ohne eine Sorte zu behaupten.
        // **Zweiter Anlauf, und der erste war ein Gesicht.** Runde Schale plus
        // zwei gleich große Kreise darüber ergaben auf dem Prüfbogen ein
        // grinsendes Smiley — die Schale war der Mund. Beides ist behoben: Die
        // Schale hat einen flachen Boden statt eines Bogens, und die Früchte
        // sind verschieden groß und liegen auf verschiedener Höhe. Symmetrie
        // ist hier keine Gestaltung, sondern die Ursache.
        "obst": { p in
            p.begin(p.at(0.10, 0.58))
            p.to(p.at(0.22, 0.90))
            p.to(p.at(0.78, 0.90))
            p.to(p.at(0.90, 0.58))
            p.line([p.at(0.05, 0.58), p.at(0.95, 0.58)])
            p.circle(p.at(0.36, 0.39), 0.175)
            p.circle(p.at(0.68, 0.45), 0.125)
            p.line([p.at(0.36, 0.21), p.at(0.46, 0.10)])
        },

        // Tomate: runder Körper, Kelch als Doppelstrich, Stiel. Drei Striche
        // oben liefen bei 13 pt zu; zwei lassen die Kuppe stehen.
        "tomaten": { p in
            p.circle(p.at(0.50, 0.62), 0.32)
            p.line([p.at(0.28, 0.22), p.at(0.50, 0.34), p.at(0.72, 0.22)])
            p.line([p.at(0.50, 0.34), p.at(0.50, 0.10)])
        },

        // Gurke: gerader Körper, nach links geneigt, mit drei Querkerben. Die
        // Kerben und die **Neigungsrichtung** sind der ganze Unterschied zur
        // Zucchini, die nach rechts liegt.
        "gurke": { p in
            p.capsule(0.50, 0.50, 0.30, 0.86, tilt: -32)
            for t in [CGFloat(-0.22), 0, 0.22] {
                quer(&p, mitte: (0.50, 0.50), hoehe: 0.86, neigung: -32, bei: t, laenge: 0.20)
            }
        },

        // Zucchini: nach rechts geneigt, mit Stiel am oberen Ende. Der erste
        // Entwurf setzte den Stiel oben **links** an — die Kapsel liegt aber
        // andersherum, und auf dem Prüfbogen schwebte ein Klecks neben der
        // Frucht. Das obere Ende wird deshalb gerechnet, nicht geschätzt.
        "zucchini": { p in
            p.capsule(0.48, 0.52, 0.30, 0.82, tilt: 30)
            let ende = achse(mitte: (0.48, 0.52), hoehe: 0.82, neigung: 30, bei: -0.40)
            p.line([p.at(ende.0, ende.1), p.at(ende.0 + 0.10, ende.1 - 0.14)])
        },

        // Paprika: Schultern, **zwei tiefe Lappen** unten, Stiel schräg oben.
        // Der erste Entwurf hatte dieselbe Anlage mit einer Kerbe von 0,18 —
        // auf dem Prüfbogen war der Boden glatt und das Ganze ein **Einmachglas
        // mit Kreuz obendrauf**. Die Kerbe geht jetzt bis 0,64, also fast bis
        // zur Mitte des Körpers, und die Deckelquerlinie ist weg.
        "paprika": { p in
            // Die **Mulde** um den Stiel ist der zweite Fund: Mit gerader
            // Oberkante war der Körper ein Apfel mit Kerbe. Eine Paprika hat
            // hohe Schultern und sackt dazwischen ein.
            p.begin(p.at(0.50, 0.38))
            p.bow(p.at(0.18, 0.52), p.at(0.34, 0.26), p.at(0.18, 0.32))
            p.bow(p.at(0.34, 0.92), p.at(0.18, 0.74), p.at(0.18, 0.92))
            p.bow(p.at(0.50, 0.66), p.at(0.46, 0.92), p.at(0.50, 0.80))
            p.bow(p.at(0.66, 0.92), p.at(0.50, 0.80), p.at(0.54, 0.92))
            p.bow(p.at(0.82, 0.52), p.at(0.82, 0.92), p.at(0.82, 0.74))
            p.bow(p.at(0.50, 0.38), p.at(0.82, 0.32), p.at(0.66, 0.26))
            p.close()
            p.line([p.at(0.50, 0.38), p.at(0.56, 0.12)])
        },

        // Salat: drei Blätter, die aus einem Strunk auffächern.
        //
        // **Vierter Anlauf, und die drei davor waren alle derselbe Fehler:
        // ein runder Kopf.** Was man in eine runde Silhouette hineinzeichnet,
        // entscheidet, was sie ist, und keine der drei Füllungen hat gewonnen:
        //
        // 1. Eine senkrechte Rippe: ein **Apfel mit Stiel**.
        // 2. Zwei geschwungene Rippen: ein **Kürbis** — senkrechte Linien in
        //    einem runden Körper sind Rillen.
        // 3. Zwei liegende Kuppeln: ein **Gesicht**. Zwei ineinander
        //    geschachtelte Bögen in einem Rund sind Nase und Mund, und das
        //    sieht man, sobald man es einmal gesehen hat.
        //
        // Der Kopf war das Problem, nicht die Füllung. Drei Blätter aus einem
        // Punkt haben gar keine geschlossene Außenkante, in die etwas
        // hineinzudeuten wäre — und Romana, Rucola und Feldsalat sind ohnehin
        // eher ein Büschel als eine Kugel.
        "salat": { p in
            p.begin(p.at(0.50, 0.92))
            p.bow(p.at(0.50, 0.10), p.at(0.33, 0.72), p.at(0.33, 0.28))
            p.bow(p.at(0.50, 0.92), p.at(0.67, 0.28), p.at(0.67, 0.72))
            p.close()
            p.begin(p.at(0.50, 0.92))
            p.bow(p.at(0.10, 0.38), p.at(0.28, 0.68), p.at(0.13, 0.49))
            p.bow(p.at(0.50, 0.92), p.at(0.34, 0.61), p.at(0.47, 0.80))
            p.close()
            p.begin(p.at(0.50, 0.92))
            p.bow(p.at(0.90, 0.38), p.at(0.72, 0.68), p.at(0.87, 0.49))
            p.bow(p.at(0.50, 0.92), p.at(0.66, 0.61), p.at(0.53, 0.80))
            p.close()
        },

        // Zwiebel: bauchige Knolle mit **Hals**, zwei kurze Nähte, zwei Triebe.
        //
        // Der Hals ist der Fund des zweiten Anlaufs. Vorher war der Körper
        // rund und die Nähte liefen bis unten durch — auf dem Prüfbogen eine
        // **Melone mit Fühlern**. Eine Zwiebel ist unten breit und läuft oben
        // zusammen; erst dieses Gefälle trägt die Triebe, statt sie
        // anzukleben. Die Triebe wiederum trennen sie vom Knoblauch, der
        // stattdessen eine Spitze hat.
        "zwiebeln": { p in
            p.begin(p.at(0.50, 0.30))
            p.bow(p.at(0.16, 0.66), p.at(0.34, 0.30), p.at(0.16, 0.46))
            p.bow(p.at(0.50, 0.94), p.at(0.16, 0.82), p.at(0.30, 0.94))
            p.bow(p.at(0.84, 0.66), p.at(0.70, 0.94), p.at(0.84, 0.82))
            p.bow(p.at(0.50, 0.30), p.at(0.84, 0.46), p.at(0.66, 0.30))
            p.close()
            p.begin(p.at(0.42, 0.44))
            p.bow(p.at(0.38, 0.74), p.at(0.35, 0.54), p.at(0.34, 0.64))
            p.begin(p.at(0.58, 0.44))
            p.bow(p.at(0.62, 0.74), p.at(0.65, 0.54), p.at(0.66, 0.64))
            p.line([p.at(0.50, 0.30), p.at(0.50, 0.20)])
            p.line([p.at(0.50, 0.20), p.at(0.36, 0.06)])
            p.line([p.at(0.50, 0.20), p.at(0.64, 0.08)])
        },

        // Knoblauchknolle: Spitze oben, Zehennähte fächern nach unten.
        "knoblauch": { p in
            p.begin(p.at(0.50, 0.12))
            p.bow(p.at(0.16, 0.62), p.at(0.34, 0.28), p.at(0.16, 0.44))
            p.bow(p.at(0.50, 0.94), p.at(0.16, 0.80), p.at(0.30, 0.94))
            p.bow(p.at(0.84, 0.62), p.at(0.70, 0.94), p.at(0.84, 0.80))
            p.bow(p.at(0.50, 0.12), p.at(0.84, 0.44), p.at(0.66, 0.28))
            p.close()
            p.begin(p.at(0.46, 0.26))
            p.bow(p.at(0.32, 0.90), p.at(0.34, 0.44), p.at(0.30, 0.70))
            p.begin(p.at(0.54, 0.26))
            p.bow(p.at(0.68, 0.90), p.at(0.66, 0.44), p.at(0.70, 0.70))
            p.line([p.at(0.50, 0.12), p.at(0.50, 0.03)])
        },

        // Kartoffel: unregelmäßige Knolle mit drei Augen. Die Unregelmäßigkeit
        // ist der Punkt — eine runde Knolle mit Punkten ist ein Würfel.
        "kartoffeln": { p in
            p.begin(p.at(0.12, 0.48))
            p.bow(p.at(0.46, 0.18), p.at(0.12, 0.28), p.at(0.26, 0.18))
            p.bow(p.at(0.88, 0.42), p.at(0.68, 0.18), p.at(0.86, 0.24))
            p.bow(p.at(0.70, 0.84), p.at(0.92, 0.60), p.at(0.88, 0.78))
            p.bow(p.at(0.28, 0.86), p.at(0.56, 0.92), p.at(0.42, 0.92))
            p.bow(p.at(0.12, 0.48), p.at(0.14, 0.80), p.at(0.08, 0.62))
            p.close()
            p.dot(p.at(0.38, 0.44), 0.045)
            p.dot(p.at(0.62, 0.56), 0.045)
            p.dot(p.at(0.44, 0.70), 0.042)
        },

        // Möhre: verjüngter Körper, zwei Kerben, drei Blätter.
        "möhren": { p in
            p.begin(p.at(0.28, 0.38))
            p.to(p.at(0.72, 0.38))
            p.to(p.at(0.52, 0.94))
            p.close()
            p.line([p.at(0.36, 0.52), p.at(0.46, 0.49)])
            p.line([p.at(0.42, 0.68), p.at(0.52, 0.65)])
            p.line([p.at(0.50, 0.38), p.at(0.32, 0.12)])
            p.line([p.at(0.50, 0.38), p.at(0.52, 0.06)])
            p.line([p.at(0.50, 0.38), p.at(0.72, 0.14)])
        },

        // Brokkoli: wolkiger Kopf, zwei Stielstriche, Schnittkante.
        "brokkoli": { p in
            p.begin(p.at(0.16, 0.44))
            p.bow(p.at(0.36, 0.20), p.at(0.14, 0.28), p.at(0.22, 0.20))
            p.bow(p.at(0.62, 0.18), p.at(0.46, 0.12), p.at(0.52, 0.12))
            p.bow(p.at(0.84, 0.44), p.at(0.74, 0.16), p.at(0.86, 0.26))
            p.close()
            p.line([p.at(0.38, 0.46), p.at(0.40, 0.90)])
            p.line([p.at(0.62, 0.46), p.at(0.58, 0.90)])
            p.line([p.at(0.40, 0.90), p.at(0.58, 0.90)])
        },

        // Pilz: Hut als Halbkreis, Stiel mit rundem Fuß.
        "pilze": { p in
            p.begin(p.at(0.10, 0.48))
            p.bow(p.at(0.90, 0.48), p.at(0.12, 0.08), p.at(0.88, 0.08))
            p.close()
            p.begin(p.at(0.36, 0.48))
            p.to(p.at(0.36, 0.82))
            p.bow(p.at(0.64, 0.82), p.at(0.36, 0.94), p.at(0.64, 0.94))
            p.to(p.at(0.64, 0.48))
        },

        // Aubergine: schlanker Hals oben rechts, bauchiger Fuß unten links,
        // Kelch als flaches V, Stiel darüber.
        //
        // Der erste Entwurf war zu rund und zu kurz — auf dem Prüfbogen eine
        // **Zitrone mit Gekritzel obendrauf**. Was die Aubergine ausmacht, ist
        // das Gefälle: oben schmal, unten doppelt so breit, und die ganze
        // Frucht liegt schräg in der Kachel statt aufrecht darin zu stehen.
        "aubergine": { p in
            p.begin(p.at(0.62, 0.26))
            p.bow(p.at(0.28, 0.54), p.at(0.48, 0.26), p.at(0.30, 0.38))
            p.bow(p.at(0.46, 0.92), p.at(0.22, 0.74), p.at(0.26, 0.92))
            p.bow(p.at(0.82, 0.62), p.at(0.72, 0.92), p.at(0.84, 0.82))
            p.bow(p.at(0.62, 0.26), p.at(0.80, 0.44), p.at(0.72, 0.32))
            p.close()
            p.line([p.at(0.44, 0.20), p.at(0.62, 0.30), p.at(0.78, 0.18)])
            p.line([p.at(0.62, 0.28), p.at(0.64, 0.08)])
        },

        // Erbsenschote: längliche Schote, drei Erbsen. Für Kaiserschoten,
        // Zuckerschoten, Edamame — alles, was in einer Hülse steckt.
        "schoten/hülsen": { p in
            p.begin(p.at(0.08, 0.72))
            p.bow(p.at(0.92, 0.30), p.at(0.26, 0.96), p.at(0.74, 0.58))
            p.bow(p.at(0.08, 0.72), p.at(0.70, 0.28), p.at(0.28, 0.48))
            p.close()
            p.dot(p.at(0.30, 0.67), 0.072)
            p.dot(p.at(0.50, 0.56), 0.072)
            p.dot(p.at(0.70, 0.45), 0.072)
        },
    ]

    // MARK: - Vorrat, Getränke, Süßes & Tiefkühl

    private static let vorratUndGetraenke: [String: Rezept] = [

        // Farfalle: zwei Flügel mit gewellter Außenkante, in der Mitte
        // zusammengekniffen. Spaghetti wären bei 13 pt ein Knäuel.
        "nudeln": { p in
            p.begin(p.at(0.46, 0.40))
            p.to(p.at(0.10, 0.18))
            p.bow(p.at(0.10, 0.82), p.at(0.00, 0.40), p.at(0.20, 0.60))
            p.to(p.at(0.46, 0.60))
            p.close()
            p.begin(p.at(0.54, 0.40))
            p.to(p.at(0.90, 0.18))
            p.bow(p.at(0.90, 0.82), p.at(1.00, 0.40), p.at(0.80, 0.60))
            p.to(p.at(0.54, 0.60))
            p.close()
            p.line([p.at(0.46, 0.40), p.at(0.54, 0.60)])
            p.line([p.at(0.54, 0.40), p.at(0.46, 0.60)])
        },

        // Reisschale: Schale, Fuß, vier **kleine schräge** Körner.
        //
        // Größer und waagerecht gelegt waren die Körner Früchte, und die
        // Schale war damit die Obstschale von nebenan. Ein Reiskorn ist klein
        // und liegt schräg; genau daran hängt hier der Unterschied.
        "reis": { p in
            p.begin(p.at(0.12, 0.54))
            p.bow(p.at(0.88, 0.54), p.at(0.16, 0.92), p.at(0.84, 0.92))
            p.close()
            p.line([p.at(0.36, 0.94), p.at(0.64, 0.94)])
            for (cx, cy, neigung) in [(0.28, 0.44, -32.0), (0.50, 0.32, 24.0),
                                      (0.72, 0.44, -22.0)] {
                p.capsule(CGFloat(cx), CGFloat(cy), 0.15, 0.07, tilt: neigung)
            }
        },

        // Mehltüte: Papiersack mit umgeschlagener Kante und einer Ähre.
        "mehl": { p in
            p.begin(p.at(0.18, 0.90))
            p.to(p.at(0.24, 0.40))
            p.to(p.at(0.70, 0.40))
            p.to(p.at(0.76, 0.90))
            p.close()
            p.line([p.at(0.24, 0.40), p.at(0.30, 0.26), p.at(0.64, 0.26), p.at(0.70, 0.40)])
            p.line([p.at(0.30, 0.58), p.at(0.64, 0.58)])
            p.line([p.at(0.86, 0.86), p.at(0.86, 0.52)])
            p.line([p.at(0.86, 0.62), p.at(0.94, 0.54)])
            p.line([p.at(0.86, 0.62), p.at(0.78, 0.54)])
            p.line([p.at(0.86, 0.76), p.at(0.94, 0.68)])
            p.line([p.at(0.86, 0.76), p.at(0.78, 0.68)])
        },

        // Zwei Zuckerwürfel, versetzt.
        "zucker": { p in
            p.stroke.addRoundedRect(in: p.box(0.36, 0.66, 0.42, 0.42),
                                    cornerSize: p.corner(0.05))
            p.stroke.addRoundedRect(in: p.box(0.64, 0.34, 0.42, 0.42),
                                    cornerSize: p.corner(0.05))
        },

        // Salzstreuer: **abgesetzte** Kappe mit drei Löchern über einem
        // geraden Körper.
        //
        // Im ersten Entwurf ging die Kappe ohne Absatz in den Körper über und
        // das Ganze war auf dem Prüfbogen ein **Türbogen mit einem Kasten
        // darin**. Die Schulter ist es, die aus dem Umriss einen Streuer
        // macht — und die Löcher gehören in die Kappe, nicht an ihren Rand.
        "salz": { p in
            p.begin(p.at(0.30, 0.92))
            p.to(p.at(0.30, 0.44))
            p.to(p.at(0.70, 0.44))
            p.to(p.at(0.70, 0.92))
            p.close()
            p.begin(p.at(0.34, 0.44))
            p.to(p.at(0.34, 0.28))
            p.bow(p.at(0.66, 0.28), p.at(0.34, 0.10), p.at(0.66, 0.10))
            p.to(p.at(0.66, 0.44))
            p.dot(p.at(0.42, 0.24), 0.036)
            p.dot(p.at(0.50, 0.19), 0.036)
            p.dot(p.at(0.58, 0.24), 0.036)
        },

        // Ölflasche mit Ausgießer und **fallendem Tropfen**. Der Tropfen ist
        // das, was sie von jeder anderen Flasche des Satzes trennt.
        "öl": { p in
            // **Der Tropfen steht im Bauch, nicht daneben.** Neben der Flasche
            // war er erst ein Schlüsselanhänger, mit Ausgießer dazu eine
            // **Gießkanne**. Alles, was seitlich aus einer Flasche wächst,
            // wird zu einem Arm — im Bauch gelesen ist derselbe Tropfen ein
            // Etikett, und das ist die ganze Auskunft: eine Flasche mit einem
            // Tropfen darauf ist Öl und kein Wein.
            // **Und die Flasche musste dafür breiter werden.** Im ersten
            // Anlauf mit dem Tropfen im Bauch war sie so schlank, dass der
            // Tropfen zwischen ihren Wänden zulief — bei 6 pt Strich in einem
            // 18-pt-Tropfen bleibt kein Loch übrig, und übrig blieb ein
            // **schwarzes Dreieck**. Der Tropfen braucht Platz, sonst ist er
            // ein Fleck.
            p.begin(p.at(0.20, 0.92))
            p.to(p.at(0.20, 0.50))
            p.bow(p.at(0.40, 0.30), p.at(0.20, 0.38), p.at(0.40, 0.38))
            p.to(p.at(0.40, 0.12))
            p.to(p.at(0.60, 0.12))
            p.to(p.at(0.60, 0.30))
            p.bow(p.at(0.80, 0.50), p.at(0.60, 0.38), p.at(0.80, 0.38))
            p.to(p.at(0.80, 0.92))
            p.close()
            p.begin(p.at(0.50, 0.54))
            p.bow(p.at(0.68, 0.76), p.at(0.56, 0.60), p.at(0.68, 0.68))
            p.bow(p.at(0.32, 0.76), p.at(0.68, 0.87), p.at(0.32, 0.87))
            p.bow(p.at(0.50, 0.54), p.at(0.32, 0.68), p.at(0.44, 0.60))
            p.close()
        },

        // Essigflasche: schlanker Körper, langer Hals, Kugelkorken — und ein
        // **schräges** Etikett.
        //
        // **Zwei Anläufe, beide an derselben Nachbarschaft gescheitert.** Mit
        // waagerechtem Etikett war sie die Weinflasche von nebenan; mit
        // schrägem Ausgießer eine **Gießkanne**. Die Schräge gehört aufs
        // Etikett, nicht an den Hals: Sie unterscheidet, ohne etwas
        // anzubauen.
        "essig": { p in
            p.begin(p.at(0.30, 0.92))
            p.to(p.at(0.30, 0.58))
            p.bow(p.at(0.42, 0.38), p.at(0.30, 0.46), p.at(0.42, 0.46))
            p.to(p.at(0.42, 0.20))
            p.to(p.at(0.58, 0.20))
            p.to(p.at(0.58, 0.38))
            p.bow(p.at(0.70, 0.58), p.at(0.58, 0.46), p.at(0.70, 0.46))
            p.to(p.at(0.70, 0.92))
            p.close()
            p.circle(p.at(0.50, 0.12), 0.09)
            p.line([p.at(0.30, 0.80), p.at(0.70, 0.66)])
            p.line([p.at(0.30, 0.68), p.at(0.70, 0.54)])
        },

        // Müsli: Packung mit Bauchbinde, drei **schräge** Flocken daneben.
        //
        // Runde Ellipsen neben einer Schachtel mit offenen Klappen waren auf
        // dem Prüfbogen **Weintrauben an einer Kiste**. Flach und schräg
        // gelegt liest sich dasselbe Oval als Flocke.
        "müsli": { p in
            p.begin(p.at(0.20, 0.90))
            p.to(p.at(0.20, 0.26))
            p.to(p.at(0.60, 0.26))
            p.to(p.at(0.60, 0.90))
            p.close()
            p.line([p.at(0.20, 0.44), p.at(0.60, 0.44)])
            p.line([p.at(0.20, 0.58), p.at(0.60, 0.58)])
            for (cx, cy, neigung) in [(0.78, 0.36, -28.0), (0.88, 0.58, 20.0), (0.76, 0.76, -14.0)] {
                p.capsule(CGFloat(cx), CGFloat(cy), 0.22, 0.10, tilt: neigung)
            }
        },

        // Marmeladenglas: Körper, Deckel mit Stoffhaube, Band.
        "marmelade": { p in
            p.begin(p.at(0.24, 0.92))
            p.to(p.at(0.24, 0.42))
            p.to(p.at(0.76, 0.42))
            p.to(p.at(0.76, 0.92))
            p.close()
            p.begin(p.at(0.18, 0.42))
            p.bow(p.at(0.82, 0.42), p.at(0.18, 0.14), p.at(0.82, 0.14))
            p.close()
            p.line([p.at(0.18, 0.30), p.at(0.82, 0.30)])
        },

        // Kaffee: zwei Bohnen mit Naht. Eine Tasse hätte hier neben Tee und
        // Kakao gestanden und wäre die dritte gewesen.
        "kaffee": { p in
            // **Ovale, keine Linsen.** Spitz zulaufend waren die beiden Bohnen
            // auf dem Prüfbogen ein Paar **Augen**. Eine Kaffeebohne ist rund
            // und hat eine geschwungene Naht — die Naht macht sie, nicht die
            // Form.
            p.stroke.addEllipse(in: p.box(0.34, 0.32, 0.42, 0.50))
            p.begin(p.at(0.34, 0.08))
            p.bow(p.at(0.34, 0.56), p.at(0.22, 0.20), p.at(0.46, 0.44))
            p.stroke.addEllipse(in: p.box(0.66, 0.70, 0.38, 0.44))
            p.begin(p.at(0.66, 0.49))
            p.bow(p.at(0.66, 0.91), p.at(0.55, 0.60), p.at(0.77, 0.80))
        },

        // Tee: die **Kanne** — Körper, Tülle links, Henkel rechts, Deckelknauf.
        //
        // **Der Teebeutel ist zweimal gescheitert, und beide Male am selben
        // Ding: an dem, was neben der Tasse hing.** Erst war der Anhänger so
        // groß wie die Tasse und das Ganze **Mörser mit Stößel**, dann hing er
        // an einem geknickten Faden und es war ein **Bagger**. Ein Strich, der
        // aus einem Gefäß herausragt und in einem Kasten endet, ist ein Arm.
        //
        // Die Kanne braucht nichts, was heraushängt, und sie ist in diesem
        // Satz die einzige — Kakao hat den Becher, Kaffee die Bohne.
        "tee": { p in
            p.begin(p.at(0.24, 0.44))
            p.to(p.at(0.24, 0.62))
            p.bow(p.at(0.72, 0.62), p.at(0.24, 0.88), p.at(0.72, 0.88))
            p.to(p.at(0.72, 0.44))
            p.close()
            p.line([p.at(0.36, 0.44), p.at(0.60, 0.44)])
            p.line([p.at(0.48, 0.44), p.at(0.48, 0.32)])
            p.line([p.at(0.24, 0.52), p.at(0.08, 0.36), p.at(0.08, 0.24)])
            p.begin(p.at(0.72, 0.52))
            p.bow(p.at(0.72, 0.76), p.at(0.94, 0.52), p.at(0.94, 0.76))
        },

        // Wasser: ein Tropfen. Die Flasche wäre die vierte gewesen, und der
        // Tropfen ist das einzige Zeichen des Satzes, das bei 13 pt noch
        // genauso aussieht wie bei 66.
        "wasser": { p in
            // **Unten rund, nicht spitz.** Zwei Bögen von Spitze zu Spitze
            // ergaben eine Linse und damit das Blatt, das die Zitrone schon
            // einmal war. Ein Tropfen hat genau **eine** Spitze.
            p.begin(p.at(0.50, 0.06))
            p.bow(p.at(0.88, 0.60), p.at(0.62, 0.22), p.at(0.88, 0.40))
            p.bow(p.at(0.12, 0.60), p.at(0.88, 0.88), p.at(0.12, 0.88))
            p.bow(p.at(0.50, 0.06), p.at(0.12, 0.40), p.at(0.38, 0.22))
            p.close()
        },

        // Saft: Glas mit Strohhalm und einer Scheibe am Rand.
        "saft": { p in
            p.begin(p.at(0.28, 0.34))
            p.to(p.at(0.36, 0.90))
            p.to(p.at(0.64, 0.90))
            p.to(p.at(0.72, 0.34))
            p.close()
            p.line([p.at(0.30, 0.48), p.at(0.70, 0.48)])
            p.line([p.at(0.58, 0.36), p.at(0.76, 0.10)])
            p.begin(p.at(0.28, 0.34))
            p.bow(p.at(0.10, 0.34), p.at(0.26, 0.16), p.at(0.12, 0.16))
            p.close()
        },

        // Limonade: hohe Dose mit Deckelellipse **innerhalb** des Körpers und
        // einer Lasche darin.
        //
        // Im ersten Entwurf saß die Ellipse genau auf der Oberkante und lief
        // mit dem Randfalz zu einem Klotz zusammen — auf dem Prüfbogen eine
        // **leere Karte**. Ein Stück weiter unten gelesen ist dieselbe Ellipse
        // ein Deckel.
        "limonade": { p in
            p.stroke.addRoundedRect(in: p.box(0.50, 0.56, 0.44, 0.72),
                                    cornerSize: p.corner(0.06))
            p.stroke.addEllipse(in: p.box(0.50, 0.32, 0.36, 0.14))
            p.line([p.at(0.44, 0.32), p.at(0.58, 0.32)])
        },

        // Bierkrug: Körper mit Henkel, Schaumkrone, zwei Blasen.
        "bier": { p in
            p.begin(p.at(0.20, 0.38))
            p.to(p.at(0.26, 0.90))
            p.to(p.at(0.64, 0.90))
            p.to(p.at(0.70, 0.38))
            p.close()
            p.begin(p.at(0.20, 0.38))
            p.bow(p.at(0.36, 0.20), p.at(0.20, 0.26), p.at(0.26, 0.20))
            p.bow(p.at(0.56, 0.20), p.at(0.46, 0.14), p.at(0.48, 0.14))
            p.bow(p.at(0.70, 0.38), p.at(0.66, 0.20), p.at(0.72, 0.26))
            p.begin(p.at(0.72, 0.48))
            p.bow(p.at(0.72, 0.72), p.at(0.94, 0.48), p.at(0.94, 0.72))
            p.dot(p.at(0.38, 0.56), 0.04)
            p.dot(p.at(0.52, 0.68), 0.04)
        },

        // Weinflasche: langer Hals, Schulter, Etikett. Das Weinglas ist das
        // Kategoriezeichen für Alkohol — Flasche und Glas gehören zusammen
        // und werden nicht verwechselt.
        "wein": { p in
            p.begin(p.at(0.34, 0.92))
            p.to(p.at(0.34, 0.54))
            p.bow(p.at(0.44, 0.34), p.at(0.34, 0.42), p.at(0.44, 0.42))
            p.to(p.at(0.44, 0.10))
            p.to(p.at(0.56, 0.10))
            p.to(p.at(0.56, 0.34))
            p.bow(p.at(0.66, 0.54), p.at(0.56, 0.42), p.at(0.66, 0.42))
            p.to(p.at(0.66, 0.92))
            p.close()
            p.line([p.at(0.34, 0.64), p.at(0.66, 0.64)])
            p.line([p.at(0.34, 0.80), p.at(0.66, 0.80)])
        },

        // Spirituosen: kantige Flasche mit Verschluss, daneben ein Glas.
        // Zwei Gefäße statt eines — eine schlanke Flasche allein wäre der
        // Wein von nebenan.
        "spirituosen": { p in
            p.begin(p.at(0.10, 0.92))
            p.to(p.at(0.10, 0.44))
            p.to(p.at(0.22, 0.30))
            p.to(p.at(0.22, 0.16))
            p.to(p.at(0.40, 0.16))
            p.to(p.at(0.40, 0.30))
            p.to(p.at(0.52, 0.44))
            p.to(p.at(0.52, 0.92))
            p.close()
            p.line([p.at(0.10, 0.60), p.at(0.52, 0.60)])
            p.begin(p.at(0.64, 0.56))
            p.to(p.at(0.70, 0.92))
            p.to(p.at(0.90, 0.92))
            p.to(p.at(0.96, 0.56))
            p.close()
        },

        // Schokoladentafel: Raster aus sechs Feldern, eine Ecke abgebrochen.
        "schokolade": { p in
            p.begin(p.at(0.12, 0.24))
            p.to(p.at(0.88, 0.24))
            p.to(p.at(0.88, 0.60))
            p.to(p.at(0.64, 0.60))
            p.to(p.at(0.64, 0.80))
            p.to(p.at(0.12, 0.80))
            p.close()
            p.line([p.at(0.12, 0.42), p.at(0.88, 0.42)])
            p.line([p.at(0.12, 0.60), p.at(0.64, 0.60)])
            p.line([p.at(0.37, 0.24), p.at(0.37, 0.80)])
            p.line([p.at(0.64, 0.24), p.at(0.64, 0.60)])
        },

        // Keks mit **Biss** und vier Stückchen. Der Biss ist die Auskunft:
        // Ein Kreis mit Punkten wäre die Wurstscheibe von nebenan.
        "kekse": { p in
            p.begin(p.at(0.74, 0.24))
            p.bow(p.at(0.50, 0.90), p.at(0.92, 0.44), p.at(0.78, 0.90))
            p.bow(p.at(0.24, 0.36), p.at(0.20, 0.90), p.at(0.10, 0.50))
            p.bow(p.at(0.46, 0.30), p.at(0.32, 0.28), p.at(0.38, 0.34))
            p.bow(p.at(0.56, 0.16), p.at(0.54, 0.26), p.at(0.48, 0.16))
            p.bow(p.at(0.74, 0.24), p.at(0.66, 0.16), p.at(0.72, 0.16))
            p.close()
            p.dot(p.at(0.40, 0.52), 0.055)
            p.dot(p.at(0.62, 0.48), 0.05)
            p.dot(p.at(0.54, 0.72), 0.05)
        },

        // Chipstüte: bauchiger Beutel mit gezackter Schweißnaht oben.
        "chips": { p in
            p.begin(p.at(0.24, 0.30))
            p.to(p.at(0.18, 0.90))
            p.to(p.at(0.82, 0.90))
            p.to(p.at(0.76, 0.30))
            p.close()
            p.line([p.at(0.24, 0.30), p.at(0.32, 0.20), p.at(0.42, 0.30),
                    p.at(0.52, 0.20), p.at(0.62, 0.30), p.at(0.70, 0.20),
                    p.at(0.76, 0.30)])
            p.begin(p.at(0.30, 0.62))
            p.bow(p.at(0.70, 0.62), p.at(0.42, 0.50), p.at(0.58, 0.74))
        },

        // Eiswaffel: **überstehende** Kugel, schmale Tüte, Rautenlinien.
        //
        // Gleich breit waren Kugel und Tüte im ersten Entwurf eine einzige
        // Silhouette — auf dem Prüfbogen die **Ortsmarke** von Karten-Apps.
        // Die Kugel muss über die Tüte hinausragen, sonst ist es keine Kugel,
        // sondern eine Spitze.
        "eis": { p in
            p.circle(p.at(0.50, 0.28), 0.27)
            p.line([p.at(0.24, 0.42), p.at(0.76, 0.42)])
            p.begin(p.at(0.30, 0.44))
            p.to(p.at(0.50, 0.94))
            p.to(p.at(0.70, 0.44))
            p.line([p.at(0.36, 0.54), p.at(0.60, 0.66)])
            p.line([p.at(0.64, 0.54), p.at(0.42, 0.68)])
        },

        // Pizzastück: Kruste oben, Spitze unten, drei Salamischeiben. **Die
        // Spitze zeigt nach unten** — mit der Spitze nach oben wäre es das
        // Käsedreieck.
        "pizza": { p in
            p.begin(p.at(0.10, 0.28))
            p.bow(p.at(0.90, 0.28), p.at(0.28, 0.10), p.at(0.72, 0.10))
            p.to(p.at(0.50, 0.92))
            p.close()
            p.begin(p.at(0.14, 0.38))
            p.bow(p.at(0.86, 0.38), p.at(0.30, 0.22), p.at(0.70, 0.22))
            p.dot(p.at(0.36, 0.50), 0.06)
            p.dot(p.at(0.62, 0.52), 0.055)
            p.dot(p.at(0.50, 0.72), 0.05)
        },

        // Tiefkühlgemüse: Beutel mit Flocke. Das Zeichen sagt „Gemüse aus dem
        // Frost", ohne eine Sorte zu behaupten — im Beutel ist mal Erbse, mal
        // Rahmspinat.
        "tiefkühlgemüse": { p in
            p.begin(p.at(0.22, 0.28))
            p.to(p.at(0.18, 0.90))
            p.to(p.at(0.82, 0.90))
            p.to(p.at(0.78, 0.28))
            p.close()
            p.line([p.at(0.50, 0.42), p.at(0.50, 0.78)])
            p.line([p.at(0.34, 0.51), p.at(0.66, 0.69)])
            p.line([p.at(0.66, 0.51), p.at(0.34, 0.69)])
        },

        // Pommes: Schachtel mit drei Stäbchen darüber.
        "pommes": { p in
            p.begin(p.at(0.24, 0.44))
            p.to(p.at(0.32, 0.92))
            p.to(p.at(0.68, 0.92))
            p.to(p.at(0.76, 0.44))
            p.close()
            p.line([p.at(0.34, 0.44), p.at(0.30, 0.14)])
            p.line([p.at(0.50, 0.42), p.at(0.50, 0.08)])
            p.line([p.at(0.66, 0.44), p.at(0.72, 0.16)])
        },

        // Eintopf: **tiefe** Schale mit Dampf. Kein Deckel und kein Knauf —
        // die hat der Kochtopf im Kategoriesatz.
        //
        // Die seitlichen Griffe sind weg: Mit ihnen war der Schalenrand eine
        // durchgehende Waagerechte, und darunter ein Bogen — auf dem Prüfbogen
        // ein **Mund**, mit den zwei Dampfschwaden darüber ein Gesicht. Eine
        // tiefe Schale hat ohnehin keine.
        "eintopf": { p in
            p.begin(p.at(0.20, 0.48))
            p.to(p.at(0.26, 0.74))
            p.bow(p.at(0.74, 0.74), p.at(0.32, 0.92), p.at(0.68, 0.92))
            p.to(p.at(0.80, 0.48))
            p.close()
            p.begin(p.at(0.38, 0.38))
            p.bow(p.at(0.38, 0.10), p.at(0.30, 0.30), p.at(0.46, 0.18))
            p.begin(p.at(0.60, 0.38))
            p.bow(p.at(0.60, 0.12), p.at(0.52, 0.30), p.at(0.68, 0.20))
        },

        // Konservendose: gedrungener Körper, Deckelellipse, Aufreißring
        // **auf** dem Deckel.
        //
        // Über den Deckel gesetzt war der Ring auf dem Prüfbogen der Henkel
        // einer **Laterne**. Auf dem Deckel liegend ist er das, was er ist.
        // Die Dose ist breiter als die Limonadendose und hat keine Lasche —
        // daran hält man die beiden auseinander.
        "konserven": { p in
            p.begin(p.at(0.16, 0.34))
            p.to(p.at(0.16, 0.84))
            p.bow(p.at(0.84, 0.84), p.at(0.16, 0.94), p.at(0.84, 0.94))
            p.to(p.at(0.84, 0.34))
            p.stroke.addEllipse(in: p.box(0.50, 0.34, 0.68, 0.22))
            p.circle(p.at(0.50, 0.34), 0.10)
        },

        // Erdnuss in der Schale: zwei Bäuche mit Taille, **schräg gelegt**,
        // mit drei Rillen quer.
        //
        // Senkrecht und mit zwei Punkten darin war sie auf dem Prüfbogen eine
        // **Acht**. Die Schräge nimmt ihr die Symmetrie, und Rillen sind das,
        // was eine Nussschale hat — Punkte hat sie nicht.
        "nüsse": { p in
            p.begin(p.at(0.18, 0.28))
            p.bow(p.at(0.50, 0.50), p.at(0.30, 0.06), p.at(0.52, 0.24))
            p.bow(p.at(0.82, 0.72), p.at(0.48, 0.76), p.at(0.70, 0.94))
            p.bow(p.at(0.50, 0.50), p.at(0.94, 0.52), p.at(0.72, 0.34))
            p.bow(p.at(0.18, 0.28), p.at(0.28, 0.66), p.at(0.06, 0.48))
            p.close()
            p.line([p.at(0.22, 0.44), p.at(0.36, 0.30)])
            p.line([p.at(0.58, 0.72), p.at(0.72, 0.58)])
            p.line([p.at(0.66, 0.82), p.at(0.78, 0.68)])
        },

        // Kakao: hoher Becher mit Henkel und zwei Dampfschwaden. Die Teetasse
        // steht auf einer Untertasse und hat keinen Henkel — daran hält man
        // die beiden auseinander.
        "kakao": { p in
            p.begin(p.at(0.26, 0.42))
            p.to(p.at(0.32, 0.92))
            p.to(p.at(0.64, 0.92))
            p.to(p.at(0.70, 0.42))
            p.close()
            p.begin(p.at(0.72, 0.52))
            p.bow(p.at(0.72, 0.74), p.at(0.94, 0.52), p.at(0.94, 0.74))
            p.begin(p.at(0.38, 0.30))
            p.bow(p.at(0.38, 0.06), p.at(0.30, 0.24), p.at(0.46, 0.12))
            p.begin(p.at(0.58, 0.30))
            p.bow(p.at(0.58, 0.08), p.at(0.50, 0.24), p.at(0.66, 0.14))
        },
    ]

    // MARK: - Fleisch, Wurst & Fisch

    private static let fleischUndFisch: [String: Rezept] = [

        // T-Bone-Steak: unregelmäßiges Stück mit dem Knochen **innen**.
        //
        // Der erste Entwurf hing den Knochen als Stiel mit zwei Knäufen unten
        // an einen runden Fleischklumpen — auf dem Prüfbogen ein **Luftballon**.
        // Ein dünner Strich mit runden Enden ist ein Griff, egal was daran
        // hängt. Beim T-Bone liegt der Knochen im Fleisch, und das T ist die
        // Auskunft, die kein anderes Stück des Satzes trägt.
        "fleisch": { p in
            // **Steak mit Grillstreifen, dritter Anlauf. Der Knochen ist der
            // Grund, warum die zwei davor nichts geworden sind:**
            //
            // 1. Als Stiel mit zwei Knäufen unten am Fleisch: ein **Luftballon**.
            // 2. Als T mitten im geschlossenen Rund: ein **Abzeichen**.
            //    Danach als Kerbe am Rand: ein **großes D**.
            //
            // Ein Knochen braucht Fläche, um als Knochen zu lesen, und bei
            // 13 pt gibt es die nicht. Streifen brauchen keine: Drei Schrägen
            // über einem unregelmäßigen Stück sagen „gebraten", und mehr muss
            // dieses Zeichen nicht sagen.
            // **Breit und eckig, nicht rund.** Im Raster stand das runde Steak
            // neben dem runden Putenschnitzel, und zwei texturierte Scheiben
            // nebeneinander sind zwei texturierte Scheiben. Ein Steak ist
            // länglich und hat Ecken; das Schnitzel bleibt das flache Oval.
            p.begin(p.at(0.08, 0.42))
            p.bow(p.at(0.44, 0.22), p.at(0.10, 0.28), p.at(0.24, 0.22))
            p.to(p.at(0.78, 0.26))
            p.bow(p.at(0.92, 0.54), p.at(0.90, 0.26), p.at(0.94, 0.38))
            p.bow(p.at(0.56, 0.78), p.at(0.90, 0.72), p.at(0.74, 0.78))
            p.to(p.at(0.24, 0.74))
            p.bow(p.at(0.08, 0.42), p.at(0.10, 0.72), p.at(0.06, 0.58))
            p.close()
            p.line([p.at(0.26, 0.56), p.at(0.38, 0.38)])
            p.line([p.at(0.46, 0.64), p.at(0.58, 0.40)])
            p.line([p.at(0.66, 0.66), p.at(0.76, 0.44)])
        },

        // Hackfleisch: flache Schale, Fleischberg darin, drei Windungen.
        "hackfleisch": { p in
            p.begin(p.at(0.10, 0.66))
            p.to(p.at(0.20, 0.88))
            p.to(p.at(0.80, 0.88))
            p.to(p.at(0.90, 0.66))
            p.close()
            p.begin(p.at(0.20, 0.66))
            p.bow(p.at(0.80, 0.66), p.at(0.26, 0.30), p.at(0.74, 0.30))
            p.line([p.at(0.34, 0.52), p.at(0.44, 0.46)])
            p.line([p.at(0.52, 0.42), p.at(0.62, 0.48)])
            p.line([p.at(0.40, 0.60), p.at(0.56, 0.58)])
        },

        // Wurst als **zwei Scheiben** mit Speckstückchen: Salami, Schinken,
        // Lyoner. Ein Ring wäre der Ein-/Ausschalter von iOS (siehe die
        // Fleischtheke im Kategoriesatz), zwei Scheiben sind unverwechselbar.
        "wurst": { p in
            p.circle(p.at(0.36, 0.40), 0.26)
            p.circle(p.at(0.64, 0.64), 0.26)
            p.dot(p.at(0.30, 0.34), 0.045)
            p.dot(p.at(0.42, 0.46), 0.04)
            p.dot(p.at(0.70, 0.72), 0.045)
            p.dot(p.at(0.60, 0.58), 0.04)
        },

        // Bratwurst **im Brötchen**: Wurst quer über einem aufgeschnittenen
        // Brötchen.
        //
        // **Zweimal war die Wurst allein ein Mund.** Erst eine Sichel mit
        // Grillstreifen — ein **grinsendes Gebiss** —, dann dieselbe Sichel
        // ohne alles: immer noch ein **Lächeln**. Eine liegende Sichel ist ein
        // Mund, daran ändert kein Detail etwas.
        //
        // Gerade gelegt wäre sie die Gurke, mit zwei Kapseln die Fleischtheke
        // aus dem Kategoriesatz. Im Brötchen ist sie beides nicht — und so
        // isst man sie hier ohnehin.
        "bratwurst": { p in
            p.stroke.addRoundedRect(in: p.box(0.50, 0.68, 0.84, 0.30),
                                    cornerSize: p.corner(0.15))
            p.stroke.addRoundedRect(in: p.box(0.50, 0.44, 0.76, 0.22),
                                    cornerSize: p.corner(0.11))
        },

        // Hähnchenkeule: dickes Fleisch oben, **kurzer** Knochen unten rechts
        // mit zwei dicken Knäufen.
        //
        // Auch hier war der erste Knochen zu lang und zu dünn und die Keule
        // damit eine **Lupe**. Der Knochen ist jetzt kaum länger als die
        // Knäufe breit sind — an einer Keule schaut er ja auch nur heraus.
        "hähnchen": { p in
            // **Eine Kontur, nicht zwei Teile.** Dreimal saß hier ein Knochen
            // als eigenes Ding am Fleisch — als Strich mit Knäufen war die
            // Keule eine **Lupe**, als Kapsel mit Kreis eine **Rassel**. Zwei
            // getrennte Formen übereinander liest niemand als ein Stück.
            //
            // Der vierte Anlauf zeichnet die ganze Keule als **einen**
            // geschlossenen Umriss: dicker Ballen oben rechts, Schaft, kleiner
            // Knauf unten links.
            p.begin(p.at(0.14, 0.88))
            p.bow(p.at(0.28, 0.74), p.at(0.06, 0.80), p.at(0.12, 0.72))
            p.to(p.at(0.46, 0.54))
            p.bow(p.at(0.68, 0.12), p.at(0.42, 0.30), p.at(0.48, 0.12))
            p.bow(p.at(0.88, 0.42), p.at(0.86, 0.12), p.at(0.92, 0.28))
            p.bow(p.at(0.58, 0.66), p.at(0.84, 0.58), p.at(0.72, 0.66))
            p.to(p.at(0.34, 0.84))
            p.bow(p.at(0.14, 0.88), p.at(0.28, 0.94), p.at(0.20, 0.96))
            p.close()
        },

        // Pute: das Schnitzel — flaches Stück mit drei Einschnitten.
        //
        // **Zweimal war der ganze Braten der Versuch, und zweimal ist er an
        // seinen Keulen gescheitert:** aufrecht auf der Kuppe waren sie Ohren
        // und der Braten ein **Hase**, quer angelegt zwei Augen und das Ganze
        // ein **Frosch**. Eine Kuppel mit zwei Anbauten wird zum Gesicht,
        // egal wo die Anbauten sitzen.
        //
        // Das Schnitzel ist der ehrliche Rest: Unter diesem Begriff stehen
        // Putenbrust, Putenbrustfilet, Putenschnitzel und Putensteaks — alles
        // flache Stücke. **Es ist die schwächste Zeichnung des Satzes**, weil
        // sie nichts über den Vogel sagt; sie sagt nur „Stück Fleisch", und
        // das ist wenigstens wahr.
        "pute": { p in
            p.begin(p.at(0.14, 0.54))
            p.bow(p.at(0.52, 0.22), p.at(0.14, 0.32), p.at(0.30, 0.22))
            p.bow(p.at(0.88, 0.48), p.at(0.74, 0.22), p.at(0.90, 0.30))
            p.bow(p.at(0.46, 0.82), p.at(0.86, 0.70), p.at(0.68, 0.82))
            p.bow(p.at(0.14, 0.54), p.at(0.26, 0.82), p.at(0.12, 0.70))
            p.close()
            // **Paniert, nicht gegrillt.** Schräge Striche hatte das Steak
            // schon; Krümel sagt „Schnitzel" und stößt sich mit nichts.
            p.dot(p.at(0.34, 0.44), 0.036)
            p.dot(p.at(0.50, 0.38), 0.036)
            p.dot(p.at(0.44, 0.58), 0.036)
            p.dot(p.at(0.62, 0.50), 0.036)
            p.dot(p.at(0.58, 0.68), 0.036)
            p.dot(p.at(0.72, 0.62), 0.036)
        },

        // Lamm: Wollkörper aus vier Bäuchen, Kopf links, zwei Beine.
        "lamm": { p in
            p.begin(p.at(0.34, 0.68))
            p.bow(p.at(0.36, 0.36), p.at(0.24, 0.62), p.at(0.24, 0.40))
            p.bow(p.at(0.58, 0.32), p.at(0.44, 0.28), p.at(0.48, 0.28))
            p.bow(p.at(0.80, 0.44), p.at(0.70, 0.28), p.at(0.82, 0.32))
            p.bow(p.at(0.70, 0.70), p.at(0.86, 0.60), p.at(0.80, 0.70))
            p.close()
            p.circle(p.at(0.26, 0.44), 0.13)
            p.dot(p.at(0.22, 0.42), 0.035)
            p.line([p.at(0.44, 0.70), p.at(0.44, 0.88)])
            p.line([p.at(0.66, 0.70), p.at(0.66, 0.88)])
        },

        // Schweinekopf: Schädel, zwei spitze Ohren, Rüssel mit zwei Nüstern.
        // Die spitzen Ohren trennen ihn vom Bärenkopf der Kinderkategorie,
        // der runde hat.
        "schwein": { p in
            p.circle(p.at(0.50, 0.58), 0.31)
            p.line([p.at(0.22, 0.40), p.at(0.18, 0.16), p.at(0.40, 0.28)])
            p.line([p.at(0.78, 0.40), p.at(0.82, 0.16), p.at(0.60, 0.28)])
            p.stroke.addRoundedRect(in: p.box(0.50, 0.66, 0.30, 0.20),
                                    cornerSize: p.corner(0.08))
            p.dot(p.at(0.43, 0.66), 0.035)
            p.dot(p.at(0.57, 0.66), 0.035)
        },

        // Rinderkopf: breiter Schädel, zwei geschwungene Hörner, Maul.
        "rind": { p in
            p.begin(p.at(0.22, 0.42))
            p.to(p.at(0.28, 0.74))
            p.bow(p.at(0.72, 0.74), p.at(0.36, 0.92), p.at(0.64, 0.92))
            p.to(p.at(0.78, 0.42))
            p.close()
            p.begin(p.at(0.22, 0.44))
            p.bow(p.at(0.06, 0.20), p.at(0.06, 0.42), p.at(0.02, 0.28))
            p.begin(p.at(0.78, 0.44))
            p.bow(p.at(0.94, 0.20), p.at(0.94, 0.42), p.at(0.98, 0.28))
            p.dot(p.at(0.40, 0.56), 0.04)
            p.dot(p.at(0.60, 0.56), 0.04)
            p.stroke.addEllipse(in: p.box(0.50, 0.78, 0.26, 0.14))
        },

        // Ente: Körper, Kopf, Schnabel, ein Flügelbogen.
        "ente": { p in
            p.begin(p.at(0.12, 0.62))
            p.bow(p.at(0.62, 0.50), p.at(0.18, 0.46), p.at(0.42, 0.44))
            p.bow(p.at(0.72, 0.84), p.at(0.82, 0.56), p.at(0.82, 0.76))
            p.bow(p.at(0.12, 0.62), p.at(0.48, 0.90), p.at(0.20, 0.80))
            p.close()
            p.circle(p.at(0.66, 0.30), 0.15)
            p.line([p.at(0.80, 0.28), p.at(0.96, 0.32), p.at(0.80, 0.38)])
            p.dot(p.at(0.62, 0.26), 0.035)
            p.begin(p.at(0.32, 0.62))
            p.bow(p.at(0.58, 0.68), p.at(0.40, 0.76), p.at(0.54, 0.78))
        },

        // Fisch: Körper, Keilschwanz **oben und unten**, Rückenflosse, Auge.
        // Der Kategoriefisch hat einen glatten Rücken; die Flosse ist der
        // Unterschied, an dem man die beiden nebeneinander auseinanderhält.
        "fisch": { p in
            p.begin(p.at(0.30, 0.54))
            p.bow(p.at(0.92, 0.54), p.at(0.44, 0.20), p.at(0.78, 0.24))
            p.bow(p.at(0.30, 0.54), p.at(0.78, 0.84), p.at(0.44, 0.88))
            p.close()
            p.begin(p.at(0.30, 0.54))
            p.to(p.at(0.06, 0.28))
            p.to(p.at(0.06, 0.80))
            p.close()
            p.line([p.at(0.52, 0.28), p.at(0.60, 0.12), p.at(0.72, 0.30)])
            p.dot(p.at(0.78, 0.48), 0.05)
        },
    ]

    // MARK: - Molkerei, Eier & Backwaren

    private static let molkereiUndBackwaren: [String: Rezept] = [

        // Milchtüte mit Giebel — dasselbe Motiv wie beim Kategoriezeichen,
        // schlanker gezogen. Milch ist die Milchtüte; hier etwas anderes zu
        // erfinden, nur damit es anders ist, wäre der falsche Ehrgeiz.
        "milch": { p in
            p.begin(p.at(0.26, 0.94))
            p.to(p.at(0.26, 0.44))
            p.to(p.at(0.38, 0.26))
            p.to(p.at(0.62, 0.26))
            p.to(p.at(0.74, 0.44))
            p.to(p.at(0.74, 0.94))
            p.close()
            p.line([p.at(0.26, 0.44), p.at(0.74, 0.44)])
            p.line([p.at(0.38, 0.26), p.at(0.38, 0.12), p.at(0.62, 0.12), p.at(0.62, 0.26)])
        },

        // Butter: Block mit einem abgeschnittenen Stück obenauf.
        //
        // Der erste Entwurf hatte ein aufgeschlagenes Papier als Zickzack
        // daneben und war auf dem Prüfbogen ein **Karton mit offenem Deckel**.
        // Das abgeschnittene Stück sagt dasselbe (jemand hat davon genommen)
        // und ist eine Form statt einer Falte.
        "butter": { p in
            p.stroke.addRoundedRect(in: p.box(0.50, 0.68, 0.76, 0.30),
                                    cornerSize: p.corner(0.04))
            p.begin(p.at(0.22, 0.53))
            p.to(p.at(0.34, 0.33))
            p.to(p.at(0.62, 0.33))
            p.to(p.at(0.50, 0.53))
            p.close()
        },

        // Käsedreieck mit zwei Löchern. Das Dreieck ist die Silhouette, die
        // niemand nachfragt — die Löcher sind gefüllt, weil ein Ring von drei
        // Pixeln bei 13 pt ein Punkt ist.
        "käse": { p in
            p.begin(p.at(0.08, 0.84))
            p.to(p.at(0.52, 0.20))
            p.to(p.at(0.92, 0.84))
            p.close()
            p.dot(p.at(0.42, 0.62), 0.062)
            p.dot(p.at(0.62, 0.74), 0.055)
        },

        // Frischkäse: **runde** Dose, von schräg oben — Deckelellipse, kurze
        // Wand, Bodenkante.
        //
        // Der erste Entwurf war ein flacher Becher mit aufgezogener
        // Folienlasche und stand auf dem Prüfbogen als **Eimer mit Stiel** da.
        // Die Lasche war zu klein, um als Folie zu lesen, und zu groß, um
        // nicht aufzufallen. Rund statt kantig trennt ihn ohnehin besser von
        // Quark, Sahne und Margarine, die alle Becher mit geraden Wänden sind.
        "frischkäse": { p in
            p.stroke.addEllipse(in: p.box(0.50, 0.40, 0.68, 0.26))
            p.begin(p.at(0.16, 0.40))
            p.to(p.at(0.16, 0.62))
            p.bow(p.at(0.84, 0.62), p.at(0.16, 0.82), p.at(0.84, 0.82))
            p.to(p.at(0.84, 0.40))
        },

        // Mozzarella: Kugel und eine Scheibe daneben. Die Scheibe ist flach
        // gelegt und damit das, was die Kugel von jeder anderen Kugel des
        // Satzes trennt.
        "mozzarella": { p in
            p.circle(p.at(0.36, 0.54), 0.26)
            p.stroke.addEllipse(in: p.box(0.74, 0.72, 0.40, 0.22))
        },

        // Feta: Block mit **gebröselter Oberkante** und zwei Krümeln daneben.
        //
        // Die Bruchkante saß im ersten Entwurf rechts, und ein Rechteck mit
        // gezackter rechter Kante ist auf dem Prüfbogen ein **Preisschild**.
        // Oben gelesen ist dieselbe Zacke Krümel.
        "feta": { p in
            // Und die Zacke war im zweiten Anlauf zu tief: fünf Spitzen über
            // die ganze Breite ergaben eine **Krone**. Zwei flache Kerben
            // reichen, um „gebrochen" zu sagen.
            p.begin(p.at(0.14, 0.40))
            p.to(p.at(0.32, 0.32))
            p.to(p.at(0.50, 0.40))
            p.to(p.at(0.72, 0.32))
            p.to(p.at(0.72, 0.82))
            p.to(p.at(0.14, 0.82))
            p.close()
            p.dot(p.at(0.86, 0.50), 0.055)
            p.dot(p.at(0.85, 0.74), 0.045)
        },

        // Quark: hoher Becher mit gewölbter Folie. Hoch statt flach, damit er
        // neben dem Frischkäse nicht derselbe Becher ist.
        "quark": { p in
            p.begin(p.at(0.26, 0.34))
            p.to(p.at(0.34, 0.92))
            p.to(p.at(0.66, 0.92))
            p.to(p.at(0.74, 0.34))
            p.begin(p.at(0.20, 0.34))
            p.bow(p.at(0.80, 0.34), p.at(0.28, 0.14), p.at(0.72, 0.14))
            p.close()
        },

        // Joghurt: Becher mit Löffel darin. Der Löffel ist die Auskunft —
        // ohne ihn stünden hier drei gleiche Becher nebeneinander.
        "joghurt": { p in
            p.begin(p.at(0.22, 0.42))
            p.to(p.at(0.30, 0.92))
            p.to(p.at(0.70, 0.92))
            p.to(p.at(0.78, 0.42))
            p.line([p.at(0.16, 0.42), p.at(0.84, 0.42)])
            p.line([p.at(0.56, 0.40), p.at(0.74, 0.14)])
            p.stroke.addEllipse(in: p.box(0.79, 0.11, 0.20, 0.14))
        },

        // Sahne: Becher mit **Sahnetuff** — drei Bögen, die nach oben kleiner
        // werden und in einer Spitze enden.
        //
        // Ein einzelner großer Bogen über dem Becher war der erste Entwurf und
        // auf dem Prüfbogen ein **Eimer mit Deckel**. Ein Tuff ist nicht rund,
        // er ist gestapelt — erst die drei Stufen sagen „aufgeschlagen".
        "sahne": { p in
            p.begin(p.at(0.30, 0.56))
            p.to(p.at(0.36, 0.92))
            p.to(p.at(0.64, 0.92))
            p.to(p.at(0.70, 0.56))
            p.line([p.at(0.24, 0.56), p.at(0.76, 0.56)])
            p.begin(p.at(0.26, 0.54))
            p.bow(p.at(0.74, 0.54), p.at(0.30, 0.34), p.at(0.70, 0.34))
            p.begin(p.at(0.34, 0.40))
            p.bow(p.at(0.66, 0.40), p.at(0.38, 0.22), p.at(0.62, 0.22))
            p.begin(p.at(0.42, 0.27))
            p.bow(p.at(0.58, 0.27), p.at(0.46, 0.08), p.at(0.54, 0.08))
        },

        // Zwei Eier, verschieden groß und versetzt. Eines allein wäre bei
        // 13 pt ein Kreis; zwei sind ein Karton voll.
        "eier": { p in
            p.begin(p.at(0.34, 0.26))
            p.bow(p.at(0.16, 0.60), p.at(0.22, 0.26), p.at(0.16, 0.42))
            p.bow(p.at(0.34, 0.90), p.at(0.16, 0.78), p.at(0.24, 0.90))
            p.bow(p.at(0.52, 0.60), p.at(0.44, 0.90), p.at(0.52, 0.78))
            p.bow(p.at(0.34, 0.26), p.at(0.52, 0.42), p.at(0.46, 0.26))
            p.close()
            p.begin(p.at(0.70, 0.44))
            p.bow(p.at(0.56, 0.70), p.at(0.60, 0.44), p.at(0.56, 0.56))
            p.bow(p.at(0.70, 0.92), p.at(0.56, 0.84), p.at(0.62, 0.92))
            p.bow(p.at(0.84, 0.70), p.at(0.78, 0.92), p.at(0.84, 0.84))
            p.bow(p.at(0.70, 0.44), p.at(0.84, 0.56), p.at(0.80, 0.44))
            p.close()
        },

        // Margarine: breite Wanne mit übergreifendem Deckel. Der Deckelrand
        // steht seitlich über, der Becher daneben hat seinen bündig.
        "margarine": { p in
            p.stroke.addRoundedRect(in: p.box(0.50, 0.66, 0.64, 0.34),
                                    cornerSize: p.corner(0.05))
            p.stroke.addRoundedRect(in: p.box(0.50, 0.42, 0.78, 0.16),
                                    cornerSize: p.corner(0.05))
        },

        // Pudding als **Sturzform**: gewellte Kuppe, Teller darunter. Der
        // einzige Milchartikel ohne Becher — und deshalb der einzige, den man
        // bei 13 pt sofort von den anderen unterscheidet.
        "pudding": { p in
            p.begin(p.at(0.18, 0.76))
            p.bow(p.at(0.50, 0.24), p.at(0.20, 0.42), p.at(0.32, 0.24))
            p.bow(p.at(0.82, 0.76), p.at(0.68, 0.24), p.at(0.80, 0.42))
            p.close()
            p.line([p.at(0.08, 0.86), p.at(0.92, 0.86)])
        },

        // Kondensmilch: die **Tube** mit Schraubverschluss und gefalztem Ende.
        //
        // Als kleine Dose stand sie zwischen der Konservendose und der
        // Limonadendose und war die dritte Dose des Satzes. Kondensmilch gibt
        // es genauso als Tube, und eine Tube hat sonst niemand hier.
        "kondensmilch": { p in
            p.begin(p.at(0.34, 0.36))
            p.to(p.at(0.30, 0.80))
            p.to(p.at(0.70, 0.80))
            p.to(p.at(0.66, 0.36))
            p.close()
            p.line([p.at(0.28, 0.80), p.at(0.72, 0.80)])
            p.line([p.at(0.28, 0.88), p.at(0.72, 0.88)])
            p.line([p.at(0.30, 0.80), p.at(0.28, 0.88)])
            p.line([p.at(0.70, 0.80), p.at(0.72, 0.88)])
            p.stroke.addRect(p.box(0.50, 0.28, 0.26, 0.16))
            p.stroke.addRect(p.box(0.50, 0.14, 0.20, 0.14))
        },

        // Kokosnuss, halbiert: Schale, Fruchtfleischrand, drei Fasern **außen
        // am Boden**.
        //
        // Im ersten Entwurf standen die Fasern oben und strahlten von der
        // Schnittkante weg — auf dem Prüfbogen eine **Schüssel mit
        // Sonnenstrahlen**. Unten am Rund gelesen ist dieselbe Faser Schale.
        "kokosmilch": { p in
            p.begin(p.at(0.10, 0.40))
            p.bow(p.at(0.90, 0.40), p.at(0.12, 0.94), p.at(0.88, 0.94))
            p.close()
            p.begin(p.at(0.22, 0.42))
            p.bow(p.at(0.78, 0.42), p.at(0.24, 0.78), p.at(0.76, 0.78))
            // Und im zweiten Anlauf hingen sie **unter** der Schale und waren
            // Beine. Was von der Faser bleibt, sind drei Punkte im Schalenband
            // — Textur, die nichts anbaut.
            p.dot(p.at(0.28, 0.66), 0.038)
            p.dot(p.at(0.50, 0.83), 0.038)
            p.dot(p.at(0.72, 0.66), 0.038)
        },

        // Brotscheibe mit Kruste: Toastform mit Kuppe, Krustenlinie innen.
        // **Nicht der Laib** — der ist das Kategoriezeichen für Backwaren,
        // und zwei Laibe nebeneinander wären eine Verwechslung.
        "brot": { p in
            // **Zwei Kuppen statt einer.** Der erste Entwurf war eine einzige
            // Kuppe mit einer zweiten Linie darin — auf dem Prüfbogen ein
            // **Türbogen**. Eine Toastscheibe hat oben zwei Ohren und dazwischen
            // eine Senke; genau daran erkennt man sie und nicht am Rechteck.
            p.begin(p.at(0.20, 0.90))
            p.to(p.at(0.20, 0.50))
            p.bow(p.at(0.50, 0.42), p.at(0.20, 0.30), p.at(0.44, 0.30))
            p.bow(p.at(0.80, 0.50), p.at(0.56, 0.30), p.at(0.80, 0.30))
            p.to(p.at(0.80, 0.90))
            p.close()
        },

        // Knäckebrot: rechteckige Scheibe mit zwei Lochreihen.
        "knäckebrot": { p in
            p.stroke.addRoundedRect(in: p.box(0.50, 0.50, 0.62, 0.80),
                                    cornerSize: p.corner(0.05))
            for y in [CGFloat(0.34), 0.50, 0.66] {
                p.dot(p.at(0.40, y), 0.045)
                p.dot(p.at(0.60, y), 0.045)
            }
        },

        // Kuchenstück für die Feinbackwaren: Boden, Sahneschicht, Kirsche.
        // Croissant, Kuchen, Torte, Brezel stehen alle unter diesem Begriff —
        // das Stück Kuchen ist davon das, was auch bei 13 pt eine Silhouette
        // hat.
        "backwaren": { p in
            // **Muffin, drittes Motiv.** Das Tortenstück ist zweimal gescheitert
            // — aufrecht war es ein **Stufenberg mit Fahne**, liegend ein
            // **Verkehrsschild auf einer Rampe** —, und es hatte ohnehin ein
            // Problem: Ein Dreieck ist in diesem Satz schon der Käse. Der
            // Muffin steht wörtlich in der Synonymliste, hat eine Silhouette,
            // die sonst niemand hat, und trägt Kuchen, Torte und Hefezopf
            // genauso gut mit.
            p.begin(p.at(0.24, 0.52))
            p.to(p.at(0.34, 0.90))
            p.to(p.at(0.66, 0.90))
            p.to(p.at(0.76, 0.52))
            p.close()
            p.line([p.at(0.40, 0.54), p.at(0.44, 0.88)])
            p.line([p.at(0.60, 0.54), p.at(0.56, 0.88)])
            p.begin(p.at(0.18, 0.52))
            p.bow(p.at(0.42, 0.20), p.at(0.14, 0.30), p.at(0.26, 0.20))
            p.bow(p.at(0.66, 0.22), p.at(0.54, 0.14), p.at(0.58, 0.14))
            p.bow(p.at(0.82, 0.52), p.at(0.78, 0.24), p.at(0.86, 0.34))
            p.close()
        },

        // Tofu: Block mit einem Blatt darauf.
        //
        // Zwei Rechtecke nebeneinander — Block und abgeschnittener Würfel —
        // waren auf dem Prüfbogen ein **Balkendiagramm**. Unter diesem Begriff
        // stehen ohnehin „vegan", „veggie", „Fleischersatz" und „Falafel“; das
        // Blatt sagt genau das, was den Block von einem Butterstück trennt.
        "tofu": { p in
            p.stroke.addRoundedRect(in: p.box(0.50, 0.70, 0.68, 0.36),
                                    cornerSize: p.corner(0.04))
            p.begin(p.at(0.50, 0.50))
            p.bow(p.at(0.30, 0.18), p.at(0.36, 0.44), p.at(0.28, 0.32))
            p.bow(p.at(0.50, 0.50), p.at(0.50, 0.20), p.at(0.52, 0.36))
            p.close()
            p.line([p.at(0.50, 0.50), p.at(0.72, 0.28)])
        },
    ]
}

// MARK: - Rechnerei für die geneigten Früchte

/// Ein Punkt auf der Längsachse einer geneigten Kapsel, in Einheitsmaßen.
/// `bei` läuft von −0,5 (oberes Ende) bis 0,5 (unteres).
///
/// **Geschätzte Enden waren zweimal falsch.** Eine Kapsel dreht um ihre Mitte;
/// wo ihr oberes Ende landet, hängt am Vorzeichen der Neigung, und das hat man
/// beim Hinschreiben eines Stiels genau einmal richtig im Kopf.
private func achse(mitte: (CGFloat, CGFloat), hoehe: CGFloat, neigung: Double,
                   bei t: CGFloat) -> (CGFloat, CGFloat) {
    let w = neigung * .pi / 180
    return (mitte.0 - t * hoehe * CGFloat(sin(w)), mitte.1 + t * hoehe * CGFloat(cos(w)))
}

/// Ein Strich **quer** über die Kapsel an der Stelle `bei`.
private func quer(_ p: inout Pen, mitte: (CGFloat, CGFloat), hoehe: CGFloat,
                  neigung: Double, bei t: CGFloat, laenge: CGFloat) {
    let w = neigung * .pi / 180
    let (x, y) = achse(mitte: mitte, hoehe: hoehe, neigung: neigung, bei: t)
    let dx = laenge / 2 * CGFloat(cos(w)), dy = laenge / 2 * CGFloat(sin(w))
    p.line([p.at(x - dx, y - dy), p.at(x + dx, y + dy)])
}

/// Eine Hälfte einer Artikelzeichnung als `Shape` — wie `CategoryGlyphShape`,
/// nur mit dem Begriff statt der Kategorie als Schlüssel.
struct ItemGlyphShape: Shape {
    enum Part { case stroke, fill }

    let term: String
    let part: Part

    func path(in rect: CGRect) -> Path {
        // Immer quadratisch und mittig — eine gestreckte Möhre wäre keine.
        let side = min(rect.width, rect.height)
        let square = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2,
                            width: side, height: side)
        guard let drawing = ItemGlyph.drawing(for: term, in: square) else { return Path() }
        return part == .stroke ? drawing.stroke : drawing.fill
    }
}

/// **Das Zeichen einer Kachel, mit seiner Rückfallleiter.**
///
/// Begriffszeichnung → Kategoriezeichen → nichts. Dieselbe Ordnung wie in
/// `OfferImageContent`: Je genauer die Auskunft, desto weiter vorn. Ein
/// Artikel, den das Wörterbuch nicht kennt, bekommt das Zeichen seiner
/// Kategorie; einer ohne Kategorie bekommt keins, statt dass der Einkaufswagen
/// so tut, als wüsste er etwas.
struct ItemGlyphView: View {
    /// Der Wörterbuchbegriff, auf den der Artikeltext abgebildet wurde.
    let term: String?
    /// Die Kategorie seines besten Treffers — der Rückfall.
    let category: String?
    let size: CGFloat

    var body: some View {
        if let term, ItemGlyph.drawing(for: term, in: CGRect(x: 0, y: 0, width: 1, height: 1)) != nil {
            ZStack {
                ItemGlyphShape(term: term, part: .fill)
                ItemGlyphShape(term: term, part: .stroke)
                    .stroke(style: StrokeStyle(lineWidth: size * CategoryGlyph.lineWidthRatio,
                                               lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        } else if let category {
            CategoryGlyphView(category: category, size: size)
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }
}
