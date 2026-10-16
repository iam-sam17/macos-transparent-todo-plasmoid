# macOS Floating To-Do for KDE Plasma 6

[![KDE Plasma](https://img.shields.io/badge/KDE%20Plasma-6.0+-blue?style=flat-square&logo=kde&logoColor=white)](https://kde.org/plasma-desktop/)
[![Qt](https://img.shields.io/badge/Qt-6.8+-41CD52?style=flat-square&logo=qt&logoColor=white)](https://www.qt.io/)
[![Platform](https://img.shields.io/badge/Platform-Arch%20Linux%20%7C%20Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Version](https://img.shields.io/badge/Version-v1.0.2-orange?style=flat-square)](https://github.com/iam-sam17/macos-transparent-todo-plasmoid)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](./LICENSE)

A frameless, floating to-do and reminders plasmoid built natively for **KDE Plasma 6 (Wayland and X11)**. Implemented using QtQuick, Kirigami, and Plasma 6 Declarative Applet APIs, providing clean desktop rendering with zero opaque container backgrounds, inline task editing, multi-tier priority indexing, and dual-layer local persistence.

---

## Technical Specifications & Features

### 1. Frameless Desktop Integration
- **Zero-Container Rendering:** Uses `PlasmaCore.Types.NoBackground` to bypass default Plasma container frames and background svg masks.
- **Contrast Typography:** Employs high-contrast text drop shadows (`Text.DropShadow`, `rgba(0,0,0,0.85)`) to maintain legibility across light, dark, and dynamic wallpapers.

### 2. Dual-Layer Persistence Architecture
- **Primary Engine (KConfig):** Direct integration with Plasma's native configuration framework (`contents/config/main.xml`), serializing model states to `~/.config/plasma-org.kde.plasma.desktop-appletsrc`.
- **Secondary Engine (SQLite):** Client-side fallback using `QtQuick.LocalStorage` (`MacOSFloatingTodoDB`), maintaining structured records and metadata keys.
- **True Empty-State Preservation:** Explicitly serializes empty lists (`[]`) and tracks initialization via `hasCompletedIntro` boolean flag, preventing introductory demo tasks from repopulating after user deletion.

### 3. Task Management & Controls
- **Inline Editing:** In-place string mutation via double-click or edit trigger, updating models without popup dialogs.
- **Priority Indexing:** 3-tier visual priority classification (`High`, `Medium`, `Low`, `None`) with cycling triggers.
- **Segmented View Filtering:** Live client-side model filtering across `All`, `Active`, and `Done` states with dynamic counter badges.
- **Completion Tracking:** Dynamic completion percentage progress bar and one-click completed task purge.

---

## Interface Layout

```text
 ┌──────────────────────────────────────────────────────────┐
 │  FRIDAY, OCTOBER 16                            3 left    │
 │  Reminders                                               │
 │  ──────────────────────────────────────────────────────  │
 │  [   All (3)   ]    [  Active (2)  ]    [   Done (1)   ] │
 │                                                          │
 │  ○ [High]   Compile Linux kernel 6.x                     │
 │  ○ [Med]    Configure Wayland fractional scaling         │
 │  ✓ [Low]    Review systemd unit files                    │
 │                                                          │
 │                                            [Clear 1 done]│
 │  ┌────────────────────────────────────────────────────┐  │
 │  │  •  + Add a new reminder...                    [↑] │  │
 │  └────────────────────────────────────────────────────┘  │
 └──────────────────────────────────────────────────────────┘
```

---

## Installation & Deployment

### Method 1: Automated Script

```bash
git clone https://github.com/iam-sam17/macos-transparent-todo-plasmoid.git
cd macos-transparent-todo-plasmoid
chmod +x install.sh
./install.sh
```

### Method 2: Plasma Package Tool (`kpackagetool6`)

Install the package directly:
```bash
kpackagetool6 --type Plasma/Applet --install .
```

Upgrade an existing installation:
```bash
kpackagetool6 --type Plasma/Applet --upgrade .
```

### Method 3: Development Symlink

```bash
mkdir -p ~/.local/share/plasma/plasmoids/
ln -sfn "$(pwd)" ~/.local/share/plasma/plasmoids/org.minhaz.macos.transparent.todo
```

To refresh Plasma Shell without restarting the session:
```bash
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell
```

---

## Interactions & Keybindings

| Action | Trigger | Description |
| :--- | :--- | :--- |
| **Toggle Status** | Single Click | Toggles task between active and completed states |
| **Inline Edit** | Double Click / Edit Button | Activates in-place text input field |
| **Commit Edit** | `Enter` | Commits changes and writes to persistence engines |
| **Cancel Edit** | `Escape` / Defocus | Discards pending string modifications |
| **Cycle Priority** | Single Click on Dot | Cycles priority state (`none` -> `high` -> `med` -> `low`) |
| **Delete Item** | Click `✕` Button | Removes task from model and updates disk storage |
| **Submit Task** | `Enter` (in input field) | Appends task and clears input buffer |
| **Filter Switch** | Tab Click | Switches active view model (`all`, `active`, `done`) |

---

## Repository Structure

```text
macos-transparent-todo-plasmoid/
├── contents/
│   ├── config/
│   │   └── main.xml        # KConfig schema definition (tasksJson, widgetTitle, filterMode, hasCompletedIntro)
│   └── ui/
│       ├── main.qml        # Core Plasma 6 QML component & view hierarchy
│       └── Storage.js      # SQLite LocalStorage interface & settings handler
├── install.sh              # Deployment script with directory clean-up & DBUS reload
├── metadata.json           # Plasma 6 applet metadata & KPlugin descriptor
├── LICENSE                 # MIT License
└── README.md               # Technical documentation
```

---

## Changelog

### v1.0.2
- **Qt 6 Enumeration Fix:** Resolved `Invalid property assignment: unknown enumeration` crash in Plasma 6 by importing `org.kde.plasma.core as PlasmaCore` and binding `Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground`.
- **Empty-State Retention:** Fixed the issue where clearing all tasks triggered the first-run fallback, causing sample reminders to repopulate on reboot.
- **SQLite Metadata Table:** Added persistent key-value configuration tracking (`settings` table) in `Storage.js` alongside KConfig synchronization.

---

## License

This project is licensed under the [MIT License](./LICENSE).

Author: **[Minhaz](https://github.com/iam-sam17)**
