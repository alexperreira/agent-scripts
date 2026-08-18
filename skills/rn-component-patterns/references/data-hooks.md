# Mutations, Pagination, and Route Params

Loaded by `rn-component-patterns` when writing a mutation hook, an optimistic update, a
paginated list, or a screen that reads route params.

---

## Mutation Hooks (`src/hooks/mutations/`)

One hook per write operation.

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
- Every mutation invalidates the queries its write affects, in `onSuccess`. A mutation with no
  invalidation leaves stale data on screen.
- Input and output are both typed.
- The hook returns `{ mutate, mutateAsync, isPending, error }` — the screen picks which to use.
  `mutate` for fire-and-forget with callbacks, `mutateAsync` when the screen awaits the result.
- Request and response shapes come from the API contract; `api-contract-design` owns the
  envelope and error-code registry those types describe.

## Optimistic Updates

Use `onMutate` to write the expected result into the cache, and `onError` to roll it back:

```tsx
onMutate: async (input) => {
  await queryClient.cancelQueries({ queryKey: ['feed'] });
  const previous = queryClient.getQueryData<Post[]>(['feed']);
  queryClient.setQueryData<Post[]>(['feed'], (old = []) => [optimisticPost(input), ...old]);
  return { previous };
},
onError: (_err, _input, context) => {
  queryClient.setQueryData(['feed'], context?.previous);
},
onSettled: () => {
  queryClient.invalidateQueries({ queryKey: ['feed'] });
},
```

`cancelQueries` first, or an in-flight refetch can land after the optimistic write and clobber
it. Reserve optimistic updates for actions the user expects to feel instant (likes, toggles,
reordering); a slow-but-honest spinner beats a rollback flicker on anything the user is
composing.

## Paginated Lists

```tsx
// src/hooks/queries/useFeedPages.ts
export function useFeedPages() {
  return useInfiniteQuery({
    queryKey: ['feed'],
    queryFn: ({ pageParam }): Promise<FeedPage> => apiFetch(`/feed?cursor=${pageParam ?? ''}`),
    initialPageParam: '',
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
}
```

`getNextPageParam` returning `undefined` is what sets `hasNextPage` to `false` — returning
`null` keeps the list asking forever. In the screen, flatten with
`data.pages.flatMap((p) => p.items)` and wire `onEndReached` to
`() => hasNextPage && fetchNextPage()`.

Cursor pagination is the default for mobile lists (see `api-contract-design` for the `meta`
pagination block). Offset pagination duplicates and skips rows when the underlying list changes
between page fetches.

## Route Params

`useLocalSearchParams` returns `string | string[]` per param — the type generic asserts a shape
rather than validating one.

```tsx
const { id } = useLocalSearchParams<{ id: string }>();
```

For catch-all routes, or any param that a deep link could repeat, coerce explicitly:

```tsx
const raw = useLocalSearchParams().id;
const id = Array.isArray(raw) ? raw[0] : raw;
```

Params arriving from a deep link are untrusted input — a screen that passes one straight into a
query key or a path segment inherits whatever the link contained. Coerce, then guard the query
with `enabled: !!id`.

`useLocalSearchParams` reads the params of the current screen; `useGlobalSearchParams` reads the
whole URL and re-renders on every navigation change, which is rarely what a screen wants.
