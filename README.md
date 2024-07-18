# strap.sh

This is a highly-configurable, probably-overengineered Bash script to get yourself started from a base Arch install.
It assumes you have done basic user management, i.e. created a non-root user, but from there it can do everything
for you. It started as a custom script for myself to use with bootstrapping a new system, but I decided to try
modifying it to fit a general use case. Some parts are still specific to me, so bear with me as I remove them
bit by bit.

## Usage

`strap.sh` assumes you have a Git repository or a directory where all your dotfiles are stored. It can then clone
this repo for you, and perform all the actions you need from there.

`strap.sh` also assumes you have a list of packages installed on your system, stored in the repo/directory alongside
your dotfiles. You can easily generate this list with the command `pacman -Qq > <packagelist-name>`, for a complete
list, or `pacman Qqet` to only list explicitly-installed packages. The list to use is configurable.

For information on the command-line options, run `./strap.sh -h`.

## Configuration

`strap.sh` sources a user-configurable config script (by default `config.sh` within your repo). An example is provided
detailing all the variables you can set.
