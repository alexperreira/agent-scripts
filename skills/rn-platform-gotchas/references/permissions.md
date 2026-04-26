# Permissions Deep Reference

Loaded by `rn-platform-gotchas` when implementing permission flows.

---

## Request at Point of Use

Never request all permissions at app startup. Request each permission right before the
feature that needs it. Users deny blanket permission requests.

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

| Feature | Expo Package | iOS Info.plist key | Android permission |
|---------|-------------|-------------------|-------------------|
| Camera | `expo-camera` | `NSCameraUsageDescription` | `CAMERA` |
| Photo library | `expo-image-picker` | `NSPhotoLibraryUsageDescription` | `READ_MEDIA_IMAGES` (API 33+) |
| Location | `expo-location` | `NSLocationWhenInUseUsageDescription` | `ACCESS_FINE_LOCATION` |
| Notifications | `expo-notifications` | Automatic via config plugin | `POST_NOTIFICATIONS` (API 33+) |
| Microphone | `expo-audio` | `NSMicrophoneUsageDescription` | `RECORD_AUDIO` |
| Contacts | `expo-contacts` | `NSContactsUsageDescription` | `READ_CONTACTS` |

## Platform Differences in Permission Flow

- **iOS:** Shows a system dialog once. If denied, can't re-prompt — must send user to
  Settings via `Linking.openSettings()`.
- **Android:** Shows a system dialog. If denied twice, Android marks it as "permanently
  denied" — `shouldShowRequestRationale` returns `false`. Handle with `Linking.openSettings()`.
- **Android 13+ (API 33):** Granular media permissions (`READ_MEDIA_IMAGES`,
  `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`) replace the blanket `READ_EXTERNAL_STORAGE`.

## Config Plugin Setup

Most Expo packages add required permissions via config plugins automatically. Add them in
`app.json`:

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

The string you provide becomes the permission dialog text on iOS and the rationale text
on Android. Always write a specific reason — "this app needs camera access" is worse than
"we need camera access to scan barcodes."
