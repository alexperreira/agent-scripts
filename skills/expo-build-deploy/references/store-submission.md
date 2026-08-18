# Store Submission Reference

Loaded by `expo-build-deploy` before a first submission to either store, or when configuring
automated submission credentials.

---

## iOS — TestFlight / App Store

```bash
# Submit the latest production build
eas submit --platform ios

# Or submit automatically when the build finishes
eas build --profile production --platform ios --auto-submit
```

**Requirements:**
- Apple Developer Program membership ($99/year)
- An App Store Connect app whose bundle identifier matches the build
- `ascAppId` set under `submit.production.ios` in `eas.json`

TestFlight builds are usable within minutes of processing; App Store review is the slow leg.
Internal TestFlight testers (up to 100, same team) need no review — external testers do.

## Android — Play Store

```bash
eas submit --platform android

eas build --profile production --platform android --auto-submit
```

**Requirements:**
- Google Play Developer account ($25 one-time)
- A Play Console app whose package name matches the build
- A Google service account JSON key uploaded to EAS for automated submission

Play's internal testing track propagates in minutes; production rollout supports staged
percentages, which pair well with a matching EAS Update rollout percentage.

## Internal Distribution — Skip the Stores

```bash
eas build --profile preview --platform all
```

`"distribution": "internal"` produces an installable APK (Android) or ad hoc build (iOS) shared
by URL — no review, no test-flight processing. This is the right channel for QA and stakeholder
review; routing those builds through the store instead is the most common source of
self-inflicted release delay.

iOS ad hoc distribution requires each test device's UDID registered on the Apple Developer
account, which EAS prompts for during the build.

## Version Numbers

With `"appVersionSource": "remote"` in `eas.json`, EAS owns the build number and
`autoIncrement: true` on the `production` profile bumps it per build. The user-facing version
string still comes from `version` in app.json and is a deliberate, manual decision — bump it
when the release notes say a new version shipped, not on every build.
