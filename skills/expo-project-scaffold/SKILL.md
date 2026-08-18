---
name: expo-project-scaffold
description: >
  Scaffolds new Expo/React Native projects with opinionated defaults: SDK 55+, Expo Router,
  Zustand + TanStack Query, TypeScript, and a scalable folder structure. Use this skill whenever
  someone is starting a new mobile app, initializing an Expo project, asking "how should I set up
  my app", "what's the right folder structure", "which navigation library should I use", "what
  state management for React Native", or adding a major new feature area that needs new
  screens/routes/navigation. Also trigger proactively when building a mobile app from scratch,
  choosing between React Native libraries, or when Claude Code is about to run
  `create-expo-app` without guidance. Owns project init, folder structure, dependency
  selection, and required-file generation. If the question is about build, deploy, OTA, or the
  WSL2 device workflow, use `expo-build-deploy`. If it's about component architecture or state
  placement, use `rn-component-patterns`. If it's about iOS/Android differences, use
  `rn-platform-gotchas`.
---

# Expo Project Scaffold

Opinionated project setup for Expo/React Native apps. Every default here has a reason; follow
them unless the user explicitly overrides.

**Two things determine whether a scaffold survives contact with the first feature:**

1. **Resolve the decision gates before writing files.** Auth provider, backend, styling, and tab
   structure are wrong-guess-expensive. Ask; do not assume.
2. **Generate every file in the required-files table yourself**, with the correct content, even
   when the SDK template already ships a version. CC skips layout files and the providers
   wrapper whenever they aren't listed explicitly.

Goal: a new project is buildable, navigable, and data-ready within the first session — no
placeholder architecture that gets ripped out later.

---

## Routing to Sibling Skills

- Modifying an existing project's architecture → `rn-component-patterns`
- Build, deploy, OTA, dev builds, WSL2 device workflow → `expo-build-deploy`
- iOS/Android differences or permission flows → `rn-platform-gotchas`
- Adding a single screen to an existing app → no skill needed

---

## Opinionated Defaults (and Why)

### SDK & Runtime

| Choice | Value | Why |
|--------|-------|-----|
| Expo SDK | 55+ (latest stable) | New Architecture only, `/src/app` default, React 19.2 |
| React Native | 0.83+ (bundled with SDK 55) | Ships with the SDK — never pinned independently |
| TypeScript | Always | Non-negotiable for any project Claude Code will touch |
| New Architecture | Enabled (default, no opt-out in SDK 55+) | Legacy is removed |

### Navigation

| Choice | Value | Why |
|--------|-------|-----|
| Router | Expo Router (file-based) | Official Expo recommendation, built on React Navigation v7, universal deep linking for free, less boilerplate |
| React Navigation directly | Only when integrating into an existing RN app that already uses it | Expo Router wraps React Navigation internally; installing both produces version conflicts and duplicate providers |

### State Management

| Choice | Value | Why |
|--------|-------|-----|
| Client state | Zustand | Minimal boilerplate, hooks-based, tiny bundle. No Redux ceremony. |
| Server state | TanStack Query | Caching, background refetch, loading/error states for free |
| Context | Auth and theme providers only — thin wrappers | Context re-renders every consumer on any change; frequently-updating state belongs in Zustand |

Zustand owns state that lives entirely in the app; TanStack Query owns everything that comes
from or goes to a server. **`rn-component-patterns` owns the full state placement table** —
consult it whenever the home for a piece of state is unclear.

### Styling

| Choice | Value | Why |
|--------|-------|-----|
| Primary | NativeWind (Tailwind for RN) | Utility-first, familiar from web, good Expo DX |
| Fallback | `StyleSheet.create` | For RN style props NativeWind doesn't cover |
| Component library | None by default | Add on demand rather than pre-installing a UI kit |

NativeWind is a default, not a mandate — confirm the user is comfortable with Tailwind first
(see the decision gates).

**Read `references/backend-and-auth.md`** when the user names or needs a backend or auth
provider — it covers Supabase / Firebase / custom-API tradeoffs, Clerk vs provider-native auth,
and what each choice implies for the scaffold.

---

## Decision Gates — Resolve Before Building

Check these before generating any files. Unresolved gates create rework.

| Decision | When to ask | Default if user says "just pick" |
|----------|-------------|----------------------------------|
| **Auth needed?** | User mentions login, signup, accounts, protected content | No auth. Scaffold the `(auth)/` group only on request. |
| **Auth provider** | Auth confirmed, provider unnamed | Clerk (best Expo DX). If a backend exists, match it (Supabase → Supabase Auth). |
| **Backend / API** | User describes data that persists or syncs | Backend-agnostic scaffold with placeholder URLs in `.env.example`. Ask what they plan to use. |
| **Styling approach** | Always, before installing NativeWind | Ask: "Tailwind/NativeWind, or plain StyleSheet?" Install NativeWind only once confirmed. |
| **Tab structure** | User described the app's purpose but not its screens | Propose 3–4 tabs from the domain and confirm before creating route files. |

When the user says "you decide", take the rightmost column and **state each choice explicitly**
so they can override. Auth provider and backend are always announced, never silent.

Auth changes the routing structure (protected vs public route groups), so scaffold it during
initial setup rather than retrofitting.

---

## Folder Structure

`/src/app` contains ONLY route files. Everything else lives outside it.

```
my-app/
├── app.json                     # Expo config (stays at root)
├── metro.config.js              # Metro bundler config (stays at root)
├── tsconfig.json                # TypeScript config (stays at root)
├── package.json
├── .env                         # Local env vars (EXPO_PUBLIC_ prefix for client)
├── .env.example                 # Committed, documents required vars
├── src/
│   ├── app/                     # ROUTES ONLY — Expo Router file-based routing
│   │   ├── _layout.tsx          # Root layout (providers, fonts, splash)
│   │   ├── index.tsx            # Entry route (/ path)
│   │   ├── (auth)/              # Route group: unauthenticated screens
│   │   │   ├── _layout.tsx
│   │   │   ├── login.tsx
│   │   │   └── register.tsx
│   │   ├── (tabs)/              # Route group: main tab navigation
│   │   │   ├── _layout.tsx      # Tab navigator config
│   │   │   ├── index.tsx        # First tab (home)
│   │   │   ├── explore.tsx
│   │   │   └── profile.tsx
│   │   └── [id].tsx             # Dynamic route example
│   ├── components/              # Shared UI components
│   │   ├── ui/                  # Primitives (Button, Input, Card)
│   │   └── features/            # Feature-specific composed components
│   ├── hooks/                   # Custom hooks
│   │   ├── queries/             # TanStack Query hooks (useProducts, useUser)
│   │   └── mutations/           # TanStack Query mutation hooks
│   ├── stores/                  # Zustand stores
│   │   ├── useAuthStore.ts      # Auth state (token, user, isAuthenticated)
│   │   └── useAppStore.ts       # App-level UI state (theme, onboarding)
│   ├── lib/                     # Shared utilities
│   │   ├── api.ts               # API client (fetch wrapper or axios instance)
│   │   ├── queryClient.ts       # TanStack Query client config
│   │   └── storage.ts           # AsyncStorage / SecureStore helpers
│   ├── constants/               # App-wide constants (colors, spacing, config)
│   │   └── theme.ts
│   ├── providers/               # Context providers (composed in root layout)
│   │   └── index.tsx            # Single Providers wrapper component
│   └── types/                   # Shared TypeScript types
│       └── index.ts
```

`src/app/` IS the screens directory — a `/screens` folder inside it is a structural mistake.
Screen components live in `src/components/features/<feature>/`, and route files re-export them
in one line:

```tsx
// src/app/(tabs)/explore.tsx
export { ExploreScreen as default } from '@/components/features/explore/ExploreScreen';
```

`rn-component-patterns` owns the component hierarchy rules this implies.

### Required Files — Always Generate These

| File | Purpose | Notes |
|------|---------|-------|
| `src/app/_layout.tsx` | Root layout | Wraps children in `<Providers>`, manages splash, loads auth token |
| `src/app/(tabs)/_layout.tsx` | Tab navigator | Defines every tab screen with icon and title |
| `src/app/(auth)/_layout.tsx` | Auth stack (if auth requested) | `Stack`, `headerShown: false` |
| `src/app/index.tsx` | Entry redirect | Auth: redirect by auth state. No auth: redirect to `(tabs)`. |
| `src/providers/index.tsx` | Providers wrapper | Includes `QueryClientProvider` |
| `src/lib/queryClient.ts` | TanStack Query config | Sets `refetchOnWindowFocus: false` |
| `src/stores/useAppStore.ts` | Base Zustand store | Typed skeleton at minimum |
| `.env.example` | Env var documentation | Every `EXPO_PUBLIC_` var the app reads appears here |

`.env` holds real values and stays out of git; `.env.example` holds the key names. Anything
prefixed `EXPO_PUBLIC_` is embedded in the JS bundle and readable by anyone with the app —
`secrets-env-management` covers what may and may not carry that prefix.

---

## Project Init Sequence

### 1. Create the project

```bash
npx create-expo-app@latest my-app --template default@sdk-55
cd my-app
```

The SDK 55 default template ships Expo Router with `/src/app`, TypeScript, New Architecture, and
native tabs on iOS/Android with custom tabs on web.

### 2. Install core dependencies

```bash
npx expo install zustand @tanstack/react-query
npx expo install expo-secure-store   # For token storage
npx expo install expo-constants      # For env/config access
```

**`npx expo install` for every Expo-compatible package** — it resolves the version matching the
SDK. Plain `npm install` pulls versions that break at runtime rather than at install time.

### 3. Install NativeWind (if confirmed)

```bash
npx expo install nativewind tailwindcss
```

Then follow https://www.nativewind.dev/getting-started/expo-router — v4 setup requires Metro
config changes and a `global.css`, and the steps change between versions, so use the live guide
rather than a remembered config.

### 4. TanStack Query client

```tsx
// src/lib/queryClient.ts
import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5,    // 5 minutes
      gcTime: 1000 * 60 * 30,      // 30 minutes (formerly cacheTime)
      retry: 2,
      refetchOnWindowFocus: false,  // web default; on mobile it refetches on every foreground
    },
  },
});
```

### 5. Providers wrapper

```tsx
// src/providers/index.tsx
import { QueryClientProvider } from '@tanstack/react-query';
import { queryClient } from '@/lib/queryClient';

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  );
}
```

### 6. Root layout

The root layout does three things: wraps providers, manages the splash screen, and (with auth)
performs the initial token read.

```tsx
// src/app/_layout.tsx — no auth
import { useEffect } from 'react';
import { Stack } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { Providers } from '@/providers';

SplashScreen.preventAutoHideAsync();

export default function RootLayout() {
  useEffect(() => {
    // Hide splash once fonts/config are loaded — swap for a useFonts() check
    // if the project loads custom fonts.
    SplashScreen.hideAsync();
  }, []);

  return (
    <Providers>
      <Stack>
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
      </Stack>
    </Providers>
  );
}
```

With auth, the splash screen stays up until the async SecureStore read resolves, so `index.tsx`
never redirects on a half-loaded auth state — the with-auth layout is in
`references/auth-routing.md`.

### 7. Sample Zustand store

```tsx
// src/stores/useAppStore.ts
import { create } from 'zustand';

interface AppState {
  hasCompletedOnboarding: boolean;
  setOnboardingComplete: () => void;
}

export const useAppStore = create<AppState>((set) => ({
  hasCompletedOnboarding: false,
  setOnboardingComplete: () => set({ hasCompletedOnboarding: true }),
}));
```

**Store splitting:** one store per domain concern. The test — if two pieces of state are never
read together in the same component, they belong in separate stores. A store is a single
`create()` call, not an architectural commitment. **Split any store whose interface exceeds ~50
lines.**

| Store | Owns | Example state |
|-------|------|---------------|
| `useAuthStore` | Auth tokens, user identity, login state | `token`, `isAuthenticated`, `user` |
| `useAppStore` | App-level UI state | `hasCompletedOnboarding`, `theme`, `isOffline` |
| `use[Feature]Store` | Feature-specific transient state | Active workout sets, compose draft, filters |

### 8. Path aliases

The SDK 55 template configures `@/*` → `./src/*` in `tsconfig.json`. Verify it, and use the
`@/` prefix in every import:

```json
{ "compilerOptions": { "paths": { "@/*": ["./src/*"] } } }
```

### 9. First query hook

Add one query hook so the data layer is proven end-to-end before feature work starts.
`rn-component-patterns` owns the query hook template and rules.

---

## SDK 55 API Changes That Break Copied Code

Examples on the web and in model memory predate these. Check each when scaffolding:

| Old | Current |
|---|---|
| `expo-av` | `expo-audio` and `expo-video` (`expo-av` deprecated in SDK 53, gone by SDK 55) |
| `import * as FileSystem from 'expo-file-system'` (legacy API) | New API is the default export in SDK 54+; legacy call sites import `expo-file-system/legacy` |
| Committed `android/` and `ios/` directories | Continuous Native Generation produces them at build time; they stay out of git |
| `androidStatusBar.backgroundColor` in app.json | No-ops under edge-to-edge (see `rn-platform-gotchas`) |

---

## Dev Environment

This stack targets WSL2/Ubuntu + one physical iPhone + no macOS. **`expo-build-deploy` owns the
device workflow** — Expo Go limits, when to move to a development build, ADB bridging from
Windows, EAS Build for iOS, and `--tunnel` when the phone and WSL2 aren't on one network.

At scaffold time only two things matter: iOS device builds require EAS (cloud), and Expo Go is
fine until the project needs push notifications, OAuth, or any custom native module — plan the
move to a development build early rather than after it blocks something.

---

## Auth-Aware Routing

**Read `references/auth-routing.md`** whenever auth is part of the scaffold. It holds the
`(auth)/` vs `(tabs)/` route group structure, the root `index.tsx` redirect, `useAuthStore` with
SecureStore, the with-auth root layout, the `(auth)/_layout.tsx` stack, and the API client that
turns a 401 into a global logout.

Short version: root `index.tsx` reads `useAuthStore.isAuthenticated` and redirects to `(tabs)`
or `(auth)/login`; the root layout holds the splash until the token check resolves; the API
client clears the token on 401 so expiry is handled in one place.

---

## Checklist: Is the Scaffold Complete?

Verify before handing off to implementation. Every box is a command that was run or a file that
was opened — not an assumption about what the template produced.

**Structure & config:**
- [ ] `npx expo start` runs without errors
- [ ] `npx tsc --noEmit` passes
- [ ] `@/` path alias resolves in imports
- [ ] `.env.example` documents every var the app reads
- [ ] No `android/` or `ios/` directories committed (managed workflow)
- [ ] Every Expo-compatible package was installed with `npx expo install`
- [ ] No `react-navigation` packages in `package.json` alongside Expo Router

**Required files exist with correct content:**
- [ ] `src/app/_layout.tsx` — wraps in `<Providers>`, manages splash
- [ ] `src/app/(tabs)/_layout.tsx` — every tab declared with a title
- [ ] `src/app/(auth)/_layout.tsx` — present if auth was requested (Stack, no header)
- [ ] `src/app/index.tsx` — redirects to the correct route group
- [ ] `src/providers/index.tsx` — includes `QueryClientProvider`
- [ ] `src/lib/queryClient.ts` — includes `refetchOnWindowFocus: false`

**State & routing:**
- [ ] At least one Zustand store with a typed interface, split by domain
- [ ] Server data lives in TanStack Query, not Zustand
- [ ] Route files are one-line re-exports
- [ ] Every route group has its own `_layout.tsx`
- [ ] Tab navigation renders on the default route
- [ ] With auth: splash stays visible until the token check completes

**If every box passes, report the scaffold as complete and stop** — a clean scaffold needs no
invented follow-up work. From here, `task-doc-generator` turns the first feature into a task doc,
and `expo-build-deploy` produces the first development build.
