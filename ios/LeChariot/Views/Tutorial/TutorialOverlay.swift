import SwiftUI

/// The tour itself: a scrim over the whole app with a hole cut around exactly
/// one control, and a card that says what that control does.
///
/// Everything outside the hole is inert — that is the point. Testers who opened
/// the app after onboarding did not know where to start, and a tour that leaves
/// the whole screen live is just a tooltip they can tap past by accident.
///
/// Two frames are hands-on: the hole passes touches so the tester can actually
/// type and tap. They still wait for "Weiter" like every other frame — see
/// `TutorialStep.allowsInteraction`. The rest only explain.
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

    private var step: TutorialStep { tutorial.step }

    var body: some View {
        ZStack(alignment: .topLeading) {
            scrim
            blockers
            cardLayer
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
            moveHoleIfNeeded()
        }
        .onChange(of: tutorial.index) { _, _ in
            enterStep()
            // Beim Schrittwechsel steht der neue Anker meist noch nicht da.
            // Dann tut das hier nichts, und das Loch bleibt liegen, bis der
            // Anker unten eintrifft — statt in die Ecke zu fliegen.
            moveHoleIfNeeded()
        }
        .onChange(of: resolvedHole) { _, _ in moveHoleIfNeeded() }
        .task(id: tutorial.index) {
            let index = tutorial.index
            try? await Task.sleep(for: Self.anchorGrace)
            guard !Task.isCancelled else { return }
            graceExpiredFor = index
        }
        .onChange(of: graceExpiredFor) { _, _ in skipIfNothingToShow() }
        // Zweiter Auslöser: Ein Anker, der nach Ablauf der Schonfrist wieder
        // verschwindet, darf den Rundgang nicht anhalten.
        .onChange(of: anchorFingerprint) { _, _ in skipIfNothingToShow() }
    }

    // MARK: Ablauf

    private func enterStep() {
        if step.seedsDemoItems {
            tutorial.seedDemoItems(into: list)
        }
        cardFocused = true
    }

    /// Kein Ziel auf dem Bildschirm — etwa die Karte bei einem Tester, in dessen
    /// Gegend diese Woche nichts passt. Dann geht der Rundgang weiter, statt vor
    /// einem Loch ins Leere stehen zu bleiben.
    private func skipIfNothingToShow() {
        guard graceExpiredFor == tutorial.index, resolvedHole == nil else { return }
        tutorial.next()
    }

    /// Zieht das gezeichnete Loch nach, wenn `SpotlightTransition` etwas zu
    /// tun sieht. Geflogen wird nur der Schrittwechsel; ein Ziel, das sich an
    /// Ort und Stelle verschiebt (Tastatur, Umbau darunter), wird sofort
    /// übernommen.
    private func moveHoleIfNeeded() {
        guard let move = SpotlightTransition.move(
            shown: shownHole, shownIndex: shownIndex,
            resolved: resolvedHole, index: tutorial.index
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
        }
    }

    private func rect(for target: TutorialTarget) -> CGRect? {
        guard let anchor = anchors[target] else { return nil }
        let frame = proxy[anchor].insetBy(dx: -Theme.Spacing.sm, dy: -Theme.Spacing.sm)
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
    private var spaceAbove: CGFloat {
        guard let hole = resolvedHole else { return 0 }
        return hole.minY - safeArea.top - gap - Theme.Spacing.sm
    }

    private var spaceBelow: CGFloat {
        guard let hole = resolvedHole else { return 0 }
        return proxy.size.height - hole.maxY - safeArea.bottom
            - gap - Theme.Spacing.sm
    }

    private var placement: CardPlacement {
        // Bei Barrierefreiheits-Schriftgraden passt neben dem Loch nichts mehr
        // Sinnvolles hin — die Karte allein braucht dann fast den ganzen
        // Bildschirm. Sie rückt in die Mitte und scrollt; das Loch bleibt
        // sichtbar, nur eben hinter ihr.
        if typeSize.isAccessibilitySize { return .centred }
        guard resolvedHole != nil else { return .centred }
        return spaceBelow >= spaceAbove ? .below : .above
    }

    @ViewBuilder
    private var cardLayer: some View {
        let hole = resolvedHole
        VStack(spacing: 0) {
            switch placement {
            case .below:
                // Pinnt die Oberkante der Karte auf `hole.maxY + gap`.
                layoutSpacer(height: (hole?.maxY ?? 0) + gap)
                card()
                    .layoutPriority(cardPriority)
                // Das Overlay ignoriert die sichere Fläche, also muss der
                // Abstand zum Rand hier von Hand zurück.
                layoutSpacer(minLength: safeArea.bottom + Theme.Spacing.sm)
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
                layoutSpacer(minLength: safeArea.bottom + Theme.Spacing.sm)
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

    private var cardStack: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            textBlock
            stepDots
            controls
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

    private var controls: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Auf dem letzten Rahmen heißt der Primärknopf „Fertig" und tut
            // dasselbe wie der Abbruch — beide rufen `finish()`. Zwei Knöpfe
            // nebeneinander, die dasselbe tun, lesen sich als Entscheidung, die
            // keine ist; gemeldet am 2026-07-30. Der Abbruch bleibt auf jedem
            // Rahmen davor, denn dort ist er eine echte Wahl.
            if !tutorial.isLastStep {
                Button {
                    tutorial.skip()
                } label: {
                    Text("Tour beenden")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .frame(minHeight: 44)
                }
                .buttonStyle(TactileButtonStyle())
                .accessibilityIdentifier("tutorial.skip")
            }

            Spacer(minLength: 0)

            Button {
                tutorial.next()
            } label: {
                Text(tutorial.isLastStep ? "Fertig" : "Weiter")
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
