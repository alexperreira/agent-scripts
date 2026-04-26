---
name: rn-component-patterns
description: >
  Opinionated patterns for building screens, components, hooks, and managing data flow in
  Expo/React Native apps. Use this skill whenever someone is building a new screen or feature,
  asking "how should I structure this component", "where does this logic go", "should this be a
  hook or a component", "how do I handle loading/error states", or reviewing component code for
  architecture issues. Also trigger proactively when Claude Code is about to write a screen
  component with inline data fetching, create a god component with 200+ lines, put business logic
  in a route file, or mix server state with client state. Covers component hierarchy, custom hook
  patterns, state placement rules, performance basics, and TypeScript conventions for
  Expo Router + Zustand + TanStack Query projects. If the question is about project setup or
  scaffolding, use `expo-project-scaffold` instead. If it's about build/deploy, use
  `expo-build-deploy`. If it's about iOS/Android platform differences, use `rn-platform-gotchas`.
---

# React Native Component Patterns

Opinionated patterns for building screens and components in Expo/React Native apps that use
Expo Router, Zustand, and TanStack Query. These patterns assume the folder structure from the
`expo-project-scaffold` skill is in place.

The goal: every component has one job, every piece of state has one home, and CC can modify
any screen without breaking the rest of the app.

---

## Component Hierarchy

There are exactly three levels of components. Don't invent more.

### 1. Route files (`src/app/`)

Thin re-exports only. No imports of `useState`, `useEffect`, or any hook. No JSX beyond
a single default export.

```tsx
// src/app/(tabs)/feed.tsx
export { FeedScreen as default } from '@/components/features/feed/FeedScreen';
```

If a route file contains anything else, it's wrong.

### 2. Screen components (`src/components/features/<feature>/`)

Each screen is a single file that composes UI from smaller components and wires up data.
A screen component:
- Calls custom hooks (queries, mutations, stores)
- Handles loading/error/empty states
- Composes feature components and UI primitives
- Does NOT contain reusable UI logic — that belongs in hooks or sub-components

```tsx
// src/components/features/feed/FeedScreen.tsx
import { View, Text } from 'react-native';
import { useFeed } from '@/hooks/queries/useFeed';
import { PostCard } from './PostCard';
import { LoadingSpinner } from '@/components/ui/LoadingSpinner';
import { ErrorMessage } from '@/components/ui/ErrorMessage';
import { EmptyState } from '@/components/ui/EmptyState';

export function FeedScreen() {
  const { data: posts, isLoading, error, refetch } = useFeed();

  if (isLoading) return <LoadingSpinner />;
  if (error) return <ErrorMessage message="Couldn't load feed" onRetry={refetch} />;
  if (!posts?.length) return <EmptyState message="No posts yet" />;

  return (
    <View>
      {posts.map((post) => (
        <PostCard key={post.id} post={post} />
      ))}
    </View>
  );
}
```

**Screen component rules:**
- One screen per file
- File lives in `src/components/features/<feature>/`
- Name matches the route: `feed.tsx` route → `FeedScreen.tsx` component
- Max ~150 lines. If longer, extract sub-components into the same directory.

### 3. UI components

Split into two categories:

**Primitives (`src/components/ui/`)** — Generic, reusable across any feature:
- `Button`, `Input`, `Card`, `Avatar`, `LoadingSpinner`, `ErrorMessage`, `EmptyState`
- Accept only props, no feature-specific logic
- No direct hook calls to stores or queries

**Feature components (`src/components/features/<feature>/`)** — Specific to one feature:
- `PostCard`, `WorkoutRow`, `ProfileHeader`
- May call feature-specific hooks
- Live alongside their screen component

The test: "Could another feature use this component unchanged?" If yes → `ui/`. If no →
`features/<feature>/`.

---

## Custom Hook Patterns

Hooks are where logic lives. Components render; hooks think.

### Query hooks (`src/hooks/queries/`)

One hook per data entity or query. Wraps TanStack Query's `useQuery`.

```tsx
// src/hooks/queries/useWorkouts.ts
import { useQuery } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api';
import type { Workout } from '@/types/workout';

export function useWorkouts() {
  return useQuery({
    queryKey: ['workouts'],
    queryFn: (): Promise<Workout[]> => apiFetch('/workouts'),
  });
}

// For a single entity by ID:
export function useWorkout(id: string) {
  return useQuery({
    queryKey: ['workouts', id],
    queryFn: (): Promise<Workout> => apiFetch(`/workouts/${id}`),
    enabled: !!id,  // Don't fire if id is empty
  });
}
```

**Query hook rules:**
- Always type the return with a Promise generic
- Always use `enabled` for conditional queries (don't wrap in `if`)
- Query keys should be hierarchical: `['workouts']` → `['workouts', id]`
- Never call `useQuery` inside a callback or condition — hooks must be top-level

### Mutation hooks (`src/hooks/mutations/`)

One hook per write operation. Wraps TanStack Query's `useMutation`.

```tsx
// src/hooks/mutations/useCreatePost.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api';
import type { Post, CreatePostInput } from '@/types/post';

export function useCreatePost() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: CreatePostInput): Promise<Post> =>
      apiFetch('/posts', {
        method: 'POST',
        body: JSON.stringify(input),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['feed'] });
    },
  });
}
```

**Mutation hook rules:**
- Always invalidate related queries in `onSuccess`
- Type both input and output
- For optimistic updates, use `onMutate` + `onError` rollback (see TanStack Query docs)
- The hook returns `{ mutate, mutateAsync, isPending, error }` — let the screen decide
  which to use

### Logic hooks (`src/hooks/`)

For non-data logic that multiple components share. These don't call TanStack Query.

```tsx
// src/hooks/useDebounce.ts
import { useState, useEffect } from 'react';

export function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debouncedValue;
}
```

**When to create a logic hook:** When the same `useState` + `useEffect` combination appears in
two or more components. One instance is not enough — don't pre-abstract.

---

## State Placement Rules

Every piece of state has exactly one correct home. This table is the decision tree:

| Question | Answer | State lives in... |
|----------|--------|-------------------|
| Does the data come from an API? | Yes | TanStack Query (`useQuery` / `useMutation`) |
| Is it UI state used by one component only? | Yes | Local `useState` in that component |
| Is it UI state shared across screens? | Yes | Zustand store |
| Is it form input state? | Yes | Local `useState` or a form library (React Hook Form) |
| Is it derived from other state? | Yes | `useMemo` — don't store it separately |
| Is it the URL / route params? | Yes | Expo Router (`useLocalSearchParams`, `useGlobalSearchParams`) |

**Route param type safety:** `useLocalSearchParams` returns `string | string[]` for each param
by default. Always pass a type generic and coerce to string when passing to a query hook:

```tsx
const { id } = useLocalSearchParams<{ id: string }>();
```

If a param could be an array (e.g., from a catch-all route), handle it explicitly:
```tsx
const rawId = useLocalSearchParams<{ id: string }>().id;
const id = Array.isArray(rawId) ? rawId[0] : rawId;
```

**Common mistakes CC makes:**
1. Fetching API data with `useEffect` + `useState` instead of `useQuery` — always wrong.
2. Putting a loading boolean in Zustand when TanStack Query already provides `isLoading`.
3. Creating a Zustand store for state that only one component uses — use `useState` instead.
4. Duplicating server data into Zustand "for convenience" — read from the query cache instead.
5. Storing derived values (filtered lists, computed totals) as state — use `useMemo`.

---

## Loading, Error, and Empty States

Every screen that fetches data must handle three non-happy states. Don't skip any of them.

### Pattern: Tri-state guard at the top of the screen

```tsx
export function FeedScreen() {
  const { data, isLoading, error, refetch } = useFeed();

  if (isLoading) return <LoadingSpinner />;
  if (error) return <ErrorMessage message="Couldn't load feed" onRetry={refetch} />;
  if (!data?.length) return <EmptyState message="No posts yet" />;

  // Happy path below — `data` is guaranteed non-null and non-empty
  return (/* ... */);
}
```

This pattern narrows the type: after the three guards, TypeScript knows `data` is defined
and non-empty. No optional chaining needed in the happy path.

### Variant: Single-entity screens (detail/profile views)

For screens that load one entity by ID (not a list), replace the empty state check with a
null/not-found guard:

```tsx
export function UserProfileScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { data: user, isLoading, error, refetch } = useUserProfile(id);

  if (isLoading) return <LoadingSpinner />;
  if (error) return <ErrorMessage message="Couldn't load profile" onRetry={refetch} />;
  if (!user) return <ErrorMessage message="User not found" />;

  // Happy path — `user` is guaranteed non-null
  return (/* ... */);
}
```

The difference: list screens check `!data?.length` (empty list), single-entity screens check
`!data` (entity doesn't exist). Don't use `EmptyState` for a missing entity — use `ErrorMessage`
with a descriptive message.

### Standard UI components for these states

Create these once in `src/components/ui/` and reuse everywhere:

| Component | Props | Purpose |
|-----------|-------|---------|
| `LoadingSpinner` | `size?`, `message?` | Centered spinner with optional text |
| `ErrorMessage` | `message`, `onRetry?` | Error text + retry button |
| `EmptyState` | `message`, `action?` | Illustration + message + optional CTA |

CC will skip the empty state component. It will render nothing or a blank screen when the
list is empty. Always include it.

---

## List Rendering

For any list longer than ~20 items, use `FlashList` (from `@shopify/flash-list`) instead
of `FlatList`. It's a drop-in replacement with significantly better scroll performance.

```tsx
import { FlashList } from '@shopify/flash-list';

<FlashList
  data={posts}
  renderItem={({ item }) => <PostCard post={item} />}
  estimatedItemSize={120}  // Required — estimate average item height in px
  keyExtractor={(item) => item.id}
/>
```

**List rules:**
- Always provide `keyExtractor` with a stable unique ID (not array index)
- Always set `estimatedItemSize` for FlashList — it won't work well without it
- For pull-to-refresh: use `refreshing` + `onRefresh` props, wire to TanStack Query's `refetch`
- For pagination: use TanStack Query's `useInfiniteQuery` + `onEndReached`

---

## TypeScript Conventions

### Props interfaces

Every component gets a named `Props` interface, not inline types.

```tsx
// GOOD
interface PostCardProps {
  post: Post;
  onPress?: (id: string) => void;
}

export function PostCard({ post, onPress }: PostCardProps) { /* ... */ }

// BAD — inline, unnamed, hard to export or extend
export function PostCard({ post, onPress }: { post: Post; onPress?: (id: string) => void }) {}
```

### Shared types (`src/types/`)

One file per domain entity. Export interfaces, not types (unless you need a union).

```tsx
// src/types/post.ts
export interface Post {
  id: string;
  author: User;
  content: string;
  createdAt: string;
  likes: number;
  comments: number;
}

export interface CreatePostInput {
  content: string;
}
```

**Type rules:**
- IDs are `string` (even if the backend uses numbers — it's safer for React keys)
- Dates are `string` (ISO 8601 from the API). Parse to Date objects only at display time.
- Never use `any`. If you don't know the type, use `unknown` and narrow it.
- Never use `enum`. Use string union types: `type Status = 'active' | 'archived'`.

---

## Performance Basics

Don't optimize prematurely, but don't ignore these free wins:

### `React.memo` — Use for list item components

```tsx
import { memo } from 'react';

interface PostCardProps {
  post: Post;
  onPress?: (id: string) => void;
}

export const PostCard = memo(function PostCard({ post, onPress }: PostCardProps) {
  return (/* ... */);
});
```

Wrap any component rendered inside a `FlashList` or `FlatList` `renderItem`. Don't wrap
screen components or components that always receive new props.

### `useCallback` — Use for callbacks passed to memoized children

```tsx
// In the parent screen
const handlePress = useCallback((id: string) => {
  router.push(`/post/${id}`);
}, []);
```

If you pass a function to a `memo`-wrapped child, wrap it in `useCallback` or the memo
is useless (new function reference every render).

### `useMemo` — Use for expensive computations

```tsx
const filteredPosts = useMemo(
  () => posts.filter((p) => p.author.id !== blockedUserId),
  [posts, blockedUserId]
);
```

Don't use `useMemo` for simple lookups, string concatenation, or single property access. Use it
for filtering, sorting, or transforming arrays — these are the most common valid use cases in
screens with lists. Rule of thumb: if the operation iterates over an array or involves `.filter()`,
`.map()`, `.sort()`, or `.reduce()`, wrap it in `useMemo`.

### What NOT to optimize

- Don't memoize everything — it adds complexity and memory overhead
- Don't use `useCallback` for handlers that aren't passed to `memo` children
- Don't split components just for performance — split for readability first

---

## Common Footguns

Things CC gets wrong at the component level:

1. **God components.** A 300-line component that fetches data, manages local state, handles
   navigation, and renders complex UI. Split it: data → hook, sub-sections → components.

2. **`useEffect` for data fetching.** Always use TanStack Query. The only valid `useEffect`
   in a screen is for one-time setup (loading fonts, checking auth, subscribing to
   app state changes).

3. **Inline styles everywhere.** Whether using NativeWind or StyleSheet, keep styles
   consistent. Don't mix `style={{ padding: 16 }}` with className or StyleSheet refs in the
   same component.

4. **Missing `key` prop or using array index.** Always use a stable unique ID. Array index
   causes bugs when list items are reordered, inserted, or deleted.

5. **Calling `router.push` inside `useEffect`.** Navigation side effects should happen in
   event handlers or the root index redirect. Not in `useEffect` — it causes race conditions
   and double-navigation.

6. **Ignoring the empty state.** CC renders a blank screen when the list is empty. Always
   handle `data.length === 0` explicitly.

7. **Prop drilling through 3+ levels.** If a prop passes through components that don't use
   it, either lift the hook call closer to where the data is needed, or use a Zustand store
   for shared UI state.

8. **Creating a new Zustand store for every piece of state.** Use `useState` for
   single-component state. Zustand is for state shared across multiple screens.

9. **Forgetting `enabled` on conditional queries.** If a query depends on a value that might
   be null (like a route param), use `enabled: !!value` to prevent unnecessary requests.

10. **Not typing API responses.** CC will use `any` or leave the type inferred as `unknown`
    from `response.json()`. Always type the query function's return type explicitly.

---

## File Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Route files | kebab-case (Expo Router convention) | `workout-detail.tsx` |
| Screen components | PascalCase with `Screen` suffix | `WorkoutDetailScreen.tsx` |
| UI components | PascalCase | `PostCard.tsx`, `Button.tsx` |
| Hooks | camelCase with `use` prefix | `useWorkouts.ts`, `useDebounce.ts` |
| Stores | camelCase with `use` + `Store` suffix | `useAuthStore.ts` |
| Types | PascalCase, one file per entity | `workout.ts` (exports `Workout`, `CreateWorkoutInput`) |
| Constants | camelCase file, UPPER_SNAKE values | `theme.ts` → `export const SPACING_SM = 8` |

---

## Checklist: Is the Component Well-Structured?

Use this when reviewing a screen or feature component:

- [ ] Route file is a thin re-export (no hooks, no JSX beyond default export)
- [ ] Screen component is under 150 lines
- [ ] All API data comes from TanStack Query hooks, not `useEffect` + `useState`
- [ ] Loading, error, and empty states are all handled explicitly
- [ ] Local state that's only used in one component uses `useState`, not Zustand
- [ ] Shared state across screens uses Zustand, not prop drilling
- [ ] Derived state uses `useMemo`, not a separate `useState`
- [ ] List rendering uses FlashList with `estimatedItemSize` and stable `keyExtractor`
- [ ] Props interface is named and exported, not inline
- [ ] No `any` types — all API responses are explicitly typed
- [ ] Callbacks passed to memoized children are wrapped in `useCallback`
- [ ] No navigation calls inside `useEffect`
