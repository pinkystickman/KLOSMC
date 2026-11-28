# Floppy Disk Storage Tutorial — KL OS / HackOS 3.0.0

## What you need

- One CC:Tweaked computer running KL OS Standard or HackOS Government.
- One or more CC:Tweaked Disk Drive blocks.
- One or more floppy disks.
- Optional: wired modem(s) and cable if exposing compatible peripherals over a wired peripheral network.

## Build the storage station

1. Craft a Disk Drive using the recipe shown by your installed CC:Tweaked version or recipe viewer. The standard recipe uses stone and redstone dust; modpacks can alter recipes.
2. Place the computer.
3. Place the first Disk Drive next to a side of the computer.
4. Insert a floppy disk in the drive.
5. Repeat with additional drives where your world/peripheral layout allows. Each drive holds one inserted item at a time.
6. Open Disk Manager and press `R` to refresh. The app lists every drive peripheral visible to the computer.

For the first test, keep one Disk Drive directly adjacent to the computer. Once that works, add more drives or experiment with wired modem exposure. CC:Tweaked's `disk` functions accept local sides and remote peripheral names, but mount visibility depends on the peripheral topology/version.

## Copy files

### Computer → floppy

1. Select the drive with the inserted floppy.
2. Press `O`.
3. Enter a source path, for example `/Documents/notes.txt` or `/www/index.html`.
4. Enter a relative destination, for example `notes.txt` or `web/index.html`.
5. If the destination already exists, type `OVERWRITE` to replace it.

Allowed source areas are `/Documents`, `/www` and `/Applications`. System folders are intentionally excluded.

### Floppy → computer

1. Select the inserted disk.
2. Press `I`.
3. Enter a path relative to the disk root, for example `notes.txt`.
4. Choose the destination filename in `/Documents`.
5. If needed, approve overwrite by typing `OVERWRITE`.

### Label and eject

- Press `L` to change the disk label (leave blank to clear it).
- Press `E`, then type `EJECT` to eject it.
- Do not eject a disk while a file copy is in progress.

## How storage appears in CC:Tweaked

CC:Tweaked mounts floppy media as folders in the computer filesystem, commonly `/disk`, `/disk2`, etc. Disk Manager asks the disk API for the current mount path rather than assuming a fixed disk name. This allows multiple inserted disks to be handled without a hard-coded maximum count.

Each floppy is a separate volume with finite capacity. Disk Manager does not merge them into one huge disk, stripe files across disks, or make storage infinite. Keep a second copy of important files on another disk or computer.

## One-computer storage station

Use one computer as the physical storage station. Connect its drives and manage all inserted floppies with Disk Manager on that computer. In 3.0.0, this is local storage management; it does not publish every floppy as a shared network drive. A later Disk Station service can add authenticated network access to the attached disks.


## Back up Malware Lab scenarios (Government)

The Disk Manager allows copying data from `/HackOS-Lab` to a floppy. Use `O` and enter a path such as `/HackOS-Lab/scenarios/ransomware-demo.klvirus`. This file is a JSON simulation description, not executable malware.
