# config file for strap.sh.
# WARNING: DO NOT CHANGE ANY VARIABLE NAMES.
# you will break strap.sh if you do.

### PACKAGE LIST FILE ###

# the files to source the package list from.
# uses pkg_list_ess if -e flag is set.
declare pkg_list="fullpackagelist"

# strap.sh can run user-specified hooks at various points
# during the bootstrap process. Each hook is a Bash function,
# that you then add to the arrays below.

### PRE-INSTALL-HOOKS ###

declare -a pre_install_hooks=()

### POST-INSTALL-HOOKS

declare -a post_install_hooks=(
    clone_all_remote_projects
)

### POST-LINK-HOOKS

declare -a post_link_hooks=(

)

# example hook: read a remote_urls file and clone each url, assuming it is a git repo
function clone_all_remote_projects() {
    # check that a remote urls file exists
    [[ -e ./remote_urls ]] || echo "remote-url file not present!"; return 1
    # check if projects dir exists, create if not
    [[ -e ~/Projects ]] || mkdir ~/Projects
    cd_back=$PWD

    cd ~/Projects
    while read url; do
        git clone "$url"
    done < remote_urls
    cd "$cd_back"
}

### LINK DIRECTORIES
# list of dest and source files
# key: dest file
# value: src file

# Add directories as needed.
declare -Ag linkdirs=(
    ["$CONFIG_DIR/alacritty/alacritty.yml"]="alacritty/alacritty.yml"
    ["$CONFIG_DIR/cava/config"]="cava/config"
    ["$CONFIG_DIR/dunst/dunstrc"]="dunst/dunstrc"
    ["$CONFIG_DIR/fish/config.fish"]="fish.config.fish"
    ["$CONFIG_DIR/i3/config"]="i3/config"
    ["$CONFIG_DIR/i3/i3lock"]="i3/i3lock"
    ["$CONFIG_DIR/mpd/mpd.conf"]="mpd/mpd.conf"
    ["$CONFIG_DIR/mpd/mpd_notify.sh"]="mpd/mpd_notify.sh"
    ["$CONFIG_DIR/ncmpcpp/config"]="ncmpcpp/config"
    ["$CONFIG_DIR/nvim/init.vim"]="nvim/init.vim"
    ["$CONFIG_DIR/picom/picom.conf"]="picom/picom.conf"
    ["$CONFIG_DIR/polybar/config"]="polybar/config"
    ["$CONFIG_DIR/qtile/autostart.sh"]="qtile/autostart.sh"
    ["$CONFIG_DIR/config.py"]="qtile/config.py"
    ["$CONFIG_DIR/scrot/run.sh"]="scrot/run.sh"
    ["$CONFIG_DIR/spectrwm/bar_action.sh"]="spectrwm/bar_action.sh"
    ["$CONFIG_DIR/spotify-dbus.sh"]="spotify/spotify-dbus.sh"
    ["$CONFIG_DIR/xmobar/xmobarrc"]="xmobar/xmobarrc"
    ["$CONFIG_DIR/xmonad/xmonad.hs"]="xmonad/xmonad.hs"
)

