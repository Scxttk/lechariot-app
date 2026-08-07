import XCTest
@testable import LeChariot

/// **Das ganze Wörterbuch gegen ein erfundenes Regal.**
///
/// Seit `ac24311` bildet die Suche Suchwörter über `MatchDictionary` auf
/// Begriffe ab. Belegt war dieser Weg bisher durch eine Handvoll ausgesuchter
/// Fälle — „Fleischersatz", „creme fraiche", „Milchreis". Das Wörterbuch hat
/// aber 85 Begriffe und 636 Synonyme, und **gepflegt wird es im anderen Repo**
/// (`/pflegerunde` im Backend, hierher gespiegelt vom Wörterbuch-Abgleich).
/// Eine Änderung dort kann die Suche hier stiller verschlechtern, als irgendein
/// bestehender Test merken würde.
///
/// Deshalb fährt dieser Test das Wörterbuch selbst ab, statt Beispiele
/// aufzuzählen: Er liest die JSON-Datei **unabhängig von `MatchDictionary`**
/// noch einmal ein — würde er die geladenen Tabellen der Klasse benutzen, die
/// er prüft, ginge ein Ladefehler durch, weil beide Seiten denselben Fehler
/// machten.
///
/// Das Regal ist erfunden. Bewusst: Echte Zeilen in Supabase zu säen hieße,
/// ausgedachte Produkte in die Einkaufsliste eines Testers laufen zu lassen.
///
/// **Zwei Richtungen, und die zweite trägt genauso viel.** Dass ein Synonym
/// etwas findet, ist die eine Hälfte; dass ein gesperrtes Wort nichts findet,
/// die andere. „Milchreis" darf das Milchregal nicht öffnen, „Kartoffelsalat"
/// nicht das Salatregal. Genau diese Paare kippen leise, wenn jemand am
/// Wörterbuch dreht.
final class MatchShelfTests: XCTestCase {

    // MARK: Das Regal

    /// Ein erfundenes Angebot je Begriff, getaggt wie das Backend taggt: der
    /// Begriffsname als einziger `match_key`.
    ///
    /// Die Titel sind absichtlich echte Produktnamen und **nicht** aus den
    /// Synonymlisten zusammengesetzt — von den 721 geprüften Synonymen stehen
    /// nur 99 wörtlich in einem Titel, die übrigen 622 können ausschließlich
    /// über den Tag ankommen. Ein paar Titel sind mit Absicht Stolperdrähte:
    /// „Leibniz Butterkeks" (bei `butter` gesperrt), „Milka Alpenmilch" (bei
    /// `milch` gesperrt), „Putenbrustfilet" (bei `fisch` gesperrt) — sie
    /// gehören zu einem anderen Begriff und müssen dort auch bleiben.
    private static let regal: [String: String] = [
        // Tranche 9 (2026-08-07): Baumarkt, Garten, Tierbedarf.
        "backform": "Springform 26 cm",
        "besteck": "Einweggabeln 20 Stück",
        "blumenerde": "Blumenerde 20 l",
        "blumentopf": "Übertopf 14 cm",
        "büroklammern": "Büroklammern 100 Stück",
        "gartenwerkzeug": "Gartenschere Bypass",
        "grillzubehör": "Grillzange 40 cm",
        "handschuhe": "Putzhandschuhe Gr. M",
        "holzkohle": "Grillkohle 3 kg",
        "hundefutter": "Hundefutter Rind 800 g",
        "katzenfutter": "Katzenfutter Adult 400 g",
        "küchenhelfer": "Schneebesen 30 cm",
        "luftballon": "Luftballons bunt 20 Stück",
        "pfanne": "Bratpfanne 28 cm",
        "pinsel": "Malerpinsel 50 mm",
        "schere": "Küchenschere",
        "schrauben": "Spanplattenschrauben 4x40",
        "socken": "Wollsocken Gr. 42",
        "sonnenschirm": "Sonnenschirm 200 cm",
        "spülmittel": "Spülmittel Zitrone 500 ml",
        "streusalz": "Auftausalz 10 kg",
        "taschenlampe": "LED-Taschenlampe",
        "toilettenpapier": "Toilettenpapier 3-lagig 10 Rollen",
        "vogelfutter": "Meisenknödel 6 Stück",
        "waschmittel": "Vollwaschmittel 20 WL",
        "zimmerpflanze": "Grünpflanze im Topf",
        // Tranche 8 (2026-08-07): Haushalt und Pflege — das erste Non-Food.
        "allzweckreiniger": "Frosch Allzweckreiniger 1 l",
        "alufolie": "Alufolie 30 m",
        "batterien": "Varta AA 4 Stück",
        "deo": "Nivea Deo Roll-on 50 ml",
        "duschgel": "Duschgel Sport 300 ml",
        "geschenkpapier": "Geschenkpapier 2 Rollen",
        "geschirrtabs": "Somat All in 1 40 Tabs",
        "glühbirne": "LED-Lampe E27 warmweiß",
        "handcreme": "Handcreme Ringelblume 75 ml",
        "kerzen": "Teelichter 50 Stück",
        "makeup": "Lippenstift Rot 4 g",
        "müllbeutel": "Müllbeutel 60 l, 10 Stück",
        "notizblock": "Notizblock A6 kariert",
        "pflaster": "Pflaster Strips 20 Stück",
        "putzlappen": "Topfschwämme 5 Stück",
        "rasierer": "Einwegrasierer 5 Stück",
        "schmerzmittel": "Hustenbonbons 75 g",
        "seife": "Kernseife 100 g",
        "servietten": "Servietten 3-lagig 50 Stück",
        "shampoo": "Shampoo Volumen 300 ml",
        "sonnencreme": "Sonnencreme LSF 50 200 ml",
        "stifte": "Bleistifte HB 10 Stück",
        "streichhölzer": "Streichhölzer 3 Schachteln",
        "strohhalme": "Papier-Trinkhalme 50 Stück",
        "tampons": "Tampons normal 16 Stück",
        "vitamine": "Magnesium Brausetabletten",
        "wattepads": "Wattepads 100 Stück",
        "zahnpasta": "Zahncreme Complete 75 ml",
        // Tranche 7 (2026-08-07): die letzten Lebensmittel.
        "babynahrung": "Hipp Karottenbrei 190 g",
        "chili": "Chiliflocken 35 g",
        "erdnussbutter": "Erdnussmus crunchy 500 g",
        "getreideriegel": "Hafer-Riegel 6 x 25 g",
        "grillsauce": "BBQ Sauce Hickory 450 ml",
        "hamburger": "Rinderfrikadellen 4 Stück",
        "hartkäse": "Manchego am Stück 200 g",
        "hummus": "Hummus Classic 200 g",
        "ingwer": "Ingwerknolle lose",
        "ketchup": "Heinz Tomato Ketchup 500 ml",
        "kokoswasser": "Kokoswasser 330 ml",
        "koriander": "Koriander im Bund",
        "kräuterfrischkäse": "Frischkäse Kräuter 175 g",
        "maultaschen": "Maultaschen 400 g",
        "mayonnaise": "Thomy Mayonnaise 250 ml",
        "panettone": "Panettone Classico 500 g",
        "paprikapulver": "Paprika edelsüß 45 g",
        "pesto": "Pesto alla Genovese 190 g",
        "pfeffer": "Schwarzer Pfeffer gemahlen 50 g",
        "pfefferminztee": "Pfefferminztee 20 Beutel",
        "senf": "Löwensenf mittelscharf 250 ml",
        "sojasauce": "Kikkoman Sojasauce 250 ml",
        "trüffel": "Trüffelöl 100 ml",
        "weißwein": "Riesling trocken 0,75 l",
        "wraps": "Weizen-Tortillas 6 Stück",
        // Tranche 6 (2026-08-07): der Rest aus Obst & Gemüse.
        "artischocken": "Artischockenherzen 240 g",
        "blutorangen": "Blutorangen Moro 1 kg",
        "chicorée": "Chicorée 500 g",
        "drachenfrucht": "Drachenfrucht, Stück",
        "guave": "Maracuja 3 Stück",
        "haselnüsse": "Haselnusskerne 200 g",
        "kastanien": "Maronen vorgegart 200 g",
        "kiwi": "Kiwi Zespri 6 Stück",
        "kohlrabi": "Kohlrabi Klasse I",
        "kokosnuss": "Kokosnuss, Stück",
        "kresse": "Gartenkresse im Schälchen",
        "lauch": "Porree Klasse I",
        "maiskolben": "Zuckermais 2 Kolben",
        "mangold": "Mangold Bund",
        "portulak": "Postelein 100 g",
        "preiselbeeren": "Getrocknete Cranberries 200 g",
        "quinoa": "Quinoa weiß 500 g",
        "römersalat": "Römersalatherzen 2 Stück",
        "schwarzwurzel": "Schwarzwurzeln 500 g",
        "snacktomaten": "Snacktomaten 250 g",
        "spargel": "Grüner Spargel 500 g",
        "weizengras": "Weizengras Pulver 100 g",
        "zitronengras": "Zitronengras 2 Stangen",
        // Tranche 5 (2026-08-07): Zutaten, Gewürze, Tiefkühl.
        "ahornsirup": "Ahornsirup Grade A 250 ml",
        "backpulver": "Backpulver 10 x 17 g",
        "bratensauce": "Bratensauce dunkel 250 ml",
        "dosentomaten": "Gehackte Tomaten 400 g",
        "fischsauce": "Fischsauce 200 ml",
        "hefe": "Frischhefe 42 g",
        "hühnerfrikassee": "Hühnerfrikassee 400 g",
        "kapern": "Kapern in Essig 100 g",
        "kartoffelpüree": "Kartoffelpüree Portionsbeutel",
        "knödel": "Semmelknödel 6 Stück",
        "kohlrouladen": "Kohlrouladen 500 g",
        "kokosflocken": "Kokosraspeln 200 g",
        "kurkuma": "Kurkuma gemahlen 40 g",
        "lebensmittelfarbe": "Speisefarbe 4 Fläschchen",
        "mandelmus": "Mandelmus weiß 250 g",
        "marinade": "Grillmarinade Kräuter 250 ml",
        "marzipan": "Marzipanrohmasse 200 g",
        "muskatnuss": "Muskatnüsse 3 Stück",
        "oregano": "Oregano gerebelt 12 g",
        "pfefferkörner": "Pfeffermühle bunt 45 g",
        "pinienkerne": "Pinienkerne 100 g",
        "safran": "Safranfäden 0,1 g",
        "schokodrops": "Schokotropfen zartbitter 100 g",
        "semmelbrösel": "Paniermehl 400 g",
        "speisestärke": "Speisestärke 400 g",
        "tütensuppe": "Tomatensuppe Beutel 3 Teller",
        "vanille": "Bourbon-Vanilleschoten 2 Stück",
        "zimt": "Zimtstangen 20 g",
        // Tranche 4 (2026-08-07): Getränke, Süßwaren, Getreide.
        "bonbons": "Werther's Original 245 g",
        "chiasamen": "Bio Chiasamen 500 g",
        "cornflakes": "Kellogg's Corn Flakes 375 g",
        "couscous": "Couscous 500 g",
        "dörrobst": "Getrocknete Aprikosen 200 g",
        "gelee": "Johannisbeergelee 340 g",
        "glasnudeln": "Glasnudeln 250 g",
        "glühwein": "Winzerglühwein rot 1 l",
        "grieß": "Hartweizengrieß 500 g",
        "kaffeepads": "Senseo Pads Classic 36er",
        "kaugummi": "Wrigley's Extra Spearmint",
        "kuvertüre": "Zartbitter-Kuvertüre 200 g",
        "lasagneblätter": "Lasagneplatten 250 g",
        "lollis": "Chupa Chups 10 Stück",
        "nougatcreme": "Nuss-Nougat-Creme 400 g",
        "plätzchen": "Butterspekulatius 200 g",
        "popcorn": "Popcorn süß 100 g",
        "reispapier": "Reispapier 22 cm, 100 g",
        "schnaps": "Wodka Gorbatschow 0,7 l",
        "sirup": "Holunderblütensirup 0,5 l",
        "smoothie": "Green Smoothie 250 ml",
        "sportgetränk": "Isodrink Zitrone 750 ml",
        "spätzle": "Schwäbische Spätzle 500 g",
        "tempeh": "Bio Tempeh Natur 200 g",
        "tonicwater": "Thomas Henry Tonic 6 x 0,2 l",
        // Tranche 3 (2026-08-07): Brot, Milchprodukte, Fleisch & Fisch.
        "bacon": "Bacon Frühstücksspeck 100 g",
        "bagel": "Sesam-Bagels 4 Stück",
        "burgerbrötchen": "Burger Buns 4 Stück",
        "croissant": "Buttercroissants 6 Stück",
        "fleischwurst": "Lyoner am Stück 300 g",
        "grillkäse": "Grillkäse Natur 200 g",
        "hüttenkäse": "Körniger Frischkäse 200 g",
        "kaffeerahm": "Kaffeesahne 10 x 10 g",
        "kassler": "Kasslernacken ohne Knochen",
        "magerquark": "Speisequark Magerstufe 500 g",
        "muscheln": "Miesmuscheln 1 kg",
        "pflanzendrink": "Hafermilch Barista 1 l",
        "pizzateig": "Frischer Pizzateig 400 g",
        "raclettekäse": "Raclette Scheiben 400 g",
        "reibekäse": "Geriebener Gouda 200 g",
        "ricotta": "Ricotta 250 g",
        "roggenbrot": "Vollkornbrot geschnitten 500 g",
        "sardellen": "Sardellenfilets in Öl",
        "schinken": "Serranoschinken 100 g",
        "schnitzel": "Schweineschnitzel 2 Stück",
        "sojajoghurt": "Kokosjoghurt Natur 400 g",
        "steak": "Rumpsteak 250 g",
        "zimtschnecken": "Zimtschnecken 4 Stück",
        // Tranche 2 (2026-08-07): Obst, Gemüse, Kräuter aus Bring!s größter
        // Kategorie.
        "basilikum": "Basilikum im Topf",
        "birnen": "Abate Fetel Birnen, 1 kg",
        "dill": "Bund Dill, frisch",
        "feigen": "Türkische Feigen 250 g Schale",
        "fenchel": "Fenchelknolle Klasse I",
        "granatapfel": "Granatapfel Wonderful",
        "grünkohl": "Grünkohl 500 g Beutel",
        "kaki": "Sharonfrucht 2 Stück",
        "kohl": "Spitzkohl Klasse I",
        "kürbis": "Hokkaido, ganze Frucht",
        "lauchzwiebeln": "Bund Frühlingszwiebeln",
        "litschi": "Litschis 250 g Schale",
        "minze": "Marokkanische Minze im Topf",
        "papaya": "Papaya Formosa, Stück",
        "pastinaken": "Pastinaken 500 g",
        "peperoni": "Peperoni mild, 100 g",
        "petersilie": "Glatte Petersilie im Bund",
        "quitten": "Quitten 1 kg Netz",
        "rettich": "Bayerischer Radi, Stück",
        "rhabarber": "Rhabarber Bund 500 g",
        "rosenkohl": "Rosenkohl 500 g",
        "schnittlauch": "Schnittlauch im Topf",
        "sellerie": "Staudensellerie Klasse I",
        "stachelbeeren": "Stachelbeeren 250 g Schale",
        // Tranche 1 (2026-08-07): Begriffe für Wörter, die bisher gesperrt
        // waren und nichts trafen. Titel wie im Regal darüber — echte
        // Produktnamen, nicht aus den Synonymlisten zusammengesetzt.
        "brühe": "Knorr Gemüsebrühe 12 Würfel",
        "eiswürfel": "Eiswürfel 1 kg Beutel",
        "essiggurken": "Kühne Gewürzgurken 720 ml",
        "fleischsalat": "Homann Fleischsalat 200 g",
        "kartoffelchips": "funny-frisch Chipsfrisch ungarisch",
        "kartoffelknödel": "Pfanni Kartoffelknödel halb & halb",
        "kartoffelsalat": "Homann Kartoffelsalat 400 g",
        "krautsalat": "Kühne Weinsauerkraut 500 g",
        "kuchen": "Coppenrath & Wiese Käsekuchen",
        "maiswaffeln": "Maiswaffeln ungesalzen 100 g",
        "milcheis": "Langnese Cremissimo Eis am Stiel",
        "müsliriegel": "Corny Big Schoko 6 x 50 g",
        "nudelsalat": "Popp Nudelsalat 400 g",
        "röstzwiebeln": "Röstzwiebeln 150 g Beutel",
        "salatdressing": "Kühne Salatdressing Kräuter 500 ml",
        "salzbrezeln": "Lorenz Saltletts Sticks 250 g",
        "süßkartoffeln": "Süßkartoffeln lose, 1 kg",
        "tomatensaft": "Hohes C Tomatensaft 1 l",
        "tomatensauce": "Barilla Napoletana 400 g",
        "traubensaft": "Rotbäckchen Traubensaft 0,7 l",
        "traubenzucker": "Dextro Energy Classic 6 Täfelchen",
        "vanillezucker": "Dr. Oetker Vanillezucker 10er",
        "zitronensaft": "Zitronensaft 200 ml Flasche",
        "aubergine": "Aubergine Klasse I, Stück",
        "avocado": "Avocado Hass, 2 Stück",
        "backwaren": "Mohn-Croissant 4 Stück",
        "bananen": "Chiquita Bananen, 1 kg",
        "beeren": "Deutsche Erdbeeren 500 g Schale",
        "bier": "Radeberger Pilsner 20 x 0,33 l",
        "bratwurst": "Thüringer Rostbratwurst 400 g",
        "brokkoli": "Brokkoli lose, 500 g",
        "brot": "Bauernbrot geschnitten 750 g",
        "butter": "Deutsche Markenbutter 250 g",
        "chips": "Crunchips Paprika 175 g",
        "eier": "Freilandeier Größe M, 10 Stück",
        "eintopf": "Erbseneintopf mit Speck 800 g",
        "eis": "Langnese Cremissimo Vanille 900 ml",
        "ente": "Frische Entenbrust 400 g",
        "essig": "Aceto Balsamico di Modena 500 ml",
        "fertiggericht": "Steinhaus Maultaschen 400 g",
        "feta": "Patros Hirtenkäse 200 g",
        "fisch": "Frischer Lachs aus Norwegen 200 g",
        "fleisch": "Frisches Gulasch vom Kalb 500 g",
        "frischkäse": "Philadelphia Natur 175 g",
        "gewürze": "Ostmann Paprika edelsüß 50 g",
        "gurke": "Salatgurke Klasse I, Stück",
        "hackfleisch": "Gemischtes Hackfleisch 500 g",
        "hähnchen": "Hähnchenbrustfilet frisch 400 g",
        "joghurt": "Landliebe Joghurt mild 500 g",
        "kaffee": "Dallmayr Prodomo gemahlen 500 g",
        "kakao": "Nesquik Kakaopulver 400 g",
        "kartoffeln": "Speisekartoffeln festkochend 2 kg",
        "kekse": "Leibniz Butterkeks 200 g",
        "knoblauch": "Knoblauch lose, 200 g Netz",
        "knäckebrot": "Wasa Knäckebrot Delicate 270 g",
        "kokosmilch": "Kokosmilch 17% Fett 400 ml",
        "kondensmilch": "Bärenmarke Kondensmilch 7,5% 340 g",
        "konserven": "Bonduelle Mais 3 x 150 g",
        "käse": "Gouda jung am Stück 400 g",
        "lamm": "Lammkeule ohne Knochen 1 kg",
        "limonade": "Sprite Zero 1,25 l",
        "margarine": "Rama Original 500 g",
        "marmelade": "Schwartau Extra Erdbeere 340 g",
        "mehl": "Aurora Weizenmehl Type 405, 1 kg",
        "melone": "Wassermelone kernarm, Stück",
        "milch": "Frische Vollmilch 3,5% Fett, 1 l",
        "mozzarella": "Galbani Mozzarella 125 g",
        "möhren": "Bundmöhren mit Grün, Bund",
        "müsli": "Kölln Haferflocken zart 500 g",
        "nudeln": "Barilla Spaghetti No. 5, 500 g",
        "nüsse": "Alesto Cashewkerne geröstet 200 g",
        "obst": "Ananas frisch, Stück",
        "orangen": "Saftorangen Netz 2 kg",
        "paprika": "Spitzpaprika rot, 500 g",
        "pfirsich": "Nektarinen Klasse I, 1 kg",
        "pilze": "Braune Champignons 250 g",
        "pizza": "Wagner Steinofen-Pizza Margherita",
        "pommes": "McCain Pommes frites 750 g",
        "protein/fitness": "Powerbar Proteinriegel Vanille 45 g",
        "pudding": "Dr. Oetker Grießpudding 500 g",
        "pute": "Putenbrustfilet frisch 400 g",
        "quark": "Speisequark Magerstufe 500 g",
        "reis": "Oryza Basmatireis 1 kg",
        "rind": "Rumpsteak vom Rind 2 x 200 g",
        "saft": "Hohes C Orangensaft 1 l",
        "sahne": "Schlagsahne 30% Fett, 200 g",
        "salat": "Eisbergsalat Kopf, Stück",
        "salz": "Bad Reichenhaller Meersalz 500 g",
        "schokolade": "Milka Alpenmilch 100 g",
        "schoten/hülsen": "Zuckerschoten 200 g",
        "schwein": "Schweinefilet frisch 500 g",
        "soßen": "Thomy Delikatess Mayonnaise 500 ml",
        "spirituosen": "Jack Daniel's Old No. 7, 0,7 l",
        "tee": "Meßmer Kamillentee 25 Beutel",
        "tiefkühlgemüse": "Iglo Rahm-Spinat 450 g",
        "tofu": "Taifun Tofu Natur 200 g",
        "tomaten": "Rispentomaten 500 g",
        "trauben": "Helle Tafeltrauben kernlos 500 g",
        "wasser": "Mineralwasser Medium 6 x 1,5 l",
        "wein": "Riesling trocken Rheinhessen 0,75 l",
        "windeln/hygiene": "Pampers Baby-Dry Größe 4, 70 Stück",
        "wurst": "Salami Original geschnitten 100 g",
        "zitronen": "Zitronen ungewachst, 500 g Netz",
        "zucchini": "Zucchini grün, 500 g",
        "zucker": "Südzucker Feinster Zucker 1 kg",
        "zwiebeln": "Speisezwiebeln 2 kg Netz",
        "äpfel": "Äpfel Elstar 2 kg Beutel",
        "öl": "Bertolli Olivenöl extra vergine 500 ml",
    ]

    private static func angebot(_ produkt: String, tag: String) -> Offer {
        var zeile = Offer(
            market: "Lidl", product: produkt, price: 1.99,
            regularPrice: nil, unit: nil, category: "sonstiges", emoji: nil,
            validFrom: Date(timeIntervalSince1970: 0),
            validUntil: Date(timeIntervalSince1970: 604_800),
            basePrice: nil, baseUnit: nil, nationwide: false
        )
        zeile.matchKey = [tag]
        return zeile
    }

    /// Das Regal mit echten Titeln — so sähe die Woche aus.
    private static let echtesRegal: [Offer] = regal.sorted { $0.key < $1.key }
        .map { angebot($0.value, tag: $0.key) }

    /// Dasselbe Regal ohne jeden Titel, der helfen könnte.
    ///
    /// Die Ziffer verschwindet unter `OfferMatcher.normalize` (alles außer
    /// Buchstaben wird Leerzeichen), also tragen **alle** Zeilen dieselben
    /// Titelwörter — „qxvz zzyx", in keiner Sprache ein Lebensmittel. Bleibt
    /// nur der Tag. Ohne diesen zweiten Durchlauf wären die 99 Synonyme, die
    /// wörtlich in einem Titel stehen, aus dem falschen Grund grün.
    private static let namenlosesRegal: [Offer] = regal.keys.sorted()
        .enumerated()
        .map { angebot("Qxvz Zzyx \($0.offset)", tag: $0.element) }

    // MARK: Das Wörterbuch, unabhängig von `MatchDictionary` gelesen

    private struct Eintrag: Decodable {
        let exact: [String]?
        let block: [String]?
        let suffix: [String]?
    }

    private struct Datei: Decodable {
        let begriffe: [String: Eintrag]
    }

    private static let woerterbuch: [String: Eintrag] = {
        // Im Test-Bundle liegt die Datei nicht, in der App schon — derselbe
        // doppelte Weg wie in `MatchDictionary`.
        let bundles = [Bundle.main, Bundle(for: MatchRejectionStore.self)]
        guard let url = bundles.compactMap({
            $0.url(forResource: "matching-woerterbuch", withExtension: "json")
        }).first,
              let data = try? Data(contentsOf: url),
              let datei = try? JSONDecoder().decode(Datei.self, from: data)
        else { return [:] }
        return datei.begriffe
    }()

    /// Dieselbe Normalisierung, die der Lader von `MatchDictionary` benutzt.
    private static func normalisiert(_ text: String) -> String {
        OfferMatcher.normalize(text).split(separator: " ").joined(separator: " ")
    }

    /// Die Wörter, die diesen Begriff meinen: die `exact`-Liste plus der
    /// Begriffsname selbst, abzüglich der gesperrten — genau die Regel aus
    /// `MatchDictionary.loaded`, hier noch einmal von Hand, damit ein Fehler
    /// dort nicht auf beiden Seiten gleich ausfällt.
    private static func synonyme(of begriff: String, _ eintrag: Eintrag) -> [String] {
        let gesperrt = Set((eintrag.block ?? []).map(normalisiert))
        return ((eintrag.exact ?? []) + [begriff])
            .map(normalisiert)
            .filter { !$0.isEmpty && !gesperrt.contains($0) }
    }

    private func produkte(_ suchwort: String, in regal: [Offer]) -> Set<String> {
        Set(OfferMatcher.matches(for: suchwort, in: regal).map(\.offer.product))
    }

    /// Eine Meldung statt siebenhundert. Bricht der Wörterbuch-Abgleich etwas,
    /// stehen sonst hunderte identische Zeilen im Protokoll und die eigentliche
    /// Ursache liegt irgendwo dazwischen.
    private func melde(_ fehler: [String], _ was: String) {
        guard !fehler.isEmpty else { return }
        let auszug = fehler.prefix(15).joined(separator: "\n  ")
        let rest = fehler.count > 15 ? "\n  … und \(fehler.count - 15) weitere" : ""
        XCTFail("\(was): \(fehler.count)\n  \(auszug)\(rest)")
    }

    // MARK: Das Regal wächst mit dem Wörterbuch

    /// **Der Wachstumsmechanismus.** Kommt drüben ein Begriff dazu, fehlt hier
    /// die Zeile und dieser Test sagt welcher — statt dass die Prüfung unter
    /// der Hand einen Begriff weniger abdeckt.
    func testDasRegalHatZuJedemBegriffEineZeile() {
        XCTAssertFalse(
            Self.woerterbuch.isEmpty,
            "Wörterbuch nicht im Bundle — dann prüft hier nichts mehr etwas"
        )
        let fehlend = Set(Self.woerterbuch.keys).subtracting(Self.regal.keys).sorted()
        let ueberzaehlig = Set(Self.regal.keys).subtracting(Self.woerterbuch.keys).sorted()
        XCTAssertTrue(
            fehlend.isEmpty,
            "Ohne Angebot im Regal: \(fehlend) — je eine Zeile in `regal` nachtragen"
        )
        XCTAssertTrue(
            ueberzaehlig.isEmpty,
            "Begriff gibt es nicht mehr: \(ueberzaehlig) — Zeile aus `regal` entfernen"
        )
    }

    // MARK: Vorwärts — jedes Synonym findet seinen Begriff

    /// Jedes einzelne Synonym jedes Begriffs, gegen das volle Regal getippt.
    func testJedesSynonymFindetSeinAngebot() {
        var fehler: [String] = []
        var geprueft = 0
        for (begriff, eintrag) in Self.woerterbuch.sorted(by: { $0.key < $1.key }) {
            guard let titel = Self.regal[begriff] else { continue }
            for wort in Self.synonyme(of: begriff, eintrag) {
                geprueft += 1
                if !produkte(wort, in: Self.echtesRegal).contains(titel) {
                    fehler.append("„\(wort)“ findet „\(begriff)“ nicht")
                }
            }
        }
        XCTAssertGreaterThan(
            geprueft, 600,
            "nur \(geprueft) Synonyme geprüft — das Wörterbuch wurde nicht gelesen"
        )
        melde(fehler, "Synonyme ohne Treffer")
    }

    /// Dasselbe noch einmal, aber die Titel können nicht mehr helfen: Hier
    /// **muss** der Weg über das Wörterbuch tragen.
    func testJedesSynonymTraegtAuchOhneJedenTitel() {
        var fehler: [String] = []
        var geprueft = 0
        let reihenfolge = Self.regal.keys.sorted()
        for (begriff, eintrag) in Self.woerterbuch.sorted(by: { $0.key < $1.key }) {
            guard let index = reihenfolge.firstIndex(of: begriff) else { continue }
            let titel = "Qxvz Zzyx \(index)"
            for wort in Self.synonyme(of: begriff, eintrag) {
                geprueft += 1
                if !produkte(wort, in: Self.namenlosesRegal).contains(titel) {
                    fehler.append("„\(wort)“ erreicht „\(begriff)“ nur über den Titel")
                }
            }
        }
        XCTAssertGreaterThan(
            geprueft, 600,
            "nur \(geprueft) Synonyme geprüft — das Wörterbuch wurde nicht gelesen"
        )
        melde(fehler, "Synonyme, die ohne Titelhilfe nichts finden")
    }

    // MARK: Gegenrichtung — gesperrte Wörter öffnen ihr Regal nicht

    /// „Milchreis" ist kein Milchprodukt, „Erdnussbutter" keine Butter,
    /// „Kartoffelsalat" kein Salat. Alle 150 Sperrwörter, jedes gegen sein
    /// eigenes Regal.
    ///
    /// Der Test ist heute leicht zu erfüllen, und das ist kein Einwand: Die
    /// Suche wertet **nur `exact`** aus, nie die Suffix-Regeln, und deshalb
    /// kommt kein Sperrwort überhaupt in die Nähe. Genau diese Entscheidung
    /// hält der Test fest — siehe die Gegenprobe unten, die zeigt, was sie
    /// wert ist.
    func testKeinGesperrtesWortOeffnetSeinRegal() {
        var fehler: [String] = []
        var geprueft = 0
        for (begriff, eintrag) in Self.woerterbuch.sorted(by: { $0.key < $1.key }) {
            guard let titel = Self.regal[begriff] else { continue }
            for wort in (eintrag.block ?? []).map(Self.normalisiert) where !wort.isEmpty {
                geprueft += 1
                if produkte(wort, in: Self.echtesRegal).contains(titel) {
                    fehler.append("„\(wort)“ öffnet „\(begriff)“")
                }
            }
        }
        XCTAssertGreaterThan(
            geprueft, 100,
            "nur \(geprueft) Sperrwörter geprüft — die Sperrlisten wurden nicht gelesen"
        )
        melde(fehler, "Sperrwörter mit Treffer")
    }

    /// **Was der Test oben wert ist.**
    ///
    /// `MatchDictionary` wertet die Suffix-Regeln absichtlich nicht aus: Sie
    /// sind zum Abgrasen von Produkt*texten* gebaut („…brötchen" → `brot`), und
    /// auf ein Suchwort angewandt greifen sie zu weit. Wer das eines Tages
    /// „vereinheitlicht", schaltet damit auf einen Schlag die Sperrwörter
    /// scharf, die auf eine Suffix-Regel ihres eigenen Begriffs enden — heute
    /// 37 Stück. „Kartoffelsalat" endet auf `salat` und öffnete dann das ganze
    /// Salatregal, „Putenbrustfilet" das Fischregal.
    ///
    /// Dass diese Menge nicht leer ist, ist die Bedingung dafür, dass der Test
    /// darüber überhaupt etwas behauptet. Wird sie leer, prüft er nichts mehr,
    /// und dann soll er das sagen.
    func testDieSperrlistenHabenScharfeFaelle() {
        var scharf: [String] = []
        for (begriff, eintrag) in Self.woerterbuch {
            let suffixe = (eintrag.suffix ?? []).map(Self.normalisiert).filter { !$0.isEmpty }
            for wort in (eintrag.block ?? []).map(Self.normalisiert)
            where !wort.contains(" ") && suffixe.contains(where: wort.hasSuffix) {
                scharf.append("\(begriff)/\(wort)")
            }
        }
        XCTAssertGreaterThan(
            scharf.count, 0,
            "Kein Sperrwort endet mehr auf eine Suffix-Regel seines Begriffs — "
                + "testKeinGesperrtesWortOeffnetSeinRegal behauptet damit nichts mehr"
        )
        // Die beiden namentlich, weil sie in der Notiz vom 2026-07-31 stehen.
        XCTAssertTrue(scharf.contains("salat/kartoffelsalat"), "Fälle: \(scharf.sorted())")
        XCTAssertTrue(scharf.contains("fisch/putenbrustfilet"), "Fälle: \(scharf.sorted())")
    }
}
