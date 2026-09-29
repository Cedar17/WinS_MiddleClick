# WinS_MiddleClick

A tiny, zero-UI Windows utility that maps plain `Win+S` to a middle mouse click while preserving normal Windows-key shortcuts.

## Behavior

`WinS_MiddleClick` runs silently in the current user session. It has no window, tray icon, settings page, installer, service, or background network activity. Only one instance may run at a time. To stop it, end `WinS_MiddleClick-x64.exe` or `WinS_MiddleClick-arm64.exe` in Task Manager.

The native executable keeps the same deferred-Win behavior as the original `WinS_MiddleClick.cmd` implementation:

```text
Physical Win-down
    ↓
Swallow it first; do not send it to Windows yet
    ↓
Wait for the next event
    ├─ S, with no Shift/Ctrl/Alt
    │     ↓
    │   Swallow S
    │   SendInput MiddleDown + MiddleUp
    │   Swallow the following S-up / Win-up
    │
    ├─ Another ordinary key
    │     ↓
    │   Replay Win-down with SendInput
    │   Pass the original key through
    │   → Win+E / Win+R / Win+D continue to work normally
    │
    ├─ Shift/Ctrl/Alt
    │     ↓
    │   Replay Win-down
    │   Pass the modifier through normally
    │   → Win+Shift+S and similar shortcuts continue to work normally
    │
    └─ Win is released by itself
          ↓
        Replay a complete Win down/up
        → pressing Win alone still opens the Start menu
```

## Downloads

Release assets are built for both supported architectures:

- `WinS_MiddleClick-x64.exe` — native x64 build for Intel/AMD Windows PCs.
- `WinS_MiddleClick-arm64.exe` — native ARM64 build for Windows on ARM.

Both are portable single-file executables. No installation is required.

## Usage

1. Download the executable for your architecture.
2. Put it anywhere you want to keep it.
3. Double-click it. Nothing visible appears when startup succeeds.
4. Press `Win+S` to generate one middle-click event.
5. To stop it, open Task Manager and end the `WinS_MiddleClick-*` process.

Starting the same build again while it is already running exits immediately because the utility uses the per-user-session mutex `Local\\WinS_MiddleClick`.

If the keyboard hook cannot be installed, the program shows a small error dialog instead of failing silently.

## Build

Requirements:

- Windows 11 or Windows 10
- Visual Studio 2022 Build Tools with MSVC and CMake
- CMake 3.20 or newer

x64:

```powershell
cmake -S . -B build-x64 -A x64
cmake --build build-x64 --config Release
```

ARM64:

```powershell
cmake -S . -B build-arm64 -A ARM64
cmake --build build-arm64 --config Release
```

The outputs are named `WinS_MiddleClick-x64.exe` and `WinS_MiddleClick-arm64.exe`. Their embedded Windows `ProductName`, `InternalName`, and `OriginalFilename` metadata also include the architecture.

## Repository layout

```text
WinS_MiddleClick/
├── .github/
│   └── workflows/
│       └── build.yml
├── src/
│   ├── main.cpp
│   ├── hook.cpp
│   └── hook.hpp
├── CMakeLists.txt
├── LICENSE
├── README.md
├── .gitignore
└── WinS_MiddleClick.cmd
```

`WinS_MiddleClick.cmd` is retained as the original, already-tested reference implementation. The native C++ executable does not depend on it at runtime.

## CI and releases

GitHub Actions builds both x64 and ARM64 on every push and pull request. Pushing a tag matching `v*` builds both Release executables and publishes them as assets on the corresponding GitHub Release.

## License

MIT.
