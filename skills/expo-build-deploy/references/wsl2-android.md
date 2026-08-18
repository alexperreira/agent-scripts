# Local Android Builds from WSL2

Loaded by `expo-build-deploy` when building Android locally instead of on EAS. Running
`eas build --platform android` avoids all of this and is the lower-friction default; local
builds pay off when iterating on native code or when EAS build minutes matter.

---

## What Runs Where

| Piece | Lives on | Why |
|---|---|---|
| Android SDK + build-tools used by Gradle | **Inside WSL2** (Linux) | Gradle invokes Linux binaries (`aapt2`, `d8`). A `/mnt/c/...` SDK ships Windows `.exe` build-tools and the build fails partway through. |
| JDK 17 | Inside WSL2 | Same reason |
| Emulator, or the USB-attached phone | **Windows host** | WSL2 has no direct USB access and no GPU path for the emulator |
| `adb` server | Windows host | It owns the device; WSL2 connects to it over TCP |

```bash
# In WSL2 — SDK installed inside the Linux filesystem
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"
```

Point `ANDROID_HOME` at the Windows SDK (`/mnt/c/Users/<username>/AppData/Local/Android/Sdk`)
only for tooling that just needs to locate `adb` — not for Gradle builds.

## Bridging ADB into WSL2

**Windows 11 with mirrored networking** (`.wslconfig` → `[wsl2]` / `networkingMode=mirrored`) —
WSL2 shares the host's network stack, so localhost works directly:

```bash
export ADB_SERVER_SOCKET=tcp:localhost:5037
```

**NAT networking (the default)** — start the Windows ADB server listening on all interfaces:

```powershell
# Windows PowerShell
adb kill-server
adb -a -P 5037 nodaemon server
```

Then point WSL2 at the Windows host address, which is the default gateway under NAT:

```bash
export ADB_SERVER_SOCKET=tcp:$(ip route show default | awk '{print $3}'):5037
adb devices   # should list the Windows-attached device
```

`host.docker.internal` resolves only inside Docker Desktop containers — plain WSL2 shells have no
such host entry, so it is not a substitute for the gateway address.

An alternative to the TCP bridge is `usbipd-win`, which attaches the USB device into WSL2
directly; it needs a per-boot `usbipd attach` and gives WSL2 its own `adb` server.

## Building

```bash
npx expo run:android          # debug build onto the connected device/emulator
```

Rebuild only when native dependencies change — JS changes come from the dev server as usual.

## Physical Android Device

1. Enable Developer Options and USB debugging on the phone
2. Plug it into the **Windows** host and accept the RSA fingerprint prompt
3. Confirm `adb devices` lists it from WSL2 before starting the build

If the device shows as `unauthorized`, the fingerprint prompt was dismissed — revoke USB
debugging authorizations on the phone and replug.
