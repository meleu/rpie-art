# rpie-art
Easy way to install art on your RetroPie.

The `rpie-art.sh` is a script that let you easily install [overlays](https://github.com/libretro/RetroArch/wiki/Overlay-image-configuration), [launching images](https://github.com/retropie/retropie-setup/wiki/runcommand#adding-custom-launching-images) and [scrape images](https://github.com/RetroPie/RetroPie-Setup/wiki/Scraper) (not yet implemented) in your RetroPie.

The art files come from other github repositories maintained by other users. You can see the art repository list in the [`repositories.txt` file](https://github.com/meleu/rpie-art/blob/master/repositories.txt).


## How to use the script?

Clone the repo and execute the script, as simple as that.

```
git clone --depth 1 https://github.com/meleu/rpie-art
cd rpie-art
./rpie-art.sh
```

After launching `rpie-art.sh` script follow the instructions in the dialog boxes.

Although the script is perfectly able to install/uninstall overlays and launching images **it's still a work in progress**. If you find some bug or want to make a suggestion, use the [issue tracker](issues).


## How can I make the script able to install my custom art?

### First of all: github account/repository

The script downloads art from github repositories, then you need to have an account to create one.

### `info.txt` file

You need to know how to use the `info.txt` file. It's pretty simple and straightforward, details [here](INFO.md).

### launching art

If you're good in making splashscreens, you're good in making launching images too! Just create your art and put the `info.txt` in the same directory. The `info.txt` for launching image only is as simple as [this example](https://github.com/meleu/rpie-art/blob/master/INFO.md#example-1-launching-image-only)

### overlay art

You need to know the configurations needed to make the overlay work. There's a [detailed doc in the RetroArch wiki](https://github.com/libretro/RetroArch/wiki/Overlay-image-configuration) but many users are succeeding by looking the @UDb23 files as templates. His repository can be found here: https://github.com/UDb23/rpie-ovl

### adding your repository to the rpie-art tool

After creating your github repository, adding some art files and filling some `info.txt` files, you can add your repo to the `rpie-art.sh` script by adding the repo URL and a description in the [`repositories.txt` file](repositories.txt) and submitting a Pull Request (if you don't know how to do it just contact me in the [issue tracker](issues)).

## A brief history of this tool

- We, RetroPie enthusiasts, started the [MAME ROW](https://retropie.org.uk/forum/topic/9011/mame-row-rules-and-list-of-rounds) where we choose a random arcade game to play every week.

- The @UDb23 came with his Computer Graphics talent and created some awesome overlays for the MAME ROW games. And then was born the most prolific game specific overlay creator in history.

- @UDb23 became a super star and his fans started a [topic in RetroPie forum](https://retropie.org.uk/forum/post/46365) to request overlays for their favorite arcade games. And, guess what? He listened to fans' requests!

- One of those fans, @meleu, was impressed by the overlays created by @UDb23 but didn't like downloading the files from websites with strange links, pages full of animations and, mainly, host services that don't let users download files directly from command line. Then @meleu suggested that the files should be hosted on github. And, guess what? the Overlay Master agreed!

- To show his infinite gratitude @meleu started to work on a bash script to let the users easily install the Overlay Master's art.

- The file naming conventions needed to make the script work began to be very confusing, then ( @backstander suggested](https://retropie.org.uk/forum/post/65486) the creation of an "information file" where the script gets the info it needs to work. And then the `info.txt` idea was born.

- The Overlay Guru's charisma, coupled with the reasonable `info.txt` simplicity, inspired those who have skills with CG software and have begun a new era of custom RetroPie art creation.
