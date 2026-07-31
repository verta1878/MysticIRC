# Installation

## Windows x64

1. Download `Rez2ANS-Next-3.1.0-Windows-x64-Setup.exe` from the current release folder or GitHub Release.
2. Optionally verify it against `SHA256SUMS`.
3. Run the installer and follow the prompts.
4. Launch **Rez2ANS Next** from the Start Menu.

The installer places the application in Program Files, adds an Apps & Features entry, and includes an uninstaller.

## Debian, Ubuntu, and Mint x64

Download `rez2ans-next_3.1.0_amd64.deb`, then install it with your graphical package installer or from a terminal:

```bash
sudo apt install ./rez2ans-next_3.1.0_amd64.deb
```

If your system reports missing dependencies, run:

```bash
sudo apt --fix-broken install
```

Launch Rez2ANS Next from your applications menu after installation.

The package supports Debian 13 and current Ubuntu/Mint releases without a
manual Qt compatibility package. APT selects the correct Qt 6 package names
for your distribution.

## Linux x64 AppImage

The AppImage is a portable alternative to the Debian package. Download
`Rez2ANS_v3.1-x86_64.AppImage`, make it executable, and run it:

```bash
chmod +x Rez2ANS_v3.1-x86_64.AppImage
./Rez2ANS_v3.1-x86_64.AppImage
```

It includes the Qt runtime and does not install files into your system. A
standard graphical Linux desktop session is required.

## Linux x64 Flatpak

Download `Rez2ANS-Next-3.1.0-x86_64.flatpak`, then install and run it:

```bash
flatpak install --user ./Rez2ANS-Next-3.1.0-x86_64.flatpak
flatpak run com.suddendeaththgsketch.Rez2ANSNext
```

The Flatpak includes a stable Qt runtime and avoids Linux distribution package
differences. It is CPU-only in this release, so conversions can be slower than
the Debian package or AppImage when Vulkan acceleration is available. See the
[Flatpak guide](FLATPAK.md) for details.

## Vulkan acceleration

Vulkan is optional. When a compatible GPU and driver are available, Rez2ANS Next can offer its Vulkan-accelerated path. The normal CPU path remains available and does not require a discrete NVIDIA card.

Keep your graphics driver current. If a Vulkan option is unavailable or causes problems, use the CPU path and include your GPU and driver details when asking for help.

## Updating

Install a newer release over an older one using the same platform installer. Keep any profiles or export folders you want to preserve before uninstalling.
