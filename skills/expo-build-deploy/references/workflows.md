# EAS Workflows Reference

Loaded by `expo-build-deploy` when setting up CI/CD automation.

---

## File Location

Workflow YAML files live in `.eas/workflows/` at your project root (same level as `eas.json`).

```
my-app/
├── .eas/
│   └── workflows/
│       ├── development-builds.yml
│       ├── preview-updates.yml
│       └── production-release.yml
├── eas.json
├── app.json
└── src/
```

## Triggers

```yaml
# Trigger on push to specific branches
on:
  push:
    branches: ['main', 'release/*']

# Trigger on pull request
on:
  pull_request:
    branches: ['main']

# Trigger on label added to PR
on:
  pull_request:
    types: ['labeled']
    branches: ['main']

# Manual trigger only (no `on` block — run with `eas workflow:run`)
```

## Pre-Packaged Job Types

| Type | Purpose |
|------|---------|
| `build` | Create Android/iOS app binary |
| `submit` | Submit build to App Store / Play Store |
| `update` | Publish OTA update via EAS Update |
| `fingerprint` | Calculate native fingerprint (for update vs rebuild decisions) |
| `get-build` | Retrieve existing build matching criteria |
| `deploy` | Deploy web build to EAS Hosting |
| `maestro-cloud` | Run Maestro E2E tests |

## Example: Development Builds (Parallel)

```yaml
# .eas/workflows/development-builds.yml
name: Development Builds
jobs:
  build_ios:
    name: Build iOS Dev
    type: build
    params:
      platform: ios
      profile: development
  build_android:
    name: Build Android Dev
    type: build
    params:
      platform: android
      profile: development
```

## Example: Preview Updates on Every PR

```yaml
# .eas/workflows/preview-updates.yml
name: Preview Update
on:
  pull_request:
    branches: ['main']
jobs:
  update:
    name: Publish Preview Update
    type: update
    params:
      branch: ${{ github.ref_name }}
      message: "PR #${{ github.event.pull_request.number }}: ${{ github.event.pull_request.title }}"
      environment: preview
```

## Example: Smart Release (Fingerprint Check)

This workflow checks if native code changed. If yes, it builds and submits. If no, it
publishes an OTA update — avoiding unnecessary store releases.

```yaml
# .eas/workflows/production-release.yml
name: Production Release
on:
  push:
    branches: ['main']
jobs:
  fingerprint:
    name: Check Fingerprint
    type: fingerprint
    environment: production

  get_build:
    name: Find Existing Build
    type: get-build
    needs: [fingerprint]
    params:
      fingerprint: ${{ needs.fingerprint.outputs.fingerprint }}
      profile: production

  # If no matching build exists, create one
  build_ios:
    name: Build iOS
    type: build
    needs: [get_build]
    if: ${{ !needs.get_build.outputs.build_id }}
    params:
      platform: ios
      profile: production

  build_android:
    name: Build Android
    type: build
    needs: [get_build]
    if: ${{ !needs.get_build.outputs.build_id }}
    params:
      platform: android
      profile: production

  # If a matching build exists, just publish an OTA update
  update:
    name: Publish OTA Update
    type: update
    needs: [get_build]
    if: ${{ needs.get_build.outputs.build_id }}
    params:
      channel: production
      message: ${{ github.event.head_commit.message }}
      environment: production
```

## Running Workflows

```bash
# Run a workflow manually
eas workflow:run .eas/workflows/production-release.yml

# Workflows also trigger automatically via GitHub events (push, PR)
# Requires GitHub repo linked to EAS project
```

## Linking GitHub

1. Go to your project's GitHub settings on expo.dev
2. Install the Expo GitHub App
3. Select and connect your repository
4. Add `on:` triggers to your workflow YAML files

After linking, pushes and PRs to matching branches automatically trigger workflows.
