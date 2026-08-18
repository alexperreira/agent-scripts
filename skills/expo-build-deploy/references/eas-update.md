# EAS Update: Channels, Rollouts, and Bundle Diffing

Loaded by `expo-build-deploy` when mapping channels to branches, promoting or rolling back an
update, or enabling bundle diffing.

---

## Channels and Branches

- **Channel** — a label baked into a build, set per profile in `eas.json` (`production`,
  `preview`, `staging`). A build's channel is fixed at build time.
- **Branch** — where updates are published. Branch name defaults to channel name.
- **Mapping** — a channel points at a branch. Every build on channel `production` receives
  whatever is published to branch `production`.

The indirection is the promotion mechanism: publish to `preview`, verify on preview builds, then
point the `production` channel at that branch (or republish the same commit to `production`)
without rebuilding anything.

```bash
eas channel:list
eas channel:edit production --branch release-2026-03
```

A build profile without a `channel` produces binaries that are not subscribed to anything. They
install fine and never update — the failure is silent, which is why the channel check belongs in
the pre-ship checklist.

## Rollouts

```bash
eas update --channel production --rollout-percentage 10 --environment production \
  --message "Test new checkout flow"
```

Start at 5–10%, watch error rates on the EAS dashboard, then raise the percentage. The point is
bounding the blast radius: a bad JS bundle reaches 10% of users instead of all of them, and the
rollback is another publish rather than a store review.

To roll back, republish the last known-good update to the branch, or use the dashboard's
"revert" on the branch. Devices pick it up on next launch — users on the bad bundle stay on it
until they relaunch, so a rollback is not instantaneous.

## Bundle Diffing (SDK 55 — Beta, Opt-In)

SDK 55 supports Hermes bytecode diffing: devices download a patch instead of the full bundle,
roughly 75% smaller.

```json
{
  "expo": {
    "updates": {
      "enableBsdiffPatchSupport": true
    }
  }
}
```

Requires a new build after enabling — the patching support lives in native code. Falls back to
the full bundle when a patch would not be smaller.

## Update Delivery Timing

`expo-updates` checks for an update on app launch by default and applies it on the *next*
launch. An urgent fix therefore reaches a user two cold starts after publish, not one. Projects
that need faster convergence configure `checkAutomatically` and call `Updates.fetchUpdateAsync()`
plus `Updates.reloadAsync()` explicitly — at the cost of a reload mid-session, which is only
acceptable at a natural boundary such as returning to the app from background.
