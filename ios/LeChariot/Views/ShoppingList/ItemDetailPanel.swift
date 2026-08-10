import SwiftUI

/// Die Angaben zum eben angelegten Artikel — **als Schicht, nicht als Blatt.**
///
/// Scotts Rückmeldung vom 03.08., nach dem Bring!-Video Bild für Bild: „Das
/// Mengen-Menü blockiert das Weitertippen — genau das, was Bring! nicht tut."
/// Bis dahin war das hier ein `.sheet`, das beim Anlegen von selbst aufging,
/// dem Eingabefeld den Fokus nahm und ein „Fertig" verlangte, bevor der nächste
/// Artikel getippt werden konnte. Drei Artikel hintereinander waren drei
/// Tastatur-Abbrüche.
///
/// **Was diese Ansicht anders macht — und es sind vier Dinge, keine Geschmacks-
/// frage:**
///
/// 1. Sie liegt zwischen Liste und Eingabezeile, im selben Block wie die
///    Vorschläge. Kein Modal, keine sichere Fläche, kein Fokus.
/// 2. Sie hat **keinen eigenen Knopf zum Weglegen**, weil es nichts zu
///    bestätigen gibt: Jeder Chip schreibt sofort durch. Ein ignoriertes Panel
///    speichert nichts und richtet nichts an — es wird beim nächsten Artikel
///    schlicht ersetzt. Bis zum 08.08. saß hier ein ✗ oben rechts; der Ausgang
///    liegt seitdem als „Fertig" unten links an der Tastatur, wo der Daumen
///    ohnehin ist (`ShoppingListView.doneButton`, Scotts Punkt C-3).
/// 3. Die Kachelzeile oben zeigt, was gerade entstanden ist; der aktive Artikel
///    hervorgehoben, die vorigen ruhig. Man sieht seinen eigenen Fluss, ohne die
///    Liste zu verlassen.
/// 4. Die volle Fassung (Freitext, Gruppen mit Überschriften, alte Wörter)
///    liegt einen benannten Knopf weiter — sie ist eine Absicht, kein
///    Durchgangszimmer.
struct ItemDetailPanel: View {
    /// Der Artikel, dessen Angaben hier stehen. **Live aus dem Speicher
    /// gereicht**, nicht kopiert: Ein Chip, den man antippt, muss im selben
    /// Durchgang eingefärbt zurückkommen.
    let item: ShoppingItem
    /// Die Reihen für **diesen** Artikel — Menge, Größe, ggf. Sorte aus dem
    /// Wörterbuch, Art, Anlass. Siehe `ItemDetailVocabulary.groups(for:)`.
    let reihen: [ItemDetailVocabulary.Group]
    /// Die zuletzt angelegten Artikel, ältester zuerst.
    let recent: [ShoppingItem]
    /// Wie viel Höhe hier stehen darf, ohne der Liste ihre Kachelreihe zu
    /// nehmen. `nil` heißt: Es drängt nichts, nimm die volle Zahl an Reihen.
    /// Gerechnet wird sie in `ShoppingListView.platzFuerAngaben`.
    var platz: CGFloat?
    let onFocus: (ShoppingItem) -> Void
    let onToggleChip: (String) -> Void
    let onOpenFull: () -> Void

    /// Die Höhe **einer** Reihe: Überschrift, kleiner Abstand, Chipreihe.
    /// Skaliert mit der Schrift, aber immer als **ganze** Reihe.
    @ScaledMetric(relativeTo: .subheadline) private var rowHeight: CGFloat = 60

    /// Wie viele Reihen **höchstens** dastehen.
    ///
    /// **Vier, und das ist die Zahl, um die es Scott ging** (08.08.): Bring!
    /// gibt den Angaben rund 45 % des Bildschirms, wir gaben ihnen 25 % — und
    /// genau daran las sich das Ergebnis nicht wie Bring!. Vier Reihen plus
    /// Kachelzeile, Notizzeile und Eingabezeile ergeben gemessen 47 %.
    ///
    /// **Höchstens**, weil die vier auf einem iPhone 17 Pro gemessen wurden und
    /// dort mit 9 pt aufgingen — auf jedem kleineren Bildschirm nicht mehr.
    /// Welche Zahl es wirklich wird, entscheidet der Platz: siehe `vocabulary`.
    private static let maxRows = 4

    /// Die Höhe des Wortschatz-Feldes. Fest, nicht mitwachsend: Ob ein Artikel
    /// zwei Chips gewählt hat oder keinen und ob das Wörterbuch eine Sorte
    /// kennt oder nicht, darf die Eingabezeile darunter nicht bewegen —
    /// dieselbe Regel wie beim Wörterbuch-Streifen.
    ///
    /// **Immer ein ganzes Vielfaches einer Reihe**, und darin steckt die
    /// Lehre vom 03.08.: Damals stand hier eine senkrecht scrollende Spalte
    /// auf fester Höhe, und der Schnitt landete **mitten in einer Chipreihe**
    /// — „klein" lag halb über und halb unter der Kante der Eingabezeile. Der
    /// Ausweg war seinerzeit, alles in **eine** waagerechte Reihe zu legen;
    /// mit einem hohen Panel ist diese Not vorbei, aber die Lehre nicht: Die
    /// Höhe ist heute ein Vielfaches der Reihenhöhe, und gescrollt wird
    /// **reihenweise** (`.viewAligned`). Angeschnitten werden kann damit
    /// nichts, in keiner Scroll-Lage und bei keinem Schriftgrad.
    private func vocabularyHeight(_ rows: Int) -> CGFloat {
        CGFloat(rows) * rowHeight + CGFloat(rows - 1) * Theme.Spacing.xs
    }

    var body: some View {
        // Enge Abstände zwischen den drei Teilen, weite innerhalb: Was hier
        // gespart wird, ist die Höhe, die oben die Liste bekommt.
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            header
            vocabulary
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.xs)
        .readableWidth()
        // **Kein Bezeichner auf dem Behälter.** Er erbt sich auf jedes Kind
        // und überschreibt dessen eigenen — am Simulator gemessen: „Notiz …"
        // trug danach `list.detailPanel` statt `list.detailPanel.more` und war
        // für keine Journey mehr auffindbar. Dieselbe Falle steht seit dem
        // 30.07. in `TutorialOverlay` beschrieben.
        // **Ein- und ausblenden, nicht schieben — und das ist keine
        // Geschmacksfrage.** `.move(edge: .bottom)` verschiebt die Schicht in
        // ihren Platz hinein, und der Rundgang-Anker nimmt diese Verschiebung
        // mit: Am 03.08. gemessen lag sein Loch danach dauerhaft 186 pt tiefer
        // als die Schicht, die der Rahmen erklärt — der Anker wird nach der
        // Bewegung nicht noch einmal gemeldet. Ohne Versatz kein falsches Loch.
        .transition(.opacity)
    }

    // MARK: Kachelzeile

    /// **„Notiz …" bleibt neben der Kachelzeile, und das ist gemessen.**
    ///
    /// Bring! führt sie als eigene Zeile unten im Panel, und so stand sie hier
    /// auch einen Nachmittag lang. Der Preis dafür sind 48 pt, und die fehlen
    /// genau dort, wo es an diesem Tag um jeden Punkt ging: Über dem Block
    /// muss eine **ganze Kachelreihe** stehen bleiben (112 pt seit den drei
    /// Spalten aus #91). Mit der Notizzeile blieben 73 pt — also keine
    /// Kachel; ohne sie 121 pt — also eine ganze.
    /// **Die Zeile scrollt dem aktiven Artikel nach** (10.08., zweiter Befund
    /// des Zonen-Bildes vom 08.08.).
    ///
    /// Der aktive Chip ist der zuletzt angelegte, also **der letzte** der
    /// Reihe — und die Reihe endet an `noteRow`, das sich seine Breite mit
    /// `layoutPriority` nimmt. Ab dem dritten, vierten Artikel steht der Chip,
    /// auf den es gerade ankommt, damit halb unter der Kante: gefärbt, aber
    /// nicht lesbar. Aufgefallen ist das am gerenderten Bild und an keinem
    /// Test — die Journeys fragen `frame` und `label`, und beide stimmen auch
    /// für einen Chip, von dem die Hälfte fehlt.
    ///
    /// `.trailing` und nicht `.center`: Der neue Artikel gehört ans Ende, und
    /// mittig gezogen stünde rechts von ihm eine Lücke, in der nichts ist.
    /// Ohne Bewegung, weil der Wechsel selbst schon einer ist — die Schicht
    /// blendet im selben Moment ein.
    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(recent) { entry in
                            recentChip(entry)
                                .id(entry.id)
                        }
                        // **Ein Streifen Nichts am Ende, und er ist gemessen.**
                        // Am Anschlag rechts liegt die Kante der Scroll-Fläche
                        // nicht dort, wo „Notiz …" anfängt: Der aktive Chip
                        // endete bei 287,7, der Knopf beginnt bei 285,7 — zwei
                        // Punkte darunter. Der Streifen schiebt den letzten
                        // Chip um seine Breite nach links, und damit steht er
                        // ganz im Bild statt fast.
                        Color.clear
                            .frame(width: Theme.Spacing.md, height: 1)
                            .accessibilityHidden(true)
                    }
                }
                .onChange(of: item.id, initial: true) { _, id in
                    proxy.scrollTo(id, anchor: .trailing)
                }
            }
            // Vorrang, sonst nimmt die gierige Scroll-Ansicht daneben die ganze
            // Breite und drückt den Knopf auf null — am Simulator gemessen:
            // Die Kachelzeile stand, der Knopf war im Baum nicht auffindbar.
            noteRow
                .fixedSize()
                .layoutPriority(1)
        }
    }

    private func recentChip(_ entry: ShoppingItem) -> some View {
        let isActive = entry.id == item.id
        return Button {
            onFocus(entry)
        } label: {
            Text(entry.text)
                .font(.subheadline.weight(isActive ? .semibold : .regular))
                .lineLimit(1)
                .foregroundStyle(isActive ? Theme.onAccent : Theme.secondaryText)
                .padding(.horizontal, Theme.Spacing.md)
                .frame(height: 32)
                .background(
                    isActive ? Theme.accent : Theme.surface,
                    in: Capsule()
                )
                .overlay(Capsule().strokeBorder(isActive ? Color.clear : Theme.stroke))
        }
        .buttonStyle(TactileButtonStyle())
        // Der Artikelname allein wäre die Beschriftung der Listenzeile — zwei
        // Knöpfe mit demselben Namen auf einem Bildschirm, und keine Journey
        // könnte sie auseinanderhalten.
        .accessibilityLabel("Angaben zu \(entry.text)")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("list.detailPanel.recent")
    }

    /// Der Weg in die volle Fassung. **Benannt statt nur ein Zeichen:** Hier
    /// liegt der Freitext, und ein Punkt-Punkt-Punkt-Knopf sagt niemandem,
    /// dass man dahinter etwas schreiben kann.
    private var noteRow: some View {
        Button(action: onOpenFull) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "square.and.pencil")
                Text("Notiz …")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, Theme.Spacing.md)
            .frame(height: 32)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.stroke))
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel("Notiz und alle Angaben zu \(item.text)")
        .accessibilityIdentifier("list.detailPanel.more")
    }

    // MARK: Wortschatz

    /// **Die Reihen liegen wieder übereinander — und diesmal trägt die Höhe
    /// sie** (2026-08-08, Scotts Nachrunde zu Punkt C).
    ///
    /// Am 03.08. lagen sie schon einmal so, und es ging schief: eine senkrecht
    /// scrollende Spalte in einem **niedrigen** Panel, auf feste Höhe
    /// geschnitten. Egal welche Höhe — der Schnitt landete mitten in einer
    /// Chipreihe, weil eine Gruppe 65 pt hoch ist und der Rest des Panels
    /// nicht; „klein" lag halb über und halb unter der Kante der Eingabezeile.
    /// Der Ausweg war, alles in **eine** waagerechte Reihe zu legen.
    ///
    /// **Was sich geändert hat, ist die Höhe, nicht die Meinung.** Bring! gibt
    /// den Angaben rund 45 % des Bildschirms; wir gaben ihnen 25 %, und genau
    /// daran las sich der Bildschirm nicht wie Bring!. Mit vier Reihen ist der
    /// Zwang weg, alles in eine Zeile zu pressen — die Lehre von damals bleibt
    /// trotzdem stehen und ist jetzt **eingebaut** statt umgangen:
    ///
    /// 1. Die Höhe ist ein **ganzes Vielfaches** der Reihenhöhe.
    /// 2. Eine Reihe ist selbst unteilbar — Überschrift plus **eine**
    ///    Chipzeile, die zur Seite scrollt, statt umzubrechen. Ein Umbruch
    ///    machte die Reihe je Artikel verschieden hoch, und dann wanderte die
    ///    Eingabezeile beim Weitertippen.
    /// 3. Gescrollt wird **reihenweise** (`.viewAligned`), damit auch in
    ///    jeder Zwischenlage eine ganze Reihe an der Kante steht.
    ///
    /// Der ganze Wortschatz mit Umbruch, Überschriften und Freitext liegt
    /// weiterhin hinter „Notiz …".
    ///
    /// **Wie viele Reihen es werden, entscheidet der Platz — und das ist der
    /// Nachtrag vom 09.08.** Vier Reihen waren auf einem iPhone 17 Pro unter
    /// iOS 26.2 gemessen, und sie gingen dort mit **9 pt** auf. Diese 9 pt sind
    /// die ganze Reserve gewesen, und sie reicht nirgends sonst: Die Tastatur
    /// unter iOS 26.1 ist 10 pt höher, ein iPhone 16e hat 30 pt weniger Schirm,
    /// ein iPhone SE 207 pt weniger. Gemessen (Kachelreihe über dem Block):
    /// 17 Pro/26.2 **+9 pt**, 17 Pro/26.1 **−1**, 16e **−6**, SE **−81**. Auf
    /// dem SE stand von der oberen Zone ein Streifen von 39 pt — genau der
    /// Zierrat, gegen den `header` argumentiert.
    ///
    /// Was daraus wird, steht in `sichtbareReihen`: 17 Pro/26.2 **vier** (und
    /// damit auf Scotts Gerät unverändert), 17 Pro/26.1 und 16e **drei**,
    /// SE **zwei**.
    private var vocabulary: some View {
        wortschatz(rows: sichtbareReihen)
    }

    /// Die Höhe des Panels **ohne** den Wortschatz: der obere Rand aus `body`,
    /// die 32 pt hohe Kachelzeile aus `recentChip`, der Abstand des `VStack`
    /// darunter. Alle drei sind Maße dieser Ansicht selbst — nachgerechnet
    /// gegen den Simulator: 40 pt, und mit drei Reihen ergab das ein Panel von
    /// 228 pt, genau wie gemessen.
    private var kopfHoehe: CGFloat {
        Theme.Spacing.xs + 32 + Theme.Spacing.xs
    }

    /// Die größte Reihenzahl, die in `platz` passt — höchstens `maxRows`,
    /// mindestens eine. Ohne `platz` bleibt es bei `maxRows`.
    private var sichtbareReihen: Int {
        guard let platz else { return Self.maxRows }
        for rows in stride(from: Self.maxRows, through: 2, by: -1)
        where kopfHoehe + vocabularyHeight(rows) <= platz {
            return rows
        }
        return 1
    }

    private func wortschatz(rows: Int) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                ForEach(reihen) { group in
                    groupRow(group)
                }
            }
            .scrollTargetLayout()
        }
        .frame(height: vocabularyHeight(rows))
        .scrollTargetBehavior(.viewAligned)
        .scrollBounceBehavior(.basedOnSize)
    }

    private func groupRow(_ group: ItemDetailVocabulary.Group) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(group.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(group.chips, id: \.self) { chip in
                        chipButton(chip)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(height: rowHeight, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chipButton(_ word: String) -> some View {
        let isOn = (item.detail ?? []).contains(word)
        return Button {
            onToggleChip(word)
        } label: {
            Text(word)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(isOn ? Theme.onAccent : Color.primary)
                .padding(.horizontal, Theme.Spacing.md)
                .frame(minWidth: 64)
                .frame(height: 44)
                .background(
                    isOn ? Theme.accent : Theme.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                        .strokeBorder(isOn ? Color.clear : Theme.stroke)
                )
        }
        .buttonStyle(TactileButtonStyle())
        // Farbe allein sagt es nicht — `.isSelected` ist, was VoiceOver
        // vorliest, und der Audit prüft auf die Beschriftung.
        .accessibilityLabel(word)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    let milch = ShoppingItem(text: "Milch", detail: ["1 l"])
    return VStack {
        Spacer()
        ItemDetailPanel(
            item: milch,
            reihen: ItemDetailVocabulary.groups(for: milch.text),
            recent: [ShoppingItem(text: "Butter"), ShoppingItem(text: "Kaffee"), milch],
            onFocus: { _ in },
            onToggleChip: { _ in },
            onOpenFull: {}
        )
    }
    .background(.bar)
}
