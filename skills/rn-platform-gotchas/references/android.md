# Android-Specific Behavior Reference

Loaded by `rn-platform-gotchas` when working on StatusBar appearance, Android back navigation,
or tab back-stack behavior.

---

## StatusBar

Use `expo-status-bar`, not React Native's built-in `StatusBar` component.

```tsx
import { StatusBar } from 'expo-status-bar';

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

**Key point:** with edge-to-edge on Android the status bar is permanently transparent. The app
controls content appearance (light/dark icons) and nothing else. Any design that depends on a
solid status bar color needs to draw that color itself, behind the inset.

---

## Back Navigation

Android has a hardware/gesture back button; iOS does not. Two cases matter.

### Unsaved changes

```tsx
import { usePreventRemove, useNavigation } from 'expo-router';
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

Import both `usePreventRemove` and `useNavigation` from `expo-router`. Expo Router re-exports
the React Navigation surface it wraps; importing from `@react-navigation/native` directly pulls
in a second copy of the navigation packages (see `expo-project-scaffold` on why React Navigation
is never installed alongside Expo Router).

This hook covers the Android back gesture and the iOS swipe-back gesture with one call.

### Tab back behavior

On Android, back from a non-initial tab goes to the first tab, then exits the app. Expo Router's
tab navigator implements this by default — keep the default unless there is a stated reason to
change it.

For flows outside the navigator (a custom wizard step, a fullscreen overlay), `BackHandler` from
`react-native` is the escape hatch.
