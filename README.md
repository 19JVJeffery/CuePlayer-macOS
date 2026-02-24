# CuePlayer-macOS

A **native macOS show cue player** built with Swift and SwiftUI — inspired by the open-source [LivePlay](https://github.com/tdoukinitsas/liveplay) project, rebuilt from scratch as a native Xcode application for macOS 14+.

---

## ✨ Features

### 🎵 Audio Playback
- **Multi-track playback** using `AVAudioEngine` — play multiple cues simultaneously
- **Precise In/Out trimming** — play exactly the portion you need
- **Individual volume control** per cue (0–150%)
- **Fade in / Fade out** configurable per cue
- **Real-time progress bars** with time elapsed and remaining
- **Emergency Stop All** button (also `Escape` keyboard shortcut)

### 📋 Playlist Management
- **Hierarchical cues** — Audio cues and Group cues with nested children
- **Drag & Drop** — Drop audio files directly into the playlist
- **Color coding** — 12 preset colors for quick visual identification
- **Context menus** — Right-click any cue for Play, Stop, Duplicate, Delete, Add to Cart
- **Reorder** — Drag rows to reorder cues in the list
- **Import Audio** — Multi-file import via `⌘I`

### 🎛️ Cart Player
- **16 quick-access slots** for instant one-click playback
- **Drag to assign** — Drag playlist cues onto cart slots
- **Visual feedback** — Slots glow and animate while playing
- **Toggle** — Click a playing cart cue to stop it

### 🎚️ Advanced Behaviors (per-cue)

**Ducking Behavior:** Stop All · Duck Others · No Ducking

**End Behavior:** Nothing · Play Next · Loop · Go To…

**Start Behavior:** Nothing · Play Next · Play Specific…

### 🎨 Properties Inspector
- Name, Color, File assignment per cue
- In/Out point sliders with effective duration display
- Volume, Fade In, Fade Out, Stop Fade sliders
- Full behavior configuration
- Notes field per cue

### 🌊 Waveform Visualization
- Real-time waveform rendering from audio files
- In/Out point markers overlaid on waveform

### 🗂️ Project Management
- **JSON-based** project files (`.cueshow` extension)
- Save / Save As / Open / Recent Projects
- Unsaved-changes indicator in toolbar
- Per-project theme settings

### ⌨️ Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| `⌘N` | New show |
| `⌘O` | Open show |
| `⌘S` | Save |
| `⌘⇧S` | Save As |
| `⌘I` | Import audio files |
| `Escape` | Stop all cues |
| `⌘M` | Toggle master mute |

---

## 🔨 Building

### Requirements
- macOS 14.0 or later
- Xcode 15.0 or later

### Steps
1. Open `CuePlayer/CuePlayer.xcodeproj` in Xcode
2. Select the **CuePlayer** scheme
3. Press `⌘R` to build and run

> **No third-party dependencies** — uses only Apple frameworks: `SwiftUI`, `AVFoundation`, `AppKit`

---

## 📁 Project Structure

```
CuePlayer/
├── CuePlayer.xcodeproj/          # Xcode project file
└── CuePlayer/
    ├── CuePlayerApp.swift        # @main app entry + menu commands
    ├── ContentView.swift         # Main 3-panel window layout
    ├── Models/
    │   ├── CueModels.swift       # AudioCue, GroupCue, CartItem data models
    │   └── ProjectManager.swift  # Project file I/O and cue management
    ├── Audio/
    │   └── AudioEngine.swift    # AVAudioEngine multi-track playback
    ├── Views/
    │   ├── PlaylistView.swift   # Sidebar playlist with drag & drop
    │   ├── ActiveCuesView.swift # Currently playing cues with progress
    │   ├── CartPlayerView.swift # 16-slot quick-access cart
    │   ├── PropertiesPanel.swift # Inspector for selected cue
    │   └── WaveformView.swift   # Audio waveform visualization
    ├── Assets.xcassets/          # App icon + accent color
    ├── Info.plist
    └── CuePlayer.entitlements
```

---

## 🆚 Improvements Over LivePlay

| Feature | LivePlay (Electron) | CuePlayer-macOS (Native) |
|---------|-------------------|----------------------|
| Runtime | Electron + V8 (~150 MB) | Native Swift (<5 MB) |
| Platform | Cross-platform web app | macOS-native, no Rosetta needed |
| Audio | Web Audio API | AVAudioEngine (CoreAudio) |
| Waveform | External audiowaveform binary | Pure Swift via AVAudioFile |
| File format | `.lpa` zip archive | `.cueshow` JSON |
| UI | Vue 3 + Carbon Design | Native SwiftUI |

---

Inspired by [LivePlay](https://github.com/tdoukinitsas/liveplay) by @tdoukinitsas (GPL-3.0). CuePlayer-macOS is an independent native reimplementation.
