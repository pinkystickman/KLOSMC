# KL OS / HackOS 2.8.0

A two-edition operating system for Minecraft CC: Tweaked.

## Editions

- **Standard / KL OS**: Windows-inspired desktop, Files, Browser, Terminal, KL Store, KL Maker, Website Studio, Server, Network, Remote, Mail, Antivirus, Security Settings and OS Update.
- **Government / HackOS**: all shared applications plus Hack Console and the full multi-computer Remote Center.

## Protected Antivirus Security Channel

The root file `/security.lua` is the protected security core. Normal OS Update and installer upgrade flows will not overwrite it once it exists. If it is missing on an older installation, the OS updater may install the baseline core once.

To update security, open **Antivirus → Check for Security Updates**. Antivirus checks `security/manifest.json`, shows the available version and release notes, and waits for explicit approval. To install, type `UPDATE`. The patch is restricted to the protected `security.lua` target, downloaded to staging, checked for valid Lua syntax, backed up, and then installed. The computer reboots so the new module is loaded cleanly.

The security update feed is independent from `manifest.json`; ordinary OS updates do not update the protected security core. `apps/antivirus.lua` is a normal OS application and can receive UI improvements through ordinary OS updates.

**Trust note:** security files are fetched over HTTPS from the configured GitHub repository, but this release does not implement cryptographic publisher signatures. Use a repository you control and do not treat this Minecraft feature as enterprise-grade endpoint security.

## Remote Desktop

Both editions include the remote agent. On the target computer, open Remote and enable incoming access; share its displayed 8-digit code with the controller. On Government, open Remote, scan, select the target and authenticate. Choose Remote Desktop to see its live terminal UI.

CC:Tweaked does not provide passive mouse-hover events. Remote clicks and dragging are forwarded, but the cursor cannot be mirrored while moving without a button pressed. Rednet traffic is not encrypted by this project.

## Website hosting

Website Studio creates pages in `/www`; enable hosting in Server. It hosts pages over the in-game rednet network for the KL/HackOS browser.

## Install

Upload the contents of this folder to the root of `https://github.com/pinkystickman/KLOSMC` (main branch), then on a CC:Tweaked computer run:

```lua
wget https://raw.githubusercontent.com/pinkystickman/KLOSMC/main/install.lua install.lua
install.lua
```

Choose Standard or Government in the installer. HTTP must be enabled in the CC:Tweaked server configuration.

## Important

This is an in-game Minecraft OS, not a real-world remote administration platform. Use remote controls only on computers you own or have permission to administer.
