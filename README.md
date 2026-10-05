# MacConnect 🟢📱💻

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Android](https://img.shields.io/badge/Android-5.0%2B%20(API%2021%2B)-green.svg)](https://developer.android.com)
[![macOS](https://img.shields.io/badge/macOS-11.0%2B-black.svg)](https://apple.com/macos)
[![Protocol](https://img.shields.io/badge/Bluetooth-RFCOMM%20P2P-informational.svg)]()
[![APK Size](https://img.shields.io/badge/APK%20Size-~49%20KB-success.svg)]()

> **iPhone Mirroring / Continuity-style Android-to-macOS Bridge over Pure Bluetooth.**  
> Seamlessly forward notifications, share text/clipboard, and transfer files directly from your Android phone to your Mac without Wi-Fi, local networks, cloud servers, or third-party accounts.

---

## ✨ Features

- 🔔 **Native Notification Mirroring**  
  Notifications from WhatsApp, Telegram, Slack, Messages, Instagram, Gmail, and any Android app appear natively in macOS Notification Center with alert sound (`Glass`), application name badge, subtitle, and body text.
- 📋 **Seamless Clipboard & Text Sharing**  
  Type or paste any text/link on your phone and instantly push it to your Mac's system pasteboard (`NSPasteboard`). A banner notification confirms the transfer.
- 📁 **Bluetooth File Transfer**  
  Transfer photos, videos, PDFs, and files of any size directly from your phone to `~/Downloads/MacConnect/` on your Mac with real-time percentage progress.
- 📜 **In-App Notification History**  
  Past notifications are safely saved locally on your phone (up to 200 items) in a dedicated tab. Easily review past notifications or clear the history anytime.
- 🟢 **Minimalist macOS Menu Bar Companion**  
  A single, clean status dot in your macOS menu bar indicates connection status at a glance:
  - 🟢 **Connected** – Active and forwarding
  - 🟡 **Connecting** – Negotiating Bluetooth channel
  - 🔴 **Disconnected** – Waiting for device
  Includes phone battery percentage, recent notifications list, and a quick-open shortcut to the Downloads folder.
- 🔒 **100% Private & Offline**  
  Operates strictly peer-to-peer over local Bluetooth RFCOMM sockets. Zero telemetry, zero Internet access, and zero data leaving your devices.
- ⚡ **Ultra-Lightweight & Zero Bloat**  
  - Android APK: **~49 KB** (written in pure Android SDK without heavy dependencies or AndroidX).
  - macOS App: **~80 KB** (native Cocoa/Objective-C with `IOBluetooth` and `UserNotifications.framework`).

---

## 🏗️ Project Structure

```text
macconnect/
├── MacConnect.apk              # Ready-to-install signed APK (~49 KB)
├── android/
│   ├── src/main/java/          # Native Java source files
│   │   └── com/macconnect/android/
│   │       ├── MainActivity.java
│   │       ├── BluetoothService.java
│   │       ├── NotificationListener.java
│   │       ├── NotificationHistoryManager.java
│   │       ├── NotificationHistoryAdapter.java
│   │       ├── NotificationItem.java
│   │       └── Constants.java
│   ├── src/main/res/           # Layouts, values, and drawables
│   ├── AndroidManifest.xml
│   └── build.sh                # Standalone AAPT2/javac/d8 build script
├── mac/
│   ├── MacConnect/             # Native Objective-C / Cocoa source files
│   │   ├── main.m
│   │   ├── AppDelegate.m / .h
│   │   ├── BluetoothBridge.m / .h
│   │   ├── NotificationPresenter.m / .h
│   │   └── Info.plist
│   └── build.sh                # Standalone clang build script
├── install_apk.sh              # ADB install helper
├── start_mac.sh                # Launch helper for macOS companion
└── README.md
```

---

## 🚀 Quick Start Guide

### 1. Bluetooth Pairing (One-time Setup)
1. On your Mac: Open **System Settings** -> **Bluetooth** and ensure Bluetooth is enabled.
2. On your Android phone: Open **Settings** -> **Bluetooth** and pair with your Mac.

---

### 2. Install & Configure the Android App

#### Installation:
- **Via ADB** (if USB debugging is enabled):
  ```bash
  ./install_apk.sh
  ```
- **Or Manual Transfer**:
  Copy `MacConnect.apk` to your phone via USB or Bluetooth and tap to install.

#### Permissions & Optimization:
1. Open **MacConnect** on your Android phone.
2. Go to the **Ayarlar (Settings)** tab:
   - **Notification Access:** Tap **İzin Ver (Enable)** and turn on the switch for MacConnect.
   - **Bluetooth Permission:** Tap **İzin Ver (Enable)** (Android 12+).
3. **Xiaomi / Redmi / MIUI / HyperOS Users**:
   To prevent MIUI's aggressive battery manager from killing the background service:
   - Go to **App Info** -> **Autostart** -> Enable.
   - Go to **App Info** -> **Battery Saver** -> Select **No restrictions**.
   - In Recent Apps, long-press the MacConnect card and tap the **Lock** icon.

---

### 3. Run the macOS Companion App

On your Mac, launch the companion app:
```bash
./start_mac.sh
```
*(Or open `mac/build/MacConnect.app` directly).*

The status dot will appear in your menu bar:
- When your phone connects, the dot turns **🟢** and your phone battery percentage is displayed in the menu.
- Click the menu item to view recent notifications, send a test notification, or open the `~/Downloads/MacConnect/` folder.

---

## 🛠️ Building from Source

### Android APK Build
Requirements: Android SDK Build-Tools (AAPT2, d8, zipalign, apksigner) and Java 8+:
```bash
./android/build.sh
```
Output APK: `MacConnect.apk` and `android/bin/MacConnect.apk`.

### macOS App Build
Requirements: macOS Command Line Tools / Xcode:
```bash
./mac/build.sh
```
Output Bundle: `mac/build/MacConnect.app`.

---

## 📡 Bluetooth Protocol Specification

MacConnect exchanges newline-delimited (`\n`) JSON packets across an RFCOMM channel matching UUID `94f39d29-7d6d-437d-973b-fba39e49d4ee`.

| Packet Type | Direction | Payload Keys | Description |
|---|---|---|---|
| `handshake` | Phone → Mac | `device_name`, `battery`, `android_version` | Initial connection metadata |
| `notification_posted` | Phone → Mac | `app_name`, `title`, `text`, `sub_text`, `timestamp` | Forwarded notification |
| `clipboard_text` | Phone → Mac | `text`, `timestamp` | Text copied to Mac pasteboard |
| `file_start` | Phone → Mac | `file_name`, `file_size`, `total_chunks` | Start of file stream |
| `file_chunk` | Phone → Mac | `file_name`, `chunk_index`, `data` (base64) | 12 KB file data chunk |
| `file_end` | Phone → Mac | `file_name` | File reassembly & disk save trigger |
| `ping` / `pong` | Both | `battery` | Heartbeat & battery monitor |

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
