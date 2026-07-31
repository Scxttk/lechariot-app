import Foundation

/// The words an item's detail line can be built from.
///
/// **A vocabulary, not a text field.** Scott's decision from 2026-07-31, and it
/// buys two things at once. For the person: tapping is faster than typing at
/// the moment you are already holding the phone in one hand. For the app: the
/// detail can never contain something that has to be filtered before it is
/// shown, logged, or stored — there is nothing to sanitise, because there is
/// nothing to type.
///
/// Bring!'s "Details zu Milch" sheet is the model: amount, packaging, fat
/// content, kind, and only then free text. We take the first four and leave the
/// free text out.
///
/// **None of this reaches the matcher.** Some of the words (`Bio`, `Hafer`,
/// `Soja`, `1 l`) also exist in the dictionary, which makes the temptation to
/// feed them into the query real — and "Bio" as a fourth search word breaks the
/// AND exactly the way "Landliebe" would. Feeding the vocabulary into matching
/// would be its own decision with its own evidence.
enum ItemDetailVocabulary {

    /// One row of chips.
    ///
    /// - Parameter exclusive: only one chip of this group can be chosen. Two
    ///   amounts or two pack sizes at once say nothing anybody could act on in
    ///   a shop; two kinds ("Bio", "laktosefrei") say something perfectly
    ///   sensible.
    struct Group: Identifiable, Equatable {
        let title: String
        let chips: [String]
        let exclusive: Bool
        var id: String { title }
    }

    static let groups: [Group] = [
        Group(title: "Menge", chips: ["1", "2", "3", "4", "6", "12"], exclusive: true),
        Group(title: "Größe", chips: ["klein", "groß", "250 g", "500 g", "1 kg", "1 l"], exclusive: true),
        Group(
            title: "Art",
            chips: ["Bio", "laktosefrei", "glutenfrei", "vegan", "Hafer", "Soja", "Mandel"],
            exclusive: false
        ),
    ]

    /// Every chip, in the order the sheet shows them. The detail line follows
    /// this order too — see `toggling`.
    static let allChips: [String] = groups.flatMap(\.chips)

    /// The group a chip belongs to, or nil for a word that is no longer in the
    /// vocabulary.
    ///
    /// Old lists can carry such a word: the vocabulary is allowed to change,
    /// and a detail written last month is still a true note about what somebody
    /// wanted. It stays on the item and stays removable — it just no longer has
    /// a chip to sit under.
    static func group(of chip: String) -> Group? {
        groups.first { $0.chips.contains(chip) }
    }

    /// The detail after tapping `chip`.
    ///
    /// Three rules, and the reason they live here rather than in the sheet is
    /// that all three are invisible in the result: you see which chips are on,
    /// never why the one you did not touch went off.
    ///
    /// 1. Tapping a chosen chip removes it — the same tap undoes itself.
    /// 2. In an exclusive group the new chip replaces its sibling, rather than
    ///    being refused. Somebody correcting "500 g" to "1 kg" taps the one
    ///    they want, not the one they no longer want.
    /// 3. The result keeps **vocabulary order**, not tap order, so the line
    ///    under the item reads "2 · 1 l · Bio" whichever way round it was
    ///    chosen. A line that reshuffles itself looks like a bug.
    ///
    /// Words that are no longer in the vocabulary keep their relative order and
    /// go last.
    static func toggling(_ chip: String, in detail: [String]) -> [String] {
        var chosen = Set(detail)
        if chosen.contains(chip) {
            chosen.remove(chip)
        } else {
            if let group = group(of: chip), group.exclusive {
                chosen.subtract(group.chips)
            }
            chosen.insert(chip)
        }
        let known = allChips.filter { chosen.contains($0) }
        let unknown = detail.filter { chosen.contains($0) && !allChips.contains($0) }
        return known + unknown
    }
}
