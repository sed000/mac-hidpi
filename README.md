# HiDPI

Unlocks HiDPI ("Retina") scaling for external monitors on Apple Silicon Macs. That includes the full-size 2x mode macOS hides on 1440p and other low-density displays, e.g. looks like 2560×1440, rendered at 5120×2880.

There are no virtual displays and no mirroring, and nothing runs in the background.

## What's included

- **HiDPI.app**: a menu bar app that lists every HiDPI and low-resolution size and refresh rate, including hidden ones. It remembers your choice per monitor and restores it on reconnect.
- **set-hidpi**: the same switch from the command line.
- **override.sh**: installs a display override that adds extra HiDPI sizes (90%, 80%, 75%, 62.5% and 50% of native).

## Install

Requires macOS 13+ and the Xcode Command Line Tools.

```bash
./build.sh install       # build and start HiDPI.app
./override.sh install    # optional: extra HiDPI sizes (asks for your password), then restart
```

If your monitor's native size doesn't show up under HiDPI, install the override and restart.

## Command line

```bash
build/set-hidpi -l               # list external displays: id vendor product native-size
build/set-hidpi                  # first external display, native size in HiDPI
build/set-hidpi -d 2 2304x1296   # a specific display and size
```

## Uninstall

```bash
./override.sh uninstall          # then restart
```

Then quit HiDPI from its menu and delete `~/Applications/HiDPI.app`.

## Notes

- This uses private CoreGraphics APIs, so a macOS update may break it.
- HiDPI makes text smoother on low-density monitors, but it can't add pixels.
- Other tools that edit display overrides can replace the override file.
