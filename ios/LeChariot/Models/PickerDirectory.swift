import Foundation

/// What the branch picker actually has to decide once the user keeps more than
/// one region: **which postcode a store belongs to**.
///
/// The picker searches around every ready region and used to throw the results
/// into one pot, keeping the smaller distance whenever a store turned up twice.
/// For neighbouring postcodes — the case the feature was built for — that is
/// off by a kilometre and harmless. For two homes 450 km apart it produces a
/// list in which every row is measured from a different point and they are all
/// sorted together: "Penny Gößnitz · 7,6 km" above "Penny Am Haff · 22 km",
/// while standing in Ahlbeck. Reported 2026-07-30.
///
/// Two things follow from remembering the anchor instead of averaging it away,
/// and the second one is the reason this type exists at all:
///
/// 1. Every distance can name the postcode it was measured from.
/// 2. **"Nobody has fetched this area yet" becomes a per-region question.** Six
///    of the eight chains are only in the directory where somebody asked, and
///    the check for that is "everything in reach is Kaufland or Penny". Run
///    over the merged pot it is answered by whichever region happens to be the
///    best-stocked: one fetched region made every further one look complete, so
///    the request never went out and the area stayed empty **forever**. Run per
///    region, each one asks for itself.
///
/// Pure on purpose — this was private inside the View, which is why neither
/// failure had a test.
enum PickerDirectory {
    /// What one region's search came back with.
    struct RegionFind {
        let plz: String
        let lat: Double
        let lon: Double
        let branches: [Branch]
    }

    /// One selectable store, with the region it belongs to.
    struct Entry: Identifiable {
        let branch: Branch
        let anchorPLZ: String
        /// Distance from that region's centre. `nil` for a row without
        /// coordinates — kept, because a store whose position we don't know is
        /// still a store, and sorted last by the caller.
        ///
        /// Only the fallback: with location access the picker measures from
        /// where the phone actually is and recomputes from `branch`.
        let distanceKm: Double?

        var market: Market { branch.asMarket }
        var address: String { branch.addressLine }
        var id: String { branch.marketId }
    }

    /// A region whose directory has never been fetched, plus the stores the
    /// request can be anchored on.
    struct AreaCandidate {
        let plz: String
        /// **Die Mitte der Region**, um die gesucht wurde — das, was seit v21
        /// mitgeht, und der eigentliche Inhalt dieser Korrektur.
        ///
        /// Bis zum 2026-07-30 wurde hier nur der Anker weitergereicht, und das
        /// Backend schlug die PLZ aus *dessen* `branches`-Zeile nach. In
        /// Ahlbeck (17419) ist die nächste bekannte Filiale Penny Am Haff in
        /// Ueckermünde (17373), 24,5 km über das Haff — der Verzeichnislauf
        /// ging für die falsche Stadt raus und meldete Erfolg.
        ///
        /// Nicht die Geräteposition: Die gibt es ohne Ortungsfreigabe nicht,
        /// und der Picker fragt bewusst nicht ungefragt danach. Die
        /// Regionsmitte ist genau der Punkt, um den hier tatsächlich gesucht
        /// wurde, und sie steht immer zur Verfügung.
        let lat: Double
        let lon: Double
        /// Die nächstgelegene Filiale — der Existenzbeweis für diesen Ort.
        ///
        /// Wieder genau eine: Bis Migration v22 war `market_id` der
        /// Primärschlüssel von `area_requests`, weshalb die App bis zu drei
        /// Ausweich-Anker mitgab. Seit v22 ist der Schlüssel die Rasterzelle,
        /// und ein Anker kann Zeilen für mehrere Orte tragen.
        let anchor: Branch
    }

    struct Plan {
        let entries: [Entry]
        let areaCandidates: [AreaCandidate]

        /// Keyed for the row lookups, which happen once per redraw per row.
        let byMarketId: [String: Entry]

        init(entries: [Entry], areaCandidates: [AreaCandidate]) {
            self.entries = entries
            self.areaCandidates = areaCandidates
            self.byMarketId = Dictionary(
                entries.map { ($0.branch.marketId, $0) }, uniquingKeysWith: { first, _ in first }
            )
        }
    }

    /// Assigns every store to exactly one region and works out which regions
    /// still need fetching.
    ///
    /// `finds` is expected in the order the picker wants to show them; ties
    /// (the same store equally far from two regions) go to the earlier one, so
    /// the result does not depend on dictionary ordering.
    static func plan(_ finds: [RegionFind]) -> Plan {
        var best: [String: Entry] = [:]
        var candidates: [AreaCandidate] = []

        for find in finds {
            var nearestHere: [(branch: Branch, distance: Double)] = []

            for branch in find.branches {
                let distance = branch.distanceKm(from: find.lat, find.lon)

                if let distance {
                    nearestHere.append((branch, distance))
                }

                // The same store around two neighbouring postcodes: it belongs
                // to the one it is actually closer to. A row without
                // coordinates loses against any row that has them.
                if let existing = best[branch.marketId] {
                    let existingDistance = existing.distanceKm ?? .greatestFiniteMagnitude
                    guard let distance, distance < existingDistance else { continue }
                }

                best[branch.marketId] = Entry(
                    branch: branch,
                    anchorPLZ: find.plz,
                    distanceKm: distance
                )
            }

            // Asked per region, not once over everything — see the type's note.
            if AreaRequestStore.areaLooksUnfetched(find.branches), !nearestHere.isEmpty {
                // Stabil sortiert: Bei gleicher Entfernung entscheidet die
                // market_id, sonst hinge die Anker-Reihenfolge an der Laune der
                // Verzeichnisantwort — und damit auch, welche Zeile in
                // `area_requests` entsteht.
                let nearest = nearestHere
                    .min { ($0.distance, $0.branch.marketId) < ($1.distance, $1.branch.marketId) }
                if let nearest {
                    candidates.append(
                        AreaCandidate(plz: find.plz, lat: find.lat, lon: find.lon, anchor: nearest.branch)
                    )
                }
            }
        }

        return Plan(entries: Array(best.values), areaCandidates: candidates)
    }
}
