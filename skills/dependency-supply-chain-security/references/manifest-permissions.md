# Manifest Permission Review (Mobile & Extension Packages)

Loaded by `dependency-supply-chain-security` when the dependency under review is a React Native
module, an Expo config plugin, or a browser extension — the package types that can add
manifest-declared permissions to the shipped app. Plain npm and pip libraries declare no
manifest permissions; this file does not apply to them.

---

## Why this is a separate review

A React Native module or Expo config plugin can inject entries into `AndroidManifest.xml` or
`Info.plist` at build time. A browser extension dependency can widen `permissions` or
`host_permissions` in `manifest.json`. In both cases the permission appears on the app store
listing or the extension install prompt under **your** name, not the package author's.

---

## Review checklist

- [ ] Diff the generated `AndroidManifest.xml` / `Info.plist` before and after adding the
      package (`npx expo prebuild --clean`), and account for every new entry
- [ ] Diff `manifest.json` `permissions` and `host_permissions` for extension dependencies
- [ ] Each requested capability maps to a feature the app actually ships

**Requests broad permissions** is a disqualifier: camera, microphone, contacts, location,
background location, or filesystem access that is not required for the package's stated
purpose.

| Permission | Justified when | Suspicious when |
|---|---|---|
| Camera / microphone | The package is a capture, scanner, or call SDK | An analytics, UI, or utility package requests it |
| Contacts | The feature is contact import, explicitly user-initiated | Any package that isn't doing contact import |
| Location (esp. background) | Maps, delivery, geofencing feature | An SDK that only reports crashes or metrics |
| Broad filesystem / storage | File manager or media pipeline | A package that only needs its own cache dir |
| `host_permissions: <all_urls>` | The extension genuinely works on every site | The extension has one target site |

If a package needs a permission for an optional feature the app never uses, prefer a variant of
the package without that feature, or vendor the narrow piece you need.
