---
name: expo-build-deploy
description: >
  EAS Build, development builds, OTA updates, app store submission, and release management
  for Expo/React Native apps. Use this skill whenever someone asks about building their app,
  creating a development build, publishing OTA updates, submitting to TestFlight or Play Store,
  setting up eas.json, configuring EAS Update channels, or debugging build failures. Also trigger
  proactively when Claude Code is about to run `eas build` without a configured eas.json, use
  Expo Go for a feature that requires a development build (push notifications, custom native
  modules, OAuth), attempt a local iOS build on a non-macOS machine, or publish an OTA update
  without considering runtime version compatibility. Covers the full build-to-release pipeline
  for a WSL2/Ubuntu + single iPhone + no macOS setup. If the question is about project setup,
  use `expo-project-scaffold`. If it's about component architecture, use `rn-component-patterns`.
  If it's about iOS/Android platform differences, use `rn-platform-gotchas`.
---

# Expo Build & Deploy

Everything from local development to app store release for Expo SDK 55+ projects. This skill
assumes a WSL2/Ubuntu setup with a single physical iPhone and no macOS machine — the most
constrained common setup for Expo development.

The goal: know exactly which build type to use, when to switch from Expo Go to a development
build, how to ship OTA updates safely, and how to submit to stores without a Mac.

---

## When NOT to Use This Skill

- Setting up a new project from scratch → use `expo-project-scaffold`
- Component architecture, hooks, state management → use `rn-component-patterns`
- iOS/Android platform differences → use `rn-platform-gotchas`

---

## Expo Go vs Development Builds

### Expo Go

Expo Go is a sandbox for learning and early prototyping. It runs your JS inside a
pre-built native container with a fixed set of native modules.

**What Expo Go CAN do:**
- Run JS-only code and libraries
- Use most Expo SDK packages (camera preview, image picker, location, etc.)
- Hot reload, QR code scanning, error overlays

**What Expo Go CANNOT do:**
- Run libraries with custom native code not bundled in Expo Go
- Push notifications (removed in SDK 53+, throws error in SDK 55)
- OAuth / deep linking with your app's bundle identifier
- Custom splash screens, app icons, or native config from app.json
- Any native module you install yourself

**SDK 55 Expo Go status:** Expo Go v55 is available via CLI for Android and TestFlight
for iOS. It is NOT on the iOS App Store — use `eas go` or TestFlight External Beta.
Expo strongly recommends migrating to development builds for any production project.

### Development Builds

A development build is your own custom version of Expo Go — built with your project's
exact native dependencies. Same DX (hot reload, QR code, error overlays), but no
limitations on native code.

**When to switch from Expo Go to a development build:**
- You need push notifications
- You add any library with native code not in Expo Go
- You need OAuth, deep links, or custom URL schemes
- You want your actual splash screen and app icon during development
- You're building anything you plan to ship to a store

**The switch is not a migration.** You add `expo-dev-client`, create a build, and keep
developing the same way. Your JS code doesn't change.

### Creating a Development Build

```bash
# Install dev client
npx expo install expo-dev-client

# Build on EAS (required for iOS without macOS)
eas build --profile development --platform ios
eas build --profile development --platform android

# Or build Android locally (if Android Studio is set up)
npx expo run:android
```

After the build completes, install it on your device. Then start the dev server:

```bash
npx expo start --dev-client
```

Scan the QR code from your development build — same workflow as Expo Go.

---

## EAS Build Setup

### Prerequisites

```bash
# Install EAS CLI globally
npm install -g eas-cli

# Log in to your Expo account
eas login

# Link your project to EAS
eas init
```

### eas.json — Build Profiles

The `eas.json` file defines build profiles. Create it at your project root:

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

### Build Profile Cheat Sheet

| Profile | Purpose | Distribution | When to use |
|---------|---------|-------------|-------------|
| `development` | Dev build for physical devices | Internal (ad hoc) | Daily development |
| `development-simulator` | Dev build for iOS Simulator | Internal | Testing on simulator |
| `preview` | Testable build without dev tools | Internal | QA, stakeholder review |
| `production` | Store-ready binary | Store | App store submission |

### Running Builds

```bash
# Development build for iOS (cloud — required without macOS)
eas build --profile development --platform ios

# Development build for Android
eas build --profile development --platform android

# Production build for both platforms
eas build --profile production --platform all

# Check build status
eas build:list
```

**Build reuse:** If two team members run `eas build` and the project fingerprint matches,
EAS downloads the existing build instead of creating a new one.

---

## WSL2 + iPhone Development Workflow

This is the workflow for the most constrained setup: WSL2/Ubuntu, one iPhone, no Mac.

### iOS Development (No macOS)

You CANNOT build iOS locally without macOS. All iOS builds go through EAS Build (cloud).

```bash
# Create development build (cloud)
eas build --profile development --platform ios

# Install on iPhone:
# Option 1: Scan QR code from EAS dashboard
# Option 2: Use Expo Orbit (desktop app) to install
# Option 3: eas build:run (if build is recent)
```

**Apple Developer Program ($99/year) is required** for any iOS device build signing.
Simulator builds don't require it, but you can't run iOS Simulator on Windows/WSL2.

### Android Development (Local Option Available)

Android builds can run locally if Android Studio is installed on the Windows host:

1. Install Android Studio on Windows (not inside WSL2)
2. Enable USB debugging on your Android device or start an emulator
3. From WSL2, connect to the Windows ADB server:

```bash
# In WSL2, point ADB to Windows host
export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037

# Or set the Windows ADB path
export ANDROID_HOME=/mnt/c/Users/<username>/AppData/Local/Android/Sdk
```

4. Run the local Android build:

```bash
npx expo run:android
```

Alternatively, just use EAS Build for Android too — it's simpler and avoids local
toolchain issues.

### Daily Development Flow

1. **First time:** Create a development build via `eas build --profile development`
2. **Install** the build on your iPhone (QR from dashboard or Expo Orbit)
3. **Daily:** Run `npx expo start --dev-client` — scan QR from your dev build
4. **Rebuild only** when you add/remove native dependencies or upgrade SDK

You do NOT need to rebuild for JS-only changes. The dev server handles hot reload.

---

## EAS Update (OTA)

EAS Update lets you push JS and asset changes to users without going through the app
stores. Fix bugs in minutes instead of days.

### What OTA CAN Update

- JavaScript code (business logic, UI, navigation)
- Images and assets bundled with your JS
- Styling changes

### What OTA CANNOT Update

- Native code (new native modules, SDK upgrades, config plugin changes)
- App icon, splash screen, or `app.json` native config
- Anything that requires a new binary

### Setup

```bash
# Install expo-updates
npx expo install expo-updates

# Configure EAS Update
eas update:configure
```

This adds the required config to `app.json` and `eas.json`.

### Publishing Updates

```bash
# Publish to preview channel
eas update --channel preview --message "Fix login button alignment" --environment preview

# Publish to production
eas update --channel production --message "Fix crash on profile screen" --environment production
```

**SDK 55 breaking change:** `eas update` now REQUIRES the `--environment` flag. This was
made mandatory because the default was confusing. Always specify it.

### Runtime Versions

Updates are only delivered to builds with a matching runtime version. This prevents
sending JS that references native APIs that don't exist in the build.

**Recommended policy:** Use `"fingerprint"` — it auto-calculates based on your native
dependencies:

```json
{
  "expo": {
    "runtimeVersion": {
      "policy": "fingerprint"
    }
  }
}
```

When native code changes (new library, SDK upgrade, config plugin change), the fingerprint
changes automatically, and a new build is required before updates can be delivered.

### Channels and Branches

- **Channel:** A label on a build (set in `eas.json` per profile). Examples: `production`,
  `preview`, `staging`.
- **Branch:** Where updates are published. By default, branch name = channel name.
- **Mapping:** A channel points to a branch. All builds on channel `production` receive
  updates from branch `production`.

This means you can test an update on `preview` builds, then promote it to `production`
by re-publishing or remapping.

### Rollouts

Don't ship to 100% of users immediately. Use rollout percentages:

```bash
# Roll out to 10% of production users
eas update --channel production --rollout-percentage 10 --environment production --message "Test new feature"
```

Monitor error rates on the EAS dashboard. If stable, increase the percentage. If not,
the update can be rolled back.

### Bundle Diffing (SDK 55 — Beta, Opt-In)

SDK 55 supports Hermes bytecode diffing. Instead of downloading full bundles, devices
download patches — approximately 75% smaller updates.

Enable in `app.json`:

```json
{
  "expo": {
    "updates": {
      "enableBsdiffPatchSupport": true
    }
  }
}
```

Requires a new build after enabling. Falls back to full bundle if a patch isn't beneficial.

---

## EAS Submit (App Stores)

### iOS (TestFlight / App Store)

```bash
# Submit the latest production build
eas submit --platform ios

# Or auto-submit after build completes
eas build --profile production --platform ios --auto-submit
```

**Requirements:**
- Apple Developer Program membership ($99/year)
- App Store Connect app created with matching bundle identifier
- `ascAppId` set in `eas.json` submit config

### Android (Play Store)

```bash
# Submit to Play Store
eas submit --platform android

# Or auto-submit
eas build --profile production --platform android --auto-submit
```

**Requirements:**
- Google Play Developer account ($25 one-time)
- Play Store app created with matching package name
- Service account JSON key uploaded to EAS (for automated submission)

### Internal Distribution (Skip the Stores)

For QA and stakeholder testing, use internal distribution instead of store submission:

```bash
# Build with internal distribution
eas build --profile preview --platform all
```

This creates an installable APK (Android) or ad hoc build (iOS) that you share via URL.
No store review required.

---

## EAS Workflows (CI/CD)

EAS Workflows automate builds, updates, submissions, and tests with YAML config files.

**For full workflow YAML syntax, triggers, and example configurations, read
`references/workflows.md`.**

Quick example — build and submit on push to `main`:

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

Key workflow job types: `build`, `submit`, `update`, `fingerprint`, `get-build`, `maestro-cloud`.

---

## Common Footguns

1. **Using Expo Go for features that need a dev build.** Push notifications, OAuth, custom
   native modules, and deep linking all require a development build. Don't debug mysterious
   failures in Expo Go — just switch.

2. **Rebuilding for every JS change.** You only need to rebuild when native dependencies
   change. JS-only changes are served via the dev server (development) or OTA updates
   (production).

3. **Forgetting `--environment` on `eas update`.** This is required in SDK 55. Omitting it
   will error.

4. **Mismatched runtime versions.** If you add a native dependency and publish an OTA update
   without rebuilding, the update targets the old runtime version and won't reach new builds.
   Use `"fingerprint"` policy to catch this automatically.

5. **No `channel` in build profiles.** If your `eas.json` build profile doesn't specify a
   `channel`, builds won't receive OTA updates. Always set `channel` on `preview` and
   `production` profiles.

6. **Attempting local iOS build on WSL2.** `npx expo run:ios` requires macOS + Xcode. On
   WSL2, all iOS builds must go through EAS Build (cloud).

7. **Skipping internal distribution.** Sending production builds to testers through the
   store is slow. Use `"distribution": "internal"` for preview/QA builds.

8. **Publishing OTA to 100% immediately.** Use rollout percentages to limit blast radius.
   Start at 5–10%, monitor, then increase.

9. **Not setting up `expo-updates` early.** If you wait until launch to add OTA update
   support, you need a full store release first. Install `expo-updates` and configure
   channels during initial project setup.

10. **Ignoring build caching.** EAS caches dependencies between builds. Custom cache paths
    can be set in `eas.json` to speed up builds further (~30% improvement).

---

## Checklist: Ready to Ship?

### Development Setup
- [ ] `expo-dev-client` installed for development builds
- [ ] `eas.json` has `development`, `preview`, and `production` profiles
- [ ] Development build created and installed on test device
- [ ] Dev server runs with `npx expo start --dev-client`

### OTA Updates
- [ ] `expo-updates` installed and configured
- [ ] `runtimeVersion` uses `"fingerprint"` policy
- [ ] `channel` set on `preview` and `production` build profiles
- [ ] `--environment` flag included in all `eas update` commands
- [ ] Bundle diffing enabled (optional, SDK 55 beta)

### Store Submission
- [ ] Apple Developer Program / Google Play Developer account set up
- [ ] App Store Connect / Play Console app created
- [ ] `production` build profile configured with `autoIncrement`
- [ ] `submit` config in `eas.json` has store credentials
- [ ] Internal distribution tested before store submission

### WSL2-Specific
- [ ] iOS builds use EAS Build (cloud), not local
- [ ] Android local builds have ADB bridged from Windows (if using local builds)
- [ ] Expo Orbit or QR code used for device installation
