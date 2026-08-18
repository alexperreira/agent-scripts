# Frontend Render Profiling

Read when Phase 2 identifies the **Render / UI** layer as the bottleneck.

---

## React / React Native

**Step 1 — React DevTools Profiler**
Record a render cycle. Look for:
- Components rendering more times than expected
- Expensive renders (> 16ms for 60fps budget)
- Components re-rendering when their props haven't changed

**Step 2 — Identify unnecessary re-renders**
```ts
// Add to a component you suspect is over-rendering
import { useRef, useEffect } from 'react';

function useRenderCount(label: string) {
  const count = useRef(0);
  useEffect(() => {
    count.current++;
    console.log(`[render] ${label}: ${count.current}`);
  });
}
```

**Step 3 — Common fixes**

| Problem | Fix |
|---|---|
| Parent re-renders cause unnecessary child renders | `React.memo()` on child |
| Inline object/array props recreated every render | `useMemo()` for objects, `useCallback()` for functions |
| Context value changes cause all consumers to re-render | Split context or memoize value |
| Large list rendering all items | `FlatList` (RN) or `react-window` (web) with `keyExtractor` |
| Expensive computation on every render | `useMemo()` with correct dependency array |

Memoizing a component that renders infrequently or cheaply is not an optimization — check it
against the budget table first.

---

## React Native / Expo Specific

- **JS thread vs UI thread:** Heavy JS work blocks animations. Move expensive logic off the
  main thread with `InteractionManager.runAfterInteractions()` or Worklets (Reanimated).
- **Image loading:** Unoptimized images are a leading mobile performance cost. Use `expo-image`
  over the built-in `Image` — it has caching and progressive loading built in.
- **FlatList performance:** Always set `keyExtractor`, `getItemLayout` (if fixed height),
  `initialNumToRender`, and `windowSize`. Never use `ScrollView` for long lists.
- **Hermes profiler:** For deep JS profiling on device, enable the Hermes profiler via
  React Native DevTools and capture a CPU profile during the slow interaction.
