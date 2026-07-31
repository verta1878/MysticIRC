# Flatpak

The Rez2ANS Next Flatpak is a portable, sandboxed Linux x64 package. It is a
good choice when you want the same Qt runtime across different distributions.

## Install

```bash
flatpak install --user ./Rez2ANS-Next-3.1.0-x86_64.flatpak
flatpak run com.suddendeaththgsketch.Rez2ANSNext
```

Use `--user` to install it only for your account. Flatpak may download the KDE
Qt runtime the first time you install an application using it.

## Performance

The 3.1.0 Flatpak intentionally uses the CPU conversion path and does not ship
the optional Vulkan backend. It may be slower than the native Debian package
or AppImage on a system where Vulkan acceleration is available. Choose the
Debian package or AppImage for maximum conversion speed.

## Updating and removal

```bash
flatpak update com.suddendeaththgsketch.Rez2ANSNext
flatpak uninstall com.suddendeaththgsketch.Rez2ANSNext
```
