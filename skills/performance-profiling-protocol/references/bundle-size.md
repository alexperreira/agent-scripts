# Bundle Size (Web)

Read when Phase 2 identifies the **Config / build** layer — a large bundle slowing initial load.
Relevant for web surfaces only.

---

## Measure

```bash
# Analyze bundle with source-map-explorer
npx source-map-explorer 'build/static/js/*.js'

# Or with webpack-bundle-analyzer
npx webpack-bundle-analyzer build/static/js/*.js
```

---

## Common culprits

- Large libraries imported in full when only a subset is used (`lodash` → `lodash-es` with
  tree shaking, or individual imports)
- Moment.js — replace with `date-fns` or `dayjs`
- Duplicate dependencies at different versions
- Assets (images, fonts) bundled into JS instead of served separately

Splitting a bundle that is already under the project's stated budget is not an optimization.
