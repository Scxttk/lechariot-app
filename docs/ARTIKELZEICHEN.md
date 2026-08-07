# Artikelzeichen: der Arbeitsvorrat

**Ziel** (Scott, 2026-08-07): mindestens so viele Artikelzeichen wie Bring!, lieber
mehr. Das Zuordnen und die beste Filiale bleiben der Kern der App — die Zeichen
sind Oberfläche, aber sie entscheiden, ob das Raster (Richtung D) trägt.

## Woher diese Liste kommt

Aus Scotts Bildschirmaufnahme von Bring! (`_attachments/bring-referenz-2026-08-03.mp4`
im Vault, 3:11 min). Der Katalog ist dort Kategorie für Kategorie durchgeblättert.
Ausgelesen mit Apples Vision (`VNRecognizeTextRequest`, Deutsch), und **die
Kachelfarbe entscheidet, was ein Artikel ist**: Bring! setzt jede Artikelkachel auf
Mintgrün (`90,171,161`) oder Lachsrot (steht auf der Liste), während Kopfzeile,
Kategorieliste und Tab-Leiste auf dem dunklen Grund liegen. Ein Punkt knapp über
der Beschriftung trifft die Kachel — zuverlässiger als jede Höhenschwelle.

Nur übernommen, was in **mindestens zwei** Bildern gleich gelesen wurde; ein
einzelner Fund ist meistens ein Lesefehler (112 Stück verworfen).

**Das ist eine Abschrift der Namen, keine Kopie der Zeichnungen.** Bring!s
Illustrationen sind ihr Urheberrecht und kommen nicht ins Bundle. Als Vorlage zum
Ansehen sind sie das, was sie hier sind: eine Messlatte für den Umfang.

## Der Stand

| | |
|---|---:|
| Artikel bei Bring! (gelesen) | **750** |
| davon kennt unser Wörterbuch schon | 267 |
| **neu** | **483** |
| gezeichnet (`ItemGlyphs.swift`) | **226** |

### Fortschritt

| Tranche | Thema | Begriffe | Zeichen gesamt | Abdeckung |
|---|---|---:|---:|---:|
| — | Ausgangslage | 85 | 80 | 97,8 % |
| 1 | Gesperrte Wörter ohne Begriff | +23 | 103 | 97,8 % |
| 2 | Obst, Gemüse, Kräuter | +24 | 127 | **98,1 %** |
| 3 | Brot, Milch, Fleisch & Fisch | +23 | 150 | 98,1 % |
| 4 | Getränke, Süßwaren, Getreide | +25 | 175 | **98,3 %** |
| 5 | Zutaten, Gewürze, Tiefkühl | +28 | 203 | 98,3 % |
| 6 | Rest aus Obst & Gemüse | +23 | **226** | 98,3 % |

**Erfahrungswert aus fünf Runden:** rund 25 Zeichen je Runde, davon lesen **etwa
ein Drittel beim ersten Wurf etwas anderes** und brauchen einen zweiten Durchgang.
Die Fehllesungen stehen jeweils am Rezept — sie sind der eigentliche Wert des
Prüfbogens.

**Wiederkehrende Fallen**, in fünf Runden gesammelt:

- Ein konisches Gefäß mit etwas Rundem darüber ist ein **Blumentopf**.
- Zwei Löcher über einem Strich sind ein **Gesicht**.
- Ein Ballen auf einem Stiel ist ein **Baum**.
- Geneigte Kapseln, die unten zusammenlaufen, sind ein **Buchstabe**.
- Senkrechte Striche mit Querbalken sind ein **Zaun**.
- Kreis im Kreis mit Kreuz ist ein **Wappen**.
- Drei Punkte im Dreieck auf einer Kugel sind ein **Gesicht** (Kokosnuss).
- `capsule` wird **gestrichen**: bei 0,095 Strichstärke deckt der Strich eine
  0,10 breite Kapsel voll zu. Ein dünner Gegenstand ist eine **Linie**.

**Zwei Dinge fehlen, nicht eines.** Ein Artikel braucht einen **Begriff** im
`matching-woerterbuch.json` (sonst löst `ItemGlyphTerm` ihn nicht auf und die Zeile
bekommt gar nichts) **und** eine Zeichnung. Die fett gesetzten Namen unten haben
beides nicht.

**Wo wir am dünnsten sind, ist Non-Food** — Haushalt 89 von 93 neu, Pflege &
Gesundheit 54 von 60, Baumarkt & Garten 33 von 40. Das ist kein Versäumnis, sondern
Bauart: Unser Wörterbuch ist für den Angebots-Zuordner gebaut und kennt, was in
Prospekten steht. Daraus folgt eine Entscheidung, die vor der Arbeit steht — siehe
unten.

## Die Entscheidung, die vor dem Zeichnen kommt

Am 06.08. wurde Non-Food **absichtlich** aus den Top-Angeboten gefiltert
(`Categories.middleAisle`: Kindersessel −88 %, Werkstattfeilen −72 % standen ganz
oben). Für die **Liste** brauchen wir dieselben Warengruppen aber, sonst schreibt
jemand „Müllbeutel" und bekommt weder Zeichen noch Kategorie.

Heute ist das dasselbe Feld. **Ein Begriff muss „auf der Liste erlaubt" sein können,
ohne „im Angebotsvergleich zu zählen".** Das ist Arbeit am Wörterbuch und am
Zuordner, nicht am Zeichensatz — und sie geht dem Zeichnen der 122 Non-Food-Artikel
voraus, sonst zeichnet jemand 122 Bilder für Wörter, die die App nicht annimmt.

## Reihenfolge

1. **Lebensmittel zuerst** — dort funktioniert der Zuordner schon, dort liegt der
   Kern der App. 361 neue Artikel in neun Kategorien.
2. **Die Trennung Liste/Vergleich** bauen (siehe oben).
3. **Non-Food** — 176 neue Artikel in Haushalt, Pflege & Gesundheit, Baumarkt.

Je Kategorie ein Arbeitspaket: erst die Begriffe ins Wörterbuch, dann die
Zeichnungen in `ItemGlyphs.swift`, dann der Prüfbogen (`tools/zeichensatz.swift`)
bei 13,1 / 19,7 / 65,6 pt. Der Vertrag für die Zeichnungen steht im Kopf von
`CategoryGlyphs.swift`; `ItemGlyphTests` fängt jeden Begriff ohne Zeichnung.

## Der Katalog

**Fett = Begriff und Zeichnung fehlen.** Normal gesetzt = das Wörterbuch kennt das
Wort bereits; dort fehlt oft nur noch die Zeichnung.

### Obst & Gemüse — 153 Artikel, davon 68 neu

Ananas, Aprikosen, Artischocken, Aubergine, Avocado, Açaí Beeren, Bananen, **Basilikum**, Beeren, **Birnen**, Blaubeeren, Blumenkohl, **Blutorangen**, Brechbohnen, Brokkoli, Brombeeren, Buschbohnen, **Butternut Kürbis**, Champignons, Cherrytomaten, **Chicorée**, **Chili**, Chinakohl, Clementinen, Datteln, **Dill**, **Drachenfrucht**, Edamame, Eisbergsalat, Erbsen, Erdbeeren, **Feigen**, Feldsalat, **Fenchel**, **Gemüse**, Goji Beeren, **Goldkiwi**, **Granatapfel**, Grapefruit, Grüne Bohnen, **Grünkohl**, **Guave**, Gurke, Gurken, **Halloween Kürbis**, **Haselnüsse**, Heidelbeeren, **Hokkaido Kürbis**, Honigmelone, Ingwer, **Inspiration**, Johannisbeeren, **Kaki**, Karotten, Kartoffeln, **Kastanien**, **Khaki**, **Kinder Joy**, Kirschen, Kiwi, Knoblauch, **Knollensellerie**, **Kohl**, Kohlrabi, **Kokosnuss**, Kokosnuss Öl, Koriander, **Kresse**, Kräuter, **Kürbis**, Lauch, **Lauchzwiebeln**, **Leinsamen**, Limette, **Listen**, **Litschi**, Mais, **Maiskolben**, **Majoran**, Mandarinen, Mango, **Mangold**, **Marroni**, Melone, **Minze**, Mirabellen, Möhren, Nektarine, Obst, Oliven, Orange, Orangen, Pak Choi, **Papaya**, Paprika, Passionsfrucht, **Pastinaken**, **Peperoni**, Petersilie, **Pfefferminze**, Pfifferlinge, Pfirsich, Pflaumen, Pilze, Porree, **Portulak**, **Preiselbeeren**, **Quinoa**, **Quitten**, Radieschen, Rapsöl, **Rettich**, **Rhabarber**, Rispentomaten, **Romasalat**, **Rosenkohl**, Rote Bete, Rotkohl, **Rotkraut**, Rucola, **Römersalat**, Salat, **Salbei**, **Schnittlauch**, **Schwarzwurzel**, Sellerie, **Snacktomaten**, **Speisemöhren**, Spinat, **Spitzkohl**, Spitzpaprika, **Stachelbeeren**, **Stangenselerie**, Thai Auberginen, **Thai Basilikum**, **Thymian**, Tomaten, Trauben, Wassermelone, Weintrauben, **Weisskohl**, **Weizengras**, **Weißkohl**, **Wirz**, Zitrone, Zitronen, **Zitronengras**, Zucchini, Zwiebeln, maten, **mix**, **schi Getränk**, Äpfel

### Brot & Gebäck — 28 Artikel, davon 14 neu

**Aufbackbrötchen**, **Bagel**, Baguette, Blätterteig, Brot, Brötchen, **Burgerbrötchen**, **Buttercroissants**, Croissant, Knusperbrot, Knäckebrot, **Kräuterbaguette**, **Kuchenteig**, **Körnerbrot "das**, **Listen**, Muffins, Naan Brot, **Pizzateig**, **Pure"**, **Roggenbrot**, **Schokobrötchen**, Toast, Vegan, **Vegane Schoko**, Waffeln, Wraps, **Zimtschnecken**, Zwieback

### Milch & Käse — 46 Artikel, davon 25 neu

Chicken, **Dose**, **Gratinkäse**, **Grillkäse**, **Hafermilch**, **Hartkäse**, **Hüttenkäse**, Joghurt, **Kaffeerahm**, **Kiri**, **Kochcreme**, Kondensmilch, Kräuterbutter, **Kräuterfrischkäse**, Käse, **Käseecken**, **Käsestück**, Leuchtfeuer Käse, **Listen**, **Magarine**, **Magerquark**, **Mandelmilch**, Margarine, Mascarpone, Milch, Mozzarella, **MüllerMilch**, **Ofenkäse**, Parmesan, Quark, **Raclettekäse**, **Reibekäse**, **Ricotta**, SKYR, Sahne, Sauerrahm, Saure Sahne, Schafskäse, Schlagsahne, Schmand, Schmelzkäse, **Seidentofu**, Skyr, **Sojajoghurt**, **Sojamilch**, **Vegane Chunks**

### Fleisch & Fisch — 46 Artikel, davon 25 neu

Aufschnitt, **Bacon**, Bratwurst, Fisch, Fleisch, **Fleischsalat**, **Fleischwurst**, Frankfurter, Garnelen, **Grillfleisch**, Hackfleisch, **Hamburger**, Hähnchen, Hähnchenbrust, **Inspiration**, **Kalbfleisch**, **Kassler**, **Kochschinken**, Lachs, Lamm, Leberwurst, **Listen**, **Mett für Igel**, **Mettigel**, Mortadella, **Muscheln**, **Rindfleisch**, **Rohschinken**, Salami, **Sardellen**, Schinken, **Schnitzel**, Schweinefleisch, Speck, **Steak**, Thunfisch, Vegane Lyoner, **Veganes Gyros**, Wiener, **Wildfleisch**, Wurst, **cker**, **die ROSTOCKER**, **kel**, **keulensteaks**, **zeltes**

### Zutaten & Gewürze — 105 Artikel, davon 68 neu

**Ahornsirup**, **Amaranth**, **Anis**, Apfelmus, **Austernsauce**, BBQ Sauce, **Backpulver**, Balsamico, Bohnen, **Bourbon Vanille**, **Bratensauce**, Brühe, Buttermilch, Cashewkerne, **Curry Paste**, DIP, Dip, **Dosenobst**, **Dosentomaten**, **Erdnussbutter**, Essig, **Essiggurken**, **Fischsauce**, **Fleischgewürz**, **Gemüsebrühe**, **Gewürzgurken**, Götterspeise, **Hanfsamen**, **Hefe**, **Hefeflocken**, Hummus, **Kapern**, **Kartoffeln Mal**, Ketchup, Kichererbsen, Kidneybohnen, Kikkoman Sojasauce, **Kokosflocken**, Kokosmilch, **Kokoswasser**, **Kurkuma**, **Kürbiskerne**, **Lebensmittelfarbe**, Linsen, **Listen**, **Lorbeer**, **Mandelaroma**, **Mandelmus**, Mandeln, **Marinade**, **Marzipan**, Mayonnaise, Meersalz, **Muskatnuss**, **NATRON**, **Natron**, **Nelken**, Nüsse, Olivenöl, **Oregano**, Paniermehl, Paprikapulver, Pesto, Pfeffer, **Pfefferkörner**, **Pinienkerne**, Pistazien, **Polenta**, **Preiselbeer Sauce**, Puddingpulver, Puderzucker, **RUN**, **Rahmsoße**, **Rosinen**, **Rosmarin**, **Rumaroma**, **Röstzwiebeln**, **Safran**, **Salatsauce**, Salz, Sauerkraut, **Schokodrops**, **Semmelbrösel**, Senf, **Silberzwiebeln**, Sojasauce, **Sossenbinder**, **Speisestärke**, **Streusel**, **Tahini**, **Tamarindenpaste**, Tomatenmark, **Tomatensauce**, **Trüffel**, **Vanille**, **Vanilleextrakt**, **Vanillesoße**, **Vanillezucker**, Walnüsse, **Zimt**, Zucker, **blätter**, **kerne**, **len**, **ten**

### Fertig- & Tiefkühlprodukte — 39 Artikel, davon 28 neu

**Blumenkohl Tk**, **Brokkoli TK**, Chicken Wings, **Dinoschnitzel**, **Dr. Oetker**, Eis, **Erdbeeren oder**, Fischstäbchen, **Frosta**, **Gemüse gefroren**, Himbeeren, **Hitchis Kratzeis**, **Hühnerfrikassee**, **Kaisergemüse**, **Kartoffelpüree**, **Kartoffelstock**, **Klossteig**, **Knödel**, **Kohlrouladen**, **La Mia Familia**, Lasagne, **Lego Set**, **Listen**, Maultaschen, **Mini pizzen**, **Pasta Sauce**, **Piccolini**, Pizza, Pommes, Pommes Frites, **Röschen triologie**, Suppe, **Suprema**, **Tiefkühl brokoli**, **Tütensuppe**, **buttergemüse**, **chen**, **croissants**, rella Pizza

### Getreideprodukte — 37 Artikel, davon 18 neu

Basmatireis, **Chiasamen**, Ciabatta, **Corn Flakes**, **Couscous**, Dinkelmehl, **Dr. Oetker**, Fusilli, **Fussili**, **Glasnudeln**, Gnocchi, **Grieß**, Haferflocken, **Inspiration**, Jasminreis, **Knöpfli**, **Lasagnenblätter**, **Listen**, Mehl, Mini Gnocchi, Müsli, Nudeln, Penne, Ravioli, Reis, **Reisnudeln**, **Reispapier**, Risottoreis, Spaghetti, **Spirelli**, **Spirulina**, **Spätzle**, **Tempeh**, Tofu, Tortellini, **VITALS**, Vitalis Müsli

### Snacks & Süsswaren — 47 Artikel, davon 31 neu

**Bonbons**, Brezeln, **Bring!**, **CHOCOLATE**, Chips, **Choco Fresh**, Cracker, **Creme**, Dessert, **Dr. Oetker**, **Dörrobst**, Erdnüsse, **Ferrero Rocher**, Fertige Kleine Kuchen, **Fertige Kuchensnacks**, **Gelee**, **Getreideriegel**, Honig, **Inspiration**, **Kaugummi**, Kekse, Konfitüre, **Kovertüre**, **Krabbenchips**, Kuchen, **Lebkuchen**, **Listen**, **Lollis**, Marmelade, **Nougatcreme**, **Panettone**, **Plätzchen**, **Pop Corn**, **Pringles**, **Riegel**, Salzstangen, Schokolade, Schokoriegel, **Snacks**, **Süssigkeiten**, Torte, Tortilla Chips, **Vanille Sauce**, **Vielen Dank**, **corny hafer schoko**, **iii**, **our users**

### Getränke — 49 Artikel, davon 23 neu

Apfelsaft, Bier, Champagner, Cola, **Cola Light**, Die limo, Eistee, **Eiswürfel**, Energy Drink, **Fruchtsaft**, **Getränke**, Gin, **Glühwein**, **Inspiration**, Kaffee, Kaffeebohnen, Kaffeekapseln, Kaffeepads, Kakao, **Koawach**, **Koffeingetränk**, Kräutertee, **Light**, Limonade, **Listen**, **Mango Maracuja**, Mineralwasser, Orangensaft, **Pfefferminztee**, Prosecco, **Punsch**, Rotwein, Rum, **SENSEO® Pads**, Saft, **Schnaps**, Sekt, **Sirup**, **Smoothie**, **Spezi kasten**, **Sportgetränk**, Tee, **Tonic Water**, Wasser, **Weisswein**, Whisky, Wodka, **Zigaretten**, **enseo**

### Haushalt — 93 Artikel, davon 89 neu

**Abflussreiniger**, **Allzweckreiniger**, **Alufolie**, **Ausstechformen**, **Babynahrung**, **Backpalette**, **Backpapier**, **Backpinsel**, **Badreiniger**, **Ballon**, **Batterien**, **Besteck**, **Bleistift**, **Blumen**, **Briefumschläge**, **Büroklammern**, **Creme Bruehle**, **Entkalker**, **Essigessenz**, **Feuerzeug**, **Fleckenzwerg**, **Frischhaltefolie**, **Frosch**, **Frosch Baby**, **Gefrierbeutel**, **Geschenk**, **Geschenkband**, **Geschenkpapier**, **Geschirrsalz**, **Geschirrtabs**, **Glasreiniger**, **Glühbirne**, **Grillanzünder**, **Grillzange**, **Handschuhe**, **Inspiration**, **Kerzen**, **Klarspüler**, **Klebezettel**, **Klobürste**, **Kostüme**, **Kuchenform**, **Kugelschreiber**, Küchenrolle, **Küchentücher**, **Lametta**, **Listen**, **Locher**, **Luftballon**, **Marker**, **Möbelpolitur**, **Müllsäcke**, **Mütze**, **Notizblock**, **Papier**, **Pfanne**, **Putzlappen**, **Putzmittel**, **Radiergummi**, **Reflektoren**, **Reiniger**, **Rolldeo**, **Saftpresse**, **Schal**, **Schere**, **Schneebesen**, **Schwamm**, **Schüssel**, **Scrub Mommy**, **Servietten**, **Socken**, **Spieße**, **Spitzer**, Spülmittel, **Staubwedel**, **Stifte**, **Streichhölzer**, **Strohhalme**, **Taschenlampe**, **Tintenpatronen**, **Tischbombe**, **Toilettenreiniger**, **True Fruits**, **WC-Reiniger**, Waschmittel, Weichspüler, **Wollsocken**, **Zahnstocher**, **baby®**, **chen**, **schmuck**, **tel**, **zen**

### Pflege & Gesundheit — 60 Artikel, davon 54 neu

**Badesalz**, **Bartöl**, **Binden**, **Blasenpflaster**, **Bodylotion**, **Conditioner**, Deo, Duschgel, **Feuchttücher**, **Gesichtscreme**, **Gesichtsmaske**, **Haargel**, **Haarspray**, **Haarspülung**, **Haaröl**, **Handcreme**, **Hustenbonbons**, **Inspiration**, **Kinderschminke**, **Kohletabletten**, **Kompressen**, **Kondome**, **Kosmetiktücher**, **Kühlgel**, **Linsenmittel**, **Lippenpflege**, **Lippenstift**, **Listen**, **Makeup**, **Makeup Entferner**, Mundspülung, **Muskelcreme**, **Mückenschutz**, **Nagelfeile**, **Nagellack**, **Nasensalbe**, **Parfüm**, **Peeling**, **Pflaster**, **Pinzette**, **Puder**, **Rasierer**, **Rasierklingen**, **Rasierschaum**, **Rasierwasser**, **Schmerzmittel**, **Seife**, Shampoo, **Sonnencreme**, **Tampons**, Taschentücher, Toilettenpapier, **Verband**, **Vitamine**, **Wattepads**, **mittel**, **ner**, **spray**, **ter**, **www**

### Tierbedarf — 7 Artikel, davon 7 neu

**Fischfutter**, **Hundefutter**, **Hundesnack**, **Katzenfutter**, **Katzensnack**, **Katzenstreu**, **Vogelfutter**

### Baumarkt & Garten — 40 Artikel, davon 33 neu

Brokkoli, **Brokkr**, Brot, Brötchen, **Gemüse**, **Giesskanne**, **Grill**, **Hacke**, Haferflocken, **Heckenschere**, **Holzkohle**, **Inspiration**, **Knoblauchpulver**, **Listen**, **Lucky Bamboo**, Milch, **Naturtofu**, **Nägel**, **PROPANE**, **Pestizide**, **Pflanzen**, **Pinsel**, **Propangas**, **Rasenmäher**, **Saatgut**, **Schaufel**, **Schneeketten**, **Schrauben**, **Setzholz**, **Setzlinge**, **Sonnenschirm**, **Streusalz**, **Stärke?**, **Sämereien**, Tomaten, **Töpfe**, **ben**, maten, **sen (10€)**, **Übertöpfe**
