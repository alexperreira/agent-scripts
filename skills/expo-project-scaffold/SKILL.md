---
name: expo-project-scaffold
description: >
  Scaffolds new Expo/React Native projects with opinionated defaults: SDK 55+, Expo Router,
  Zustand + TanStack Query, TypeScript, and a scalable folder structure. Use this skill whenever
  someone is starting a new mobile app, initializing an Expo project, asking "how should I set up
  my app", "what's the right folder structure", "which navigation library should I use", "what
  state management for React Native", or adding a major new feature area that needs new
  screens/routes/navigation. Also trigger proactively when a conversation involves building a
  mobile app from scratch, choosing between React Native libraries, or when Claude Code is about
  to run `create-expo-app` without guidance. Covers project init, folder structure, dependency
  selection, navigation setup, state management wiring, and dev environment config for a
  WSL2/Ubuntu + single iPhone + no macOS setup. If someone asks about build/deploy or platform
  gotchas, point them to the companion skills instead.
---

# Expo Project Scaffold

Opinionated project setup for Expo/React Native apps. Every decision here has a reason — if
you're generating a scaffold, follow these defaults unless the user explicitly overrides them.

The goal: a new project should be buildable, navigable, and data-ready within the first session.
No placeholder architecture that needs to be ripped out later.

---

## When NOT to Use This Skill

- Modifying an existing project's architecture → use `rn-component-patterns`
- Build, deploy, or OTA workflow → use `expo-build-deploy`
- iOS/Android platform differences or permission issues → use `rn-platform-gotchas`
- Adding a single new screen to an existing app → probably doesn't need this skill

---

## Opinionated Defaults (and Why)

These are the standard choices. Override only when the user gives a specific reason.

### SDK & Runtime

| Choice | Value | Why |
|--------|-------|-----|
| Expo SDK | 55+ (latest stable) | New Architecture only, `/src/app` default, React 19.2 |
| React Native | 0.83+ (bundled with SDK 55) | Shipped with SDK, don't pin independently |
| TypeScript | Always | Non-negotiable for any project Claude Code will touch |
| New Architecture | Enabled (default, no opt-out in SDK 55+) | Legacy is removed |

### Navigation

| Choice | Value | Why |
|--------|-------|-----|
| Router | Expo Router (file-based) | Official Expo recommendation, built on React Navigation v7, universal deep linking for free, file-based routing reduces boilerplate and is familiar to web devs |
| When to use React Navigation directly | Almost never | Only if integrating into an existing RN app that already uses it. For new projects, always Expo Router. |

### State Management

| Choice | Value | Why |
|--------|-------|-----|
| Client state | Zustand | Minimal boilerplate, hooks-based, tiny bundle, scales well. No Redux ceremony. |
| Server state | TanStack Query (React Query) | Caching, background refetching, loading/error states for free. Don't hand-roll `useEffect` + `useState` for API calls. |
| When to use Context | Auth provider, theme provider — thin wrappers only | Context re-renders all consumers on any change. Never put frequently-updating state in Context. |

**The split matters.** Zustand owns UI state, user preferences, form drafts, selected items — anything
that lives entirely in the app. TanStack Query owns everything that comes from or goes to a server.
If Claude Code puts API response data into a Zustand store, that's a bug.

### Styling

| Choice | Value | Why |
|--------|-------|-----|
| Primary | NativeWind (Tailwind CSS for RN) | Utility-first, familiar from web, good DX with Expo |
| Fallback | StyleSheet.create | When NativeWind doesn't support a specific RN style prop |
| Component library | None by default | Add as needed. Don't pre-install UI kits. |

If the user is unfamiliar with Tailwind or prefers StyleSheet, don't force NativeWind. Ask first.

### Data & Backend

Don't pre-commit to a backend. The scaffold should be backend-agnostic. However, when the user
specifies one, the most common Expo-compatible options are:

- **Supabase** — Postgres + auth + realtime, good free tier, RN SDK works
- **Firebase** — If the user already knows it. Heavier setup with Expo.
- **Custom API** — TanStack Query works with any REST or GraphQL endpoint

### Auth

Don't scaffold auth unless the user asks for it. When they do:

- **Clerk** — Best DX for Expo, prebuilt components, handles OAuth flows
- **Supabase Auth** — If already using Supabase for the backend
- **Firebase Auth** — If already using Firebase

Auth affects routing structure (protected vs. public route groups), so if auth is requested,
scaffold it during initial setup, not after.

---

## Decision Gates — STOP and Ask Before Building

Before generating any files, check whether these decisions are resolved. If not, **ask the user
before proceeding.** Do not assume defaults for these — wrong guesses here create rework.

| Decision | When to ask | Default if user says "just pick" |
|----------|-------------|----------------------------------|
| **Auth needed?** | User mentions login, signup, accounts, protected content | No auth. Only scaffold `(auth)/` group if explicitly requested. |
| **Auth provider** | User confirmed auth is needed but didn't name a provider | Recommend Clerk (best Expo DX). If user has a backend already, match it (Supabase → Supabase Auth, Firebase → Firebase Auth). |
| **Backend / API** | User describes data that needs persistence or sync | Backend-agnostic scaffold. Use placeholder API URLs in `.env.example`. Ask what they're using or planning to use. |
| **Styling approach** | Always, before installing NativeWind | Ask: "Are you comfortable with Tailwind / NativeWind, or do you prefer plain StyleSheet?" Default to NativeWind only if confirmed. |
| **Tab structure** | User describes the app's purpose but not its screens | Propose 3-4 tabs based on the domain and ask for confirmation before creating route files. |

**If the user says "just set it up" or "you decide"**, use the defaults in the rightmost column
and state what you chose so they can override. Never silently pick an auth provider or backend.

---

## Folder Structure

This is the canonical structure for a new Expo Router project on SDK 55+. The `/src/app` directory
contains ONLY route files. All other code lives outside it.

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

### Rules for Route Files

Route files in `src/app/` should be **thin**. They import a screen component and re-export it:

```tsx
// src/app/(tabs)/explore.tsx — GOOD: thin route file
export { ExploreScreen as default } from '@/components/features/explore/ExploreScreen';
```

```tsx
// src/app/(tabs)/explore.tsx — BAD: business logic in route file
export default function ExploreScreen() {
  const [data, setData] = useState([]);
  useEffect(() => { fetch('/api/items').then(... ) }, []);
  // 200 lines of JSX...
}
```

Why: route files define navigation structure. Screen components define UI and behavior. Mixing
them makes refactoring navigation painful and makes screens untestable in isolation.

### Required Files — Always Generate These

Every scaffold must produce these files. CC tends to skip layout files and the providers wrapper
when they aren't explicitly listed. Do not rely on the SDK template for any of these — generate
them with the correct content even if the template includes a version.

| File | Purpose | Notes |
|------|---------|-------|
| `src/app/_layout.tsx` | Root layout | Must wrap children in `<Providers>`, handle splash screen, load auth token |
| `src/app/(tabs)/_layout.tsx` | Tab navigator config | Must define all tab screens with icons and titles |
| `src/app/(auth)/_layout.tsx` | Auth stack config (if auth requested) | Stack navigator, `headerShown: false` |
| `src/app/index.tsx` | Entry route / redirect | If auth: redirect based on auth state. If no auth: redirect to `(tabs)`. |
| `src/providers/index.tsx` | Providers wrapper | Must include `QueryClientProvider`. Add other providers here as needed. |
| `src/lib/queryClient.ts` | TanStack Query config | Must set `refetchOnWindowFocus: false` for mobile |
| `src/stores/useAppStore.ts` | Base Zustand store | At minimum, a typed skeleton |
| `.env.example` | Documents all env vars | Every `EXPO_PUBLIC_` var the app uses must appear here |

---

## Project Init Sequence

When scaffolding a new project, follow this exact order:

### 1. Create the project

```bash
npx create-expo-app@latest my-app --template default@sdk-55
cd my-app
```

The SDK 55 default template already includes:
- Expo Router with `/src/app` structure
- TypeScript
- New Architecture enabled
- Native tabs on iOS/Android, custom tabs on web

### 2. Install core dependencies

```bash
npx expo install zustand @tanstack/react-query
npx expo install expo-secure-store   # For token storage
npx expo install expo-constants      # For env/config access
```

Always use `npx expo install` instead of `npm install` for Expo-compatible packages. It resolves
the correct version for your SDK.

### 3. Install NativeWind (if using)

Follow the official NativeWind v4 setup guide — it requires Metro config changes and a
`global.css` file. Don't hand-roll the config; it changes between versions.

```bash
npx expo install nativewind tailwindcss
```

Then follow: https://www.nativewind.dev/getting-started/expo-router

### 4. Set up the TanStack Query client

```tsx
// src/lib/queryClient.ts
import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5,    // 5 minutes
      gcTime: 1000 * 60 * 30,      // 30 minutes (formerly cacheTime)
      retry: 2,
      refetchOnWindowFocus: false,  // Not useful on mobile
    },
  },
});
```

### 5. Set up the Providers wrapper

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

### 6. Wire providers into root layout

The root layout handles three things: provider wrapping, splash screen management, and (if auth
is scaffolded) initial auth token loading. Use the version that matches the project:

**Without auth:**
```tsx
// src/app/_layout.tsx
import { useEffect } from 'react';
import { Stack } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { Providers } from '@/providers';

SplashScreen.preventAutoHideAsync();

export default function RootLayout() {
  useEffect(() => {
    // Hide splash once fonts/config are loaded
    // Replace with useFonts() check if loading custom fonts
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

**With auth (splash stays until token is checked):**
```tsx
// src/app/_layout.tsx
import { useEffect } from 'react';
import { Stack } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { Providers } from '@/providers';
import { useAuthStore } from '@/stores/useAuthStore';

SplashScreen.preventAutoHideAsync();

export default function RootLayout() {
  const loadToken = useAuthStore((s) => s.loadToken);
  const isLoading = useAuthStore((s) => s.isLoading);

  useEffect(() => {
    loadToken();
  }, []);

  useEffect(() => {
    if (!isLoading) {
      SplashScreen.hideAsync();
    }
  }, [isLoading]);

  return (
    <Providers>
      <Stack>
        <Stack.Screen name="index" options={{ headerShown: false }} />
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen name="(auth)" options={{ headerShown: false }} />
      </Stack>
    </Providers>
  );
}
```

The splash screen stays visible while `isLoading` is true (SecureStore async read). Once the
token check completes, splash hides and `index.tsx` redirects to the correct route group.

### 7. Create a sample Zustand store

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

**When to split Zustand stores:** One store per domain concern. The test: if two pieces of state
are never read together in the same component, they belong in separate stores. Zustand stores
are cheap — creating a new one is a single `create()` call, not an architectural decision.

Common split pattern for a scaffold:

| Store | Owns | Example state |
|-------|------|---------------|
| `useAuthStore` | Auth tokens, user identity, login state | `token`, `isAuthenticated`, `user` |
| `useAppStore` | App-level UI state | `hasCompletedOnboarding`, `theme`, `isOffline` |
| `use[Feature]Store` | Feature-specific transient state | Active workout sets, compose draft, filter selections |

Do NOT create a single god store. If a store file exceeds ~50 lines of interface definition,
it's time to split.

### 8. Create a sample query hook

```tsx
// src/hooks/queries/useExample.ts
import { useQuery } from '@tanstack/react-query';

async function fetchExample(): Promise<{ message: string }> {
  const response = await fetch('https://api.example.com/hello');
  if (!response.ok) throw new Error('Network response was not ok');
  return response.json();
}

export function useExample() {
  return useQuery({
    queryKey: ['example'],
    queryFn: fetchExample,
  });
}
```

### 9. Set up path aliases

The SDK 55 template already configures `@/*` → `./src/*` in `tsconfig.json`. Verify it exists:

```json
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```

All imports should use `@/` prefix: `import { Button } from '@/components/ui/Button'`.

---

## Dev Environment Notes (WSL2 + iPhone + No macOS)

This section applies specifically to a WSL2/Ubuntu development setup with a physical iPhone
and no macOS machine.

- **Expo Go** is fine for early development but has limitations (no custom native modules, push
  notifications removed in SDK 53+). Plan to move to development builds early.
- **Android Emulator** works in WSL2 via Android Studio installed on Windows with ADB bridge.
  Set `ANDROID_HOME` in WSL2 to point to the Windows SDK path.
- **iOS builds** require EAS Build (cloud) — you cannot build iOS locally without macOS.
  `eas build --platform ios` handles this.
- **Testing on physical iPhone**: Use Expo Go for dev, EAS Build + internal distribution or
  TestFlight for anything requiring native modules.
- **Hot reload**: Works over the local network. Make sure WSL2 and iPhone are on the same
  network, or use `--tunnel` flag with Expo CLI.

---

## Common Footguns

Things Claude Code (or any implementation agent) gets wrong during scaffold:

1. **Installing `react-navigation` alongside Expo Router.** Don't. Expo Router wraps React
   Navigation internally. Adding both creates version conflicts and duplicate providers.

2. **Putting business logic in route files.** Route files should be thin re-exports. The moment
   a route file imports `useState` or `useEffect`, something is wrong.

3. **Using `npm install` instead of `npx expo install`.** Expo install resolves SDK-compatible
   versions. Regular npm install can pull incompatible versions.

4. **Creating a `/screens` directory inside `/src/app`.** The `app` directory IS the screens
   directory in Expo Router. Screen components live in `/src/components/features/`.

5. **Storing server data in Zustand.** If the data came from an API, it belongs in TanStack
   Query. Zustand is for client-only state.

6. **Forgetting `refetchOnWindowFocus: false`.** This React Query default makes sense on web
   but causes unnecessary refetches on mobile when the app comes to foreground.

7. **Using `expo-av` for audio/video.** Deprecated and removed in SDK 55. Use `expo-audio`
   and `expo-video` instead.

8. **Not setting up `.env.example`.** Every env var the app needs should be documented here.
   Claude Code will add secrets to `.env` without documenting them unless told otherwise.

9. **Importing from `expo-file-system` without updating.** In SDK 54+, the default export
   changed to the new API. Legacy imports need `expo-file-system/legacy`.

10. **Creating `android/` and `ios/` directories in a managed workflow project.** If using
    Continuous Native Generation (the default), these directories are generated at build time
    and should not be committed.

---

## Auth-Aware Routing Pattern

When auth is needed, read `references/auth-routing.md` for the full pattern including:
- Route group structure (`(auth)/` vs `(tabs)/`)
- Root `index.tsx` redirect logic
- `useAuthStore` with SecureStore (Zustand)
- `(auth)/_layout.tsx` stack config
- API client with automatic 401 → logout handling

The short version: root `index.tsx` checks `useAuthStore.isAuthenticated` and redirects to
either `(tabs)` or `(auth)/login`. The root layout holds the splash screen until the async
token check completes. Auth expiry (401) is handled globally in the API client.

---

## Checklist: Is the Scaffold Complete?

Before handing off to implementation, verify:

**Structure & config:**
- [ ] `npx expo start` runs without errors
- [ ] TypeScript compiles with no errors (`npx tsc --noEmit`)
- [ ] `@/` path alias resolves correctly in imports
- [ ] `.env.example` exists and documents all required vars
- [ ] No `android/` or `ios/` directories committed (if managed workflow)
- [ ] `npx expo install` was used for all Expo-compatible packages

**Required files exist and have correct content:**
- [ ] `src/app/_layout.tsx` — wraps in `<Providers>`, handles splash screen
- [ ] `src/app/(tabs)/_layout.tsx` — defines tab screens with titles
- [ ] `src/app/(auth)/_layout.tsx` — exists if auth was requested (Stack, no header)
- [ ] `src/app/index.tsx` — redirects to correct route group
- [ ] `src/providers/index.tsx` — includes `QueryClientProvider`
- [ ] `src/lib/queryClient.ts` — includes `refetchOnWindowFocus: false`

**State management:**
- [ ] At least one Zustand store exists with typed interface
- [ ] No API/server data stored in Zustand (belongs in TanStack Query)
- [ ] Zustand stores are split by domain (no god store)

**Routing:**
- [ ] Tab navigation renders on the default route
- [ ] Route files are thin (no business logic in `src/app/`)
- [ ] Every route group has its own `_layout.tsx`
- [ ] If auth: splash screen stays visible until token check completes
