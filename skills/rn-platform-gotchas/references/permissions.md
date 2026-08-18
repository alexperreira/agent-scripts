# Permissions Deep Reference

Loaded by `rn-platform-gotchas` when implementing any permission flow.

---

## Request at Point of Use

Request each permission immediately before the feature that needs it. Blanket startup prompts
get denied, and a denial is close to permanent (see below).

```tsx
import * as ImagePicker from 'expo-image-picker';
import { Alert, Linking } from 'react-native';

async function pickImage() {
  const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();

  if (status !== 'granted') {
    Alert.alert(
      'Permission needed',
      'We need access to your photos to upload a profile picture.',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Open Settings', onPress: () => Linking.openSettings() },
      ]
    );
    return;
  }

  const result = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ['images'],
    quality: 0.8,
  });

  if (!result.canceled) {
    // handle selected image
  }
}
```

## Common Expo Permissions

| Feature | Expo package | iOS Info.plist key | Android permission |
|---------|-------------|-------------------|-------------------|
| Camera | `expo-camera` | `NSCameraUsageDescription` | `CAMERA` |
| Photo library | `expo-image-picker` | `NSPhotoLibraryUsageDescription` | `READ_MEDIA_IMAGES` (API 33+) |
| Location | `expo-location` | `NSLocationWhenInUseUsageDescription` | `ACCESS_FINE_LOCATION` |
| Notifications | `expo-notifications` | Automatic via config plugin | `POST_NOTIFICATIONS` (API 33+), plus a notification channel on Android 8+ |
| Microphone | `expo-audio` | `NSMicrophoneUsageDescription` | `RECORD_AUDIO` |
| Contacts | `expo-contacts` | `NSContactsUsageDescription` | `READ_CONTACTS` |

**Notifications on Android:** creating a notification channel is not optional. Without one,
Android 8+ drops notifications silently — no error, no delivery.

## Platform Differences in the Denial Flow

- **iOS:** the system dialog shows once. After a denial there is no re-prompt — every later
  `request*Async()` resolves to `denied` immediately. Recovery is `Linking.openSettings()`.
- **Android:** after two denials the permission is permanently denied and
  `shouldShowRequestRationale` returns `false`. Same recovery path.
- **Android 13+ (API 33):** granular media permissions (`READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`,
  `READ_MEDIA_AUDIO`) replace the blanket `READ_EXTERNAL_STORAGE`. Request only the media type
  the feature uses.

Because both platforms reach a no-more-dialogs state, call `get*PermissionsAsync()` to read the
current status before requesting, and give every denial path a Settings button.

## Config Plugin Setup

Expo config plugins generate the plist and manifest entries during `npx expo prebuild` — these
files are rarely edited by hand. Declare the plugins in `app.json`:

```json
{
  "expo": {
    "plugins": [
      ["expo-camera", { "cameraPermission": "We need camera access to scan barcodes." }],
      ["expo-location", { "locationWhenInUsePermission": "We use your location to find nearby gyms." }]
    ]
  }
}
```

The string becomes the iOS permission dialog text and the Android rationale text. Name the
concrete feature: "we need camera access to scan barcodes" earns grants that "this app needs
camera access" does not, and App Review rejects vague purpose strings.
