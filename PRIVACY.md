# Datenschutzerklärung — Le Chariot

Stand: 25. Oktober 2026

Le Chariot vergleicht die Wochenangebote deutscher Supermärkte mit deiner
Einkaufsliste. Diese Erklärung sagt, was die App dabei über dich speichert und
was sie verschickt. Der kurze Teil vorweg: **Dein Name verlässt dein Telefon
nicht, deine Einkaufsliste nur, wenn du „Kochen" nutzt und vorher zustimmst.**

## Verantwortlich

Scott Koehler · <scott_koehler@web.de>

Le Chariot ist ein privates, nicht-kommerzielles Projekt: kostenlos, ohne
Werbung, ohne Käufe im Programm. Sollte sich das ändern, kommen an dieser Stelle
die vollständigen Anbieterangaben dazu.

## Was auf dem Gerät bleibt

Diese Daten werden ausschließlich lokal gespeichert und nie übertragen:

- dein Vorname
- deine Einkaufsliste (Ausnahme: „Kochen", siehe unten)
- deine Notizen zu Artikeln
- welche Märkte du magst (die Frage aus dem Onboarding)
- welche Angebote du weggelegt hast
- alle Einstellungen der App

## Was übertragen wird

Erst wenn du im Onboarding ausdrücklich zustimmst, wird ein Profil an unseren
Server übertragen. Ohne diese Zustimmung geht nichts davon raus.

| Was | Wozu |
|---|---|
| eine zufällige Installations-ID | um deine Angaben einander zuzuordnen, ohne zu wissen, wer du bist |
| Postleitzahl und gewählte Filialen | damit die richtigen Prospekte geholt und dir angezeigt werden |
| Haushaltsgröße, Einkaufsrhythmus, Budget, Ernährungsangaben | um die Vorschläge auf deinen Haushalt zuzuschneiden |

Meldest du einen falschen Treffer („Das passt nicht"), wird zusätzlich
übertragen: das Wort von deiner Liste, das den Treffer erzeugt hat, das
gefundene Produkt, der Markt, und dein Freitext-Kommentar, falls du einen
schreibst. Das dient dazu, die Produkterkennung zu verbessern. Die Meldung
geht nur raus, wenn du sie abschickst.

### Kochen

„Kochen" schlägt Gerichte aus deiner Liste vor und macht aus einem Gericht
eine Zutatenliste. Dafür wird ein Sprachmodell gefragt: **Claude von Anthropic**. Bevor das zum ersten Mal passiert, fragt die App dich
ausdrücklich; ohne deine Zustimmung bleibt „Kochen" aus und alles andere
funktioniert wie bisher.

Übertragen wird nur, was die Antwort braucht:

| Was | Wozu |
|---|---|
| das Gericht, das du eintippst, oder die Texte der Einträge deiner Liste | damit das Modell Gerichte bzw. Zutaten nennen kann |
| Begriffe aus den Angeboten der Woche (z. B. „hackfleisch"), ohne Markt oder Filiale | damit Vorschläge zu den Angeboten passen |
| die Installations-ID | nur für das Tageslimit; gespeichert wird davon ein nicht umkehrbarer Hash, der nach zwei Tagen gelöscht wird |

Nicht übertragen werden dein Vorname, deine Notizen, deine Postleitzahl und
deine Filialen. Die Anfrage geht über unseren Server (Supabase) an Anthropic;
wir speichern weder die Anfrage noch die Antwort. Anthropic verarbeitet sie,
um die Antwort zu erzeugen, und verwendet Daten aus dieser Schnittstelle nach
seinen Bedingungen nicht zum Training seiner Modelle. Anthropic kann
Anfragen für eine begrenzte Zeit zur Missbrauchserkennung aufbewahren; die
Einzelheiten stehen in der Datenschutzerklärung von Anthropic
(<https://www.anthropic.com/legal/privacy>). Die Verarbeitung kann in den USA
stattfinden; sie stützt sich auf die Standardvertragsklauseln der
EU-Kommission im Datenverarbeitungsvertrag von Anthropic.

Deine Zustimmung kannst du in den Einstellungen unter **Kochen** jederzeit
widerrufen.

**Die Installations-ID ist zufällig** und wird bei der Installation erzeugt. Sie
ist aus keiner Gerätekennung abgeleitet und lässt sich mit nichts außerhalb
dieser App verknüpfen. Da wir weder Namen noch E-Mail-Adresse noch ein
Benutzerkonto haben, sind die übertragenen Daten für uns nicht einer Person
zuzuordnen.

## Standort

Wenn du es erlaubst, benutzt die App deinen Standort, um deine Postleitzahl zu
bestimmen und die Entfernung zu den Filialen zu berechnen. **Deine Koordinaten
verlassen das Gerät nicht** — übertragen wird nur die Postleitzahl. Beides geht
auch ohne Standortfreigabe: Die Postleitzahl kannst du eingeben, die
Entfernungen werden dann ab deren Mitte gerechnet.

## Wer die Daten bekommt

Gespeichert wird bei **Supabase** (Supabase Inc.), unserem Hosting-Anbieter, der
die Daten in unserem Auftrag verarbeitet. Nutzt du „Kochen", geht deine Anfrage
außerdem an **Anthropic** (siehe oben). Darüber hinaus geben wir nichts
weiter.

Die App enthält **keine Bibliotheken von Drittanbietern** — kein Analyse-SDK,
kein Werbenetzwerk, keine Absturzberichte an Dritte. Sie spricht ausschließlich
mit unserem eigenen Server; auch „Kochen" läuft über ihn.

## Werbung und Tracking

Findet nicht statt. Es gibt keine Werbung, keine Werbe-ID (IDFA), kein
geräteübergreifendes Tracking und keine Weitergabe an Datenhändler.

## Rechtsgrundlage

Die Übertragung des Profils beruht auf deiner Einwilligung
(Art. 6 Abs. 1 lit. a DSGVO), die du im Onboarding ausdrücklich erteilst und
jederzeit widerrufen kannst. Eine Rückmeldung zu einem falschen Treffer schickst
du selbst ab; auch das ist eine Einwilligung. Für „Kochen" gibt es eine eigene
Einwilligung, die du vor der ersten Nutzung erteilst.

## Speicherdauer

Profile und Rückmeldungen werden gespeichert, solange sie für die Verbesserung
der App gebraucht werden. Preisverläufe werden nach 26 Wochen automatisch
gelöscht.

## Deine Rechte

Du hast das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung der
Verarbeitung, Datenübertragbarkeit und Widerspruch, sowie das Recht, dich bei
einer Aufsichtsbehörde zu beschweren.

Weil wir bewusst nicht wissen, wer du bist, brauchen wir für Auskunft oder
Löschung deine Installations-ID. Du findest sie in der App unter
**Einstellungen → App**; ein Tipp auf die Zeile kopiert sie. Schick sie an die
oben genannte Adresse, dann löschen wir die zugehörigen Zeilen.

Achtung: „App zurücksetzen" vergibt eine **neue** Installations-ID. Wenn du
früher hochgeladene Angaben löschen lassen willst, kopier die alte vorher —
danach kann sie niemand mehr zuordnen, wir nicht und du auch nicht. Löschst du
die App, ohne dich zu melden, bleibt eine Handvoll Zeilen ohne jeden Bezug zu
dir zurück — wir können sie dann keinem Menschen mehr zuordnen, du aber auch
nicht mehr benennen.

Deine Einwilligung widerrufen kannst du in den Einstellungen der App. Alles, was
lokal gespeichert ist, verschwindet mit dem Löschen der App.

## Änderungen

Ändert sich, was die App überträgt, wird diese Seite vorher angepasst. Das Datum
oben sagt, welcher Stand gilt.
