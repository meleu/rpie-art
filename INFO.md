# `info.txt` file specification

In order to let the `rpie-art.sh` script work fine, every art directory **MUST** have a file named `info.txt`, from where the script gets all the information it needs to automate the art installation.

The `info.txt` format is:

```
# comments
key = "value"
```

Below we have a description of every valid `info.txt` entry.

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


## `rom_clones`: OPTIONAL (used for arcade game overlays only)

List of clones that can use the same overlay as the parent ROM separeted with a semicolon (don't use the trailing `.zip`).

**Examples:**
```
rom_clones = "romA; romB; romC"
```


