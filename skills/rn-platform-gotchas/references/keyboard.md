# Keyboard Behavior Reference

Loaded by `rn-platform-gotchas` when the project cannot take the `react-native-keyboard-controller`
dependency, or when diagnosing why the keyboard covers an input.

---

## Platform Behavior Differences

| Behavior | iOS | Android (edge-to-edge) |
|----------|-----|----------------------|
| Keyboard pushes content up | Only with `KeyboardAvoidingView` | `adjustResize` is the manifest default, but under edge-to-edge the window does not resize — it behaves like `adjustNothing` |
| Keyboard height includes safe area | Yes (bottom inset baked in) | No |
| Keyboard animation tracking | Smooth, frame-by-frame | Historically janky; fixed by `react-native-keyboard-controller` |
| `Keyboard.dismiss()` reliability | Consistent | Can fail with custom inputs |

---

## Fallback: `KeyboardAvoidingView`

For a screen with 1–2 inputs where the full `keyboard-controller` dependency is unwanted:

```tsx
import { KeyboardAvoidingView, Platform } from 'react-native';

<KeyboardAvoidingView
  behavior="padding"
  style={{ flex: 1 }}
  keyboardVerticalOffset={Platform.OS === 'ios' ? 64 : 0}
>
  {/* inputs */}
</KeyboardAvoidingView>
```

**Why `behavior="padding"` on both platforms:** the old advice was `'height'` on Android, which
relied on the window resizing under `adjustResize`. With edge-to-edge (the SDK 55+ default) the
window no longer resizes, so `'height'` computes a zero delta and the keyboard still covers the
input. `'padding'` works on both.

**`keyboardVerticalOffset` has no correct constant.** The right value depends on whether the
screen has a header, a tab bar, or custom chrome — and it differs per platform. Measure it per
screen, or use `react-native-keyboard-controller`, which needs no offset at all. This is the
single strongest argument for the library.

---

## `KeyboardToolbar` Behavior

`react-native-keyboard-controller`'s `KeyboardToolbar` renders the prev/next/done accessory bar.
iOS supplies an equivalent natively for some input types; Android supplies nothing. Rendering
the toolbar makes multi-field forms behave the same on both platforms.

`bottomOffset` on `KeyboardAwareScrollView` is the gap left between the focused input and the
top of the keyboard — `62` is a reasonable default when a `KeyboardToolbar` is present, since
the toolbar occupies that space.
