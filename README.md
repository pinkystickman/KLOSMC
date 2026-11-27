# KL OS / HackOS 2.3.0

Minecraft **CC: Tweaked** operating system with two editions, rednet networking, remote administration, and internal in-game Mail.

## Editions

### Standard — KL OS

The classic KL OS desktop with Files, Shell, Browser and Security Center. It includes the Mail app and the authenticated Remote agent; incoming remote control is disabled until enabled locally in Remote Access Settings.

### Government — HackOS

The Windows-inspired HackOS desktop with Files, Browser, Network Center, Server Manager, Terminal, Remote Center, Hack Console, Security Center and Mail.

## New in 2.3.0: Remote Center

Government edition can manage multiple discovered computers from one dashboard. Each target must run KL OS / HackOS 2.3.0 (or a compatible updated remote agent), have a modem connected to the same reachable rednet network, and have **Remote Access enabled locally**. A valid eight-digit access code is required for every connection.

- **Remote Desktop:** stream the target computer's terminal screen.
- **Mouse and keyboard:** forward key, character, paste, click, drag, mouse-up and scroll events to the target. Screen coordinates are scaled to the target terminal size.
- **Cursor tracking:** click, drag, release and scroll positions update the target UI cursor. CC:Tweaked exposes mouse movement while a button is held (`mouse_drag`) but does not provide a general free-hover mouse-move event; therefore passive hover movement cannot be mirrored.
- **Remote Shell:** execute CraftOS commands with returned output.
- **File Transfer:** upload/download individual files in the target's `/public` folder. Maximum file size is 8192 bytes.
- **Power Management:** remotely restart or shut down a connected target, with a confirmation prompt.
- **Multi-PC dashboard:** discover and select multiple remote-enabled computers.

Remote Desktop uses a terminal mirror and is not a Minecraft game-world video stream. It displays the target computer's CC:Tweaked terminal UI. Screen capture needs CC:Tweaked 1.84.0 or newer (`window.getLine`). The controller should be an advanced computer to generate physical mouse events; the target can be any supported CC computer. Keyboard navigation works on regular computers too.

## New: HackOS internal Mail

Mail is an in-game messaging system transported over rednet, not external SMTP/Internet email. Each computer has one local mailbox address such as `admin@computer-12`. Open **Mail → Network Scan** to discover mail-enabled nodes, then compose to the recipient's mailbox address. Inbox and Sent folders are saved locally. Mail requires the recipient to be online and running the 2.3.0 mail service.

- Mailbox usernames can be changed in Mailbox Settings.
- Subject limit: 100 characters.
- Body limit: 3000 characters.
- Up to 100 inbox and 100 sent messages are retained per computer.

## Hack Console / exploit-lab

Government edition can also discover KL OS / HackOS computers exposing the deliberate, Minecraft-only legacy diagnostics endpoint, even when normal Remote Access is disabled. This is a read-only guest session for basic diagnostics and text files inside `/public`. It does not grant remote desktop, keyboard/mouse control, arbitrary shell commands, file modification, or power management. A target owner can patch the endpoint in Security Center.

## Setup / install

Publish the contents of this package (not the outer `HackOS-2.3.0` folder) to the root of the `main` branch of:

`https://github.com/pinkystickman/KLOSMC`

Then run on each computer:

```text
wget https://raw.githubusercontent.com/pinkystickman/KLOSMC/main/install.lua install.lua
install.lua
```

Choose **STANDARD / KL OS** or **GOVERNMENT / HACKOS** in the graphical installer. The installer is configured to download files from the repository's `main` branch. GitHub is not updated automatically by this ZIP.

## Networking and compatibility

- Uses CC:Tweaked `rednet` over wired, wireless or Ender modems. Wired networks need wired modems and networking cable.
- Logical IPv4 addresses identify CC computers; they are not actual TCP/IP addresses.
- Every participant needs a modem attached and must be on a network reachable by rednet.
- Remote Control, Remote Desktop, File Transfer and Power require the target's local Remote Access setting and access code.
- Hack Console read-only diagnostics and Mail are separate services.
- File transfer is restricted to `/public`.

## Security note

This project is a Minecraft/CC:Tweaked roleplay and learning OS, not a secure real-world administration platform. Rednet packets and access codes are not encrypted by this project. Use only in trusted worlds and do not expose the network to untrusted players.

## License

MIT. See `LICENSE`.
