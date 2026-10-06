# MacConnect 🟢📱💻

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Android](https://img.shields.io/badge/Android-5.0%2B%20(API%2021%2B)-green.svg)](https://developer.android.com)
[![macOS](https://img.shields.io/badge/macOS-11.0%2B-black.svg)](https://apple.com/macos)
[![Bluetooth](https://img.shields.io/badge/Bluetooth-RFCOMM-informational.svg)]()
[![APK Size](https://img.shields.io/badge/APK%20Size-~49%20KB-success.svg)]()

A lightweight Bluetooth utility for Android and macOS. Forwards notifications, syncs clipboard text, and transfers files directly to your Mac without Wi-Fi, internet access, or cloud accounts.

---

## What It Does

- **Call Answering from Mac:** When your phone rings (cellular or VoIP like WhatsApp/Telegram), MacConnect alerts you on macOS with "Cevapla" (Answer) and "Reddet" (Decline) buttons. Answering connects the call immediately without touching the phone.
- **Notifications on Mac:** Android notifications (WhatsApp, Telegram, Slack, SMS, etc.) appear in macOS Notification Center with app icon, sound, app name, and full text.
- **Notification History & Details:** Past notifications are saved on the phone. Tapping any notification opens a detail view with full unclipped text, timestamp, and a copy button.
- **Clipboard Sharing:** Send text or notes from your phone straight to your Mac clipboard (`Cmd+V` to paste).
- **File Transfer:** Send photos, videos, or documents directly to `~/Downloads/MacConnect/` over Bluetooth.
- **Menu Bar Indicator:** Simple status dot in the macOS menu bar:
  - 🟢 Connected
  - 🟡 Connecting
  - 🔴 Disconnected
  - 📞 Incoming Call (with Answer & Reject quick actions)
  Also shows phone battery percentage and recent notifications.
- **Offline & Private:** All communication is strictly local over Bluetooth RFCOMM sockets. No network setup, no servers, no accounts.
- **Lightweight:** Pure native code. Android APK is ~130 KB; macOS app is ~110 KB.

---

## Project Structure

```text
macconnect/
├── MacConnect.apk              # Pre-built signed APK (~49 KB)
├── android/
│   ├── src/main/java/          # Android Java sources
│   ├── src/main/res/           # Layouts and resources
│   ├── AndroidManifest.xml
│   └── build.sh                # Standalone build script
├── mac/
│   ├── MacConnect/             # macOS Objective-C sources
│   └── build.sh                # Standalone build script
├── install_apk.sh              # ADB install helper
├── start_mac.sh                # App launcher
└── README.md
```

---

## How to Set Up

### 1. Bluetooth Pairing (One-time)
1. Turn on Bluetooth on both your Mac and Android phone.
2. Pair your phone with your Mac in standard Bluetooth settings.

### 2. Install Android App
- **Via ADB:**
  ```bash
  ./install_apk.sh
  ```
- **Or Manual:** Transfer `MacConnect.apk` to your phone and install it.

**Permissions:**
- Open MacConnect, go to **Ayarlar (Settings)** tab.
- Enable **Notification Access** and **Bluetooth Permission**.
- *(Xiaomi / Redmi / MIUI):* Enable **Autostart**, set Battery Saver to **No restrictions**, and lock the app in the recent apps screen so the system doesn't kill it in the background.

### 3. Run Mac App
```bash
./start_mac.sh
```
*(Or open `mac/build/MacConnect.app`)*

The menu bar icon will show:
- 🟢 Connected: phone linked and ready.
- Click the icon to view battery status, recent notifications, or open the downloads folder.

---

## Build from Source

### Android APK
```bash
./android/build.sh
```
Requires Android SDK build-tools and Java 8+.

### macOS App
```bash
./mac/build.sh
```
Requires macOS Command Line Tools (Clang).

---

## Bluetooth Protocol

Newline-delimited JSON packets over Bluetooth RFCOMM (UUID `94f39d29-7d6d-437d-973b-fba39e49d4ee`):

| Type | Direction | Payload | Description |
|---|---|---|---|
| `handshake` | Phone → Mac | `device_name`, `battery`, `android_version` | Initial connection metadata |
| `notification_posted` | Phone → Mac | `app_name`, `title`, `text`, `sub_text` | Forwarded notification |
| `clipboard_text` | Phone → Mac | `text` | Copies text to Mac clipboard |
| `file_start` | Phone → Mac | `file_name`, `file_size`, `total_chunks` | Initiates file transfer |
| `file_chunk` | Phone → Mac | `file_name`, `chunk_index`, `data` (base64) | 12 KB file chunk |
| `file_end` | Phone → Mac | `file_name` | Saves file to disk |
| `incoming_call` | Phone → Mac | `name`, `number`, `app_name`, `call_type` | Rings Mac with caller details |
| `call_action` | Mac → Phone | `action` (`answer` / `reject`) | Answers or rejects the call |
| `call_ended` | Phone → Mac | - | Dismisses incoming call banner |
| `ping` / `pong` | Both | `battery` | Heartbeat & battery updates |

---

## License

[MIT License](LICENSE)
