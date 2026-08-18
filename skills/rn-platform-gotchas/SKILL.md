---
name: rn-platform-gotchas
description: >
  iOS and Android platform differences for Expo/React Native: safe areas, edge-to-edge, keyboard
  behavior, permissions, shadows, haptics, StatusBar, and Android back navigation. Use this skill
  whenever something works on one platform but not the other, when building anything involving
  keyboard input, safe areas, permissions, shadows, haptics, or back navigation, or when someone
  asks "why does this look different on Android" or "this works on iOS but breaks on Android."
  Also trigger proactively when Claude Code is about to use the built-in SafeAreaView (deprecated),
  write a form without keyboard handling, add a shadow without Android elevation, request
  permissions without platform-specific handling, or use Platform.OS checks where file extensions
  would be cleaner. Targets Expo SDK 55+. If the question is about project setup, use
  `expo-project-scaffold`. If it's about component architecture, use `rn-component-patterns`. If
  it's about build/deploy, use `expo-build-deploy`.
---

# React Native Platform Gotchas

iOS and Android diverge in ways that ship silently when only one platform is tested. This covers
the divergences that cause real bugs in Expo SDK 55+ — not an exhaustive list.

**The four that ship broken most often:**

1. Safe areas come from `react-native-safe-area-context`. React Native's built-in `SafeAreaView`
   is iOS-only and deprecated — treat any import of it as a bug.
2. Edge-to-edge is the default on Android in SDK 55+. Insets are now mandatory on Android, not
   just iOS, and `androidStatusBar.backgroundColor` in app.json no-ops.
3. A card styled with iOS shadow props alone is invisible on Android. Every elevated surface
   goes through the `shadow()` helper below.
4. Every screen with a `TextInput` gets keyboard handling. Without it the keyboard covers the
   input on both platforms.

---

## Routing to Sibling Skills

- Scaffolding a new project → `expo-project-scaffold`
- Component architecture, state placement, list rendering → `rn-component-patterns`
- Build, deploy, or OTA updates → `expo-build-deploy`

---

## Safe Areas

Safe areas keep content clear of the status bar, notch, home indicator, and navigation bar.
This is the #1 source of "looks fine on my phone, broken on theirs."

Use `react-native-safe-area-context` (ships with Expo SDK 55) and wrap the app once:

```tsx
// src/providers/index.tsx
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

**Prefer `useSafeAreaInsets`** — it gives exact pixel values per edge, which composes with any
layout:

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

Reach for the `SafeAreaView` component (from the same package) when the requirement is simply
"apply all safe insets to this container":

```tsx
import { SafeAreaView } from 'react-native-safe-area-context';

<SafeAreaView edges={['top', 'bottom']} style={{ flex: 1 }}>
  {/* content */}
</SafeAreaView>
```

**Insets not needed:** tab screens using SDK 55 native tabs (handled automatically), stack
screens with a header (the header covers the status bar), content inside `ScrollView` (use
`contentContainerStyle` padding or `contentInsetAdjustmentBehavior="automatic"` on iOS).

**Insets required:** screens without a header (custom header, fullscreen media, onboarding),
floating action buttons and bottom sheets (offset by `insets.bottom`), custom tab bars, modals
and overlays.

### Android Edge-to-Edge (SDK 55+)

App content renders behind the system bars by default. Consequences:

- `androidStatusBar.backgroundColor` in app.json is deprecated and has no effect — it no-ops
  with a warning. Bar background is no longer app-controlled on Android 15+.
- Safe area insets are now load-bearing on Android. Before edge-to-edge, opaque system bars
  handled this; that free pass is gone.
- `expo-status-bar` and `expo-navigation-bar` still set bar *style* (light/dark content).
  Background color and translucency customization is deprecated on Android 15+.
- React Native's built-in `Modal` runs in its own native context. Prefer Expo Router modal
  screens; if using the RN `Modal`, set `statusBarTranslucent` and `navigationBarTranslucent`
  to `true`.

---

## Keyboard Handling

**Use `react-native-keyboard-controller`.** It is included in Expo Go since SDK 54, behaves
identically on both platforms, and integrates with `react-native-reanimated` — which has
deprecated its own `useAnimatedKeyboard` in favor of this library.

```tsx
// src/app/_layout.tsx
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

```tsx
import { KeyboardAwareScrollView, KeyboardToolbar } from 'react-native-keyboard-controller';

export function FormScreen() {
  return (
    <>
      <KeyboardAwareScrollView bottomOffset={62} contentContainerStyle={styles.container}>
        <TextInput placeholder="Email" style={styles.input} keyboardType="email-address" />
        <TextInput placeholder="Password" style={styles.input} secureTextEntry />
      </KeyboardAwareScrollView>
      <KeyboardToolbar />
    </>
  );
}
```

`KeyboardAwareScrollView` auto-scrolls to the focused input; `KeyboardToolbar` adds
prev/next/done navigation, which iOS supplies natively and Android does not.

Requires `react-native-reanimated` (already present in most Expo projects).

**Read `references/keyboard.md`** when the project cannot take the `keyboard-controller`
dependency, or when debugging why the keyboard covers an input — it holds the per-platform
behavior table and the `KeyboardAvoidingView` fallback with its edge-to-edge caveat.

---

## Platform-Specific Code

| Scope of the difference | Mechanism |
|---|---|
| 1–2 values | `Platform.OS === 'ios' ? a : b` |
| A style object that differs per platform | `Platform.select` inside `StyleSheet.create` |
| The whole implementation differs | `.ios.tsx` / `.android.tsx` file extensions |

```tsx
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

```
components/
├── DatePicker.ios.tsx
├── DatePicker.android.tsx
└── DatePicker.tsx        # optional — web/default fallback
```

Metro resolves the correct file per build target; import the extensionless path
(`import { DatePicker } from '@/components/DatePicker'`).

**The 20-line rule:** when a platform `if/else` block spans 20+ lines, split it into
`.ios.tsx` / `.android.tsx` files instead. Native date pickers, platform-specific animations,
and genuinely different UIs belong in separate files.

---

## Shadows

iOS uses shadow props; Android uses `elevation`, which draws a gray-only Material shadow and
also controls z-ordering. No single API covers both, so route every elevated surface through
one helper:

```tsx
// src/lib/shadows.ts
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

**CC footgun:** Claude Code sets iOS shadow props and calls it done, leaving the card flat on
Android. Every shadow either uses `shadow()` or includes `elevation` explicitly.

On Android, `overflow: 'hidden'` with `borderRadius` clips the `elevation` shadow. Separate the
shadow container from the rounded content:

```tsx
<View style={shadow(2)}>
  <View style={{ borderRadius: 12, overflow: 'hidden' }}>
    {/* content */}
  </View>
</View>
```

---

## Permissions

**Request each permission at the moment the user takes the action that needs it** — a blanket
prompt at launch gets denied.

```tsx
import * as ImagePicker from 'expo-image-picker';
import { Alert, Linking } from 'react-native';

async function pickImage() {
  const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();

  if (status !== 'granted') {
    Alert.alert('Permission Required',
      'Please grant photo access in Settings to use this feature.',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Open Settings', onPress: () => Linking.openSettings() },
      ]);
    return;
  }

  const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'] });
  if (!result.canceled) { /* handle result.assets[0] */ }
}
```

**Permanent denial is the state that breaks flows.** On iOS after the first denial, and on
Android after "Don't ask again", every later `request*Async()` returns `denied` without showing
a dialog. The only recovery is `Linking.openSettings()`, so check `get*PermissionsAsync()` first
and always offer the Settings route.

**Android notifications require a notification channel on Android 8+.** Without a channel,
notifications are dropped silently.

**Read `references/permissions.md`** before wiring any permission flow — it holds the
package/plist/manifest-key table for every common permission, the config-plugin snippets that
generate those entries, and the Android 13+ granular media permission rules.

---

## Android-Only Behavior

Android has a hardware/gesture back button; iOS does not. Guard destructive navigation with
`usePreventRemove` from `expo-router` — it covers both the Android back gesture and the iOS
swipe-back gesture:

```tsx
import { usePreventRemove, useNavigation } from 'expo-router';
import { Alert } from 'react-native';

const navigation = useNavigation();

usePreventRemove(hasUnsavedChanges, ({ data }) => {
  Alert.alert('Discard changes?', 'You have unsaved changes.', [
    { text: 'Stay', style: 'cancel' },
    { text: 'Discard', style: 'destructive', onPress: () => navigation.dispatch(data.action) },
  ]);
});
```

**Read `references/android.md`** when working on StatusBar appearance, tab back behavior, or
anything Android-specific beyond the above — it holds the `expo-status-bar` prop-by-platform
table and the Expo Router tab back-stack behavior.

---

## Styling Differences

**Text metrics differ:** iOS renders San Francisco, Android renders Roboto. The same `fontSize`
produces different line widths, so a `Text` that fits on one line on iOS can wrap on Android, and
a `lineHeight` tuned on one platform reads too tight or too loose on the other. Verify
text-heavy screens and any hardcoded `numberOfLines` on both platforms before shipping.

**`Pressable` is the touch handler for new code** (`TouchableOpacity` is legacy). It carries
`android_ripple` for native Material feedback, which is what makes an app feel non-native on
Android when it is missing:

```tsx
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

Android gets the ripple; iOS uses the `pressed` state for opacity or scale.

**Haptics are a supplement, never the feedback itself.** `expo-haptics` drives the Taptic Engine
on iOS and the vibration motor on Android, where the effect is coarser and no-ops entirely when
the user has system haptics off. Pair every haptic with a visible state change.

---

## Checklist: Is It Cross-Platform Ready?

Apply this to **every screen and component the change introduces or touches** — list them first,
then walk the rows for each. Done means every listed screen has been checked on both platforms,
not that the list "looks fine."

**Safe areas:**
- [ ] Safe area imports come from `react-native-safe-area-context` (no built-in `SafeAreaView`)
- [ ] `SafeAreaProvider` is in the root layout
- [ ] Headerless screens apply insets; FABs and bottom sheets offset by `insets.bottom`
- [ ] No `androidStatusBar.backgroundColor` in app.json

**Keyboard:**
- [ ] Every screen with a `TextInput` uses `KeyboardAwareScrollView` (or the documented fallback)
- [ ] The focused input and the submit button stay visible with the keyboard open, both platforms

**Shadows:**
- [ ] Every elevated surface uses `shadow()` or sets both iOS shadow props and `elevation`

**Permissions:**
- [ ] Each permission is requested at its point of use
- [ ] Permanent denial routes to `Linking.openSettings()`
- [ ] plist descriptions and Android manifest entries exist (via config plugins)

**Touch & navigation:**
- [ ] Touchables are `Pressable` with `android_ripple`
- [ ] Custom flows (forms, wizards, modals) handle Android back

**Visual:**
- [ ] Text-heavy screens checked on both platforms for wrapping
- [ ] StatusBar appearance set via `expo-status-bar`

**If every row passes, say so and stop.** A clean cross-platform review is a real result —
report "no platform issues found" rather than inventing marginal concerns. For non-platform
code quality on the same diff, hand off to `code-review-checklist`.
