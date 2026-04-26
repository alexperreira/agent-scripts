# Auth-Aware Routing Pattern

Read this file when scaffolding a project that includes authentication. This pattern uses
Expo Router's redirect mechanism with route groups to separate public and protected screens.

---

## Route Structure

```
src/app/
├── _layout.tsx          # Root: loads auth state, shows splash while loading
├── index.tsx            # Redirects to (tabs) or (auth) based on auth state
├── (auth)/              # Public routes — login, register, forgot password
│   ├── _layout.tsx      # Stack navigator, no header
│   └── ...
└── (tabs)/              # Protected routes — main app
    ├── _layout.tsx      # Tab navigator
    └── ...
```

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

The root layout's splash screen stays visible while `isLoading` is true (see step 6 in the
init sequence). By the time `index.tsx` renders, the token check has already completed and
`isAuthenticated` is reliable.

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
- `isLoading` starts `true` — splash screen stays visible until `loadToken()` completes.
- `SecureStore` is used instead of `AsyncStorage` because auth tokens are sensitive.
- `getState()` can be called outside React components (e.g., in an API client) to read the
  current token for `Authorization` headers:

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

## 401 Handling in API Client

When the API returns a 401, clear the token — this triggers a re-render that redirects back
to the login screen automatically via the root `index.tsx` redirect:

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

This pattern means auth expiry is handled globally — no individual screen needs to check
for 401s or redirect to login.
