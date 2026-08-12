import SwiftUI

/// **Der eigene Zeichensatz für die 15 Kategorien** — gezeichnet, nicht
/// eingekauft.
///
/// Schritt 2 von L-3 im [[Le Chariot Liste-Konzept]]. Schritt 1 lieh sich
/// Systemglyphen aus SF Symbols; das behob den Emoji-Teppich, lieferte aber
/// keinen eigenen Zeichenstil. Hier steht der Satz, mit dem die Kachel
/// aussieht wie diese App und nicht wie iOS.
///
/// **Gezeichnet wie das App-Icon** (`tools/icon.swift`): Formeln im Code,
/// keine Dateien im Bundle. 15 Zeichnungen als PDF-Assets wären 15 Dateien,
/// die niemand mehr anfasst; hier ist jede Kurve eine Zeile, die man ändern
/// kann.
///
/// **Einheitsquadrat, y nach unten.** Jede Zeichnung lebt in 0…1 und wird
/// beim Zeichnen auf das Zielrechteck gestreckt. Damit trägt derselbe Satz
/// die 13 pt der Listenzeile und die 66 pt des Detailblatts.
///
/// **Ein Strich, überall gleich breit.** Monolinie mit runden Enden ist das
/// einzige, was bei 13 pt trägt: Flächen laufen zu, Haarlinien verschwinden,
/// unterschiedliche Strichstärken werden zu Matsch. Gefüllt wird nur, was
/// als Umriss ohnehin zulaufen würde — Pfotenballen, Augen.
enum CategoryGlyph {

    /// Was gezeichnet wird — **vier Ebenen, von hinten nach vorn.**
    ///
    /// Bis zum 11.08. waren es zwei: Strich und Fläche. Das trug die Form, aber
    /// jede Zeichnung war ein hohler Umriss in derselben Farbe, und ein Raster
    /// aus hohlen Umrissen sieht aus wie ein Drahtmodell, nicht wie ein Regal.
    /// Die beiden neuen Ebenen liegen **hinter** dem Strich und nehmen ihm
    /// nichts weg: Der Umriss trägt die Bedeutung weiter allein, die Flächen
    /// geben ihm einen Körper.
    ///
    /// - `koerper`: der ausgefüllte Umriss, schwach.
    /// - `schatten`: die **abgewandte** Fläche — die Seitenwand einer Schachtel,
    ///   die Unterseite einer Frucht, die hintere von zwei Beeren. Derselbe
    ///   Farbwert, nur dichter.
    /// - `stroke`: die Monolinie, unverändert.
    /// - `fill`: die vollen Punkte — Kerne, Augen, Ballen.
    ///
    /// **Eine Farbe, zwei Dichten — und das ist eine Entscheidung, keine
    /// Sparmaßnahme.** Der erste Anlauf am 11.08. gab jeder Ware einen eigenen
    /// Ton: rote Tomate, warme Banane, cremefarbene Milch. Scott: „no i hate,
    /// i want like bring … if more then 1 color just shaded."
    ///
    /// Und der Blick in die Referenzaufnahme (`bring-referenz-2026-08-03.mp4`
    /// im Vault) gab ihm recht gegen die eigene Annahme: **Bring! ist gar
    /// nicht bunt.** Die Kachelzeichnungen dort sind durchweg **weiß** auf
    /// einer mintgrünen Kachel — eine einzige Farbe. Woher der Eindruck von
    /// Wertigkeit kommt, ist etwas anderes, und es sind drei Dinge:
    ///
    /// 1. **Tiefe durch Ton, nicht durch Farbe** — Schachteln stehen in
    ///    Dreiviertelansicht, mit einer abgesetzten Seitenwand.
    /// 2. **Mehr Gegenstand je Zeichnung** — nicht eine Beere, sondern eine
    ///    Handvoll; nicht ein Knödel, sondern ein Haufen.
    /// 3. **Textur statt Umriss** — Kerne, Rillen, Schraffur.
    ///
    /// Die Farbe war also der falsche Hebel. Was fehlt, ist Zeichnung.
    struct Drawing {
        var koerper = Path()
        var schatten = Path()
        /// Die **dünne** Innenzeichnung: Kerne, Rillen, Schraffur, Falze.
        var fein = Path()
        var stroke = Path()
        var fill = Path()
    }

    /// Deckkraft der beiden Flächen.
    ///
    /// **Erlaufen wie die Strichstärke.** Bei 0,08 ist die Körperfläche auf
    /// der Creme nicht mehr da und die Zeichnung wieder hohl; bei 0,28 steht
    /// sie so satt, dass der Strich seine eigene Kontur verliert. Der Schatten
    /// muss vom Körper unterscheidbar sein, ohne zur Fläche zu werden — der
    /// Abstand zwischen den beiden ist das, was die Dreiviertelansicht trägt.
    static let koerperDeckkraft: CGFloat = 0.14
    static let schattenDeckkraft: CGFloat = 0.34

    /// Strichstärke im Verhältnis zur Kantenlänge.
    ///
    /// **Erlaufen, nicht gewählt.** Bei 0,07 zerfällt der Satz auf der
    /// Listenzeile (13 pt → 0,9 pt Strich, unter einem Gerätepixel bei @2x),
    /// bei 0,12 laufen Schneeflocke und Pfote zu. 0,095 hält beides aus:
    /// 1,25 pt bei 13 pt, 6,2 pt auf dem Detailblatt.
    static let lineWidthRatio: CGFloat = 0.095

    /// Strichstärke der Innenzeichnung.
    ///
    /// **Die zweite Stärke, und warum es sie jetzt doch gibt.** „Ein Strich,
    /// überall gleich breit" stand hier von Anfang an, und der Satz war
    /// richtig, solange eine Zeichnung aus einem Umriss und zwei Kerben
    /// bestand: Zwei Stärken auf drei Linien sind kein Stil, sondern ein
    /// Versehen.
    ///
    /// Sobald aber Textur dazukommt — Kerne, Rillen, die Segmente einer
    /// aufgeschnittenen Zitrone —, kippt die Rechnung. Sechs Linien in
    /// Konturstärke innerhalb eines Umrisses sind bei 40 pt ein schwarzer
    /// Fleck; das steht seit der ersten Runde als Fallgrube am `pilze`-Rezept.
    /// Mit 0,055 trägt dieselbe Textur, ohne die Fläche zuzusetzen — und die
    /// Kontur bleibt die Kontur, weil sie fast doppelt so breit ist.
    ///
    /// Der Abstand ist das Entscheidende, nicht der Wert: Bei 0,075 sahen die
    /// beiden Stärken nach einem Fehler aus, nicht nach einer Ordnung.
    static let feinLineWidthRatio: CGFloat = 0.055

    /// Die Zeichnung dieser Kategorie, oder `nil` für eine, die es hier nicht
    /// gibt — dann greift der nächste Rückfall, statt dass irgendein Zeichen
    /// das Falsche behauptet.
    static func drawing(for category: String, in rect: CGRect) -> Drawing? {
        guard let recipe = recipes[category] else { return nil }
        var pen = Pen(rect: rect)
        recipe(&pen)
        return Drawing(koerper: pen.koerper, schatten: pen.schatten, fein: pen.fein,
                       stroke: pen.stroke, fill: pen.fill)
    }

    /// Nur für Tests und das Werkzeug: alle Kategorien, für die hier etwas
    /// gezeichnet ist.
    static var drawnCategories: [String] { recipes.keys.sorted() }

    // MARK: Die fünfzehn

    private static let recipes: [String: (inout Pen) -> Void] = [

        // Apfel: zwei Bäuche mit einer Kerbe oben, Stiel, Blatt. Die Kerbe ist
        // das, was ihn vom Kreis unterscheidet — ohne sie ist es eine Kirsche.
        "Obst & Gemüse": { p in
            p.begin(p.at(0.50, 0.30))
            p.bow(p.at(0.16, 0.55), p.at(0.36, 0.20), p.at(0.16, 0.34))
            p.bow(p.at(0.50, 0.93), p.at(0.16, 0.78), p.at(0.32, 0.93))
            p.bow(p.at(0.84, 0.55), p.at(0.68, 0.93), p.at(0.84, 0.78))
            p.bow(p.at(0.50, 0.30), p.at(0.84, 0.34), p.at(0.64, 0.20))
            p.close()
            p.begin(p.at(0.50, 0.30))
            p.bow(p.at(0.56, 0.08), p.at(0.50, 0.20), p.at(0.52, 0.12))
            p.begin(p.at(0.56, 0.16))
            p.bow(p.at(0.86, 0.13), p.at(0.66, 0.06), p.at(0.82, 0.03))
            p.bow(p.at(0.56, 0.16), p.at(0.86, 0.22), p.at(0.70, 0.20))
        },

        // Milchtüte mit Giebel. Der Falz oben ist die halbe Miete: ein
        // Rechteck mit Dreiecksdach ist ein Haus — erst die abgeflachte
        // Spitze mit dem aufgestellten Kamm macht die Tüte. Der erste
        // Entwurf hatte die Spitze und war auf dem Prüfbogen ein Haus.
        "Molkerei & Eier": { p in
            p.begin(p.at(0.22, 0.94))
            p.to(p.at(0.22, 0.42))
            p.to(p.at(0.35, 0.24))
            p.to(p.at(0.65, 0.24))
            p.to(p.at(0.78, 0.42))
            p.to(p.at(0.78, 0.94))
            p.close()
            p.line([p.at(0.22, 0.42), p.at(0.78, 0.42)])
            p.line([p.at(0.35, 0.24), p.at(0.35, 0.10), p.at(0.65, 0.10), p.at(0.65, 0.24)])
        },

        // Zwei Würstchen, leicht geneigt und gegeneinander versetzt.
        //
        // **Vierter Anlauf. Die drei davor stehen hier, weil sie zeigen,
        // woran es jedes Mal lag: an der Silhouette, nie am Strich.**
        //
        // 1. Hufeisen mit runden Kappen — die Kappen brauchten
        //    Kontrollpunkte über den Endpunkten und wurden zu zwei Hörnern.
        //    Auf dem Prüfbogen eine **Tulpe**.
        // 2. Dasselbe mit geraden Schnittflächen und großer Lücke: ein
        //    **Hufeisen**, jetzt eindeutig als solches.
        // 3. Enger Ring aus echten Kreisbögen, Lücke oben: bei 13 pt der
        //    **Ein-/Ausschalter** von iOS. Ein Ring mit einer Kerbe oben ist
        //    besetzt, und dagegen kommt keine Strichstärke an.
        //
        // Zwei Kapseln sind, was übrig bleibt, wenn man das Runde aufgibt —
        // und sie haben den Vorteil, dass **zwei** davon nie eine Pille und
        // nie eine Batterie sind. Die Neigung ist nicht Zierde: Zwei
        // senkrechte Kapseln nebeneinander sind ein Ladebalken.
        "Fleisch & Wurst": { p in
            p.capsule(0.36, 0.52, 0.26, 0.74, tilt: -16)
            p.capsule(0.65, 0.48, 0.26, 0.74, tilt: -16)
        },

        // Fisch: Körper mit spitzer Nase, Schwanzflosse als Keil, ein Auge.
        // Das Auge ist gefüllt — als Ring wäre es bei 13 pt ein Fleck.
        "Fisch": { p in
            p.begin(p.at(0.32, 0.50))
            p.bow(p.at(0.94, 0.50), p.at(0.46, 0.13), p.at(0.80, 0.18))
            p.bow(p.at(0.32, 0.50), p.at(0.80, 0.82), p.at(0.46, 0.87))
            p.close()
            p.begin(p.at(0.32, 0.50))
            p.to(p.at(0.06, 0.20))
            p.to(p.at(0.06, 0.80))
            p.close()
            p.dot(p.at(0.76, 0.42), 0.052)
        },

        // Brotlaib: Kuppe mit zwei Schnitten. Drei waren es im ersten
        // Entwurf, und bei 13 pt lief die Kuppe damit zu — zwei lassen
        // zwischen sich Fläche stehen.
        "Backwaren": { p in
            p.begin(p.at(0.10, 0.84))
            p.to(p.at(0.10, 0.56))
            p.bow(p.at(0.90, 0.56), p.at(0.10, 0.18), p.at(0.90, 0.18))
            p.to(p.at(0.90, 0.84))
            p.close()
            p.line([p.at(0.40, 0.50), p.at(0.30, 0.72)])
            p.line([p.at(0.66, 0.54), p.at(0.56, 0.76)])
        },

        // Schneeflocke: drei Achsen, jede mit vier Ästen. Ohne die Äste ist
        // es ein Sternchen.
        //
        // **Die Äste standen im ersten Entwurf am Bildrand statt am Arm** —
        // sie wurden aus rohen Einheitszahlen gebaut und nie durch `at()`
        // geschickt, landeten also bei ein paar Pixeln links oben. Auf dem
        // Prüfbogen war das ein Punkt neben der Flocke. Genau dafür gibt es
        // den Prüfbogen; im Simulator wäre es bei 13 pt Schmutz gewesen.
        "Tiefkühl": { p in
            for i in 0..<3 {
                let winkel = Double(i) * .pi / 3
                let dx = CGFloat(cos(winkel)) * 0.42, dy = CGFloat(sin(winkel)) * 0.42
                p.line([p.at(0.5 - dx, 0.5 - dy), p.at(0.5 + dx, 0.5 + dy)])
                for ende in [CGFloat(1), CGFloat(-1)] {
                    let bx = 0.5 + ende * dx * 0.52, by = 0.5 + ende * dy * 0.52
                    for seite in [1.0, -1.0] {
                        let ast = winkel + seite * 0.9
                        p.line([p.at(bx, by),
                                p.at(bx + ende * CGFloat(cos(ast)) * 0.22,
                                     by + ende * CGFloat(sin(ast)) * 0.22)])
                    }
                }
            }
        },

        // Bonbon im Papier: Kern mit zwei gedrehten Zipfeln.
        "Süßes & Snacks": { p in
            p.begin(p.at(0.36, 0.32))
            p.to(p.at(0.64, 0.32))
            p.bow(p.at(0.64, 0.68), p.at(0.78, 0.42), p.at(0.78, 0.58))
            p.to(p.at(0.36, 0.68))
            p.bow(p.at(0.36, 0.32), p.at(0.22, 0.58), p.at(0.22, 0.42))
            p.close()
            p.line([p.at(0.30, 0.38), p.at(0.06, 0.20), p.at(0.10, 0.50),
                    p.at(0.06, 0.80), p.at(0.30, 0.62)])
            p.line([p.at(0.70, 0.38), p.at(0.94, 0.20), p.at(0.90, 0.50),
                    p.at(0.94, 0.80), p.at(0.70, 0.62)])
        },

        // Flasche mit Verschluss: Deckel, Hals, Schulter, Bauch.
        "Getränke": { p in
            p.begin(p.at(0.41, 0.20))
            p.to(p.at(0.41, 0.34))
            p.bow(p.at(0.26, 0.54), p.at(0.41, 0.44), p.at(0.26, 0.44))
            p.to(p.at(0.26, 0.94))
            p.to(p.at(0.74, 0.94))
            p.to(p.at(0.74, 0.54))
            p.bow(p.at(0.59, 0.34), p.at(0.74, 0.44), p.at(0.59, 0.44))
            p.to(p.at(0.59, 0.20))
            p.close()
            p.line([p.at(0.39, 0.20), p.at(0.61, 0.20), p.at(0.61, 0.08),
                    p.at(0.39, 0.08)], closed: true)
        },

        // Weinglas: Kelch, Stiel, Fuß. Der lesbarste Kandidat des ganzen
        // Satzes — drei Striche und niemand fragt nach.
        "Alkohol": { p in
            p.begin(p.at(0.26, 0.12))
            p.to(p.at(0.74, 0.12))
            p.bow(p.at(0.50, 0.58), p.at(0.74, 0.44), p.at(0.64, 0.58))
            p.bow(p.at(0.26, 0.12), p.at(0.36, 0.58), p.at(0.26, 0.44))
            p.close()
            p.line([p.at(0.50, 0.58), p.at(0.50, 0.86)])
            p.line([p.at(0.28, 0.90), p.at(0.72, 0.90)])
        },

        // Kochtopf: Deckel mit Knauf, Korpus, zwei Griffe.
        "Vorräte & Kochen": { p in
            p.line([p.at(0.44, 0.14), p.at(0.56, 0.14)])
            p.line([p.at(0.50, 0.14), p.at(0.50, 0.26)])
            p.line([p.at(0.16, 0.30), p.at(0.84, 0.30)])
            p.begin(p.at(0.24, 0.36))
            p.to(p.at(0.30, 0.90))
            p.to(p.at(0.70, 0.90))
            p.to(p.at(0.76, 0.36))
            p.begin(p.at(0.24, 0.42))
            p.bow(p.at(0.10, 0.56), p.at(0.12, 0.42), p.at(0.10, 0.48))
            p.begin(p.at(0.76, 0.42))
            p.bow(p.at(0.90, 0.56), p.at(0.88, 0.42), p.at(0.90, 0.48))
        },

        // Seifenstück mit zwei Blasen.
        //
        // **Zweimal keine Flasche mehr.** Erster Entwurf: Pumpspender.
        // Zweiter: Tube. Beide standen auf dem Prüfbogen bei 13 pt neben den
        // Getränken wie deren Zwilling — ein hochkanter Behälter mit
        // Schulter und Deckel ist ein hochkanter Behälter mit Schulter und
        // Deckel, egal was oben draufsitzt. Das Seifenstück liegt **quer**
        // und ist damit die einzige Zeichnung des Satzes, die man schon an
        // der Ausrichtung erkennt.
        "Drogerie": { p in
            p.stroke.addRoundedRect(in: p.box(0.50, 0.70, 0.76, 0.40),
                                    cornerSize: p.corner(0.16))
            p.circle(p.at(0.70, 0.24), 0.145)
            p.circle(p.at(0.36, 0.26), 0.10)
        },

        // Besen: Stiel, Bund, Borsten. Der Bund trennt Stiel und Kopf — ohne
        // ihn ist es ein Trichter am Stock.
        "Haushalt": { p in
            p.line([p.at(0.50, 0.08), p.at(0.50, 0.46)])
            p.begin(p.at(0.24, 0.92))
            p.to(p.at(0.34, 0.46))
            p.to(p.at(0.66, 0.46))
            p.to(p.at(0.76, 0.92))
            p.close()
            p.line([p.at(0.30, 0.66), p.at(0.70, 0.66)])
        },

        // Pfote: vier Zehen und ein Ballen, gefüllt. Als Umrisse liefen sie
        // bei 13 pt zu — ein Ring von 3 px ist ein Punkt.
        //
        // Die Zehen stehen auf einem Bogen und nicht auf einer Geraden, und
        // der Ballen ist kleiner als im ersten Entwurf: Dort saß er so tief
        // und breit, dass die Zehen wie Krümel darüber lagen.
        "Tierbedarf": { p in
            p.dot(p.at(0.19, 0.38), 0.098)
            p.dot(p.at(0.39, 0.23), 0.103)
            p.dot(p.at(0.62, 0.23), 0.103)
            p.dot(p.at(0.82, 0.38), 0.098)
            p.fill.addEllipse(in: p.box(0.50, 0.68, 0.50, 0.40))
        },

        // Bärenkopf: Schädel, zwei Ohren, Schnauze, zwei Augen. Der ganze
        // Bär war der erste Entwurf und war bei 13 pt ein Fleck mit Beinen.
        "Kinder": { p in
            p.circle(p.at(0.26, 0.28), 0.14)
            p.circle(p.at(0.74, 0.28), 0.14)
            p.circle(p.at(0.50, 0.58), 0.32)
            p.dot(p.at(0.39, 0.51), 0.05)
            p.dot(p.at(0.61, 0.51), 0.05)
            p.fill.addEllipse(in: p.box(0.50, 0.70, 0.26, 0.18))
        },

        // Einkaufskorb: Bügel, Wanne, zwei Rippen. Nicht der Wagen — der ist
        // das App-Icon und die letzte Reserve der Kachel; zwei Wagen
        // übereinander wären eine Verwechslung.
        "Sonstiges": { p in
            p.begin(p.at(0.32, 0.38))
            p.bow(p.at(0.68, 0.38), p.at(0.32, 0.14), p.at(0.68, 0.14))
            p.begin(p.at(0.10, 0.40))
            p.to(p.at(0.22, 0.90))
            p.to(p.at(0.78, 0.90))
            p.to(p.at(0.90, 0.40))
            p.close()
            p.line([p.at(0.38, 0.50), p.at(0.42, 0.80)])
            p.line([p.at(0.62, 0.50), p.at(0.58, 0.80)])
        },
    ]
}

/// **Die Feder: eine Mittellinie wird zu einer Kontur, die ihre Breite ändert.**
///
/// Scott, 11.08., nach dem Blick auf Bring!: „their drawing font has different
/// sizes by drawing, like u use a pencil in reallife and draw a circle."
///
/// Und das ist der Punkt, an dem eine gleichmäßige Monolinie nicht mehr
/// weiterkommt. `stroke(lineWidth:)` kann nur **eine** Breite über den ganzen
/// Pfad — deshalb sieht jede so gezeichnete Form gedruckt aus und keine
/// gezeichnet. Wer mit einem Stift einen Kreis zieht, dreht die Hand nicht mit:
/// Die Spitze liegt schräg, und der Strich wird dort breit, wo er quer zur
/// Spitze läuft, und schmal, wo er längs läuft.
///
/// Genau das steht hier. Die Mittellinie wird abgetastet, an jedem Punkt die
/// Tangente bestimmt, und die halbe Breite links und rechts abgetragen — mit
/// einem Faktor, der vom Winkel zwischen Tangente und Federhaltung abhängt.
/// Heraus kommt eine **gefüllte** Fläche, kein gestrichener Pfad.
///
/// Der Preis ist ehrlich zu nennen: Die Kontur ist danach kein Pfad mehr, den
/// man animieren oder mit `.trim` aufziehen kann. Für den Artikelsatz ist das
/// gleichgültig — er wird gezeichnet, nicht bewegt. `CartGlyph` bleibt deshalb
/// bei der echten Linie, denn die **wird** aufgezogen.
enum Feder {

    /// Wie die Feder gehalten wird.
    struct Profil {
        /// Grundbreite im Verhältnis zur Kantenlänge — was `lineWidthRatio`
        /// vorher allein war, hier nur noch das Maximum.
        var breite: CGFloat
        /// Federwinkel in Grad. Ein Strich **quer** dazu wird am breitesten.
        var neigung: Double = -32
        /// Schmalste Breite als Anteil der Grundbreite. 1,0 wäre wieder die
        /// gleichmäßige Monolinie; unter 0,4 zerfällt der Strich dort, wo er
        /// längs zur Feder läuft.
        var schmal: CGFloat = 0.52
        /// Über welchen Anteil der Länge ein **offenes** Ende ausläuft.
        /// Geschlossene Umrisse haben keine Enden und laufen nicht aus.
        var spitze: CGFloat = 0.16
        /// **Untergrenze in Punkten, nicht im Verhältnis.**
        ///
        /// `schmal` ist ein *Verhältnis* und schrumpft deshalb mit der
        /// Zeichnung mit — bei kleinen Größen läuft die schmalste Stelle
        /// unter das, was auf dem Gerät noch ein Strich ist, und reißt auf.
        /// Die Untergrenze steht dagegen in **Punkten**: Kein Abschnitt wird
        /// schmaler als dieser Wert, egal wie stark die Feder sonst moduliert.
        ///
        /// **Das ist der Grund, warum `schmal` nicht mehr die Größe mitdenken
        /// muss.** Vorher war der Wert ein Kompromiss zwischen „groß soll man
        /// die Feder sehen" und „klein darf sie nicht zerfallen"; jetzt
        /// beantwortet die Klemme die zweite Hälfte, und `schmal` ist wieder
        /// eine reine Gestaltungsfrage.
        ///
        /// Bei 0,072 Grundbreite und `schmal` 0,46 greift sie genau dort, wo
        /// es eng wird: 90 pt → 2,98 pt schmalste Stelle, ungeklemmt; 40 pt →
        /// 1,32 wird **1,50**; 22 pt → 0,73 wird **1,50**.
        var mindest: CGFloat = 1.5
    }

    /// Die ausgezogene Kontur zu einer Mittellinie.
    static func kontur(_ mittellinie: Path, seite: CGFloat, profil: Profil) -> Path {
        var ergebnis = Path()
        for zug in zuege(mittellinie) {
            ergebnis.addPath(umriss(zug.punkte, geschlossen: zug.geschlossen,
                                    breite: seite * profil.breite, profil: profil))
        }
        return ergebnis
    }

    // MARK: Zerlegen

    /// Der Pfad als Streckenzüge — Kurven werden abgetastet, weil sich eine
    /// Normale nur an einer Strecke ablesen lässt.
    private static func zuege(_ p: Path, schritte: Int = 14) -> [(punkte: [CGPoint], geschlossen: Bool)] {
        var alle: [(punkte: [CGPoint], geschlossen: Bool)] = []
        var lauf: [CGPoint] = []
        var start = CGPoint.zero
        var jetzt = CGPoint.zero

        func ablegen(_ geschlossen: Bool) {
            if lauf.count >= 2 { alle.append((lauf, geschlossen)) }
            lauf = []
        }

        p.forEach { element in
            switch element {
            case .move(let zu):
                ablegen(false)
                lauf = [zu]; start = zu; jetzt = zu
            case .line(let zu):
                lauf.append(zu); jetzt = zu
            case .quadCurve(let zu, let c):
                let von = jetzt
                for i in 1...schritte {
                    let t = CGFloat(i) / CGFloat(schritte)
                    let u: CGFloat = 1 - t
                    let a: CGFloat = u * u
                    let b: CGFloat = 2 * u * t
                    let c2: CGFloat = t * t
                    let x: CGFloat = a * von.x + b * c.x + c2 * zu.x
                    let y: CGFloat = a * von.y + b * c.y + c2 * zu.y
                    lauf.append(CGPoint(x: x, y: y))
                }
                jetzt = zu
            case .curve(let zu, let c1, let c2):
                let von = jetzt
                for i in 1...schritte {
                    let t = CGFloat(i) / CGFloat(schritte)
                    let u: CGFloat = 1 - t
                    let a: CGFloat = u * u * u
                    let b: CGFloat = 3 * u * u * t
                    let c: CGFloat = 3 * u * t * t
                    let d: CGFloat = t * t * t
                    let x: CGFloat = a * von.x + b * c1.x + c * c2.x + d * zu.x
                    let y: CGFloat = a * von.y + b * c1.y + c * c2.y + d * zu.y
                    lauf.append(CGPoint(x: x, y: y))
                }
                jetzt = zu
            case .closeSubpath:
                ablegen(true)
                jetzt = start
            }
        }
        ablegen(false)
        return alle
    }

    // MARK: Ausziehen

    private static func umriss(_ roh: [CGPoint], geschlossen: Bool,
                               breite: CGFloat, profil: Profil) -> Path {
        // Doppelte Punkte raus — sonst ist die Tangente dort ein Nullvektor.
        var pts: [CGPoint] = []
        for q in roh where pts.isEmpty || hypot(q.x - pts[pts.count - 1].x,
                                                q.y - pts[pts.count - 1].y) > 1e-6 {
            pts.append(q)
        }
        if geschlossen, pts.count > 2,
           hypot(pts[0].x - pts[pts.count - 1].x, pts[0].y - pts[pts.count - 1].y) < 1e-6 {
            pts.removeLast()
        }
        guard pts.count >= 2 else { return Path() }

        let n = pts.count
        var laenge: [CGFloat] = [0]
        for i in 1..<n {
            laenge.append(laenge[i - 1] + hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y))
        }
        let gesamt = max(laenge[n - 1], 1e-6)
        let phi = profil.neigung * .pi / 180

        var links: [CGPoint] = [], rechts: [CGPoint] = []
        for i in 0..<n {
            let vor = geschlossen ? pts[(i - 1 + n) % n] : pts[max(i - 1, 0)]
            let nach = geschlossen ? pts[(i + 1) % n] : pts[min(i + 1, n - 1)]
            let tx = nach.x - vor.x, ty = nach.y - vor.y
            let tl = max(hypot(tx, ty), 1e-6)

            // Der Federeffekt: quer zur Haltung breit, längs dazu schmal.
            let winkel = atan2(ty, tx)
            var faktor = profil.schmal + (1 - profil.schmal) * abs(sin(winkel - phi))

            // Offene Enden laufen aus — ein Strich, der abrupt aufhört, sieht
            // abgeschnitten aus, keiner, der dünner wird.
            //
            // **Nur, wenn der Strich lang genug dafür ist.** Beim ersten
            // Anlauf lief die Verjüngung über einen *Anteil* der Länge, und
            // kurze Striche bestehen nur aus Enden: Das Möhrenkraut und die
            // Kelchblätter der Tomate verschwanden zu Splittern. Die Spitze
            // greift deshalb über eine Strecke, die an der Breite gemessen
            // ist — wer kürzer ist als vier Federbreiten, behält seine.
            if !geschlossen, gesamt > breite * 4 {
                let rand = min(laenge[i], gesamt - laenge[i]) / (gesamt * profil.spitze)
                faktor *= 0.55 + 0.45 * min(1, rand)
            }

            // Die Klemme sitzt am Ende, nach Feder *und* Spitze: Was hier
            // gemessen wird, ist die Breite, die wirklich gezeichnet wird.
            let h = max(profil.mindest, breite * faktor) / 2
            let nx = -ty / tl * h, ny = tx / tl * h
            links.append(CGPoint(x: pts[i].x + nx, y: pts[i].y + ny))
            rechts.append(CGPoint(x: pts[i].x - nx, y: pts[i].y - ny))
        }

        var pfad = Path()
        if geschlossen {
            // Zwei gegenläufige Ringe ergeben unter der Nonzero-Regel den
            // Reif dazwischen — genau die ausgezogene Linie.
            pfad.addLines(links)
            pfad.closeSubpath()
            pfad.addLines(rechts.reversed())
            pfad.closeSubpath()
        } else {
            // **Von Hand und nicht mit `addLines`.** `addLines` setzt selbst
            // ein `move` und beginnt damit einen *neuen* Teilpfad — die
            // Rückseite wurde so zu einer zweiten, eigenen Fläche, und unter
            // der Nonzero-Regel löschten die beiden einander stellenweise
            // aus. Auf dem Prüfbogen waren die Bananen danach hohle Umrisse.
            pfad.move(to: links[0])
            for q in links.dropFirst() { pfad.addLine(to: q) }
            for q in rechts.reversed() { pfad.addLine(to: q) }
            pfad.closeSubpath()
        }
        return pfad
    }
}

/// Der Zeichenstift: rechnet Einheitskoordinaten auf das Zielrechteck um und
/// sammelt Striche und Flächen getrennt ein.
///
/// Eigener Typ statt roher `Path`-Aufrufe in jeder Zeichnung, damit die
/// fünfzehn Rezepte oben lesbar bleiben — dort steht die Gestaltung, hier die
/// Rechnerei.
struct Pen {
    let rect: CGRect
    var koerper = Path()
    var schatten = Path()
    var fein = Path()
    var stroke = Path()
    var fill = Path()

    /// **Der zuletzt begonnene Umriss, mitgeschrieben.**
    ///
    /// Damit ein Rezept nicht zweimal dieselbe Kurve tippen muss: Es zeichnet
    /// die Silhouette wie bisher und hängt `alsKoerper()` an — derselbe Pfad
    /// wandert dann zusätzlich in die Körperfläche. Ein zweiter Satz
    /// Koordinaten für dieselbe Form wäre der sichere Weg, dass Umriss und
    /// Fläche irgendwann auseinanderlaufen.
    ///
    /// Läuft ab `begin`, `line(closed:)`, `circle`, `capsule` und `rechteck`.
    private var aktuell = Path()

    /// **Jeder geschlossene Umriss, den das Rezept gezogen hat.**
    ///
    /// Grundlage für die Körperfläche, die sich ein Rezept nicht selbst
    /// aussucht (siehe `groessteGeschlossene` und `ItemGlyph.drawing`). Offene
    /// Züge stehen hier bewusst nicht drin: Ein offener Pfad wird beim Füllen
    /// gedanklich geschlossen und legt dann eine Fläche dorthin, wo keine ist.
    private(set) var geschlossene: [Path] = []

    /// Der flächengrößte geschlossene Umriss — die Silhouette des Gegenstands.
    ///
    /// **Warum die größte und nicht die erste:** Die Reihenfolge im Rezept ist
    /// Gestaltungsgeschichte, keine Aussage über die Form. Beim Käse steht die
    /// abgewandte Seitenwand vor der Vorderfront, beim Eierkarton der Deckel
    /// vor der Wanne. Die Fläche ist dagegen genau das, was den Gegenstand vom
    /// Beiwerk trennt: Der Bauch ist größer als der Stiel, die Schale größer
    /// als das Blatt darin.
    var groessteGeschlossene: Path? {
        geschlossene.max { Pen.flaeche($0) < Pen.flaeche($1) }
    }

    /// Der Flächeninhalt eines geschlossenen Pfades — Gaußsche Trapezformel
    /// auf einem abgetasteten Streckenzug.
    ///
    /// Abgetastet statt über die Kontrollpunkte gerechnet, weil eine Sichel
    /// (Banane) und ihr Kontrollpolygon verschieden groß sind — und die Sichel
    /// steht in diesem Satz nicht selten neben ihrem eigenen Stiel.
    static func flaeche(_ pfad: Path) -> CGFloat {
        var punkte: [CGPoint] = []
        var letzter = CGPoint.zero
        var summe: CGFloat = 0

        func schliesse() {
            guard punkte.count >= 3 else { punkte = []; return }
            var a: CGFloat = 0
            for i in punkte.indices {
                let p = punkte[i], q = punkte[(i + 1) % punkte.count]
                a += p.x * q.y - q.x * p.y
            }
            summe += abs(a) / 2
            punkte = []
        }

        /// Ein Kurvenstück als zwölf Strecken — fein genug, dass die
        /// Reihenfolge zweier Umrisse nicht an der Abtastung hängt.
        func kurve(_ f: (CGFloat) -> CGPoint) {
            for i in 1...12 { punkte.append(f(CGFloat(i) / 12)) }
        }

        pfad.forEach { element in
            switch element {
            case .move(let to):
                schliesse()
                punkte = [to]
                letzter = to
            case .line(let to):
                punkte.append(to)
                letzter = to
            case .quadCurve(let to, let control):
                let von = letzter
                kurve { (t: CGFloat) -> CGPoint in
                    let u: CGFloat = 1 - t
                    let a: CGFloat = u * u
                    let b: CGFloat = 2 * u * t
                    let c: CGFloat = t * t
                    let x: CGFloat = a * von.x + b * control.x + c * to.x
                    let y: CGFloat = a * von.y + b * control.y + c * to.y
                    return CGPoint(x: x, y: y)
                }
                letzter = to
            case .curve(let to, let control1, let control2):
                let von = letzter
                kurve { (t: CGFloat) -> CGPoint in
                    let u: CGFloat = 1 - t
                    let a: CGFloat = u * u * u
                    let b: CGFloat = 3 * u * u * t
                    let c: CGFloat = 3 * u * t * t
                    let d: CGFloat = t * t * t
                    let x: CGFloat = a * von.x + b * control1.x + c * control2.x + d * to.x
                    let y: CGFloat = a * von.y + b * control1.y + c * control2.y + d * to.y
                    return CGPoint(x: x, y: y)
                }
                letzter = to
            case .closeSubpath:
                schliesse()
            }
        }
        schliesse()
        return summe
    }

    /// Von Hand, weil `aktuell` privat ist und der erzeugte Initialisierer
    /// damit ebenfalls privat wäre.
    init(rect: CGRect) { self.rect = rect }

    func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }

    // MARK: Die hinteren Ebenen

    /// Der zuletzt gezeichnete Umriss ist zugleich der Körper der Zeichnung.
    ///
    /// Gehört hinter den geschlossenen Umriss, nicht hinter eine Innenlinie —
    /// ein offener Pfad wird beim Füllen gedanklich geschlossen und legt dann
    /// eine Fläche dorthin, wo keine ist.
    mutating func alsKoerper() { koerper.addPath(aktuell) }

    /// Der zuletzt gezeichnete Umriss ist eine **abgewandte** Fläche.
    ///
    /// Die Seitenwand einer Schachtel, die Unterseite einer Frucht, die
    /// hintere von zwei Beeren. Beliebig oft je Zeichnung — anders als beim
    /// verworfenen Farbmodell ist hier nichts zu rationieren: Es ist derselbe
    /// Farbwert, nur dichter, und zwei Schattenflächen sind zwei abgewandte
    /// Seiten, kein zweiter Farbton.
    mutating func alsSchatten() { schatten.addPath(aktuell) }

    /// Eine gefüllte Schattenfläche ohne eigenen Umriss.
    mutating func tupfen(_ center: CGPoint, _ radius: CGFloat) {
        schatten.addEllipse(in: ring(center, radius))
    }

    // MARK: Innenzeichnung

    /// Dünner Streckenzug — Rillen, Falze, Schraffur.
    mutating func feinLinie(_ points: [CGPoint], closed: Bool = false) {
        guard let first = points.first else { return }
        fein.move(to: first)
        for point in points.dropFirst() { fein.addLine(to: point) }
        if closed { fein.closeSubpath() }
    }

    /// Dünner Kreis — Kerne, Blasen, Löcher.
    mutating func feinKreis(_ center: CGPoint, _ radius: CGFloat) {
        fein.addEllipse(in: ring(center, radius))
    }

    /// Dünner Bogen — Wölbungen, Segmente, angedeutete Rundungen.
    mutating func feinBogen(_ von: CGPoint, _ nach: CGPoint,
                            _ c1: CGPoint, _ c2: CGPoint) {
        fein.move(to: von)
        fein.addCurve(to: nach, control1: c1, control2: c2)
    }

    /// Eine Kapsel — Rechteck mit halbrunden Enden —, um ihre eigene Mitte
    /// gedreht. Maße und Mittelpunkt in Einheitsmaßen, Neigung in Grad.
    mutating func capsule(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat,
                          tilt: Double) {
        let frame = box(cx, cy, w, h)
        let form = Path(roundedRect: frame, cornerRadius: min(frame.width, frame.height) / 2)
        let mitte = at(cx, cy)
        let drehung = CGAffineTransform(translationX: mitte.x, y: mitte.y)
            .rotated(by: tilt * .pi / 180)
            .translatedBy(x: -mitte.x, y: -mitte.y)
        let gedreht = form.applying(drehung)
        stroke.addPath(gedreht)
        aktuell = gedreht
        geschlossene.append(gedreht)
    }

    /// Ein Rechteck mit runden Ecken, Maße und Radius in Einheitsmaßen.
    ///
    /// Ersetzt `p.stroke.addRoundedRect(in: p.box(…), cornerSize: p.corner(…))`
    /// an den Aufrufstellen — der rohe Weg umgeht die Mitschrift und lässt
    /// `alsKoerper()` danach ins Leere greifen.
    mutating func rechteck(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat,
                           ecke: CGFloat) {
        var form = Path()
        form.addRoundedRect(in: box(cx, cy, w, h), cornerSize: corner(ecke))
        stroke.addPath(form)
        aktuell = form
        geschlossene.append(form)
    }

    /// Eckenradius in Einheitsmaßen, für `addRoundedRect`.
    func corner(_ radius: CGFloat) -> CGSize {
        CGSize(width: radius * rect.width, height: radius * rect.height)
    }

    /// Ein Rechteck um einen Mittelpunkt, in Einheitsmaßen.
    func box(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: rect.minX + (cx - w / 2) * rect.width,
               y: rect.minY + (cy - h / 2) * rect.height,
               width: w * rect.width, height: h * rect.height)
    }

    mutating func begin(_ point: CGPoint) {
        stroke.move(to: point)
        aktuell = Path()
        aktuell.move(to: point)
    }
    mutating func to(_ point: CGPoint) {
        stroke.addLine(to: point)
        aktuell.addLine(to: point)
    }
    mutating func bow(_ point: CGPoint, _ c1: CGPoint, _ c2: CGPoint) {
        stroke.addCurve(to: point, control1: c1, control2: c2)
        aktuell.addCurve(to: point, control1: c1, control2: c2)
    }
    mutating func close() {
        stroke.closeSubpath()
        aktuell.closeSubpath()
        geschlossene.append(aktuell)
    }

    mutating func line(_ points: [CGPoint], closed: Bool = false) {
        guard let first = points.first else { return }
        stroke.move(to: first)
        aktuell = Path()
        aktuell.move(to: first)
        for point in points.dropFirst() {
            stroke.addLine(to: point)
            aktuell.addLine(to: point)
        }
        if closed {
            stroke.closeSubpath()
            aktuell.closeSubpath()
            geschlossene.append(aktuell)
        }
    }

    /// **Ein Vieleck mit abgerundeten Ecken.**
    ///
    /// Der Grund, warum es das gibt: `lineJoin: .round` rundet nur die
    /// *Außenseite* eines Knicks, der Pfad selbst knickt weiter scharf. Bei
    /// einer Strichstärke von 0,065 ist das an jeder Ecke sichtbar, und ein
    /// Satz aus Schachteln, Keilen und Dreiecken wird dadurch — Scott,
    /// 11.08. — „so kantig". Eine Milchtüte hat keine scharfen Kanten, ein
    /// Eierkarton schon gar nicht, und selbst der Käsekeil ist an der Rinde
    /// rund.
    ///
    /// Jede Ecke wird um `radius` beschnitten und durch eine quadratische
    /// Kurve über den ursprünglichen Eckpunkt ersetzt. Der Radius wird an
    /// kurzen Kanten automatisch gekürzt (halbe Kantenlänge), damit ein
    /// enges Vieleck nicht in sich zusammenfällt.
    mutating func rund(_ punkte: [CGPoint], _ radius: CGFloat, closed: Bool = true) {
        guard punkte.count >= 3 else { line(punkte, closed: closed); return }
        let r = radius * min(rect.width, rect.height)
        var form = Path()

        func gekuerzt(_ von: CGPoint, _ nach: CGPoint) -> CGPoint {
            let dx = nach.x - von.x, dy = nach.y - von.y
            let laenge = max(sqrt(dx * dx + dy * dy), 0.0001)
            let t = min(r, laenge / 2) / laenge
            return CGPoint(x: von.x + dx * t, y: von.y + dy * t)
        }

        let n = punkte.count
        // Bei einem offenen Zug bleiben erster und letzter Punkt spitz —
        // dort ist keine Ecke, sondern ein Ende.
        let ecken = closed ? Array(0..<n) : Array(1..<(n - 1))
        if !closed { form.move(to: punkte[0]) }

        for (lauf, i) in ecken.enumerated() {
            let vor = punkte[(i - 1 + n) % n]
            let hier = punkte[i]
            let nach = punkte[(i + 1) % n]
            let ein = gekuerzt(hier, vor)
            let aus = gekuerzt(hier, nach)
            if closed && lauf == 0 { form.move(to: ein) } else { form.addLine(to: ein) }
            form.addQuadCurve(to: aus, control: hier)
        }

        if closed {
            form.closeSubpath()
        } else {
            form.addLine(to: punkte[n - 1])
        }
        stroke.addPath(form)
        aktuell = form
        if closed { geschlossene.append(form) }
    }

    /// Gestrichener Kreis, Radius in Einheitsmaßen.
    mutating func circle(_ center: CGPoint, _ radius: CGFloat) {
        stroke.addEllipse(in: ring(center, radius))
        aktuell = Path(ellipseIn: ring(center, radius))
        geschlossene.append(aktuell)
    }

    /// Gestrichenes Oval um einen Mittelpunkt, Maße in Einheitsmaßen.
    ///
    /// Für alles, was rund, aber nicht kreisrund ist — und das ist der
    /// Unterschied zwischen zwei roten Früchten: Der Apfel steht hoch, die
    /// Tomate liegt breit.
    mutating func oval(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) {
        let form = Path(ellipseIn: box(cx, cy, w, h))
        stroke.addPath(form)
        aktuell = form
        geschlossene.append(form)
    }

    /// Gefüllter Punkt, Radius in Einheitsmaßen.
    mutating func dot(_ center: CGPoint, _ radius: CGFloat) {
        fill.addEllipse(in: ring(center, radius))
    }

    private func ring(_ center: CGPoint, _ radius: CGFloat) -> CGRect {
        let rx = radius * rect.width, ry = radius * rect.height
        return CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2)
    }
}

/// Eine Hälfte einer Zeichnung als `Shape` — damit sie sich wie jede andere
/// SwiftUI-Form verhält: Größe von außen, Farbe von außen, animierbar.
///
/// Zwei Formen statt eines `Canvas`, weil `Canvas` seine Farbe selbst holen
/// müsste. So erbt die Zeichnung `.foregroundStyle` von der Aufrufstelle,
/// genau wie das `Image(systemName:)` davor.
struct CategoryGlyphShape: Shape {
    /// Welche der fünf Ebenen diese Form zeigt.
    enum Part { case koerper, schatten, fein, stroke, fill }

    let category: String
    let part: Part
    /// Wenn gesetzt, liefert `.stroke` die bereits **ausgezogene** Kontur —
    /// eine Fläche, die gefüllt und nicht gestrichen wird.
    var feder: Feder.Profil?

    func path(in rect: CGRect) -> Path {
        // Immer quadratisch und mittig: eine gestreckte Milchtüte wäre keine.
        let side = min(rect.width, rect.height)
        let square = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2,
                            width: side, height: side)
        guard let drawing = CategoryGlyph.drawing(for: category, in: square) else { return Path() }
        if part == .stroke, let feder {
            return Feder.kontur(drawing.stroke, seite: side, profil: feder)
        }
        return drawing.pfad(part)
    }
}

extension CategoryGlyph.Drawing {
    /// Die Ebene zu ihrem Namen — damit die Ansicht die vier Fälle einmal
    /// aufzählt und nicht an jeder Stelle wieder.
    func pfad(_ part: CategoryGlyphShape.Part) -> Path {
        switch part {
        case .koerper: return koerper
        case .schatten: return schatten
        case .fein: return fein
        case .stroke: return stroke
        case .fill: return fill
        }
    }
}

/// **Die fünf Ebenen übereinander.**
///
/// Von hinten nach vorn: Körper, Schatten, volle Punkte, Innenzeichnung,
/// Kontur. Die Kontur zuletzt, weil sie die Kanten der Flächen aufnimmt — läge
/// eine Fläche darüber, wäre der Umriss an dieser Stelle halb so breit.
///
/// **Alles erbt `foregroundStyle` von außen.** Keine Ebene holt sich eine
/// eigene Farbe; die beiden Flächen unterscheiden sich nur in der Deckkraft.
/// Damit wird eine abgehakte Kachel grau, und zwar ganz — ohne dass die
/// Aufrufstelle etwas dafür tun müsste.
struct GlyphEbenen<S: Shape>: View {
    let form: (CategoryGlyphShape.Part) -> S
    let size: CGFloat
    /// Strichstärken als Verhältnis zur Kantenlänge. **Als Parameter und
    /// nicht als Konstante**, weil der Kategoriesatz bei 13 pt und der
    /// Artikelsatz bei 40 pt gezeichnet wird — siehe `ItemGlyph.lineWidthRatio`.
    var kontur: CGFloat = CategoryGlyph.lineWidthRatio
    var feinheit: CGFloat = CategoryGlyph.feinLineWidthRatio
    /// Ob `.stroke` schon als Fläche kommt. Muss zu dem passen, was die Form
    /// liefert — deshalb setzen beide Ansichten es gemeinsam.
    var ausgezogen: Bool = false

    var body: some View {
        ZStack {
            form(.koerper).opacity(CategoryGlyph.koerperDeckkraft)
            form(.schatten).opacity(CategoryGlyph.schattenDeckkraft)
            form(.fill)
            // Die Innenzeichnung bleibt **gleichmäßig dünn**. Auch von Hand
            // ist die Textur der leichte Strich, nicht der aufgedrückte —
            // Federwirkung auf Kernen und Rillen wäre Unruhe, keine Zeichnung.
            form(.fein)
                .stroke(style: StrokeStyle(lineWidth: size * feinheit,
                                           lineCap: .round, lineJoin: .round))
            if ausgezogen {
                form(.stroke)
            } else {
                form(.stroke)
                    .stroke(style: StrokeStyle(lineWidth: size * kontur,
                                               lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
    }
}

/// Die fertige Zeichnung: Flächen und Strich übereinander, in der Farbe, die
/// von außen kommt.
struct CategoryGlyphView: View {
    let category: String
    /// Kantenlänge. Der Strich wächst mit — fest gesetzt wäre er auf dem
    /// Detailblatt eine Haarlinie und auf der Listenzeile ein Balken.
    let size: CGFloat

    var body: some View {
        GlyphEbenen(form: { CategoryGlyphShape(category: category, part: $0) },
                    size: size)
    }
}
