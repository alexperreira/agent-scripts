# Component Performance Reference

Loaded by `rn-component-patterns` when a screen is measurably slow, or when deciding whether a
computation deserves `useMemo`.

Measure first — `performance-profiling-protocol` owns the budgets (16ms per render commit, 100ms
tap-to-feedback, 3s cold start) and the profiling workflow. Everything below is what to change
once a measurement points at render cost.

---

## `React.memo` — list items

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

Applies to any component rendered inside a `FlashList` or `FlatList` `renderItem`. Screen
components and components that receive fresh props every render gain nothing from `memo` and
pay the comparison cost.

## `useCallback` — callbacks into memoized children

```tsx
const handlePress = useCallback((id: string) => {
  router.push(`/post/${id}`);
}, []);
```

A `memo` child receiving an inline arrow function re-renders every time — the new function
identity fails the props comparison. `useCallback` on handlers that are *not* passed to memoized
children is pure overhead.

## `useMemo` — the threshold

```tsx
const filteredPosts = useMemo(
  () => posts.filter((p) => p.author.id !== blockedUserId),
  [posts, blockedUserId]
);
```

**Rule of thumb:** if the operation iterates an array — `.filter()`, `.map()`, `.sort()`,
`.reduce()` — wrap it. Filtering, sorting, and transforming lists inside a screen are the common
valid cases. Property access, string concatenation, and single lookups stay bare; the memo
bookkeeping costs more than the work.

## Optimizations that cost more than they return

| Tempting move | Why it backfires |
|---|---|
| Memoizing every component | Comparison cost and retained memory on components that always re-render anyway |
| `useCallback` on every handler | Dependency arrays to maintain, no render saved |
| Splitting components for speed | Split for readability; the render cost usually moves rather than disappears |
| Caching a query that already returns in <10ms | Below the budget — see `performance-profiling-protocol` |
