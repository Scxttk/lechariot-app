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
///
/// ## Wer eine Fläche bekommt
///
/// **Jeder geschlossene Umriss trägt eine Körperfläche — ohne Ausnahme und
/// ohne Zutun des Rezepts.** `drawing(for:in:)` nimmt dafür den
/// flächengrößten geschlossenen Umriss der Zeichnung. Ein Rezept, das nichts
/// sagt, ist damit trotzdem zweitonig; ein Rezept, das `alsKoerper()` oder
/// `alsSchatten()` ruft, hat die Frage selbst beantwortet und behält recht.
///
/// **Linie bleibt nur, was gar keinen geschlossenen Umriss hat** — der
/// Dampf über der Tasse, gekreuztes Besteck, ein Zweig. Das ist keine
/// Geschmacksentscheidung je Zeichnung, sondern eine Eigenschaft der Form:
/// Ein offener Zug hat keine Innenseite, und ein gedanklich geschlossener
/// legt Fläche dorthin, wo keine ist.
///
/// **Warum als Regel und nicht als Handarbeit:** Zehn Zeichnungen bekamen
/// ihre Fläche am 11./12.08. von Hand, 322 nicht. Ein Satz, in dem die
/// Hälfte Fläche trägt und die andere nicht, liest sich als Versehen — und
/// von Hand nachgezogen wäre er beim nächsten neuen Zeichen wieder
/// uneinheitlich. Die Regel gilt für den **Artikel**satz; der Kategoriesatz
/// steht bei 13 pt und bleibt Monolinie (siehe `CategoryGlyphs.swift`).
///
/// ## Herkunft der Geometrie
///
/// Einzelne Zeichnungen gehen auf **Lucide** (lucide.dev, ISC) zurück, mit
/// `tools/svg2pen.py` in dieses Rezeptformat übersetzt und danach zweitonig
/// umgezogen. Welche das sind, steht namentlich in `NOTICE` — dort steht
/// auch, warum der Hinweis fällig ist. Alle übrigen sind hier gezeichnet;
/// Lucide dient ihnen als Maßstab für Strichdisziplin und Geometrie, nicht
/// als Vorlage.
enum ItemGlyph {

    typealias Rezept = (inout Pen) -> Void

    /// **Der Artikelsatz zieht einen dünneren Strich als der Kategoriesatz.**
    ///
    /// Nicht als Geschmacksfrage, sondern weil die beiden bei verschiedenen
    /// Größen stehen. `CategoryGlyph.lineWidthRatio` (0,095) ist für die
    /// **13 pt** der Abschnittszeile erlaufen — dort ist alles Dünnere unter
    /// einem Gerätepixel. Der Artikelsatz steht im Raster bei **40 pt** und
    /// auf dem Chip bei 22 pt, also beim Drei- bis Zweifachen.
    ///
    /// Bei 0,095 auf 40 pt ist der Strich 3,8 pt breit, und das ist der Grund,
    /// warum jeder Versuch von mehr Zeichnung am 11.08. scheiterte: Zwei
    /// Kanten, die näher als 0,095 beieinander liegen, sind **eine** Kante.
    /// Drei Bananen nebeneinander wurden zu einem Klotz, zwei Möhren zu einem
    /// „W", und die Körnung im Brokkolikopf zu zwei Augen. Nicht die
    /// Zeichnungen waren zu ehrgeizig, sondern der Strich zu breit für sie.
    ///
    /// 0,065 bei 40 pt sind 2,6 pt — immer noch eine kräftige Monolinie, aber
    /// mit Platz zwischen zwei Kanten. Bei 22 pt bleiben 1,4 pt.
    static let lineWidthRatio: CGFloat = 0.065
    static let feinLineWidthRatio: CGFloat = 0.036

    /// **Wie der Artikelsatz gehalten wird.**
    ///
    /// Die Grundbreite liegt unter `lineWidthRatio`, weil die Feder an ihrer
    /// breitesten Stelle so breit ist wie die alte gleichmäßige Linie — und im
    /// Mittel deutlich schmaler. Gemessen am Referenzsatz (OpenMoji, 0,0278;
    /// siehe `docs/ZEICHEN-RECHERCHE.md`) kommt der Satz damit von 2,3-fach
    /// auf etwa 1,5-fach heran, ohne bei 22 pt zu zerfallen.
    /// **Die Feder schwingt verhalten — und 0,15 ist ausprobiert und
    /// verworfen, nicht übersehen.**
    ///
    /// Am 12.08. stand die Frage, warum der Satz trotz eingeschalteter Feder
    /// wie eine Monolinie aussieht. Gemessen (Konturpixel auf einem
    /// Probebogen, `breite` konstant gehalten): Der ganze Weg von der flachen
    /// Linie bis zum Extrem nimmt **nur ein Viertel** der Konturfläche weg —
    /// 1,00 → 100 %, 0,46 → 84 %, 0,28 → 78 %, 0,15 → 75 %. Ein gebogener
    /// Umriss läuft durch jede Richtung und mittelt sich selbst aus.
    ///
    /// Daraufhin lief der Satz eine Runde auf **0,15**, und auf dem Prüfbogen
    /// 90/40/22 hat Scott ihn wieder abgewählt: Bei 90 pt schwoll die Kontur
    /// zwischen 1,5 und 6,5 pt, und das war eine andere Zeichnung — kalligrafisch
    /// statt gezeichnet. **0,46 ist die Anmutung, die bleiben soll**; die Feder
    /// soll dem Strich Leben geben und nicht selbst das Motiv werden.
    ///
    /// **Die Untergrenze aus derselben Runde bleibt trotzdem**, weil sie
    /// unabhängig vom Wert richtig ist: Ein *Verhältnis* schrumpft mit der
    /// Zeichnung mit, eine Grenze in **Punkten** nicht. Sie ist bei 0,46 kein
    /// totes Gewicht, sondern greift dort, wo es klein wird — 90 pt: 2,98 pt
    /// schmalste Stelle, ungeklemmt; 40 pt: 1,32 → **1,50**; 22 pt: 0,73 →
    /// **1,50**. Genau die Größen, bei denen ein dünn auslaufender Strich auf
    /// dem Gerät aufreißt.
    ///
    /// **`breite` bleibt bei 0,072.** Auf dem Prüfbogen sahen 0,085 und 0,095
    /// kräftiger aus, aber 0,095 ist genau der Wert, an dem der Satz am 11.08.
    /// gescheitert ist: Zwei Kanten, die näher beieinander liegen als der
    /// Strich breit ist, sind eine Kante — drei Bananen wurden ein Klotz.
    static let feder = Feder.Profil(breite: 0.072, neigung: -32, schmal: 0.46,
                                    spitze: 0.18, mindest: 1.5)

    /// Die Zeichnung dieses Begriffs, oder `nil` für einen, für den es hier
    /// keine gibt — dann greift das Kategoriezeichen, statt dass ein
    /// erfundenes Bild das Falsche behauptet.
    static func drawing(for term: String, in rect: CGRect) -> CategoryGlyph.Drawing? {
        guard let recipe = recipes[term] else { return nil }
        var pen = Pen(rect: rect)
        recipe(&pen)

        // **Die Regel aus dem Kopf dieser Datei, an genau einer Stelle.**
        // Wer nichts gesagt hat, bekommt seinen größten geschlossenen Umriss
        // als Körperfläche. Wer `alsKoerper()` oder `alsSchatten()` gerufen
        // hat, hat die Frage schon beantwortet und wird nicht überstimmt.
        var koerper = pen.koerper
        if koerper.isEmpty, pen.schatten.isEmpty, let silhouette = pen.groessteGeschlossene {
            koerper = silhouette
        }

        return CategoryGlyph.Drawing(koerper: koerper, schatten: pen.schatten,
                                     fein: pen.fein, stroke: pen.stroke, fill: pen.fill)
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
                     vorratUndGetraenke, tranche1, tranche2, tranche3, tranche4, tranche5, tranche6, tranche7, tranche8, tranche9, tranche10, tranche11] {
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
        //
        // **Die Kerbe war da und man sah sie nicht.** Auf dem Prüfbogen vom
        // 11.08. war dieser Apfel ein **Kreis mit Blatt** — nicht weil die
        // Kerbe fehlte, sondern weil das Blatt quer über ihr lag und genau
        // das zudeckte, was den Apfel vom Kreis unterscheidet. Zwei
        // Änderungen: Die Kerbe geht auf 0,36 herunter, während die Schultern
        // auf 0,14 stehen bleiben, und das Blatt rückt **neben** den Stiel.
        // **Zwei Äpfel, und der hintere ist nur der Teil, den man sieht.**
        //
        // Verdeckte Kanten werden hier von Hand weggelassen, nicht
        // übermalt: Der vordere Körper deckt bei 14 % Deckkraft nichts zu,
        // ein voller hinterer Umriss stünde also mitten durch ihn hindurch.
        // Der hintere Apfel ist deshalb nur der Sichelrest rechts — genau so
        // viel, wie an einem vorderen vorbeiragen würde.
        "äpfel": { p in
            p.begin(p.at(0.63, 0.33))
            p.bow(p.at(0.96, 0.60), p.at(0.84, 0.25), p.at(0.96, 0.42))
            p.bow(p.at(0.66, 0.90), p.at(0.96, 0.79), p.at(0.83, 0.90))
            p.begin(p.at(0.42, 0.34))
            p.bow(p.at(0.07, 0.56), p.at(0.25, 0.13), p.at(0.07, 0.30))
            p.bow(p.at(0.42, 0.95), p.at(0.07, 0.82), p.at(0.24, 0.95))
            p.bow(p.at(0.77, 0.56), p.at(0.60, 0.95), p.at(0.77, 0.82))
            p.bow(p.at(0.42, 0.34), p.at(0.77, 0.30), p.at(0.59, 0.13))
            p.close()
            p.alsKoerper()
            p.begin(p.at(0.43, 0.32))
            p.bow(p.at(0.50, 0.07), p.at(0.45, 0.22), p.at(0.46, 0.13))
            blatt(&p, von: (0.44, 0.19), nach: (0.13, 0.08), bauch: 0.12)
            // Glanz auf dem Bauch — zwei feine Striche, die der Wölbung
            // folgen. Als Konturstärke wären sie eine Narbe.
            p.feinBogen(p.at(0.17, 0.56), p.at(0.24, 0.41),
                        p.at(0.15, 0.49), p.at(0.19, 0.43))
            p.feinBogen(p.at(0.25, 0.62), p.at(0.31, 0.51),
                        p.at(0.24, 0.57), p.at(0.27, 0.52))
        },

        // Banane: Außenbogen, Innenbogen, Stiel links — und die **Blüte** am
        // rechten Ende. Der Stiel unterscheidet die Sichel vom Mond; die
        // Spitze am anderen Ende macht aus der Sichel eine Frucht mit zwei
        // Enden, statt einer, die einfach aufhört.
        //
        // Im Körper selbst steht bewusst keine Kante: Die Sichel ist an ihrer
        // dicksten Stelle 0,18 stark, eine Linie darin hätte beidseitig 0,09
        // Luft und liefe bei 40 pt mit beiden Rändern zusammen.
        //
        // **Etwas dicker als zuvor**, seit die Sichel eine Fläche trägt: Bei
        // 0,18 Bauchstärke blieben nach dem Strich 0,085 Fläche übrig, und
        // eine Fläche von 3,4 pt bei 40 pt Zeichen ist keine. Jetzt 0,24.
        // **Eine Hand, keine einzelne Frucht.** Bananen liegen im Laden zu
        // dritt am Stiel, und drei Sicheln übereinander sind das, was eine
        // einzelne Sichel nie war: unverwechselbar. Die hinteren beiden sind
        // nur Bögen — verdeckte Kanten fallen weg (siehe `äpfel`).
        "bananen": { p in
            // **Eine Hand, keine einzelne Frucht** — drei Sicheln am selben
            // Stielansatz. Die hinteren beiden standen im ersten Anlauf 0,06
            // hinter der vorderen und verschmolzen mit ihr zu einem Klotz;
            // bei 0,065 Strichstaerke braucht es mindestens 0,10 Abstand,
            // damit zwei Kanten zwei bleiben.
            p.begin(p.at(0.20, 0.18))
            p.bow(p.at(0.95, 0.26), p.at(0.24, 0.74), p.at(0.84, 0.70))
            p.begin(p.at(0.16, 0.30))
            p.bow(p.at(0.93, 0.38), p.at(0.20, 0.88), p.at(0.82, 0.84))
            // Die vordere Banane, geschlossen: sie traegt die Flaeche.
            p.begin(p.at(0.12, 0.44))
            p.bow(p.at(0.90, 0.52), p.at(0.17, 0.99), p.at(0.78, 0.95))
            p.bow(p.at(0.12, 0.44), p.at(0.68, 0.74), p.at(0.25, 0.66))
            p.close()
            p.alsKoerper()
            // Der gemeinsame Stielansatz links, die Bluete rechts.
            p.line([p.at(0.15, 0.24), p.at(0.08, 0.10)])
            p.line([p.at(0.90, 0.52), p.at(0.96, 0.44)])
        },

        // Zitrone: bauchiges Oval, schräg gelegt, mit einem Zipfel an **beiden**
        // Enden. Der erste Entwurf war schlanker und hatte nur einen Zipfel —
        // auf dem Prüfbogen ein **Blatt**. Die Zipfel sind es, die aus einer
        // Linsenform eine Zitrone machen.
        // **Bauchig statt linsenförmig, mit Zipfel und Blatt.**
        //
        // Der schlanke, an beiden Enden spitze Körper war auf dem Prüfbogen ein
        // **Blatt** — und zwar hartnäckig, auch nachdem die Zipfel dazukamen:
        // Eine Form, die doppelt so breit wie hoch ist und beidseitig ausläuft,
        // ist die Silhouette eines Blattes, egal was man ihr anhängt.
        //
        // Der Körper ist deshalb rundlich (0,74 × 0,60) und der Zipfel sitzt nur
        // noch **rechts**; links sitzt stattdessen das Blatt. Damit ist die
        // Zitrone unsymmetrisch, und das trennt sie zugleich vom Apfel, der
        // höher als breit ist und seine Kerbe oben trägt.
        //
        // **Zipfel an beiden Enden, seit der Körper eine Fläche hat.** Mit dem
        // warmen Ton war der rundliche Körper auf dem Prüfbogen vom 11.08. die
        // **Orange** von nebenan — ein gefüllter runder Körper verliert die
        // kleine Unsymmetrie, an der man ihn vorher noch erkannte. Der zweite
        // Zipfel links kostet nichts und ist das, was keine Orange hat.
        "zitronen": { p in
            // **Ganze Frucht hinten links, halbe Scheibe vorn rechts.**
            //
            // Der erste Anlauf legte die Haelfte als Halbkreis nach unten und
            // die ganze Frucht als Sichel dahinter — auf dem Pruefbogen war
            // das eine **Erbsenschote mit Faecher**. Eine Haelfte, die auf
            // ihrer flachen Seite steht, liest sich nicht als Schnittflaeche,
            // sondern als Huelle. Die Scheibe ist deshalb ein **voller
            // Kreis** mit Segmenten: So sieht ein Querschnitt aus.
            p.begin(p.at(0.34, 0.30))
            p.bow(p.at(0.10, 0.54), p.at(0.20, 0.28), p.at(0.10, 0.38))
            p.bow(p.at(0.36, 0.82), p.at(0.10, 0.70), p.at(0.22, 0.82))
            p.bow(p.at(0.58, 0.56), p.at(0.50, 0.82), p.at(0.58, 0.72))
            p.bow(p.at(0.34, 0.30), p.at(0.58, 0.40), p.at(0.48, 0.30))
            p.close()
            p.alsSchatten()
            p.line([p.at(0.34, 0.30), p.at(0.31, 0.22)])
            p.line([p.at(0.36, 0.82), p.at(0.38, 0.90)])
            // Die Scheibe vorn: Schale, Fruchtfleisch, acht Segmente.
            p.circle(p.at(0.66, 0.58), 0.30)
            p.alsKoerper()
            p.feinKreis(p.at(0.66, 0.58), 0.235)
            for i in 0..<8 {
                let w = CGFloat(i) * .pi / 4.0
                p.feinLinie([p.at(0.66 + cos(w) * 0.03, 0.58 + sin(w) * 0.03),
                             p.at(0.66 + cos(w) * 0.215, 0.58 + sin(w) * 0.215)])
            }
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
        // Tomate: runder Körper, Kelch als Doppelstrich, Stiel — und ein
        // **Glanzbogen** oben links. Drei Kelchstriche liefen bei 13 pt zu;
        // zwei lassen die Kuppe stehen, und das gilt bei 22 pt weiter.
        //
        // Der Glanzbogen ist der Zuwachs und liegt 0,13 innerhalb der Kreislinie
        // — enger und er verschmilzt bei 40 pt mit ihr zu einer doppelt so
        // dicken Kante.
        // **Der Kelch statt des Glanzlichts.**
        //
        // Im Bauch stand ein einzelner kurzer Bogen als Glanzlicht. Er hatte
        // weder oben noch unten Anschluss und war auf dem Prüfbogen vom
        // 11.08. schlicht ein **Kratzer** in der Frucht — Glanz braucht eine
        // Fläche, auf der er liegen kann, und die gab es hier nicht.
        //
        // Was die Tomate stattdessen braucht, sitzt oben: Aus dem zweizipfligen
        // V ist ein **vierblättriger Kelch** geworden. Zwei Zipfel über einem
        // Kreis sind ein Vogel über einem Ball.
        //
        // **Und sie liegt breit.** Mit dem Ton kam ein Nachbar dazu, den es
        // vorher nicht gab: Der Apfel ist seit heute ebenfalls rot, und ein
        // roter Kreis mit Grün obendrauf ist beides. Getrennt werden sie an
        // der Silhouette, wie immer in diesem Satz — der Apfel steht **hoch**
        // und hat seine Kerbe, die Tomate **liegt** (0,68 × 0,60).
        "tomaten": { p in
            // Die kleinere Tomate hinten rechts, nur der sichtbare Rest.
            p.begin(p.at(0.66, 0.44))
            p.bow(p.at(0.95, 0.66), p.at(0.86, 0.40), p.at(0.95, 0.52))
            p.bow(p.at(0.70, 0.88), p.at(0.95, 0.80), p.at(0.84, 0.88))
            // Die vordere: liegt breit, damit sie nicht der Apfel ist.
            p.oval(0.42, 0.64, 0.68, 0.60)
            p.alsKoerper()
            // Vierblaettriger Kelch. Zwei Zipfel ueber einem Rund waren ein
            // Vogel ueber einem Ball.
            p.line([p.at(0.16, 0.28), p.at(0.42, 0.38), p.at(0.68, 0.28)])
            p.line([p.at(0.28, 0.20), p.at(0.42, 0.38), p.at(0.56, 0.20)])
            p.line([p.at(0.42, 0.38), p.at(0.42, 0.10)])
            // Wangenfalte und Glanz.
            p.feinBogen(p.at(0.16, 0.66), p.at(0.22, 0.52),
                        p.at(0.15, 0.59), p.at(0.18, 0.54))
            p.feinBogen(p.at(0.42, 0.90), p.at(0.62, 0.82),
                        p.at(0.52, 0.91), p.at(0.60, 0.88))
        },

        // Gurke: gerader Körper, nach links geneigt, mit drei Querkerben. Die
        // Kerben und die **Neigungsrichtung** sind der ganze Unterschied zur
        // Zucchini, die nach rechts liegt.
        // Gerader Körper, nach links geneigt, mit **vier Noppen** im Zickzack.
        //
        // Zwei Anläufe, zwei verschiedene Lebensmittel:
        //
        // 1. Drei **Querkerben** — neben `brot` auf dem Bogen ein **Baguette**.
        //    Quer eingeschnitten wird Brot, nicht Gemüse.
        // 2. Eine durchgehende **Längsrippe** — eine Kapsel mit einem Schlitz
        //    darin, also ein Brötchen mit Einschnitt. Eine Linie, die mittig
        //    fast über die ganze Länge läuft, teilt den Körper, statt ihn zu
        //    strukturieren.
        //
        // Die Noppen tun beides nicht: Sie sitzen abwechselnd links und rechts
        // der Achse, berühren keine Kante und teilen nichts. Warzig ist die
        // Eigenschaft, die eine Gurke von jedem Laib und jeder Zucchini
        // unterscheidet.
        "gurke": { p in
            p.capsule(0.50, 0.50, 0.32, 0.86, tilt: -32)
            let w = -32.0 * .pi / 180
            for (i, t) in [CGFloat(-0.24), -0.08, 0.08, 0.24].enumerated() {
                let (x, y) = achse(mitte: (0.50, 0.50), hoehe: 0.86, neigung: -32, bei: t)
                let seite: CGFloat = i % 2 == 0 ? 0.06 : -0.06
                p.dot(p.at(x + seite * CGFloat(cos(w)), y + seite * CGFloat(sin(w))), 0.032)
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

        // Salat: **eine Schüssel mit Blättern darin**, nicht mehr ein Büschel.
        //
        // Fünfter Anlauf. Die vier davor drehten sich um die Frage, wie man
        // *die Pflanze* zeichnet — runder Kopf (dreimal falsch gelesen: Apfel,
        // Kürbis, Gesicht), dann drei auffächernde Blätter. Der Büschel war
        // sauber gezeichnet und trotzdem unbrauchbar: Auf dem Prüfbogen vom
        // 12.08. las er sich bei 40 pt als **Schilf**, bei 22 pt als drei
        // Striche. Scott, ebenfalls 12.08.: „the current salat glyph is bad."
        //
        // **Der Fehler war die Wahl des Gegenstands, nicht die Zeichnung.**
        // Ein Blattbüschel ohne Gefäß hat keine Silhouette, an der man es
        // festhält — jede Blattform ist bei 22 pt ein Strich. Die Schüssel
        // hat eine, und sie ist außerdem das, was „Salat" auf einer
        // Einkaufsliste meint. Dieselbe Lehre wie beim Ei: Der **Karton**
        // trägt die Zeichnung, nicht das einzelne Stück.
        //
        // Geometrie der Schale aus Lucide `salad` (ISC, siehe `NOTICE`),
        // übersetzt mit `tools/svg2pen.py`. Die Blätter sind eigene Hand:
        // Lucides Blattwerk ist ein Geflecht aus fünf Bögen und bei 22 pt ein
        // Fleck — hier stehen zwei Lappen mit einer Lücke dazwischen, weil
        // zwei Kanten näher als 0,065 eine Kante sind.
        "salat": { p in
            // Die Schale. Sie trägt die Fläche — größter geschlossener Umriss.
            p.begin(p.at(0.500, 0.875))
            p.bow(p.at(0.635, 0.850), p.at(0.545, 0.875), p.at(0.593, 0.866))
            p.bow(p.at(0.751, 0.778), p.at(0.677, 0.834), p.at(0.718, 0.808))
            p.bow(p.at(0.835, 0.670), p.at(0.785, 0.748), p.at(0.814, 0.710))
            p.bow(p.at(0.873, 0.538), p.at(0.855, 0.629), p.at(0.883, 0.566))
            p.bow(p.at(0.500, 0.500), p.at(0.863, 0.505), p.at(0.680, 0.497))
            p.bow(p.at(0.127, 0.538), p.at(0.320, 0.497), p.at(0.137, 0.505))
            p.bow(p.at(0.165, 0.670), p.at(0.117, 0.566), p.at(0.145, 0.629))
            p.bow(p.at(0.249, 0.778), p.at(0.186, 0.710), p.at(0.215, 0.748))
            p.bow(p.at(0.365, 0.850), p.at(0.282, 0.808), p.at(0.323, 0.834))
            p.bow(p.at(0.500, 0.875), p.at(0.407, 0.866), p.at(0.455, 0.875))
            p.close()
            // Der Standfuß — ohne ihn schwebt die Schale.
            p.line([p.at(0.30, 0.93), p.at(0.70, 0.93)])
            // **Zwei Blätter mit Spitze, nicht zwei Lappen.** Der erste Anlauf
            // hatte zwei rundliche Kuppen über dem Rand, und auf dem Prüfbogen
            // standen sie zwei Zellen neben `eier` — es waren dieselbe Form.
            // Ein rundes Ding in einer Schale ist ein Ei, ein Knödel oder eine
            // Kugel Eis; erst die auslaufende Spitze und die Mittelrippe machen
            // daraus ein Blatt. Beide sitzen mit dem Fuß **hinter** dem Rand,
            // damit sie in der Schale liegen und nicht darauf.
            p.begin(p.at(0.30, 0.52))
            p.bow(p.at(0.25, 0.16), p.at(0.20, 0.42), p.at(0.19, 0.26))
            p.bow(p.at(0.50, 0.52), p.at(0.38, 0.22), p.at(0.47, 0.36))
            p.close()
            p.feinBogen(p.at(0.28, 0.50), p.at(0.26, 0.22),
                        p.at(0.28, 0.40), p.at(0.27, 0.30))
            p.begin(p.at(0.55, 0.52))
            p.bow(p.at(0.79, 0.25), p.at(0.60, 0.36), p.at(0.71, 0.26))
            p.bow(p.at(0.72, 0.52), p.at(0.82, 0.36), p.at(0.79, 0.45))
            p.close()
            p.feinBogen(p.at(0.62, 0.50), p.at(0.76, 0.30),
                        p.at(0.66, 0.43), p.at(0.72, 0.35))
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
            // Zwei Moehren, die hintere schmaler und weit genug zur Seite:
            // Standen ihre Innenkanten 0,04 auseinander, waren die beiden
            // Wurzeln ein „W".
            //
            // **Bauchige Flanken statt gerader.** Als Dreieck aus drei
            // Strecken war die Moehre ein Pfeil — und drei Pfeile im Raster
            // sind eine Navigation. Eine Wurzel ist an der Schulter breit,
            // verjuengt sich ungleichmaessig und laeuft stumpf aus.
            p.begin(p.at(0.60, 0.40))
            p.bow(p.at(0.79, 0.84), p.at(0.66, 0.60), p.at(0.74, 0.74))
            p.bow(p.at(0.90, 0.40), p.at(0.86, 0.72), p.at(0.90, 0.56))
            p.bow(p.at(0.60, 0.40), p.at(0.83, 0.35), p.at(0.68, 0.35))
            p.close()
            p.alsSchatten()
            p.line([p.at(0.76, 0.40), p.at(0.70, 0.19)])
            p.line([p.at(0.76, 0.40), p.at(0.87, 0.17)])
            // Die vordere Moehre.
            p.begin(p.at(0.09, 0.38))
            p.bow(p.at(0.31, 0.93), p.at(0.16, 0.60), p.at(0.25, 0.80))
            p.bow(p.at(0.49, 0.38), p.at(0.41, 0.78), p.at(0.48, 0.58))
            p.bow(p.at(0.09, 0.38), p.at(0.40, 0.32), p.at(0.19, 0.32))
            p.close()
            p.alsKoerper()
            p.line([p.at(0.29, 0.38), p.at(0.11, 0.13)])
            p.line([p.at(0.29, 0.38), p.at(0.31, 0.05)])
            p.line([p.at(0.29, 0.38), p.at(0.51, 0.11)])
            p.feinLinie([p.at(0.16, 0.52), p.at(0.26, 0.49)])
            p.feinLinie([p.at(0.21, 0.66), p.at(0.31, 0.63)])
            p.feinLinie([p.at(0.25, 0.79), p.at(0.33, 0.76)])
        },

        // Brokkoli: wolkiger Kopf, zwei Stielstriche, Schnittkante.
        // **Drei Röschen statt einer Kuppe.**
        //
        // Auf dem Prüfbogen vom 11.08. war das hier der **Pilz** — und der
        // steht in diesem Satz zwei Zellen weiter. Die Oberkante hatte zwar
        // schon drei Bögen, aber ihre Kontrollpunkte lagen so flach, dass
        // zwischen den Röschen keine Bucht entstand: Was blieb, war eine
        // glatte Kuppe auf einem Stiel, und das ist die Silhouette eines
        // Pilzes, egal wie viele Bögen sie gekostet hat.
        //
        // Jetzt greifen die Kontrollpunkte über die Endpunkte hinaus (0,10
        // gegen 0,26), und **zwischen** den Röschen laufen zwei kurze Fugen
        // in den Kopf hinein. Erst die Fugen machen aus der gebuchteten
        // Oberkante einen Kopf aus Teilen.
        "brokkoli": { p in
            // **Nach Lucide, in unserem Stil.**
            //
            // Zehn eigene Anlaeufe standen hier vorher, und jeder war eine
            // andere Fehllesung (Pilz, Gesicht, Croissant, Broetchen). Die
            // Form kommt deshalb aus Lucide (ISC) und ist mit
            // `tools/svg2pen.py` in Rezeptzeilen uebersetzt — Bogenbefehle
            // und relative Koordinaten inklusive, von Hand waere das eine
            // Fehlerquelle ohne Gegenwert.
            //
            // **Umgezogen, nicht uebernommen:** Kopf und Strunk bekommen die
            // Koerperflaeche des Satzes, die beiden Haken wandern in die
            // duenne Innenzeichnung, und die Kontur zieht die Feder. Das
            // Original ist eine gleichmaessige Haarlinie ohne Flaeche.
            //
            // **Die Lizenz verlangt den Hinweis**, auch fuer die umgezogene
            // Fassung: siehe `NOTICE` im Wurzelverzeichnis. Nicht der Stil
            // entscheidet darueber, sondern dass die Geometrie aus ihrer
            // Datei stammt.
            p.begin(p.at(0.297, 0.454))
            p.bow(p.at(0.244, 0.432), p.at(0.246, 0.406), p.at(0.260, 0.442))
            p.bow(p.at(0.201, 0.392), p.at(0.227, 0.422), p.at(0.212, 0.408))
            p.bow(p.at(0.174, 0.340), p.at(0.189, 0.377), p.at(0.180, 0.359))
            p.bow(p.at(0.167, 0.282), p.at(0.169, 0.322), p.at(0.166, 0.301))
            p.bow(p.at(0.181, 0.225), p.at(0.168, 0.263), p.at(0.173, 0.243))
            p.bow(p.at(0.213, 0.177), p.at(0.188, 0.208), p.at(0.200, 0.191))
            p.bow(p.at(0.260, 0.142), p.at(0.226, 0.163), p.at(0.243, 0.151))
            p.bow(p.at(0.316, 0.126), p.at(0.277, 0.134), p.at(0.297, 0.128))
            p.bow(p.at(0.374, 0.130), p.at(0.335, 0.124), p.at(0.356, 0.129))
            p.bow(p.at(0.424, 0.132), p.at(0.392, 0.131), p.at(0.408, 0.137))
            p.bow(p.at(0.472, 0.098), p.at(0.441, 0.126), p.at(0.455, 0.106))
            p.bow(p.at(0.529, 0.084), p.at(0.490, 0.090), p.at(0.510, 0.085))
            p.bow(p.at(0.587, 0.090), p.at(0.548, 0.082), p.at(0.569, 0.084))
            p.bow(p.at(0.640, 0.115), p.at(0.606, 0.095), p.at(0.624, 0.104))
            p.bow(p.at(0.680, 0.157), p.at(0.655, 0.126), p.at(0.667, 0.148))
            p.bow(p.at(0.717, 0.173), p.at(0.693, 0.167), p.at(0.702, 0.171))
            p.bow(p.at(0.775, 0.170), p.at(0.733, 0.176), p.at(0.758, 0.165))
            p.bow(p.at(0.820, 0.205), p.at(0.792, 0.176), p.at(0.811, 0.190))
            p.bow(p.at(0.833, 0.262), p.at(0.830, 0.221), p.at(0.832, 0.244))
            p.bow(p.at(0.824, 0.309), p.at(0.833, 0.279), p.at(0.817, 0.295))
            p.bow(p.at(0.871, 0.343), p.at(0.830, 0.322), p.at(0.857, 0.330))
            p.bow(p.at(0.903, 0.392), p.at(0.884, 0.357), p.at(0.895, 0.375))
            p.bow(p.at(0.916, 0.449), p.at(0.911, 0.410), p.at(0.915, 0.430))
            p.bow(p.at(0.909, 0.507), p.at(0.917, 0.468), p.at(0.915, 0.489))
            p.bow(p.at(0.883, 0.559), p.at(0.904, 0.525), p.at(0.891, 0.543))
            p.bow(p.at(0.863, 0.605), p.at(0.875, 0.575), p.at(0.864, 0.588))
            p.bow(p.at(0.875, 0.662), p.at(0.862, 0.622), p.at(0.874, 0.643))
            p.bow(p.at(0.866, 0.720), p.at(0.875, 0.681), p.at(0.872, 0.701))
            p.bow(p.at(0.838, 0.771), p.at(0.860, 0.738), p.at(0.850, 0.756))
            p.bow(p.at(0.794, 0.809), p.at(0.826, 0.786), p.at(0.811, 0.799))
            p.bow(p.at(0.740, 0.830), p.at(0.778, 0.819), p.at(0.759, 0.827))
            p.bow(p.at(0.682, 0.831), p.at(0.721, 0.834), p.at(0.700, 0.834))
            p.bow(p.at(0.626, 0.812), p.at(0.663, 0.828), p.at(0.643, 0.821))
            p.bow(p.at(0.581, 0.775), p.at(0.610, 0.802), p.at(0.594, 0.789))
            p.bow(p.at(0.552, 0.724), p.at(0.569, 0.760), p.at(0.599, 0.778))
            p.alsKoerper()
            p.begin(p.at(0.650, 0.592))
            p.bow(p.at(0.597, 0.618), p.at(0.703, 0.605), p.at(0.614, 0.609))
            p.bow(p.at(0.547, 0.650), p.at(0.580, 0.628), p.at(0.563, 0.639))
            p.bow(p.at(0.500, 0.687), p.at(0.531, 0.662), p.at(0.515, 0.674))
            p.bow(p.at(0.455, 0.726), p.at(0.485, 0.699), p.at(0.470, 0.713))
            p.bow(p.at(0.413, 0.768), p.at(0.441, 0.740), p.at(0.427, 0.754))
            p.bow(p.at(0.371, 0.810), p.at(0.399, 0.782), p.at(0.385, 0.796))
            p.bow(p.at(0.330, 0.853), p.at(0.357, 0.824), p.at(0.344, 0.839))
            p.bow(p.at(0.288, 0.896), p.at(0.316, 0.867), p.at(0.304, 0.885))
            p.bow(p.at(0.236, 0.916), p.at(0.273, 0.906), p.at(0.254, 0.916))
            p.bow(p.at(0.180, 0.898), p.at(0.218, 0.916), p.at(0.197, 0.907))
            p.bow(p.at(0.133, 0.862), p.at(0.162, 0.889), p.at(0.146, 0.876))
            p.bow(p.at(0.099, 0.813), p.at(0.119, 0.848), p.at(0.107, 0.831))
            p.bow(p.at(0.083, 0.756), p.at(0.090, 0.796), p.at(0.082, 0.774))
            p.bow(p.at(0.110, 0.706), p.at(0.085, 0.738), p.at(0.099, 0.721))
            p.bow(p.at(0.153, 0.665), p.at(0.122, 0.691), p.at(0.139, 0.678))
            p.bow(p.at(0.196, 0.623), p.at(0.167, 0.651), p.at(0.181, 0.637))
            p.bow(p.at(0.238, 0.582), p.at(0.210, 0.609), p.at(0.224, 0.596))
            p.bow(p.at(0.279, 0.539), p.at(0.252, 0.567), p.at(0.211, 0.537))
            p.alsKoerper()
            p.feinBogen(p.at(0.417, 0.542), p.at(0.380, 0.536), p.at(0.429, 0.571), p.at(0.392, 0.540))
            p.feinBogen(p.at(0.380, 0.536), p.at(0.347, 0.521), p.at(0.369, 0.533), p.at(0.357, 0.527))
            p.feinBogen(p.at(0.347, 0.521), p.at(0.320, 0.496), p.at(0.337, 0.514), p.at(0.328, 0.505))
            p.feinBogen(p.at(0.320, 0.496), p.at(0.301, 0.464), p.at(0.312, 0.487), p.at(0.306, 0.476))
            p.feinBogen(p.at(0.301, 0.464), p.at(0.292, 0.429), p.at(0.297, 0.453), p.at(0.293, 0.441))
            p.feinBogen(p.at(0.292, 0.429), p.at(0.294, 0.392), p.at(0.291, 0.417), p.at(0.292, 0.404))
            p.feinBogen(p.at(0.294, 0.392), p.at(0.306, 0.358), p.at(0.296, 0.380), p.at(0.286, 0.333))
            p.feinBogen(p.at(0.691, 0.614), p.at(0.668, 0.603), p.at(0.704, 0.634), p.at(0.675, 0.607))
            p.feinBogen(p.at(0.668, 0.603), p.at(0.647, 0.589), p.at(0.661, 0.599), p.at(0.654, 0.595))
            p.feinBogen(p.at(0.647, 0.589), p.at(0.628, 0.572), p.at(0.640, 0.584), p.at(0.634, 0.578))
            p.feinBogen(p.at(0.628, 0.572), p.at(0.613, 0.553), p.at(0.623, 0.566), p.at(0.617, 0.560))
            p.feinBogen(p.at(0.613, 0.553), p.at(0.600, 0.531), p.at(0.608, 0.546), p.at(0.604, 0.539))
            p.feinBogen(p.at(0.600, 0.531), p.at(0.591, 0.508), p.at(0.596, 0.524), p.at(0.593, 0.516))
            p.feinBogen(p.at(0.591, 0.508), p.at(0.585, 0.483), p.at(0.588, 0.500), p.at(0.569, 0.466))
        },

        // Pilz: Hut als Halbkreis, Stiel mit rundem Fuß.
        // Hut, Stiel — und **drei Tupfen auf dem Hut**.
        //
        // Der glatte Hut war eine Kuppe auf einem Sockel und damit dieselbe
        // Figur wie ein Türbogen oder ein Grabstein. Tupfen sagen „Pilz" ohne
        // ein zweites Bauteil; Lamellen unter dem Hut wären das naheliegendere
        // Detail gewesen, brauchen aber sechs Striche auf 0,08 Abstand — bei
        // 40 pt ein schwarzer Balken.
        "pilze": { p in
            p.begin(p.at(0.10, 0.48))
            p.bow(p.at(0.90, 0.48), p.at(0.12, 0.08), p.at(0.88, 0.08))
            p.close()
            p.begin(p.at(0.36, 0.48))
            p.to(p.at(0.36, 0.82))
            p.bow(p.at(0.64, 0.82), p.at(0.36, 0.94), p.at(0.64, 0.94))
            p.to(p.at(0.64, 0.48))
            p.dot(p.at(0.32, 0.30), 0.050)
            p.dot(p.at(0.54, 0.26), 0.050)
            p.dot(p.at(0.69, 0.32), 0.045)
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

        // Reisschale: Schale, Fuß, gehäufter Reis, zwei Stäbchen.
        //
        // **Einzelne Körner sind zweimal gescheitert, und beide Male an
        // derselben Stelle: an dem, was über dem Schalenrand steht.** Groß und
        // waagerecht waren sie Früchte, also die Obstschale von nebenan; klein
        // und schräg auf einem Häufchen wurden sie zu Zehen und die Schale zum
        // Napf. Der Prüfbogen zeigte beides nebeneinander.
        //
        // Ein Haufen ist keine Zählung von Körnern, und bei 13 pt ist er
        // ohnehin das Einzige, was von ihnen übrig bliebe. Was die Schale
        // festlegt, sind die **Stäbchen** — sie sind im ganzen Satz einmalig,
        // und sie überleben als zwei Striche bis in die kleinste Fassung.
        "reis": { p in
            p.begin(p.at(0.12, 0.52))
            p.bow(p.at(0.88, 0.52), p.at(0.16, 0.92), p.at(0.84, 0.92))
            p.close()
            p.line([p.at(0.36, 0.94), p.at(0.64, 0.94)])
            p.begin(p.at(0.22, 0.52))
            p.bow(p.at(0.78, 0.52), p.at(0.30, 0.24), p.at(0.70, 0.24))
            p.line([p.at(0.60, 0.06), p.at(0.42, 0.40)])
            p.line([p.at(0.74, 0.12), p.at(0.54, 0.44)])
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
        // **Ein Würfel mit drei sichtbaren Flächen** statt zweier flacher
        // Quadrate.
        //
        // Zwei überlappende Rechtecke waren die sparsamste Art, „Würfelzucker"
        // zu sagen, und zugleich die abstrakteste im ganzen Satz: Auf dem
        // Prüfbogen standen dort zwei Karteikarten. Ein Würfel ist erst ein
        // Würfel, wenn man ihm ansieht, dass er drei Dimensionen hat — die
        // Deckfläche und die Seitenfläche sind der ganze Unterschied.
        //
        // Die Tiefe ist mit 0,16 × 0,14 angesetzt: knapp über den 0,13, unter
        // denen zwei Kanten bei 40 pt eine werden.
        //
        // **Und daneben liegen drei Körner — die sind kein Schmuck.** Der
        // Würfel allein war fertig gezeichnet, bis ein breiterer Prüfbogen
        // `hefe` daneben stellte: ebenfalls ein Würfel in derselben Achse, nur
        // mit einer Bande quer. Bei 22 pt waren die beiden nicht mehr
        // auseinanderzuhalten, und `eiswürfel` ist gleich zweimal derselbe
        // Körper. Drei Würfel im Satz, und der neue war der dritte.
        //
        // Die Körner sind das, was nur Zucker hat: Hefe bröselt nicht, Eis
        // schmilzt. Sie liegen weit genug ab (0,12 Luft zur nächsten Kante),
        // um bei 40 pt nicht an den Körper anzuwachsen.
        "zucker": { p in
            p.line([p.at(0.10, 0.44), p.at(0.48, 0.44),
                    p.at(0.48, 0.80), p.at(0.10, 0.80)], closed: true)
            p.line([p.at(0.10, 0.44), p.at(0.26, 0.30),
                    p.at(0.64, 0.30), p.at(0.48, 0.44)])
            p.line([p.at(0.64, 0.30), p.at(0.64, 0.66), p.at(0.48, 0.80)])
            p.dot(p.at(0.76, 0.84), 0.045)
            p.dot(p.at(0.88, 0.88), 0.038)
            p.dot(p.at(0.82, 0.72), 0.034)
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

        // Kaffee: **eine** Bohne, aufrecht, mit geschwungener Naht. Eine Tasse
        // hätte hier neben Tee und Kakao gestanden und wäre die dritte gewesen.
        "kaffee": { p in
            // **Eine statt zwei — und der Grund steht zwei Zeilen weiter unten
            // im selben Satz.** Zwei versetzte Ovale mit einem Strich darin
            // sind `nüsse`; auf dem Prüfbogen nebeneinander waren die beiden
            // Zeichen kaum zu unterscheiden, bei 13 pt gar nicht. Eine einzelne
            // aufrechte Bohne kollidiert mit nichts, und die Naht hat in der
            // vollen Kachel Platz für ihren Schwung — sie macht die Bohne, nicht
            // die Form.
            p.oval(0.50, 0.50, 0.46, 0.72)
            p.begin(p.at(0.50, 0.16))
            p.bow(p.at(0.50, 0.84), p.at(0.30, 0.36), p.at(0.70, 0.64))
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
        // Tasse, Henkel — und der **Teebeutel an Schnur und Etikett**.
        //
        // Vorher hing hier ein Fähnchen *über* dem Tassenrand und ein zweiter
        // Strich lief links heraus; auf dem Prüfbogen war das eine **Kanne mit
        // Ausguss**. Das Etikett gehört an das andere Ende der Schnur, außerhalb
        // der Tasse: Genau daran erkennt man einen Teebeutel, und genau das
        // trennt die Tasse von jeder Kaffeetasse.
        "tee": { p in
            p.begin(p.at(0.20, 0.48))
            p.to(p.at(0.24, 0.78))
            p.bow(p.at(0.64, 0.78), p.at(0.28, 0.92), p.at(0.60, 0.92))
            p.to(p.at(0.68, 0.48))
            p.close()
            p.begin(p.at(0.68, 0.54))
            p.bow(p.at(0.68, 0.72), p.at(0.88, 0.54), p.at(0.88, 0.72))
            // Schnur und Etikett gehen **schräg zur Seite**, nicht senkrecht
            // nach oben. Mittig über der Tasse war das Etikett ein Fähnchen auf
            // einem Mast — bei 22 pt ein Lolli. Ein Teebeutel hängt über den
            // Rand, seine Schnur läuft schief.
            p.line([p.at(0.30, 0.48), p.at(0.20, 0.30)])
            p.rechteck(0.16, 0.20, 0.20, 0.15, ecke: 0.03)
        },

        // Wasser: Glas mit Wasserspiegel und zwei Blasen.
        //
        // **Der Begriff heißt `wasser`, `mineralwasser` und `sprudel`** — und
        // der Tropfen, der hier vorher stand, sagte nur das erste. Er war
        // sauber gezeichnet und bei 13 pt tadellos; er sagte bloß nichts über
        // das, was jemand tatsächlich in den Wagen legt.
        //
        // **Die Blasen sind gefüllt, nicht gestrichen** — genau wie beim Bier,
        // und aus demselben Grund: Ein Ring von 0,05 Radius ist bei 13 pt ein
        // grauer Fleck, ein Punkt bleibt ein Punkt. Die Welle statt eines
        // geraden Spiegels ist der zweite Unterschied zum Saftglas, das gerade
        // gefüllt ist und einen Halm hat; das Bierglas hat Henkel und Schaum.
        // Eine Flasche wäre hier die **sechste** gewesen (Wein, Spirituosen,
        // Öl, Essig, Milch) und bei 13 pt keine davon zu unterscheiden.
        "wasser": { p in
            p.begin(p.at(0.28, 0.16))
            p.to(p.at(0.36, 0.92))
            p.to(p.at(0.64, 0.92))
            p.to(p.at(0.72, 0.16))
            p.close()
            p.begin(p.at(0.303, 0.44))
            p.bow(p.at(0.697, 0.44), p.at(0.43, 0.56), p.at(0.57, 0.32))
            p.dot(p.at(0.44, 0.62), 0.055)
            p.dot(p.at(0.57, 0.74), 0.045)
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
        // Glas, Füllstand, drei Perlen — und **die Zitronenscheibe auf dem
        // Rand**.
        //
        // Vorher stand hier ein Rechteck mit einer Ellipse obenauf, und das war
        // im Getränkeregal des Satzes nichts: `wasser` ist ein Glas mit
        // Füllstand, `cola` eine Dose, `saft` ein Glas mit Halm. Ein Becher
        // ohne Merkmal ist der Platzhalter zwischen dreien, die eines haben.
        //
        // Die Scheibe ist das Merkmal, das noch frei war — sie sitzt auf dem
        // Rand statt im Glas, damit sie den Füllstand nicht kreuzt.
        "limonade": { p in
            p.begin(p.at(0.28, 0.30))
            p.to(p.at(0.34, 0.86))
            p.bow(p.at(0.66, 0.86), p.at(0.40, 0.92), p.at(0.60, 0.92))
            p.to(p.at(0.72, 0.30))
            p.close()
            p.line([p.at(0.30, 0.44), p.at(0.70, 0.44)])
            p.dot(p.at(0.44, 0.60), 0.035)
            p.dot(p.at(0.58, 0.68), 0.030)
            p.dot(p.at(0.47, 0.78), 0.028)
            p.begin(p.at(0.64, 0.30))
            p.bow(p.at(0.92, 0.30), p.at(0.64, 0.10), p.at(0.92, 0.10))
            p.close()
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
            p.oval(0.50, 0.34, 0.68, 0.22)
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
            p.rechteck(0.50, 0.68, 0.84, 0.30, ecke: 0.15)
            p.rechteck(0.50, 0.44, 0.76, 0.22, ecke: 0.11)
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
            p.rechteck(0.50, 0.66, 0.30, 0.20, ecke: 0.08)
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
            p.oval(0.50, 0.78, 0.26, 0.14)
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

        // Fisch: Körper, Keilschwanz, Rückenflosse, Auge.
        //
        // **Neu gezeichnet am 12.08.** Der Vorgänger war ein Kreisbogenpaar
        // mit einem *geraden* Dreieck als Schwanz, und beides zusammen las
        // sich auf dem Prüfbogen als Kinderzeichnung: Der Körper war an
        // beiden Enden gleich spitz, also zeigte nichts, wo vorn ist, und das
        // Dreieck saß mit einer scharfen Kante daran — die einzige Gerade im
        // ganzen Satz (siehe „es gibt keine geraden Strecken" im Kopf von
        // `CategoryGlyphs.swift`).
        //
        // Der Körper kommt aus Lucide `fish` (ISC, siehe `NOTICE`), übersetzt
        // mit `tools/svg2pen.py`: ein Oval, das nach vorn füllig und nach
        // hinten schlank wird. Kiemenbogen und Auge sind eigene Zutat — bei
        // Lucide steht dort ein zweiter Konturstrich, und der ist bei 22 pt
        // mit der Rückenlinie eine Kante.
        "fisch": { p in
            p.begin(p.at(0.271, 0.500))
            p.bow(p.at(0.441, 0.300), p.at(0.290, 0.400), p.at(0.360, 0.330))
            p.bow(p.at(0.702, 0.260), p.at(0.530, 0.262), p.at(0.630, 0.248))
            p.bow(p.at(0.894, 0.437), p.at(0.790, 0.290), p.at(0.870, 0.370))
            p.bow(p.at(0.894, 0.564), p.at(0.907, 0.476), p.at(0.907, 0.524))
            p.bow(p.at(0.702, 0.740), p.at(0.870, 0.630), p.at(0.790, 0.710))
            p.bow(p.at(0.441, 0.700), p.at(0.630, 0.752), p.at(0.530, 0.738))
            p.bow(p.at(0.271, 0.500), p.at(0.360, 0.670), p.at(0.290, 0.600))
            p.close()
            // Der Schwanz, mit Schwung statt Kante — die Kerbe sitzt mittig,
            // die beiden Spitzen liegen verschieden hoch.
            p.begin(p.at(0.30, 0.42))
            p.bow(p.at(0.07, 0.20), p.at(0.22, 0.34), p.at(0.13, 0.24))
            p.bow(p.at(0.12, 0.50), p.at(0.08, 0.32), p.at(0.11, 0.42))
            p.bow(p.at(0.07, 0.82), p.at(0.13, 0.60), p.at(0.09, 0.72))
            p.bow(p.at(0.30, 0.60), p.at(0.14, 0.78), p.at(0.23, 0.68))
            // Rückenflosse.
            p.begin(p.at(0.50, 0.29))
            p.bow(p.at(0.68, 0.14), p.at(0.54, 0.20), p.at(0.60, 0.15))
            p.bow(p.at(0.70, 0.26), p.at(0.71, 0.17), p.at(0.71, 0.21))
            // Kiemenbogen, dünn — in Konturstärke wäre er der zweite Rücken.
            p.feinBogen(p.at(0.62, 0.29), p.at(0.62, 0.71),
                        p.at(0.53, 0.40), p.at(0.53, 0.60))
            p.dot(p.at(0.78, 0.44), 0.045)
        },
    ]

    // MARK: - Molkerei, Eier & Backwaren

    private static let molkereiUndBackwaren: [String: Rezept] = [

        // Milchtüte mit Giebel — dasselbe Motiv wie beim Kategoriezeichen,
        // schlanker gezogen. Milch ist die Milchtüte; hier etwas anderes zu
        // erfinden, nur damit es anders ist, wäre der falsche Ehrgeiz.
        // Milchtüte mit **echtem Giebel**: First oben, Giebelkante quer, die
        // gefaltete Spitze als V, Bodennaht unten.
        //
        // Der erste Entwurf hatte einen aufgesetzten Hals mit Deckel und stand
        // auf dem Prüfbogen als **Flasche** da — der Hals war schmaler als der
        // Giebel und damit las das Auge Flaschenhals, nicht Ausguss. Der flache
        // First ist es, der die Tüte macht: Eine Milchtüte läuft oben nicht
        // spitz zu, sie ist zusammengefaltet.
        "milch": { p in
            // **Keine gerade Kante an der ganzen Tuete.**
            //
            // Mit `rund()` waren die Ecken weich und die Zeichnung trotzdem
            // kantig — weil zwischen den Ecken weiter Strecken lagen. Eine
            // beschichtete Kartontuete steht nie ganz gerade: Die Waende
            // beulen leicht aus, der Giebel sitzt schief. Jede Flanke ist
            // deshalb ein flacher Bogen (Auslenkung 0,015 bis 0,02) — zu
            // wenig, um als Delle zu lesen, genug, damit nichts gezeichnet
            // aussieht wie gefraest.
            // Seitenwand rechts, abgewandt.
            p.begin(p.at(0.63, 0.33))
            p.bow(p.at(0.83, 0.25), p.at(0.70, 0.30), p.at(0.77, 0.27))
            p.bow(p.at(0.85, 0.83), p.at(0.86, 0.44), p.at(0.86, 0.64))
            p.bow(p.at(0.64, 0.91), p.at(0.78, 0.86), p.at(0.71, 0.89))
            p.bow(p.at(0.63, 0.33), p.at(0.62, 0.72), p.at(0.62, 0.52))
            p.close()
            p.alsSchatten()
            // Vorderfront.
            p.begin(p.at(0.22, 0.33))
            p.bow(p.at(0.63, 0.33), p.at(0.36, 0.31), p.at(0.49, 0.31))
            p.bow(p.at(0.64, 0.91), p.at(0.65, 0.52), p.at(0.65, 0.72))
            p.bow(p.at(0.21, 0.91), p.at(0.50, 0.93), p.at(0.35, 0.93))
            p.bow(p.at(0.22, 0.33), p.at(0.20, 0.72), p.at(0.20, 0.52))
            p.close()
            p.alsKoerper()
            // Giebel: vordere Schraege und die abgewandte daneben.
            p.begin(p.at(0.22, 0.33))
            p.bow(p.at(0.34, 0.16), p.at(0.25, 0.26), p.at(0.29, 0.20))
            p.bow(p.at(0.52, 0.16), p.at(0.40, 0.14), p.at(0.46, 0.14))
            p.bow(p.at(0.63, 0.33), p.at(0.57, 0.20), p.at(0.61, 0.26))
            p.begin(p.at(0.52, 0.16))
            p.bow(p.at(0.70, 0.09), p.at(0.58, 0.13), p.at(0.64, 0.10))
            p.bow(p.at(0.83, 0.25), p.at(0.76, 0.13), p.at(0.81, 0.19))
            // Der aufgestellte Kamm.
            p.feinLinie([p.at(0.34, 0.16), p.at(0.41, 0.09), p.at(0.60, 0.09), p.at(0.52, 0.16)])
            // Etikettband auf der Front.
            p.feinBogen(p.at(0.22, 0.55), p.at(0.64, 0.55), p.at(0.36, 0.57), p.at(0.50, 0.57))
            p.feinBogen(p.at(0.22, 0.69), p.at(0.64, 0.69), p.at(0.36, 0.71), p.at(0.50, 0.71))
        },

        // Butter: Block mit einem abgeschnittenen Stück obenauf.
        //
        // Der erste Entwurf hatte ein aufgeschlagenes Papier als Zickzack
        // daneben und war auf dem Prüfbogen ein **Karton mit offenem Deckel**.
        // Das abgeschnittene Stück sagt dasselbe (jemand hat davon genommen)
        // und ist eine Form statt einer Falte.
        // Der Block, das abgeschnittene Stück obenauf — und **eine** Falte im
        // Papier am rechten Ende.
        //
        // Erst standen hier **zwei** senkrechte Linien als Banderole, und der
        // Prüfbogen zeigte, warum das nicht geht: Zwei Linien quer durch einen
        // Quader teilen ihn in drei Fächer, und aus dem Päckchen wurde ein
        // **Regal mit drei Kisten**. Eine Linie war nicht besser, nur weniger
        // falsch — sie machte aus dem Block einen großen und einen kleinen
        // Kasten.
        //
        // **Eine Linie, die eine Kante berührt, teilt; eine, die in der Ecke
        // sitzt, faltet.** Deshalb liegt das Papier jetzt als abgeknickte Ecke
        // oben rechts und läuft nicht mehr durch den Block hindurch.
        "butter": { p in
            p.rechteck(0.50, 0.68, 0.80, 0.32, ecke: 0.04)
            p.line([p.at(0.74, 0.52), p.at(0.90, 0.68)])
            p.begin(p.at(0.26, 0.52))
            p.to(p.at(0.36, 0.34))
            p.to(p.at(0.64, 0.34))
            p.to(p.at(0.54, 0.52))
            p.close()
        },

        // Käsedreieck mit zwei Löchern. Das Dreieck ist die Silhouette, die
        // niemand nachfragt — die Löcher sind gefüllt, weil ein Ring von drei
        // Pixeln bei 13 pt ein Punkt ist.
        // Keil, **Rindenband** an der Unterkante, drei Löcher versetzt.
        //
        // Die Rinde ist der Zuwachs: Ein Dreieck mit Löchern ist ein Dreieck
        // mit Löchern, erst das Band an der Grundseite sagt „geschnitten von
        // einem Laib". Sie liegt auf 0,66 und nicht tiefer — bei 0,70 lief sie
        // bei 40 pt mit der Grundkante zu einem Balken zusammen (Strich 3,8 pt,
        // also 0,095 in Einheitsmaßen: zwei Striche brauchen 0,13 Abstand).
        //
        // Die Löcher sind gefüllt, nicht geringelt: Ein Ring von drei Pixeln
        // ist bei 22 pt ein Punkt, nur ein unsauberer.
        // Der Keil ist **höher gezogen** (0,18 statt 0,24) und die Rinde tiefer
        // gerutscht (0,72 statt 0,66). Grund: In der ersten Fassung saßen die
        // Löcher dort, wo das Dreieck schon schmal ist, und drängten sich unter
        // der Spitze zusammen. Der Platz für Löcher ist unten, also musste die
        // Rinde nach unten und der Keil in die Höhe.
        // **Der Keil zeigt nach links, und das ist der ganze Punkt.**
        //
        // Hier stand ein gleichschenkliges Dreieck mit der Spitze nach oben,
        // einer Querlinie und drei Punkten darin. Daneben steht in diesem
        // Satz `pizza`: ein Dreieck mit einer Rundung und Punkten darin. Auf
        // dem Prüfbogen vom 11.08. lagen die beiden nebeneinander und waren
        // **dasselbe Zeichen** — ein Dreieck mit Tupfen. Keine Strichstärke
        // rettet zwei Zeichnungen, die sich nur in der Rundung unterscheiden.
        //
        // Drei Dinge trennen sie jetzt: Der Käse liegt **quer** statt hoch,
        // seine Löcher sind **gestrichene Ringe** statt voller Punkte (ein
        // Loch ist ein Loch, ein Belagstück ist ein Fleck), und er hat eine
        // **Rinde** — die Doppellinie an der hohen Kante.
        "käse": { p in
            // **Ein Keil, der nach links spitz zulaeuft** — und dessen Kanten
            // leicht bauchig sind. Vier Anlaeufe: ein gleichschenkliges
            // Dreieck mit Punkten (= `pizza` zwei Zellen weiter), ein Quader
            // mit zwei Loechern (= ein **Koffer**), dann derselbe Keil aus
            // Strecken — richtig in der Form und trotzdem hart, weil ein
            // Kaeselaib geschnitten und nicht gefraest wird.
            // Deckflaeche entlang der Oberkante.
            p.begin(p.at(0.07, 0.59))
            p.bow(p.at(0.21, 0.45), p.at(0.11, 0.53), p.at(0.15, 0.48))
            p.bow(p.at(0.92, 0.23), p.at(0.45, 0.36), p.at(0.70, 0.28))
            p.bow(p.at(0.77, 0.36), p.at(0.88, 0.28), p.at(0.83, 0.32))
            p.bow(p.at(0.07, 0.59), p.at(0.52, 0.46), p.at(0.28, 0.54))
            p.close()
            p.alsSchatten()
            // Schnittflaeche rechts — hier ist der Keil am dicksten.
            p.begin(p.at(0.77, 0.36))
            p.bow(p.at(0.92, 0.23), p.at(0.83, 0.32), p.at(0.88, 0.27))
            p.bow(p.at(0.93, 0.63), p.at(0.94, 0.36), p.at(0.94, 0.50))
            p.bow(p.at(0.78, 0.77), p.at(0.89, 0.68), p.at(0.83, 0.73))
            p.bow(p.at(0.77, 0.36), p.at(0.76, 0.63), p.at(0.76, 0.50))
            p.close()
            p.alsSchatten()
            // Vorderflaeche.
            p.begin(p.at(0.07, 0.59))
            p.bow(p.at(0.77, 0.36), p.at(0.28, 0.54), p.at(0.52, 0.45))
            p.bow(p.at(0.78, 0.77), p.at(0.76, 0.50), p.at(0.76, 0.64))
            p.bow(p.at(0.07, 0.59), p.at(0.52, 0.83), p.at(0.26, 0.71))
            p.close()
            p.alsKoerper()
            p.feinKreis(p.at(0.42, 0.60), 0.048)
            p.feinKreis(p.at(0.62, 0.56), 0.036)
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
            p.oval(0.50, 0.40, 0.68, 0.26)
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
            p.oval(0.74, 0.72, 0.40, 0.22)
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
        // Hoher Becher, **aufgesetzter Deckelrand**, eine Naht auf halber Höhe.
        // Hoch statt flach, damit er neben dem Frischkäse nicht derselbe Becher
        // ist; der kantige Deckel trennt ihn von der gewölbten Folie, die
        // vorher hier lag und bei 22 pt nur eine dicke Kappe war.
        "quark": { p in
            p.begin(p.at(0.26, 0.36))
            p.to(p.at(0.34, 0.90))
            p.to(p.at(0.66, 0.90))
            p.to(p.at(0.74, 0.36))
            p.close()
            p.rechteck(0.50, 0.30, 0.60, 0.12, ecke: 0.03)
            // **Hier stand eine abgezogene Folienecke, und sie ist wieder weg.**
            // Schräg nach oben war sie ein **Strohhalm**, flach nach rechts ein
            // **Löffelstiel** — beide Male machte der Fortsatz aus dem Becher
            // ein Trinkgefäß. Ein Detail, das an der Silhouette zieht, kostet
            // mehr, als es einbringt: Der aufgesetzte Deckelrand allein sagt
            // „verschlossener Becher", und der berührt den Umriss nicht.
        },

        // Joghurt: Becher mit Löffel darin. Der Löffel ist die Auskunft —
        // ohne ihn stünden hier drei gleiche Becher nebeneinander.
        // Becher mit Löffel darin — der Löffel ist die Auskunft, ohne ihn
        // stünden hier drei gleiche Becher nebeneinander. Neu ist das
        // **Bandenetikett** auf 0,58: Es füllt die leere Wand, die den Becher
        // vorher zu einem Eimer machte, und liegt 0,14 unter dem Rand.
        "joghurt": { p in
            // Der Becher lief bis zum 12.08. offen aus und war damit der
            // einzige im Satz ohne Körperfläche — geschlossen wird er entlang
            // derselben Waagerechten, auf der ohnehin der Rand liegt.
            p.begin(p.at(0.22, 0.44))
            p.to(p.at(0.30, 0.92))
            p.to(p.at(0.70, 0.92))
            p.to(p.at(0.78, 0.44))
            p.close()
            p.line([p.at(0.16, 0.44), p.at(0.84, 0.44)])
            p.line([p.at(0.25, 0.58), p.at(0.75, 0.58)])
            p.line([p.at(0.56, 0.42), p.at(0.74, 0.14)])
            p.oval(0.79, 0.11, 0.20, 0.14)
        },

        // Sahne: Becher mit **Sahnetuff** — drei Bögen, die nach oben kleiner
        // werden und in einer Spitze enden.
        //
        // Ein einzelner großer Bogen über dem Becher war der erste Entwurf und
        // auf dem Prüfbogen ein **Eimer mit Deckel**. Ein Tuff ist nicht rund,
        // er ist gestapelt — erst die drei Stufen sagen „aufgeschlagen".
        // Becher mit **Sahnetuff** — drei Bögen, die nach oben kleiner werden.
        //
        // Ein einzelner großer Bogen war der erste Entwurf und auf dem
        // Prüfbogen ein **Eimer mit Deckel**. Ein Tuff ist nicht rund, er ist
        // gestapelt.
        //
        // **Die Wanne ist breit und flach, nicht hoch und schmal** — und das ist
        // der ganze Punkt. Ein schlanker Becher mit einem Tuff darauf war auf
        // dem Prüfbogen **Softeis in der Waffel**; neben `eis` im selben Raster
        // wäre das zweimal dasselbe Bild gewesen. Breiter als hoch liest sich
        // als Becher, und der Tuff bleibt, was er ist: aufgeschlagene Sahne.
        //
        // Die drei Stufen stehen auf 0,14 und 0,13 Abstand — knapp über dem,
        // was der 3,8-pt-Strich bei 40 pt noch offen lässt.
        "sahne": { p in
            // Wie beim Joghurt: offener Becher, deshalb bis zum 12.08. ohne
            // Fläche. Der Tuff darüber bleibt Linie — drei offene Bögen haben
            // keine Innenseite, und gefüllt wäre er eine Haube.
            p.begin(p.at(0.22, 0.60))
            p.to(p.at(0.26, 0.90))
            p.to(p.at(0.74, 0.90))
            p.to(p.at(0.78, 0.60))
            p.close()
            p.line([p.at(0.16, 0.60), p.at(0.84, 0.60)])
            p.begin(p.at(0.28, 0.58))
            p.bow(p.at(0.72, 0.58), p.at(0.32, 0.40), p.at(0.68, 0.40))
            p.begin(p.at(0.36, 0.44))
            p.bow(p.at(0.64, 0.44), p.at(0.40, 0.28), p.at(0.60, 0.28))
            p.begin(p.at(0.44, 0.31))
            p.bow(p.at(0.56, 0.31), p.at(0.47, 0.18), p.at(0.53, 0.18))
        },

        // **Zwei Eier im Karton**, nicht mehr zwei Eier im Nichts.
        //
        // Vorher lagen hier zwei freistehende Ovale, und genau das war das
        // Problem: Ein Oval ist bei 22 pt eine Kartoffel, eine Zwiebel oder ein
        // Ballon — der Satz hat von allen dreien eines. Der Karton darunter ist
        // die Auskunft, die das Oval allein nicht geben kann, und zugleich das,
        // was man im Laden in die Hand nimmt.
        //
        // Die beiden Kuppen stehen 0,16 auseinander. Bei 0,08 lagen ihre
        // 3,8-pt-Striche bei 40 pt aufeinander und aus zwei Eiern wurde ein
        // Doppelhöcker.
        // Die beiden Eier tragen den Ton, die Schachtel nur ihren Körper —
        // sonst wäre das Zeichen ein cremefarbener Block mit einer Kante.
        // Die Kuppen werden dafür geschlossen; die Schlusslinie liegt genau
        // auf der Oberkante der Schachtel und ist deshalb keine zweite.
        "eier": { p in
            // **Drei Eier in der offenen Schachtel.** Im ersten Anlauf sass
            // der Deckel so tief, dass die Eier bis zur Haelfte darin
            // verschwanden — drei Boegen unter einem Dach, also eine Arkade.
            //
            // Gepresste Pappe hat **nirgends** eine gerade Kante: Deckel und
            // Wanne sind deshalb aus Boegen gebaut, nicht aus Strecken mit
            // gerundeten Ecken. Der Unterschied ist klein und genau der
            // zwischen „Karton" und „Kiste".
            p.begin(p.at(0.15, 0.34))
            p.bow(p.at(0.27, 0.15), p.at(0.17, 0.26), p.at(0.21, 0.19))
            p.bow(p.at(0.84, 0.15), p.at(0.45, 0.12), p.at(0.66, 0.12))
            p.bow(p.at(0.91, 0.34), p.at(0.89, 0.19), p.at(0.91, 0.26))
            p.bow(p.at(0.15, 0.34), p.at(0.66, 0.39), p.at(0.38, 0.39))
            p.close()
            p.alsSchatten()
            // Die drei Eier, das mittlere vorn und groesser.
            p.begin(p.at(0.16, 0.68))
            p.bow(p.at(0.38, 0.68), p.at(0.16, 0.40), p.at(0.38, 0.40))
            p.close()
            p.alsKoerper()
            p.begin(p.at(0.62, 0.68))
            p.bow(p.at(0.84, 0.68), p.at(0.62, 0.40), p.at(0.84, 0.40))
            p.close()
            p.alsKoerper()
            p.begin(p.at(0.38, 0.70))
            p.bow(p.at(0.62, 0.70), p.at(0.38, 0.38), p.at(0.62, 0.38))
            p.close()
            p.alsKoerper()
            // Die Wanne.
            p.begin(p.at(0.06, 0.67))
            p.bow(p.at(0.94, 0.67), p.at(0.34, 0.64), p.at(0.66, 0.64))
            p.bow(p.at(0.85, 0.90), p.at(0.93, 0.78), p.at(0.90, 0.85))
            p.bow(p.at(0.15, 0.90), p.at(0.62, 0.94), p.at(0.38, 0.94))
            p.bow(p.at(0.06, 0.67), p.at(0.10, 0.85), p.at(0.07, 0.78))
            p.close()
            p.feinLinie([p.at(0.28, 0.74), p.at(0.27, 0.85)])
            p.feinLinie([p.at(0.50, 0.76), p.at(0.50, 0.87)])
            p.feinLinie([p.at(0.72, 0.74), p.at(0.73, 0.85)])
        },

        // Margarine: breite Wanne mit übergreifendem Deckel. Der Deckelrand
        // steht seitlich über, der Becher daneben hat seinen bündig.
        "margarine": { p in
            p.rechteck(0.50, 0.66, 0.64, 0.34, ecke: 0.05)
            p.rechteck(0.50, 0.42, 0.78, 0.16, ecke: 0.05)
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
            p.rechteck(0.50, 0.28, 0.26, 0.16, ecke: 0)
            p.rechteck(0.50, 0.14, 0.20, 0.14, ecke: 0)
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
            // **Laib und eine Scheibe daneben.** Die Scheibe trug im ersten
            // Anlauf zwei feine Kreise als Poren — und war damit ein
            // **Gesicht**: zwei Loecher in einer runden Flaeche, die Falle
            // Nummer zwei der Liste. Zwei waagerechte Striche sagen dasselbe
            // und koennen keine Augen sein.
            p.begin(p.at(0.30, 0.76))
            p.bow(p.at(0.30, 0.50), p.at(0.27, 0.68), p.at(0.27, 0.58))
            p.bow(p.at(0.94, 0.50), p.at(0.30, 0.22), p.at(0.94, 0.22))
            p.bow(p.at(0.94, 0.76), p.at(0.97, 0.58), p.at(0.97, 0.68))
            p.bow(p.at(0.30, 0.76), p.at(0.80, 0.82), p.at(0.44, 0.82))
            p.close()
            p.alsSchatten()
            // Die Krustennaht und die drei Einschnitte.
            p.feinBogen(p.at(0.32, 0.62), p.at(0.93, 0.62),
                        p.at(0.48, 0.66), p.at(0.78, 0.66))
            p.feinLinie([p.at(0.46, 0.44), p.at(0.54, 0.32)])
            p.feinLinie([p.at(0.62, 0.42), p.at(0.70, 0.30)])
            p.feinLinie([p.at(0.78, 0.44), p.at(0.86, 0.32)])
            // Die Scheibe, links davor.
            p.begin(p.at(0.06, 0.90))
            p.bow(p.at(0.06, 0.68), p.at(0.03, 0.83), p.at(0.03, 0.74))
            p.bow(p.at(0.40, 0.68), p.at(0.06, 0.50), p.at(0.40, 0.50))
            p.bow(p.at(0.40, 0.90), p.at(0.43, 0.74), p.at(0.43, 0.83))
            p.bow(p.at(0.06, 0.90), p.at(0.32, 0.94), p.at(0.14, 0.94))
            p.close()
            p.alsKoerper()
            p.feinLinie([p.at(0.12, 0.78), p.at(0.34, 0.78)])
            p.feinLinie([p.at(0.12, 0.86), p.at(0.30, 0.86)])
        },

        // Knäckebrot: rechteckige Scheibe mit zwei Lochreihen.
        "knäckebrot": { p in
            p.rechteck(0.50, 0.50, 0.62, 0.80, ecke: 0.05)
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
            p.rechteck(0.50, 0.70, 0.68, 0.36, ecke: 0.04)
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

// MARK: - Tranche 1: Wörter, die bisher nichts trafen

/// **Dreiundzwanzig Zeichen zu den Begriffen aus Tranche 1** (2026-08-07).
///
/// Die Begriffe kamen im Backend dazu (`9792df2`): Wörter, die auf Blocklisten
/// standen und keinem Begriff gehörten — „Kartoffelsalat", „Röstzwiebeln",
/// „Müsliriegel". Ohne Zeichnung fiele jeder von ihnen auf sein
/// Kategoriezeichen zurück, und `ItemGlyphTests` wird genau dafür rot.
///
/// **Vier Salate, vier verschiedene Bilder.** Der naheliegende Weg wäre
/// viermal dieselbe Schüssel mit anderem Inhalt gewesen — und bei 13 pt ist
/// der Inhalt weg, dann stehen vier gleiche Schüsseln nebeneinander. Genau
/// der Fehler, der das ganze Vorhaben ausgelöst hat (fünfmal derselbe Apfel).
/// Deshalb trägt jeder Salat ein **eigenes Gefäß oder Motiv**: Schüssel mit
/// Knolle, Gabel mit Nudel, halber Kohlkopf, Feinkostbecher.
///
/// **Und die drei Säfte sind absichtlich ein System.** Glas plus Frucht
/// darüber — Traube, Zitrone, Tomate. Wer eines gelernt hat, liest die
/// anderen beiden ohne Nachdenken.
private let tranche1: [String: ItemGlyph.Rezept] = [

    // Süßkartoffel: länger als die Kartoffel, an beiden Enden spitz, mit
    // einem Trieb. Ohne den Trieb ist sie bei 13 pt von der Kartoffel nicht
    // zu unterscheiden — beides ist dann ein Oval.
    "süßkartoffeln": { p in
        p.begin(p.at(0.10, 0.66))
        p.bow(p.at(0.90, 0.44), p.at(0.26, 0.30), p.at(0.72, 0.28))
        p.bow(p.at(0.10, 0.66), p.at(0.76, 0.74), p.at(0.30, 0.86))
        p.close()
        // Zwei Blätter an kurzem Trieb. Der erste Entwurf hatte eine
        // gerollte Ranke, und die war auf dem Prüfbogen eine Schnecke.
        p.line([p.at(0.78, 0.34), p.at(0.80, 0.18)])
        p.begin(p.at(0.80, 0.18))
        p.bow(p.at(0.62, 0.10), p.at(0.74, 0.10), p.at(0.64, 0.16))
        p.bow(p.at(0.80, 0.18), p.at(0.62, 0.04), p.at(0.74, 0.08))
        p.begin(p.at(0.80, 0.18))
        p.bow(p.at(0.96, 0.10), p.at(0.86, 0.10), p.at(0.94, 0.16))
        p.bow(p.at(0.80, 0.18), p.at(0.96, 0.04), p.at(0.86, 0.08))
    },

    // Einmachglas mit Bügelverschluss, darin zwei Gurken. Der Deckelrand ist
    // das, was es vom Trinkglas trennt.
    "essiggurken": { p in
        p.line([p.at(0.24, 0.24), p.at(0.76, 0.24)])
        p.line([p.at(0.28, 0.16), p.at(0.72, 0.16)])
        p.line([p.at(0.28, 0.16), p.at(0.24, 0.24)])
        p.line([p.at(0.72, 0.16), p.at(0.76, 0.24)])
        p.begin(p.at(0.24, 0.24))
        p.to(p.at(0.24, 0.86))
        p.bow(p.at(0.76, 0.86), p.at(0.24, 0.94), p.at(0.76, 0.94))
        p.to(p.at(0.76, 0.24))
        p.capsule(0.40, 0.58, 0.14, 0.42, tilt: -8)
        p.capsule(0.60, 0.60, 0.14, 0.38, tilt: 9)
    },

    // Kartoffelsalat: Schüssel, und darüber die Knolle, um die es geht.
    "kartoffelsalat": { p in
        p.begin(p.at(0.12, 0.58))
        p.bow(p.at(0.88, 0.58), p.at(0.18, 0.92), p.at(0.82, 0.92))
        p.close()
        p.begin(p.at(0.34, 0.44))
        p.bow(p.at(0.66, 0.40), p.at(0.36, 0.24), p.at(0.66, 0.24))
        p.bow(p.at(0.34, 0.44), p.at(0.66, 0.52), p.at(0.38, 0.54))
        p.close()
    },

    // Nudelsalat: Gabel mit aufgedrehter Nudel. Kein Teller — der wäre
    // wieder eine Schüssel.
    "nudelsalat": { p in
        p.line([p.at(0.50, 0.10), p.at(0.50, 0.54)])
        p.line([p.at(0.38, 0.10), p.at(0.38, 0.30)])
        p.line([p.at(0.62, 0.10), p.at(0.62, 0.30)])
        p.line([p.at(0.38, 0.30), p.at(0.62, 0.30)])
        p.begin(p.at(0.24, 0.66))
        p.bow(p.at(0.76, 0.70), p.at(0.30, 0.46), p.at(0.74, 0.48))
        p.bow(p.at(0.26, 0.80), p.at(0.78, 0.88), p.at(0.28, 0.92))
        p.bow(p.at(0.70, 0.82), p.at(0.30, 0.70), p.at(0.66, 0.70))
    },

    // Krautsalat: halbierter Kohlkopf. Die inneren Bögen sind der ganze
    // Witz — sie machen aus einer Kugel einen Schnitt.
    "krautsalat": { p in
        p.circle(p.at(0.50, 0.52), 0.38)
        p.begin(p.at(0.16, 0.60))
        p.bow(p.at(0.84, 0.60), p.at(0.34, 0.30), p.at(0.66, 0.30))
        p.begin(p.at(0.26, 0.70))
        p.bow(p.at(0.74, 0.70), p.at(0.38, 0.48), p.at(0.62, 0.48))
        p.line([p.at(0.50, 0.62), p.at(0.50, 0.90)])
    },

    // Fleischsalat: Feinkostbecher mit Deckelrand und Etikett.
    "fleischsalat": { p in
        p.line([p.at(0.18, 0.30), p.at(0.82, 0.30)])
        p.begin(p.at(0.22, 0.30))
        p.to(p.at(0.30, 0.88))
        p.to(p.at(0.70, 0.88))
        p.to(p.at(0.78, 0.30))
        p.close()
        p.line([p.at(0.34, 0.52), p.at(0.66, 0.52)])
        p.line([p.at(0.36, 0.66), p.at(0.64, 0.66)])
    },

    // Röstzwiebeln: drei Ringe, locker gestreut.
    "röstzwiebeln": { p in
        p.circle(p.at(0.34, 0.36), 0.20)
        p.circle(p.at(0.34, 0.36), 0.09)
        p.circle(p.at(0.66, 0.54), 0.17)
        p.circle(p.at(0.66, 0.54), 0.07)
        p.circle(p.at(0.40, 0.76), 0.14)
        p.circle(p.at(0.40, 0.76), 0.06)
    },

    // Tomatensauce: bauchiges Glas mit Schraubdeckel, Tomate auf dem Bauch.
    "tomatensauce": { p in
        p.line([p.at(0.34, 0.12), p.at(0.66, 0.12)])
        p.line([p.at(0.34, 0.12), p.at(0.34, 0.22)])
        p.line([p.at(0.66, 0.12), p.at(0.66, 0.22)])
        p.begin(p.at(0.34, 0.22))
        p.bow(p.at(0.20, 0.46), p.at(0.24, 0.26), p.at(0.20, 0.34))
        p.to(p.at(0.20, 0.86))
        p.bow(p.at(0.80, 0.86), p.at(0.20, 0.94), p.at(0.80, 0.94))
        p.to(p.at(0.80, 0.46))
        p.bow(p.at(0.66, 0.22), p.at(0.80, 0.34), p.at(0.76, 0.26))
        p.circle(p.at(0.50, 0.64), 0.15)
        p.line([p.at(0.50, 0.49), p.at(0.50, 0.44)])
    },

    // Die drei Säfte: dasselbe Glas, darüber die Frucht. Traube.
    "traubensaft": { p in
        saftkarton(&p)
        p.circle(p.at(0.38, 0.58), 0.075)
        p.circle(p.at(0.54, 0.58), 0.075)
        p.circle(p.at(0.46, 0.74), 0.075)
    },

    // Zitrone: Oval mit Zipfeln an beiden Enden — dasselbe Motiv wie beim
    // Begriff „zitronen", damit man es wiedererkennt.
    "zitronensaft": { p in
        saftkarton(&p)
        p.begin(p.at(0.32, 0.64))
        p.bow(p.at(0.62, 0.64), p.at(0.37, 0.52), p.at(0.57, 0.52))
        p.bow(p.at(0.32, 0.64), p.at(0.57, 0.76), p.at(0.37, 0.76))
        p.line([p.at(0.32, 0.64), p.at(0.28, 0.64)])
        p.line([p.at(0.62, 0.64), p.at(0.66, 0.64)])
    },

    // Tomate: Kreis mit Kelchblatt.
    "tomatensaft": { p in
        saftkarton(&p)
        p.circle(p.at(0.47, 0.66), 0.13)
        p.line([p.at(0.41, 0.53), p.at(0.53, 0.53)])
        p.line([p.at(0.47, 0.50), p.at(0.47, 0.56)])
    },

    // Vanillezucker: Tütchen mit gezacktem Aufriss und der Schote darauf.
    "vanillezucker": { p in
        p.line([p.at(0.26, 0.22), p.at(0.74, 0.22), p.at(0.74, 0.86),
                p.at(0.26, 0.86)], closed: true)
        p.line([p.at(0.26, 0.22), p.at(0.34, 0.14), p.at(0.42, 0.22),
                p.at(0.50, 0.14), p.at(0.58, 0.22), p.at(0.66, 0.14),
                p.at(0.74, 0.22)])
        p.capsule(0.50, 0.56, 0.12, 0.42, tilt: 14)
    },

    // Traubenzucker: Rolle aus Täfelchen, wie sie im Regal liegt.
    // **Drei Täfelchen übereinander, mit angerissener Hülle.** Anlauf 1 war
    // eine geneigte Kapsel mit Schrägstrichen (ein Brötchen), Anlauf 2 eine
    // Rolle mit eingedrehten Enden (eine Garnrolle). Gestapelte Scheiben sind
    // das, woran man Täfelchen erkennt — und die Hülle sagt, dass sie
    // verpackt sind.
    "traubenzucker": { p in
        p.begin(p.at(0.20, 0.28))
        p.bow(p.at(0.80, 0.28), p.at(0.27, 0.14), p.at(0.73, 0.14))
        p.bow(p.at(0.20, 0.28), p.at(0.73, 0.42), p.at(0.27, 0.42))
        p.close()
        p.begin(p.at(0.20, 0.48))
        p.bow(p.at(0.80, 0.48), p.at(0.27, 0.34), p.at(0.73, 0.34))
        p.begin(p.at(0.20, 0.68))
        p.bow(p.at(0.80, 0.68), p.at(0.27, 0.54), p.at(0.73, 0.54))
        p.line([p.at(0.20, 0.28), p.at(0.20, 0.70)])
        p.line([p.at(0.80, 0.28), p.at(0.80, 0.70)])
        p.begin(p.at(0.20, 0.70))
        p.bow(p.at(0.80, 0.70), p.at(0.27, 0.88), p.at(0.73, 0.88))
    },

    // Brühe: Würfel mit aufgerissener Ecke, darüber zwei Fäden Dampf.
    "brühe": { p in
        p.line([p.at(0.24, 0.44), p.at(0.76, 0.44), p.at(0.76, 0.90),
                p.at(0.24, 0.90)], closed: true)
        p.line([p.at(0.60, 0.44), p.at(0.76, 0.60)])
        p.begin(p.at(0.40, 0.32))
        p.bow(p.at(0.40, 0.08), p.at(0.30, 0.24), p.at(0.50, 0.18))
        p.begin(p.at(0.60, 0.32))
        p.bow(p.at(0.60, 0.12), p.at(0.50, 0.26), p.at(0.70, 0.20))
    },

    // Salatdressing: Flasche mit langem Hals, leicht gekippt, mit Ausguss.
    "salatdressing": { p in
        p.line([p.at(0.38, 0.10), p.at(0.54, 0.10)])
        p.begin(p.at(0.38, 0.10))
        p.to(p.at(0.36, 0.36))
        p.bow(p.at(0.24, 0.56), p.at(0.34, 0.44), p.at(0.26, 0.48))
        p.to(p.at(0.24, 0.88))
        p.bow(p.at(0.72, 0.88), p.at(0.24, 0.94), p.at(0.72, 0.94))
        p.to(p.at(0.70, 0.56))
        p.bow(p.at(0.54, 0.36), p.at(0.68, 0.48), p.at(0.58, 0.44))
        p.to(p.at(0.54, 0.10))
        p.close()
        p.line([p.at(0.28, 0.66), p.at(0.68, 0.66)])
    },

    // Eiswürfel: zwei Würfel, der hintere versetzt. Die Deckfläche macht aus
    // dem Quadrat einen Körper.
    "eiswürfel": { p in
        p.line([p.at(0.12, 0.48), p.at(0.30, 0.34), p.at(0.62, 0.34),
                p.at(0.62, 0.48)], closed: true)
        p.line([p.at(0.12, 0.48), p.at(0.12, 0.82), p.at(0.44, 0.82),
                p.at(0.44, 0.48)])
        p.line([p.at(0.44, 0.82), p.at(0.62, 0.68), p.at(0.62, 0.34)])
        p.line([p.at(0.44, 0.48), p.at(0.62, 0.34)])
        p.line([p.at(0.56, 0.62), p.at(0.70, 0.52), p.at(0.90, 0.52),
                p.at(0.90, 0.62)], closed: true)
        p.line([p.at(0.56, 0.62), p.at(0.56, 0.88), p.at(0.78, 0.88),
                p.at(0.78, 0.62)])
        p.line([p.at(0.78, 0.88), p.at(0.90, 0.78), p.at(0.90, 0.62)])
    },

    // Chips: Tüte mit gezacktem Aufriss oben, ein Chip davor.
    "kartoffelchips": { p in
        p.line([p.at(0.24, 0.26), p.at(0.28, 0.18), p.at(0.36, 0.26),
                p.at(0.44, 0.18), p.at(0.52, 0.26), p.at(0.60, 0.18),
                p.at(0.64, 0.26)])
        p.line([p.at(0.24, 0.26), p.at(0.24, 0.88), p.at(0.64, 0.88),
                p.at(0.64, 0.26)])
        // Der Chip steht **frei** neben dem Beutel. Am Beutel klebend las er
        // sich als Henkel.
        p.begin(p.at(0.74, 0.62))
        p.bow(p.at(0.96, 0.76), p.at(0.86, 0.50), p.at(0.98, 0.62))
        p.bow(p.at(0.74, 0.62), p.at(0.94, 0.90), p.at(0.76, 0.80))
    },

    // Kartoffelknödel: Kugel auf einem Teller. Der Teller ist nur ein Strich
    // mit zwei Enden — mehr trägt bei 13 pt nicht.
    "kartoffelknödel": { p in
        p.circle(p.at(0.50, 0.44), 0.28)
        p.begin(p.at(0.34, 0.34))
        p.bow(p.at(0.52, 0.28), p.at(0.38, 0.28), p.at(0.46, 0.26))
        p.begin(p.at(0.12, 0.76))
        p.bow(p.at(0.88, 0.76), p.at(0.28, 0.90), p.at(0.72, 0.90))
    },

    // Müsliriegel: Balken mit gestreuten Körnern.
    "müsliriegel": { p in
        // Höher als der erste Wurf: bei 0,24 Höhe fiel er durch die Schwelle
        // gegen entartete Zeichnungen — ein Riegel, der nur noch ein Strich
        // ist, sagt nichts mehr.
        p.line([p.at(0.10, 0.34), p.at(0.90, 0.34), p.at(0.90, 0.68),
                p.at(0.10, 0.68)], closed: true)
        p.dot(p.at(0.26, 0.44), 0.04)
        p.dot(p.at(0.46, 0.58), 0.04)
        p.dot(p.at(0.64, 0.44), 0.04)
        p.dot(p.at(0.80, 0.58), 0.04)
    },

    // Brezel: der eine Fall, in dem drei Bögen ein Wort sind.
    // **Vier Anläufe Brezel, vier Fehllesungen — jetzt Salzstangen.**
    //
    // Der Reihe nach, weil zusammen eine Regel daraus wird: geschlossener
    // Umriss → ein **Apfel**. Zwei gekreuzte Bögen → eine **Glühbirne**.
    // Umriss plus zwei Ringe plus ein X darin → eine **Eule**, weil zwei
    // Löcher über einem Strich immer ein Gesicht sind. Ein Band, das sich
    // selbst kreuzt → zwei **Haken**.
    //
    // Die Brezel lebt davon, dass man sieht, **welches Band über welchem
    // liegt** — und genau das kann eine Monolinie ohne Überdeckung nicht
    // zeigen. Das ist keine Frage von noch einem Versuch, sondern eine
    // Eigenschaft des Zeichenstils.
    //
    // Der Begriff trägt „salzstangen" und „laugenbrezel" mit; gezeichnet ist
    // deshalb das, was in derselben Tüte liegt und sich in einer Linie sagen
    // lässt. **Lieber ein Bild, das stimmt, als eins, das das richtige Wort
    // meint und falsch gelesen wird.**
    "salzbrezeln": { p in
        // **Der Strich ist die Stange, nicht ihr Umriss.** Zwei Anläufe mit
        // `capsule` liefen zu einem Klumpen zusammen, und der Grund ist
        // Arithmetik: Eine Kapsel wird **gestrichen**, und bei 0,095
        // Strichstärke deckt der Strich eine 0,10 breite Kapsel vollständig
        // zu. In einem Monolinien-Satz ist ein dünner Gegenstand eine Linie.
        p.line([p.at(0.22, 0.84), p.at(0.36, 0.16)])
        p.line([p.at(0.50, 0.88), p.at(0.50, 0.14)])
        p.line([p.at(0.78, 0.84), p.at(0.64, 0.16)])
        p.dot(p.at(0.30, 0.44), 0.035)
        p.dot(p.at(0.70, 0.52), 0.035)
        p.dot(p.at(0.42, 0.68), 0.035)
    },

    // **Der Wellenrand muss gezackt sein, nicht gewölbt.** Vier weiche Bögen
    // ergeben wieder einen Kreis, und der war auf dem Prüfbogen ein Knopf.
    // Acht kurze Bögen mit Gegenschwung sind als Rand zu erkennen.
    "maiswaffeln": { p in
        let n = 10
        var punkte: [CGPoint] = []
        for i in 0..<(n * 2) {
            let winkel = Double(i) / Double(n * 2) * 2 * Double.pi
            let r: CGFloat = i.isMultiple(of: 2) ? 0.40 : 0.33
            punkte.append(p.at(0.50 + r * CGFloat(cos(winkel)),
                               0.50 + r * CGFloat(sin(winkel))))
        }
        p.line(punkte, closed: true)
        p.dot(p.at(0.40, 0.42), 0.05)
        p.dot(p.at(0.62, 0.48), 0.05)
        p.dot(p.at(0.46, 0.64), 0.05)
    },

    // Eis am Stiel. Der Stiel unterscheidet es vom Riegel darüber.
    "milcheis": { p in
        p.begin(p.at(0.30, 0.34))
        p.bow(p.at(0.70, 0.34), p.at(0.30, 0.10), p.at(0.70, 0.10))
        p.to(p.at(0.70, 0.70))
        p.bow(p.at(0.30, 0.70), p.at(0.70, 0.80), p.at(0.30, 0.80))
        p.close()
        p.line([p.at(0.50, 0.76), p.at(0.50, 0.94)])
    },

    // Kuchenstück: Keil mit Boden, Guss und Kirsche.
    // **Tortenstück von vorn, nicht als Dreieck.** Anlauf 1 war ein
    // gleichschenkliges Dreieck mit Kirsche an der Spitze — ein Tannenbaum.
    // Anlauf 2 ein liegender Keil — eine Rampe. Ein Stück steht auf seinem
    // Boden, hat oben Guss und in der Mitte eine Schicht; erst das ist Kuchen.
    "kuchen": { p in
        p.line([p.at(0.14, 0.86), p.at(0.86, 0.86)])
        p.line([p.at(0.14, 0.86), p.at(0.24, 0.44)])
        p.line([p.at(0.86, 0.86), p.at(0.76, 0.44)])
        p.begin(p.at(0.24, 0.44))
        p.bow(p.at(0.42, 0.44), p.at(0.28, 0.34), p.at(0.38, 0.34))
        p.bow(p.at(0.58, 0.44), p.at(0.46, 0.54), p.at(0.54, 0.54))
        p.bow(p.at(0.76, 0.44), p.at(0.62, 0.34), p.at(0.72, 0.34))
        p.line([p.at(0.18, 0.66), p.at(0.82, 0.66)])
        p.dot(p.at(0.50, 0.30), 0.09)
        p.line([p.at(0.52, 0.22), p.at(0.58, 0.12)])
    },
]

// MARK: - Tranche 2: Obst, Gemüse, Kräuter

/// **Vierundzwanzig Zeichen zu Tranche 2** (2026-08-07, Backend `50b724b`).
///
/// Aus Bring!s größter Kategorie. **Die Auswahl folgt der Unterscheidbarkeit,
/// nicht dem Katalog:** Sechs weitere Kräuter sind nicht dabei, weil Basilikum,
/// Minze, Salbei, Oregano und Estragon alle dasselbe Blattbüschel wären — und
/// fünf gleiche Büschel sind genau der Fehler, gegen den das Vorhaben läuft.
///
/// Die vier, die es hierher geschafft haben, sind es über ihre **Silhouette**:
/// Basilikum ein Zweig mit breiten Blattpaaren, Minze zwei gezähnte Blätter,
/// Schnittlauch ein Bündel Röhren mit Blüte, Dill eine Dolde aus Strichen.
private let tranche2: [String: ItemGlyph.Rezept] = [

    // Birne: oben schmal, unten bauchig — der Unterschied zum Apfel steckt
    // allein in der Taille, nicht im Stiel.
    "birnen": { p in
        p.begin(p.at(0.50, 0.20))
        p.bow(p.at(0.34, 0.52), p.at(0.42, 0.26), p.at(0.34, 0.40))
        p.bow(p.at(0.50, 0.92), p.at(0.34, 0.76), p.at(0.30, 0.92))
        p.bow(p.at(0.66, 0.52), p.at(0.70, 0.92), p.at(0.66, 0.76))
        p.bow(p.at(0.50, 0.20), p.at(0.66, 0.40), p.at(0.58, 0.26))
        p.close()
        p.line([p.at(0.50, 0.20), p.at(0.52, 0.08)])
        p.begin(p.at(0.52, 0.12))
        p.bow(p.at(0.74, 0.08), p.at(0.60, 0.04), p.at(0.72, 0.02))
        p.bow(p.at(0.52, 0.12), p.at(0.74, 0.14), p.at(0.62, 0.14))
    },

    // Feige: Tropfenform mit kurzem Stiel, dazu der aufgeschnittene Kern.
    "feigen": { p in
        p.begin(p.at(0.50, 0.20))
        p.bow(p.at(0.20, 0.62), p.at(0.34, 0.26), p.at(0.20, 0.44))
        p.bow(p.at(0.50, 0.90), p.at(0.20, 0.78), p.at(0.32, 0.90))
        p.bow(p.at(0.80, 0.62), p.at(0.68, 0.90), p.at(0.80, 0.78))
        p.bow(p.at(0.50, 0.20), p.at(0.80, 0.44), p.at(0.66, 0.26))
        p.close()
        // **Kein Kreuz im Bauch.** Ein senkrechter und ein waagerechter
        // Strich in einem Kreis sind das Apothekenzeichen, nicht das
        // Fruchtfleisch. Drei Kerne sagen dasselbe, ohne etwas anderes zu
        // behaupten.
        p.line([p.at(0.50, 0.20), p.at(0.50, 0.10)])
        p.line([p.at(0.42, 0.09), p.at(0.58, 0.09)])
        p.dot(p.at(0.42, 0.56), 0.045)
        p.dot(p.at(0.58, 0.58), 0.045)
        p.dot(p.at(0.50, 0.72), 0.045)
    },

    // Granatapfel: runde Frucht mit Krönchen und drei Kernen.
    "granatapfel": { p in
        p.circle(p.at(0.50, 0.58), 0.32)
        p.line([p.at(0.42, 0.28), p.at(0.40, 0.14), p.at(0.50, 0.20),
                p.at(0.60, 0.14), p.at(0.58, 0.28)])
        p.dot(p.at(0.42, 0.54), 0.05)
        p.dot(p.at(0.60, 0.56), 0.05)
        p.dot(p.at(0.50, 0.70), 0.05)
    },

    // Kaki: flache Kugel mit vier breiten Kelchblättern — die Blätter sind
    // das ganze Erkennungsmerkmal.
    "kaki": { p in
        // Der Kelch ist ein **vierzackiger Stern auf** der Frucht, keine
        // Kappe über ihr: Als durchgehender Bogen las sich das als Beutel.
        p.circle(p.at(0.50, 0.60), 0.32)
        p.line([p.at(0.30, 0.40), p.at(0.50, 0.46), p.at(0.70, 0.40)])
        p.line([p.at(0.42, 0.30), p.at(0.50, 0.46), p.at(0.58, 0.30)])
        p.line([p.at(0.50, 0.46), p.at(0.50, 0.24)])
    },

    // Litschi: runde Frucht mit genoppter Schale.
    "litschi": { p in
        p.circle(p.at(0.50, 0.56), 0.30)
        p.line([p.at(0.50, 0.26), p.at(0.54, 0.12)])
        p.dot(p.at(0.38, 0.46), 0.035)
        p.dot(p.at(0.58, 0.44), 0.035)
        p.dot(p.at(0.46, 0.60), 0.035)
        p.dot(p.at(0.64, 0.62), 0.035)
        p.dot(p.at(0.40, 0.72), 0.035)
    },

    // Papaya: halbiert, mit den Kernen im Hohlraum.
    "papaya": { p in
        p.begin(p.at(0.24, 0.28))
        p.bow(p.at(0.72, 0.84), p.at(0.42, 0.26), p.at(0.74, 0.56))
        p.bow(p.at(0.24, 0.28), p.at(0.66, 0.94), p.at(0.22, 0.62))
        p.close()
        p.dot(p.at(0.46, 0.56), 0.04)
        p.dot(p.at(0.56, 0.64), 0.04)
        p.dot(p.at(0.44, 0.70), 0.04)
    },

    // Rhabarber: zwei Stangen mit dem großen Blatt oben.
    "rhabarber": { p in
        // **Zwei Stangen mit je eigenem Blatt.** Ein einziges großes Blatt
        // über zwei Stielen war eine Tischplatte auf Beinen.
        p.line([p.at(0.34, 0.92), p.at(0.30, 0.40)])
        p.line([p.at(0.58, 0.92), p.at(0.62, 0.44)])
        p.begin(p.at(0.30, 0.40))
        p.bow(p.at(0.10, 0.16), p.at(0.18, 0.36), p.at(0.08, 0.26))
        p.bow(p.at(0.44, 0.22), p.at(0.16, 0.06), p.at(0.38, 0.08))
        p.bow(p.at(0.30, 0.40), p.at(0.46, 0.32), p.at(0.38, 0.36))
        p.close()
        p.begin(p.at(0.62, 0.44))
        p.bow(p.at(0.90, 0.22), p.at(0.72, 0.38), p.at(0.90, 0.32))
        p.bow(p.at(0.58, 0.26), p.at(0.90, 0.10), p.at(0.64, 0.10))
        p.bow(p.at(0.62, 0.44), p.at(0.54, 0.34), p.at(0.58, 0.40))
        p.close()
    },

    // Stachelbeere: Kugel mit Längsstreifen und Stiel.
    "stachelbeeren": { p in
        p.circle(p.at(0.50, 0.58), 0.30)
        p.begin(p.at(0.50, 0.28))
        p.bow(p.at(0.50, 0.88), p.at(0.30, 0.44), p.at(0.30, 0.72))
        p.begin(p.at(0.50, 0.28))
        p.bow(p.at(0.50, 0.88), p.at(0.70, 0.44), p.at(0.70, 0.72))
        p.line([p.at(0.50, 0.28), p.at(0.52, 0.12)])
    },

    // Quitte: birnenähnlich, aber gedrungener, mit Blatt am Stiel.
    "quitten": { p in
        p.begin(p.at(0.50, 0.24))
        p.bow(p.at(0.24, 0.56), p.at(0.34, 0.28), p.at(0.24, 0.42))
        p.bow(p.at(0.50, 0.92), p.at(0.24, 0.78), p.at(0.30, 0.92))
        p.bow(p.at(0.76, 0.56), p.at(0.70, 0.92), p.at(0.76, 0.78))
        p.bow(p.at(0.50, 0.24), p.at(0.76, 0.42), p.at(0.66, 0.28))
        p.close()
        p.line([p.at(0.50, 0.24), p.at(0.50, 0.10)])
        p.begin(p.at(0.50, 0.14))
        p.bow(p.at(0.76, 0.10), p.at(0.58, 0.06), p.at(0.74, 0.04))
        p.bow(p.at(0.50, 0.14), p.at(0.76, 0.16), p.at(0.60, 0.16))
    },

    // Fenchel: bauchige Knolle mit zwei Stängeln und Fiederblatt.
    "fenchel": { p in
        p.begin(p.at(0.50, 0.50))
        p.bow(p.at(0.22, 0.72), p.at(0.28, 0.52), p.at(0.22, 0.60))
        p.bow(p.at(0.50, 0.92), p.at(0.22, 0.86), p.at(0.34, 0.92))
        p.bow(p.at(0.78, 0.72), p.at(0.66, 0.92), p.at(0.78, 0.86))
        p.bow(p.at(0.50, 0.50), p.at(0.78, 0.60), p.at(0.72, 0.52))
        p.close()
        // **Die Stängel bleiben kurz und stehen dicht.** Weit gespreizt und
        // lang waren sie ein Geweih; das Fiederblatt oben macht daraus eine
        // Knolle mit Grün.
        p.line([p.at(0.44, 0.52), p.at(0.42, 0.28)])
        p.line([p.at(0.56, 0.52), p.at(0.58, 0.28)])
        p.line([p.at(0.42, 0.28), p.at(0.28, 0.16)])
        p.line([p.at(0.42, 0.28), p.at(0.40, 0.12)])
        p.line([p.at(0.58, 0.28), p.at(0.72, 0.16)])
        p.line([p.at(0.58, 0.28), p.at(0.60, 0.12)])
    },

    // Kohlkopf: Kugel mit umgeschlagenen äußeren Blättern.
    "kohl": { p in
        // **Die Blattadern gehen vom Strunk aus, nicht quer.** Zwei
        // waagerechte Bögen im Kreis lasen sich als Schale mit Sonnenaufgang.
        p.circle(p.at(0.50, 0.54), 0.32)
        p.line([p.at(0.50, 0.86), p.at(0.50, 0.36)])
        p.begin(p.at(0.50, 0.42))
        p.bow(p.at(0.20, 0.44), p.at(0.38, 0.28), p.at(0.24, 0.32))
        p.begin(p.at(0.50, 0.42))
        p.bow(p.at(0.80, 0.44), p.at(0.62, 0.28), p.at(0.76, 0.32))
        p.begin(p.at(0.50, 0.62))
        p.bow(p.at(0.24, 0.68), p.at(0.40, 0.54), p.at(0.28, 0.58))
        p.begin(p.at(0.50, 0.62))
        p.bow(p.at(0.76, 0.68), p.at(0.60, 0.54), p.at(0.72, 0.58))
    },

    // Kürbis: breite Kugel mit Rippen und Stiel.
    "kürbis": { p in
        p.circle(p.at(0.50, 0.60), 0.32)
        p.begin(p.at(0.50, 0.28))
        p.bow(p.at(0.50, 0.92), p.at(0.34, 0.44), p.at(0.34, 0.76))
        p.begin(p.at(0.50, 0.28))
        p.bow(p.at(0.50, 0.92), p.at(0.66, 0.44), p.at(0.66, 0.76))
        p.line([p.at(0.50, 0.28), p.at(0.50, 0.14)])
        p.line([p.at(0.50, 0.16), p.at(0.66, 0.10)])
    },

    // Lauchzwiebeln: zwei Röhren mit verdicktem weißen Ende unten.
    "lauchzwiebeln": { p in
        p.line([p.at(0.40, 0.72), p.at(0.30, 0.14)])
        p.line([p.at(0.54, 0.72), p.at(0.56, 0.12)])
        p.line([p.at(0.66, 0.74), p.at(0.76, 0.18)])
        p.begin(p.at(0.36, 0.68))
        p.bow(p.at(0.70, 0.70), p.at(0.36, 0.94), p.at(0.70, 0.94))
        p.close()
    },

    // Pastinake: lange spitze Wurzel mit Blattschopf.
    "pastinaken": { p in
        // **Senkrecht und nach unten spitz.** Schräg gelegt war die Wurzel
        // ein Stock zwischen anderen Stöcken.
        p.begin(p.at(0.34, 0.34))
        p.bow(p.at(0.50, 0.92), p.at(0.36, 0.62), p.at(0.44, 0.80))
        p.bow(p.at(0.66, 0.34), p.at(0.56, 0.80), p.at(0.64, 0.62))
        p.close()
        p.line([p.at(0.38, 0.42), p.at(0.24, 0.48)])
        p.line([p.at(0.62, 0.50), p.at(0.76, 0.56)])
        p.line([p.at(0.50, 0.34), p.at(0.50, 0.14)])
        p.line([p.at(0.50, 0.20), p.at(0.34, 0.10)])
        p.line([p.at(0.50, 0.20), p.at(0.66, 0.10)])
    },

    // Peperoni: gebogene Schote mit Stiel.
    "peperoni": { p in
        p.begin(p.at(0.34, 0.22))
        p.bow(p.at(0.60, 0.86), p.at(0.62, 0.34), p.at(0.66, 0.66))
        p.bow(p.at(0.34, 0.22), p.at(0.50, 0.84), p.at(0.44, 0.50))
        p.close()
        p.line([p.at(0.34, 0.22), p.at(0.24, 0.10)])
        p.line([p.at(0.24, 0.10), p.at(0.44, 0.12)])
    },

    // Rettich: dicke weiße Wurzel mit Blattschopf und Wurzelspitze.
    "rettich": { p in
        // **Oben rund, unten spitz** — und die Blätter sitzen als kurzes
        // Büschel obenauf. Zwei lange Striche nach außen waren ein Geweih.
        p.begin(p.at(0.50, 0.32))
        p.bow(p.at(0.26, 0.56), p.at(0.34, 0.32), p.at(0.26, 0.44))
        p.bow(p.at(0.50, 0.92), p.at(0.26, 0.72), p.at(0.42, 0.84))
        p.bow(p.at(0.74, 0.56), p.at(0.58, 0.84), p.at(0.74, 0.72))
        p.bow(p.at(0.50, 0.32), p.at(0.74, 0.44), p.at(0.66, 0.32))
        p.close()
        p.line([p.at(0.50, 0.32), p.at(0.50, 0.14)])
        p.line([p.at(0.50, 0.20), p.at(0.36, 0.10)])
        p.line([p.at(0.50, 0.20), p.at(0.64, 0.10)])
    },

    // Rosenkohl: kleines Röschen mit deutlich abgesetzten Blättern.
    "rosenkohl": { p in
        p.begin(p.at(0.50, 0.20))
        p.bow(p.at(0.26, 0.60), p.at(0.34, 0.26), p.at(0.26, 0.42))
        p.bow(p.at(0.50, 0.86), p.at(0.26, 0.76), p.at(0.34, 0.86))
        p.bow(p.at(0.74, 0.60), p.at(0.66, 0.86), p.at(0.74, 0.76))
        p.bow(p.at(0.50, 0.20), p.at(0.74, 0.42), p.at(0.66, 0.26))
        p.close()
        p.line([p.at(0.50, 0.22), p.at(0.50, 0.84)])
        p.begin(p.at(0.30, 0.44))
        p.bow(p.at(0.70, 0.44), p.at(0.40, 0.62), p.at(0.60, 0.62))
    },

    // Staudensellerie: Bündel Stangen mit Blattgrün.
    "sellerie": { p in
        p.line([p.at(0.38, 0.90), p.at(0.32, 0.36)])
        p.line([p.at(0.50, 0.92), p.at(0.50, 0.34)])
        p.line([p.at(0.62, 0.90), p.at(0.68, 0.36)])
        p.begin(p.at(0.32, 0.36))
        p.bow(p.at(0.20, 0.16), p.at(0.24, 0.30), p.at(0.18, 0.24))
        p.begin(p.at(0.50, 0.34))
        p.bow(p.at(0.50, 0.12), p.at(0.42, 0.24), p.at(0.44, 0.16))
        p.begin(p.at(0.68, 0.36))
        p.bow(p.at(0.80, 0.16), p.at(0.76, 0.30), p.at(0.82, 0.24))
        p.line([p.at(0.34, 0.72), p.at(0.66, 0.72)])
    },

    // Grünkohl: krause Blätter, der Kraus ist das Merkmal.
    "grünkohl": { p in
        // **Drei krause Blätter statt einer Krone.** Ein einzelner Ballen auf
        // einem Stiel ist ein Baum, egal wie krauß sein Rand ist.
        p.line([p.at(0.50, 0.92), p.at(0.50, 0.56)])
        for (mx, my, w) in [(0.24, 0.42, -1.0), (0.50, 0.28, 0.0), (0.76, 0.42, 1.0)] {
            p.begin(p.at(0.50, 0.58))
            p.bow(p.at(mx + w * 0.10, my - 0.16),
                  p.at(mx - 0.14, my + 0.10), p.at(mx - 0.16, my - 0.06))
            p.bow(p.at(0.50, 0.58),
                  p.at(mx + 0.18, my - 0.04), p.at(mx + 0.10, my + 0.14))
            p.close()
        }
    },

    // Basilikum: Zweig mit zwei Paar breiten Blättern.
    "basilikum": { p in
        p.line([p.at(0.50, 0.92), p.at(0.50, 0.24)])
        blatt(&p, von: (0.50, 0.42), nach: (0.16, 0.28), bauch: 0.13)
        blatt(&p, von: (0.50, 0.42), nach: (0.84, 0.28), bauch: -0.13)
        blatt(&p, von: (0.50, 0.66), nach: (0.20, 0.58), bauch: 0.11)
        blatt(&p, von: (0.50, 0.66), nach: (0.80, 0.58), bauch: -0.11)
    },

    // Minze: zwei Blätter mit gezähntem Rand und Mittelrippe.
    "minze": { p in
        p.line([p.at(0.50, 0.92), p.at(0.50, 0.46)])
        p.begin(p.at(0.50, 0.50))
        p.bow(p.at(0.20, 0.14), p.at(0.28, 0.48), p.at(0.16, 0.32))
        p.bow(p.at(0.50, 0.50), p.at(0.34, 0.20), p.at(0.44, 0.34))
        p.line([p.at(0.50, 0.50), p.at(0.24, 0.20)])
        p.begin(p.at(0.50, 0.58))
        p.bow(p.at(0.82, 0.28), p.at(0.66, 0.56), p.at(0.82, 0.44))
        p.bow(p.at(0.50, 0.58), p.at(0.72, 0.32), p.at(0.58, 0.44))
        p.line([p.at(0.50, 0.58), p.at(0.78, 0.34)])
    },

    // Schnittlauch: Bündel Röhren, eine mit Blüte. Die Blüte trennt ihn vom
    // Weizengras.
    "schnittlauch": { p in
        p.line([p.at(0.34, 0.92), p.at(0.24, 0.28)])
        p.line([p.at(0.46, 0.92), p.at(0.46, 0.18)])
        p.line([p.at(0.58, 0.92), p.at(0.66, 0.30)])
        p.line([p.at(0.70, 0.92), p.at(0.80, 0.44)])
        p.circle(p.at(0.46, 0.13), 0.09)
    },

    // Dill: Dolde aus feinen Strichen an einem Stiel.
    "dill": { p in
        p.line([p.at(0.50, 0.92), p.at(0.50, 0.34)])
        p.line([p.at(0.50, 0.34), p.at(0.16, 0.14)])
        p.line([p.at(0.50, 0.34), p.at(0.32, 0.10)])
        p.line([p.at(0.50, 0.34), p.at(0.50, 0.08)])
        p.line([p.at(0.50, 0.34), p.at(0.68, 0.10)])
        p.line([p.at(0.50, 0.34), p.at(0.84, 0.14)])
        p.line([p.at(0.50, 0.60), p.at(0.26, 0.48)])
        p.line([p.at(0.50, 0.60), p.at(0.74, 0.48)])
    },

    // Petersilie: krause Büschel an drei Stielen — der Kraus unterscheidet
    // sie von Dills geraden Strichen.
    "petersilie": { p in
        p.line([p.at(0.50, 0.92), p.at(0.50, 0.52)])
        p.line([p.at(0.50, 0.62), p.at(0.30, 0.44)])
        p.line([p.at(0.50, 0.62), p.at(0.70, 0.44)])
        p.circle(p.at(0.28, 0.36), 0.13)
        p.circle(p.at(0.50, 0.28), 0.15)
        p.circle(p.at(0.72, 0.36), 0.13)
    },
]

// MARK: - Tranche 3: Brot, Milchprodukte, Fleisch & Fisch

/// **Dreiundzwanzig Zeichen zu Tranche 3** (2026-08-07, Backend `Tranche 3`).
///
/// Konkrete Gegenstände — die zeichnen sich am sichersten. Sechs Käse in
/// einer Kategorie sind trotzdem eine Falle: Sie unterscheiden sich nicht in
/// der Silhouette, sondern in der **Form, in der man sie kauft** — Ecke,
/// Beutel, Rad, Becher, Pfanne. Danach ist hier gezeichnet.
private let tranche3: [String: ItemGlyph.Rezept] = [

    // Bagel: Ring mit Loch und Saatkörnern. Das Loch trennt ihn vom Brötchen.
    "bagel": { p in
        p.circle(p.at(0.50, 0.52), 0.34)
        p.circle(p.at(0.50, 0.52), 0.12)
        p.dot(p.at(0.34, 0.32), 0.03)
        p.dot(p.at(0.66, 0.34), 0.03)
        p.dot(p.at(0.30, 0.68), 0.03)
        p.dot(p.at(0.70, 0.70), 0.03)
    },

    // Burgerbrötchen: Deckel, Sesam, Boden — die Fuge in der Mitte ist das,
    // was es vom Kieselstein trennt.
    "burgerbrötchen": { p in
        p.begin(p.at(0.14, 0.48))
        p.bow(p.at(0.86, 0.48), p.at(0.20, 0.14), p.at(0.80, 0.14))
        p.close()
        p.line([p.at(0.14, 0.58), p.at(0.86, 0.58)])
        p.begin(p.at(0.16, 0.66))
        p.bow(p.at(0.84, 0.66), p.at(0.22, 0.86), p.at(0.78, 0.86))
        p.close()
        p.dot(p.at(0.38, 0.32), 0.03)
        p.dot(p.at(0.58, 0.28), 0.03)
        p.dot(p.at(0.68, 0.38), 0.03)
    },

    // Croissant: Sichel mit angesetzten Hörnern.
    "croissant": { p in
        // **Die Hörner müssen sich nach innen krümmen.** Ein Bogen mit zwei
        // geraden Enden ist eine Brücke; erst die eingerollten Spitzen machen
        // die Sichel.
        p.begin(p.at(0.14, 0.74))
        p.bow(p.at(0.86, 0.74), p.at(0.20, 0.20), p.at(0.80, 0.20))
        p.bow(p.at(0.14, 0.74), p.at(0.74, 0.52), p.at(0.26, 0.52))
        p.close()
        p.begin(p.at(0.14, 0.74))
        p.bow(p.at(0.26, 0.86), p.at(0.06, 0.84), p.at(0.16, 0.90))
        p.begin(p.at(0.86, 0.74))
        p.bow(p.at(0.74, 0.86), p.at(0.94, 0.84), p.at(0.84, 0.90))
        p.line([p.at(0.38, 0.42), p.at(0.34, 0.62)])
        p.line([p.at(0.62, 0.42), p.at(0.66, 0.62)])
    },

    // Teig: Rolle mit Nudelholz darüber.
    "pizzateig": { p in
        p.begin(p.at(0.14, 0.74))
        p.bow(p.at(0.86, 0.74), p.at(0.30, 0.58), p.at(0.70, 0.58))
        p.bow(p.at(0.14, 0.74), p.at(0.70, 0.90), p.at(0.30, 0.90))
        p.close()
        p.capsule(0.50, 0.36, 0.56, 0.14, tilt: -8)
        p.line([p.at(0.16, 0.32), p.at(0.06, 0.30)])
        p.line([p.at(0.84, 0.40), p.at(0.94, 0.42)])
    },

    // Roggenbrot: dunkler Laib, kastiger als das Weißbrot, mit Kerben.
    "roggenbrot": { p in
        p.begin(p.at(0.12, 0.72))
        p.bow(p.at(0.88, 0.72), p.at(0.14, 0.28), p.at(0.86, 0.28))
        p.close()
        p.line([p.at(0.30, 0.44), p.at(0.38, 0.34)])
        p.line([p.at(0.46, 0.42), p.at(0.54, 0.32)])
        p.line([p.at(0.62, 0.44), p.at(0.70, 0.34)])
        p.line([p.at(0.12, 0.60), p.at(0.88, 0.60)])
    },

    // Zimtschnecke: Spirale von oben, im Papierförmchen.
    "zimtschnecken": { p in
        p.circle(p.at(0.50, 0.50), 0.34)
        p.begin(p.at(0.50, 0.24))
        p.bow(p.at(0.50, 0.66), p.at(0.74, 0.28), p.at(0.72, 0.62))
        p.bow(p.at(0.44, 0.44), p.at(0.34, 0.68), p.at(0.34, 0.46))
        p.bow(p.at(0.56, 0.48), p.at(0.50, 0.40), p.at(0.56, 0.42))
        p.line([p.at(0.20, 0.80), p.at(0.80, 0.80)])
    },

    // Pflanzendrink: Karton mit Halm — dasselbe Gefäß wie die Säfte, aber mit
    // Ähre statt Frucht.
    "pflanzendrink": { p in
        p.line([p.at(0.24, 0.34), p.at(0.24, 0.92), p.at(0.70, 0.92),
                p.at(0.70, 0.34)], closed: true)
        p.line([p.at(0.24, 0.34), p.at(0.38, 0.22), p.at(0.70, 0.22),
                p.at(0.70, 0.34)])
        p.line([p.at(0.38, 0.22), p.at(0.38, 0.34), p.at(0.70, 0.34)])
        p.line([p.at(0.47, 0.80), p.at(0.47, 0.48)])
        p.line([p.at(0.47, 0.56), p.at(0.34, 0.48)])
        p.line([p.at(0.47, 0.56), p.at(0.60, 0.48)])
        p.line([p.at(0.47, 0.68), p.at(0.34, 0.60)])
        p.line([p.at(0.47, 0.68), p.at(0.60, 0.60)])
    },

    // Hüttenkäse: Becher mit Deckelfolie und Körnung.
    "hüttenkäse": { p in
        p.line([p.at(0.20, 0.32), p.at(0.80, 0.32)])
        p.begin(p.at(0.24, 0.32))
        p.to(p.at(0.32, 0.88))
        p.to(p.at(0.68, 0.88))
        p.to(p.at(0.76, 0.32))
        p.close()
        p.dot(p.at(0.42, 0.52), 0.04)
        p.dot(p.at(0.58, 0.56), 0.04)
        p.dot(p.at(0.48, 0.70), 0.04)
    },

    // Magerquark: derselbe Becher, aber glatt und mit Löffel — die Körnung
    // ist genau der Unterschied zum Hüttenkäse.
    "magerquark": { p in
        p.line([p.at(0.18, 0.36), p.at(0.74, 0.36)])
        p.begin(p.at(0.22, 0.36))
        p.to(p.at(0.30, 0.90))
        p.to(p.at(0.66, 0.90))
        p.to(p.at(0.72, 0.36))
        p.close()
        p.line([p.at(0.60, 0.36), p.at(0.80, 0.14)])
        p.begin(p.at(0.80, 0.14))
        p.bow(p.at(0.92, 0.24), p.at(0.90, 0.10), p.at(0.94, 0.16))
        p.bow(p.at(0.80, 0.14), p.at(0.88, 0.28), p.at(0.80, 0.22))
    },

    // Raclette: Pfännchen mit Stiel — so kauft man ihn nicht, aber so kennt
    // man ihn, und darum geht es beim Erkennen.
    "raclettekäse": { p in
        p.begin(p.at(0.16, 0.44))
        p.to(p.at(0.16, 0.70))
        p.bow(p.at(0.64, 0.70), p.at(0.16, 0.86), p.at(0.64, 0.86))
        p.to(p.at(0.64, 0.44))
        p.close()
        p.line([p.at(0.64, 0.52), p.at(0.94, 0.44)])
        p.line([p.at(0.24, 0.36), p.at(0.56, 0.36)])
        p.line([p.at(0.24, 0.36), p.at(0.24, 0.44)])
        p.line([p.at(0.56, 0.36), p.at(0.56, 0.44)])
    },

    // Reibekäse: Beutel mit Streifen. Der Beutel ist die Kaufform.
    "reibekäse": { p in
        p.line([p.at(0.26, 0.24), p.at(0.74, 0.24), p.at(0.78, 0.88),
                p.at(0.22, 0.88)], closed: true)
        p.line([p.at(0.26, 0.24), p.at(0.34, 0.14), p.at(0.50, 0.22),
                p.at(0.66, 0.14), p.at(0.74, 0.24)])
        p.line([p.at(0.32, 0.48), p.at(0.46, 0.44)])
        p.line([p.at(0.52, 0.56), p.at(0.68, 0.52)])
        p.line([p.at(0.32, 0.68), p.at(0.48, 0.64)])
        p.line([p.at(0.54, 0.76), p.at(0.68, 0.72)])
    },

    // Ricotta: runder Becher mit Deckel, glatt.
    "ricotta": { p in
        p.begin(p.at(0.20, 0.40))
        p.bow(p.at(0.80, 0.40), p.at(0.20, 0.24), p.at(0.80, 0.24))
        p.bow(p.at(0.20, 0.40), p.at(0.80, 0.56), p.at(0.20, 0.56))
        p.close()
        p.line([p.at(0.20, 0.40), p.at(0.24, 0.80)])
        p.line([p.at(0.80, 0.40), p.at(0.76, 0.80)])
        p.begin(p.at(0.24, 0.80))
        p.bow(p.at(0.76, 0.80), p.at(0.30, 0.92), p.at(0.70, 0.92))
    },

    // Grillkäse: Scheibe mit Grillstreifen.
    "grillkäse": { p in
        p.line([p.at(0.16, 0.34), p.at(0.84, 0.34), p.at(0.84, 0.74),
                p.at(0.16, 0.74)], closed: true)
        p.line([p.at(0.28, 0.34), p.at(0.20, 0.74)])
        p.line([p.at(0.48, 0.34), p.at(0.40, 0.74)])
        p.line([p.at(0.68, 0.34), p.at(0.60, 0.74)])
        p.line([p.at(0.86, 0.36), p.at(0.80, 0.66)])
    },

    // Sojajoghurt: Becher mit Blatt — das Blatt sagt „pflanzlich", ohne dass
    // es jemand lesen muss.
    "sojajoghurt": { p in
        p.line([p.at(0.20, 0.42), p.at(0.76, 0.42)])
        p.begin(p.at(0.24, 0.42))
        p.to(p.at(0.32, 0.90))
        p.to(p.at(0.68, 0.90))
        p.to(p.at(0.72, 0.42))
        blatt(&p, von: (0.48, 0.38), nach: (0.76, 0.14), bauch: -0.10)
        p.line([p.at(0.48, 0.38), p.at(0.66, 0.24)])
    },

    // Kaffeerahm: kleines Döschen mit abgezogener Ecke.
    "kaffeerahm": { p in
        p.begin(p.at(0.22, 0.44))
        p.to(p.at(0.30, 0.82))
        p.to(p.at(0.70, 0.82))
        p.to(p.at(0.78, 0.44))
        p.close()
        p.line([p.at(0.22, 0.44), p.at(0.62, 0.44)])
        p.begin(p.at(0.62, 0.44))
        p.bow(p.at(0.86, 0.24), p.at(0.74, 0.42), p.at(0.86, 0.34))
        p.line([p.at(0.86, 0.24), p.at(0.78, 0.44)])
    },

    // Bacon: zwei gewellte Streifen mit Fettrand.
    "bacon": { p in
        p.begin(p.at(0.10, 0.36))
        p.bow(p.at(0.90, 0.34), p.at(0.34, 0.16), p.at(0.66, 0.52))
        p.bow(p.at(0.10, 0.52), p.at(0.66, 0.66), p.at(0.34, 0.32))
        p.close()
        p.begin(p.at(0.10, 0.60))
        p.bow(p.at(0.90, 0.58), p.at(0.34, 0.40), p.at(0.66, 0.76))
        p.bow(p.at(0.10, 0.76), p.at(0.66, 0.90), p.at(0.34, 0.56))
        p.close()
    },

    // Fleischwurst: Ring mit Zipfel — die Ringform ist ihr Merkmal.
    "fleischwurst": { p in
        p.circle(p.at(0.50, 0.54), 0.32)
        p.circle(p.at(0.50, 0.54), 0.14)
        p.line([p.at(0.50, 0.22), p.at(0.50, 0.10)])
        p.line([p.at(0.42, 0.12), p.at(0.58, 0.12)])
    },

    // Kassler: Stück am Knochen, mit Fettrand.
    "kassler": { p in
        p.begin(p.at(0.26, 0.34))
        p.bow(p.at(0.80, 0.44), p.at(0.52, 0.24), p.at(0.76, 0.30))
        p.bow(p.at(0.52, 0.86), p.at(0.84, 0.62), p.at(0.70, 0.84))
        p.bow(p.at(0.26, 0.34), p.at(0.28, 0.86), p.at(0.20, 0.54))
        p.close()
        p.circle(p.at(0.36, 0.50), 0.09)
        p.line([p.at(0.62, 0.40), p.at(0.70, 0.72)])
    },

    // Schinken: Keule mit Knochenende.
    "schinken": { p in
        // **Der Knochen liegt in der Keule, nicht an einer Schnur.** Ein
        // Kreis am dünnen Stiel war ein Luftballon; jetzt ist der Knochen ein
        // kurzer Stummel mit zwei Köpfen, wie man ihn am Schinken sieht.
        p.begin(p.at(0.36, 0.30))
        p.bow(p.at(0.80, 0.58), p.at(0.66, 0.26), p.at(0.84, 0.40))
        p.bow(p.at(0.40, 0.88), p.at(0.74, 0.82), p.at(0.54, 0.90))
        p.bow(p.at(0.36, 0.30), p.at(0.22, 0.80), p.at(0.18, 0.46))
        p.close()
        p.line([p.at(0.34, 0.28), p.at(0.24, 0.14)])
        p.circle(p.at(0.20, 0.10), 0.07)
        p.circle(p.at(0.32, 0.14), 0.06)
        // **Zwei Einschnitte statt einem.** Ein einzelner Strich im Körper ist
        // eine Kerbe; zwei parallele im Abstand 0,136 sind das eingeschnittene
        // Rautenmuster, das man auf einer Schinkenkruste sieht. Enger ginge
        // nicht — unter 0,13 laufen sie bei 40 pt zu einem Balken zusammen.
        p.line([p.at(0.40, 0.48), p.at(0.66, 0.56)])
        p.line([p.at(0.36, 0.62), p.at(0.62, 0.70)])
    },

    // Muscheln: aufgeklappte Schale mit Rippen.
    "muscheln": { p in
        p.begin(p.at(0.50, 0.82))
        p.bow(p.at(0.12, 0.34), p.at(0.24, 0.78), p.at(0.12, 0.54))
        p.bow(p.at(0.88, 0.34), p.at(0.30, 0.10), p.at(0.70, 0.10))
        p.bow(p.at(0.50, 0.82), p.at(0.88, 0.54), p.at(0.76, 0.78))
        p.close()
        p.line([p.at(0.50, 0.82), p.at(0.34, 0.26)])
        p.line([p.at(0.50, 0.82), p.at(0.50, 0.20)])
        p.line([p.at(0.50, 0.82), p.at(0.66, 0.26)])
    },

    // Sardellen: zwei schlanke Fische, in der Dose gedacht.
    "sardellen": { p in
        p.begin(p.at(0.14, 0.36))
        p.bow(p.at(0.76, 0.36), p.at(0.34, 0.22), p.at(0.60, 0.22))
        p.bow(p.at(0.14, 0.36), p.at(0.60, 0.50), p.at(0.34, 0.50))
        p.close()
        p.line([p.at(0.76, 0.36), p.at(0.90, 0.26), p.at(0.90, 0.46)], closed: true)
        p.begin(p.at(0.14, 0.66))
        p.bow(p.at(0.76, 0.66), p.at(0.34, 0.52), p.at(0.60, 0.52))
        p.bow(p.at(0.14, 0.66), p.at(0.60, 0.80), p.at(0.34, 0.80))
        p.close()
        p.line([p.at(0.76, 0.66), p.at(0.90, 0.56), p.at(0.90, 0.76)], closed: true)
    },

    // Schnitzel: paniertes Stück mit gewelltem Rand und Zitronenspalte.
    "schnitzel": { p in
        // **Der Rand muss wellig sein.** Ein rundes Stück mit drei Punkten
        // darin ist ein Keks mit Schokostückchen; die Wellen sind das, was
        // paniertes Fleisch von Gebäck trennt. Dazu die Zitronenspalte.
        p.begin(p.at(0.40, 0.20))
        p.bow(p.at(0.62, 0.30), p.at(0.50, 0.16), p.at(0.60, 0.20))
        p.bow(p.at(0.80, 0.46), p.at(0.68, 0.36), p.at(0.82, 0.36))
        p.bow(p.at(0.72, 0.70), p.at(0.78, 0.58), p.at(0.66, 0.60))
        p.bow(p.at(0.46, 0.84), p.at(0.76, 0.82), p.at(0.56, 0.82))
        p.bow(p.at(0.22, 0.66), p.at(0.34, 0.88), p.at(0.20, 0.80))
        p.bow(p.at(0.26, 0.40), p.at(0.24, 0.54), p.at(0.18, 0.46))
        p.bow(p.at(0.40, 0.20), p.at(0.32, 0.30), p.at(0.30, 0.22))
        p.close()
        p.dot(p.at(0.42, 0.44), 0.03)
        p.dot(p.at(0.56, 0.56), 0.03)
        p.dot(p.at(0.38, 0.64), 0.03)
    },

    // Steak: Stück mit Knochen an der Seite und Grillstreifen.
    "steak": { p in
        p.begin(p.at(0.34, 0.26))
        p.bow(p.at(0.86, 0.52), p.at(0.66, 0.22), p.at(0.86, 0.34))
        p.bow(p.at(0.38, 0.84), p.at(0.86, 0.72), p.at(0.62, 0.86))
        p.bow(p.at(0.34, 0.26), p.at(0.18, 0.80), p.at(0.14, 0.38))
        p.close()
        p.line([p.at(0.46, 0.40), p.at(0.70, 0.46)])
        p.line([p.at(0.42, 0.56), p.at(0.72, 0.62)])
        p.line([p.at(0.44, 0.70), p.at(0.66, 0.74)])
    },
]

// MARK: - Tranche 4: Getränke, Süßwaren, Getreide

/// **Fünfundzwanzig Zeichen zu Tranche 4** (2026-08-07).
///
/// Die schwierigste Gruppe bisher: Bonbons, Lollis, Kaugummi und Plätzchen
/// sind alle „etwas Kleines, Süßes". Getrennt sind sie hier über **Verpackung
/// und Haltung** — der Lolli am Stiel, das Bonbon im gedrehten Papier, der
/// Kaugummistreifen in der Hülle, das Plätzchen als Stern.
private let tranche4: [String: ItemGlyph.Rezept] = [

    // Cornflakes: Schale mit Flocken und Löffel.
    "cornflakes": { p in
        p.begin(p.at(0.10, 0.50))
        p.bow(p.at(0.78, 0.50), p.at(0.16, 0.88), p.at(0.72, 0.88))
        p.close()
        p.line([p.at(0.68, 0.46), p.at(0.90, 0.20)])
        p.begin(p.at(0.90, 0.20))
        p.bow(p.at(0.80, 0.36), p.at(0.98, 0.22), p.at(0.90, 0.36))
        p.close()
        p.dot(p.at(0.28, 0.42), 0.05)
        p.dot(p.at(0.48, 0.38), 0.05)
    },

    // Couscous: Schale mit feinem Korn — die Körnung ist der Unterschied zu
    // den Flocken darüber.
    "couscous": { p in
        p.begin(p.at(0.14, 0.52))
        p.bow(p.at(0.86, 0.52), p.at(0.20, 0.90), p.at(0.80, 0.90))
        p.close()
        p.begin(p.at(0.22, 0.52))
        p.bow(p.at(0.78, 0.52), p.at(0.34, 0.32), p.at(0.66, 0.32))
        p.dot(p.at(0.38, 0.44), 0.03)
        p.dot(p.at(0.52, 0.40), 0.03)
        p.dot(p.at(0.64, 0.46), 0.03)
    },

    // Grieß: Tüte mit Ausguss und rieselndem Korn.
    "grieß": { p in
        p.line([p.at(0.20, 0.30), p.at(0.60, 0.30), p.at(0.64, 0.90),
                p.at(0.16, 0.90)], closed: true)
        p.line([p.at(0.20, 0.30), p.at(0.30, 0.18), p.at(0.50, 0.24),
                p.at(0.60, 0.30)])
        p.dot(p.at(0.76, 0.40), 0.03)
        p.dot(p.at(0.84, 0.54), 0.03)
        p.dot(p.at(0.78, 0.68), 0.03)
    },

    // Glasnudeln: dünnes Bündel mit Bandage in der Mitte.
    "glasnudeln": { p in
        // **Gewellt, nicht gerade.** Vier senkrechte Striche mit zwei
        // Querbalken sind ein Gartenzaun; erst der Schwung macht sie zu
        // Nudeln. Die Bandage bleibt, sie hält das Bündel zusammen.
        for (i, x) in [0.24, 0.40, 0.56, 0.72].enumerated() {
            let v = CGFloat(x) + (i.isMultiple(of: 2) ? 0.0 : 0.02)
            p.begin(p.at(v, 0.12))
            p.bow(p.at(v + 0.04, 0.50), p.at(v - 0.08, 0.28), p.at(v + 0.10, 0.36))
            p.bow(p.at(v - 0.02, 0.90), p.at(v - 0.02, 0.66), p.at(v + 0.08, 0.76))
        }
        p.line([p.at(0.14, 0.48), p.at(0.86, 0.46)])
        p.line([p.at(0.14, 0.60), p.at(0.86, 0.58)])
    },

    // Spätzle: drei kurze, gebogene Klöße auf einem Haufen.
    "spätzle": { p in
        p.capsule(0.36, 0.38, 0.16, 0.40, tilt: -60)
        p.capsule(0.62, 0.46, 0.16, 0.40, tilt: 40)
        p.capsule(0.44, 0.68, 0.16, 0.44, tilt: -15)
        p.capsule(0.70, 0.74, 0.14, 0.32, tilt: 70)
    },

    // Lasagneblätter: gestapelte Platten mit gewelltem Rand.
    "lasagneblätter": { p in
        for y in [0.36, 0.54, 0.72] {
            p.line([p.at(0.16, CGFloat(y)), p.at(0.84, CGFloat(y) - 0.06)])
            p.line([p.at(0.16, CGFloat(y) + 0.10), p.at(0.84, CGFloat(y) + 0.04)])
            p.line([p.at(0.16, CGFloat(y)), p.at(0.16, CGFloat(y) + 0.10)])
            p.line([p.at(0.84, CGFloat(y) - 0.06), p.at(0.84, CGFloat(y) + 0.04)])
        }
    },

    // Chiasamen: Löffel voll feiner Körner.
    "chiasamen": { p in
        p.begin(p.at(0.22, 0.52))
        p.bow(p.at(0.66, 0.52), p.at(0.22, 0.82), p.at(0.66, 0.82))
        p.close()
        p.line([p.at(0.64, 0.56), p.at(0.90, 0.34)])
        p.dot(p.at(0.34, 0.46), 0.03)
        p.dot(p.at(0.46, 0.42), 0.03)
        p.dot(p.at(0.56, 0.46), 0.03)
        p.dot(p.at(0.40, 0.34), 0.03)
    },

    // Reispapier: runde Blätter, halb durchscheinend gedacht.
    "reispapier": { p in
        // **Zwei Kreise nebeneinander sind ein Mengendiagramm**, und ein
        // Kreis mit einer Kerbe ist ein angebissener Keks. Reispapier sind
        // **runde Blätter im Stapel**: zwei Scheiben leicht versetzt, die
        // obere durchscheinend gedacht, dazu die Kante des Stapels.
        p.circle(p.at(0.44, 0.42), 0.30)
        p.circle(p.at(0.58, 0.58), 0.30)
        p.line([p.at(0.28, 0.86), p.at(0.74, 0.86)])
    },

    // Tempeh: Block mit sichtbaren Bohnen im Schnitt.
    "tempeh": { p in
        p.line([p.at(0.14, 0.32), p.at(0.86, 0.32), p.at(0.86, 0.74),
                p.at(0.14, 0.74)], closed: true)
        p.dot(p.at(0.30, 0.46), 0.045)
        p.dot(p.at(0.50, 0.42), 0.045)
        p.dot(p.at(0.68, 0.48), 0.045)
        p.dot(p.at(0.38, 0.62), 0.045)
        p.dot(p.at(0.60, 0.62), 0.045)
    },

    // Bonbon: Kugel im gedrehten Papier — die zwei Zipfel sind das Zeichen.
    "bonbons": { p in
        p.circle(p.at(0.50, 0.52), 0.20)
        p.line([p.at(0.30, 0.52), p.at(0.10, 0.34), p.at(0.14, 0.56),
                p.at(0.08, 0.72), p.at(0.30, 0.54)])
        p.line([p.at(0.70, 0.52), p.at(0.90, 0.34), p.at(0.86, 0.56),
                p.at(0.92, 0.72), p.at(0.70, 0.54)])
    },

    // Kaugummi: Streifen in der Hülle, einer halb herausgezogen.
    "kaugummi": { p in
        p.line([p.at(0.24, 0.30), p.at(0.62, 0.30), p.at(0.62, 0.88),
                p.at(0.24, 0.88)], closed: true)
        p.line([p.at(0.62, 0.36), p.at(0.86, 0.24), p.at(0.86, 0.68),
                p.at(0.62, 0.80)])
        p.line([p.at(0.30, 0.44), p.at(0.56, 0.44)])
        p.line([p.at(0.30, 0.58), p.at(0.56, 0.58)])
    },

    // Lolli: Kugel am Stiel mit Spirale.
    "lollis": { p in
        p.circle(p.at(0.50, 0.36), 0.26)
        p.begin(p.at(0.50, 0.36))
        p.bow(p.at(0.50, 0.16), p.at(0.62, 0.34), p.at(0.62, 0.18))
        p.bow(p.at(0.50, 0.58), p.at(0.30, 0.14), p.at(0.28, 0.58))
        p.line([p.at(0.50, 0.62), p.at(0.50, 0.92)])
    },

    // Plätzchen: Stern mit Zuckerpunkt.
    "plätzchen": { p in
        var punkte: [CGPoint] = []
        for i in 0..<12 {
            let w = Double(i) / 12 * 2 * Double.pi - Double.pi / 2
            let r: CGFloat = i.isMultiple(of: 2) ? 0.38 : 0.18
            punkte.append(p.at(0.50 + r * CGFloat(cos(w)), 0.52 + r * CGFloat(sin(w))))
        }
        p.line(punkte, closed: true)
        p.dot(p.at(0.50, 0.52), 0.06)
    },

    // Popcorn: Tüte mit gestreiftem Papier und überquellenden Puffs.
    "popcorn": { p in
        p.line([p.at(0.26, 0.46), p.at(0.74, 0.46), p.at(0.68, 0.92),
                p.at(0.32, 0.92)], closed: true)
        p.line([p.at(0.42, 0.46), p.at(0.40, 0.92)])
        p.line([p.at(0.58, 0.46), p.at(0.60, 0.92)])
        p.circle(p.at(0.36, 0.32), 0.11)
        p.circle(p.at(0.60, 0.26), 0.12)
        p.circle(p.at(0.72, 0.40), 0.09)
    },

    // Nougatcreme: Glas mit Deckel und Messer daneben.
    "nougatcreme": { p in
        p.line([p.at(0.24, 0.24), p.at(0.62, 0.24)])
        p.line([p.at(0.24, 0.24), p.at(0.22, 0.34)])
        p.line([p.at(0.62, 0.24), p.at(0.64, 0.34)])
        p.line([p.at(0.22, 0.34), p.at(0.22, 0.88), p.at(0.64, 0.88),
                p.at(0.64, 0.34)], closed: true)
        p.line([p.at(0.28, 0.52), p.at(0.58, 0.52)])
        p.line([p.at(0.78, 0.28), p.at(0.86, 0.72)])
        p.line([p.at(0.78, 0.28), p.at(0.72, 0.44), p.at(0.82, 0.50)])
    },

    // Dörrobst: drei geschrumpfte Scheiben mit welligem Rand.
    "dörrobst": { p in
        for (cx, cy, r) in [(0.32, 0.36, 0.19), (0.66, 0.44, 0.17), (0.44, 0.72, 0.18)] {
            var pk: [CGPoint] = []
            for i in 0..<10 {
                let w = Double(i) / 10 * 2 * Double.pi
                let rr = CGFloat(r) * (i.isMultiple(of: 2) ? 1.0 : 0.74)
                pk.append(p.at(CGFloat(cx) + rr * CGFloat(cos(w)),
                               CGFloat(cy) + rr * CGFloat(sin(w))))
            }
            p.line(pk, closed: true)
        }
    },

    // Gelee: Glas mit Schraubdeckel und Fruchtstück.
    "gelee": { p in
        p.line([p.at(0.28, 0.18), p.at(0.72, 0.18), p.at(0.72, 0.30),
                p.at(0.28, 0.30)], closed: true)
        p.line([p.at(0.28, 0.30), p.at(0.24, 0.88), p.at(0.76, 0.88),
                p.at(0.72, 0.30)])
        p.circle(p.at(0.50, 0.60), 0.14)
    },

    // Kuvertüre: Tafel mit abgebrochenem Stück.
    "kuvertüre": { p in
        p.line([p.at(0.16, 0.30), p.at(0.72, 0.30), p.at(0.72, 0.82),
                p.at(0.16, 0.82)], closed: true)
        p.line([p.at(0.34, 0.30), p.at(0.34, 0.82)])
        p.line([p.at(0.53, 0.30), p.at(0.53, 0.82)])
        p.line([p.at(0.16, 0.56), p.at(0.72, 0.56)])
        p.line([p.at(0.72, 0.42), p.at(0.90, 0.36), p.at(0.90, 0.66),
                p.at(0.72, 0.70)])
    },

    // Glühwein: Becher mit Henkel, Dampf und Zimtstange.
    "glühwein": { p in
        p.line([p.at(0.20, 0.46), p.at(0.28, 0.90), p.at(0.66, 0.90),
                p.at(0.74, 0.46)], closed: true)
        p.begin(p.at(0.74, 0.56))
        p.bow(p.at(0.74, 0.78), p.at(0.94, 0.56), p.at(0.94, 0.78))
        p.line([p.at(0.46, 0.42), p.at(0.58, 0.16)])
        p.begin(p.at(0.34, 0.40))
        p.bow(p.at(0.34, 0.18), p.at(0.24, 0.32), p.at(0.44, 0.26))
    },

    // Sirup: schlanke Flasche mit langem Hals und Etikett.
    "sirup": { p in
        p.line([p.at(0.42, 0.10), p.at(0.58, 0.10)])
        p.line([p.at(0.42, 0.10), p.at(0.42, 0.34)])
        p.line([p.at(0.58, 0.10), p.at(0.58, 0.34)])
        p.begin(p.at(0.42, 0.34))
        p.bow(p.at(0.28, 0.52), p.at(0.40, 0.44), p.at(0.28, 0.46))
        p.to(p.at(0.28, 0.90))
        p.to(p.at(0.72, 0.90))
        p.to(p.at(0.72, 0.52))
        p.bow(p.at(0.58, 0.34), p.at(0.72, 0.46), p.at(0.60, 0.44))
        p.close()
        p.line([p.at(0.28, 0.62), p.at(0.72, 0.62)])
        p.line([p.at(0.28, 0.76), p.at(0.72, 0.76)])
    },

    // Smoothie: Becher mit Kuppeldeckel und Halm.
    "smoothie": { p in
        p.begin(p.at(0.28, 0.40))
        p.to(p.at(0.34, 0.90))
        p.to(p.at(0.68, 0.90))
        p.to(p.at(0.74, 0.40))
        p.close()
        p.begin(p.at(0.28, 0.40))
        p.bow(p.at(0.74, 0.40), p.at(0.32, 0.20), p.at(0.70, 0.20))
        p.line([p.at(0.56, 0.24), p.at(0.72, 0.06)])
        p.line([p.at(0.34, 0.62), p.at(0.68, 0.62)])
    },

    // Tonic: Longdrinkglas mit Eis und Limettenscheibe.
    "tonicwater": { p in
        p.line([p.at(0.32, 0.16), p.at(0.36, 0.90), p.at(0.66, 0.90),
                p.at(0.70, 0.16)], closed: true)
        p.line([p.at(0.34, 0.44), p.at(0.68, 0.44)])
        p.circle(p.at(0.50, 0.66), 0.10)
        p.line([p.at(0.40, 0.66), p.at(0.60, 0.66)])
    },

    // Kaffeepad: runde Scheibe mit gewelltem Rand und Naht.
    "kaffeepads": { p in
        // **Kein Kreis im Kreis mit Kreuz** — das war ein Wappen. Ein Pad ist
        // eine flache Scheibe mit gekräuseltem Rand und Pulver darin.
        var rand: [CGPoint] = []
        for i in 0..<20 {
            let w = Double(i) / 20 * 2 * Double.pi
            let r: CGFloat = i.isMultiple(of: 2) ? 0.36 : 0.32
            rand.append(p.at(0.50 + r * CGFloat(cos(w)), 0.52 + r * CGFloat(sin(w))))
        }
        p.line(rand, closed: true)
        p.circle(p.at(0.50, 0.52), 0.16)
        p.dot(p.at(0.46, 0.48), 0.035)
        p.dot(p.at(0.56, 0.54), 0.035)
        p.dot(p.at(0.47, 0.60), 0.035)
    },

    // Schnaps: bauchige Flasche mit Korken und schmalem Hals.
    "schnaps": { p in
        p.line([p.at(0.42, 0.08), p.at(0.58, 0.08), p.at(0.58, 0.18),
                p.at(0.42, 0.18)], closed: true)
        p.line([p.at(0.44, 0.18), p.at(0.44, 0.40)])
        p.line([p.at(0.56, 0.18), p.at(0.56, 0.40)])
        p.begin(p.at(0.44, 0.40))
        p.bow(p.at(0.24, 0.66), p.at(0.32, 0.48), p.at(0.24, 0.54))
        p.bow(p.at(0.50, 0.92), p.at(0.24, 0.84), p.at(0.34, 0.92))
        p.bow(p.at(0.76, 0.66), p.at(0.66, 0.92), p.at(0.76, 0.84))
        p.bow(p.at(0.56, 0.40), p.at(0.76, 0.54), p.at(0.68, 0.48))
    },

    // Sportgetränk: Trinkflasche mit Sportverschluss.
    "sportgetränk": { p in
        p.line([p.at(0.44, 0.06), p.at(0.56, 0.06), p.at(0.56, 0.16),
                p.at(0.44, 0.16)], closed: true)
        p.begin(p.at(0.32, 0.30))
        p.bow(p.at(0.68, 0.30), p.at(0.40, 0.16), p.at(0.60, 0.16))
        p.to(p.at(0.70, 0.88))
        p.bow(p.at(0.30, 0.88), p.at(0.70, 0.94), p.at(0.30, 0.94))
        p.close()
        p.line([p.at(0.34, 0.50), p.at(0.66, 0.50)])
        p.line([p.at(0.34, 0.66), p.at(0.66, 0.66)])
    },
]

// MARK: - Tranche 5: Zutaten, Gewürze, Tiefkühl

/// **Achtundzwanzig Zeichen zu Tranche 5** (2026-08-07).
///
/// Gewürze sind die härteste Gruppe überhaupt: Kurkuma, Safran und Muskat
/// sind alle „braunes Pulver in einem Glas". Getrennt sind sie hier über das
/// **Gefäß und die Form, in der man sie kauft** — Streuer, Mühle, Fäden im
/// Röhrchen, ganze Nuss mit Reibe. Wo auch das nicht trägt, stehen mehrere
/// verwandte Gewürze bewusst unter **einem** Begriff (`oregano` trägt auch
/// Rosmarin und Salbei), statt fünf gleiche Gläser zu zeichnen.
private let tranche5: [String: ItemGlyph.Rezept] = [

    // Ahornsirup: Kanne mit Henkel und schmalem Hals.
    "ahornsirup": { p in
        p.line([p.at(0.40, 0.10), p.at(0.56, 0.10)])
        p.line([p.at(0.40, 0.10), p.at(0.38, 0.30)])
        p.line([p.at(0.56, 0.10), p.at(0.58, 0.30)])
        p.begin(p.at(0.38, 0.30))
        p.bow(p.at(0.24, 0.52), p.at(0.34, 0.42), p.at(0.24, 0.46))
        p.to(p.at(0.24, 0.88))
        p.to(p.at(0.72, 0.88))
        p.to(p.at(0.72, 0.52))
        p.bow(p.at(0.58, 0.30), p.at(0.72, 0.46), p.at(0.62, 0.42))
        p.close()
        p.begin(p.at(0.72, 0.58))
        p.bow(p.at(0.72, 0.76), p.at(0.90, 0.58), p.at(0.90, 0.76))
    },

    // Backpulver: Tütchen mit Aufriss und Häufchen davor.
    "backpulver": { p in
        p.line([p.at(0.24, 0.28), p.at(0.64, 0.28), p.at(0.64, 0.84),
                p.at(0.24, 0.84)], closed: true)
        p.line([p.at(0.24, 0.28), p.at(0.32, 0.18), p.at(0.44, 0.26),
                p.at(0.56, 0.18), p.at(0.64, 0.28)])
        p.begin(p.at(0.68, 0.84))
        p.bow(p.at(0.94, 0.84), p.at(0.74, 0.64), p.at(0.90, 0.64))
        p.close()
    },

    // Hefe: Würfel mit Bruchkante.
    "hefe": { p in
        p.line([p.at(0.20, 0.36), p.at(0.62, 0.36), p.at(0.62, 0.82),
                p.at(0.20, 0.82)], closed: true)
        p.line([p.at(0.62, 0.36), p.at(0.82, 0.24), p.at(0.82, 0.70),
                p.at(0.62, 0.82)])
        p.line([p.at(0.20, 0.36), p.at(0.40, 0.24), p.at(0.82, 0.24)])
        p.line([p.at(0.30, 0.52), p.at(0.52, 0.52)])
    },

    // Speisestärke: Schachtel mit Ausgussecke.
    "speisestärke": { p in
        p.line([p.at(0.24, 0.26), p.at(0.68, 0.26), p.at(0.68, 0.86),
                p.at(0.24, 0.86)], closed: true)
        p.line([p.at(0.68, 0.26), p.at(0.82, 0.36), p.at(0.82, 0.86),
                p.at(0.68, 0.86)])
        p.line([p.at(0.24, 0.26), p.at(0.38, 0.16), p.at(0.82, 0.16),
                p.at(0.82, 0.36)])
        p.line([p.at(0.32, 0.48), p.at(0.60, 0.48)])
    },

    // Semmelbrösel: Streuer mit Löchern und rieselndem Korn.
    "semmelbrösel": { p in
        p.begin(p.at(0.32, 0.34))
        p.to(p.at(0.28, 0.86))
        p.to(p.at(0.72, 0.86))
        p.to(p.at(0.68, 0.34))
        p.close()
        p.line([p.at(0.34, 0.24), p.at(0.66, 0.24)])
        p.line([p.at(0.34, 0.24), p.at(0.32, 0.34)])
        p.line([p.at(0.66, 0.24), p.at(0.68, 0.34)])
        p.dot(p.at(0.44, 0.18), 0.03)
        p.dot(p.at(0.56, 0.18), 0.03)
    },

    // Vanille: zwei Schoten mit Blüte.
    "vanille": { p in
        // **Zwei geneigte Kapseln, die sich unten treffen, sind ein „V".**
        // Parallel gelegt und leicht versetzt bleiben es zwei Schoten. Die
        // Blüte sitzt daneben, nicht darüber.
        p.capsule(0.34, 0.56, 0.11, 0.68, tilt: -6)
        p.capsule(0.52, 0.60, 0.11, 0.62, tilt: 4)
        p.circle(p.at(0.76, 0.40), 0.11)
        p.dot(p.at(0.76, 0.40), 0.04)
    },

    // Zimt: zwei Stangen, eine gerollt gedacht.
    "zimt": { p in
        // Dasselbe wie bei der Vanille, nur ein „W": Drei zusammenlaufende
        // Kapseln lesen sich als Buchstabe. Zwei parallele Stangen mit
        // sichtbarer Rollnaht am Kopf bleiben Zimt.
        p.capsule(0.36, 0.54, 0.17, 0.74, tilt: -4)
        p.capsule(0.60, 0.56, 0.17, 0.68, tilt: 5)
        p.circle(p.at(0.36, 0.22), 0.055)
        p.circle(p.at(0.60, 0.26), 0.05)
    },

    // Muskatnuss: ganze Nuss neben der Reibe.
    "muskatnuss": { p in
        p.begin(p.at(0.30, 0.44))
        p.bow(p.at(0.30, 0.80), p.at(0.12, 0.50), p.at(0.12, 0.74))
        p.bow(p.at(0.30, 0.44), p.at(0.48, 0.74), p.at(0.48, 0.50))
        p.close()
        p.line([p.at(0.60, 0.20), p.at(0.86, 0.28), p.at(0.72, 0.86),
                p.at(0.46, 0.78)], closed: true)
        p.dot(p.at(0.64, 0.40), 0.03)
        p.dot(p.at(0.74, 0.44), 0.03)
        p.dot(p.at(0.62, 0.56), 0.03)
        p.dot(p.at(0.72, 0.60), 0.03)
    },

    // Kurkuma: Streuer mit Lochdeckel — das Standardglas der Gewürzreihe.
    "kurkuma": { p in
        p.line([p.at(0.30, 0.30), p.at(0.70, 0.30), p.at(0.72, 0.88),
                p.at(0.28, 0.88)], closed: true)
        p.line([p.at(0.34, 0.20), p.at(0.66, 0.20), p.at(0.70, 0.30)])
        p.line([p.at(0.34, 0.20), p.at(0.30, 0.30)])
        p.dot(p.at(0.44, 0.14), 0.03)
        p.dot(p.at(0.56, 0.14), 0.03)
        p.line([p.at(0.34, 0.56), p.at(0.66, 0.56)])
    },

    // Safran: Fäden im Röhrchen — die Fäden sind sein einziges Merkmal.
    "safran": { p in
        p.line([p.at(0.36, 0.24), p.at(0.64, 0.24), p.at(0.64, 0.88),
                p.at(0.36, 0.88)], closed: true)
        p.line([p.at(0.36, 0.36), p.at(0.64, 0.36)])
        p.line([p.at(0.42, 0.48), p.at(0.50, 0.68)])
        p.line([p.at(0.52, 0.46), p.at(0.46, 0.72)])
        p.line([p.at(0.58, 0.52), p.at(0.54, 0.78)])
    },

    // Oregano: getrockneter Zweig — steht für die ganze Kräutergruppe.
    "oregano": { p in
        p.line([p.at(0.22, 0.86), p.at(0.74, 0.20)])
        for t in [0.25, 0.45, 0.65] {
            let x = 0.22 + (0.74 - 0.22) * CGFloat(t)
            let y = 0.86 - (0.86 - 0.20) * CGFloat(t)
            blatt(&p, von: (x, y), nach: (x - 0.22, y - 0.08), bauch: 0.07)
            blatt(&p, von: (x, y), nach: (x + 0.14, y + 0.16), bauch: 0.07)
        }
    },

    // Pfefferkörner: Mühle mit Kurbel.
    "pfefferkörner": { p in
        p.begin(p.at(0.34, 0.34))
        p.to(p.at(0.30, 0.88))
        p.to(p.at(0.70, 0.88))
        p.to(p.at(0.66, 0.34))
        p.close()
        p.begin(p.at(0.34, 0.34))
        p.bow(p.at(0.66, 0.34), p.at(0.38, 0.18), p.at(0.62, 0.18))
        p.line([p.at(0.50, 0.22), p.at(0.50, 0.10)])
        p.line([p.at(0.50, 0.10), p.at(0.64, 0.08)])
        p.line([p.at(0.32, 0.60), p.at(0.68, 0.60)])
    },

    // Kapern: Glas mit kleinen Kugeln.
    "kapern": { p in
        p.line([p.at(0.32, 0.20), p.at(0.68, 0.20), p.at(0.68, 0.30),
                p.at(0.32, 0.30)], closed: true)
        p.line([p.at(0.30, 0.30), p.at(0.28, 0.88), p.at(0.72, 0.88),
                p.at(0.70, 0.30)])
        p.circle(p.at(0.42, 0.54), 0.08)
        p.circle(p.at(0.58, 0.60), 0.08)
        p.circle(p.at(0.46, 0.74), 0.08)
    },

    // Pinienkerne: drei Tropfenkerne, gestreut.
    "pinienkerne": { p in
        for (cx, cy, tilt) in [(0.32, 0.36, -30.0), (0.62, 0.48, 25.0), (0.42, 0.72, 60.0)] {
            p.capsule(CGFloat(cx), CGFloat(cy), 0.16, 0.30, tilt: tilt)
        }
    },

    // Kokosflocken: halbe Nuss mit Flocken davor.
    "kokosflocken": { p in
        p.begin(p.at(0.16, 0.44))
        p.bow(p.at(0.72, 0.44), p.at(0.24, 0.14), p.at(0.64, 0.14))
        p.bow(p.at(0.16, 0.44), p.at(0.64, 0.74), p.at(0.24, 0.74))
        p.close()
        p.begin(p.at(0.26, 0.44))
        p.bow(p.at(0.62, 0.44), p.at(0.32, 0.28), p.at(0.56, 0.28))
        p.line([p.at(0.30, 0.84), p.at(0.46, 0.80)])
        p.line([p.at(0.52, 0.86), p.at(0.68, 0.82)])
        p.line([p.at(0.72, 0.72), p.at(0.88, 0.68)])
    },

    // Mandelmus: Glas mit Löffel darin.
    "mandelmus": { p in
        p.line([p.at(0.26, 0.24), p.at(0.62, 0.24), p.at(0.64, 0.34),
                p.at(0.24, 0.34)], closed: true)
        p.line([p.at(0.24, 0.34), p.at(0.24, 0.88), p.at(0.64, 0.88),
                p.at(0.64, 0.34)])
        p.line([p.at(0.56, 0.30), p.at(0.80, 0.12)])
        p.begin(p.at(0.80, 0.12))
        p.bow(p.at(0.90, 0.24), p.at(0.90, 0.10), p.at(0.94, 0.18))
        p.bow(p.at(0.80, 0.12), p.at(0.86, 0.28), p.at(0.78, 0.22))
    },

    // Marzipan: Brot mit abgeschnittener Scheibe.
    "marzipan": { p in
        p.line([p.at(0.16, 0.42), p.at(0.66, 0.42), p.at(0.66, 0.76),
                p.at(0.16, 0.76)], closed: true)
        p.line([p.at(0.66, 0.42), p.at(0.82, 0.32), p.at(0.82, 0.66),
                p.at(0.66, 0.76)])
        p.line([p.at(0.16, 0.42), p.at(0.32, 0.32), p.at(0.82, 0.32)])
        p.line([p.at(0.30, 0.42), p.at(0.30, 0.76)])
    },

    // Schokodrops: drei Tropfen mit Spitze.
    "schokodrops": { p in
        for (cx, cy, r) in [(0.32, 0.42, 0.16), (0.64, 0.38, 0.14), (0.48, 0.70, 0.17)] {
            p.begin(p.at(CGFloat(cx), CGFloat(cy) - CGFloat(r) * 1.7))
            p.bow(p.at(CGFloat(cx) + CGFloat(r), CGFloat(cy) + CGFloat(r) * 0.5),
                  p.at(CGFloat(cx) + CGFloat(r) * 0.4, CGFloat(cy) - CGFloat(r)),
                  p.at(CGFloat(cx) + CGFloat(r), CGFloat(cy) - CGFloat(r) * 0.2))
            p.bow(p.at(CGFloat(cx) - CGFloat(r), CGFloat(cy) + CGFloat(r) * 0.5),
                  p.at(CGFloat(cx) + CGFloat(r), CGFloat(cy) + CGFloat(r) * 1.4),
                  p.at(CGFloat(cx) - CGFloat(r), CGFloat(cy) + CGFloat(r) * 1.4))
            p.bow(p.at(CGFloat(cx), CGFloat(cy) - CGFloat(r) * 1.7),
                  p.at(CGFloat(cx) - CGFloat(r), CGFloat(cy) - CGFloat(r) * 0.2),
                  p.at(CGFloat(cx) - CGFloat(r) * 0.4, CGFloat(cy) - CGFloat(r)))
            p.close()
        }
    },

    // Lebensmittelfarbe: Fläschchen mit Pipette.
    "lebensmittelfarbe": { p in
        p.line([p.at(0.34, 0.44), p.at(0.34, 0.88), p.at(0.66, 0.88),
                p.at(0.66, 0.44)], closed: true)
        p.line([p.at(0.42, 0.44), p.at(0.42, 0.30), p.at(0.58, 0.30),
                p.at(0.58, 0.44)])
        p.begin(p.at(0.42, 0.30))
        p.bow(p.at(0.58, 0.30), p.at(0.42, 0.16), p.at(0.58, 0.16))
        p.line([p.at(0.38, 0.62), p.at(0.62, 0.62)])
    },

    // Dosentomaten: Konservendose mit Tomate darauf.
    "dosentomaten": { p in
        p.begin(p.at(0.24, 0.34))
        p.bow(p.at(0.76, 0.34), p.at(0.24, 0.20), p.at(0.76, 0.20))
        p.bow(p.at(0.24, 0.34), p.at(0.76, 0.48), p.at(0.24, 0.48))
        p.close()
        p.line([p.at(0.24, 0.34), p.at(0.24, 0.82)])
        p.line([p.at(0.76, 0.34), p.at(0.76, 0.82)])
        p.begin(p.at(0.24, 0.82))
        p.bow(p.at(0.76, 0.82), p.at(0.30, 0.92), p.at(0.70, 0.92))
        p.circle(p.at(0.50, 0.64), 0.13)
        p.line([p.at(0.44, 0.51), p.at(0.56, 0.51)])
    },

    // Bratensauce: Sauciere mit Ausguss.
    "bratensauce": { p in
        p.begin(p.at(0.18, 0.44))
        p.to(p.at(0.24, 0.82))
        p.bow(p.at(0.68, 0.82), p.at(0.30, 0.92), p.at(0.62, 0.92))
        p.to(p.at(0.74, 0.44))
        p.close()
        p.line([p.at(0.74, 0.50), p.at(0.94, 0.38)])
        p.begin(p.at(0.18, 0.52))
        p.bow(p.at(0.18, 0.72), p.at(0.02, 0.52), p.at(0.02, 0.72))
    },

    // Fischsauce: schlanke Flasche mit Ausgussverschluss.
    "fischsauce": { p in
        p.line([p.at(0.44, 0.08), p.at(0.58, 0.08), p.at(0.58, 0.20),
                p.at(0.44, 0.20)], closed: true)
        p.line([p.at(0.46, 0.20), p.at(0.44, 0.36)])
        p.line([p.at(0.56, 0.20), p.at(0.58, 0.36)])
        p.line([p.at(0.44, 0.36), p.at(0.32, 0.48), p.at(0.32, 0.90),
                p.at(0.70, 0.90), p.at(0.70, 0.48), p.at(0.58, 0.36)])
        p.line([p.at(0.34, 0.60), p.at(0.68, 0.60)])
    },

    // Marinade: Beutel mit Zipper und Zweig darin.
    "marinade": { p in
        p.line([p.at(0.22, 0.26), p.at(0.78, 0.26), p.at(0.74, 0.88),
                p.at(0.26, 0.88)], closed: true)
        p.line([p.at(0.22, 0.36), p.at(0.78, 0.36)])
        p.line([p.at(0.50, 0.78), p.at(0.50, 0.50)])
        p.line([p.at(0.50, 0.60), p.at(0.36, 0.50)])
        p.line([p.at(0.50, 0.60), p.at(0.64, 0.50)])
    },

    // Tütensuppe: Tüte mit Tellersymbol.
    "tütensuppe": { p in
        p.line([p.at(0.26, 0.24), p.at(0.74, 0.24), p.at(0.74, 0.88),
                p.at(0.26, 0.88)], closed: true)
        p.line([p.at(0.26, 0.24), p.at(0.34, 0.14), p.at(0.50, 0.22),
                p.at(0.66, 0.14), p.at(0.74, 0.24)])
        p.begin(p.at(0.34, 0.52))
        p.bow(p.at(0.66, 0.52), p.at(0.38, 0.72), p.at(0.62, 0.72))
        p.close()
    },

    // Kartoffelpüree: Klecks auf dem Teller mit Kuhle.
    "kartoffelpüree": { p in
        p.begin(p.at(0.14, 0.72))
        p.bow(p.at(0.86, 0.72), p.at(0.24, 0.88), p.at(0.76, 0.88))
        p.begin(p.at(0.22, 0.70))
        p.bow(p.at(0.50, 0.34), p.at(0.24, 0.48), p.at(0.34, 0.34))
        p.bow(p.at(0.78, 0.70), p.at(0.66, 0.34), p.at(0.76, 0.48))
        p.begin(p.at(0.40, 0.48))
        p.bow(p.at(0.60, 0.48), p.at(0.44, 0.58), p.at(0.56, 0.58))
    },

    // Knödel: zwei Kugeln auf dem Teller.
    "knödel": { p in
        p.circle(p.at(0.36, 0.46), 0.20)
        p.circle(p.at(0.64, 0.52), 0.18)
        p.begin(p.at(0.12, 0.74))
        p.bow(p.at(0.88, 0.74), p.at(0.24, 0.90), p.at(0.76, 0.90))
    },

    // Kohlroulade: gewickelte Rolle mit Faden.
    "kohlrouladen": { p in
        p.begin(p.at(0.18, 0.42))
        p.bow(p.at(0.82, 0.42), p.at(0.26, 0.24), p.at(0.74, 0.24))
        p.to(p.at(0.82, 0.72))
        p.bow(p.at(0.18, 0.72), p.at(0.74, 0.90), p.at(0.26, 0.90))
        p.close()
        p.begin(p.at(0.18, 0.42))
        p.bow(p.at(0.82, 0.42), p.at(0.26, 0.60), p.at(0.74, 0.60))
        p.line([p.at(0.50, 0.24), p.at(0.50, 0.88)])
    },

    // Frikassee: Topf mit Deckel und Griffen.
    "hühnerfrikassee": { p in
        p.line([p.at(0.20, 0.44), p.at(0.24, 0.86), p.at(0.76, 0.86),
                p.at(0.80, 0.44)], closed: true)
        p.line([p.at(0.14, 0.40), p.at(0.86, 0.40)])
        p.begin(p.at(0.34, 0.40))
        p.bow(p.at(0.66, 0.40), p.at(0.38, 0.24), p.at(0.62, 0.24))
        p.line([p.at(0.50, 0.24), p.at(0.50, 0.14)])
        p.begin(p.at(0.14, 0.46))
        p.bow(p.at(0.14, 0.62), p.at(0.02, 0.46), p.at(0.02, 0.62))
    },
]

// MARK: - Tranche 6: der Rest aus Obst & Gemüse

/// **Dreiundzwanzig Zeichen zu Tranche 6** (2026-08-07).
///
/// Was in Bring!s größter Kategorie noch offen war. **Vier Salate unter einem
/// Begriff** (`römersalat` trägt Kopf-, Eisberg-, Feldsalat und Rucola): Ein
/// Salatkopf ist ein Salatkopf, und vier Varianten desselben Bildes wären der
/// Fehler, gegen den das Vorhaben läuft.
private let tranche6: [String: ItemGlyph.Rezept] = [

    // Blutorange: Kugel mit angeschnittener Hälfte, Segmente sichtbar.
    "blutorangen": { p in
        p.circle(p.at(0.36, 0.56), 0.28)
        p.line([p.at(0.36, 0.30), p.at(0.38, 0.16)])
        p.begin(p.at(0.62, 0.44))
        p.bow(p.at(0.62, 0.88), p.at(0.94, 0.48), p.at(0.94, 0.84))
        p.close()
        p.line([p.at(0.62, 0.66), p.at(0.90, 0.66)])
        p.line([p.at(0.62, 0.52), p.at(0.80, 0.56)])
        p.line([p.at(0.62, 0.80), p.at(0.80, 0.76)])
    },

    // Chicorée: geschlossene Knospe mit spitzen Blattenden.
    "chicorée": { p in
        p.begin(p.at(0.50, 0.10))
        p.bow(p.at(0.28, 0.86), p.at(0.30, 0.34), p.at(0.26, 0.66))
        p.bow(p.at(0.72, 0.86), p.at(0.38, 0.94), p.at(0.62, 0.94))
        p.bow(p.at(0.50, 0.10), p.at(0.74, 0.66), p.at(0.70, 0.34))
        p.close()
        p.line([p.at(0.42, 0.24), p.at(0.40, 0.84)])
        p.line([p.at(0.58, 0.24), p.at(0.60, 0.84)])
    },

    // Drachenfrucht: ovale Frucht mit abstehenden Schuppen.
    "drachenfrucht": { p in
        p.begin(p.at(0.50, 0.20))
        p.bow(p.at(0.50, 0.86), p.at(0.24, 0.34), p.at(0.24, 0.72))
        p.bow(p.at(0.50, 0.20), p.at(0.76, 0.72), p.at(0.76, 0.34))
        p.close()
        p.line([p.at(0.26, 0.38), p.at(0.10, 0.28)])
        p.line([p.at(0.74, 0.38), p.at(0.90, 0.28)])
        p.line([p.at(0.26, 0.62), p.at(0.10, 0.56)])
        p.line([p.at(0.74, 0.62), p.at(0.90, 0.56)])
        p.dot(p.at(0.44, 0.50), 0.03)
        p.dot(p.at(0.56, 0.60), 0.03)
    },

    // Kiwi: halbierte Frucht mit Kernkranz.
    "kiwi": { p in
        p.circle(p.at(0.50, 0.52), 0.34)
        p.circle(p.at(0.50, 0.52), 0.10)
        for i in 0..<8 {
            let w = Double(i) / 8 * 2 * Double.pi
            p.dot(p.at(0.50 + 0.20 * CGFloat(cos(w)), 0.52 + 0.20 * CGFloat(sin(w))), 0.028)
        }
    },

    // Guave/Maracuja: halbierte Frucht mit Kerngrube.
    "guave": { p in
        p.circle(p.at(0.50, 0.54), 0.32)
        p.begin(p.at(0.28, 0.54))
        p.bow(p.at(0.72, 0.54), p.at(0.34, 0.32), p.at(0.66, 0.32))
        p.bow(p.at(0.28, 0.54), p.at(0.66, 0.76), p.at(0.34, 0.76))
        p.close()
        p.dot(p.at(0.44, 0.50), 0.035)
        p.dot(p.at(0.58, 0.54), 0.035)
        p.dot(p.at(0.48, 0.62), 0.035)
    },

    // Haselnuss: runde Nuss im gezackten Fruchtbecher.
    "haselnüsse": { p in
        p.circle(p.at(0.50, 0.62), 0.26)
        p.line([p.at(0.24, 0.50), p.at(0.32, 0.30), p.at(0.44, 0.44),
                p.at(0.56, 0.26), p.at(0.68, 0.44), p.at(0.76, 0.30),
                p.at(0.76, 0.50)])
    },

    // Kastanie: glänzende Nuss mit heller Narbe unten.
    "kastanien": { p in
        p.begin(p.at(0.50, 0.20))
        p.bow(p.at(0.20, 0.62), p.at(0.30, 0.24), p.at(0.20, 0.44))
        p.bow(p.at(0.80, 0.62), p.at(0.20, 0.88), p.at(0.80, 0.88))
        p.bow(p.at(0.50, 0.20), p.at(0.80, 0.44), p.at(0.70, 0.24))
        p.close()
        p.begin(p.at(0.36, 0.78))
        p.bow(p.at(0.64, 0.78), p.at(0.40, 0.66), p.at(0.60, 0.66))
        p.close()
    },

    // Kokosnuss: Nuss mit den drei Keimlöchern.
    "kokosnuss": { p in
        // **Drei Keimlöcher im Dreieck sind ein Gesicht** — zwei Augen und
        // ein Mund, dieselbe Falle wie bei der Brezel. Halbiert gezeichnet,
        // mit den Löchern **am Rand** statt in der Mitte, ist es eine Nuss.
        p.circle(p.at(0.50, 0.54), 0.34)
        p.begin(p.at(0.24, 0.44))
        p.bow(p.at(0.76, 0.44), p.at(0.32, 0.20), p.at(0.68, 0.20))
        p.bow(p.at(0.24, 0.44), p.at(0.68, 0.68), p.at(0.32, 0.68))
        p.close()
        p.dot(p.at(0.30, 0.80), 0.04)
        p.dot(p.at(0.50, 0.86), 0.04)
        p.dot(p.at(0.70, 0.80), 0.04)
    },

    // Kresse: Schälchen mit dichtem, kurzem Bewuchs.
    "kresse": { p in
        p.line([p.at(0.22, 0.62), p.at(0.28, 0.88), p.at(0.72, 0.88),
                p.at(0.78, 0.62)], closed: true)
        for x in [0.30, 0.40, 0.50, 0.60, 0.70] {
            p.line([p.at(CGFloat(x), 0.60), p.at(CGFloat(x) - 0.03, 0.30)])
            p.dot(p.at(CGFloat(x) - 0.03, 0.26), 0.035)
        }
    },

    // Maiskolben: Kolben mit Körnerraster und Hüllblatt.
    "maiskolben": { p in
        p.begin(p.at(0.44, 0.14))
        p.bow(p.at(0.44, 0.84), p.at(0.26, 0.30), p.at(0.26, 0.68))
        p.bow(p.at(0.44, 0.14), p.at(0.62, 0.68), p.at(0.62, 0.30))
        p.close()
        // **Vier Querreihen, keine Längslinie.** Drei Reihen *und* eine Linie
        // durch die Mitte ergaben ein Gitter, und ein Gitter aus Feldern von
        // 0,14 × 0,13 ist bei 22 pt eine graue Fläche — der Kolben war dort ein
        // dunkler Fleck mit einem Blatt daneben. Die Reihen allein tragen die
        // Körnung; die Längslinie war die eine Linie zu viel.
        p.line([p.at(0.33, 0.28), p.at(0.55, 0.28)])
        p.line([p.at(0.29, 0.42), p.at(0.59, 0.42)])
        p.line([p.at(0.29, 0.56), p.at(0.59, 0.56)])
        p.line([p.at(0.33, 0.70), p.at(0.55, 0.70)])
        blatt(&p, von: (0.56, 0.66), nach: (0.90, 0.44), bauch: -0.10)
    },

    // Mangold: breites Blatt mit dickem Stiel.
    "mangold": { p in
        p.line([p.at(0.48, 0.92), p.at(0.50, 0.46)])
        p.begin(p.at(0.50, 0.50))
        p.bow(p.at(0.18, 0.24), p.at(0.30, 0.48), p.at(0.16, 0.38))
        p.bow(p.at(0.50, 0.08), p.at(0.20, 0.10), p.at(0.36, 0.06))
        p.bow(p.at(0.82, 0.24), p.at(0.64, 0.06), p.at(0.80, 0.10))
        p.bow(p.at(0.50, 0.50), p.at(0.84, 0.38), p.at(0.70, 0.48))
        p.close()
        p.line([p.at(0.50, 0.46), p.at(0.50, 0.12)])
    },

    // Preiselbeeren: drei kleine Beeren am Zweig.
    "preiselbeeren": { p in
        p.circle(p.at(0.34, 0.56), 0.15)
        p.circle(p.at(0.62, 0.48), 0.15)
        p.circle(p.at(0.50, 0.78), 0.14)
        p.line([p.at(0.34, 0.41), p.at(0.40, 0.20)])
        p.line([p.at(0.62, 0.33), p.at(0.48, 0.18)])
        p.line([p.at(0.40, 0.20), p.at(0.48, 0.18)])
    },

    // Quinoa: Schale mit feinem Korn und Spiralen.
    "quinoa": { p in
        p.begin(p.at(0.16, 0.52))
        p.bow(p.at(0.84, 0.52), p.at(0.22, 0.88), p.at(0.78, 0.88))
        p.close()
        p.circle(p.at(0.36, 0.42), 0.06)
        p.circle(p.at(0.52, 0.36), 0.06)
        p.circle(p.at(0.66, 0.44), 0.06)
    },

    // Salatkopf: lockere Blätter um ein Herz — steht für die ganze Gruppe.
    "römersalat": { p in
        p.begin(p.at(0.50, 0.16))
        p.bow(p.at(0.14, 0.56), p.at(0.26, 0.20), p.at(0.14, 0.36))
        p.bow(p.at(0.50, 0.90), p.at(0.14, 0.78), p.at(0.30, 0.90))
        p.bow(p.at(0.86, 0.56), p.at(0.70, 0.90), p.at(0.86, 0.78))
        p.bow(p.at(0.50, 0.16), p.at(0.86, 0.36), p.at(0.74, 0.20))
        p.close()
        p.begin(p.at(0.28, 0.48))
        p.bow(p.at(0.50, 0.84), p.at(0.34, 0.68), p.at(0.42, 0.80))
        p.begin(p.at(0.72, 0.48))
        p.bow(p.at(0.50, 0.84), p.at(0.66, 0.68), p.at(0.58, 0.80))
        p.line([p.at(0.50, 0.24), p.at(0.50, 0.80)])
    },

    // Schwarzwurzel: lange dünne Wurzel, gerade, mit Erdspitze.
    "schwarzwurzel": { p in
        p.begin(p.at(0.38, 0.12))
        p.bow(p.at(0.56, 0.92), p.at(0.44, 0.44), p.at(0.50, 0.70))
        p.bow(p.at(0.38, 0.12), p.at(0.48, 0.68), p.at(0.32, 0.42))
        p.close()
        p.line([p.at(0.42, 0.34), p.at(0.22, 0.26)])
        p.line([p.at(0.48, 0.58), p.at(0.70, 0.52)])
        p.line([p.at(0.38, 0.12), p.at(0.30, 0.04)])
    },

    // Snacktomaten: Rispe mit drei kleinen Früchten.
    "snacktomaten": { p in
        p.circle(p.at(0.30, 0.64), 0.16)
        p.circle(p.at(0.58, 0.70), 0.16)
        p.circle(p.at(0.74, 0.46), 0.15)
        p.line([p.at(0.24, 0.28), p.at(0.80, 0.22)])
        p.line([p.at(0.30, 0.48), p.at(0.34, 0.28)])
        p.line([p.at(0.58, 0.54), p.at(0.56, 0.26)])
        p.line([p.at(0.74, 0.31), p.at(0.72, 0.24)])
    },

    // Weizengras: dichtes Büschel gerader Halme in der Schale.
    "weizengras": { p in
        p.line([p.at(0.24, 0.66), p.at(0.28, 0.88), p.at(0.72, 0.88),
                p.at(0.76, 0.66)], closed: true)
        for (x, tip) in [(0.30, 0.20), (0.40, 0.10), (0.50, 0.16), (0.60, 0.08), (0.70, 0.22)] {
            p.line([p.at(CGFloat(x), 0.64), p.at(CGFloat(x) + 0.03, CGFloat(tip))])
        }
    },

    // Zitronengras: drei Halme mit verdicktem Fuß.
    "zitronengras": { p in
        for (x, t) in [(0.34, -8.0), (0.50, 0.0), (0.66, 8.0)] {
            p.capsule(CGFloat(x), 0.72, 0.13, 0.34, tilt: t)
            p.line([p.at(CGFloat(x) + CGFloat(t) * 0.004, 0.56),
                    p.at(CGFloat(x) + CGFloat(t) * 0.012, 0.10)])
        }
    },

    // Portulak: kleine runde Blätter an dünnen Stielen.
    "portulak": { p in
        p.line([p.at(0.50, 0.92), p.at(0.50, 0.46)])
        p.line([p.at(0.50, 0.66), p.at(0.28, 0.50)])
        p.line([p.at(0.50, 0.66), p.at(0.72, 0.50)])
        p.circle(p.at(0.24, 0.42), 0.12)
        p.circle(p.at(0.76, 0.42), 0.12)
        p.circle(p.at(0.50, 0.30), 0.13)
    },

    // Artischocke: Knospe aus geschuppten Blättern mit Stiel.
    "artischocken": { p in
        p.begin(p.at(0.50, 0.14))
        p.bow(p.at(0.22, 0.52), p.at(0.30, 0.18), p.at(0.22, 0.36))
        p.bow(p.at(0.50, 0.80), p.at(0.22, 0.70), p.at(0.34, 0.80))
        p.bow(p.at(0.78, 0.52), p.at(0.66, 0.80), p.at(0.78, 0.70))
        p.bow(p.at(0.50, 0.14), p.at(0.78, 0.36), p.at(0.70, 0.18))
        p.close()
        p.line([p.at(0.26, 0.42), p.at(0.74, 0.42)])
        p.line([p.at(0.30, 0.60), p.at(0.70, 0.60)])
        p.line([p.at(0.50, 0.80), p.at(0.50, 0.94)])
    },

    // Spargel: drei Stangen mit Kopf.
    "spargel": { p in
        for (x, t) in [(0.32, -10.0), (0.50, 0.0), (0.68, 10.0)] {
            p.line([p.at(CGFloat(x) - CGFloat(t) * 0.006, 0.90),
                    p.at(CGFloat(x) + CGFloat(t) * 0.004, 0.26)])
            p.begin(p.at(CGFloat(x) + CGFloat(t) * 0.004 - 0.06, 0.26))
            p.bow(p.at(CGFloat(x) + CGFloat(t) * 0.004, 0.10),
                  p.at(CGFloat(x) + CGFloat(t) * 0.004 - 0.06, 0.16),
                  p.at(CGFloat(x) + CGFloat(t) * 0.004 - 0.03, 0.10))
            p.bow(p.at(CGFloat(x) + CGFloat(t) * 0.004 + 0.06, 0.26),
                  p.at(CGFloat(x) + CGFloat(t) * 0.004 + 0.03, 0.10),
                  p.at(CGFloat(x) + CGFloat(t) * 0.004 + 0.06, 0.16))
            p.close()
        }
    },

    // Lauch: lange Stange, unten weiß und dick, oben aufgefächert.
    "lauch": { p in
        p.begin(p.at(0.40, 0.90))
        p.bow(p.at(0.60, 0.90), p.at(0.38, 0.96), p.at(0.62, 0.96))
        p.to(p.at(0.58, 0.52))
        p.to(p.at(0.42, 0.52))
        p.close()
        p.line([p.at(0.42, 0.52), p.at(0.26, 0.12)])
        p.line([p.at(0.50, 0.52), p.at(0.50, 0.08)])
        p.line([p.at(0.58, 0.52), p.at(0.74, 0.12)])
        p.line([p.at(0.36, 0.70), p.at(0.64, 0.70)])
    },

    // Kohlrabi: Knolle mit zwei Stielen und Blatt.
    "kohlrabi": { p in
        p.circle(p.at(0.50, 0.66), 0.26)
        p.line([p.at(0.42, 0.42), p.at(0.30, 0.16)])
        p.line([p.at(0.58, 0.42), p.at(0.70, 0.16)])
        blatt(&p, von: (0.30, 0.16), nach: (0.12, 0.06), bauch: 0.07)
        blatt(&p, von: (0.70, 0.16), nach: (0.88, 0.06), bauch: -0.07)
        p.line([p.at(0.32, 0.84), p.at(0.30, 0.92)])
    },
]

// MARK: - Tranche 7: die letzten Lebensmittel

/// **Fünfundzwanzig Zeichen zu Tranche 7** (2026-08-07).
///
/// Damit ist Bring!s Lebensmittelteil weitgehend gezeichnet. **Fünf Flaschen
/// und Gläser in einer Runde** — Ketchup, Mayonnaise, Senf, Sojasauce, BBQ —
/// sind die Falle dieser Gruppe. Getrennt sind sie über die **Silhouette des
/// Gefäßes**, die im Regal wirklich verschieden ist: Quetschflasche mit
/// Taille, breites Glas mit Deckel, kleines Glas mit Bügel, schlanke
/// Sojaflasche mit Ausguss, Flasche mit Griffkerbe.
private let tranche7: [String: ItemGlyph.Rezept] = [

    // Ketchup: Quetschflasche mit Taille und Spitzverschluss.
    "ketchup": { p in
        p.line([p.at(0.42, 0.08), p.at(0.58, 0.08)])
        p.line([p.at(0.42, 0.08), p.at(0.40, 0.20)])
        p.line([p.at(0.58, 0.08), p.at(0.60, 0.20)])
        p.begin(p.at(0.40, 0.20))
        p.bow(p.at(0.30, 0.48), p.at(0.38, 0.34), p.at(0.34, 0.40))
        p.bow(p.at(0.28, 0.90), p.at(0.26, 0.62), p.at(0.28, 0.76))
        p.to(p.at(0.72, 0.90))
        p.bow(p.at(0.70, 0.48), p.at(0.72, 0.76), p.at(0.74, 0.62))
        p.bow(p.at(0.60, 0.20), p.at(0.66, 0.40), p.at(0.62, 0.34))
        p.close()
        p.line([p.at(0.32, 0.62), p.at(0.68, 0.62)])
    },

    // Mayonnaise: breites Glas mit Schraubdeckel.
    "mayonnaise": { p in
        // **Ein breites Rechteck mit Deckel und zwei Querlinien ist ein
        // Notizblock.** Die Mayonnaise braucht ihre Form: bauchiges Glas mit
        // eingezogener Schulter, dazu ein Löffel — dann ist es kein Papier.
        p.line([p.at(0.30, 0.16), p.at(0.66, 0.16), p.at(0.66, 0.26),
                p.at(0.30, 0.26)], closed: true)
        p.begin(p.at(0.30, 0.26))
        p.bow(p.at(0.22, 0.46), p.at(0.28, 0.34), p.at(0.22, 0.38))
        p.to(p.at(0.22, 0.88))
        p.to(p.at(0.74, 0.88))
        p.to(p.at(0.74, 0.46))
        p.bow(p.at(0.66, 0.26), p.at(0.74, 0.38), p.at(0.68, 0.34))
        p.line([p.at(0.28, 0.62), p.at(0.68, 0.62)])
    },

    // Senf: kleines Glas mit Bügelverschluss.
    "senf": { p in
        p.line([p.at(0.34, 0.22), p.at(0.66, 0.22)])
        p.line([p.at(0.34, 0.22), p.at(0.30, 0.34)])
        p.line([p.at(0.66, 0.22), p.at(0.70, 0.34)])
        p.line([p.at(0.30, 0.34), p.at(0.28, 0.88), p.at(0.72, 0.88),
                p.at(0.70, 0.34)], closed: true)
        p.line([p.at(0.40, 0.16), p.at(0.60, 0.16)])
        p.line([p.at(0.50, 0.16), p.at(0.50, 0.22)])
    },

    // Sojasauce: schlanke Flasche mit Ausgusskappe.
    "sojasauce": { p in
        p.line([p.at(0.44, 0.06), p.at(0.60, 0.06), p.at(0.58, 0.18),
                p.at(0.46, 0.18)], closed: true)
        p.line([p.at(0.46, 0.18), p.at(0.38, 0.38)])
        p.line([p.at(0.58, 0.18), p.at(0.66, 0.38)])
        p.line([p.at(0.38, 0.38), p.at(0.36, 0.90), p.at(0.68, 0.90),
                p.at(0.66, 0.38)], closed: true)
        p.line([p.at(0.40, 0.58), p.at(0.64, 0.58)])
    },

    // Grillsauce: Flasche mit Griffkerbe an der Seite.
    "grillsauce": { p in
        p.line([p.at(0.42, 0.08), p.at(0.58, 0.08), p.at(0.58, 0.22),
                p.at(0.42, 0.22)], closed: true)
        p.begin(p.at(0.42, 0.22))
        p.bow(p.at(0.28, 0.44), p.at(0.38, 0.34), p.at(0.28, 0.38))
        p.to(p.at(0.28, 0.90))
        p.to(p.at(0.72, 0.90))
        p.to(p.at(0.72, 0.44))
        p.bow(p.at(0.58, 0.22), p.at(0.72, 0.38), p.at(0.62, 0.34))
        p.begin(p.at(0.28, 0.56))
        p.bow(p.at(0.28, 0.70), p.at(0.16, 0.56), p.at(0.16, 0.70))
        p.line([p.at(0.34, 0.78), p.at(0.66, 0.78)])
    },

    // Pesto: kleines Glas mit Deckel und Blatt.
    "pesto": { p in
        p.line([p.at(0.30, 0.24), p.at(0.70, 0.24), p.at(0.70, 0.34),
                p.at(0.30, 0.34)], closed: true)
        p.line([p.at(0.30, 0.34), p.at(0.28, 0.88), p.at(0.72, 0.88),
                p.at(0.70, 0.34)])
        blatt(&p, von: (0.38, 0.68), nach: (0.62, 0.50), bauch: 0.09)
    },

    // Hummus: flache Schale mit Kichererbse und Ölmulde.
    "hummus": { p in
        p.begin(p.at(0.14, 0.52))
        p.bow(p.at(0.86, 0.52), p.at(0.20, 0.86), p.at(0.80, 0.86))
        p.close()
        p.begin(p.at(0.32, 0.60))
        p.bow(p.at(0.68, 0.60), p.at(0.40, 0.70), p.at(0.60, 0.70))
        p.circle(p.at(0.50, 0.38), 0.10)
    },

    // Ingwer: knorrige Knolle mit zwei Fingern.
    "ingwer": { p in
        p.begin(p.at(0.24, 0.44))
        p.bow(p.at(0.62, 0.42), p.at(0.30, 0.24), p.at(0.56, 0.24))
        p.bow(p.at(0.74, 0.68), p.at(0.74, 0.48), p.at(0.78, 0.58))
        p.bow(p.at(0.40, 0.80), p.at(0.66, 0.84), p.at(0.50, 0.82))
        p.bow(p.at(0.24, 0.44), p.at(0.24, 0.74), p.at(0.18, 0.58))
        p.close()
        p.line([p.at(0.36, 0.42), p.at(0.28, 0.22)])
        p.line([p.at(0.60, 0.44), p.at(0.72, 0.28)])
    },

    // Koriander: Zweig mit drei gefiederten Blattpaaren.
    "koriander": { p in
        p.line([p.at(0.50, 0.92), p.at(0.50, 0.36)])
        for (y, w) in [(0.44, 0.24), (0.58, 0.20), (0.72, 0.16)] {
            blatt(&p, von: (0.50, CGFloat(y)), nach: (0.50 - CGFloat(w), CGFloat(y) - 0.14), bauch: 0.06)
            blatt(&p, von: (0.50, CGFloat(y)), nach: (0.50 + CGFloat(w), CGFloat(y) - 0.14), bauch: -0.06)
        }
        p.circle(p.at(0.50, 0.24), 0.10)
    },

    // Pfeffer: Streuer mit Lochdeckel und Körnern.
    "pfeffer": { p in
        p.begin(p.at(0.34, 0.36))
        p.to(p.at(0.32, 0.88))
        p.to(p.at(0.68, 0.88))
        p.to(p.at(0.66, 0.36))
        p.close()
        p.begin(p.at(0.34, 0.36))
        p.bow(p.at(0.66, 0.36), p.at(0.36, 0.22), p.at(0.64, 0.22))
        p.dot(p.at(0.44, 0.20), 0.03)
        p.dot(p.at(0.56, 0.20), 0.03)
        p.dot(p.at(0.44, 0.56), 0.04)
        p.dot(p.at(0.56, 0.62), 0.04)
    },

    // Paprikapulver: Dose mit Streuöffnung und Schote als Marke.
    "paprikapulver": { p in
        p.line([p.at(0.30, 0.30), p.at(0.70, 0.30), p.at(0.70, 0.88),
                p.at(0.30, 0.88)], closed: true)
        p.line([p.at(0.30, 0.30), p.at(0.34, 0.18), p.at(0.66, 0.18),
                p.at(0.70, 0.30)])
        p.begin(p.at(0.44, 0.50))
        p.bow(p.at(0.56, 0.74), p.at(0.56, 0.56), p.at(0.60, 0.66))
        p.bow(p.at(0.44, 0.50), p.at(0.48, 0.72), p.at(0.40, 0.62))
        p.close()
        p.line([p.at(0.44, 0.50), p.at(0.40, 0.42)])
    },

    // Chili: Flocken im flachen Glas — die ganze Schote hat `peperoni`.
    "chili": { p in
        p.begin(p.at(0.22, 0.42))
        p.to(p.at(0.26, 0.86))
        p.to(p.at(0.74, 0.86))
        p.to(p.at(0.78, 0.42))
        p.close()
        p.line([p.at(0.20, 0.36), p.at(0.80, 0.36)])
        p.line([p.at(0.20, 0.36), p.at(0.22, 0.42)])
        p.line([p.at(0.80, 0.36), p.at(0.78, 0.42)])
        p.dot(p.at(0.36, 0.56), 0.035)
        p.dot(p.at(0.54, 0.52), 0.035)
        p.dot(p.at(0.64, 0.66), 0.035)
        p.dot(p.at(0.42, 0.72), 0.035)
    },

    // Babynahrung: Gläschen mit Schraubdeckel und Schnullerbogen.
    "babynahrung": { p in
        p.line([p.at(0.30, 0.28), p.at(0.70, 0.28), p.at(0.70, 0.38),
                p.at(0.30, 0.38)], closed: true)
        p.begin(p.at(0.30, 0.38))
        p.bow(p.at(0.26, 0.60), p.at(0.28, 0.46), p.at(0.26, 0.52))
        p.to(p.at(0.26, 0.86))
        p.to(p.at(0.74, 0.86))
        p.to(p.at(0.74, 0.60))
        p.bow(p.at(0.70, 0.38), p.at(0.74, 0.52), p.at(0.72, 0.46))
        p.begin(p.at(0.38, 0.66))
        p.bow(p.at(0.62, 0.66), p.at(0.42, 0.76), p.at(0.58, 0.76))
    },

    // Maultaschen: zwei gefüllte Taschen mit Rillenrand.
    "maultaschen": { p in
        p.line([p.at(0.14, 0.34), p.at(0.54, 0.34), p.at(0.54, 0.60),
                p.at(0.14, 0.60)], closed: true)
        p.line([p.at(0.14, 0.42), p.at(0.54, 0.42)])
        p.line([p.at(0.40, 0.54), p.at(0.86, 0.54), p.at(0.86, 0.82),
                p.at(0.40, 0.82)], closed: true)
        p.line([p.at(0.40, 0.62), p.at(0.86, 0.62)])
    },

    // Wrap: gerollter Fladen, schräg angeschnitten.
    "wraps": { p in
        p.begin(p.at(0.30, 0.90))
        p.bow(p.at(0.66, 0.20), p.at(0.34, 0.62), p.at(0.52, 0.32))
        p.bow(p.at(0.78, 0.30), p.at(0.74, 0.16), p.at(0.80, 0.20))
        p.bow(p.at(0.46, 0.92), p.at(0.70, 0.62), p.at(0.54, 0.82))
        p.close()
        p.begin(p.at(0.66, 0.20))
        p.bow(p.at(0.78, 0.30), p.at(0.70, 0.30), p.at(0.74, 0.32))
        p.line([p.at(0.42, 0.62), p.at(0.58, 0.68)])
    },

    // Hamburger: Frikadelle von der Seite, mit Grillstreifen.
    "hamburger": { p in
        p.begin(p.at(0.16, 0.50))
        p.bow(p.at(0.84, 0.50), p.at(0.22, 0.28), p.at(0.78, 0.28))
        p.bow(p.at(0.16, 0.50), p.at(0.78, 0.72), p.at(0.22, 0.72))
        p.close()
        p.line([p.at(0.30, 0.44), p.at(0.54, 0.44)])
        p.line([p.at(0.42, 0.56), p.at(0.68, 0.56)])
    },

    // Hartkäse: Ecke mit Rinde — die gerade Rinde trennt sie vom Weichkäse.
    "hartkäse": { p in
        p.line([p.at(0.14, 0.74), p.at(0.30, 0.30), p.at(0.86, 0.44),
                p.at(0.72, 0.84)], closed: true)
        p.line([p.at(0.30, 0.30), p.at(0.86, 0.44)])
        p.line([p.at(0.34, 0.40), p.at(0.80, 0.52)])
        p.dot(p.at(0.36, 0.62), 0.05)
        p.dot(p.at(0.58, 0.66), 0.05)
    },

    // Kräuterfrischkäse: Becher mit Deckel und Kräuterzweig.
    "kräuterfrischkäse": { p in
        p.line([p.at(0.20, 0.40), p.at(0.80, 0.40)])
        p.begin(p.at(0.24, 0.40))
        p.to(p.at(0.28, 0.86))
        p.to(p.at(0.72, 0.86))
        p.to(p.at(0.76, 0.40))
        p.close()
        p.line([p.at(0.50, 0.76), p.at(0.50, 0.52)])
        p.line([p.at(0.50, 0.60), p.at(0.38, 0.52)])
        p.line([p.at(0.50, 0.60), p.at(0.62, 0.52)])
    },

    // Panettone: hoher Kuchen mit Papiermanschette und Kuppel.
    "panettone": { p in
        // **Senkrechte Rillen in einem sich verjüngenden Behälter sind ein
        // Papierkorb.** Der Panettone hat eine Kuppel, die über die
        // Manschette **hinausragt**, und die Manschette sitzt unten — das ist
        // sein Bild, nicht die Rillen.
        p.begin(p.at(0.22, 0.50))
        p.bow(p.at(0.78, 0.50), p.at(0.26, 0.12), p.at(0.74, 0.12))
        p.line([p.at(0.28, 0.50), p.at(0.30, 0.86), p.at(0.70, 0.86),
                p.at(0.72, 0.50)], closed: true)
        p.line([p.at(0.28, 0.64), p.at(0.72, 0.64)])
        p.line([p.at(0.40, 0.30), p.at(0.44, 0.20)])
        p.line([p.at(0.56, 0.28), p.at(0.60, 0.18)])
    },

    // Getreideriegel: Riegel mit Körnerstruktur und Wickel.
    "getreideriegel": { p in
        p.line([p.at(0.12, 0.44), p.at(0.88, 0.38), p.at(0.90, 0.62),
                p.at(0.14, 0.68)], closed: true)
        p.line([p.at(0.34, 0.42), p.at(0.36, 0.66)])
        p.line([p.at(0.62, 0.40), p.at(0.64, 0.64)])
        p.dot(p.at(0.24, 0.54), 0.03)
        p.dot(p.at(0.48, 0.52), 0.03)
        p.dot(p.at(0.76, 0.50), 0.03)
    },

    // Trüffel: knollige Knolle mit warziger Oberfläche.
    "trüffel": { p in
        p.begin(p.at(0.50, 0.20))
        p.bow(p.at(0.20, 0.52), p.at(0.30, 0.20), p.at(0.18, 0.36))
        p.bow(p.at(0.44, 0.86), p.at(0.22, 0.72), p.at(0.30, 0.86))
        p.bow(p.at(0.80, 0.56), p.at(0.66, 0.88), p.at(0.82, 0.76))
        p.bow(p.at(0.50, 0.20), p.at(0.78, 0.36), p.at(0.68, 0.20))
        p.close()
        p.dot(p.at(0.40, 0.46), 0.04)
        p.dot(p.at(0.58, 0.42), 0.04)
        p.dot(p.at(0.52, 0.64), 0.04)
        p.dot(p.at(0.34, 0.66), 0.04)
    },

    // Erdnussbutter: Glas mit Deckel und der Nuss darauf.
    "erdnussbutter": { p in
        p.line([p.at(0.26, 0.22), p.at(0.74, 0.22), p.at(0.74, 0.32),
                p.at(0.26, 0.32)], closed: true)
        p.line([p.at(0.26, 0.32), p.at(0.24, 0.88), p.at(0.76, 0.88),
                p.at(0.74, 0.32)])
        p.begin(p.at(0.40, 0.56))
        p.bow(p.at(0.60, 0.56), p.at(0.40, 0.42), p.at(0.60, 0.42))
        p.bow(p.at(0.40, 0.56), p.at(0.60, 0.70), p.at(0.40, 0.70))
        p.close()
        p.line([p.at(0.50, 0.44), p.at(0.50, 0.68)])
    },

    // Kokoswasser: Nuss mit Strohhalm.
    "kokoswasser": { p in
        p.circle(p.at(0.46, 0.60), 0.30)
        p.line([p.at(0.52, 0.32), p.at(0.78, 0.10)])
        p.line([p.at(0.78, 0.10), p.at(0.90, 0.14)])
        p.dot(p.at(0.36, 0.50), 0.035)
        p.dot(p.at(0.54, 0.52), 0.035)
    },

    // Kräutertee: Beutel mit Fähnchen am Faden.
    "pfefferminztee": { p in
        p.line([p.at(0.30, 0.44), p.at(0.62, 0.44), p.at(0.58, 0.88),
                p.at(0.34, 0.88)], closed: true)
        p.line([p.at(0.46, 0.44), p.at(0.46, 0.28)])
        p.line([p.at(0.46, 0.28), p.at(0.74, 0.20)])
        p.line([p.at(0.74, 0.20), p.at(0.74, 0.34), p.at(0.50, 0.40)])
    },

    // Weißwein: Kelchglas mit Stiel und Fuß.
    "weißwein": { p in
        p.begin(p.at(0.28, 0.16))
        p.bow(p.at(0.50, 0.58), p.at(0.28, 0.42), p.at(0.36, 0.56))
        p.bow(p.at(0.72, 0.16), p.at(0.64, 0.56), p.at(0.72, 0.42))
        p.close()
        p.line([p.at(0.50, 0.58), p.at(0.50, 0.84)])
        p.line([p.at(0.32, 0.86), p.at(0.68, 0.86)])
        p.line([p.at(0.31, 0.34), p.at(0.69, 0.34)])
    },
]

// MARK: - Tranche 8: Haushalt und Pflege

/// **Achtundzwanzig Zeichen zu Tranche 8** (2026-08-07) — das erste Non-Food.
///
/// Hier gilt eine andere Regel als bei Lebensmitteln: Ein Apfel ist ein Apfel,
/// aber Duschgel, Shampoo und Handcreme sind **dieselbe Flasche**. Getrennt
/// sind sie über das, was oben draufsitzt — Pumpe, Klappdeckel, Sprühkopf,
/// Tube ohne Kopf — und über die Proportion. Wo auch das nicht trägt, stehen
/// verwandte Dinge unter einem Begriff (`allzweckreiniger` trägt Glas-, Bad-
/// und WC-Reiniger).
private let tranche8: [String: ItemGlyph.Rezept] = [

    // Müllbeutel: Rolle mit abgerissenem Beutel.
    "müllbeutel": { p in
        // **Eine Rolle mit Loch über einem Trichter ist eine Kamera.** Der
        // Müllbeutel braucht seine eigene Form: oben offen und gerafft, unten
        // ausgebeult — ein Sack, kein Gerät.
        p.begin(p.at(0.26, 0.30))
        p.bow(p.at(0.74, 0.30), p.at(0.34, 0.22), p.at(0.66, 0.22))
        p.bow(p.at(0.78, 0.72), p.at(0.78, 0.44), p.at(0.82, 0.58))
        p.bow(p.at(0.50, 0.92), p.at(0.74, 0.86), p.at(0.62, 0.92))
        p.bow(p.at(0.22, 0.72), p.at(0.38, 0.92), p.at(0.26, 0.86))
        p.bow(p.at(0.26, 0.30), p.at(0.18, 0.58), p.at(0.22, 0.44))
        p.close()
        p.line([p.at(0.26, 0.30), p.at(0.20, 0.18)])
        p.line([p.at(0.42, 0.26), p.at(0.40, 0.14)])
        p.line([p.at(0.58, 0.26), p.at(0.62, 0.14)])
        p.line([p.at(0.74, 0.30), p.at(0.80, 0.18)])
    },

    // Alufolie: Schachtel mit herausgezogener Bahn und Zackenkante.
    "alufolie": { p in
        p.line([p.at(0.12, 0.52), p.at(0.72, 0.52), p.at(0.72, 0.82),
                p.at(0.12, 0.82)], closed: true)
        p.line([p.at(0.12, 0.52), p.at(0.24, 0.38), p.at(0.84, 0.38),
                p.at(0.72, 0.52)])
        p.line([p.at(0.84, 0.38), p.at(0.84, 0.68), p.at(0.72, 0.82)])
        p.line([p.at(0.20, 0.52), p.at(0.26, 0.60), p.at(0.34, 0.52),
                p.at(0.42, 0.60), p.at(0.50, 0.52)])
    },

    // Geschirrtab: Würfel mit Kern.
    "geschirrtabs": { p in
        p.line([p.at(0.20, 0.36), p.at(0.68, 0.36), p.at(0.68, 0.80),
                p.at(0.20, 0.80)], closed: true)
        p.line([p.at(0.68, 0.36), p.at(0.84, 0.26), p.at(0.84, 0.70),
                p.at(0.68, 0.80)])
        p.line([p.at(0.20, 0.36), p.at(0.36, 0.26), p.at(0.84, 0.26)])
        p.circle(p.at(0.44, 0.58), 0.10)
    },

    // Schwamm: Quader mit rauer Oberseite.
    "putzlappen": { p in
        p.line([p.at(0.14, 0.48), p.at(0.72, 0.48), p.at(0.72, 0.80),
                p.at(0.14, 0.80)], closed: true)
        p.line([p.at(0.72, 0.48), p.at(0.88, 0.36), p.at(0.88, 0.68),
                p.at(0.72, 0.80)])
        p.line([p.at(0.14, 0.48), p.at(0.30, 0.36), p.at(0.88, 0.36)])
        p.line([p.at(0.14, 0.62), p.at(0.72, 0.62)])
        p.dot(p.at(0.28, 0.72), 0.03)
        p.dot(p.at(0.48, 0.70), 0.03)
    },

    // Reiniger: Sprühflasche mit Pistolengriff.
    "allzweckreiniger": { p in
        p.line([p.at(0.32, 0.36), p.at(0.30, 0.88), p.at(0.70, 0.88),
                p.at(0.68, 0.36)], closed: true)
        p.line([p.at(0.42, 0.36), p.at(0.42, 0.22), p.at(0.58, 0.22),
                p.at(0.58, 0.36)])
        p.line([p.at(0.42, 0.26), p.at(0.24, 0.14)])
        p.line([p.at(0.24, 0.14), p.at(0.12, 0.18)])
        p.line([p.at(0.34, 0.56), p.at(0.66, 0.56)])
    },

    // Servietten: gefalteter Stapel mit Diagonale.
    "servietten": { p in
        p.line([p.at(0.18, 0.30), p.at(0.82, 0.30), p.at(0.82, 0.74),
                p.at(0.18, 0.74)], closed: true)
        p.line([p.at(0.18, 0.30), p.at(0.82, 0.74)])
        p.line([p.at(0.18, 0.80), p.at(0.82, 0.80)])
        p.line([p.at(0.20, 0.86), p.at(0.80, 0.86)])
    },

    // Kerze: Stumpf mit Docht und Flamme.
    "kerzen": { p in
        p.line([p.at(0.34, 0.42), p.at(0.34, 0.90), p.at(0.66, 0.90),
                p.at(0.66, 0.42)], closed: true)
        p.line([p.at(0.50, 0.42), p.at(0.50, 0.34)])
        p.begin(p.at(0.50, 0.34))
        p.bow(p.at(0.50, 0.10), p.at(0.38, 0.28), p.at(0.42, 0.14))
        p.bow(p.at(0.50, 0.34), p.at(0.58, 0.14), p.at(0.62, 0.28))
        p.close()
    },

    // Streichholz: Schachtel mit einem Holz davor.
    "streichhölzer": { p in
        p.line([p.at(0.14, 0.50), p.at(0.62, 0.50), p.at(0.62, 0.84),
                p.at(0.14, 0.84)], closed: true)
        p.line([p.at(0.14, 0.62), p.at(0.62, 0.62)])
        p.line([p.at(0.66, 0.78), p.at(0.86, 0.34)])
        p.dot(p.at(0.88, 0.28), 0.07)
    },

    // Batterie: Zelle mit Pluspol.
    "batterien": { p in
        p.line([p.at(0.28, 0.24), p.at(0.62, 0.24), p.at(0.62, 0.88),
                p.at(0.28, 0.88)], closed: true)
        p.line([p.at(0.38, 0.24), p.at(0.38, 0.16), p.at(0.52, 0.16),
                p.at(0.52, 0.24)])
        p.line([p.at(0.34, 0.44), p.at(0.56, 0.44)])
        p.line([p.at(0.45, 0.36), p.at(0.45, 0.52)])
        p.line([p.at(0.34, 0.70), p.at(0.56, 0.70)])
    },

    // Glühbirne: Kolben mit Sockelgewinde.
    "glühbirne": { p in
        p.begin(p.at(0.36, 0.56))
        p.bow(p.at(0.64, 0.56), p.at(0.20, 0.14), p.at(0.80, 0.14))
        p.close()
        p.line([p.at(0.38, 0.62), p.at(0.62, 0.62)])
        p.line([p.at(0.38, 0.72), p.at(0.62, 0.72)])
        p.line([p.at(0.42, 0.82), p.at(0.58, 0.82)])
    },

    // Strohhalm: zwei geknickte Halme.
    "strohhalme": { p in
        p.line([p.at(0.28, 0.90), p.at(0.40, 0.32), p.at(0.22, 0.16)])
        p.line([p.at(0.56, 0.90), p.at(0.66, 0.36), p.at(0.86, 0.24)])
    },

    // Geschenkpapier: Rolle mit Schleife.
    "geschenkpapier": { p in
        p.line([p.at(0.36, 0.30), p.at(0.36, 0.92)])
        p.line([p.at(0.60, 0.30), p.at(0.60, 0.92)])
        p.begin(p.at(0.36, 0.30))
        p.bow(p.at(0.60, 0.30), p.at(0.36, 0.20), p.at(0.60, 0.20))
        p.bow(p.at(0.36, 0.30), p.at(0.60, 0.40), p.at(0.36, 0.40))
        p.close()
        p.begin(p.at(0.62, 0.56))
        p.bow(p.at(0.90, 0.44), p.at(0.76, 0.62), p.at(0.90, 0.56))
        p.bow(p.at(0.62, 0.56), p.at(0.90, 0.32), p.at(0.74, 0.44))
    },

    // Stift: Bleistift mit Spitze und Radierkappe.
    "stifte": { p in
        p.line([p.at(0.24, 0.86), p.at(0.36, 0.90), p.at(0.74, 0.22),
                p.at(0.62, 0.16)], closed: true)
        p.line([p.at(0.24, 0.86), p.at(0.14, 0.94), p.at(0.36, 0.90)])
        p.line([p.at(0.62, 0.16), p.at(0.74, 0.22)])
        p.line([p.at(0.58, 0.26), p.at(0.70, 0.32)])
    },

    // Notizblock: Block mit Spirale und Zeilen.
    "notizblock": { p in
        p.line([p.at(0.24, 0.26), p.at(0.76, 0.26), p.at(0.76, 0.88),
                p.at(0.24, 0.88)], closed: true)
        for x in [0.34, 0.50, 0.66] {
            p.line([p.at(CGFloat(x), 0.20), p.at(CGFloat(x), 0.32)])
        }
        p.line([p.at(0.32, 0.50), p.at(0.68, 0.50)])
        p.line([p.at(0.32, 0.64), p.at(0.68, 0.64)])
        p.line([p.at(0.32, 0.78), p.at(0.54, 0.78)])
    },

    // Seife: Stück mit Schaumblasen.
    "seife": { p in
        // **Zwei Blasen über einem Körper sind Augen.** Dieselbe Falle wie
        // bei Kokosnuss und Brezel. Die Blasen liegen jetzt **seitlich
        // versetzt** und in drei Größen — eine Reihe, kein Paar.
        p.begin(p.at(0.12, 0.54))
        p.bow(p.at(0.72, 0.54), p.at(0.12, 0.40), p.at(0.72, 0.40))
        p.to(p.at(0.72, 0.78))
        p.bow(p.at(0.12, 0.78), p.at(0.72, 0.92), p.at(0.12, 0.92))
        p.close()
        p.circle(p.at(0.74, 0.32), 0.11)
        p.circle(p.at(0.88, 0.16), 0.07)
        p.circle(p.at(0.62, 0.16), 0.05)
    },

    // Duschgel: Flasche mit Klappdeckel.
    "duschgel": { p in
        p.line([p.at(0.38, 0.12), p.at(0.62, 0.12), p.at(0.62, 0.24),
                p.at(0.38, 0.24)], closed: true)
        p.line([p.at(0.34, 0.24), p.at(0.32, 0.88), p.at(0.68, 0.88),
                p.at(0.66, 0.24)], closed: true)
        p.line([p.at(0.36, 0.46), p.at(0.64, 0.46)])
        p.line([p.at(0.36, 0.62), p.at(0.64, 0.62)])
    },

    // Shampoo: Flasche mit Pumpe — der Kopf ist der Unterschied zum Duschgel.
    "shampoo": { p in
        p.line([p.at(0.34, 0.36), p.at(0.32, 0.88), p.at(0.68, 0.88),
                p.at(0.66, 0.36)], closed: true)
        p.line([p.at(0.46, 0.36), p.at(0.46, 0.22), p.at(0.56, 0.22)])
        p.line([p.at(0.56, 0.22), p.at(0.56, 0.14), p.at(0.74, 0.14)])
        p.line([p.at(0.74, 0.14), p.at(0.74, 0.24)])
        p.line([p.at(0.36, 0.58), p.at(0.64, 0.58)])
    },

    // Deo: schlanke Dose mit Sprühkopf.
    "deo": { p in
        p.line([p.at(0.38, 0.30), p.at(0.38, 0.88), p.at(0.62, 0.88),
                p.at(0.62, 0.30)], closed: true)
        p.line([p.at(0.42, 0.30), p.at(0.42, 0.18), p.at(0.58, 0.18),
                p.at(0.58, 0.30)])
        p.dot(p.at(0.72, 0.14), 0.03)
        p.dot(p.at(0.80, 0.22), 0.03)
        p.dot(p.at(0.70, 0.26), 0.03)
    },

    // Zahnpasta: Tube mit Schraubkappe und gequetschtem Ende.
    "zahnpasta": { p in
        p.line([p.at(0.44, 0.10), p.at(0.56, 0.10), p.at(0.56, 0.20),
                p.at(0.44, 0.20)], closed: true)
        p.line([p.at(0.40, 0.20), p.at(0.32, 0.82)])
        p.line([p.at(0.60, 0.20), p.at(0.68, 0.82)])
        p.line([p.at(0.32, 0.82), p.at(0.68, 0.82)])
        p.line([p.at(0.32, 0.82), p.at(0.30, 0.90), p.at(0.70, 0.90),
                p.at(0.68, 0.82)])
    },

    // Handcreme: flache Tube, breiter als die Zahnpasta, mit Klappdeckel.
    "handcreme": { p in
        p.line([p.at(0.40, 0.14), p.at(0.60, 0.14), p.at(0.60, 0.26),
                p.at(0.40, 0.26)], closed: true)
        p.line([p.at(0.30, 0.26), p.at(0.28, 0.86), p.at(0.72, 0.86),
                p.at(0.70, 0.26)], closed: true)
        p.begin(p.at(0.38, 0.56))
        p.bow(p.at(0.62, 0.56), p.at(0.42, 0.44), p.at(0.58, 0.44))
    },

    // Sonnencreme: Tube mit Sonne.
    "sonnencreme": { p in
        p.line([p.at(0.42, 0.14), p.at(0.58, 0.14), p.at(0.58, 0.24),
                p.at(0.42, 0.24)], closed: true)
        p.line([p.at(0.32, 0.24), p.at(0.30, 0.88), p.at(0.70, 0.88),
                p.at(0.68, 0.24)], closed: true)
        p.circle(p.at(0.50, 0.56), 0.11)
        for i in 0..<6 {
            let w = Double(i) / 6 * 2 * Double.pi
            p.line([p.at(0.50 + 0.16 * CGFloat(cos(w)), 0.56 + 0.16 * CGFloat(sin(w))),
                    p.at(0.50 + 0.22 * CGFloat(cos(w)), 0.56 + 0.22 * CGFloat(sin(w)))])
        }
    },

    // Rasierer: Griff mit Klingenkopf.
    "rasierer": { p in
        p.line([p.at(0.30, 0.20), p.at(0.70, 0.20), p.at(0.70, 0.34),
                p.at(0.30, 0.34)], closed: true)
        p.line([p.at(0.32, 0.27), p.at(0.68, 0.27)])
        p.line([p.at(0.44, 0.34), p.at(0.44, 0.90)])
        p.line([p.at(0.56, 0.34), p.at(0.56, 0.90)])
        p.line([p.at(0.44, 0.90), p.at(0.56, 0.90)])
    },

    // Wattepads: gestapelte Scheiben.
    "wattepads": { p in
        p.begin(p.at(0.18, 0.44))
        p.bow(p.at(0.82, 0.44), p.at(0.18, 0.26), p.at(0.82, 0.26))
        p.bow(p.at(0.18, 0.44), p.at(0.82, 0.62), p.at(0.18, 0.62))
        p.close()
        p.begin(p.at(0.18, 0.58))
        p.bow(p.at(0.82, 0.58), p.at(0.18, 0.76), p.at(0.82, 0.76))
        p.begin(p.at(0.18, 0.70))
        p.bow(p.at(0.82, 0.70), p.at(0.18, 0.88), p.at(0.82, 0.88))
    },

    // Pflaster: Streifen mit Wundkissen.
    "pflaster": { p in
        p.begin(p.at(0.18, 0.34))
        p.bow(p.at(0.30, 0.22), p.at(0.10, 0.26), p.at(0.20, 0.18))
        p.to(p.at(0.82, 0.66))
        p.bow(p.at(0.70, 0.78), p.at(0.90, 0.74), p.at(0.80, 0.82))
        p.close()
        p.line([p.at(0.36, 0.38), p.at(0.64, 0.62)])
        p.line([p.at(0.30, 0.48), p.at(0.58, 0.70)])
    },

    // Schmerzmittel: Blister mit Tabletten.
    "schmerzmittel": { p in
        p.line([p.at(0.18, 0.32), p.at(0.82, 0.32), p.at(0.82, 0.78),
                p.at(0.18, 0.78)], closed: true)
        p.circle(p.at(0.34, 0.46), 0.08)
        p.circle(p.at(0.58, 0.46), 0.08)
        p.circle(p.at(0.34, 0.64), 0.08)
        p.circle(p.at(0.58, 0.64), 0.08)
    },

    // Vitamine: Dose mit Deckel und Tablette.
    "vitamine": { p in
        p.line([p.at(0.30, 0.24), p.at(0.70, 0.24), p.at(0.70, 0.34),
                p.at(0.30, 0.34)], closed: true)
        p.line([p.at(0.30, 0.34), p.at(0.30, 0.86), p.at(0.70, 0.86),
                p.at(0.70, 0.34)])
        p.circle(p.at(0.50, 0.60), 0.12)
        p.line([p.at(0.38, 0.60), p.at(0.62, 0.60)])
    },

    // Tampon: Hülse mit Rückholband.
    "tampons": { p in
        // Breiter als der erste Wurf: bei 0,26 fiel die Hülse durch die
        // Schwelle gegen entartete Zeichnungen — dieselbe wie beim
        // Müsliriegel.
        p.capsule(0.50, 0.46, 0.34, 0.58, tilt: 0)
        p.line([p.at(0.50, 0.75), p.at(0.50, 0.94)])
        p.line([p.at(0.33, 0.38), p.at(0.67, 0.38)])
    },

    // Lippenstift: ausgefahrene Mine im Hülsenkörper.
    "makeup": { p in
        p.line([p.at(0.36, 0.44), p.at(0.36, 0.90), p.at(0.64, 0.90),
                p.at(0.64, 0.44)], closed: true)
        p.line([p.at(0.40, 0.44), p.at(0.40, 0.20)])
        p.line([p.at(0.60, 0.44), p.at(0.60, 0.20)])
        p.begin(p.at(0.40, 0.20))
        p.bow(p.at(0.60, 0.20), p.at(0.44, 0.08), p.at(0.62, 0.12))
        p.close()
    },
]

// MARK: - Tranche 9: Baumarkt, Garten, Tierbedarf

/// **Sechsundzwanzig Zeichen zu Tranche 9** (2026-08-07) — der Rest des
/// Katalogs.
///
/// Hier zeigt sich die Arbeitsteilung, um die es die ganze Zeit ging: Diese
/// Begriffe arbeiten **für die Liste**, nicht für den Angebotsvergleich.
/// Tierfutter bleibt im Vergleich `nonfood` (der Riegel greift vor dem
/// Wörterbuch), bekommt auf der Kachel aber sein Zeichen — weil
/// `ItemGlyphTerm` das Wörterbuch direkt fragt.
private let tranche9: [String: ItemGlyph.Rezept] = [

    // Toilettenpapier: Rolle mit Hülse und abgerissener Bahn.
    "toilettenpapier": { p in
        p.circle(p.at(0.44, 0.52), 0.32)
        p.circle(p.at(0.44, 0.52), 0.11)
        p.line([p.at(0.72, 0.42), p.at(0.90, 0.36), p.at(0.90, 0.72),
                p.at(0.74, 0.68)])
    },

    // Waschmittel: Karton mit Griffloch und Messbecher.
    "waschmittel": { p in
        p.line([p.at(0.16, 0.34), p.at(0.66, 0.34), p.at(0.66, 0.86),
                p.at(0.16, 0.86)], closed: true)
        p.line([p.at(0.28, 0.44), p.at(0.54, 0.44)])
        p.begin(p.at(0.70, 0.62))
        p.to(p.at(0.74, 0.86))
        p.to(p.at(0.92, 0.86))
        p.to(p.at(0.94, 0.62))
        p.close()
    },

    // Spülmittel: Flasche mit Kappe und Schaumblasen.
    "spülmittel": { p in
        p.line([p.at(0.42, 0.10), p.at(0.58, 0.10), p.at(0.58, 0.22),
                p.at(0.42, 0.22)], closed: true)
        p.line([p.at(0.36, 0.22), p.at(0.34, 0.88), p.at(0.66, 0.88),
                p.at(0.64, 0.22)], closed: true)
        p.circle(p.at(0.80, 0.34), 0.08)
        p.circle(p.at(0.88, 0.52), 0.05)
    },

    // Besteck: Gabel und Messer gekreuzt.
    "besteck": { p in
        p.line([p.at(0.30, 0.90), p.at(0.30, 0.42)])
        p.line([p.at(0.22, 0.10), p.at(0.22, 0.32), p.at(0.38, 0.32),
                p.at(0.38, 0.10)])
        p.line([p.at(0.30, 0.42), p.at(0.22, 0.32)])
        p.line([p.at(0.30, 0.42), p.at(0.38, 0.32)])
        p.line([p.at(0.68, 0.90), p.at(0.68, 0.46)])
        p.begin(p.at(0.68, 0.46))
        p.bow(p.at(0.68, 0.12), p.at(0.82, 0.42), p.at(0.82, 0.16))
        p.close()
    },

    // Pfanne: Topf von der Seite mit Stiel.
    "pfanne": { p in
        p.begin(p.at(0.14, 0.44))
        p.to(p.at(0.18, 0.76))
        p.bow(p.at(0.62, 0.76), p.at(0.24, 0.88), p.at(0.56, 0.88))
        p.to(p.at(0.66, 0.44))
        p.close()
        p.line([p.at(0.66, 0.50), p.at(0.94, 0.42)])
        p.line([p.at(0.10, 0.42), p.at(0.70, 0.42)])
    },

    // Backform: Springform mit Rand und Boden.
    "backform": { p in
        p.begin(p.at(0.14, 0.42))
        p.bow(p.at(0.86, 0.42), p.at(0.14, 0.26), p.at(0.86, 0.26))
        p.bow(p.at(0.14, 0.42), p.at(0.86, 0.58), p.at(0.14, 0.58))
        p.close()
        p.line([p.at(0.14, 0.42), p.at(0.18, 0.72)])
        p.line([p.at(0.86, 0.42), p.at(0.82, 0.72)])
        p.begin(p.at(0.18, 0.72))
        p.bow(p.at(0.82, 0.72), p.at(0.24, 0.86), p.at(0.76, 0.86))
        p.circle(p.at(0.50, 0.42), 0.11)
    },

    // Küchenhelfer: Schneebesen mit Bügeln.
    "küchenhelfer": { p in
        p.line([p.at(0.50, 0.14), p.at(0.50, 0.44)])
        p.line([p.at(0.42, 0.10), p.at(0.58, 0.10)])
        p.begin(p.at(0.50, 0.44))
        p.bow(p.at(0.50, 0.90), p.at(0.20, 0.56), p.at(0.22, 0.84))
        p.begin(p.at(0.50, 0.44))
        p.bow(p.at(0.50, 0.90), p.at(0.80, 0.56), p.at(0.78, 0.84))
        p.begin(p.at(0.50, 0.44))
        p.bow(p.at(0.50, 0.90), p.at(0.36, 0.60), p.at(0.36, 0.86))
        p.begin(p.at(0.50, 0.44))
        p.bow(p.at(0.50, 0.90), p.at(0.64, 0.60), p.at(0.64, 0.86))
    },

    // Schere: zwei Blätter und zwei Ringe.
    "schere": { p in
        p.line([p.at(0.28, 0.16), p.at(0.62, 0.62)])
        p.line([p.at(0.72, 0.16), p.at(0.38, 0.62)])
        p.circle(p.at(0.32, 0.78), 0.14)
        p.circle(p.at(0.68, 0.78), 0.14)
    },

    // Handschuh: Stulpe mit Daumen und vier Fingern.
    "handschuhe": { p in
        p.line([p.at(0.26, 0.90), p.at(0.24, 0.50)])
        p.line([p.at(0.74, 0.90), p.at(0.76, 0.50)])
        p.line([p.at(0.26, 0.90), p.at(0.74, 0.90)])
        for x in [0.34, 0.48, 0.62] {
            p.begin(p.at(CGFloat(x) - 0.05, 0.50))
            p.bow(p.at(CGFloat(x) + 0.05, 0.50), p.at(CGFloat(x) - 0.05, 0.18),
                  p.at(CGFloat(x) + 0.05, 0.18))
        }
        p.begin(p.at(0.76, 0.56))
        p.bow(p.at(0.88, 0.40), p.at(0.90, 0.56), p.at(0.92, 0.44))
        p.bow(p.at(0.76, 0.44), p.at(0.84, 0.34), p.at(0.76, 0.36))
    },

    // Luftballon: Ballon mit Knoten und Schnur.
    "luftballon": { p in
        p.begin(p.at(0.50, 0.14))
        p.bow(p.at(0.50, 0.62), p.at(0.18, 0.20), p.at(0.20, 0.58))
        p.bow(p.at(0.50, 0.14), p.at(0.80, 0.58), p.at(0.82, 0.20))
        p.close()
        p.line([p.at(0.44, 0.62), p.at(0.56, 0.62), p.at(0.50, 0.70)], closed: true)
        p.begin(p.at(0.50, 0.70))
        p.bow(p.at(0.56, 0.94), p.at(0.42, 0.80), p.at(0.62, 0.84))
    },

    // Taschenlampe: Griff mit Reflektorkopf und Strahlen.
    "taschenlampe": { p in
        // **Senkrecht mit Strahlen nach oben war eine Giraffe.** Eine
        // Taschenlampe liegt schräg und leuchtet **zur Seite**; der Kegel
        // sagt, dass sie an ist, und trennt sie von jedem Rohr.
        p.line([p.at(0.16, 0.66), p.at(0.20, 0.46), p.at(0.52, 0.54),
                p.at(0.48, 0.74)], closed: true)
        p.line([p.at(0.52, 0.50), p.at(0.60, 0.52), p.at(0.56, 0.78),
                p.at(0.48, 0.76)], closed: true)
        p.line([p.at(0.60, 0.52), p.at(0.90, 0.30)])
        p.line([p.at(0.56, 0.78), p.at(0.92, 0.72)])
        p.line([p.at(0.72, 0.42), p.at(0.86, 0.50)])
    },

    // Büroklammer: gebogener Draht.
    "büroklammern": { p in
        p.begin(p.at(0.36, 0.86))
        p.to(p.at(0.36, 0.30))
        p.bow(p.at(0.64, 0.30), p.at(0.36, 0.14), p.at(0.64, 0.14))
        p.to(p.at(0.64, 0.74))
        p.bow(p.at(0.48, 0.74), p.at(0.64, 0.86), p.at(0.48, 0.86))
        p.to(p.at(0.48, 0.34))
    },

    // Hundefutter: Napf mit Knochen.
    "hundefutter": { p in
        p.begin(p.at(0.12, 0.58))
        p.bow(p.at(0.88, 0.58), p.at(0.20, 0.90), p.at(0.80, 0.90))
        p.close()
        p.line([p.at(0.32, 0.36), p.at(0.68, 0.30)])
        p.circle(p.at(0.28, 0.32), 0.08)
        p.circle(p.at(0.28, 0.42), 0.08)
        p.circle(p.at(0.72, 0.26), 0.08)
        p.circle(p.at(0.72, 0.36), 0.08)
    },

    // Katzenfutter: Dose mit Ring und Fischgräte.
    "katzenfutter": { p in
        p.begin(p.at(0.22, 0.40))
        p.bow(p.at(0.78, 0.40), p.at(0.22, 0.26), p.at(0.78, 0.26))
        p.bow(p.at(0.22, 0.40), p.at(0.78, 0.54), p.at(0.22, 0.54))
        p.close()
        p.line([p.at(0.22, 0.40), p.at(0.22, 0.82)])
        p.line([p.at(0.78, 0.40), p.at(0.78, 0.82)])
        p.begin(p.at(0.22, 0.82))
        p.bow(p.at(0.78, 0.82), p.at(0.28, 0.92), p.at(0.72, 0.92))
        p.line([p.at(0.38, 0.66), p.at(0.62, 0.66)])
        p.line([p.at(0.44, 0.60), p.at(0.44, 0.72)])
        p.line([p.at(0.54, 0.60), p.at(0.54, 0.72)])
    },

    // Vogelfutter: Knödel im Netz am Haken.
    "vogelfutter": { p in
        p.circle(p.at(0.50, 0.62), 0.28)
        p.line([p.at(0.50, 0.34), p.at(0.50, 0.16)])
        p.begin(p.at(0.50, 0.16))
        p.bow(p.at(0.66, 0.16), p.at(0.50, 0.06), p.at(0.66, 0.06))
        p.line([p.at(0.28, 0.50), p.at(0.72, 0.74)])
        p.line([p.at(0.28, 0.74), p.at(0.72, 0.50)])
    },

    // Blumenerde: Sack mit Erde und Trieb.
    "blumenerde": { p in
        p.line([p.at(0.20, 0.44), p.at(0.80, 0.44), p.at(0.76, 0.90),
                p.at(0.24, 0.90)], closed: true)
        p.line([p.at(0.20, 0.44), p.at(0.28, 0.34), p.at(0.50, 0.42),
                p.at(0.72, 0.34), p.at(0.80, 0.44)])
        p.line([p.at(0.50, 0.76), p.at(0.50, 0.58)])
        blatt(&p, von: (0.50, 0.64), nach: (0.32, 0.54), bauch: 0.06)
        blatt(&p, von: (0.50, 0.64), nach: (0.68, 0.54), bauch: -0.06)
    },

    // Blumentopf: Topf mit Rand und Untersetzer.
    "blumentopf": { p in
        p.line([p.at(0.24, 0.36), p.at(0.76, 0.36)])
        p.line([p.at(0.26, 0.36), p.at(0.34, 0.82), p.at(0.66, 0.82),
                p.at(0.74, 0.36)], closed: true)
        p.line([p.at(0.26, 0.44), p.at(0.74, 0.44)])
        p.begin(p.at(0.28, 0.86))
        p.bow(p.at(0.72, 0.86), p.at(0.34, 0.94), p.at(0.66, 0.94))
    },

    // Zimmerpflanze: Topf mit drei Blättern.
    "zimmerpflanze": { p in
        p.line([p.at(0.30, 0.62), p.at(0.36, 0.90), p.at(0.64, 0.90),
                p.at(0.70, 0.62)], closed: true)
        p.line([p.at(0.50, 0.62), p.at(0.50, 0.34)])
        blatt(&p, von: (0.50, 0.42), nach: (0.22, 0.26), bauch: 0.09)
        blatt(&p, von: (0.50, 0.42), nach: (0.78, 0.26), bauch: -0.09)
        blatt(&p, von: (0.50, 0.34), nach: (0.52, 0.08), bauch: 0.09)
    },

    // Gartenwerkzeug: Spaten mit Stiel und Griff.
    "gartenwerkzeug": { p in
        p.line([p.at(0.50, 0.28), p.at(0.50, 0.58)])
        p.line([p.at(0.38, 0.16), p.at(0.62, 0.16)])
        p.line([p.at(0.38, 0.16), p.at(0.38, 0.28), p.at(0.62, 0.28),
                p.at(0.62, 0.16)])
        p.line([p.at(0.34, 0.58), p.at(0.66, 0.58), p.at(0.62, 0.82),
                p.at(0.50, 0.92), p.at(0.38, 0.82)], closed: true)
    },

    // Schraube: Kopf mit Schlitz und Gewinde.
    "schrauben": { p in
        p.line([p.at(0.30, 0.18), p.at(0.70, 0.18), p.at(0.70, 0.30),
                p.at(0.30, 0.30)], closed: true)
        p.line([p.at(0.40, 0.24), p.at(0.60, 0.24)])
        p.line([p.at(0.42, 0.30), p.at(0.42, 0.76), p.at(0.50, 0.92),
                p.at(0.58, 0.76), p.at(0.58, 0.30)])
        p.line([p.at(0.42, 0.44), p.at(0.58, 0.50)])
        p.line([p.at(0.42, 0.58), p.at(0.58, 0.64)])
    },

    // Pinsel: Stiel mit Zwinge und Borsten.
    "pinsel": { p in
        p.line([p.at(0.50, 0.10), p.at(0.50, 0.46)])
        p.line([p.at(0.38, 0.46), p.at(0.62, 0.46), p.at(0.62, 0.58),
                p.at(0.38, 0.58)], closed: true)
        p.line([p.at(0.36, 0.58), p.at(0.32, 0.90), p.at(0.68, 0.90),
                p.at(0.64, 0.58)], closed: true)
        p.line([p.at(0.44, 0.62), p.at(0.42, 0.88)])
        p.line([p.at(0.56, 0.62), p.at(0.58, 0.88)])
    },

    // Streusalz: Sack mit Schneeflocke.
    "streusalz": { p in
        p.line([p.at(0.22, 0.42), p.at(0.78, 0.42), p.at(0.74, 0.90),
                p.at(0.26, 0.90)], closed: true)
        p.line([p.at(0.22, 0.42), p.at(0.30, 0.30), p.at(0.70, 0.30),
                p.at(0.78, 0.42)])
        for i in 0..<3 {
            let w = Double(i) / 3 * Double.pi
            p.line([p.at(0.50 - 0.14 * CGFloat(cos(w)), 0.66 - 0.14 * CGFloat(sin(w))),
                    p.at(0.50 + 0.14 * CGFloat(cos(w)), 0.66 + 0.14 * CGFloat(sin(w)))])
        }
    },

    // Holzkohle: Sack mit Briketts davor.
    "holzkohle": { p in
        p.line([p.at(0.20, 0.34), p.at(0.72, 0.34), p.at(0.68, 0.76),
                p.at(0.24, 0.76)], closed: true)
        p.line([p.at(0.20, 0.34), p.at(0.28, 0.24), p.at(0.64, 0.24),
                p.at(0.72, 0.34)])
        p.begin(p.at(0.30, 0.82))
        p.bow(p.at(0.56, 0.86), p.at(0.34, 0.74), p.at(0.54, 0.76))
        p.bow(p.at(0.30, 0.82), p.at(0.50, 0.94), p.at(0.34, 0.92))
        p.close()
        p.begin(p.at(0.62, 0.80))
        p.bow(p.at(0.86, 0.84), p.at(0.66, 0.72), p.at(0.86, 0.74))
        p.bow(p.at(0.62, 0.80), p.at(0.82, 0.92), p.at(0.66, 0.90))
        p.close()
    },

    // Grillzange: zwei Schenkel mit Gelenk.
    "grillzubehör": { p in
        p.begin(p.at(0.24, 0.16))
        p.bow(p.at(0.40, 0.86), p.at(0.26, 0.48), p.at(0.34, 0.70))
        p.begin(p.at(0.24, 0.16))
        p.bow(p.at(0.62, 0.84), p.at(0.34, 0.44), p.at(0.54, 0.68))
        p.begin(p.at(0.40, 0.86))
        p.bow(p.at(0.30, 0.92), p.at(0.36, 0.92), p.at(0.32, 0.94))
        p.begin(p.at(0.62, 0.84))
        p.bow(p.at(0.74, 0.90), p.at(0.68, 0.90), p.at(0.72, 0.92))
    },

    // Sonnenschirm: Schirmdach mit Mast und Fuß.
    "sonnenschirm": { p in
        p.begin(p.at(0.10, 0.48))
        p.bow(p.at(0.90, 0.48), p.at(0.20, 0.10), p.at(0.80, 0.10))
        p.close()
        p.line([p.at(0.30, 0.48), p.at(0.50, 0.14), p.at(0.70, 0.48)])
        p.line([p.at(0.50, 0.14), p.at(0.50, 0.86)])
        p.line([p.at(0.36, 0.90), p.at(0.64, 0.90)])
    },

    // Socken: Paar, eine leicht versetzt.
    "socken": { p in
        p.begin(p.at(0.16, 0.20))
        p.to(p.at(0.34, 0.20))
        p.to(p.at(0.34, 0.56))
        p.bow(p.at(0.14, 0.76), p.at(0.34, 0.72), p.at(0.24, 0.78))
        p.bow(p.at(0.16, 0.56), p.at(0.06, 0.74), p.at(0.14, 0.62))
        p.close()
        p.begin(p.at(0.52, 0.30))
        p.to(p.at(0.70, 0.30))
        p.to(p.at(0.70, 0.66))
        p.bow(p.at(0.50, 0.86), p.at(0.70, 0.82), p.at(0.60, 0.88))
        p.bow(p.at(0.52, 0.66), p.at(0.42, 0.84), p.at(0.50, 0.72))
        p.close()
    },
]

// MARK: - Tranche 10: der Rest

/// **Einundzwanzig Zeichen zu Tranche 10** (2026-08-07) — was nach neun
/// Runden übrig war: Kosmetik-Detail, Tiefkühl-Varianten, Einzelstücke.
private let tranche10: [String: ItemGlyph.Rezept] = [

    // Haargel: Tiegel mit Schraubdeckel und Wirbel.
    "haargel": { p in
        p.line([p.at(0.22, 0.36), p.at(0.78, 0.36), p.at(0.78, 0.48),
                p.at(0.22, 0.48)], closed: true)
        p.line([p.at(0.24, 0.48), p.at(0.26, 0.84), p.at(0.74, 0.84),
                p.at(0.76, 0.48)])
        p.begin(p.at(0.38, 0.66))
        p.bow(p.at(0.62, 0.66), p.at(0.42, 0.56), p.at(0.58, 0.56))
        p.line([p.at(0.40, 0.28), p.at(0.44, 0.14)])
        p.line([p.at(0.56, 0.28), p.at(0.60, 0.14)])
    },

    // Gesichtsmaske: Tuchmaske mit Augen- und Mundöffnung.
    "gesichtsmaske": { p in
        p.begin(p.at(0.50, 0.14))
        p.bow(p.at(0.22, 0.56), p.at(0.28, 0.16), p.at(0.20, 0.34))
        p.bow(p.at(0.50, 0.90), p.at(0.24, 0.78), p.at(0.36, 0.90))
        p.bow(p.at(0.78, 0.56), p.at(0.64, 0.90), p.at(0.76, 0.78))
        p.bow(p.at(0.50, 0.14), p.at(0.80, 0.34), p.at(0.72, 0.16))
        p.close()
        p.line([p.at(0.34, 0.44), p.at(0.44, 0.44)])
        p.line([p.at(0.56, 0.44), p.at(0.66, 0.44)])
        p.begin(p.at(0.42, 0.68))
        p.bow(p.at(0.58, 0.68), p.at(0.46, 0.74), p.at(0.54, 0.74))
    },

    // Nagelfeile: schmales Blatt mit Griff und Riffelung.
    "nagelfeile": { p in
        p.line([p.at(0.26, 0.88), p.at(0.36, 0.90), p.at(0.66, 0.16),
                p.at(0.52, 0.12)], closed: true)
        p.line([p.at(0.30, 0.78), p.at(0.42, 0.82)])
        p.line([p.at(0.36, 0.62), p.at(0.48, 0.66)])
        p.line([p.at(0.42, 0.46), p.at(0.54, 0.50)])
        p.line([p.at(0.48, 0.30), p.at(0.60, 0.34)])
    },

    // Parfüm: Flakon mit Zerstäuber.
    "parfüm": { p in
        p.line([p.at(0.30, 0.44), p.at(0.30, 0.88), p.at(0.70, 0.88),
                p.at(0.70, 0.44)], closed: true)
        p.line([p.at(0.42, 0.44), p.at(0.42, 0.28), p.at(0.58, 0.28),
                p.at(0.58, 0.44)])
        p.begin(p.at(0.58, 0.32))
        p.bow(p.at(0.78, 0.24), p.at(0.68, 0.34), p.at(0.76, 0.30))
        p.dot(p.at(0.86, 0.18), 0.035)
        p.dot(p.at(0.92, 0.28), 0.03)
    },

    // Mückenschutz: Sprühflasche mit Mücke.
    "mückenschutz": { p in
        p.line([p.at(0.28, 0.42), p.at(0.28, 0.88), p.at(0.60, 0.88),
                p.at(0.60, 0.42)], closed: true)
        p.line([p.at(0.36, 0.42), p.at(0.36, 0.28), p.at(0.52, 0.28),
                p.at(0.52, 0.42)])
        p.capsule(0.80, 0.36, 0.10, 0.24, tilt: 20)
        p.line([p.at(0.74, 0.26), p.at(0.66, 0.14)])
        p.line([p.at(0.84, 0.26), p.at(0.92, 0.14)])
    },

    // Muskelcreme: Tube mit Wärmestrahlen.
    "muskelcreme": { p in
        p.line([p.at(0.42, 0.36), p.at(0.58, 0.36), p.at(0.58, 0.46),
                p.at(0.42, 0.46)], closed: true)
        p.line([p.at(0.34, 0.46), p.at(0.32, 0.90), p.at(0.68, 0.90),
                p.at(0.66, 0.46)], closed: true)
        for x in [0.36, 0.50, 0.64] {
            p.begin(p.at(CGFloat(x), 0.28))
            p.bow(p.at(CGFloat(x), 0.10), p.at(CGFloat(x) - 0.07, 0.22),
                  p.at(CGFloat(x) + 0.07, 0.16))
        }
    },

    // Kohletabletten: Röhrchen mit Tabletten.
    "kohletabletten": { p in
        p.line([p.at(0.36, 0.24), p.at(0.64, 0.24), p.at(0.64, 0.34),
                p.at(0.36, 0.34)], closed: true)
        p.line([p.at(0.36, 0.34), p.at(0.36, 0.88), p.at(0.64, 0.88),
                p.at(0.64, 0.34)])
        p.circle(p.at(0.50, 0.50), 0.09)
        p.circle(p.at(0.50, 0.70), 0.09)
    },

    // Kondome: Packung mit Ring.
    "kondome": { p in
        // **Ein breites Rechteck mit Kreis in der Mitte ist ein Geldschein.**
        // Die Packung steht hochkant, hat eine Zackenkante zum Abreißen und
        // den Ring als Umriss statt als Scheibe.
        p.line([p.at(0.30, 0.26), p.at(0.70, 0.26), p.at(0.70, 0.86),
                p.at(0.30, 0.86)], closed: true)
        p.line([p.at(0.30, 0.36), p.at(0.36, 0.30), p.at(0.44, 0.36),
                p.at(0.52, 0.30), p.at(0.60, 0.36), p.at(0.70, 0.30)])
        p.circle(p.at(0.50, 0.62), 0.13)
        p.circle(p.at(0.50, 0.62), 0.05)
    },

    // Kontaktlinsen: Blister mit Linse.
    "kontaktlinsen": { p in
        p.begin(p.at(0.20, 0.50))
        p.bow(p.at(0.72, 0.50), p.at(0.20, 0.26), p.at(0.72, 0.26))
        p.bow(p.at(0.20, 0.50), p.at(0.72, 0.74), p.at(0.20, 0.74))
        p.close()
        p.line([p.at(0.72, 0.36), p.at(0.90, 0.30)])
        p.line([p.at(0.72, 0.64), p.at(0.90, 0.70)])
        p.begin(p.at(0.34, 0.50))
        p.bow(p.at(0.58, 0.50), p.at(0.36, 0.38), p.at(0.56, 0.38))
        p.bow(p.at(0.34, 0.50), p.at(0.56, 0.62), p.at(0.36, 0.62))
    },

    // Klobürste: Bürstenkopf am Stiel im Ständer.
    "klobürste": { p in
        p.line([p.at(0.50, 0.12), p.at(0.50, 0.46)])
        p.begin(p.at(0.34, 0.46))
        p.bow(p.at(0.66, 0.46), p.at(0.34, 0.68), p.at(0.66, 0.68))
        p.close()
        p.line([p.at(0.32, 0.72), p.at(0.36, 0.90), p.at(0.64, 0.90),
                p.at(0.68, 0.72)], closed: true)
    },

    // Möbelpolitur: Dose mit Sprühkopf und Glanzsternen.
    "möbelpolitur": { p in
        p.line([p.at(0.32, 0.34), p.at(0.32, 0.88), p.at(0.64, 0.88),
                p.at(0.64, 0.34)], closed: true)
        p.line([p.at(0.40, 0.34), p.at(0.40, 0.20), p.at(0.56, 0.20),
                p.at(0.56, 0.34)])
        p.line([p.at(0.76, 0.24), p.at(0.88, 0.36)])
        p.line([p.at(0.88, 0.24), p.at(0.76, 0.36)])
        p.line([p.at(0.78, 0.54), p.at(0.86, 0.62)])
        p.line([p.at(0.86, 0.54), p.at(0.78, 0.62)])
    },

    // Aufbackbrötchen: zwei Rohlinge auf dem Blech.
    "aufbackbrötchen": { p in
        p.begin(p.at(0.14, 0.56))
        p.bow(p.at(0.46, 0.56), p.at(0.14, 0.30), p.at(0.46, 0.30))
        p.close()
        p.begin(p.at(0.54, 0.56))
        p.bow(p.at(0.86, 0.56), p.at(0.54, 0.30), p.at(0.86, 0.30))
        p.close()
        p.line([p.at(0.24, 0.44), p.at(0.36, 0.44)])
        p.line([p.at(0.64, 0.44), p.at(0.76, 0.44)])
        p.line([p.at(0.08, 0.62), p.at(0.92, 0.62), p.at(0.86, 0.76),
                p.at(0.14, 0.76)], closed: true)
    },

    // Schokobrötchen: Brötchen mit Tropfen.
    "schokobrötchen": { p in
        p.begin(p.at(0.16, 0.68))
        p.bow(p.at(0.84, 0.68), p.at(0.18, 0.26), p.at(0.82, 0.26))
        p.close()
        p.dot(p.at(0.36, 0.48), 0.055)
        p.dot(p.at(0.56, 0.42), 0.055)
        p.dot(p.at(0.64, 0.58), 0.055)
        p.dot(p.at(0.42, 0.62), 0.055)
    },

    // Knoblauchpulver: Streuer mit Knolle.
    "knoblauchpulver": { p in
        p.line([p.at(0.30, 0.38), p.at(0.30, 0.88), p.at(0.70, 0.88),
                p.at(0.70, 0.38)], closed: true)
        p.line([p.at(0.34, 0.28), p.at(0.66, 0.28), p.at(0.70, 0.38)])
        p.line([p.at(0.34, 0.28), p.at(0.30, 0.38)])
        p.begin(p.at(0.50, 0.52))
        p.bow(p.at(0.36, 0.70), p.at(0.40, 0.54), p.at(0.36, 0.62))
        p.bow(p.at(0.64, 0.70), p.at(0.36, 0.80), p.at(0.64, 0.80))
        p.bow(p.at(0.50, 0.52), p.at(0.64, 0.62), p.at(0.60, 0.54))
        p.close()
    },

    // Backaroma: Fläschchen mit Tropfer.
    "mandelaroma": { p in
        // Breiter als der erste Wurf — bei 0,24 fiel das Fläschchen durch die
        // Schwelle gegen entartete Zeichnungen.
        p.line([p.at(0.32, 0.48), p.at(0.32, 0.88), p.at(0.68, 0.88),
                p.at(0.68, 0.48)], closed: true)
        p.line([p.at(0.38, 0.48), p.at(0.38, 0.32), p.at(0.62, 0.32),
                p.at(0.62, 0.48)])
        p.line([p.at(0.34, 0.32), p.at(0.66, 0.32)])
        p.begin(p.at(0.42, 0.24))
        p.bow(p.at(0.58, 0.24), p.at(0.42, 0.08), p.at(0.58, 0.08))
        p.close()
    },

    // Vanillesoße: Kännchen mit Ausguss.
    "vanillesoße": { p in
        p.begin(p.at(0.22, 0.44))
        p.to(p.at(0.28, 0.84))
        p.bow(p.at(0.68, 0.84), p.at(0.34, 0.92), p.at(0.62, 0.92))
        p.to(p.at(0.74, 0.44))
        p.close()
        p.line([p.at(0.74, 0.50), p.at(0.92, 0.40)])
        p.line([p.at(0.26, 0.58), p.at(0.70, 0.58)])
    },

    // Krabbenchips: gewellte Chips im Häufchen.
    "krabbenchips": { p in
        for (cx, cy, t) in [(0.32, 0.42, -20.0), (0.62, 0.38, 25.0), (0.48, 0.68, 5.0)] {
            p.begin(p.at(CGFloat(cx) - 0.16, CGFloat(cy)))
            p.bow(p.at(CGFloat(cx) + 0.16, CGFloat(cy) + CGFloat(t) * 0.002),
                  p.at(CGFloat(cx) - 0.06, CGFloat(cy) - 0.16),
                  p.at(CGFloat(cx) + 0.06, CGFloat(cy) + 0.10))
            p.bow(p.at(CGFloat(cx) - 0.16, CGFloat(cy)),
                  p.at(CGFloat(cx) + 0.06, CGFloat(cy) + 0.20),
                  p.at(CGFloat(cx) - 0.06, CGFloat(cy) + 0.06))
            p.close()
        }
    },

    // Geschenk: Päckchen mit Band und Schleife.
    "geschenk": { p in
        p.line([p.at(0.16, 0.44), p.at(0.84, 0.44), p.at(0.84, 0.88),
                p.at(0.16, 0.88)], closed: true)
        p.line([p.at(0.50, 0.44), p.at(0.50, 0.88)])
        p.line([p.at(0.16, 0.58), p.at(0.84, 0.58)])
        p.begin(p.at(0.50, 0.44))
        p.bow(p.at(0.26, 0.24), p.at(0.36, 0.44), p.at(0.26, 0.34))
        p.bow(p.at(0.50, 0.44), p.at(0.26, 0.14), p.at(0.42, 0.28))
        p.begin(p.at(0.50, 0.44))
        p.bow(p.at(0.74, 0.24), p.at(0.64, 0.44), p.at(0.74, 0.34))
        p.bow(p.at(0.50, 0.44), p.at(0.74, 0.14), p.at(0.58, 0.28))
    },

    // Kostüm: Maske am Stab.
    "kostüme": { p in
        p.begin(p.at(0.50, 0.18))
        p.bow(p.at(0.18, 0.44), p.at(0.26, 0.18), p.at(0.16, 0.30))
        p.bow(p.at(0.50, 0.72), p.at(0.20, 0.62), p.at(0.32, 0.72))
        p.bow(p.at(0.82, 0.44), p.at(0.68, 0.72), p.at(0.80, 0.62))
        p.bow(p.at(0.50, 0.18), p.at(0.84, 0.30), p.at(0.74, 0.18))
        p.close()
        p.dot(p.at(0.38, 0.40), 0.05)
        p.dot(p.at(0.62, 0.40), 0.05)
        p.line([p.at(0.50, 0.72), p.at(0.50, 0.94)])
    },

    // Reflektor: Dreieck mit Strahlen.
    "reflektoren": { p in
        p.line([p.at(0.50, 0.28), p.at(0.80, 0.76), p.at(0.20, 0.76)], closed: true)
        p.line([p.at(0.50, 0.42), p.at(0.66, 0.68), p.at(0.34, 0.68)], closed: true)
        p.line([p.at(0.16, 0.24), p.at(0.26, 0.34)])
        p.line([p.at(0.84, 0.24), p.at(0.74, 0.34)])
        p.line([p.at(0.50, 0.14), p.at(0.50, 0.22)])
    },

    // Pestizide: Sprühflasche mit Verbotszeichen über dem Käfer.
    "pestizide": { p in
        p.line([p.at(0.20, 0.42), p.at(0.20, 0.88), p.at(0.52, 0.88),
                p.at(0.52, 0.42)], closed: true)
        p.line([p.at(0.28, 0.42), p.at(0.28, 0.28), p.at(0.44, 0.28),
                p.at(0.44, 0.42)])
        p.circle(p.at(0.74, 0.52), 0.20)
        p.line([p.at(0.60, 0.38), p.at(0.88, 0.66)])
    },
]

// MARK: - Tranche 11: die letzten Lücken

/// **Sechs Zeichen zu Tranche 11** (2026-08-07) — was nach zehn Runden noch
/// fehlte.
private let tranche11: [String: ItemGlyph.Rezept] = [

    // Lippenpflege: Stift mit abgenommener Kappe.
    "lippenpflege": { p in
        // Breiter als der erste Wurf — dieselbe Schwelle wie beim Müsliriegel.
        p.line([p.at(0.32, 0.40), p.at(0.32, 0.88), p.at(0.68, 0.88),
                p.at(0.68, 0.40)], closed: true)
        p.line([p.at(0.36, 0.40), p.at(0.36, 0.22), p.at(0.64, 0.22),
                p.at(0.64, 0.40)])
        p.begin(p.at(0.36, 0.22))
        p.bow(p.at(0.64, 0.22), p.at(0.38, 0.08), p.at(0.62, 0.08))
        p.close()
    },

    // Rindfleisch: Stück mit Knochen und Maserung.
    "rindfleisch": { p in
        p.begin(p.at(0.30, 0.28))
        p.bow(p.at(0.84, 0.50), p.at(0.62, 0.22), p.at(0.84, 0.34))
        p.bow(p.at(0.36, 0.84), p.at(0.84, 0.72), p.at(0.60, 0.86))
        p.bow(p.at(0.30, 0.28), p.at(0.16, 0.80), p.at(0.12, 0.40))
        p.close()
        p.circle(p.at(0.34, 0.52), 0.09)
        p.line([p.at(0.54, 0.42), p.at(0.66, 0.68)])
    },

    // Tofu: Block mit angeschnittener Ecke und Sojabohne.
    "naturtofu": { p in
        p.line([p.at(0.16, 0.38), p.at(0.68, 0.38), p.at(0.68, 0.82),
                p.at(0.16, 0.82)], closed: true)
        p.line([p.at(0.68, 0.38), p.at(0.84, 0.28), p.at(0.84, 0.72),
                p.at(0.68, 0.82)])
        p.line([p.at(0.16, 0.38), p.at(0.32, 0.28), p.at(0.84, 0.28)])
        p.begin(p.at(0.34, 0.56))
        p.bow(p.at(0.50, 0.56), p.at(0.34, 0.46), p.at(0.50, 0.46))
        p.bow(p.at(0.34, 0.56), p.at(0.50, 0.66), p.at(0.34, 0.66))
        p.close()
    },

    // Speisemöhren: Bund mit drei Wurzeln und Grün.
    "speisemöhren": { p in
        for (x, t) in [(0.32, -14.0), (0.50, 0.0), (0.68, 14.0)] {
            p.begin(p.at(CGFloat(x) - 0.09, 0.42))
            p.bow(p.at(CGFloat(x) + CGFloat(t) * 0.004, 0.90),
                  p.at(CGFloat(x) - 0.06, 0.68), p.at(CGFloat(x) - 0.01, 0.82))
            p.bow(p.at(CGFloat(x) + 0.09, 0.42),
                  p.at(CGFloat(x) + 0.03, 0.82), p.at(CGFloat(x) + 0.08, 0.68))
            p.close()
        }
        p.line([p.at(0.20, 0.36), p.at(0.80, 0.36)])
        p.line([p.at(0.32, 0.36), p.at(0.24, 0.14)])
        p.line([p.at(0.50, 0.36), p.at(0.50, 0.10)])
        p.line([p.at(0.68, 0.36), p.at(0.76, 0.14)])
    },

    // Fruchtsaft: Flasche mit Fruchtscheibe auf dem Etikett.
    "fruchtsaft": { p in
        p.line([p.at(0.42, 0.08), p.at(0.58, 0.08), p.at(0.58, 0.20),
                p.at(0.42, 0.20)], closed: true)
        p.line([p.at(0.44, 0.20), p.at(0.42, 0.36)])
        p.line([p.at(0.56, 0.20), p.at(0.58, 0.36)])
        p.line([p.at(0.42, 0.36), p.at(0.32, 0.50), p.at(0.32, 0.90),
                p.at(0.68, 0.90), p.at(0.68, 0.50), p.at(0.58, 0.36)])
        p.circle(p.at(0.50, 0.66), 0.12)
        p.line([p.at(0.38, 0.66), p.at(0.62, 0.66)])
    },

    // Cola: Dose mit Lasche und Wellenband.
    "cola": { p in
        p.line([p.at(0.32, 0.24), p.at(0.68, 0.24), p.at(0.68, 0.86),
                p.at(0.32, 0.86)], closed: true)
        p.begin(p.at(0.32, 0.24))
        p.bow(p.at(0.68, 0.24), p.at(0.32, 0.14), p.at(0.68, 0.14))
        p.circle(p.at(0.50, 0.21), 0.045)
        p.begin(p.at(0.32, 0.56))
        p.bow(p.at(0.68, 0.56), p.at(0.44, 0.44), p.at(0.56, 0.68))
    },
]

/// Ein Blatt als zwei Bögen zwischen zwei Punkten. **Kräuter unterscheiden
/// sich in der Blattform, und die entsteht aus der Bauchtiefe** — ohne einen
/// gemeinsamen Baustein wären es zwanzig handgelegte Kurven, die beim ersten
/// Nachziehen auseinanderlaufen.
private func blatt(_ p: inout Pen, von a: (CGFloat, CGFloat),
                   nach b: (CGFloat, CGFloat), bauch: CGFloat) {
    let mx = (a.0 + b.0) / 2, my = (a.1 + b.1) / 2
    let dx = b.0 - a.0, dy = b.1 - a.1
    let len = max(0.0001, (dx * dx + dy * dy).squareRoot())
    let nx = -dy / len * bauch, ny = dx / len * bauch
    p.begin(p.at(a.0, a.1))
    p.bow(p.at(b.0, b.1), p.at(mx + nx, my + ny), p.at(mx + nx, my + ny))
    p.bow(p.at(a.0, a.1), p.at(mx - nx, my - ny), p.at(mx - nx, my - ny))
    p.close()
}

/// Der Karton, den sich die drei Säfte teilen: Giebel links, Strohhalm rechts.
///
/// **Der erste Entwurf war ein konisches Glas mit der Frucht darüber — und
/// las sich als Blumentopf mit Pflanze.** Alle drei. Ein sich nach unten
/// verjüngendes Gefäß mit etwas Rundem obendrauf ist im Kopf ein Topf, egal
/// was gemeint war. Der Strohhalm räumt das aus: Kein Blumentopf hat einen.
///
/// **Eine Funktion und nicht dreimal derselbe Block** — sonst laufen die drei
/// beim ersten Nachziehen auseinander, und das Motiv lebt davon, dass sie es
/// nicht tun. Die Frucht sitzt auf dem Bauch wie ein Etikett; dieselbe Lesart
/// wie bei `tomatensauce`.
private func saftkarton(_ p: inout Pen) {
    p.line([p.at(0.24, 0.34), p.at(0.24, 0.92), p.at(0.70, 0.92),
            p.at(0.70, 0.34)], closed: true)
    p.line([p.at(0.24, 0.34), p.at(0.38, 0.22), p.at(0.70, 0.22),
            p.at(0.70, 0.34)])
    p.line([p.at(0.38, 0.22), p.at(0.38, 0.34), p.at(0.70, 0.34)])
    // Der Strohhalm, mit Knick.
    p.line([p.at(0.60, 0.26), p.at(0.78, 0.14), p.at(0.90, 0.18)])
}

/// Eine Hälfte einer Artikelzeichnung als `Shape` — wie `CategoryGlyphShape`,
/// nur mit dem Begriff statt der Kategorie als Schlüssel.
struct ItemGlyphShape: Shape {
    let term: String
    let part: CategoryGlyphShape.Part
    /// Wenn gesetzt, liefert `.stroke` die ausgezogene Kontur als Fläche.
    var feder: Feder.Profil?

    func path(in rect: CGRect) -> Path {
        // Immer quadratisch und mittig — eine gestreckte Möhre wäre keine.
        let side = min(rect.width, rect.height)
        let square = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2,
                            width: side, height: side)
        guard let drawing = ItemGlyph.drawing(for: term, in: square) else { return Path() }
        if part == .stroke, let feder {
            return Feder.kontur(drawing.stroke, seite: side, profil: feder)
        }
        return drawing.pfad(part)
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
            GlyphEbenen(form: { ItemGlyphShape(term: term, part: $0, feder: ItemGlyph.feder) },
                        size: size,
                        kontur: ItemGlyph.lineWidthRatio,
                        feinheit: ItemGlyph.feinLineWidthRatio,
                        ausgezogen: true)
        } else if let category {
            CategoryGlyphView(category: category, size: size)
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }
}
