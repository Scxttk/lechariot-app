# Shipping a TestFlight build

## Erst nachsehen, dann raten

```bash
tools/asc-builds.sh    # nur lesend: Builds + Zertifikate aus App Store Connect
```

**Der Satz „ob der Build die Verarbeitung übersteht, ist von hier aus nicht
prüfbar" stand seit dem 31.07. in jedem Rundenbericht — und er war falsch.**
Derselbe API-Schlüssel, der zum Hochladen nicht reicht, darf lesen. Am 03.08.
hat der erste Aufruf in einem Zug bestätigt, dass **alle zehn** bis dahin
unbestätigten Builds `VALID` sind, `2026.0803.1440` eingeschlossen.

Der zweite Abschnitt sagt, woran der Upload hängt. Am 03.08.: **kein einziges
Vertriebszertifikat im Konto** — zwei Entwicklungs- und ein Developer-ID-Zertifikat,
sonst nichts. Das ist kein verlorenes Zertifikat, sondern ein nie ausgestelltes;
deshalb ist der Haken *„Zugriff auf cloud-verwaltete Vertriebszertifikate"* beim
Schlüssel der eigentliche Weg und keine Abkürzung.


`tools/release.sh` builds a distribution-signed `.ipa`. Everything below it in
this file is the part Apple insists a human does.

```
tools/release.sh              # archive + .ipa
tools/release.sh --upload     # and upload it, with an App Store Connect API key
```

The script refuses to run on a dirty working tree, and refuses to run without a
filled-in `APIKeys.plist` — without real keys `APIConfig.isConfigured` is false
and the app quietly serves mock offers, which nobody would recognise as a fault
on a real phone.

**Signing is proven, and so is uploading.** The archive-and-export path produces
a genuinely App-Store-signed `.ipa` — `Apple Distribution: Scott Koehler
(3DZ9T8SGX5)`, chained to Apple WWDR, with a store profile and
`get-task-allow: false`. Verified on the unpacked artifact.

`--upload` works too, and has since an Apple ID was added to Xcode. It was first
walked end to end on 2026-07-31 with build `0.1.0 (2026.0731.2046)`, which went
up without a prompt, and again on 2026-08-01.

**How it authenticates:** the script uses the three `ASC_*` variables if all of
them are set, and otherwise falls back to the Apple ID signed into Xcode,
printing `Kein API-Schlüssel gesetzt` when it does. There is no `.p8` on this Mac
today, so the fallback *is* the live path. An API key is only needed where nobody
is signed in — that is, CI.

If an upload ever does fail, the signed `.ipa` is already in `build/export/` and
goes out through Xcode → Organizer → Distribute App. That is a failed upload, not
a failed build.

> **This section used to say the opposite** — that uploading was "a different
> door, and it is shut", because `DVTDeveloperAccountManagerAppleIDLists` was
> empty and the step died with `IDEDistributionUploadAccountStep: "Failed to Use
> Accounts"`. That was true when written and stopped being true the moment an
> account was added. It is recorded rather than deleted because the failure mode
> is worth recognising if it returns: an empty account list *also* reports
> `missingApp(bundleId: "com.skoehler.lechariot")`, which reads like a missing
> App Store Connect record and is not one. The giveaway in the same log is
> `App Store Connect team IDs for account (null) are ()` — an empty team list
> from a session that does not exist.

## Version and build number

`MARKETING_VERSION` lives in `ios/project.yml` and is the number testers see.
The build number is a UTC timestamp, `YYYY.MMDD.hhmm`, set at archive time —
never written into `project.yml`, where `xcodegen generate` would reset it.

It used to be the commit count, which read nicely and broke on first contact
with a squash merge: thirteen commits collapsed into one, the count fell from 85
to 76, and App Store Connect requires the build number to *rise* within a
version. Any history rewrite does that. A clock cannot go backwards, so the
timestamp is the number and the commit hash in the script's output says which
code it was.

So: raise `MARKETING_VERSION` by hand when a release means something, and never
touch the build number.

## One-time setup

None of this is in the repo, because none of it can be.

0. **An Apple ID in Xcode** — Xcode → Settings → Accounts, team `3DZ9T8SGX5`.
   It needs a password and a two-factor code, so it is yours and cannot be
   scripted.

   ⚠️ **This is not a one-time step, and the note here used to claim it was.**
   On 2026-08-02 the account list was empty and `Apple Distribution: Scott
   Koehler (3DZ9T8SGX5)` was gone from both keychains; the run died with `No
   Accounts: Add a new account in Accounts settings.` The day before, the same
   command had uploaded a build. In between: the Xcode update to 26.3. The
   store provisioning profile survived (valid to 2027-07-30) — only the
   certificate and the session were gone, and Xcode re-issued the certificate
   by itself once the account was back.

   The old note also said signing never depended on the account. That was
   wrong in the case that matters: without an account there is no distribution
   certificate to sign *with*. **Step 2 is the way out of this whole class.**

1. **App record.** appstoreconnect.apple.com → Apps → +, platform iOS, bundle ID
   `com.skoehler.lechariot`, primary language German. The App ID is already
   registered on the developer portal, and the distribution certificate plus the
   store provisioning profile exist — nothing has to be clicked for signing.

2. **API key** — the fix for step 0. A key is a file; it survives Xcode
   updates, and `--upload` then never asks who is logged in.

   App Store Connect → Users and Access → Integrations → App Store Connect API
   → Team Keys → **+**, name it (`Le Chariot Upload`), role **App Manager**.
   Copy the **Issuer ID** shown above the key list — it is not in the file and
   cannot be derived. **The `.p8` downloads exactly once**, so put it away
   before closing the tab:

   ```bash
   mkdir -p ~/.appstoreconnect/private_keys && chmod 700 ~/.appstoreconnect/private_keys
   mv ~/Downloads/AuthKey_*.p8 ~/.appstoreconnect/private_keys/
   chmod 600 ~/.appstoreconnect/private_keys/AuthKey_*.p8
   echo 'export ASC_ISSUER_ID=<Issuer-ID>' > ~/.config/lechariot/asc-env
   ```

   That is all. `release.sh` finds the key itself: exactly one `AuthKey_*.p8`
   in that directory, key id read from the filename (Apple's own naming rule),
   issuer id from `~/.config/lechariot/asc-env`. Two keys in the directory and
   it refuses to guess; a key without an issuer id and it says so instead of
   silently falling back. Environment variables still win if they are set.

   Nothing of this goes in the repo. `~/.config/lechariot/env` holds the
   backend credentials; the issuer id gets its own file next to it so a
   backend run never has to source app-release settings.

3. **Privacy answers.** App Store Connect asks the same questions the privacy
   manifest answers, and the two have to agree.
   `ios/LeChariot/Resources/PrivacyInfo.xcprivacy` is the reference; its header
   comment says which table each declaration comes from. Summary: a random
   per-install id, postcode and branch ids, the search word and free-text
   comment from a match report, plus household size, weekly trips, budget
   bracket and diet tags. No name, no shopping list, no device identifier, no
   tracking, nothing sold on.

   One call in there is worth knowing you made: every declaration says *not
   linked to the user's identity*. That is accurate — there is no account, the
   install id is random, and the first name never leaves the phone — but the
   combination of postcode, branch ids, household size and diet is not nothing.
   If that ever feels too thin, flipping the `Linked` booleans to true is the
   conservative direction and costs only a worse-looking privacy label.

## Internal or external testers

Internal testers skip Beta App Review, but each one has to be a user on the App
Store Connect account. That works for you and nobody else.

External testers get a public link, which is the point — and that needs Beta App
Review once per version, with a review note explaining what the app does and how
to reach something worth seeing. A reviewer who never picks a branch sees a
shopping list with no prices, so say in the note which postcode to enter
(Dresden, `01219`) and where the branches are chosen.

Export compliance is already answered in the Info.plist
(`ITSAppUsesNonExemptEncryption = false` — HTTPS only, standard exemption), so
builds do not sit blocked on that question.

### The review note

The reviewer is usually not in Germany, and that is the whole problem. Offers
exist only for postcodes somebody has requested, and branch data is fetched per
area — so a reviewer who grants location access in California gets an empty
picker and rejects the app as broken. The note has to steer them away from the
location prompt and onto a postcode that has data.

Paste this into *Anmerkungen*, adjusting the postcode if 01219 ever goes cold:

```
Le Chariot vergleicht die Wochenangebote deutscher Supermaerkte mit einer
Einkaufsliste. Die Daten sind ausschliesslich deutsch.

WICHTIG: Bitte die Standortfreigabe ABLEHNEN und die Postleitzahl von Hand
eingeben - 01219 (Dresden). Ausserhalb Deutschlands findet die Standortsuche
keine Filialen, und die App sieht dann leer aus.

1. Onboarding: Vorname eingeben, dann PLZ 01219 tippen
2. Die Fragen zu Haushalt und Ernaehrung koennen uebersprungen werden
3. Zum Schluss bietet die App einen kurzen Rundgang an - "Los geht's" fuehrt
   durch die Einkaufsliste, "Spaeter" geht direkt dorthin
4. Auf der Einkaufsliste steht "Noch keine Filiale gewaehlt". Dort auf
   "Filialen waehlen" tippen und zwei bis drei Laeden auswaehlen
   (z. B. Lidl, ALDI, Netto), dann "Fertig"
5. Ein Wort in die Zeile unten eintragen, z. B. "Milch", "Brot" oder "Kaese"
6. Oben steht dann, welcher Markt die Liste am guenstigsten abdeckt

Kein Login, kein Konto, keine Bezahlfunktion.
```

`Anmeldeinformationen` stays empty and *Anmeldung erforderlich* stays unticked —
there is no account.

**The note is walked by a test.** `ReviewNoteJourneyTests` follows the numbered
steps above on a fresh install and fails if any of them stops leading anywhere.
That test exists because this note was wrong once and nobody noticed: until
2026-07-31 the branch picker was step 3 of the onboarding wizard, and the day
the wizard started ending in the shopping list instead, step 3 described a screen
that no longer appeared there. A review note that does not match the app is a
rejection risk, and prose does not fail a build on its own.

Two things the test cannot check, so they are yours to keep true: the postcode
still having offers, and the location prompt — that is a system dialog, and a
test run without location services never sees it. The note tells the reviewer to
decline it, which is the path the test does walk (postcode typed by hand).


## What testers will notice first

Not bugs, gaps. Worth saying in the tester note rather than collecting the same
report eight times:

- Only some chains show a crossed-out original price, so the average-discount
  figure reads unevenly across chains. REWE, Lidl and EDEKA are decided and
  unbuilt.
- The multi-branch picker has never been used on a real device by anyone. Since
  2026-07-31 it is no longer part of the onboarding: the wizard ends in the
  shopping list, and the list asks for branches — so a tester who skips that
  step has a working shopping list with no price comparison, which looks like a
  gap and is one.
- ~~Contrast in Settings is not covered by the accessibility gate.~~ Covered
  again since 2026-08-01: the gate was off from 28.07. because the audit
  measures *through* the shadow of a card and reported findings the rendered
  pixels contradict. Bars are excluded and the screen is given longer to settle,
  so Settings is measured sharply again.
