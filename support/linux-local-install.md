# Local Linux build and user install

This installs the native Flutter Linux bundle built from this checkout. The Rust plugin is built by cargokit as part of Flutter's Linux build.

## Desktop theme

On Linux, select **Settings → General → Theme → System** to follow the desktop's colors and light/dark appearance. System mode uses the desktop palette; the separate Color setting continues to control explicit Light/Dark themes. If no desktop palette is available, LocalSend uses its existing system-theme behavior.

LocalSend follows `$XDG_CONFIG_HOME/themes/.caelestia-use/Colors.qml`, defaulting to `~/.config/themes/.caelestia-use/Colors.qml`. Your existing `~/bin/theme`, Caelestia, Noctalia, and shell-mode switching scripts publish their applied palette through this selector. This covers static selections, dynamic wallpaper changes, shell-mode handoffs including Waybar, and switching back from Static to Dynamic within either shell. If the selector has never been available, `themes/current/Colors.qml` provides a static fallback.

Changes apply while LocalSend is open. The watcher follows selector changes and atomic replacements of generated theme directories, retains the previous palette during incomplete updates, and checks every five seconds to recover missed filesystem notifications. Text and accents are adjusted for at least 4.5:1 contrast against the mapped surfaces; outlines target 3:1. Authored backgrounds and usable palette colors are retained, and native surfaces are opaque. On the current Linux runner, Akane `#e00e1e36` and `Qt.rgba(14 / 255, 30 / 255, 54 / 255, 0.88)` both produce opaque `#0e1e36`: alpha-first bytes are decoded, then only alpha is dropped because the native runner background is opaque.

Set `LOCALSEND_DESKTOP_PALETTE=/absolute/path/to/Colors.qml` before launching LocalSend to follow another palette. Supported color expressions are quoted hex (including Qt's alpha-first form), `Qt.rgba(...)` with numbers or divisions, and simple color-property aliases. The required roles are `background`, `foreground`, and `primary`; the standard shared-theme secondary, surface, muted, warning, success, and danger roles are used when available.

## Build prerequisites

- The Flutter version pinned by `.fvmrc` and FVM (`fvm` on `PATH`).
- Rustup and the Rust toolchain pinned for the Flutter plugin crate.
- A C/C++ compiler, CMake, Ninja, `pkg-config`, and GTK 3 development files.
- The `libappindicator3` or `libayatana-appindicator3` runtime library required by the tray plugin.
- The desktop portal implementation used by the desktop environment at runtime: GNOME needs `xdg-desktop-portal` and `xdg-desktop-portal-gtk`; KDE needs `xdg-desktop-portal` and `xdg-desktop-portal-kde`.

On Arch Linux, the build tools are provided by `base-devel`, `cmake`, `ninja`, `pkgconf`, `gtk3`, and `libayatana-appindicator`, alongside FVM and the pinned Rust toolchain. Install missing build prerequisites through your normal system package workflow.

## Rust toolchain setup

`make setup` prepares the Rust toolchain before running FVM. If Cargokit's Rustup lookup cannot find an executable, the helper downloads the official `rustup-init` binary and its published SHA-256 file for x86_64 or aarch64 Linux. It verifies the checksum before atomically placing the executable at `.fvm/tools/rustup`. The binary runs as the Rustup CLI; setup does not run the interactive installer, add Rust proxies, change shell configuration, or replace system `rustc` and `cargo`.

The pinned toolchain is installed under `.fvm/tools/rustup-home`, separate from the user's default `~/.rustup`. Make prepends `.fvm/tools` to `PATH` and sets `RUSTUP_HOME` for setup and build commands, so Cargokit uses this manager and toolchain. Setup disables Rustup self-updates in this local home because Cargokit installs toolchains without the per-command `--no-self-update` option. An existing Rustup executable is reused when available. Run `make setup-rust` to prepare Rust alone, or `make DRY_RUN=1 setup-rust` to print the planned downloads and toolchain command without writing files.

Override `RUSTUP_BIN_DIR` or `RUSTUP_HOME` when a different local location is needed. These variables affect only Make invocations; no shell startup files or global PATH entries are changed.

## Build and install

From the repository root:

```sh
make install
```

`make install` runs setup, build, and install. Setup prepares the plugin's pinned Rust toolchain, installs the Flutter SDK version pinned in `.fvmrc`, and resolves the workspace's Flutter packages; run `make setup` separately to prepare dependencies without building. The default build uses `fvm flutter build linux --release --no-pub` from `app/`. It creates `app/build/linux/x64/release/bundle`, then installs the complete bundle under `~/.local/lib/localsend`. A launcher goes to `~/bin/localsend`; the desktop entry and icon go under `~/.local/share`. Ensure `~/bin` is on `PATH` to launch `localsend` from a terminal.

Preview commands with `make -n install`. `make DRY_RUN=1 install` also prints build and install actions without building or writing files. The installer rejects unclean destination paths and refuses to replace an existing `BINDIR/localsend` file unless its contents match the launcher this installer manages.

The Makefile accepts `FVM`, `RUSTUP_BIN_DIR`, `RUSTUP_HOME`, `RUST_TOOLCHAIN_FILE`, `PREFIX`, `BINDIR`, `LIBDIR`, `DATADIR`, `DESKTOPDIR`, `DESTDIR`, `BUILD_MODE`, `LINUX_ARCH`, `FLUTTER_BUILD_ARGS`, and `BUNDLE_DIR`. For example, stage an installation under a temporary root:

```sh
make install DESTDIR=/tmp/localsend-root
```

`DESTDIR` prefixes paths written during installation; launcher and desktop-entry paths still point to their final locations. `BINDIR` defaults to `~/bin`, while `LIBDIR` and `DATADIR` default below `$(PREFIX)` (`~/.local`).

The desktop entry uses the Linux application ID already set by `app/linux/CMakeLists.txt`: `org.localsend.localsend_app`. The icon is copied from `app/assets/img/logo-256.png`.

For launchers configured through `~/.config/apps.list`, use `org.localsend.localsend_app.desktop` in LocalSend's first column. The icon, display name, scale, and row position can stay as configured.

To register the installed user build in `/usr/share/applications` without rebuilding or copying the bundle:

```sh
make DRY_RUN=1 install-desktop
sudo make install-desktop BINDIR="$HOME/bin"
```

`install-desktop` validates and installs only the desktop entry. Specify `BINDIR` explicitly under sudo so the entry points at your launcher. `DESKTOPDIR` defaults to `/usr/share/applications`; `DESTDIR` can stage this target for review. It uses the same desktop ID as the user entry, so application menus show one LocalSend launcher.

On this Hyprland setup, `~/.config/hypr/windows.lua` contains the existing `float-localsend` rule at 410 × 580, centered. Its class match now covers both the old `localsend` class and the custom build's `org.localsend.localsend_app` class. Change `size` in that rule to adjust the launch dimensions.

## Existing pacman installation

The current machine has packages named `localsend` and `localsend-debug`. To remove those packages before switching to the local build, review and run:

```sh
sudo pacman -R localsend localsend-debug
```

This removes only the two named packages; installation does not invoke pacman or remove packages.
