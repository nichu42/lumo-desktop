# Unofficial Lumo Desktop packages for Linux

Proton publishes Lumo for Linux only as `.deb` and `.rpm`. This fork adds what
those formats can't cover on Arch and on distributions that prefer a
single-file app: a **pacman repository** and an **AppImage**, both built from
Proton's published GPL-3.0-only source without modifications.

> **Unofficial.** Not affiliated with, sponsored or endorsed by Proton AG.
> "Lumo" and "Proton" are trademarks of Proton AG. No QA from Proton, no
> warranty of any kind. Upstream reports belong at
> [ProtonLumo/lumo-desktop](https://github.com/ProtonLumo/lumo-desktop);
> packaging reports belong here.

## What Lumo is (and what it needs from the host)

The desktop app is a Tauri shell around the Lumo web app. Unlike an Electron
app it does **not** bundle a browser engine — it links against your system's
WebKitGTK. Every package here therefore requires:

| Component | Why |
|---|---|
| `webkit2gtk-4.1` | renders the app — required by the **pacman package**; the AppImage bundles its own copy |
| `gtk3` | window, tray, dialogs (also bundled in the AppImage) |
| `libayatana-appindicator` | tray icon |
| a Secret Service provider (`gnome-keyring` or `kwallet`) | OAuth tokens, API keys, MCP credentials |

The two artifacts differ here, measurably:

- The **Arch package** links the system WebKitGTK, so `webkit2gtk-4.1` is a
  real package dependency and the installed footprint stays small (~18 MB
  binary).
- The **AppImage** is ~85 MB because Tauri's bundler (linuxdeploy with the GTK
  plugin) pulls `libwebkit2gtk-4.1`, `libjavascriptcoregtk-4.1`, GTK 3,
  libsoup 3 and the WebKit injected bundle into the image. It therefore runs on
  distributions without `webkit2gtk-4.1`; it still needs a reasonably current
  glibc, X11/Wayland, a Secret Service provider, and GStreamer plugins for
  media playback.

Because the AppImage carries its own engine, the two artifacts are not
byte-identical: the Arch package is a thin client for the system WebKitGTK,
the AppImage is self-contained and larger. Both are built from the same
upstream commit.

## Install

### Arch (pacman repository)

```ini
# /etc/pacman.conf
[lumo]
SigLevel = Required DatabaseOptional
Server = https://nichu42.github.io/lumo-desktop/arch/x86_64
```

Then:

```sh
sudo pacman -Syu lumo-desktop
```

If the repository is published unsigned, use `SigLevel = Optional TrustAll`
instead and be aware of what that means. When it *is* signed, import the key
first:

```sh
sudo pacman-key --add <(curl -fsSL https://nichu42.github.io/lumo-desktop/arch/x86_64/lumo.gpg)
sudo pacman-key --lsign-key <key id>
```

The package builds from source and replaces an earlier `lumo-bin` deb-repack
(`provides`/`conflicts`), so a `pacman -Syu` swaps it cleanly.

### AppImage (any distribution)

Download the `.AppImage` from
[Releases](https://github.com/nichu42/lumo-desktop/releases) and either run it
directly or integrate it with [Gear Lever](https://github.com/mijorus/gearlever),
which also handles updates from the GitHub releases it tracks.

```sh
chmod +x Lumo-*.AppImage
./Lumo-*.AppImage
```

Without an integration tool the AppImage has no `.desktop` entry, so the
`proton-lumo://` handler used by browser sign-in is not registered until it is
integrated. Run it once through Gear Lever/AppImageLauncher before signing in.

## Updates

- **Arch:** `pacman -Syu`. The repository is rebuilt on every tag.
- **AppImage:** Gear Lever, or re-download the release.
- **In-app updater:** leave it alone. Lumo's built-in updater reads Proton's
  manifest, which publishes `deb`/`rpm` payloads only; on an AppImage it finds
  no matching target, and in the Arch package it would try `dpkg`. Neither can
  work — the package manager (or Gear Lever) owns updates here.

## Known limitations

- **Quick ask (global shortcut).** `tauri-plugin-global-shortcut` grabs X11
  keys, so the shortcut works on X11 sessions and generally not on Wayland.
  This is an upstream limitation, not a packaging one.
- **Connectors that run shell commands** need the tools on your `PATH`
  (`npx`/`uvx` for stdio MCP servers). Install `nodejs`/`python-uv` if you use
  them; the packages do not pull them in.
- **No Flatpak.** The connectors and shell tools that make the desktop app
  useful are exactly what a sandbox blocks. A Flatpak would either be crippled
  or need `--talk-name=org.freedesktop.Flatpak`, at which point the sandbox is
  decorative.
- **Schedules** run while the app runs; nothing installs a systemd unit.

## Building it yourself

```sh
git clone https://github.com/nichu42/lumo-desktop
cd lumo-desktop

# Arch package
cd packaging/arch && makepkg -s

# AppImage (needs webkit2gtk-4.1-dev, rust, node)
npm ci
npm run build -- --bundles appimage --config packaging/appimage/tauri.appimage.json
```

The packaged version is pinned by `_commit` in `packaging/arch/PKGBUILD`; the
commit is always a commit of
[ProtonLumo/lumo-desktop](https://github.com/ProtonLumo/lumo-desktop), and no
patches are applied. `NOTICE` records the attribution and the packaging
additions; `packaging/arch/NOTICE` must stay byte-identical to it (the Arch
workflow fails otherwise).

## First-time setup (repository owner)

- **Pages:** Settings → Pages → Source: **GitHub Actions** (not "deploy from a
  branch"). The Arch workflow deploys with `deploy-pages`; the package history
  is kept on the `repo-data` branch, which is storage only and never served.
  A branch-based Pages setup would break this workflow's deploy step.
- **Signing (recommended):** add `PACMAN_GPG_KEY` (armoured private key) and
  `PACMAN_GPG_KEY_ID` as repository secrets. Without them the repo publishes
  unsigned and prints a warning in the run log.
- **Default branch:** make `packaging` the default branch, or merge it into
  `master`. GitHub only *schedules* workflows and lists `workflow_dispatch`
  entries from the default branch — with packaging living only on `packaging`
  and `master` still mirroring upstream, the daily watcher would never run.

## Releasing

1. `git fetch upstream && git merge upstream/master` (fork tracks upstream).
2. Bump `pkgver` and `_commit` in `packaging/arch/PKGBUILD`.
3. `cd packaging/arch && makepkg --verifysource` → update `sha256sums`.
4. `makepkg --printsrcinfo > .SRCINFO`.
5. Tag `v<version>` and push — both workflows build from the tag.

`upstream-watch` runs daily against Proton's signed manifest
(`https://lumo.protondownload.com/desktop/linux/latest.json`) and opens an
issue when a new version appears.
