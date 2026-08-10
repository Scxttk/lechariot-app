import SwiftUI

/// **Wann die Karte eines Rahmens stehen darf** — als Regel, nicht als
/// Ausdruck mitten in einer Ansicht.
///
/// Eigener Typ aus demselben Grund wie `SuggestionSurface.isExpanded` und
/// `SpotlightTransition.move`: Die Aussage ist prüfbar, die Ansicht darum
/// herum nicht. Sie steht hier und nicht in einer eigenen Datei, weil sie zum
/// Overlay gehört und man sie zusammen liest.
enum TutorialCardVisibility {
    /// - Parameters:
    ///   - deed: Was der Rahmen erwartet. `.reads` hat kein Ziel und wartet
    ///     deshalb auf nichts — sonst stünde die Schlusskarte nie.
    ///   - sawTargetFor: Der Rahmen, dessen Ziel schon einmal gemeldet wurde.
    ///   - index: Der Rahmen, der gerade dran ist.
    static func isReady(deed: TutorialStep.Deed, sawTargetFor: Int?, index: Int) -> Bool {
        deed == .reads || sawTargetFor == index
    }
}

/// The tour itself: a scrim over the whole app with a hole cut around exactly
/// one control, and a card that says what that control does — and why.
///
/// Everything outside the hole is inert — that is the point. Testers who opened
/// the app after onboarding did not know where to start, and a tour that leaves
/// the whole screen live is just a tooltip they can tap past by accident.
///
/// **Seit dem 09.08. tippt der Nutzer selbst.** Es gibt kein „Weiter" mehr: Der
/// Rahmen wartet auf die Handlung, die sein Text ansagt, und geht erst dann
/// weiter (`TutorialStep.Deed`). Genau ein Rahmen je Fassung ist zum Lesen — die
/// Schlusskarte. Die Melder für die Liste (Artikel angelegt, Artikel abgehakt)
/// sitzen hier, weil das Overlay die Liste ohnehin schon in der Hand hat; die
/// übrigen melden von der Stelle, an der sie passieren.
struct TutorialOverlay: View {
    let anchors: [TutorialTarget: Anchor<CGRect>]
    let proxy: GeometryProxy
    /// Store und Liste kommen als Parameter, nicht aus der Umgebung: Das
    /// Overlay hängt per `.overlayPreferenceValue` *über* den `.environment`-
    /// Aufrufen der TabView und sähe sie dort nicht.
    let tutorial: TutorialStore
    let list: ShoppingListStore

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var cardFocused: Bool

    /// Der Rahmen, dessen Schonfrist abgelaufen ist.
    ///
    /// Bewusst ein `@State` und keine Prüfung im `.task`: Die Anker kommen als
    /// Parameter herein, und ein laufender Task hält die Kopie von *seinem*
    /// Start fest. Genau daran sind die ersten Rahmen reihenweise
    /// vorbeigelaufen — die Anker waren längst da, der Task sah aber noch das
    /// leere Wörterbuch von vorhin. Über einen Zustand geht die Entscheidung
    /// durch einen frischen `body`.
    ///
    /// Und der Schrittindex statt eines `Bool`, weil sonst die abgelaufene
    /// Schonfrist des *vorigen* Rahmens den nächsten sofort überspringt: Der
    /// Task setzt erst asynchron zurück, die Anker melden sich früher.
    @State private var graceExpiredFor: Int?

    /// Das Loch, wie es gerade **gezeichnet** wird — und der Schritt, zu dem
    /// es gehört.
    ///
    /// Getrennt vom aufgelösten Anker, weil die Anker einen Layout-Durchgang
    /// nach dem Schrittwechsel kommen. Vorher stand hier `resolvedHole ?? .zero`,
    /// und in diesem einen Durchgang schrumpfte das Loch sichtbar in die linke
    /// obere Ecke. Was wann bewegt wird, entscheidet `SpotlightTransition` —
    /// dort steht auch, warum.
    @State private var shownHole: CGRect = .zero
    @State private var shownIndex: Int = -1

    /// Anker kommen einen Layout-Durchgang nach dem Schrittwechsel — beim
    /// letzten Rahmen sogar erst nach einem Tab-Wechsel. Erst danach darf
    /// „kein Ziel“ heißen: Rahmen überspringen.
    private static let anchorGrace = Duration.milliseconds(1200)

    /// Wie lange nach einem Schrittwechsel ein nachrückender Anker noch zum
    /// Wechsel gehört — siehe `SpotlightTransition.move(settling:)`. Muss über
    /// `TourTabTransition.standard.total` liegen, denn der Tab-Wechsel bringt
    /// seine Anker erst hinter der Überblendung mit.
    private static let settleWindow = Duration.milliseconds(700)

    /// Der Schrittwechsel liegt noch im Einschwing-Fenster.
    @State private var settling = false

    private var step: TutorialStep { tutorial.step }

    var body: some View {
        ZStack(alignment: .topLeading) {
            scrim
            blockers
            holeProbe
            // **Die Karte kommt erst, wenn ihr Ziel da ist** (10.08.).
            //
            // Scotts Meldung aus Build `2026.810.705`: „the tours first stop
            // also gets automatically skipped". Der Rahmen, der sich selbst
            // überspringt, war schon vorgesehen — ein Rahmen ohne Ziel ist eine
            // Sackgasse, und `skipIfNothingToShow` räumt ihn nach 1,2 s weg.
            // Der Fehler ist nicht das Wegräumen, sondern dass er **vorher zu
            // sehen war**: Karte steht, Text steht, und dann springt sie ohne
            // Zutun weiter. Genau das liest sich von außen als Fehler.
            //
            // Jetzt wartet die Karte auf `sawTargetFor` (siehe dort). Ein
            // Rahmen, dessen Ziel nie erscheint, wird damit **nie gezeigt** —
            // er wird still übersprungen, wie es immer gemeint war. Nebenbei
            // fällt der Sprung weg, mit dem die Karte bisher jeden Rahmen
            // anfing: Ohne Loch stand sie mittig und wanderte erst mit dem
            // eintreffenden Anker an ihren Platz.
            // **Versteckt, nicht entfernt — und das ist zweimal gemessen.**
            //
            // Der erste Entwurf schrieb `if cardIsReady { cardLayer }`. Das
            // kostete fünf Journeys, und zwar mit **und** ohne Kurve darauf
            // (10.08., zwei Läufe): Ein `if` wechselt die strukturelle
            // Identität, und beim Schrittwechsel steht die abtretende Karte
            // noch im Baum, während die neue schon da ist. Dann gibt es
            // **zwei** Elemente `tutorial.card`, und XCUITest greift das
            // erste — die alte. Beide Fehlerbilder erklären sich daraus: Die
            // Journey wiederholte die Handlung des vorigen Rahmens, bis sie in
            // ihren Deckel lief („Der Rundgang hört nicht auf"), und auf der
            // Schlusskarte standen „Tour beenden" und „Fertig" gleichzeitig —
            // einer je Karte.
            //
            // Deshalb bleibt genau **eine** Karte im Baum; sie ist nur
            // unsichtbar, unantastbar und für Hilfstechnik nicht da, solange
            // ihr Ziel fehlt.
            cardLayer
                .opacity(cardIsReady ? 1 : 0)
                .allowsHitTesting(cardIsReady)
                .accessibilityHidden(!cardIsReady)
        }
        .frame(width: proxy.size.width, height: proxy.size.height)
        // Auf den Schritt animiert, nicht auf das Rechteck: Das Rechteck ändert
        // sich auch, wenn die Liste scrollt oder die Tastatur kommt, und dann
        // würde das Loch unter dem Finger davonschwimmen.
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: tutorial.index)
        // Modal, damit VoiceOver nicht durch die Abdunklung hindurchliest.
        //
        // **Ohne** `accessibilityElement(children: .contain)` — die Kombination
        // nimmt die Karte samt Knöpfen aus dem Baum, nachgewiesen an der
        // Element-Hierarchie eines Testlaufs.
        .accessibilityAddTraits(.isModal)
        .onAppear {
            enterStep()
            noteTarget()
            moveHoleIfNeeded()
        }
        .onChange(of: tutorial.index) { _, _ in
            enterStep()
            noteTarget()
            // Beim Schrittwechsel steht der neue Anker meist noch nicht da.
            // Dann tut das hier nichts, und das Loch bleibt liegen, bis der
            // Anker unten eintrifft — statt in die Ecke zu fliegen.
            moveHoleIfNeeded()
        }
        .onChange(of: resolvedHole) { _, _ in
            noteTarget()
            moveHoleIfNeeded()
        }
        .task(id: tutorial.index) {
            let index = tutorial.index
            settling = true
            try? await Task.sleep(for: Self.settleWindow)
            guard !Task.isCancelled else { return }
            settling = false
            try? await Task.sleep(for: Self.anchorGrace - Self.settleWindow)
            guard !Task.isCancelled else { return }
            graceExpiredFor = index
        }
        // Der Vorlesefokus gehört auf die Karte — und die steht jetzt erst,
        // wenn ihr Ziel gemeldet ist. Ein `cardFocused = true` auf eine Ansicht,
        // die es noch gar nicht gibt, verpufft.
        .onChange(of: cardIsReady) { _, bereit in
            if bereit { enterStep() }
        }
        .onChange(of: graceExpiredFor) { _, _ in skipIfNothingToShow() }
        // Zweiter Auslöser: ein Anker, der erst nach Ablauf der Schonfrist
        // gemeldet würde — oder eben nie. Was einmal da war, zählt weiter;
        // siehe `skipIfNothingToShow`.
        .onChange(of: anchorFingerprint) { _, _ in
            noteTarget()
            skipIfNothingToShow()
        }
        // **Die zwei Melder der Liste.** Sie stehen hier und nicht in
        // `ShoppingListView`, weil das Overlay die Liste ohnehin als Parameter
        // hält — und weil hier beide nebeneinander stehen und man sie zusammen
        // liest. Beide vergleichen **alt gegen neu**: „es gibt einen
        // abgehakten Artikel" wäre nach dem ersten Einkauf für immer wahr.
        .onChange(of: list.items.count) { alt, neu in
            if neu > alt { tutorial.report(.addsItem) }
        }
        .onChange(of: checkedCount) { alt, neu in
            if neu > alt { tutorial.report(.checksItem) }
        }
        // **Die Karte muss über der Tastatur bleiben** (09.08.).
        //
        // Der erste Rahmen zeigt auf die Eingabezeile und bittet darum, dort
        // etwas zu tippen. Sobald jemand das tut, steht die Tastatur — und die
        // Karte lag darunter, weil unter dem Loch mehr Platz *gerechnet* war
        // als tatsächlich frei. Am Bild gefunden: Im Video des Testlaufs steht
        // der Rahmen als Schemen hinter den Tasten.
        //
        // Über die Meldung und nicht über `keyboardLayoutGuide`: Das Overlay
        // ignoriert die sichere Fläche (sonst deckte es den Bildschirm nicht
        // ganz ab), und damit meldet ihm auch die Tastatur nichts.
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillChangeFrameNotification
        )) { meldung in
            guard let rahmen = meldung.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                as? CGRect else { return }
            keyboardTop = rahmen.minY
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillHideNotification
        )) { _ in
            keyboardTop = nil
        }
    }

    /// Oberkante der Tastatur, `nil` wenn keine steht.
    @State private var keyboardTop: CGFloat?

    /// Wo der Platz für die Karte nach unten endet: am Bildschirmrand oder an
    /// der Tastatur, je nachdem was weiter oben liegt.
    private var bottomLimit: CGFloat {
        min(proxy.size.height, keyboardTop ?? proxy.size.height)
    }

    private var checkedCount: Int { list.checkedItems.count }

    // MARK: Ablauf

    private func enterStep() {
        cardFocused = true
    }

    /// Kein Ziel auf dem Bildschirm — etwa die Vorschau bei einem Tester, dessen
    /// Ketten diese Woche nichts vorab veröffentlichen. Dann geht der Rundgang
    /// weiter, statt vor einem Loch ins Leere stehen zu bleiben.
    ///
    /// **Rahmen zum Lesen sind ausgenommen**, also die Schlusskarte. Ohne diese
    /// Zeile beendete sich der Rundgang 1,2 s nach seinem letzten Rahmen selbst
    /// — der Abschied wäre der einzige Rahmen, den niemand zu Ende liest. Die
    /// Ausnahme hängt am `deed` und nicht am Loch: Die Schlusskarte zeigt mit
    /// Filialen auf die Hinweiszeile der Vorschau, und ob die dasteht, hängt
    /// daran, ob die Ketten dieser Woche etwas vorab veröffentlicht haben. Ohne
    /// Ziel steht sie eben mittig — verabschieden kann sie sich trotzdem.
    ///
    /// **Und wer sein Ziel einmal hatte, verliert es nicht mehr** (09.08.). Bis
    /// dahin durfte ein Anker auch *nach* der Schonfrist noch verschwinden und
    /// den Rahmen mitnehmen; solange jeder Rahmen nach ein paar Sekunden „Weiter"
    /// wegtippte, fiel das nie auf. Ein Rahmen, der auf eine Handlung wartet,
    /// steht dagegen so lange, bis sie kommt — und unter ihm baut die App um:
    /// Beim Umbau der Eingabezeile blinkt der Winkel-Knopf für einen Durchgang
    /// weg, und der ganze Rahmen war still weg. **Am Bild gefunden**, nicht am
    /// Test: Im Bilderbogen fehlte der Vorschläge-Rahmen einfach.
    ///
    /// Geprüft wird deshalb genau einmal — an der Frage „war das Ziel jemals
    /// da?", nicht „ist es gerade da?".
    private func skipIfNothingToShow() {
        guard step.deed != .reads else { return }
        guard sawTargetFor != tutorial.index else { return }
        guard graceExpiredFor == tutorial.index, resolvedHole == nil else { return }
        tutorial.next()
    }

    /// Der Rahmen, dessen Ziel schon einmal gemeldet wurde.
    @State private var sawTargetFor: Int?

    /// **Darf die Karte dieses Rahmens stehen?**
    ///
    /// Ein Rahmen, der auf eine Handlung wartet, redet über ein Bedienelement.
    /// Solange dieses Element nicht gemeldet ist, hat die Karte nichts, worauf
    /// sie zeigt — und sie kann in derselben Sekunde wieder verschwinden, weil
    /// `skipIfNothingToShow` genau darauf wartet. Deshalb wartet sie mit.
    ///
    /// **Rahmen zum Lesen sind ausgenommen**, dieselbe Grenze wie beim
    /// Überspringen: Die Schlusskarte verabschiedet sich auch ohne Ziel.
    private var cardIsReady: Bool {
        TutorialCardVisibility.isReady(
            deed: step.deed, sawTargetFor: sawTargetFor, index: tutorial.index
        )
    }

    private func noteTarget() {
        guard resolvedHole != nil else { return }
        sawTargetFor = tutorial.index
    }

    /// Zieht das gezeichnete Loch nach, wenn `SpotlightTransition` etwas zu
    /// tun sieht. Geflogen wird nur der Schrittwechsel; ein Ziel, das sich an
    /// Ort und Stelle verschiebt (Tastatur, Umbau darunter), wird sofort
    /// übernommen.
    private func moveHoleIfNeeded() {
        guard let move = SpotlightTransition.move(
            shown: shownHole, shownIndex: shownIndex,
            resolved: resolvedHole, index: tutorial.index,
            settling: settling
        ) else { return }
        shownIndex = tutorial.index
        guard move.animated, !reduceMotion else {
            shownHole = move.rect
            return
        }
        withAnimation(.snappy(duration: 0.3)) { shownHole = move.rect }
    }

    /// Welche Anker gerade gemeldet werden — reicht als Änderungssignal, die
    /// Rechtecke selbst interessieren hier nicht.
    private var anchorFingerprint: String {
        anchors.keys.map(\.rawValue).sorted().joined(separator: ",")
    }

    // MARK: Abdunklung

    private var scrim: some View {
        ZStack {
            SpotlightShape(hole: visualHole, cornerRadius: Theme.Radius.card)
                .fill(
                    Color.black.opacity(reduceTransparency ? 0.78 : 0.6),
                    style: FillStyle(eoFill: true)
                )
            // Die Kante des Lochs als Linie — sonst ist die Hervorhebung nur
            // ein Helligkeitssprung, und auf kleinen Zielen sieht man ihn
            // nicht. Siehe `SpotlightRing` und `Theme.onScrim`. Die Linie
            // liegt **auf** der Kante, nimmt dem Loch also innen anderthalb
            // Punkte weg; das Ziel ist um `Spacing.sm` größer aufgezogen, dort
            // ist Luft.
            SpotlightRing(hole: visualHole, cornerRadius: Theme.Radius.card)
                .stroke(Theme.onScrim, lineWidth: 3)
        }
        // Rein sichtbar. Geblockt wird mit eigenen Rechtecken, siehe unten.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Vier Rechtecke rings um das Loch — sie nehmen jede Berührung, und das
    /// Loch bleibt frei.
    ///
    /// Der elegantere Weg wäre `contentShape(shape, eoFill: true)` auf der
    /// Abdunklung: eine Ansicht, exakte runde Ecken, animiert von allein. Er
    /// steht hier nicht, weil er beim Bauen als Verdächtiger galt und ersetzt
    /// wurde — ob er funktioniert, ist damit **offen**, nicht widerlegt. Die
    /// vier stumpfen Rechtecke sind am Simulator nachgewiesen (Tipper auf eine
    /// Vorschlagskachel im Loch kommt an, Tipper daneben nicht), und dabei
    /// bleibt es, bis jemand einen Grund zum Wechseln hat. Der Preis sind die
    /// paar Punkte in den runden Ecken, die antippbar bleiben — unsichtbar und
    /// folgenlos, weil dort nichts liegt.
    @ViewBuilder
    private var blockers: some View {
        let hole = interactiveHole
        if hole.width < 0.5 || hole.height < 0.5 {
            // Kein Durchlass: ein Rechteck über allem.
            blocker(CGRect(origin: .zero, size: proxy.size))
        } else {
            blocker(CGRect(x: 0, y: 0, width: proxy.size.width, height: hole.minY))
            blocker(CGRect(x: 0, y: hole.maxY,
                           width: proxy.size.width, height: proxy.size.height - hole.maxY))
            blocker(CGRect(x: 0, y: hole.minY, width: hole.minX, height: hole.height))
            blocker(CGRect(x: hole.maxX, y: hole.minY,
                           width: proxy.size.width - hole.maxX, height: hole.height))
        }
    }

    private func blocker(_ rect: CGRect) -> some View {
        Color.clear
            .contentShape(Rectangle())
            // Beides nötig: der Tap schluckt Tipper, die Drag-Geste das Wischen
            // und Scrollen der Liste darunter.
            .onTapGesture {}
            .simultaneousGesture(DragGesture(minimumDistance: 0))
            .frame(width: max(0, rect.width), height: max(0, rect.height))
            .offset(x: rect.minX, y: rect.minY)
            .accessibilityHidden(true)
    }

    /// **Das Loch als messbares Element** — nur im Testlauf.
    ///
    /// Ein Loch ist ein Stück *nicht* gezeichnete Abdunklung; kein Testwerkzeug
    /// kann es sehen, und „sieht falsch aus" ist keine Zahl. Diese durchsichtige
    /// Fläche liegt genau darauf und macht daraus einen Rahmen, den eine Journey
    /// gegen den Rahmen ihres Ziels halten kann. Ohne Berührung, ohne Farbe,
    /// außerhalb des Testlaufs gar nicht erst gebaut.
    @ViewBuilder
    private var holeProbe: some View {
        #if DEBUG
        if UITestSupport.isActive {
            Rectangle()
                // Nicht `Color.clear`: SwiftUI wirft eine Fläche ohne Inhalt
                // aus dem Barrierefreiheits-Baum, und dann misst die Journey
                // nichts. Ein Tausendstel Deckkraft ist unsichtbar und da.
                .fill(Color.black.opacity(0.001))
                .frame(width: max(0, visualHole.width), height: max(0, visualHole.height))
                .offset(x: visualHole.minX, y: visualHole.minY)
                .allowsHitTesting(false)
                .accessibilityElement()
                .accessibilityAddTraits(.isImage)
                .accessibilityLabel("Rundgang-Loch")
                // Der Zustand, an dem ein übersprungener Rahmen hängt, als
                // ablesbarer Wert: Welcher Schritt, hat er gerade ein Ziel,
                // hatte er je eines, ist die Schonfrist um. Ohne das ist ein
                // Rahmen, der sich selbst überspringt, im Testlauf nur eine
                // Abwesenheit — und die sagt nicht, warum.
                .accessibilityValue(
                    "s\(tutorial.index) ziel\(resolvedHole == nil ? 0 : 1) "
                    + "gesehen\(sawTargetFor ?? -1) frist\(graceExpiredFor ?? -1) "
                    + "anker[\(anchorFingerprint)]"
                )
                .accessibilityIdentifier("tutorial.hole")
        }
        #endif
    }

    /// Was gezeichnet wird — nicht was gerade aufgelöst ist. Der Unterschied
    /// ist der gemeldete Ruckler: siehe `SpotlightTransition`.
    private var visualHole: CGRect { shownHole }

    /// Leeres Rechteck heißt: kein Durchlass, der ganze Bildschirm ist tot.
    private var interactiveHole: CGRect {
        guard step.allowsInteraction,
              !tutorial.isVoiceOverRunning,
              let hole = resolvedHole
        else { return .zero }
        return hole
    }

    // MARK: Loch

    private var resolvedHole: CGRect? {
        rawHole.map(clampedToScreen)
    }

    private var rawHole: CGRect? {
        switch step.spotlight {
        case .anchor(let target):
            return rect(for: target)
        case .union(let first, let second):
            switch (rect(for: first), rect(for: second)) {
            case let (a?, b?): return a.union(b)
            case let (a?, nil): return a
            case let (nil, b?): return b
            default: return nil
            }
        case .tabBar:
            return tabBarBand
        case .navBar:
            return navBarBand
        case .nothing:
            return nil
        }
    }

    /// **Das Loch bleibt im Bildschirm** (09.08.).
    ///
    /// Am Bild gemessen: Die Eingabezeile liegt über die volle Breite, mit den
    /// acht Punkten Luft ringsherum wird daraus auf einem 402 pt breiten Gerät
    /// ein Loch von **−16 bis 418** — die zwei runden Ecken links und rechts
    /// liegen außerhalb des Displays. Was man sieht, ist kein hervorgehobenes
    /// Bedienelement mehr, sondern ein Balken, der unten am Rand klebt.
    ///
    /// Beschnitten statt verschoben: Ein Loch, das man in den Bildschirm
    /// *schiebt*, deckt sein Ziel nicht mehr.
    private func clampedToScreen(_ rect: CGRect) -> CGRect {
        // `sm` und nicht `xs`: Die Ecke des Rings hat `Theme.Radius.card`, und
        // vier Punkte Rand lassen davon nichts übrig — am Bild nachgesehen.
        let bounds = CGRect(origin: .zero, size: proxy.size)
            .insetBy(dx: Theme.Spacing.sm, dy: 0)
        let clamped = rect.intersection(bounds)
        return clamped.isNull ? rect : clamped
    }

    /// Wie viel Luft ein Ziel um sich bekommt.
    ///
    /// **Listenzeilen brauchen mehr.** Der Anker sitzt auf dem *Inhalt* der
    /// Zeile; die Zeile selbst legt ihre eigene Polsterung noch einmal
    /// ringsherum — bei den Einstellungen genau die 16 Punkte, die eine
    /// eingerückte Gruppe vorgibt. Mit acht Punkten Luft schnitt das Loch der
    /// Zeile diesen Rand ab: sichtbar am Rundgang-Knopf, dessen antippbare
    /// Fläche unten und an den Seiten aus der Hervorhebung herausragte
    /// (05.08. gemessen, `testTheSettingsFrameHighlightsBothItsTargets`).
    private func halo(for target: TutorialTarget) -> CGFloat {
        switch target {
        case .settingsMarkets, .settingsHelp: Theme.Spacing.lg
        default: Theme.Spacing.sm
        }
    }

    private func rect(for target: TutorialTarget) -> CGRect? {
        guard let anchor = anchors[target] else { return nil }
        let luft = halo(for: target)
        let frame = proxy[anchor].insetBy(dx: -luft, dy: -luft)
        guard frame.width > 0, frame.height > 0 else { return nil }
        // Eine Listenzeile, die knapp aus dem Bild geschoben wurde, meldet ihren
        // Rahmen weiter — nur eben außerhalb. Das ist kein Ziel.
        let visible = CGRect(origin: .zero, size: proxy.size)
        guard visible.contains(CGPoint(x: frame.midX, y: frame.midY)) else { return nil }
        return frame
    }

    /// Band von der Oberkante der Tab-Leiste bis zum unteren Bildschirmrand.
    ///
    /// Die Leiste zeichnet UIKit und trägt keinen Anker; der Nullhöhen-Marker
    /// auf der Unterkante der sicheren Fläche des Tabs ist der einzige Griff,
    /// den SwiftUI darauf hergibt.
    private var tabBarBand: CGRect? {
        // Auf dem iPad steht die Leiste oben oder als Seitenleiste — eine
        // Rechnung über die Unterkante wäre dort schlicht falsch.
        guard sizeClass == .compact, let anchor = anchors[.tabBarTop] else { return nil }
        let top = proxy[anchor].minY
        let height = proxy.size.height - top
        // Plausibilitätsgrenze: Darunter ist das keine Tab-Leiste, sondern ein
        // Messfehler — dann lieber keinen Kreis um nichts ziehen.
        guard height > 40, height < 160 else { return nil }
        // Auf aktuellem iOS schwebt die Leiste als mittige Pille; volle Breite
        // würde links und rechts leeren Hintergrund hervorheben.
        let width = min(proxy.size.width - 2 * Theme.Spacing.md, 480)
        return CGRect(
            x: (proxy.size.width - width) / 2,
            y: top - Theme.Spacing.xs,
            width: width,
            height: height + Theme.Spacing.xs
        )
    }

    /// Band vom oberen Bildschirmrand bis zur Unterkante der Navigationsleiste.
    ///
    /// Dieselbe Not wie bei `tabBarBand`: „Nächste Woche" ist ein `ToolbarItem`
    /// und liegt damit außerhalb des SwiftUI-Baums, aus dem die Anker kommen.
    /// Der Nullhöhen-Marker auf der **Ober**kante der sicheren Fläche des Tabs
    /// ist der einzige Griff darauf.
    ///
    /// **Das Band ist absichtlich die ganze Leiste und nicht der Knopf.** Es
    /// deckt damit Titel und Suchfeld mit ab — genauer geht es von hier aus
    /// nicht, und ein Loch, das nur ungefähr auf dem Knopf säße, wäre nicht
    /// ehrlicher, sondern nur schmaler. Der Kartentext sagt „oben links".
    private var navBarBand: CGRect? {
        guard let anchor = anchors[.navBarBottom] else { return nil }
        let bottom = proxy[anchor].maxY
        // Plausibilitätsgrenze wie unten: Darunter ist das keine Leiste,
        // sondern ein Messfehler. Mit großem Titel **und** Suchfeld wird sie
        // hoch — am 03.08. gemessen, seit der Marker wirklich unter der Leiste
        // sitzt und nicht mehr über ihr.
        guard bottom > 40, bottom < 320 else { return nil }
        let width = proxy.size.width - 2 * Theme.Spacing.md
        return CGRect(
            x: Theme.Spacing.md,
            y: 0,
            width: width,
            height: bottom + Theme.Spacing.xs
        )
    }

    // MARK: Karte

    private enum CardPlacement { case above, below, centred }

    private var gap: CGFloat { Theme.Spacing.lg }

    /// Die sichere Fläche kommt vom **Fenster**, nicht vom Proxy.
    ///
    /// Der GeometryReader des Overlays trägt `ignoresSafeArea` — damit deckt er
    /// den ganzen Bildschirm ab, meldet aber Insets von null. Gerechnet wurde
    /// also die ganze Zeit ohne sie, und bei AX5 stand der Titel unter der
    /// Dynamic Island. Das Fenster weiß es genau; nach UIKit greift die App für
    /// das Erscheinungsbild ohnehin schon (`AppearanceWindowBridge`).
    private var safeArea: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets ?? .zero
    }

    /// Die Karte hat Vorrang vor den Abstandhaltern.
    ///
    /// Ohne ihn teilt sie sich den Platz mit ihnen und wird zusammengedrückt —
    /// bei großen Schriftgraden auf ein Drittel, mit den Knöpfen außerhalb des
    /// Sichtbaren. Über die sichere Fläche hinaus wächst sie trotzdem nicht:
    /// Bei normalen Graden ist sie so hoch wie ihr Inhalt, bei großen genau so
    /// hoch wie `accessibilityCardHeight`.
    private var cardPriority: Double { 1 }

    /// Der Inhalt der Karte bei Barrierefreiheits-Schriftgraden: der ganze
    /// Bildschirm minus sicherer Fläche, minus Luft zu beiden Rändern, minus
    /// der eigenen Polsterung von `themeCard`.
    private var accessibilityCardHeight: CGFloat {
        proxy.size.height - safeArea.top - safeArea.bottom
            - 2 * Theme.Spacing.sm - 2 * Theme.Spacing.lg
    }

    /// Platz über dem Loch, sichere Fläche und Abstände schon abgezogen — und
    /// dazu `sm`, damit die Karte samt Abstandhaltern in den Bildschirm passt
    /// statt ihn um ein paar Punkte zu überziehen.
    /// **Die Karte rechnet mit dem gezeichneten Loch, nicht mit dem gerade
    /// aufgelösten** — seit dem 06.08.
    ///
    /// Das war die Ursache von „die Animationen sind alle nicht flüssig". Das
    /// Loch wandert an *einer* Stelle, nämlich in der Transaktion, in der der
    /// Anker eintrifft (`withAnimation` weiter unten, siehe `shownHole`). Die
    /// Karte hing dagegen an `resolvedHole`, und das ändert sich einen
    /// Layout-Durchgang **später** als `tutorial.index`. Die
    /// `.animation(…, value: tutorial.index)` am Behälter deckt diese Änderung
    /// also nicht ab.
    ///
    /// Ergebnis bei **jedem** Rahmenwechsel: **Das Loch gleitet, die Karte
    /// springt.** Genau das steht schon als Kommentar an `visualHole` („Was
    /// gezeichnet wird — nicht was gerade aufgelöst ist. Der Unterschied ist
    /// der gemeldete Ruckler"); er war nur nie auf die Karte angewandt.
    ///
    /// **`interactiveHole` bleibt bewusst auf `resolvedHole`.** Was man
    /// durchtippen kann, muss dem echten Ziel folgen und nicht der Zeichnung —
    /// sonst landet ein Tipp während des Flugs neben dem Bedienelement.
    private var cardHole: CGRect? {
        let hole = visualHole
        return hole == .zero ? nil : hole
    }

    private var spaceAbove: CGFloat {
        guard let hole = cardHole else { return 0 }
        return hole.minY - safeArea.top - gap - Theme.Spacing.sm
    }

    private var spaceBelow: CGFloat {
        guard let hole = cardHole else { return 0 }
        return bottomLimit - hole.maxY - bottomInset - gap - Theme.Spacing.sm
    }

    /// Was unten belegt ist: die Tastatur, sonst die sichere Fläche. Beides
    /// zugleich gibt es nicht — steht die Tastatur, liegt der Home-Indikator
    /// darunter.
    private var bottomInset: CGFloat {
        keyboardTop == nil ? safeArea.bottom : proxy.size.height - bottomLimit
    }

    private var placement: CardPlacement {
        // Bei Barrierefreiheits-Schriftgraden passt neben dem Loch nichts mehr
        // Sinnvolles hin — die Karte allein braucht dann fast den ganzen
        // Bildschirm. Sie rückt in die Mitte und scrollt; das Loch bleibt
        // sichtbar, nur eben hinter ihr.
        if typeSize.isAccessibilitySize { return .centred }
        guard cardHole != nil else { return .centred }
        return spaceBelow >= spaceAbove ? .below : .above
    }

    @ViewBuilder
    private var cardLayer: some View {
        let hole = cardHole
        VStack(spacing: 0) {
            switch placement {
            case .below:
                // Pinnt die Oberkante der Karte auf `hole.maxY + gap`.
                layoutSpacer(height: (hole?.maxY ?? 0) + gap)
                card()
                    .layoutPriority(cardPriority)
                // Das Overlay ignoriert die sichere Fläche, also muss der
                // Abstand zum Rand hier von Hand zurück — und die Tastatur
                // zählt mit, siehe `bottomInset`.
                layoutSpacer(minLength: bottomInset + Theme.Spacing.sm)
            case .above:
                layoutSpacer(minLength: safeArea.top + Theme.Spacing.sm)
                card()
                    .layoutPriority(cardPriority)
                // Pinnt die Unterkante der Karte auf `hole.minY - gap`, ohne
                // ihre Höhe zu kennen.
                layoutSpacer(height: proxy.size.height - (hole?.minY ?? proxy.size.height) + gap)
            case .centred:
                layoutSpacer(minLength: safeArea.top + Theme.Spacing.sm)
                card()
                    .layoutPriority(cardPriority)
                layoutSpacer(minLength: bottomInset + Theme.Spacing.sm)
            }
        }
        .frame(width: proxy.size.width, height: proxy.size.height)
    }

    /// Abstandhalter dieser Ebene liegen teils über dem Loch. Sie fangen von
    /// sich aus nichts ab — hier steht es trotzdem, weil ein durchlässiges Loch
    /// die eine Sache ist, die kein Blick auf den Bildschirm verrät.
    private func layoutSpacer(minLength: CGFloat = 0, height: CGFloat? = nil) -> some View {
        Spacer(minLength: minLength)
            .frame(height: height)
            .allowsHitTesting(false)
    }

    private func card() -> some View {
        // Zwei klare Fälle statt eines Automatismus: Bei normalen Schriftgraden
        // ist die Karte so hoch wie ihr Inhalt, bei Barrierefreiheits-Graden
        // genau so hoch wie der Platz zwischen den sicheren Flächen — und dann
        // scrollt sie. `ViewThatFits` hat hier den zu hohen Zweig genommen und
        // `frame(maxHeight:)` die gierige Scroll-Ansicht nicht gebunden; beides
        // endete mit dem Titel unter der Dynamic Island.
        Group {
            if typeSize.isAccessibilitySize {
                // Feste Höhe, nicht `maxHeight`: Ein Deckel hat die gierige
                // Scroll-Ansicht mehrfach nicht gebunden — mal stand der Titel
                // unter der Dynamic Island, mal hing „Tour beenden" unter dem
                // Bildschirmrand. Ausgerechnet passt sie immer.
                ScrollView { cardStack }
                    .frame(height: accessibilityCardHeight)
                    .scrollBounceBehavior(.basedOnSize)
            } else {
                cardStack
            }
        }
        .themeCard()
        .readableWidth()
        .padding(.horizontal, Theme.Spacing.lg)
    }

    /// **Zwei Zeilen statt drei** (09.08.). Die Punkte standen als eigene Reihe
    /// zwischen Text und Knöpfen und kosteten mit ihren Abständen rund 30 pt für
    /// sieben Punkt Höhe. Sie stehen jetzt neben dem Ausgang — dieselbe Reihe,
    /// dieselbe Aussage, eine Zeile weniger auf einer Karte, die vor dem Ziel
    /// liegt, über das sie redet.
    private var cardStack: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            textBlock
            HStack(spacing: Theme.Spacing.md) {
                stepDots
                controls
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(step.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(step.text)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Ein Element mit einem ganzen Satz — dieselbe Regel wie bei der
        // Plan-Karte und der Vorschlagskachel.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Schritt \(tutorial.index + 1) von \(tutorial.stepCount): \(step.title). \(step.text)"
        )
        .accessibilityFocused($cardFocused)
        // Der Bezeichner gehört auf dieses eine Element, nicht auf die Karte:
        // Auf dem Container gesetzt, erbt ihn **jedes** Kind und überschreibt
        // dabei `tutorial.next` und `tutorial.skip` — dann findet die Journey
        // ihre eigenen Knöpfe nicht mehr.
        .accessibilityIdentifier("tutorial.card")
    }

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<tutorial.stepCount, id: \.self) { index in
                Circle()
                    .fill(index == tutorial.index ? Theme.accent : Theme.stroke)
                    .frame(width: 7, height: 7)
            }
        }
        // Nicht antippbar und im Baum nur Lärm — die Schrittzahl steht im Label
        // der Karte. Der Audit meldet genau solche Punkte sonst unter `hitRegion`.
        .accessibilityHidden(true)
    }

    /// **Ein Knopf je Rahmen.**
    ///
    /// Auf einem Rahmen, der auf eine Handlung wartet, ist es „Tour beenden" —
    /// die eine echte Wahl, die es dort gibt. Auf der Schlusskarte ist es
    /// „Fertig", und beide rufen dasselbe (`finish()`); zwei Knöpfe
    /// nebeneinander, die dasselbe tun, lesen sich als Entscheidung, die keine
    /// ist (gemeldet am 2026-07-30).
    private var controls: some View {
        HStack(spacing: Theme.Spacing.md) {
            Spacer(minLength: 0)

            if step.deed != .reads {
                Button {
                    // **Der Ausgang war eine Ecke, kein Übergang** (06.08.).
                    // `ContentView` legt `.transition(.opacity)` auf das
                    // Overlay — aber eine Transition spielt nur, wenn die
                    // Zustandsänderung, die die Ansicht entfernt, **in** einer
                    // animierten Transaktion passiert. `skip()` und `next()`
                    // waren nackte Aufrufe, `TutorialStore.finish()` setzt
                    // `isRunning = false` ohne `withAnimation`, und nichts sonst
                    // führt eine Kurve auf diesen Wert. Abdunklung, Ring, Karte
                    // und Sperrflächen verschwanden also **in einem Bild** —
                    // Scotts „it ends with a weird jump".
                    //
                    // Dass der *Anfang* weich aussah, war ein Zufall: Beim Start
                    // aus dem Onboarding kippt im selben Durchgang
                    // `isOnboardingComplete`, und dessen `.stateAnimation` in
                    // `ContentView` deckte den Baum mit ab. Aus den Einstellungen
                    // heraus poppte das Overlay auch beim Aufgehen.
                    withAnimation(Theme.Motion.screen.animation(reduceMotion: reduceMotion)) {
                        tutorial.skip()
                    }
                } label: {
                    Text("Tour beenden")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .frame(minHeight: 44)
                }
                .buttonStyle(TactileButtonStyle())
                .accessibilityIdentifier("tutorial.skip")
            }

            // **„Weiter" gibt es nur noch auf der Schlusskarte, und dort heißt
            // es „Fertig".** Das ist der Prinzipwechsel in einer Zeile: Solange
            // ein Rahmen eine Handlung erwartet, hat er keinen Knopf, der sie
            // überspringt — sonst wäre der Rundgang genau wieder das, was er
            // war, nur mit einem Hinweis mehr. Der Bezeichner bleibt
            // `tutorial.next`, damit die Journeys ihren Ausgang behalten.
            if step.deed == .reads {
                Button {
                    // Derselbe Grund wie beim Abbruch darüber: Hier ist der
                    // Knopf der Ausgang, und der muss durch eine animierte
                    // Transaktion laufen.
                    withAnimation(Theme.Motion.screen.animation(reduceMotion: reduceMotion)) {
                        tutorial.next()
                    }
                } label: {
                    Text("Fertig")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .frame(minHeight: 44)
                        .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(TactileButtonStyle())
                .accessibilityIdentifier("tutorial.next")
            }
        }
    }
}
