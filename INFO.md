# `info.txt` file specification

In order to let the `rpie-art.sh` script work fine, every art directory **MUST** have a file named `info.txt`, from where the script gets all the information it needs to automate the art installation.

The `info.txt` format is:

```
# comments
key = "value"
```

## Straight to examples

Maybe some examples can explain things pretty straightforward.

### Example 1: launching image only

This file can be named, for example, `nes/Contra/info.txt`:

```
game_name = "Contra"
system = "nes"
launching_image = "lilbud-contra.jpg"
```

The `lilbud-contra.jpg` file must be in the same directory (in this example the directory is `nes/Contra/`).

### Example 2: overlay only

This file can be named, for example, `arcade/Pac-Man/info.txt`:

```
game_name = "Pacman"
system = "arcade"
rom_config = "pacman.zip.cfg"
overlay_config = "pacman.cfg"
overlay_image = "pacman_udb-ovl.png"
```

All the files (`pacman.zip.cfg`, `pacman.cfg` and `pacman_udb-ovl.png`) must be in the same directory (in this example the directory is `arcade/Pac-Man/`).

### Example 3: two options for overlay images

This file can be named, for example, `arcade/Marvel vs. Capcom- Clash of Super Heroes/info.txt`:

```
game_name = "Marvel vs Capcom"
system = "arcade"
rom_config = "mvsc.zip.cfg"
overlay_config = "mvsc.cfg"
overlay_image = "mvsc_udb_1-ovl.png; mvsc_udb_2-ovl.png"
```
The image file names must be separated by a semicolon.

### Example 4: complete art set for a game

This file can be named, for example, `arcade/Burning Force/info.txt`:

```
# game_name: REQUIRED
game_name = "Burning Force"

# system: REQUIRED
system = "arcade"

# creator: OPTIONAL
creator = "UDb23"

# rom_config: OPTIONAL (REQUIRED for overlays)
rom_config = "burnforc.zip.cfg"

# overlay_config: OPTIONAL (REQUIRED for overlays)
overlay_config = "burnforc.cfg"

# overlay_image: OPTIONAL (REQUIRED for overlays)
overlay_image = "burnforc_udb-ovl.png"

# rom_clones: OPTIONAL
rom_clones = "burnforco"

# launching_image: OPTIONAL (REQUIRED for launching images)
launching_image = "burnforc-launching.png"

# scrape_image: OPTIONAL (REQUIRED for scrape images)
scrape_image = "burnforc-image.png"
```

Below we have a detailed description of every valid `info.txt` entry.

## `game_name`: REQUIRED

A string with the game name.

The script ignores the file if it doesn't have the `game_name` entry.

If the art is a system generic overlay (e.g.: a launching image for the NES system), game_name MUST be `_generic`

**Example:**
```
game_name = "Mega Man"
```

## `system`: REQUIRED

The system that runs the game (e.g.: nes, megadrive, neogeo, fba, etc.).

The script ignores the file if it doesn't have the `system` entry.

Use the same name as the RetroPie uses (those directories at `$HOME/RetroPie/roms/` and `/opt/retropie/configs/` are good examples).

**Example:**
```
system = "nes"
```

## `creator`: OPTIONAL

The artist that made the art.

**Example:**
```
creator = "meleu"
```


## `launching_image`: OPTIONAL

The image filename to use as runcommand launching art. If there are more than one image option, separate them with semicolon and the script will let the user choose one.

**Example:**
```
launching_image = "RomName_1-launching.png; RomName_2-launching.png"
```

The `launching_image` can also be an URL (http/https only) pointing to an image from the web. **Example**:

```launching_image = "https://raw.githubusercontent.com/HerbFargus/retropie-splashscreens-extra/master/megaman.jpg"```


## `scrape_image`: OPTIONAL

The image filename to use as emulationstation art. If there are more than one option, separate them with semicolon and the script will let the user choose one.

**Example:**
```
scrape_image = "RomName_1-image.png; RomName_2-image.png"
```

The `scrape_image` can also be an URL (http/https only) pointing to an image from the web. **Example**:

```scrape_image = "https://raw.githubusercontent.com/UDb23/rpie-ovl/master/arcade/Lunar%20Rescue/lrescue-image.png"```

## `rom_config`: OPTIONAL (REQUIRED for overlays)

The ROM config file name that stays in the same directory as the ROM.

- **RULE:** If it's an arcade game overlay, it's pretty simple: `ROM.zip.cfg`
- **GUIDELINE:** If it's a system generic overlay use `system.cfg`. Examples: `nes.cfg`, `gba.cfg`, `neogeo.cfg`.
   Generic overlays should be placed in subfolder named `_GENERIC` under the specific console folder.
- **GUIDELINE:** If it's a console game overlay, use `GameName.cfg`. But since there's no rule for console ROM file names, the script will try to find some ROMs based on the `game_name` entry and show the options to let the user choose (the script looks at the respective system's gamelist.xml and the actual file system).

**Example:**
```
rom_config = "RomFileName.cfg"
```

## `overlay_config`: OPTIONAL (REQUIRED for overlays)

The overlay config file name.

**Example:**
```
overlay_config = "RomName.cfg"
```


## `overlay_image`: OPTIONAL (REQUIRED for overlays)

The overlay image filename itself. If there are more than one image option, separate them with semicolon and the script will let the user choose one.

**Example:**
```
overlay_image = "RomName_artist_1-ovl.cfg; RomName_artist_2-ovl.cfg"
```


## `rom_clones`: OPTIONAL (usually used for arcade game overlays)

List of clones that can use the same overlay as the parent ROM separeted with a semicolon (don't use the trailing `.zip`).

**Examples:**
```
rom_clones = "romA; romB; romC"
```



