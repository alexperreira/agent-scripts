# Tooling Recommendations by Stack

Read when choosing the tool column for Must Test / Should Test rows.

---

## Node.js / TypeScript (Backend)
- **Unit + Integration:** [Vitest](https://vitest.dev) (fast, ESM-native) or Jest
- **HTTP integration:** [Supertest](https://github.com/ladjs/supertest) against a real local server
- **DB:** Spin up a real Postgres test instance (Docker); use separate test DB, not mocks
- **Mocking:** `vi.mock()` / `jest.mock()` for external services only — not for your own modules

---

## React Native / Expo (Mobile)
- **Unit + Component:** [Jest](https://jestjs.io) + [React Native Testing Library](https://callstack.github.io/react-native-testing-library/)
- **E2E:** [Maestro](https://maestro.mobile.dev) — the most reliable RN e2e tool currently;
  runs on real device or simulator. Prefer over Detox for new projects.
- **Note:** Expo Go limits what can be tested on-device. E2E tests require a development build.
  Factor this into the test strategy — if a dev build isn't available, e2e tests require
  Android Studio emulator or TestFlight.

---

## API Contract Testing
- [Zod](https://zod.dev) schema assertions at the integration test boundary — parse the
  response through the schema and fail if it doesn't match
- For more formal contract testing across services: [Pact](https://pact.io)
