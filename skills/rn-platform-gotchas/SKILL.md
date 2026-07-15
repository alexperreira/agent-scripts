---
name: rn-platform-gotchas
description: >
  iOS and Android platform differences, safe area handling, keyboard behavior, permissions, and
  platform-specific styling for Expo/React Native apps. Use this skill whenever something works
  on one platform but not the other, when building anything involving keyboard input, safe areas,
  permissions, shadows, haptics, or back navigation, or when someone asks "why does this look
  different on Android" or "this works on iOS but breaks on Android." Also trigger proactively
  when Claude Code is about to use the built-in SafeAreaView (deprecated), write a form without
  KeyboardAvoidingView, add a shadow without Android elevation fallback, request permissions
  without platform-specific handling, or use Platform.OS checks where file extensions would be
  cleaner. Covers the most common cross-platform issues in Expo SDK 55+ projects. If the question
  is about project setup, use `expo-project-scaffold`. If it's about component architecture, use
  `rn-component-patterns`. If it's about build/deploy, use `expo-build-deploy`.
---

# React Native Platform Gotchas

iOS and Android behave differently in ways that silently break your app if you only test on one
platform. This skill covers the differences that actually matter in Expo SDK 55+ projects —
not an exhaustive list, but the ones that cause real bugs.

The goal: code that works on both platforms the first time, without "oh, I forgot to test on Android."

---

## When NOT to Use This Skill

- Scaffolding a new project → use `expo-project-scaffold`
- Component architecture or state management → use `rn-component-patterns`
- Build, deploy, or OTA updates → use `expo-build-deploy`

---

## Safe Areas

Safe areas prevent content from being obscured by the status bar, notch, home indicator,
or navigation bar. This is the #1 source of "looks fine on my phone, broken on theirs."

### Setup

Use `react-native-safe-area-context` (ships with Expo SDK 55). **Never use React Native's
built-in `SafeAreaView`** — it's iOS-only and deprecated.

```tsx
// src/providers/index.tsx — wrap your app
import { SafeAreaProvider } from 'react-native-safe-area-context';

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <SafeAreaProvider>
      {/* other providers */}
      {children}
    </SafeAreaProvider>
  );
}
```

### Hook vs Component

Prefer `useSafeAreaInsets` over `SafeAreaView` in most cases. The hook gives you exact
pixel values for each edge, which is more flexible:

```tsx
import { View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

export function MyScreen() {
  const insets = useSafeAreaInsets();

  return (
    <View style={{ flex: 1, paddingTop: insets.top, paddingBottom: insets.bottom }}>
      {/* screen content */}
    </View>
  );
}
```

Use the `SafeAreaView` component when you just need "apply all safe insets to this container"
and don't need fine-grained control:

```tsx
import { SafeAreaView } from 'react-native-safe-area-context';

// Control which edges get insets with the `edges` prop
<SafeAreaView edges={['top', 'bottom']} style={{ flex: 1 }}>
  {/* content */}
</SafeAreaView>
```

### Android Edge-to-Edge (SDK 55+)

Edge-to-edge is now the default for Expo SDK 55+ on Android. Your app content renders behind
the status bar and navigation bar. Key implications:

- **`androidStatusBar.backgroundColor` in app.json is deprecated and has no effect.** Don't set it.
- You **must** use safe area insets on Android now — before edge-to-edge, Android's opaque
  system bars handled this for you. Not anymore.
- `expo-status-bar` and `expo-navigation-bar` still work for setting bar style (light/dark
  content), but background color and translucency customization is deprecated on Android 15+.
- React Native's built-in `Modal` runs in its own native context. For edge-to-edge modals,
  set `statusBarTranslucent` and `navigationBarTranslucent` to `true`, or use Expo Router
  modal screens instead (recommended).

### When You Need Insets (and When You Don't)

**Don't need insets:** Tab bar screens using SDK 55 native tabs (handled automatically),
stack screens with a header (header accounts for status bar), screens inside `ScrollView`
(use `contentContainerStyle` padding or `contentInsetAdjustmentBehavior="automatic"` on iOS).

**Do need insets:** Screens without headers (custom header, fullscreen media, onboarding),
floating action buttons or bottom sheets (offset by `insets.bottom`), custom tab bar
implementations, modals and overlays.

---

## Keyboard Handling

The keyboard behaves differently on iOS and Android, and the default React Native tools are
barely adequate. Here's the landscape:

### Platform Behavior Differences

| Behavior | iOS | Android (edge-to-edge) |
|----------|-----|----------------------|
| Keyboard pushes content up | Only with `KeyboardAvoidingView` | `adjustResize` is default, but with edge-to-edge it behaves like `adjustNothing` |
| Keyboard height includes safe area | Yes (bottom inset baked in) | No |
| Keyboard animation tracking | Smooth, frame-by-frame | Historically janky, fixed by `react-native-keyboard-controller` |
| `Keyboard.dismiss()` reliability | Consistent | Can fail with custom inputs |

### Recommended: `react-native-keyboard-controller`

This is the library to use. It's included in Expo Go since SDK 54, provides identical behavior
on both platforms, and integrates with `react-native-reanimated` for smooth animations.
Reanimated has deprecated its own `useAnimatedKeyboard` in favor of this library.

**Setup:**

```tsx
// src/app/_layout.tsx — add KeyboardProvider
import { KeyboardProvider } from 'react-native-keyboard-controller';

export default function RootLayout() {
  return (
    <KeyboardProvider>
      <Providers>
        <Stack />
      </Providers>
    </KeyboardProvider>
  );
}
```

Requires `react-native-reanimated` (already in most Expo projects).

**For forms with multiple inputs:**

```tsx
import { TextInput, View, StyleSheet } from 'react-native';
import { KeyboardAwareScrollView, KeyboardToolbar } from 'react-native-keyboard-controller';

export function FormScreen() {
  return (
    <>
      <KeyboardAwareScrollView bottomOffset={62} contentContainerStyle={styles.container}>
        <TextInput placeholder="Email" style={styles.input} keyboardType="email-address" />
        <TextInput placeholder="Password" style={styles.input} secureTextEntry />
        <TextInput placeholder="Confirm Password" style={styles.input} secureTextEntry />
      </KeyboardAwareScrollView>
      <KeyboardToolbar />
    </>
  );
}
```

`KeyboardAwareScrollView` auto-scrolls to the focused input. `KeyboardToolbar` adds prev/next/done
navigation — the kind of thing iOS does natively but Android doesn't.

### Fallback: `KeyboardAvoidingView`

For simple screens with 1-2 inputs where you don't need the full `keyboard-controller`:

```tsx
import { KeyboardAvoidingView, Platform } from 'react-native';

<KeyboardAvoidingView
  behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
  style={{ flex: 1 }}
  keyboardVerticalOffset={Platform.OS === 'ios' ? 64 : 0}
>
  {/* inputs */}
</KeyboardAvoidingView>
```

The `behavior` and `keyboardVerticalOffset` props almost always need platform-specific
values. This inconsistency is exactly why `react-native-keyboard-controller` is preferred.

---

## Platform-Specific Code

Three approaches, from simplest to most isolated:

### 1. `Platform.OS` — inline checks

```tsx
import { Platform } from 'react-native';

const marginTop = Platform.OS === 'ios' ? 20 : 0;
```

Use for: one-off style tweaks, simple conditionals.

### 2. `Platform.select` — platform-keyed objects

```tsx
import { Platform, StyleSheet } from 'react-native';

const styles = StyleSheet.create({
  container: {
    ...Platform.select({
      ios: { shadowColor: '#000', shadowOffset: { width: 0, height: 2 },
             shadowOpacity: 0.1, shadowRadius: 4 },
      android: { elevation: 4 },
    }),
  },
});
```

Use for: style objects that differ significantly between platforms.

### 3. Platform file extensions — `.ios.tsx` / `.android.tsx`

```
components/
├── DatePicker.ios.tsx
├── DatePicker.android.tsx
└── DatePicker.tsx        # optional — used as web/default fallback
```

Metro resolves the correct file automatically based on the build target. Import as usual:
```tsx
import { DatePicker } from '@/components/DatePicker'; // resolves to .ios or .android
```

Use for: components where the entire implementation differs between platforms (native date
pickers, platform-specific animations, completely different UI).

**When to use which:**
- **1-2 lines different** → `Platform.OS` or `Platform.select`
- **Shared logic, different styles** → `Platform.select` in `StyleSheet.create`
- **Fundamentally different implementations** → file extensions
- Don't use `Platform.OS` checks for things that should be file extensions. If an `if/else`
  block for platform detection spans 20+ lines, split into separate files.

---

## Shadows

iOS and Android have completely different shadow systems. There is no single API that works
on both.

### iOS: Shadow props

```tsx
{
  shadowColor: '#000',
  shadowOffset: { width: 0, height: 2 },
  shadowOpacity: 0.1,
  shadowRadius: 4,
}
```

### Android: Elevation

```tsx
{
  elevation: 4,
}
```

`elevation` on Android creates a Material Design shadow. It doesn't support color
customization (always gray) and controls both shadow spread and z-ordering.

### Cross-Platform Shadow Helper

Create this once in `src/lib/shadows.ts`:

```tsx
import { Platform, ViewStyle } from 'react-native';

export function shadow(depth: number = 2, color: string = '#000'): ViewStyle {
  if (Platform.OS === 'android') return { elevation: depth * 2 };
  return {
    shadowColor: color,
    shadowOffset: { width: 0, height: depth },
    shadowOpacity: 0.1 + depth * 0.03,
    shadowRadius: depth * 2,
  };
}

// Usage: ...shadow(2) in any StyleSheet
```

**CC footgun:** Claude Code will set iOS shadow props and call it done. The card will be
invisible on Android. Always include `elevation` or use the helper.

---

## Permissions

iOS and Android differ at both the request and denial level. The rule that works for both:
**request at point of use, never at launch, and recover from permanent denial with a Settings
fallback.** Once denied, iOS silently returns `denied` on every future `request*Async()` call,
and Android does the same after "Don't ask again" — so always check `get*PermissionsAsync()`
first and offer `Linking.openSettings()`.

Expo config plugins add the required iOS plist / Android manifest entries automatically when you
install the package, so you rarely edit those files by hand. One Android footgun:
`expo-notifications` needs a notification channel on Android 8+, or notifications are silently
dropped.

→ Full request-pattern code, the per-feature permission/plist/manifest matrix, the API 33+
granular-media changes, and config-plugin examples live in
[`references/permissions.md`](references/permissions.md) — read it when implementing a
permission flow.

---

## Back Navigation (Android)

Android has a hardware/gesture back button. iOS does not. This matters for:

### Preventing Accidental Back

Use `usePreventRemove` from Expo Router to block navigation when there are unsaved changes:

```tsx
import { usePreventRemove } from 'expo-router';
import { useNavigation } from '@react-navigation/native';
import { useState } from 'react';
import { Alert } from 'react-native';

export function EditScreen() {
  const navigation = useNavigation();
  const [hasUnsavedChanges, setHasUnsavedChanges] = useState(false);

  usePreventRemove(hasUnsavedChanges, ({ data }) => {
    Alert.alert('Discard changes?', 'You have unsaved changes.',
      [
        { text: 'Stay', style: 'cancel' },
        { text: 'Discard', style: 'destructive',
          onPress: () => navigation.dispatch(data.action) },
      ]);
  });
  // ... form content
}
```

This works for both the Android back gesture and the iOS swipe-back gesture.

### Tab Back Behavior

On Android, pressing back on a non-initial tab should go to the first tab, then exit the app.
Expo Router's tab navigator handles this correctly by default — don't override it unless
you have a specific reason.

---

## StatusBar

Use `expo-status-bar`, not React Native's built-in `StatusBar` component.

```tsx
import { StatusBar } from 'expo-status-bar';

// In your root layout or screen
<StatusBar style="auto" />
```

| Prop | iOS | Android (edge-to-edge) |
|------|-----|----------------------|
| `style="auto"` | Adapts to light/dark mode | Adapts to light/dark mode |
| `style="light"` | White text/icons | White text/icons |
| `style="dark"` | Black text/icons | Black text/icons |
| `backgroundColor` | No effect (always transparent) | **Deprecated** — no-ops with warning |
| `translucent` | Always true | **Deprecated** — always translucent |
| `hidden` | Works | Works |

**Key point:** With edge-to-edge on Android, the status bar is always transparent. You
control content appearance (light/dark icons) but not the background.

---

## Styling Differences

### Text Rendering

iOS uses San Francisco; Android uses Roboto. They have different metrics for the same
`fontSize`, which means:

- A `Text` component that fits on one line on iOS might wrap on Android (or vice versa).
- `lineHeight` values that look perfect on one platform may look too tight or loose on the other.
- **Fix:** Test text-heavy screens on both platforms. Don't hardcode `numberOfLines` without
  testing on Android.

### Pressable vs TouchableOpacity

`Pressable` is the recommended touch handler. It supports `android_ripple` for native
Material feedback on Android:

```tsx
import { Pressable, Platform, Text } from 'react-native';

<Pressable
  onPress={handlePress}
  android_ripple={{ color: 'rgba(0, 0, 0, 0.1)' }}
  style={({ pressed }) => [
    styles.button, pressed && Platform.OS === 'ios' && styles.buttonPressed,
  ]}
>
  <Text>Press Me</Text>
</Pressable>
```

- On Android: `android_ripple` gives the native ripple effect.
- On iOS: Use the `pressed` state to change opacity or scale.
- `TouchableOpacity` still works but is considered legacy. Prefer `Pressable` for new code.

### Border Radius + Elevation Clipping

On Android, `overflow: 'hidden'` with `borderRadius` can clip shadows from `elevation`.
Fix by separating the shadow container from the rounded content:

```tsx
<View style={shadow(2)}>
  <View style={{ borderRadius: 12, overflow: 'hidden' }}>
    {/* content */}
  </View>
</View>
```

---

## Common Footguns

1. **Using React Native's built-in `SafeAreaView`.** It's iOS-only and deprecated. Use
   `react-native-safe-area-context` always.

2. **Setting `androidStatusBar.backgroundColor` in app.json.** Deprecated in SDK 55 with
   edge-to-edge. It no-ops and logs a warning.

3. **Writing a form without any keyboard handling.** The keyboard will cover inputs on both
   platforms. Use `react-native-keyboard-controller`'s `KeyboardAwareScrollView` or at minimum
   `KeyboardAvoidingView`.

4. **iOS shadow props without Android `elevation`.** Shadows are invisible on Android without
   `elevation`. Use the cross-platform `shadow()` helper.

5. **Requesting permissions at app launch.** Users deny blanket permission requests. Request
   at point of use with context for why.

6. **Not handling permanent permission denial.** After "Don't ask again" on Android or first
   denial on iOS, subsequent requests are silent. Always offer `Linking.openSettings()`.

7. **Ignoring the Android back button.** Your app will feel broken if custom flows (forms,
   wizards, modals) don't handle hardware back. Use `usePreventRemove` or `BackHandler`.

8. **Using `TouchableOpacity` without `android_ripple`.** Missing native feedback on Android
   makes the app feel non-native. Use `Pressable` with `android_ripple`.

9. **Hardcoding `keyboardVerticalOffset` in `KeyboardAvoidingView`.** The correct value
   depends on whether you have a header, tab bar, or custom chrome — and it differs between
   platforms. This is why `react-native-keyboard-controller` is preferred.

10. **Testing only on iOS (or only on Android).** Text wrapping, shadow rendering, keyboard
    behavior, safe areas, and permissions all differ. Test both or expect bug reports.

---

## Checklist: Is It Cross-Platform Ready?

Before shipping a screen or component, verify:

**Safe areas:**
- [ ] Using `react-native-safe-area-context`, NOT built-in `SafeAreaView`
- [ ] `SafeAreaProvider` is in the root layout
- [ ] Screens without headers apply safe area insets (top, bottom as needed)
- [ ] Floating elements (FABs, bottom sheets) account for `insets.bottom`

**Keyboard:**
- [ ] Forms with text inputs use `KeyboardAwareScrollView` or `KeyboardAvoidingView`
- [ ] Keyboard doesn't cover the focused input on either platform
- [ ] Submit button is visible while keyboard is open

**Shadows:**
- [ ] Cards/elevated elements have both iOS shadow props AND Android `elevation`
- [ ] Or using a cross-platform `shadow()` helper

**Permissions:**
- [ ] Permissions are requested at point of use, not at launch
- [ ] Permanent denial is handled with a Settings redirect
- [ ] iOS plist descriptions and Android manifest permissions are configured

**Touch & interaction:**
- [ ] Using `Pressable` with `android_ripple` (not bare `TouchableOpacity`)
- [ ] Android hardware back is handled for custom flows (forms, modals)

**Visual consistency:**
- [ ] Text-heavy screens tested on both platforms for wrapping differences
- [ ] StatusBar uses `expo-status-bar`, not the built-in component
- [ ] No `androidStatusBar.backgroundColor` in app.json (deprecated)
