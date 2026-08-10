import Foundation

/// Fixture-backed repositories for previews and tests.
enum MockFixtures {
    static let day = DateFormatter.supabaseDay

    /// Validity of the CURRENT calendar week rather than a fixed date.
    ///
    /// The fixtures used to carry 13.–19.07.2026 hard-coded, so from 20.07.
    /// onwards every preview and UI-test run showed an offer that had expired
    /// — harmless for the assertions, misleading for anyone looking at the
    /// screen, and drifting further every week.
    ///
    /// **`Calendar.supabase` und nicht `.iso8601`, weil die Zeitzone dazugehört.**
    /// Der ISO-Kalender rechnet in der Zone des *Geräts*, `OfferQuery.current`
    /// fragt aber in `Calendar.supabase`, also fest in Europe/Berlin — „Angebote
    /// tragen Berliner Mitternachte". Auf einem Gerät in Berliner Zeit fallen
    /// beide auf denselben Augenblick zusammen, und der Unterschied war
    /// jahrelang unsichtbar. Westlich davon nicht: Auf einem GitHub-Runner (UTC)
    /// liegt `weekStart` zwei Stunden **hinter** dem „heute" der Abfrage, damit
    /// ist `validFrom <= today` falsch, und **kein einziges Fixture-Angebot
    /// gilt**. Gemessen am 10.08.: Alle drei Tests von `OfferHitsJourneyTests`
    /// fielen dort an derselben Zeile, während die App „NOCH KEIN TREFFER"
    /// anzeigte; Journeys ohne Angebotsbezug waren im selben Lauf grün.
    ///
    /// Mit `Calendar.supabase` kommt überall derselbe Augenblick heraus — in
    /// Berlin derselbe wie vorher, also ändert sich lokal nichts.
    static let weekStart: Date = {
        Calendar.supabase.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
    }()
    static let weekEnd: Date = weekStart.addingTimeInterval(6 * 24 * 60 * 60)

    /// `n` weeks before the current one — for the price history.
    static func weeksAgo(_ n: Int) -> (from: Date, until: Date) {
        let from = weekStart.addingTimeInterval(TimeInterval(-n * 7 * 24 * 60 * 60))
        return (from, from.addingTimeInterval(6 * 24 * 60 * 60))
    }

    static let offers: [Offer] = [
        Offer(
            marketId: "lidl-01219-1",
            market: "Lidl",
            product: "Bio Vollmilch",
            price: 0.99,
            regularPrice: 1.29,
            unit: "je 1 l",
            category: "Molkerei & Eier",
            emoji: "🥛",
            validFrom: weekStart,
            validUntil: weekEnd,
            basePrice: 0.99,
            baseUnit: "1 l",
            nationwide: false
        ),
        Offer(
            marketId: "aldi-01219-1",
            market: "Aldi",
            product: "Spanische Orangen",
            price: 2.49,
            regularPrice: nil,
            unit: "je 2 kg Netz",
            category: "Obst & Gemüse",
            emoji: "🍊",
            validFrom: weekStart,
            validUntil: weekEnd,
            basePrice: 1.25,
            baseUnit: "1 kg",
            nationwide: false
        ),
        // **Die teurere Alternative bei derselben Kette.** Ohne sie gibt es zu
        // „Vollmilch" genau einen Treffer, und eine Wahl unter einem Angebot
        // ist keine — der Tester-Wunsch vom 2026-07-31 („ich will lieber den,
        // der nicht der billigste ist") wäre gar nicht nachstellbar.
        //
        // Zwei Entscheidungen an dieser Zeile, beide gegen stille Kollateralen:
        // Sie ist **teurer** als „Bio Vollmilch", sonst würde sie zum
        // vorgeschlagenen Angebot und drei bestehende Zusicherungen auf „Bio
        // Vollmilch" fielen um, ohne dass an ihnen etwas kaputt wäre. Und sie
        // steht **hinten**, weil `MockFixtures.offers[0]` und `[1]` quer durch
        // die Tests als feste Handgriffe benutzt werden.
        Offer(
            marketId: "lidl-01219-1",
            market: "Lidl",
            product: "Landliebe Frische Vollmilch",
            price: 1.49,
            regularPrice: nil,
            unit: "je 1 l",
            category: "Molkerei & Eier",
            emoji: "🥛",
            validFrom: weekStart,
            validUntil: weekEnd,
            basePrice: 1.49,
            baseUnit: "1 l",
            nationwide: false
        ),
        // **Das erste Fixture-Angebot, das nur über sein Tag zu finden ist.**
        // Ohne eines davon kommt jede Trefferliste im Mock-Lauf ausschließlich
        // über Stufe 1 zustande — die zweite Stufe, das Wörterbuch, war auf
        // keinem Bildschirm je zu sehen. Genau die Zeile, deren Herkunft die
        // Trefferliste seit dem 01.08. benennt („über Milch"), ließ sich also
        // nicht ansehen, nur ausrechnen.
        //
        // Der Titel trägt das Wort **nicht** — das ist der ganze Zweck. Und
        // der Preis ist der höchste der drei Milchzeilen, damit sie weder das
        // vorgeschlagene Angebot wird noch die Abdeckung einer zweiten Kette
        // verschiebt: Sie liegt bei derselben Filiale wie die billigste.
        Offer(
            marketId: "lidl-01219-1",
            market: "Lidl",
            product: "Bärenmarke Die Frische",
            price: 1.79,
            regularPrice: nil,
            unit: "je 1 l",
            category: "Molkerei & Eier",
            emoji: "🥛",
            validFrom: weekStart,
            validUntil: weekEnd,
            basePrice: 1.79,
            baseUnit: "1 l",
            nationwide: false,
            matchKey: ["milch"]
        ),
    ]

    /// Zeilen der Folgewoche — damit die Wochengrenze überhaupt prüfbar ist.
    ///
    /// Ohne sie sähen Xcode-Vorschau und Simulator nur eine Woche, und der Fehler,
    /// gegen den diese Runde antritt, wäre in den UI-Journeys unsichtbar.
    ///
    /// **Getrennt von `offers`, nicht darin** — ein halbes Dutzend Tests prüft
    /// gegen `MockFixtures.offers.count`, und genau das ist auch die Aussage:
    /// Diese Zeilen gehören nicht zur laufenden Woche. `MockOfferRepository`
    /// liefert beide Töpfe zusammen aus, so wie PostgREST es auch tut.
    static let nextWeekStart: Date = weekStart.addingTimeInterval(7 * 24 * 60 * 60)
    static let nextWeekEnd: Date = nextWeekStart.addingTimeInterval(5 * 24 * 60 * 60)

    static let nextWeekOffers: [Offer] = [
        Offer(
            marketId: "lidl-01219-1",
            market: "Lidl",
            product: "Kaffee ganze Bohne",
            price: 4.99,
            regularPrice: 7.99,
            unit: "je 1 kg",
            category: "Kaffee & Tee",
            emoji: "☕️",
            validFrom: nextWeekStart,
            validUntil: nextWeekEnd,
            basePrice: 4.99,
            baseUnit: "1 kg",
            nationwide: false,
            matchKey: ["kaffee"]
        ),
        Offer(
            marketId: "lidl-01219-1",
            market: "Lidl",
            product: "Bio Vollmilch",
            price: 0.79,
            regularPrice: 1.29,
            unit: "je 1 l",
            category: "Molkerei & Eier",
            emoji: "🥛",
            validFrom: nextWeekStart,
            validUntil: nextWeekEnd,
            basePrice: 0.79,
            baseUnit: "1 l",
            nationwide: false,
            matchKey: ["milch"]
        ),
    ]

    /// **Die dritte Kette, nur für die Vorschau-Parität** (2026-08-02).
    ///
    /// Die Markt-Leiste erscheint erst ab zwei Ketten. Damit die Vorschau eine
    /// bekommt, brauchen zwei gewählte Ketten Zeilen der Folgewoche — und für
    /// den Abschnitt „Ohne Vorschau" muss gleichzeitig eine dritte **keine**
    /// haben. Mit den zwei alten Saatgut-Filialen (Lidl, Aldi) ist das nicht zu
    /// haben: Gäbe man Aldi Zeilen, verlöre `NextWeekJourneyTests` seinen Fall.
    ///
    /// Deshalb Netto: Lidl und Netto liefern die Folgewoche, **Aldi nicht** —
    /// die drei Zustände, die der Bildschirm auseinanderhalten muss, in einem
    /// Saatgut.
    ///
    /// **Getrennt von `offers` und `nextWeekOffers`**, weil ein halbes Dutzend
    /// Tests gegen deren `count` prüft. Sichtbar wird die Kette ohnehin nur,
    /// wenn ihre Filiale gewählt ist — `MockOfferRepository` filtert nach
    /// `branchIds`, und das tut nur `-uiTestingOnboardedThreeChains`.
    static let thirdChainOffers: [Offer] = [
        Offer(
            marketId: "netto-01219-1",
            market: "Netto",
            product: "Deutsche Erdbeeren",
            price: 1.99,
            regularPrice: 2.99,
            unit: "je 500 g Schale",
            category: "Obst & Gemüse",
            emoji: "🍓",
            validFrom: weekStart,
            validUntil: weekEnd,
            basePrice: 3.98,
            baseUnit: "1 kg",
            nationwide: false
        ),
        Offer(
            marketId: "netto-01219-1",
            market: "Netto",
            product: "Rügenwalder Teewurst",
            price: 1.29,
            regularPrice: 1.99,
            unit: "je 125 g",
            category: "Fleisch & Wurst",
            emoji: "🥓",
            validFrom: nextWeekStart,
            validUntil: nextWeekEnd,
            basePrice: 10.32,
            baseUnit: "1 kg",
            nationwide: false
        ),
    ]

    /// Was `MockOfferRepository` normalerweise ausliefert.
    static let standard: [Offer] = offers + nextWeekOffers + thirdChainOffers

    // MARK: Der Sonntag

    /// **Der Sonntagszustand, ohne auf einen Sonntag zu warten** (10.08.).
    ///
    /// Scotts Feldtest vom 09.08.: acht Filialen gewählt, sichtbar nur zwei —
    /// die Prospektwochen der übrigen sechs endeten Samstag, die neuen fingen
    /// Montag an. Für 01219 galten an dem Tag **68 von 3 038** Zeilen. Der
    /// Zustand hängt am Kalender und ist damit einen Tag die Woche prüfbar;
    /// das ist keine Grundlage für einen Test und erst recht keine, um ein
    /// Bild anzusehen.
    ///
    /// **Nachgestellt wird der Zustand, nicht das Datum.** Die Zeilen hängen
    /// am letzten Samstag **vor** und am nächsten Montag **nach** heute, also
    /// an einem abgelaufenen und einem künftigen Fenster — an einem echten
    /// Sonntag sind das gestern und morgen, an jedem anderen Tag dasselbe
    /// Muster mit weiteren Abständen. Ein festes Datum wäre nach einer Woche
    /// wieder die Sorte Fixture, die den Bildschirm anlügt (siehe `weekStart`).
    ///
    /// Drei Ketten, drei Zustände — genau die, die der Bildschirm
    /// auseinanderhalten muss:
    ///  · **Lidl** hat ein längeres Fenster und steht ganz normal da (bei Scott
    ///    war das Kaufland, 01.–31.08.).
    ///  · **Aldi** ruht mit beiden Daten: endete Samstag, fängt Montag an.
    ///  · **Netto** ruht mit **nur** dem Ende — ohne Vorschau, also auch ohne
    ///    Knopf „Nächste Woche". Ohne diesen dritten Fall stünde der halbe Satz
    ///    in keinem Bild.
    static let letzterSamstag: Date = zurueck(zuWochentag: 7, vor: .now)
    static let naechsterMontag: Date = vor(zuWochentag: 2, nach: .now)

    /// Der letzte/nächste Wochentag (Gregorianisch: 1 = Sonntag … 7 = Samstag)
    /// **streng** vor bzw. nach dem Stichtag — „streng", damit an genau dem
    /// Wochentag selbst nicht null Tage herauskommen und die Zeile dann heute
    /// gälte statt gestern.
    private static func zurueck(zuWochentag ziel: Int, vor tag: Date) -> Date {
        let kalender = Calendar.supabase
        let heute = kalender.startOfDay(for: tag)
        let ist = kalender.component(.weekday, from: heute)
        let abstand = (ist - ziel + 7 - 1) % 7 + 1
        return kalender.date(byAdding: .day, value: -abstand, to: heute) ?? heute
    }

    private static func vor(zuWochentag ziel: Int, nach tag: Date) -> Date {
        let kalender = Calendar.supabase
        let heute = kalender.startOfDay(for: tag)
        let ist = kalender.component(.weekday, from: heute)
        let abstand = (ziel - ist + 7 - 1) % 7 + 1
        return kalender.date(byAdding: .day, value: abstand, to: heute) ?? heute
    }

    static let sunday: [Offer] = [
        // Die Kette mit dem langen Fenster — sie überlebt den Sonntag.
        Offer(
            marketId: "lidl-01219-1",
            market: "Lidl",
            product: "Bio Vollmilch",
            price: 0.99,
            regularPrice: 1.29,
            unit: "je 1 l",
            category: "Molkerei & Eier",
            emoji: "🥛",
            validFrom: letzterSamstag.addingTimeInterval(-20 * 24 * 60 * 60),
            validUntil: naechsterMontag.addingTimeInterval(20 * 24 * 60 * 60),
            basePrice: 0.99,
            baseUnit: "1 l",
            nationwide: false
        ),
        Offer(
            marketId: "lidl-01219-1",
            market: "Lidl",
            product: "Landliebe Frische Vollmilch",
            price: 1.49,
            regularPrice: nil,
            unit: "je 1 l",
            category: "Molkerei & Eier",
            emoji: "🥛",
            validFrom: letzterSamstag.addingTimeInterval(-20 * 24 * 60 * 60),
            validUntil: naechsterMontag.addingTimeInterval(20 * 24 * 60 * 60),
            basePrice: 1.49,
            baseUnit: "1 l",
            nationwide: false
        ),
        // Aldi: abgelaufen — und die neue Woche liegt schon vor.
        Offer(
            marketId: "aldi-01219-1",
            market: "Aldi",
            product: "Spanische Orangen",
            price: 2.49,
            regularPrice: nil,
            unit: "je 2 kg Netz",
            category: "Obst & Gemüse",
            emoji: "🍊",
            validFrom: letzterSamstag.addingTimeInterval(-5 * 24 * 60 * 60),
            validUntil: letzterSamstag,
            basePrice: 1.25,
            baseUnit: "1 kg",
            nationwide: false
        ),
        Offer(
            marketId: "aldi-01219-1",
            market: "Aldi",
            product: "Rispentomaten",
            price: 1.79,
            regularPrice: 2.49,
            unit: "je 500 g",
            category: "Obst & Gemüse",
            emoji: "🍅",
            validFrom: naechsterMontag,
            validUntil: naechsterMontag.addingTimeInterval(5 * 24 * 60 * 60),
            basePrice: 3.58,
            baseUnit: "1 kg",
            nationwide: false
        ),
        // Netto: abgelaufen, und **keine** Vorschau.
        Offer(
            marketId: "netto-01219-1",
            market: "Netto",
            product: "Deutsche Erdbeeren",
            price: 1.99,
            regularPrice: 2.99,
            unit: "je 500 g Schale",
            category: "Obst & Gemüse",
            emoji: "🍓",
            validFrom: letzterSamstag.addingTimeInterval(-5 * 24 * 60 * 60),
            validUntil: letzterSamstag,
            basePrice: 3.98,
            baseUnit: "1 kg",
            nationwide: false
        ),
    ]

    // MARK: Ein Prospekt in echter Größe

    /// **Der Vorrat für das Messgeschirr** (2026-08-02).
    ///
    /// Sieben Fixture-Zeilen ruckeln nicht, und ein Messstand, der auf sieben
    /// Zeilen misst, misst nichts. Eine Penny-Filiale trug am 01.08. in der
    /// Produktion **1 125** Zeilen nach dem Dedupe; das hier ist dieselbe
    /// Größenordnung, damit die Zahlen etwas mit dem Gerät zu tun haben.
    ///
    /// Gebaut statt abgetippt, weil nur die Menge zählt: Produktnamen,
    /// Kategorien und Preise rotieren, damit Gruppierung, Sortierung und
    /// Suche nicht auf einem Sonderfall messen. Die Bilder bleiben leer — ein
    /// Netzabruf im Messlauf wäre die Leitung, nicht die App.
    static let bulkChains = ["Lidl", "Aldi", "Netto"]

    static func bulk(perChain: Int, weeksAhead: Int = 0) -> [Offer] {
        let woerter = ["Vollmilch", "Butter", "Kaffee", "Joghurt", "Käse", "Hackfleisch",
                       "Bananen", "Tomaten", "Nudeln", "Reis", "Waschmittel", "Zahnpasta"]
        let marken = ["Landliebe", "Bärenmarke", "Milbona", "Gut & Günstig", "Ja!",
                      "Rügenwalder", "Dr. Oetker", "Barilla"]
        let from = weeksAhead == 0
            ? weekStart
            : weekStart.addingTimeInterval(TimeInterval(weeksAhead * 7 * 24 * 60 * 60))
        let until = from.addingTimeInterval(6 * 24 * 60 * 60)

        var result: [Offer] = []
        for (chainIndex, chain) in bulkChains.enumerated() {
            for i in 0..<perChain {
                let wort = woerter[i % woerter.count]
                let marke = marken[(i / woerter.count) % marken.count]
                let preis = Double((i * 37) % 900 + 49) / 100
                result.append(Offer(
                    marketId: "\(chain.lowercased())-01219-1",
                    market: chain,
                    // Die Nummer macht jeden Titel eindeutig — zwei gleiche
                    // Titel zum selben Preis fielen dem Dedupe zum Opfer, und
                    // die Liste wäre stillschweigend kürzer als bestellt.
                    product: "\(marke) \(wort) \(i + 1)",
                    price: preis,
                    regularPrice: preis * 1.3,
                    unit: "je 1 Stück",
                    category: Categories.all[(i + chainIndex) % Categories.all.count],
                    emoji: nil,
                    validFrom: from,
                    validUntil: until,
                    basePrice: preis,
                    baseUnit: "1 Stück",
                    nationwide: false,
                    matchKey: [wort.lowercased()]
                ))
            }
        }
        return result
    }

    /// Three recorded weeks for the first offer fixture — enough for the
    /// detail sheet's price history to show up in previews and UI tests.
    static let priceHistory: [PriceHistoryPoint] = [
        PriceHistoryPoint(
            market: "Lidl", product: "Bio Vollmilch", nationwide: false,
            price: 1.29, regularPrice: 1.29,
            validFrom: weeksAgo(2).from,
            validUntil: weeksAgo(2).until
        ),
        PriceHistoryPoint(
            market: "Lidl", product: "Bio Vollmilch", nationwide: false,
            price: 1.19, regularPrice: 1.29,
            validFrom: weeksAgo(1).from,
            validUntil: weeksAgo(1).until
        ),
        PriceHistoryPoint(
            market: "Lidl", product: "Bio Vollmilch", nationwide: false,
            price: 0.99, regularPrice: 1.29,
            validFrom: weekStart,
            validUntil: weekEnd
        ),
    ]

    static let markets: [Market] = [
        Market(chain: "Aldi", branchName: "Dresden Prohlis", marketId: "aldi-01219-1", plz: "01219"),
        Market(chain: "Lidl", branchName: "Dresden Reick", marketId: "lidl-01219-1", plz: "01219"),
    ]


    /// Three real Dresden stores, two of them the ones the PLZ model could
    /// never reach: the second REWE in a postcode and the Netto in the
    /// Johannes-Paul-Thilman-Straße.
    static let branches: [Branch] = [
        // Dieselben beiden wie in `markets` — Mock-Läufe (UI-Journeys) müssen
        // dieselben Filialen sehen wie vorher, sonst zeigt der Picker über
        // Nacht andere Läden.
        Branch(marketId: "lidl-01219-1", chain: "Lidl", name: "Dresden Reick",
               street: "Reicker Str. 100", plz: "01219", city: "Dresden",
               lat: 51.0166, lon: 13.7727),
        Branch(marketId: "aldi-01219-1", chain: "Aldi", name: "Dresden Prohlis",
               street: "Prohliser Allee 10", plz: "01219", city: "Dresden",
               lat: 51.0011, lon: 13.7899),
        Branch(marketId: "1766063", chain: "REWE", name: "REWE Ketzscher oHG am Postplatz",
               street: "Wallstr. 2b", plz: "01067", city: "Dresden", lat: 51.0504, lon: 13.7317),
        Branch(marketId: "1766160", chain: "REWE", name: "REWE Friedrichstadt",
               street: "Friedrichstr. 7", plz: "01067", city: "Dresden", lat: 51.0561, lon: 13.7203),
        Branch(marketId: "4816", chain: "Netto", name: "Netto Marken-Discount Dresden-Strehlen",
               street: "Johannes-Paul-Thilman-Str. 3", plz: "01219", city: "Dresden",
               lat: 51.0155, lon: 13.7669),

        // Die zweite und dritte Region aus dem Fehlerbericht vom 2026-07-30.
        // Beide liegen ~450 km von Dresden entfernt, also weit außerhalb der
        // 40 km, auf die der Picker höchstens aufmacht — ein Lauf mit nur
        // 01219 sieht sie nie, und die bestehenden Journeys ändern sich nicht.
        //
        // Die Verteilung ist der eigentliche Punkt: Um 04626 steht ein Netto,
        // das Gebiet gilt damit als geholt. Um 17419 steht ausschließlich
        // Penny — bundesweit im Verzeichnis, also das Zeichen für „dieses
        // Gebiet hat nie jemand geholt". Zusammengeworfen verdeckt das Netto
        // genau dieses Zeichen, und das war der Fehler.
        Branch(marketId: "penny-04639-1", chain: "Penny", name: "Penny Gößnitz",
               street: "Altenburger Str. 13 A", plz: "04639", city: "Gößnitz",
               lat: 50.8875, lon: 12.4333),
        Branch(marketId: "netto-04626-1", chain: "Netto", name: "Netto Marken-Discount Schmölln",
               street: "Crimmitschauer Str. 2", plz: "04626", city: "Schmölln",
               lat: 50.8940, lon: 12.3600),
        Branch(marketId: "penny-17373-1", chain: "Penny", name: "Penny Am Haff",
               street: "Chausseestr. 41-43", plz: "17373", city: "Ueckermünde",
               lat: 53.7383, lon: 14.0511),
        Branch(marketId: "penny-17449-1", chain: "Penny", name: "Penny Karlshagen",
               street: "Hauptstr. 16", plz: "17449", city: "Karlshagen",
               lat: 54.0500, lon: 13.8167),
    ]

    /// Ein Verzeichnis in Dresdner Größe — für den Messlauf des Wählers.
    ///
    /// Die Verteilung ist die **gemessene** aus `MarketFilter.titles`: ALDI
    /// Nord 25 und Netto 24 heißen wörtlich alle gleich, Lidl 22 und EDEKA 14
    /// fast alle verschieden. Das ist kein Beiwerk, sondern genau der Fall,
    /// den die Titelvergabe teuer macht — ein Verzeichnis aus lauter
    /// eindeutigen Namen liefe durch den billigen Zweig und misst am Fehler
    /// vorbei.
    ///
    /// Alle liegen um die Dresdner Mitte, damit der 10-km-Kreis sie fasst und
    /// die Regel „unter sechs Filialen wird aufgemacht" nicht anspringt.
    static func dichtesVerzeichnis(_ anzahl: Int) -> [Branch] {
        // (Kette, Anteil, tragen alle denselben Namen)
        let verteilung: [(String, Int, Bool)] = [
            ("ALDI Nord", 25, true), ("Netto", 24, true), ("Lidl", 22, false),
            ("EDEKA", 14, false), ("REWE", 13, false), ("Kaufland", 9, false),
            ("Penny", 6, false),
        ]
        let gesamt = verteilung.reduce(0) { $0 + $1.1 }
        var out: [Branch] = []
        var i = 0
        for (kette, anteil, gleicherName) in verteilung {
            let n = max(1, anzahl * anteil / gesamt)
            for k in 0..<n where out.count < anzahl {
                i += 1
                // Ein Gitter von ~50 m Schrittweite um die Dresdner Mitte:
                // nah genug, dass keine Filiale aus dem Kreis fällt.
                let lat = dresden.lat + Double(i % 12) * 0.0005
                let lon = dresden.lon + Double(i / 12) * 0.0005
                out.append(Branch(
                    marketId: "dicht-\(i)",
                    chain: kette,
                    name: gleicherName ? "\(kette) Dresden" : "\(kette) Stadtteil \(k)",
                    street: "Teststraße \(i)",
                    plz: "01219", city: "Dresden", lat: lat, lon: lon
                ))
            }
        }
        return out
    }

    /// Postcode centres for mock runs. Real geocoding talks to Apple's servers,
    /// which a test must never do.
    ///
    /// This used to be one hardcoded Dresden point for **every** postcode,
    /// which made multi-region behaviour untestable: three regions all landed
    /// on the same coordinates, so nothing that depends on them apart could
    /// ever be reproduced. Unknown postcodes still fall back to that point, so
    /// every existing journey keeps the list it had.
    static let dresden = (lat: 51.0504, lon: 13.7317)

    static func coordinates(forPLZ plz: String) -> (lat: Double, lon: Double) {
        switch plz {
        case "04626": return (50.8956, 12.3556)  // Schmölln
        case "17419": return (53.9440, 14.1830)  // Ahlbeck auf Usedom
        default: return dresden
        }
    }
}

struct MockOfferRepository: OfferRepositoryProtocol {
    /// Beide Wochen, wie die echte Abfrage: `select=*` kennt keine Datumsgrenze.
    /// Getrennt werden sie erst im `OfferStore`.
    var fixtures: [Offer] = MockFixtures.standard

    func offers(branchIds: [String]) async throws -> [Offer] {
        // Nationwide rows belong to every branch of their chain.
        fixtures.filter { $0.isNationwide || branchIds.contains($0.marketId ?? "") }
    }
}

struct MockPriceHistoryRepository: PriceHistoryRepositoryProtocol {
    var fixtures: [PriceHistoryPoint] = MockFixtures.priceHistory

    func history(market: String, product: String) async throws -> [PriceHistoryPoint] {
        fixtures.filter { $0.market == market && $0.product == product }
    }
}

struct MockBranchRepository: BranchRepositoryProtocol {
    var fixtures: [Branch] = MockFixtures.branches

    func nearby(lat: Double, lon: Double, radiusKm: Double) async throws -> [Branch] {
        fixtures
            .compactMap { branch -> (Branch, Double)? in
                guard let distance = branch.distanceKm(from: lat, lon), distance <= radiusKm
                else { return nil }
                return (branch, distance)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    func branch(marketId: String) async throws -> Branch? {
        fixtures.first { $0.marketId == marketId }
    }
}

/// Records requests instead of sending them, and can be told which stores the
/// backend already has — so tests can drive the wait state without a network.
///
/// **Mit Schloss — und das `@unchecked Sendable` ist damit zum ersten Mal
/// wahr.** Die `async`-Methoden des Protokolls laufen nicht auf dem
/// Main-Actor, und beim Start ruft die App `checkPendingBranches` doppelt
/// (das `.task` und der `scenePhase`-Wechsel auf `.active` feuern beide):
/// zwei Threads in `requested.append` — Heap-Schaden. Auf dem Simulator als
/// Startabsturz etwa jeder dreißigste Lauf, `EXC_BAD_ACCESS` in
/// `Array.append` unter `requestBranch(marketId:)`, sechs .ips-Berichte vom
/// 05./06.08. mit identischem Stack (und einer vom 03.08. — der Riss ist
/// älter als jeder Verdächtige aus dem Merge). In Journeys sah das aus wie
/// „die App startet nicht": kein Rahmen, keine Leiste, 15 s Warten umsonst —
/// und beim nächsten Start ging alles, weshalb der Verdacht reihum wanderte.
final class MockBranchRequestRepository: BranchRequestRepositoryProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var readyStorage: Set<String> = []
    private var pendingStorage: Set<String> = []
    private var requestedStorage: [String] = []

    /// Stores that already carry a `last_synced`.
    var ready: Set<String> {
        get { lock.withLock { readyStorage } }
        set { lock.withLock { readyStorage = newValue } }
    }

    /// Stores whose row exists but is still pending.
    var pending: Set<String> {
        get { lock.withLock { pendingStorage } }
        set { lock.withLock { pendingStorage = newValue } }
    }

    var requested: [String] { lock.withLock { requestedStorage } }

    func request(marketId: String) async throws -> BranchRequest? {
        lock.withLock {
            if readyStorage.contains(marketId) {
                return BranchRequest(marketId: marketId, lastSynced: "2026-07-25T16:56:48Z", active: true)
            }
            if pendingStorage.contains(marketId) || requestedStorage.contains(marketId) {
                return BranchRequest(marketId: marketId, lastSynced: nil, active: true)
            }
            return nil
        }
    }

    func requestBranch(marketId: String) async throws {
        lock.withLock { requestedStorage.append(marketId) }
    }
}

/// Same shape as `MockBranchRequestRepository`, one level up: the area, not
/// the single store — **und mit demselben Schloss, aus demselben Grund**:
/// `checkPendingArea` läuft beim Start und beim `scenePhase`-Wechsel
/// nebeneinander, und der .ips-Bericht vom 03.08. zeigt denselben Riss auf
/// diesem Pfad.
final class MockAreaRequestRepository: AreaRequestRepositoryProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var readyStorage: Set<String> = []
    private var pendingStorage: Set<String> = []
    private var requestedStorage: [String] = []
    private var coordinatesStorage: [String: (lat: Double, lon: Double)] = [:]
    private var requestedCoordinatesStorage: [String: (lat: Double?, lon: Double?)] = [:]
    private var areaKeysStorage: [String: String] = [:]

    /// Anchors whose area run has finished.
    var ready: Set<String> {
        get { lock.withLock { readyStorage } }
        set { lock.withLock { readyStorage = newValue } }
    }

    /// Anchors whose row exists but whose run is still going.
    var pending: Set<String> {
        get { lock.withLock { pendingStorage } }
        set { lock.withLock { pendingStorage = newValue } }
    }

    var requested: [String] { lock.withLock { requestedStorage } }

    /// Koordinaten, die eine schon vorhandene Zeile trägt — damit Tests die
    /// Übernahmeregel („nicht die Zeile einer anderen Stadt kapern") prüfen
    /// können.
    var coordinates: [String: (lat: Double, lon: Double)] {
        get { lock.withLock { coordinatesStorage } }
        set { lock.withLock { coordinatesStorage = newValue } }
    }

    /// Was die App tatsächlich mitgeschickt hat.
    var requestedCoordinates: [String: (lat: Double?, lon: Double?)] {
        lock.withLock { requestedCoordinatesStorage }
    }

    /// Zuordnung Gebietsschlüssel -> Filiale. Wird beim Anfordern automatisch
    /// gefüllt; Tests können sie für schon vorhandene Zeilen vorbelegen.
    var areaKeys: [String: String] {
        get { lock.withLock { areaKeysStorage } }
        set { lock.withLock { areaKeysStorage = newValue } }
    }

    func request(marketId: String) async throws -> AreaRequest? {
        lock.withLock { row(for: marketId) }
    }

    /// Nur unter gehaltenem Schloss aufrufen — die eine Stelle, an der die
    /// Zeile gebaut wird, damit `request(areaKey:)` nicht durch einen zweiten
    /// Griff zum selben Schloss muss (NSLock kennt kein Wiedereintreten).
    private func row(for marketId: String) -> AreaRequest? {
        let point = coordinatesStorage[marketId]
        if readyStorage.contains(marketId) {
            return AreaRequest(
                marketId: marketId, plz: "04639",
                lastSynced: "2026-07-26T08:36:50Z", active: true,
                areaKey: point.map { AreaRequestStore.areaKey(lat: $0.lat, lon: $0.lon) },
                lat: point?.lat, lon: point?.lon
            )
        }
        if pendingStorage.contains(marketId) || requestedStorage.contains(marketId) {
            return AreaRequest(
                marketId: marketId, plz: "04639", lastSynced: nil, active: true,
                areaKey: point.map { AreaRequestStore.areaKey(lat: $0.lat, lon: $0.lon) },
                lat: point?.lat, lon: point?.lon
            )
        }
        return nil
    }

    func request(areaKey: String) async throws -> AreaRequest? {
        lock.withLock {
            if let marketId = areaKeysStorage[areaKey] {
                return row(for: marketId)
            }
            // Sonst die Zeile, deren Koordinaten in dieser Zelle liegen — so
            // muss ein Test nur `coordinates` setzen und nicht zusätzlich den
            // Schlüssel.
            for (marketId, point) in coordinatesStorage
            where AreaRequestStore.areaKey(lat: point.lat, lon: point.lon) == areaKey {
                return row(for: marketId)
            }
            return nil
        }
    }

    func requestArea(marketId: String, lat: Double?, lon: Double?) async throws {
        lock.withLock {
            requestedStorage.append(marketId)
            requestedCoordinatesStorage[marketId] = (lat, lon)
            if let lat, let lon {
                areaKeysStorage[AreaRequestStore.areaKey(lat: lat, lon: lon)] = marketId
            }
        }
    }
}

struct MockMarketRepository: MarketRepositoryProtocol {
    var fixtures: [Market] = MockFixtures.markets

    func markets(plzs: [String]) async throws -> [Market] {
        fixtures.filter { plzs.contains($0.plz) }
    }
}

/// Records uploads instead of sending them, so tests can assert that a profile
/// without consent never reaches the network.
final class MockProfileRepository: ProfileRepositoryProtocol, @unchecked Sendable {
    private(set) var uploaded: [SyncedProfile] = []

    func upload(_ profile: SyncedProfile) async throws {
        uploaded.append(profile)
    }
}

/// Records reports instead of sending them, so tests can assert that skipping
/// the question — or switching it off — never reaches the network.
final class MockMatchFeedbackRepository: MatchFeedbackRepositoryProtocol, @unchecked Sendable {
    private(set) var submitted: [MatchFeedbackReport] = []

    func submit(_ report: MatchFeedbackReport) async throws {
        submitted.append(report)
    }
}


/// Zählt statt zu löschen. Der Ausgang ist einstellbar, damit die Journeys
/// beide Fälle sehen: etwas gelöscht — und gar nichts, weil nie etwas
/// hochgeladen wurde.
final class MockPrivacyRepository: PrivacyRepositoryProtocol, @unchecked Sendable {
    var rows = DeletedRows(profiles: 1, feedback: 3)
    var failure: Error?
    private(set) var deleted: [UUID] = []

    func deleteInstallation(_ installId: UUID) async throws -> DeletedRows {
        if let failure { throw failure }
        deleted.append(installId)
        return rows
    }

    func exportInstallation(_ installId: UUID) async throws -> String {
        if let failure { throw failure }
        return "{\"install_id\":\"\(installId.uuidString)\",\"user_profiles\":[],\"match_feedback\":[]}"
    }
}
