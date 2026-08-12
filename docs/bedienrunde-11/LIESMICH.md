# Bilderbögen zur Bedienrunde 11.08., Punkt 2 und 3

Die Bilder in diesem Ordner sind die Belege zu [#139](https://github.com/Scxttk/lechariot-app/issues/139)
(Preisfahne) und [#140](https://github.com/Scxttk/lechariot-app/issues/140)
(Rahmen der Schilder). Sie sind **nicht abfotografiert**, sondern von zwei
Bögen im Unit-Ziel gezeichnet und lassen sich jederzeit neu erzeugen:

```sh
tools/tests.sh KachelFahneShots SchilderRahmenShots --result /tmp/bogen.xcresult
xcrun xcresulttool export attachments --path /tmp/bogen.xcresult --output-path /tmp/bogen
```

`-vorher` steht für den Stand von `2bb8d4f`, `-nachher` für diesen Zweig.

Die Zahl unter dem Bild — wie viel Zeichnung die Fahne verdeckt — kommt nicht
von hier, sondern aus einer Rechnung über die Pfade; sie steht im PR und in
`ShoppingGridTile.fahnenVersatz`.
