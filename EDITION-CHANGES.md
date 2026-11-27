# 2.5.0 Edition Changes

## Both editions

- Reworked desktop into a Windows 11-inspired layout.
- Removed desktop app icons; application shortcuts are in the taskbar, with a Start menu for the full app list.
- Added right-click desktop context menu: New Folder, Text Document, Lua Script, Website Page, Files and Refresh.
- Added app title bars, close/minimise controls and a persistent taskbar while an app is open.
- Added `.lua` script launching from Files; text and HTML files open in the CraftOS editor.
- Added OS Update with staged downloads, edition-aware manifests and rollback copies.
- Added Website Studio and a persistent rednet website service.
- Added `/www/index.html` and `/www/about.html` starter pages.

## STANDARD / KL OS

- Keeps the KL OS app set and classic networking/mail/remote utilities.
- Adds Website Studio, Website Server and OS Update.
- Hosts pages for both KL Browser and HackOS Browser protocols.

## GOVERNMENT / HackOS

- Keeps Remote Center, Network, Mail, Hack and Security applications.
- Adds Website Studio and OS Update to the taskbar/Start menu.
- Can create, edit and host websites while continuing to use other applications.

## HTML compatibility

The rednet browser renders a small static HTML subset: `<title>`, headings, paragraphs, links, lists and line breaks. CSS styling and JavaScript execution are not supported. Sites are stored as ordinary HTML files under `/www`.
