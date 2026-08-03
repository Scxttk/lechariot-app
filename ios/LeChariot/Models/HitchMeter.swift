import Foundation

/// **Was „es ruckelt" in Zahlen heißt.**
///
/// Scotts Meldung aus Build `2026.0801.1951` hatte keinen Ort und keine Zahl.
/// Das Simulator-Geschirr (`tools/perf.sh`) fängt Regressionen, aber es sieht
/// **kein thermisches Drosseln, keinen leeren Akku, kein älteres Gerät** — wo
/// das Ruckeln wirklich passiert, kann nur das iPhone messen.
///
/// Diese Rechnung ist der Kern der Anzeige, und sie ist bewusst pur: Sie kennt
/// keinen `CADisplayLink`, nur Zahlen. So ist jede Regel prüfbar, ohne dass
/// irgendwo ein Bild gezeichnet werden muss.
///
/// **Ein Ruckler ist nicht „ein langsames Bild", sondern die Zeit, die ein Bild
/// zu spät kam.** Apple rechnet in Millisekunden Ruckelzeit je Sekunde
/// Laufzeit; dieselbe Einheit steht in MetricKits `scrollHitchTimeRatio`, damit
/// die Live-Anzeige und der Tagesbericht dieselbe Sprache sprechen.
struct HitchMeter {
    struct Sample: Equatable {
        /// Wie lange dieses Bild wirklich stand.
        let duration: Double
        /// Wie lange es hätte stehen dürfen (1/120 s bei ProMotion).
        let expected: Double
    }

    /// Wie weit zurück gerechnet wird. Eine Sekunde ist kurz genug, dass die
    /// Anzeige auf ein Ruckeln reagiert, während man es noch sieht.
    var window: Double = 1.0

    private(set) var samples: [Sample] = []

    /// Die Zeit, die ein Bild **zu spät** kam. Nie negativ: Ein Bild, das
    /// schneller fertig war, gleicht kein vorheriges Ruckeln aus — dieser
    /// Fehler macht aus einer ruckeligen Strecke mit einem schnellen Stück eine
    /// glatte.
    static func hitchTime(duration: Double, expected: Double) -> Double {
        max(0, duration - expected)
    }

    mutating func record(duration: Double, expected: Double) {
        samples.append(Sample(duration: duration, expected: expected))
        // Nur die letzte Sekunde behalten: von vorn wegwerfen, solange der Rest
        // das Fenster noch **überschreitet**.
        //
        // Streng größer, und das ist kein Geschmack. Mit `>=` hing die Regel an
        // einem Gleitkomma-Rest: 120 Bilder zu je 1/120 s summieren sich auf
        // 0,999999999999 — knapp *unter* einer Sekunde. Ein 0,5-s-Ruckler von
        // davor blieb damit stehen und meldete 328 ms/s Ruckelzeit auf einer
        // Strecke, die glatt lief. Gefunden von
        // `testTheWindowForgetsWhatIsOlderThanASecond`.
        var total = elapsed
        while samples.count > 1, total > window {
            total -= samples[0].duration
            samples.removeFirst()
        }
    }

    var elapsed: Double { samples.reduce(0) { $0 + $1.duration } }

    /// Bilder je Sekunde. Nil, solange noch nichts gemessen wurde — eine 0 wäre
    /// eine Aussage, und „noch nichts" ist keine.
    var fps: Double? {
        guard elapsed > 0 else { return nil }
        return Double(samples.count) / elapsed
    }

    /// Millisekunden Ruckelzeit je Sekunde — dieselbe Einheit wie MetricKits
    /// `scrollHitchTimeRatio`.
    var hitchMillisecondsPerSecond: Double? {
        guard elapsed > 0 else { return nil }
        let hitch = samples.reduce(0) { $0 + Self.hitchTime(duration: $1.duration, expected: $1.expected) }
        return hitch / elapsed * 1000
    }

    /// Apples Schwelle für „das fällt auf": mehr als 5 ms Ruckelzeit je
    /// Sekunde gilt in den MetricKit-Richtlinien als spürbar.
    static let noticeableHitchMsPerSecond = 5.0

    var isNoticeable: Bool {
        (hitchMillisecondsPerSecond ?? 0) > Self.noticeableHitchMsPerSecond
    }
}
