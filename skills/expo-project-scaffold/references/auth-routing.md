# Auth-Aware Routing Pattern

Read this file when scaffolding a project that includes authentication. The pattern uses Expo
Router's redirect mechanism with route groups to separate public and protected screens.

---

## Route Structure

```
src/app/
├── _layout.tsx          # Root: loads auth state, holds splash while loading
├── index.tsx            # Redirects to (tabs) or (auth) based on auth state
├── (auth)/              # Public routes — login, register, forgot password
│   ├── _layout.tsx      # Stack navigator, no header
│   └── ...
└── (tabs)/              # Protected routes — main app
    ├── _layout.tsx      # Tab navigator
    └── ...
```

## Root Layout — Hold the Splash Until the Token Read Resolves

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
  }, [loadToken]);

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

The SecureStore read is async. Holding the splash until it resolves is what keeps a logged-in
user from seeing a flash of the login screen on cold start.

## Root Index — Redirect Based on Auth State

```tsx
// src/app/index.tsx
import { Redirect } from 'expo-router';
import { useAuthStore } from '@/stores/useAuthStore';

export default function Index() {
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);

  if (isAuthenticated) {
    return <Redirect href="/(tabs)" />;
  }

  return <Redirect href="/(auth)/login" />;
}
```

By the time `index.tsx` renders, the token check has completed, so `isAuthenticated` is
trustworthy. This is also why redirects belong here rather than in a screen's `useEffect`.

## Auth Store — Zustand + SecureStore

```tsx
// src/stores/useAuthStore.ts
import { create } from 'zustand';
import * as SecureStore from 'expo-secure-store';

interface AuthState {
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  setToken: (token: string) => Promise<void>;
  clearToken: () => Promise<void>;
  loadToken: () => Promise<void>;
}

export const useAuthStore = create<AuthState>((set) => ({
  token: null,
  isAuthenticated: false,
  isLoading: true,

  setToken: async (token) => {
    await SecureStore.setItemAsync('auth_token', token);
    set({ token, isAuthenticated: true });
  },

  clearToken: async () => {
    await SecureStore.deleteItemAsync('auth_token');
    set({ token: null, isAuthenticated: false });
  },

  loadToken: async () => {
    const token = await SecureStore.getItemAsync('auth_token');
    set({ token, isAuthenticated: !!token, isLoading: false });
  },
}));
```

**Key details:**
- `isLoading` starts `true` — the splash screen depends on it.
- Tokens go in `SecureStore` (Keychain/Keystore), not `AsyncStorage`.
- `getState()` reads the current token outside React, which is how the API client attaches the
  `Authorization` header:

```tsx
// src/lib/api.ts — non-React usage of Zustand
const token = useAuthStore.getState().token;
```

## Auth Layout

```tsx
// src/app/(auth)/_layout.tsx
import { Stack } from 'expo-router';

export default function AuthLayout() {
  return (
    <Stack screenOptions={{ headerShown: false }} />
  );
}
```

## 401 Handling in the API Client

A 401 clears the token, which re-renders the root redirect and lands the user on login. Handling
it here means no screen needs its own 401 branch:

```tsx
// src/lib/api.ts
import { useAuthStore } from '@/stores/useAuthStore';

const API_BASE = process.env.EXPO_PUBLIC_API_URL;

export async function apiFetch(path: string, options: RequestInit = {}) {
  const token = useAuthStore.getState().token;

  const response = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    },
  });

  if (response.status === 401) {
    useAuthStore.getState().clearToken();
    throw new Error('Unauthorized');
  }

  if (!response.ok) {
    throw new Error(`API error: ${response.status}`);
  }

  return response.json();
}
```

This is the minimal version. When the API uses the standard `{ ok, data|error, meta }` envelope,
`apiFetch` also unwraps `data` and surfaces `error.code` — `api-contract-design` owns that
envelope and the error-code registry, and `auth-authorization-audit` covers whether a 401-clears-
token flow is sufficient for the app's threat model (refresh tokens, forced logout, session
fixation).
