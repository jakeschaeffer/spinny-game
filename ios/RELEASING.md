# Releasing Yet Another Line (iOS)

How to ship an update to the App Store, and what went wrong or worked well last time.

## Key facts

| | |
|---|---|
| Branch | `yet-another-line-app-store` (not `main`, which only has the old web version) |
| Bundle ID | `com.jakeschaeffer.onemoreline` (kept from the old name; don't change it) |
| Team ID | `3BGFWC629H` |
| App Store Connect app | https://appstoreconnect.apple.com/apps/6816804636/distribution |
| Signing | Automatic. Needs the "Apple Distribution" certificate in the keychain and an Apple ID signed in to Xcode (Settings → Accounts). |
| Export compliance | Answered in `YetAnotherLine-Info.plist` (`ITSAppUsesNonExemptEncryption`), so builds skip the encryption question. |
| Game Center | Entitlement in `YetAnotherLine.entitlements`. Leaderboard IDs: `com.jakeschaeffer.onemoreline.score.easy` and `com.jakeschaeffer.onemoreline.score.astro` (see `GameCenter.swift`). |

## Release history

| Version | Build | Notes |
|---|---|---|
| 1.0 | 1–2 | First release. |
| 1.0.1 | 3 | Glass icon buttons (pause, menu sound/settings) tappable across the whole circle. Submitted Oct 20, 2026; approved by Oct 21. |
| 1.1 | 4 | Easy and Astro (Hard) modes, learning mode, Game Center leaderboards, best combo, path trace with sharing, planet ramp, easter eggs. Submitted Oct 21, 2026 together with both leaderboards. |

Add a row each time you ship.

## Version and build numbers

Both live in `YetAnotherLine.xcodeproj/project.pbxproj`, four times each (app and test targets, Debug and Release). Change all four.

- `MARKETING_VERSION` is what users see (1.0.1). Once a version is **approved**, App Store Connect closes it and rejects any new build with that version ("The train version '1.0' is closed"). So every update after an approval needs a new version: patch (1.0.2) for fixes, minor (1.1) for features.
- `CURRENT_PROJECT_VERSION` is the build number. It must be higher than every build ever uploaded for the app, even rejected or unreleased ones. Just keep incrementing it.

```bash
sed -i '' 's/MARKETING_VERSION = 1.0.1;/MARKETING_VERSION = 1.0.2;/; s/CURRENT_PROJECT_VERSION = 3;/CURRENT_PROJECT_VERSION = 4;/' ios/YetAnotherLine.xcodeproj/project.pbxproj
```

## Steps

### 1. Check the build

```bash
xcodebuild test -project ios/YetAnotherLine.xcodeproj -scheme YetAnotherLine -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Then play it in the simulator. For UI changes, tap off-center and with a bit of finger drift, not just dead-center taps (see "Lessons" below). Ideally also try the TestFlight build on a real phone before submitting.

### 2. Bump the version and build number

See above. Don't commit yet; commit after the upload succeeds, so a failed upload doesn't leave a burned number in the repo.

### 3. Archive and upload

Run from the repo root. Archives go outside the repo.

```bash
xcodebuild archive -project ios/YetAnotherLine.xcodeproj -scheme YetAnotherLine \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath ~/Library/Developer/Xcode/Archives/YetAnotherLine.xcarchive -allowProvisioningUpdates

xcodebuild -exportArchive -archivePath ~/Library/Developer/Xcode/Archives/YetAnotherLine.xcarchive \
  -exportOptionsPlist ios/ExportOptions.plist -exportPath /tmp/YetAnotherLine-export -allowProvisioningUpdates
```

The archive is signed for development; the export step re-signs it for distribution. The upload uses the Apple ID signed in to Xcode, so no API key is needed. Look for `Upload succeeded` and `** EXPORT SUCCEEDED **`.

Alternative: Xcode → Product → Archive, then Organizer → Distribute App → App Store Connect.

### 4. Commit the bump

```bash
git commit -am "Bump to version X.Y.Z (build N)"
git push origin HEAD:yet-another-line-app-store
```

### 5. Submit in App Store Connect

1. Wait for processing. In TestFlight the build shows **Ready to Submit**, usually within a few minutes.
2. Distribution → the **+** next to "iOS App" → enter the new version → Create.
3. Under **Build**, click Add Build and pick the new build.
4. Fill in **What's New in This Version**. It's required for updates and starts empty. Everything else (description, keywords, screenshots, review notes) carries over from the last version.
5. Check **App Store Version Release**. It carries over from the last version; currently "Automatically release this version" after approval, to all users at once.
6. **Save**, then **Add for Review**. A "Draft Submission" panel opens. This can take 10+ seconds; stay on the page until it appears.
7. In the panel, confirm it lists only the new version, then **Submit for Review**. Status becomes **Waiting for Review**. Review can take up to 48 hours, and Apple emails when it's done.

You can withdraw a submission from Distribution → App Review until review starts.

## Game Center leaderboards (one-time setup)

The app submits each mode's best score to its own leaderboard. The leaderboards have to exist in App Store Connect, and the first version that uses them has to ship them, or scores go nowhere.

**Status:** done for 1.1 on Oct 21, 2026. Both leaderboards have an English (U.S.) localization and " point"/" points" suffixes, Astro is first and the default, and both were submitted with version 1.1.

1. In App Store Connect, open Distribution → Game Center (under Growth & Marketing) and add two **classic** leaderboards:

   | Reference name | Leaderboard ID | Display name |
   |---|---|---|
   | Easy high score | `com.jakeschaeffer.onemoreline.score.easy` | Easy |
   | Astro high score | `com.jakeschaeffer.onemoreline.score.astro` | Astro (Hard) |

   Score format: Integer. Submission type: Best score. Sort order: High to low. Leaderboard IDs can never be reused, even after deletion, so copy them exactly.
2. On the new version's page, check **Game Center** and Save. Then add the version for review, and on each leaderboard's page click **Add for Review** → the existing draft iOS submission. First-time leaderboards must be in the same submission as the app version (the version page itself has no leaderboard picker). They go live when that version is approved.
3. To test before release, run a development or TestFlight build on a phone signed in to Game Center. Those builds use the Game Center sandbox, which only shows leaderboards that exist in App Store Connect.

The simulator usually isn't signed in to Game Center; the leaderboard button then shows a "Sign in to Game Center" prompt instead.

## Lessons from 1.1

- **First-time leaderboards ride in the version's submission.** Check Game Center on the version page, add the version for review, then use each leaderboard's own Add for Review and pick the existing draft. The draft should list the version plus the leaderboards before you submit.
- **App Store Connect can hang on a spinner in a resized browser window.** Load the page at its natural size first, then widen it.

## Lessons from 1.0.1

- **Version 1.0 was already approved**, so the first upload as 1.0 build 3 was rejected. Check the current App Store version before bumping.
- **Simulator taps are too perfect.** The pause bug only showed with off-center or drifting presses. On iOS 26, `glassEffect` isn't hit-testable, so any custom button using it needs `.contentShape(...)`; the iOS 17–25 fallback hid the bug.
- **App Store Connect's sidebar collapses in a narrow browser window.** Widen the window to see the "+" next to "iOS App".
- **Don't leave the page while "Add for Review" says Processing.** The first attempt didn't create a submission because the page was left mid-request; clicking it again worked.
