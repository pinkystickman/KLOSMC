# HackOS for CC: Tweaked

HackOS is a lightweight, Windows-inspired graphical operating environment for Minecraft **CC: Tweaked**. It builds on the original KL OS project and adds a logical IP-address layer, node discovery, and a web server which can run on any CC computer.

## Features

- Windows-inspired colour desktop, taskbar, launcher, mouse support and keyboard cursor.
- File Explorer, CraftOS terminal and in-game browser.
- Network Center with a configurable logical IPv4 address and hostname.
- Network discovery over CC: Tweaked rednet.
- Server Manager: any computer running the Server app can host a HackOS website and answer node-discovery requests.
- Browser access by IP address or advertised hostname.
- Graphical installer with download progress and a backup of an existing non-HackOS `startup.lua`.

## Install

**Publish the package to GitHub first.** This ZIP contains the finished HackOS source, but it does not automatically change the remote repository. Open the `HackOS-2.0.0` folder in this archive and upload its *contents* (not the outer folder) to the root of the `main` branch of `pinkystickman/KLOSMC`, replacing the old KL OS files. Commit the changes.

Then:

1. Use an Advanced Computer for the full colour experience. A modem is required for networking; wired modems and networking cable work well for a local wired network. Wireless and Ender modems are also opened by HackOS when available.
2. Enable the CC:Tweaked HTTP API in the world/server configuration.
3. At the CraftOS prompt, run:

   ```text
   wget https://raw.githubusercontent.com/pinkystickman/KLOSMC/main/install.lua install.lua
   install.lua
   ```

4. Choose **Install HackOS**. The computer reboots when installation is complete.

The installer is configured to download its manifest and files from:
`https://raw.githubusercontent.com/pinkystickman/KLOSMC/main/`

## Network setup

- Connect the computers with wired modems and network cable, or use wireless / Ender modems. Attachments must be compatible with the same rednet network.
- Open **Network Center** to view or change the computer's logical IPv4 address and hostname.
- Addresses default to a deterministic private-style address based on the CC computer ID. Set static addresses that are unique on your network.
- The **Server** app turns the current computer into a discoverable node and web host. Keep the Server Manager open while clients connect.
- Open **Browser**, then enter a server's IP address (for example `10.0.0.25`) or its advertised hostname. Use **Directory** to scan for active HackOS server nodes.

## Important networking details

HackOS IP addresses are a lightweight **logical addressing layer**, not a full TCP/IP stack. Packets are transported by CC: Tweaked `rednet`, which addresses computers using their in-game computer IDs. The IP-to-computer mapping is discovered through HackOS node announcements. A node must be running the Server app to answer discovery requests and host the bundled website. Wired modem links provide the physical network path between computers; they do not create an actual Internet connection.

## Security notice

HackOS is intended for Minecraft roleplay, learning and hobby projects. CC: Tweaked rednet does not provide authentication, encryption, or sender verification by itself. The logical IP addresses and Windows-like appearance do **not** make this a secure real-world operating system. Do not use it for real government, confidential, or sensitive data.

## Project layout

- `install.lua` — graphical GitHub installer
- `startup.lua` — boot entry point and crash screen
- `os/` — desktop, UI and network modules
- `apps/` — Files, Terminal, Browser, Network Center and Server apps
- `server/webserver.lua` — discovery responder and in-game web host

## License

MIT. See [LICENSE](LICENSE).
