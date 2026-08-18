# Backend and Auth Provider Choices

Loaded by `expo-project-scaffold` when the user names a backend or auth provider, or asks which
to use. The scaffold itself stays backend-agnostic until one of these is chosen.

---

## Backend

Do not pre-commit to a backend. When the user names one:

| Option | Fit | Notes |
|---|---|---|
| **Supabase** | Postgres + auth + realtime, usable free tier | RN SDK works with Expo; pairs with Supabase Auth so the auth decision resolves itself |
| **Firebase** | Only when the user already knows it | Heavier Expo setup — needs config plugins and a development build |
| **Custom API** | Any REST or GraphQL endpoint | TanStack Query is transport-agnostic; `api-contract-design` owns the contract shape |

For a custom API, the response envelope, error codes, and pagination style are decisions the
mobile client is stuck with once it ships to a store — old app versions keep calling the old
shape for months. Settle them with `api-contract-design` before the first query hook is written,
and treat any backend schema change behind that API as a compatibility question
(`db-migration-safety`).

## Auth

Scaffold auth only when asked. When asked:

| Option | Fit | Notes |
|---|---|---|
| **Clerk** | Best Expo DX | Prebuilt components, handles OAuth flows end to end |
| **Supabase Auth** | Already on Supabase | One less service, session handling built in |
| **Firebase Auth** | Already on Firebase | Same reasoning |

All three need a development build once OAuth or deep links are involved — Expo Go cannot handle
a custom URL scheme (see `expo-build-deploy`). Budget for that before promising a login flow
demoable in Expo Go.

Auth determines the route group layout, so decide before generating route files rather than
retrofitting `(auth)/` later. The routing mechanics live in `auth-routing.md`.

## Token Storage

Tokens go in `expo-secure-store` (Keychain on iOS, Keystore on Android), never `AsyncStorage`,
which is plaintext on disk. `secrets-env-management` covers what else does and does not belong
in client storage or in an `EXPO_PUBLIC_` env var.
