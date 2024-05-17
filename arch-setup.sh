# the partitioned device
DEVICE="
    sda
"
# mount position inside MOUNTPOINT | partition information | encryption setup
PARTITION="
    /boot | ext4 1MiB   256MiB | mkfs.ext4
    /     | ext4 256MiB 64GiB  | mkfs.ext4
    /home | ext4 64GiB  100%   | mkfs.ext4
"
USERNAME="
    random user name
"
PASSWORD="
    bassword or whatever
"
MOUNTPOINT="
    /mnt
"
PACKAGES="
    intel-ucode
    nvidia
    ttf-dejavu
    ttf-liberation
"
HOSTNAME="
    arch
"
REGION="
    Asia
"
CITY="
    Shanghai
"
LOGFILE="
    /tmp/arch-setup-log-file.txt
"

RED=$'\e[031m'
CYAN=$'\e[036m'
BOLD=$'\e[1m'

trim() {
    echo -e "${@}" | sed -e 's/^[[:space:]]*//' | awk 'NF' -
}

path-fmt() {
    echo -e "${@}" | sed "s/\/$//" | sed "s/\/+/\//"
}

STAGE=()
COLOR=()
add-prefix() {
    STAGE+=("$1")
    COLOR+=("$2$3$4")
}

pop-prefix() {
    unset STAGE[-1]
    unset COLOR[-1]
}

tell() {
    local STOPCOLOR=$'\e[030m\e[022m'
    trim "$@" \
    | sed "s/^/${COLOR[-1]}[${STAGE[-1]}]${STOPCOLOR} /g" \
    | sed "s/\r/\n/g"
}

HOOK=()
hook() {
    HOOK+=("$@")
}

fail() {
    add-prefix "ERROR" $RED $BOLD
    tell "$@"
    for I in $(seq 1 ${#HOOK[@]})
    do
        tell ${HOOK[-$I]}
        ${HOOK[-$I]} >& /dev/null || {
            tell "While executing cleanup hook, '$H' failed. "
        }
    done
    exit 1
}

# check if device exists
disk-check() {
    add-prefix 'CHECK DISK' $CYAN $BOLD
    local DEVLIST=$(find /dev | sed "s/^\/dev\///")
    local EXISTS=0
    for D in ${DEVLIST}
    do
        if [[ $(trim $1) == $D ]]
        then
            EXISTS=1
        fi
    done
    if [[ $EXISTS == 0 ]]
    then
        fail "
            Device [$(trim $1)] doesn't exist!
            Existing device: $(trim ${DEVLIST} | sed 's/ /, /g')
        "
    else
        tell "
            Device [$(trim $1)] successfully detected.
            Finish disk check.
        "
    fi
    pop-prefix
}

# partition disk
# $1: device
# $2: partition settings
disk-partition() {
    add-prefix 'PARTITION' $CYAN $BOLD
    tell "
        Install parted using pacman. 
        -- Don't you worry. 
        -- This only happens in ram. 
    "
    pacman -Sy --noconfirm parted >& $(trim $LOGFILE) || {
        fail "
            Cannot install 'parted'. Are you superuser?
            -- We need 'parted' to partition the disk!
        "
    }
    tell "Generate guid partition table"
    parted --script /dev/$(trim "$1") -- mklabel gpt >& $(trim $LOGFILE) || {
        fail "
            Fail to generate guid partition table (gpt). 
            Reason: \"$(cat $(trim $LOGFILE))\"
        "
    }
    local LINE=""
    while read LINE
    do
        local LINE=$(trim $(echo $LINE | awk '{split($0,a,"|"); print a[2]}'))
        tell "Make partition with configuration: $LINE"
        parted --script /dev/$(trim "$1") -- mkpart $LINE >& $(trim $LOGFILE) || {
            fail "
                Cannot partition the disk. are you superuser? what about alignment?
                Reason: \"$(cat $(trim $LOGFILE))\"
            "
        }
    done < <(trim "$2")
    pop-prefix
}

# make file systems on disk
# $1: device name
# $2: partition settings
disk-fs-format() {
    add-prefix 'FS FORMAT' $CYAN $BOLD
    # split lines to make arrays
    local CONF
    local PARS
    readarray CONF < <(trim "$2")
    readarray PARS < <(find /dev | grep -P "/dev/$(trim $1).+")
    if [[ ${#CONF[@]} != ${#PARS[@]} ]]
    then
        fail "The number of partitions is different from the number of configured partitions. "
    fi
    # file systems on partitions
    for I in $(seq 0 $((${#PARS[@]} - 1)))
    do
        local MKF="$(trim $(echo ${CONF[$I]} | awk '{split($0,a,"|"); print a[3]}'))"
        local PAR=$(trim ${PARS[$I]})
        tell "Format file system $MKF $PAR. Wait..."
        $MKF $PAR >& /dev/null || {
            fail "Cannot make file system (with $MKF) on $PAR. "
        }
    done
    pop-prefix
}

# mount partitions to mountpoints
# $1: device name
# $2: disk partition plan
# $3: mount point root
disk-mount() {
    add-prefix "MOUNT DISK" $CYAN $BOLD
    local CONF
    local PARS
    readarray CONF < <(trim "$2")
    readarray PARS < <(find /dev | grep -P "/dev/$(trim $1).+")
    if [[ ${#CONF[@]} != ${#PARS[@]} ]]
    then
        fail "The number of partitions is different from the number of configured partitions. "
    fi
    for I in $(seq 0 $((${#PARS[@]} - 1)))
    do
        local POS="$(trim $3)$(trim $(echo ${CONF[$I]} | awk '{split($0,a,"|"); print a[1]}'))"
        local PAR=$(trim ${PARS[$I]})
        tell "$PAR <-> $POS"
        mount --mkdir $PAR $POS >& $(trim $LOGFILE) || {
            fail "$(cat $(trim $LOGFILE))"
        }
        hook "umount -l $POS"
    done
    pop-prefix
}

# partition disk, encrypt disk, and install base system
install-pre() {
    pacman -Syy >& $(trim $LOGFILE) \
    || fail "Cannot update pacman database. "
    disk-check     "$DEVICE"
    disk-partition "$DEVICE" "$PARTITION"
    disk-fs-format "$DEVICE" "$PARTITION"
    disk-mount     "$DEVICE" "$PARTITION" "$MOUNTPOINT"
    pacstrap -K /mnt base base-devel linux linux-firmware sudo >& $(trim $LOGFILE) \
    || fail "Cannot install base base-devel linux linux-firmware sudo"
    genfstab -U $(trim $MOUNTPOINT) >> $(trim $MOUNTPOINT)/etc/fstab
}

# configure boot loading behaviour (systemd)
conf-systemd-boot() {
    # https://wiki.archlinux.org/title/Systemd-boot
    bootctl install
    # query fstab for root guid
    local UUID=$(cat /etc/fstab | awk '$2 == "/"' | awk $'{split($1,f,"=")\nprint f[2]}')
    local FSTY=$(cat /etc/fstab | awk '$2 == "/"' | awk $'{print $3}')
    # detect microcode image (https://wiki.archlinux.org/title/Microcode)
    if   [[ -f /boot/amd-ucode.img ]]; then
        local UCOD='/amd-ucode.img'
    elif [[ -f /boot/intel-ucode.img ]]; then
        local UCOD='/intel-ucode.img'
    else
        fail "
            you didn't install intel-ucode or amd-ucode.
            for fuck sake, what chip are you using?
        "
    fi
    # configure kernel & ramfs image generation (https://wiki.archlinux.org/title/Mkinitcpio)
    (cat - > /etc/mkinitcpio.conf) < <(trim "
        MODULES=()
        BINARIES=()
        FILES=()
        HOOKS=(base udev autodetect keyboard keymap modconf block filesystems fsck)
    ")
    # generate kernel & ramfs image
    mkinitcpio \
        -k /boot/vmlinuz-linux \
        -g /boot/initramfs-linux.img 
    # configure boot loader to load linux image and micro code (https://wiki.archlinux.org/title/Systemd-boot)
    (cat - > /boot/loader/entries/arch.conf) < <(trim "
        title   Arch Linux
        linux   /vmlinuz-linux
        initrd  $UCOD
        initrd  /initramfs-linux.img
        options root=PARTUUID=$UUID rw rootfstype=$FSTY
    ")
    # configure boot loader option menu
    (cat - > /boot/loader/loader.conf) < <(trim "
        timeout 5
        default arch
    ")
}

# configure network
conf-network() {
    # hostname
    (cat - > /etc/hostname) < <(trim "
        $HOSTNAME
    ")
    # TODO: we will worry about this part later
    (cat - > /etc/hosts) < <(trim "
        # IPv4 Hosts
        127.0.0.1    localhost
        ::1          localhost
        127.0.1.1    $HOSTNAME
        # IPv6 Hosts
        ::1		localhost	ip6-localhost	ip6-loopback
        ff02::1 	ip6-allnodes
        ff02::2 	ip6-allrouters
    ")
}

# configure localization
conf-localize() {
    # locale setup
    locale-gen
    (cat - > /etc/locale.gen) < <(trim "
        en_US.UTF-8 UTF-8
    ")
    (cat -> /etc/locale.conf) < <(trim '
        LANG="en_US.UTF-8"
        LC_COLLATE="C"
    ')
    # timezone setup
    ln -sT "/usr/share/zoneinfo/$(trim "$REGION")/$(trim "$CITY")" /etc/localtime
    hwclock --systohc
}

# after base system setup, boot into archlinux, and run everything
install-post() {
    # install all listed packages
    pacman -Sy --noconfirm $(trim "$PACKAGES")
    conf-network
    conf-localize
    # user setup
    passwd $USER < <(trim "
        $PASSWORD
        $PASSWORD
    ")
    conf-systemd-boot
}

if [[ "$1" == "install-post" ]]
then
    add-prefix "POST-INSTALLATION" $CYAN $BOLD
    install-post
    pop-prefix
else
    add-prefix "PRE-INSTALLATION" $CYAN $BOLD
    install-pre
    cp $0 "$(trim $MOUNTPOINT)/setup.sh" >& $(trim $LOGFILE) \
    || fail "cannot copy current script to $(trim $MOUNTPOINT)/setup.sh"
    arch-chroot "$(trim $MOUNTPOINT)" /setup.sh install-post \
    || fail "chroot & execute failed $(trim $MOUNTPOINT)"
    pop-prefix
fi