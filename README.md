# 🧩 ShareMounter for macOS

**Automatically mount, reconnect, and manage network drives** (SMB) – directly from your macOS menu bar.  
Version **1.0** – developed by **Kevin Tobler** 🌐 [www.kevintobler.ch](https://www.kevintobler.ch)

---

## 🔄 Changelog

### 🆕 Version 1.x
- **1.0**
  - 💾 Auto-mount saved network shares at login  
  - 🔁 Auto-Reconnect after connection loss or sleep/wake events  
  - 🧩 Integrated helper tool with full macOS authorization support  
  - 🧠 Smart background service for mount status monitoring  
  - 🖥️ Modern SwiftUI menu bar interface with status indicators  
  - 🧭 Protocol support: **SMB**
  - ⚙️ Secure Keychain storage for credentials  
  - 📊 Real-time mount status logging  

---

## 🚀 Features

- 🧠 **Auto-Reconnect** on network loss or after system sleep  
- 🔒 **Keychain Integration** – credentials are stored securely  
- ⚙️ **Helper Tool** – handles system-level mount/unmount tasks  
- 💡 **Status Monitoring** – shows mount state in the menu bar  
- 💾 **Auto-Mount at Login** – keep all shares ready automatically  
- 🔔 **Notifications** when a connection is lost or restored  
- 🧩 **SwiftUI Interface** optimized for macOS Sonoma 14.6+ 
- 🌙 **Sleep/Wake Detection** for stable mounts  

---

## 📸 Screenshots

![Screenshot](https://online.kevintobler.ch/projectimages/ShareMounterV1-0.png)  

---

## ⚙️ How It Works

1. Add your **network targets** (SMB)  
2. Credentials are stored securely in the **macOS Keychain**  
3. The app’s **Helper Tool** performs privileged mount/unmount operations  
4. A background monitor automatically **reconnects lost mounts**  
5. The **menu bar icon** shows live status for all connections  

---

## 🔧 Installation

1. Download the latest **ShareMounter.app** release  
2. Move **ShareMounter.app** to your **Applications** folder  
3. Launch the app and grant helper tool permissions  
4. Add your network drives and credentials  
5. Done — your shares will mount automatically!  

> 🧱 Requires macOS 15.6 Sequoia or newer

---

## 🧭 Helper Tool

- Installed on first launch
- Runs with system privileges for mounting/unmounting  
- Logs all operations 
- Automatically restarted on update or crash  

---

## 🧑‍💻 Developer

**Kevin Tobler**  
🌐 [www.kevintobler.ch](https://www.kevintobler.ch)  

---

## 📜 License

This project is licensed under the **MIT License** – feel free to use, modify, and distribute.
