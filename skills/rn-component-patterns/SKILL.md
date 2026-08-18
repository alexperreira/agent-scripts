---
name: rn-component-patterns
description: >
  Opinionated patterns for building screens, components, hooks, and managing data flow in
  Expo/React Native apps. Use this skill whenever someone is building a new screen or feature,
  asking "how should I structure this component", "where does this logic go", "should this be a
  hook or a component", "how do I handle loading/error states", or reviewing component code for
  architecture issues. Also trigger proactively when Claude Code is about to write a screen
  component with inline data fetching, create a god component with 200+ lines, put business logic
  in a route file, or mix server state with client state. Owns state placement, component
  hierarchy, and TypeScript conventions for Expo Router + Zustand + TanStack Query projects. If
  the question is about project setup or scaffolding, use `expo-project-scaffold` instead. If
  it's about build/deploy, use `expo-build-deploy`. If it's about iOS/Android platform
  differences, use `rn-platform-gotchas`.
---

# React Native Component Patterns

Patterns for screens and components in Expo Router + Zustand + TanStack Query projects, assuming
the folder structure from `expo-project-scaffold`.

**The four rules that decide most reviews:**

1. **Route files in `src/app/` are one-line re-exports.** A route file that imports `useState`
   or `useEffect` is misplaced logic.
2. **Anything that came from an API lives in TanStack Query.** Zustand holds client-only state.
3. **Every screen that fetches opens with the tri-state guard** — loading, error, empty — which
   also narrows the type so the happy path needs no optional chaining.
4. **Screen components stay under ~150 lines.** Past that, extract sub-components into the same
   feature directory.

Goal: every component has one job, every piece of state has one home, and CC can modify any
screen without disturbing the rest of the app.

---

## Component Hierarchy

There are exactly three levels.

### 1. Route files (`src/app/`)

```tsx
// src/app/(tabs)/feed.tsx
export { FeedScreen as default } from '@/components/features/feed/FeedScreen';
```

That single line is the whole file. Route files declare navigation structure; screen components
hold UI and behavior. Keeping them apart is what makes navigation refactors cheap and screens
testable in isolation.

### 2. Screen components (`src/components/features/<feature>/`)

A screen calls hooks, handles the non-happy states, and composes children:

```tsx
// src/components/features/feed/FeedScreen.tsx
import { View } from 'react-native';
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

One screen per file, named after its route (`feed.tsx` → `FeedScreen.tsx`), under ~150 lines.
Reusable UI logic moves into a hook or a sub-component.

### 3. UI components

| Location | Scope | Rules |
|---|---|---|
| `src/components/ui/` | Generic primitives — `Button`, `Input`, `Card`, `Avatar`, `LoadingSpinner`, `ErrorMessage`, `EmptyState` | Props in, JSX out. No store or query hooks. |
| `src/components/features/<feature>/` | Feature-specific — `PostCard`, `WorkoutRow`, `ProfileHeader` | May call feature hooks. Lives beside its screen. |

The test: "Could another feature use this component unchanged?" Yes → `ui/`. No →
`features/<feature>/`.

---

## Custom Hook Patterns

Components render; hooks think.

### Query hooks (`src/hooks/queries/`)

One hook per data entity or query.

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

// Single entity by ID:
export function useWorkout(id: string) {
  return useQuery({
    queryKey: ['workouts', id],
    queryFn: (): Promise<Workout> => apiFetch(`/workouts/${id}`),
    enabled: !!id,  // conditional queries use `enabled`, never an if-wrapper
  });
}
```

**Query hook rules:**
- Type the return with a `Promise<T>` generic on `queryFn` — this is what stops `any` from
  leaking out of `response.json()`.
- Conditional fetches use `enabled`; hooks stay at the top level of the function body.
- Query keys are hierarchical: `['workouts']` → `['workouts', id]`.
- `apiFetch` unwraps the `{ ok, data, meta }` response envelope — the envelope shape itself is
  owned by `api-contract-design`. Types in `src/types/` describe the unwrapped `data` payload.

### Logic hooks (`src/hooks/`)

Non-data logic shared by multiple components:

```tsx
// src/hooks/useDebounce.ts
export function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debouncedValue;
}
```

**Extraction threshold:** the same `useState` + `useEffect` pair appearing in two or more
components. One instance stays inline — pre-abstraction costs more than it saves.

**Read `references/data-hooks.md`** when writing a mutation, optimistic update, paginated list,
or a screen that reads route params — it holds the mutation hook template, invalidation rules,
`useInfiniteQuery` wiring, and the `useLocalSearchParams` array-coercion pattern.

---

## State Placement Rules

**This skill owns state placement.** Every piece of state has exactly one correct home:

| Question | Answer | State lives in... |
|----------|--------|-------------------|
| Does the data come from an API? | Yes | TanStack Query (`useQuery` / `useMutation`) |
| Is it UI state used by one component only? | Yes | Local `useState` in that component |
| Is it UI state shared across screens? | Yes | Zustand store |
| Is it form input state? | Yes | Local `useState` or React Hook Form |
| Is it derived from other state? | Yes | `useMemo` over the source values |
| Is it the URL / route params? | Yes | Expo Router (`useLocalSearchParams`, `useGlobalSearchParams`) |

**CC failure modes and their corrections:**

| What CC writes | What it should be |
|---|---|
| `useEffect` + `useState` to fetch API data | `useQuery` — always, no exceptions |
| A `isLoading` boolean in a Zustand store | TanStack Query's own `isLoading` |
| A Zustand store for one component's state | `useState` in that component |
| Server data copied into Zustand "for convenience" | Read from the query cache |
| A filtered/sorted list stored via `useState` | `useMemo` over the source array |
| Props threaded through 3+ non-consuming levels | Call the hook where the data is used, or a Zustand store for shared UI state |
| A conditional query wrapped in `if` | `enabled: !!value` |
| `router.push` inside `useEffect` | Navigate from event handlers or a root `<Redirect>` — `useEffect` navigation double-fires and races the router |
| A list keyed by array index | A stable unique ID in `keyExtractor` / `key` |

The one legitimate `useEffect` in a screen is one-time setup: font loading, an auth check, or an
AppState subscription.

---

## Loading, Error, and Empty States

Every fetching screen handles all three. The guards double as type narrowing — past them,
`data` is defined and non-empty.

```tsx
export function FeedScreen() {
  const { data, isLoading, error, refetch } = useFeed();

  if (isLoading) return <LoadingSpinner />;
  if (error) return <ErrorMessage message="Couldn't load feed" onRetry={refetch} />;
  if (!data?.length) return <EmptyState message="No posts yet" />;

  return (/* happy path — `data` is guaranteed non-null and non-empty */);
}
```

**Single-entity screens** (detail, profile) swap the empty check for a not-found check, since a
missing entity is an error rather than an empty collection:

```tsx
if (!user) return <ErrorMessage message="User not found" />;
```

Three shared components in `src/components/ui/` cover every screen:

| Component | Props | Purpose |
|-----------|-------|---------|
| `LoadingSpinner` | `size?`, `message?` | Centered spinner with optional text |
| `ErrorMessage` | `message`, `onRetry?` | Error text + retry button |
| `EmptyState` | `message`, `action?` | Illustration + message + optional CTA |

CC reliably omits the empty branch and ships a blank screen for an empty list. The empty branch
is the one to check first in review.

---

## List Rendering

Lists past ~20 items use `FlashList` (`@shopify/flash-list`) instead of `FlatList` — a drop-in
replacement with materially better scroll performance.

```tsx
import { FlashList } from '@shopify/flash-list';

<FlashList
  data={posts}
  renderItem={({ item }) => <PostCard post={item} />}
  keyExtractor={(item) => item.id}
/>
```

**Version note:** FlashList v2 (bundled from SDK 54 onward) measures items itself — there is no
`estimatedItemSize` prop, and passing one is dead config. On FlashList v1 `estimatedItemSize` is
required for the list to perform at all. Check the installed major version before copying an
example from the web.

`keyExtractor` takes a stable unique ID. Pull-to-refresh wires `refreshing`/`onRefresh` to
TanStack Query's `refetch`; pagination uses `useInfiniteQuery` + `onEndReached` (see
`references/data-hooks.md`).

---

## TypeScript Conventions

Every component takes a named `Props` interface:

```tsx
interface PostCardProps {
  post: Post;
  onPress?: (id: string) => void;
}

export function PostCard({ post, onPress }: PostCardProps) { /* ... */ }
```

Shared types live in `src/types/`, one file per domain entity:

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
- IDs are `string`, even when the backend uses numbers — safer as React keys.
- Dates are `string` (ISO 8601 from the API), parsed to `Date` at display time only.
- Unknown shapes are typed `unknown` and narrowed at the boundary. `any` is banned outright.
- Status-like values are string unions (`type Status = 'active' | 'archived'`), not `enum`.
- Interfaces over type aliases, except for unions.

---

## Performance

Two free wins are worth taking by default:

- **`memo` every component rendered inside a `FlashList`/`FlatList` `renderItem`.** Screen
  components and always-new-props components stay unmemoized.
- **`useCallback` any function passed to a memoized child** — otherwise the new function
  reference defeats the memo entirely.

Beyond those two, measure before changing anything: `performance-profiling-protocol` owns the
budgets (16ms per render commit, 100ms tap-to-feedback) and the profiling workflow.

**Read `references/performance.md`** when a screen is actually slow, or when deciding whether a
computation deserves `useMemo` — it holds the `useMemo` threshold rule and the list of
optimizations that cost more than they return.

---

## File Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Route files | kebab-case (Expo Router convention) | `workout-detail.tsx` |
| Screen components | PascalCase with `Screen` suffix | `WorkoutDetailScreen.tsx` |
| UI components | PascalCase | `PostCard.tsx`, `Button.tsx` |
| Hooks | camelCase with `use` prefix | `useWorkouts.ts`, `useDebounce.ts` |
| Stores | camelCase with `use` + `Store` suffix | `useAuthStore.ts` |
| Types | PascalCase entity, one file per entity | `workout.ts` (exports `Workout`, `CreateWorkoutInput`) |
| Constants | camelCase file, UPPER_SNAKE values | `theme.ts` → `export const SPACING_SM = 8` |

Styling stays consistent within a component: either NativeWind classes throughout or
`StyleSheet` refs throughout, not both plus inline objects.

---

## Checklist: Is the Component Well-Structured?

Enumerate **every screen and component the change adds or edits**, then walk the rows for each
one. The review is done when every item on that list has been checked — not when the diff has
been skimmed.

- [ ] Route file is a one-line re-export
- [ ] Screen component is under 150 lines
- [ ] All API data comes from TanStack Query hooks
- [ ] Loading, error, and empty branches all present (empty first — it is the one CC skips)
- [ ] Single-component state uses `useState`; cross-screen state uses Zustand
- [ ] Derived values use `useMemo` over stored duplicates
- [ ] Lists use FlashList with a stable `keyExtractor`
- [ ] Props interface is named
- [ ] No `any` — query functions declare their return type
- [ ] Callbacks passed to memoized children use `useCallback`
- [ ] Navigation happens in event handlers, not `useEffect`

**If every row passes, say so and stop** — "structure is sound, no changes needed" is a valid
outcome, and manufacturing a marginal refactor to look thorough costs more than it returns.

Related: `code-review-checklist` for correctness and security on the same diff,
`test-strategy-planner` for what to cover once the structure is settled, `rn-platform-gotchas`
for iOS/Android behavior of the components involved.
