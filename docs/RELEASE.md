# Shipping a TestFlight build

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

**Signing is proven; uploading is not.** The archive-and-export path produces a
genuinely App-Store-signed `.ipa` — `Apple Distribution: Scott Koehler
(3DZ9T8SGX5)`, chained to Apple WWDR, with a store profile and
`get-task-allow: false`. Verified on the unpacked artifact.

Uploading is a different door, and it is shut. There is **no Apple ID signed
into Xcode** — `DVTDeveloperAccountManagerAppleIDLists` is empty — so the upload
step fails:

```
IDEDistributionUploadAccountStep: "Failed to Use Accounts"
App Store Connect access for "3DZ9T8SGX5" is required.
```

A first attempt reported `missingApp(bundleId: "com.skoehler.lechariot")`
instead, which reads like "only the app record is missing". It is not that:
the same log shows `App Store Connect team IDs for account (null) are ()` — an
empty team list from a session that does not exist. The missing record was a
symptom of having no account, not the sole blocker.

So there are two prerequisites below, not one.

## Version and build number

`MARKETING_VERSION` lives in `ios/project.yml` and is the number testers see.
The build number is the commit count, set at archive time. It is the only number
in the project that rises on its own and still holds after `xcodegen generate` —
written into `project.yml` it would reset on every regeneration, and App Store
Connect refuses a build number it has already seen.

So: raise `MARKETING_VERSION` by hand when a release means something, and never
touch the build number.

## One-time setup

None of this is in the repo, because none of it can be.

0. **An Apple ID in Xcode.** Xcode → Settings → Accounts → **+** → Apple ID,
   with the account that holds team `3DZ9T8SGX5`. Needs the password and the
   two-factor code, so it is yours to do and cannot be scripted. Nothing signs
   in today; signing works anyway because the certificate and store profile
   already exist locally, but the upload has no session to use.

1. **App record.** appstoreconnect.apple.com → Apps → +, platform iOS, bundle ID
   `com.skoehler.lechariot`, primary language German. The App ID is already
   registered on the developer portal, and the distribution certificate plus the
   store provisioning profile exist — nothing has to be clicked for signing.

2. **API key**, only if you want `--upload` instead of Xcode's Organizer:
   App Store Connect → Users and Access → Integrations → App Store Connect API,
   role *App Manager*. The `.p8` downloads exactly once. Then

   ```
   export ASC_KEY_ID=…  ASC_ISSUER_ID=…  ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_….p8
   ```

   Keep it out of the repo — `~/.config/lechariot/env` is where the backend
   credentials already live.

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
to reach something worth seeing. A reviewer who lands on the branch picker with
nothing selected sees an empty app, so say in the note which postcode to enter
(Dresden, `01219`) and that offers appear once branches are picked.

Export compliance is already answered in the Info.plist
(`ITSAppUsesNonExemptEncryption = false` — HTTPS only, standard exemption), so
builds do not sit blocked on that question.

## What testers will notice first

Not bugs, gaps. Worth saying in the tester note rather than collecting the same
report eight times:

- Only some chains show a crossed-out original price, so the average-discount
  figure reads unevenly across chains. REWE, Lidl and EDEKA are decided and
  unbuilt.
- The guided tour and the multi-branch picker have never been used on a real
  device by anyone.
- Contrast in Settings is not covered by the accessibility gate.
