---
name: expo-build-deploy
description: >
  EAS Build, development builds, OTA updates, app store submission, and release management for
  Expo/React Native apps. Use this skill whenever someone asks about building their app, creating
  a development build, publishing OTA updates, submitting to TestFlight or Play Store, setting up
  eas.json, configuring EAS Update channels, or debugging build failures. Also trigger
  proactively when Claude Code is about to run `eas build` without a configured eas.json, use
  Expo Go for a feature that requires a development build (push notifications, custom native
  modules, OAuth), attempt a local iOS build on a non-macOS machine, or publish an OTA update
  without considering runtime version compatibility. Owns the build-to-release pipeline and the
  WSL2/Ubuntu + single iPhone + no macOS device workflow. If the question is about project setup,
  use `expo-project-scaffold`. If it's about component architecture, use `rn-component-patterns`.
  If it's about iOS/Android platform differences, use `rn-platform-gotchas`.
---

# Expo Build & Deploy

Local development through store release for Expo SDK 55+, on a WSL2/Ubuntu setup with one
physical iPhone and no macOS machine.

**Four rules that decide whether a release reaches users:**

1. **`runtimeVersion` uses the `"fingerprint"` policy.** It recomputes whenever native
   dependencies change, so an OTA update can never land on a binary that lacks the native code
   it calls.
2. **`eas update` requires `--environment` in SDK 55.** Omitting it errors out.
3. **Every build profile that should receive OTA updates sets a `channel`.** A profile with no
   channel produces binaries that silently never update.
4. **Rebuild only when native dependencies change.** JS-only changes ship via the dev server in
   development and EAS Update in production.

---

## Routing to Sibling Skills

- New project setup → `expo-project-scaffold`
- Component architecture, hooks, state → `rn-component-patterns`
- iOS/Android behavior differences → `rn-platform-gotchas`

---

## Expo Go vs Development Builds

Expo Go runs your JS inside a pre-built native container with a fixed set of native modules —
fine for learning and early prototyping, and a dead end for anything shipping.

**Move to a development build the moment the project needs any of these:**

| Need | Why Expo Go can't |
|---|---|
| Push notifications | Removed from Expo Go in SDK 53+; throws in SDK 55 |
| Any library with custom native code | Not compiled into the Expo Go binary |
| OAuth, deep links, custom URL schemes | Expo Go owns the bundle identifier, not your app |
| Your real splash screen, icon, or app.json native config | Expo Go ships its own |
| Anything destined for a store | Store binaries are builds, not Expo Go |

**SDK 55 Expo Go status:** available via CLI for Android and via TestFlight for iOS. It is NOT
on the iOS App Store — use `eas go` or TestFlight External Beta.

A development build is your own Expo Go: same hot reload, QR code, and error overlays, compiled
with your project's exact native dependencies. Switching is additive, not a migration — add
`expo-dev-client`, build once, keep writing the same JS.

```bash
npx expo install expo-dev-client

eas build --profile development --platform ios
eas build --profile development --platform android

npx expo start --dev-client   # then scan the QR from your dev build
```

---

## EAS Build Setup

```bash
npm install -g eas-cli
eas login
eas init          # links the project to EAS
```

### eas.json

```json
{
  "cli": {
    "version": ">= 15.0.0",
    "appVersionSource": "remote"
  },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal"
    },
    "development-simulator": {
      "developmentClient": true,
      "distribution": "internal",
      "ios": {
        "simulator": true
      }
    },
    "preview": {
      "distribution": "internal",
      "channel": "preview"
    },
    "production": {
      "autoIncrement": true,
      "channel": "production"
    }
  },
  "submit": {
    "production": {
      "ios": {
        "ascAppId": "YOUR_APP_STORE_CONNECT_APP_ID"
      }
    }
  }
}
```

| Profile | Purpose | Distribution | When |
|---------|---------|-------------|-------------|
| `development` | Dev build for physical devices | Internal (ad hoc) | Daily development |
| `development-simulator` | Dev build for iOS Simulator | Internal | Simulator testing (unavailable on WSL2) |
| `preview` | Testable build without dev tools | Internal | QA, stakeholder review |
| `production` | Store-ready binary | Store | Store submission |

```bash
eas build --profile production --platform all
eas build:list                                  # build status
```

**Build reuse:** when the project fingerprint matches an existing build, EAS hands back that
build instead of compiling a new one.

**Build caching:** EAS caches dependencies between builds; custom cache paths in `eas.json` cut
roughly another 30% off build time.

---

## WSL2 + iPhone Workflow

**iOS builds always go through EAS Build.** `npx expo run:ios` needs macOS and Xcode; there is
no local iOS path on WSL2, and the iOS Simulator does not run on Windows.

```bash
eas build --profile development --platform ios

# Install on the iPhone:
#   1. Scan the QR code from the EAS dashboard
#   2. Expo Orbit (desktop app)
#   3. eas build:run  (recent builds)
```

**An Apple Developer Program membership ($99/year) is required** for any iOS device build
signing.

### Daily loop

1. **Once:** `eas build --profile development` and install on the iPhone
2. **Daily:** `npx expo start --dev-client`, scan the QR from your dev build
3. **Rebuild:** only when native dependencies change or the SDK is upgraded

Hot reload runs over the local network, so WSL2 and the iPhone need to be on the same one. When
they aren't (corporate wifi, client isolation), `npx expo start --tunnel` routes around it.

**Read `references/wsl2-android.md`** to build Android locally instead of on EAS — it covers
Android Studio on the Windows host, bridging ADB into WSL2, and `ANDROID_HOME`. Using EAS Build
for Android too is the lower-friction default.

---

## EAS Update (OTA)

OTA updates ship JS and asset changes to installed apps without a store round trip — minutes
instead of days.

| Ships over the air | Requires a new binary |
|---|---|
| JavaScript (logic, UI, navigation) | Native code, new native modules, SDK upgrades |
| Images and assets bundled with the JS | App icon, splash screen, app.json native config |
| Styling changes | Config plugin changes |

```bash
npx expo install expo-updates
eas update:configure        # writes the required app.json + eas.json config
```

Install and configure `expo-updates` during initial project setup. Adding it later means
shipping a full store release first before any update can be delivered.

### Runtime versions

Updates reach only builds whose runtime version matches, which is what stops JS from calling
native APIs a binary doesn't have.

```json
{
  "expo": {
    "runtimeVersion": {
      "policy": "fingerprint"
    }
  }
}
```

The fingerprint recomputes from the native dependency graph, so adding a library or upgrading
the SDK automatically demands a new build before updates flow again.

### Publishing

```bash
eas update --channel preview --message "Fix login button alignment" --environment preview
eas update --channel production --message "Fix crash on profile screen" --environment production
```

**Start production rollouts at 5–10% to bound the blast radius**, watch error rates on the EAS
dashboard, then increase:

```bash
eas update --channel production --rollout-percentage 10 --environment production --message "..."
```

**Read `references/eas-update.md`** when mapping channels to branches, promoting an update from
preview to production, rolling one back, or enabling SDK 55 bundle diffing.

### Release compatibility

Users sit on old binaries for weeks. Any backend change that ships alongside a release has to
keep serving the versions already installed — `api-contract-design` for response shape changes,
`db-migration-safety` for the schema underneath them. An OTA update cannot rescue a client whose
API contract was broken server-side.

---

## Store Submission

```bash
eas submit --platform ios
eas build --profile production --platform android --auto-submit
```

**Read `references/store-submission.md`** before the first submission to either store — it holds
the account requirements, the `ascAppId` and service-account credential setup, and the internal
distribution path that skips store review entirely for QA builds.

For QA and stakeholder builds, `"distribution": "internal"` on the `preview` profile produces an
installable APK or ad hoc iOS build shared by URL, with no review wait.

`changelog-generator` turns completed task docs into the release notes that go into App Store
Connect and the Play Console.

---

## EAS Workflows (CI/CD)

EAS Workflows automate builds, updates, submissions, and tests from YAML in `.eas/workflows/`.

```yaml
# .eas/workflows/production-release.yml
name: Production Release
on:
  push:
    branches: ['main']
jobs:
  build_ios:
    type: build
    params:
      platform: ios
      profile: production
  build_android:
    type: build
    params:
      platform: android
      profile: production
```

Job types: `build`, `submit`, `update`, `fingerprint`, `get-build`, `deploy`, `maestro-cloud`.

**Read `references/workflows.md`** when setting up CI/CD — it holds trigger syntax, the full job
type table, GitHub linking, and the smart-release workflow that fingerprints the native layer
and picks OTA-vs-rebuild automatically.

---

## Checklist: Ready to Ship?

Walk this before every store submission. Each box is something checked in `eas.json`, the EAS
dashboard, or a device — a green CI run does not substitute.

**Development setup**
- [ ] `expo-dev-client` installed
- [ ] `eas.json` defines `development`, `preview`, and `production` profiles
- [ ] Development build installed on the test device
- [ ] `npx expo start --dev-client` connects

**OTA updates**
- [ ] `expo-updates` installed and configured
- [ ] `runtimeVersion` uses the `"fingerprint"` policy
- [ ] `channel` set on `preview` and `production` profiles
- [ ] Every `eas update` command carries `--environment`
- [ ] Rollout percentage planned for the first production push

**Store submission**
- [ ] Apple Developer / Google Play accounts active
- [ ] App Store Connect and Play Console apps created with matching identifiers
- [ ] `production` profile sets `autoIncrement`
- [ ] `submit` config holds the store credentials
- [ ] The exact build going to the store was installed and exercised via internal distribution
- [ ] Release notes drafted (`changelog-generator`)

**WSL2**
- [ ] iOS builds ran on EAS, not locally
- [ ] Android local builds have ADB bridged from Windows (if not using EAS)

**If every box passes, say the release is ready and stop.** Inventing a blocker to look careful
delays a good build. If a shipped update does cause a user-visible failure, roll back first, then
run `incident-postmortem`.
