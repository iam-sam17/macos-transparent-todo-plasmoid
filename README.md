# macOS Floating To-Do for KDE Plasma 6  📝

[![KDE Plasma](https://img.shields.io/badge/KDE%20Plasma-6.0+-blue?style=for-the-badge&logo=kde&logoColor=white)](https://kde.org/plasma-desktop/)
[![Qt](https://img.shields.io/badge/Qt-6.8+-41CD52?style=for-the-badge&logo=qt&logoColor=white)](https://www.qt.io/)
[![Platform](https://img.shields.io/badge/Platform-Arch%20Linux%20%7C%20Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Version](https://img.shields.io/badge/Version-v1.0.2-orange?style=for-the-badge)](https://github.com/iam-sam17/macos-transparent-todo-plasmoid)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](./LICENSE)

A gorgeous, **100% transparent floating macOS Reminders-style To-Do List widget** tailored natively for **KDE Plasma 6 (Wayland & X11)**. Designed specifically for clean desktop ricers who want zero opaque card containers, crisp typography with drop-shadows that float directly on dynamic wallpapers, and Apple-grade micro-interactions.

---

## ✨ Key Features

- 🪟 **100% True Floating Transparency:** 
  Uses native `PlasmaCore.Types.NoBackground` with zero opaque panels or card backgrounds. All text, checkboxes, and counters float cleanly directly over your wallpaper.
- ⭕ **macOS Circular Checkboxes:** 
  Smooth animated circular checkboxes with spring checkmarks and subtle hover glows.
- 🎯 **3-Tier Priority Tagging:**
  - 🔴 **High Priority (`!!!`):** Apple Crimson
  - 🟠 **Medium Priority (`!!`):** Sunset Amber
  - 🔵 **Low Priority (`!`):** Electric Azure
- ✎ **Inline Task Editing:**
  Double-click any task text or click the edit icon to modify reminders on the fly without modal popups.
- 📊 **Dynamic Progress Rail:**
  Smooth progress bar reflecting real-time task completion percentage.
- 🏷️ **Segmented Filter Pills:**
  Quickly filter between **All**, **Active**, and **Done** tasks with live item counts.
- ⚡ **Dual-Engine Persistence (Zero Data Loss):**
  - **Primary:** Native KDE Plasma 6 KConfig engine (`~/.config/plasma-org.kde.plasma.desktop-appletsrc`).
  - **Secondary:** Local SQLite database engine via QtQuick LocalStorage (`MacOSFloatingTodoDB`).
  - **True Empty-State Preservation:** Leaving the list empty keeps it empty across reboots. Intro/demo reminders are only seeded once on absolute first launch and will never reappear after deletion.
- 🧹 **One-Click Completed Task Cleaner:**
  Subtle macOS pill button to clear all completed items instantly.

---

## 📸 Interface Overview

```text
 ┌──────────────────────────────────────────────────────────┐
 │  FRIDAY, OCTOBER 16                            3 left    │
 │  Reminders                                               │
 │  ══════════════════════════════════════════════════════  │
 │  [   All (3)   ]    [  Active (2)  ]    [   Done (1)   ] │
 │                                                          │
 │  ○ 🔴 Finish Arch Linux Kernel compilation               │
 │  ○ 🟠 Review IELTS Advantage writing task                │
 │  ✓ 🔵 Configure Wayland fractional scaling               │
 │                                                          │
 │                                            [Clear 1 done]│
 │  ┌────────────────────────────────────────────────────┐  │
 │  │  •  + Add a new reminder...                    [↑] │  │
 │  └────────────────────────────────────────────────────┘  │
 └──────────────────────────────────────────────────────────┘
```

---

## 🚀 Installation

### Option 1: One-Click Quick Installer (Recommended)

Clone the repository and run the automated deployment script:

```bash
git clone https://github.com/iam-sam17/macos-transparent-todo-plasmoid.git
cd macos-transparent-todo-plasmoid
chmod +x install.sh
./install.sh
```

### Option 2: Manual Install via `kpackagetool6`

If you have built the `.plasmoid` archive or cloned the folder:

```bash
kpackagetool6 --type Plasma/Applet --install .
```

*To upgrade an existing installation:*
```bash
kpackagetool6 --type Plasma/Applet --upgrade .
```

### Option 3: Direct Symlink (Developer Mode)

```bash
mkdir -p ~/.local/share/plasma/plasmoids/
ln -sfn "$(pwd)" ~/.local/share/plasma/plasmoids/org.minhaz.macos.transparent.todo
```

---

## 🖥️ How to Add to Your Desktop

1. Right-click anywhere on your KDE Plasma desktop.
2. Select **"Add Widgets..."** (or press `Meta + W`).
3. Search for **"macOS Floating To-Do"**.
4. Drag and drop the widget onto your desktop wallpaper.
5. Resize freely using `Alt + Right-Click Drag` or the Plasma widget handle.

---

## ⌨️ Shortcuts & Interactions

| Action | Gesture / Shortcut |
| :--- | :--- |
| **Complete Task** | Single click on the circular checkbox |
| **Edit Task** | Double-click task text OR click hover edit pencil (✎) |
| **Save Inline Edit** | Press `Enter` |
| **Cancel / Exit Edit**| Click outside or press `Escape` |
| **Cycle Priority** | Click priority indicator (`•`, `!`, `!!`, `!!!`) |
| **Delete Task** | Click hover delete button (✕) |
| **Add New Task** | Type in the bottom input bar and press `Enter` (or click `↑`) |
| **Filter Tasks** | Click segmented tabs: `All`, `Active`, `Done` |

---

## 🏗️ Architecture & Project Structure

```text
macos-transparent-todo-plasmoid/
├── contents/
│   ├── config/
│   │   └── main.xml            # KConfig XML Schema (hasCompletedIntro, filterMode, tasksJson)
│   └── ui/
│       ├── Storage.js          # SQLite LocalStorage driver & persistent settings key-value store
│       └── main.qml            # Core Plasma 6 QML user interface & interaction logic
├── install.sh                  # One-click deployment & plasma cache refresher
├── metadata.json               # KDE Plasma 6 package metadata & KPlugin definition
├── LICENSE                     # MIT License
└── README.md                   # Documentation & guide
```

---

## 🔧 Technical Changelog

### v1.0.2
- **Qt 6 / Plasma 6 Strict Enum Fix:** Resolved `Invalid property assignment: unknown enumeration` crash by importing `org.kde.plasma.core as PlasmaCore` and binding `Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground`.
- **True Empty-State Persistence:** Eradicated the "Empty Array = First Run" bug where clearing all tasks repeatedly reloaded introductory demo reminders after a desktop reboot.
- **SQLite Settings Table:** Added persistent key-value metadata store in SQLite for fail-safe state tracking across Plasma shell refreshes.

---

## 👤 Author

Developed by **[Minhaz](https://github.com/iam-sam17)**
- GitHub: [@iam-sam17](https://github.com/iam-sam17)

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](./LICENSE) file for full details.
