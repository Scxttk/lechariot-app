import SwiftUI

/// **Die Kette als eigenes Zeichen — statt ihres Logos.**
///
/// Scotts Frage vom 06.08.: „welche märkte magst du, can we use the logo of the
/// markets, just a question."
///
/// **Rechtlich ginge es.** Ein Kettenlogo zu zeigen, um auf den echten Laden
/// hinzuweisen, ist referierender Gebrauch und zulässig, solange kein Eindruck
/// einer Geschäftsbeziehung entsteht — das ist der Grund, warum
/// Preisvergleichsseiten es dürfen.
///
/// **Praktisch kostet es mehr, als es aussieht, und zwar an der Stelle, an der
/// diese Runde gerade gearbeitet hat.** Neun Ketten heißen neun Logodateien, je
/// zwei Farbfassungen für hell und dunkel — und **jedes Logo bringt seine
/// eigene Hausfarbe mit**. Lidls Blau-Gelb-Rot, Kauflands Rot, Nettos Gelb und
/// ALDIs Blau auf einer Seite: Das ist genau das Gegenteil dessen, was die
/// Farbrunde am 06.08. erreicht hat, nämlich dass **ein** Grün führt. Dazu
/// kommt die Pflege: Ein Rebranding einer Kette ist eine Datei, die jemand
/// nachziehen muss, und niemand merkt es, wenn es nicht passiert.
///
/// **Das hier ist der Gegenvorschlag, damit er sich ansehen lässt statt
/// vorgestellt werden zu müssen:** das Monogramm der Kette, in unserer Hand
/// gesetzt. Kein Kasten darum — das wäre der Container, den diese Runde
/// überall sonst abgeräumt hat —, sondern Type auf der Fläche, in der
/// Markenfarbe, auf fester Breite, damit die Zeilen eine Kante bilden.
///
/// Wiedererkennung ohne fremde Farben, ohne Pflegelast, ohne Rechtsfrage. Ob es
/// **genug** Wiedererkennung ist, entscheidet das Auge — deshalb steht es jetzt
/// da.
struct ChainMark: View {
    let chain: String
    var size: CGFloat = 34

    /// Ein oder zwei Buchstaben, und die Regel dafür ist beobachtet, nicht
    /// gewählt: „ALDI Nord" und „ALDI Süd" unterscheiden sich erst im zweiten
    /// Wort, „Lidl" und „Kaufland" schon im ersten Buchstaben. Wo ein zweites
    /// Wort steht, trägt es mit — sonst wären zwei Ketten dasselbe Zeichen.
    private var monogram: String {
        let woerter = chain
            .split(whereSeparator: { $0 == " " || $0 == "-" })
            .map(String.init)
        guard let erstes = woerter.first?.first else { return "?" }
        if woerter.count > 1, let zweites = woerter[1].first {
            return "\(erstes)\(zweites)".uppercased()
        }
        return String(erstes).uppercased()
    }

    var body: some View {
        Text(monogram)
            // Versalien mit Sperrung: dieselbe Stimme wie „AM BESTEN ZU" auf
            // der Plan-Karte — die Emailschild-Stimme der App.
            .font(.system(size: size * 0.44, weight: .semibold, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(Theme.accent)
            .frame(width: size, alignment: .leading)
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 14) {
        ForEach(["ALDI Nord", "ALDI Süd", "Lidl", "Kaufland", "Netto", "Penny", "REWE", "EDEKA", "NORMA"], id: \.self) { chain in
            HStack(spacing: 12) {
                ChainMark(chain: chain)
                Text(chain)
            }
        }
    }
    .padding()
    .background(Theme.background)
}
