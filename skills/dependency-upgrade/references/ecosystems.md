# Ecosystem-Specific Checklists

Read this while working Steps 2–5 for a package, and pick the section matching the ecosystem.

---

## npm / Node.js
- [ ] Check `engines` field in `package.json` — target version may require newer Node
- [ ] Run `npm ls` after upgrade to surface peer dep conflicts
- [ ] Check for `peerDependenciesMeta` changes that make previously-optional deps required
- [ ] Review `exports` field changes (may break deep imports like `pkg/internal/util`)
- [ ] Confirm TypeScript types are updated (`@types/X` or bundled types)

---

## pip / Python
- [ ] Check `python_requires` in target version — may require Python version bump
- [ ] Run `pip check` after upgrade to surface incompatible requirements
- [ ] Review deprecation warnings in current version — deprecated APIs are often removed in major bumps
- [ ] Confirm type stubs are updated if using `mypy` / `pyright`
- [ ] Check for Pydantic v1 → v2 patterns if upgrading in that ecosystem (common cascade)

---

## Expo / React Native (Alex's primary mobile stack)
- [ ] Check Expo SDK compatibility matrix before upgrading React Native directly
- [ ] Always upgrade via `expo upgrade` or `expo-doctor` — do not manually bump RN version
- [ ] Review native module compatibility — many community modules lag Expo SDK releases
- [ ] Test on both iOS and Android simulators after any Expo SDK bump
- [ ] Check `app.json` / `app.config.js` for deprecated config keys in target SDK version
- [ ] EAS Build cache may need clearing after a major SDK bump
