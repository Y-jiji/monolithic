############################
#                          #
#      Configuration       #
#                          #
############################

# the disk to setup your system
DEVICE='sda'
# your region information
REGION='Asia'
# your city
CITY='Shanghai'
# log file for temporary outputs
LOGFILE='/tmp/arch-setup.txt'
# the mounting point for your root partition
MOUNTPOINT='/mnt/disk'
# just the user name
USERNAME='y-jiji'
# your password, change it to yours (and i don't use this one for any of my machines)
PASSWORD='awesome-archlinux'
# host name, your shell prompt will look like user@hostname when you login
HOSTNAME='arch'
# disk partitions, currently there is a root partition and a boot partition
PARTITION='
             /     | primary ext4  1GiB   100%  |     | mkfs.ext4 -v
             /boot | primary fat32 1MiB   1GiB  | esp | mkfs.vfat -F32
             '
# pacman mirrorlist, packages will be downloaded from the following servers. 
MIRRORLIST='
             # US
             # Server =http://mirror.cs.vt.edu/archlinux/$repo/os/$arch
             # Server =http://www.gtlib.gatech.edu/pub/archlinux/$repo/os/$arch
             # CN
             # Server =https://mirrors.sjtug.sjtu.edu.cn/archlinux/$repo/os/$arch
             # Server =http://mirrors.bfsu.edu.cn/archlinux/$repo/os/$arch
             # Server =http://mirrors.aliyun.com/archlinux/$repo/os/$arch
             '
# pacman package list, the following packages will be installed by default 
PACKAGES='
             sudo       vim            git            code
             amd-ucode  linux          linux-firmware nvidia
             gnome      networkmanager
             ttf-dejavu ttf-liberation
             '
# hosts, namely how host names are mapped to ip-addresses
HOSTS='
             # IPv4 Hosts
             127.0.0.1    localhost
             ::1          localhost
             127.0.1.1    $1
             # IPv6 Hosts
             ::1        localhost    ip6-localhost    ip6-loopback
             ff02::1    ip6-allnodes
             ff02::2    ip6-allrouters
             '

##########################
#                        #
#      Logger Setup      #
#                        #
##########################

RED=$'\e[031m'
CYAN=$'\e[036m'
BOLD=$'\e[1m'
GREY=$'\e[38;5;7m'
STOPCOLOR=$'\e[0m'

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
    tell "{START}"
}

pop-prefix() {
    tell "{END}"
    unset STAGE[-1]
    unset COLOR[-1]
}

with-retry() {
    local COUNT=$1
    shift
    for I in $(seq 1 $COUNT)
    do
        $@
        if [[ $? ==0 ]]; then break; fi
        if [[ $I ==$COUNT ]]
        then
            fail "Cannot finish command '$@' (retry $COUNT)"
        fi
    done
}

tell() {
    local PREFIX=""
    for I in $(seq 0 $((${#COLOR[@]}-1)))
    do
        PREFIX="${PREFIX}:: ${COLOR[$I]}${STAGE[$I]}${STOPCOLOR} "
    done
    trim "$@" \
    | sed "s/^/${PREFIX}:: /g" \
    | sed "s/\r/\n/g"
}

##############################
#                            #
#       Cleanup Hooks        #
#                            #
##############################

FAILHOOKS=()
hook() {
    FAILHOOKS+=("$@")
}

fail() {
    add-prefix "ERROR" $RED
    tell "$@"
    for I in $(seq 1 ${#FAILHOOKS[@]})
    do
        tell ${FAILHOOKS[-$I]}
        ${FAILHOOKS[-$I]} >& /dev/null || {
            tell "While executing cleanup hook, '${FAILHOOKS[-$I]}' failed. "
        }
    done
    exit 1
}

########################################
#                                      #
#   Pre-installation Tool functions    #
#                                      #
########################################

# check if device exists
# $1: the device to check
setup-disk-check() {
    add-prefix 'CHECK DISK'
    local DEVLIST=$(find /dev | sed "s/^\/dev\///")
    local EXISTS=0
    for D in ${DEVLIST}
    do
        if [[ $(trim $1) ==$D ]]
        then
            EXISTS=1
        fi
    done
    if [[ $EXISTS ==0 ]]
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
setup-partition() {
    add-prefix 'PARTITION'
    tell "
        Install parted using pacman. 
        -- Don't you worry. 
        -- This only happens in ram. 
    "
    pacman -S --noconfirm parted >& $(trim $LOGFILE) || {
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
    local CONF=""
    readarray CONF < <(trim "$2")
    for I in $(seq 0 $((${#CONF[@]} - 1)))
    do
        local MKPT=$(trim $(echo ${CONF[$I]} | awk '{split($0,a,"|"); print a[2]}'))
        local FLAG=$(trim $(echo ${CONF[$I]} | awk '{split($0,a,"|"); print a[3]}'))
        tell "Make partition with configuration: $MKPT"
        parted --script /dev/$(trim "$1") -- mkpart $MKPT >& $(trim $LOGFILE) || {
            fail "
                Cannot partition the disk. are you superuser? what about alignment?
                Reason: \"$(cat $(trim $LOGFILE))\"
            "
        }
        for F in $FLAG
        do
            tell "-- Attach flag $F"
        parted --script /dev/$(trim "$1") -- set $(($I+1)) $F on >& $(trim $LOGFILE)
        done || fail "Cannot set flag on partition $I $(echo)Reason: \"$(cat $(trim $LOGFILE))\""
    done
    pop-prefix
}

# make file systems on disk
# $1: device name
# $2: partition settings
setup-fs-format() {
    add-prefix 'FS FORMAT'
    pacman -S --needed --noconfirm dosfstools
    local CONF
    local PARS
    readarray CONF < <(trim "$2")
    readarray PARS < <(find /dev | grep -P "/dev/$(trim $1).+")
    if [[ ${#CONF[@]} !=${#PARS[@]} ]]
    then
        fail "The number of partitions is different from the number of configured partitions. "
    fi
    # file systems on partitions
    for I in $(seq 0 $((${#PARS[@]} - 1)))
    do
        local MKF="$(trim $(echo ${CONF[$I]} | awk '{split($0,a,"|"); print a[4]}'))"
        local PAR=$(trim ${PARS[$I]})
        tell "Format file system $MKF $PAR. Wait..."
        $MKF $PAR || {
            fail "Cannot make file system (with $MKF) on $PAR. "
        }
    done
    pop-prefix
}

# mount partitions to mountpoints
# $1: device name
# $2: disk partition plan
# $3: mount point root
setup-mount() {
    add-prefix "MOUNT DISK"
    local CONF
    local PARS
    readarray CONF < <(trim "$2")
    readarray PARS < <(find /dev | grep -P "/dev/$(trim $1).+")
    if [[ ${#CONF[@]} !=${#PARS[@]} ]]
    then
        fail "The number of partitions is different from the number of configured partitions. "
    fi
    swapoff -a -v
    for I in $(seq 0 $((${#PARS[@]} - 1)))
    do
        local POS="$(trim $3)$(trim $(echo ${CONF[$I]} | awk '{split($0,a,"|"); print a[1]}'))"
        local PAR=$(trim ${PARS[$I]})
        tell "$PAR <-> $POS"
        if [[ "$POS" =="swap" ]]
        then
            swapon $PAR >& $(trim $LOGFILE) || {
                fail "Reason: \"$(cat $(trim $LOGFILE))\""
            }
            hook "swapoff $POS"
        else
            mount --mkdir $PAR $POS >& $(trim $LOGFILE) || {
                fail "Reason: \"$(cat $(trim $LOGFILE))\""
            }
            hook "umount -l $POS"
        fi
    done
    tell "Generate fstab. "
    mkdir $(trim "$MOUNTPOINT")/etc >& /dev/null || tell "/etc alread exists"
    genfstab -U $(trim "$MOUNTPOINT") > $(trim "$MOUNTPOINT")/etc/fstab
    pop-prefix
}

# use pacstrap to bootstrap a system
# $1: the mountpoint to pacstrap into
setup-pacstrap() {
    tell "Install base system. "
    cat /etc/pacman.conf > $(trim "$1")/etc/pacman.conf
    with-retry 3 pacstrap -K $(trim "$1") base base-devel
}

########################################
#                                      #
#   Post-installation Tool Functions   #
#                                      #
########################################

# configure boot loading behaviour (systemd)
setup-systemd-boot() {
    # https://wiki.archlinux.org/title/Systemd-boot
    add-prefix 'SYSTEMD BOOT'
    bootctl install --path /boot
    # query fstab for root guid
    local UUID=$(cat /etc/fstab | awk '$2 =="/"' | awk $'{split($1,f,"=")\nprint f[2]}')
    local FSTY=$(cat /etc/fstab | awk '$2 =="/"' | awk $'{print $3}')
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
        options root=UUID=$UUID rw rootfstype=$FSTY
    ")
    # configure boot loader option menu
    (cat - > /boot/loader/loader.conf) < <(trim "
        timeout 5
        default arch
    ")
    pop-prefix
}

# configure network
# $1: hostname
# $2: hosts
setup-network() {
    # hostname
    (cat - > /etc/hostname) < <(trim "$1")
    (cat - > /etc/hosts)    < <(trim "$2")
}

# configure localization
# $1: region
# $2: city
setup-localize() {
    # locale setup
    locale-gen
    (cat - > /etc/locale.gen) < <(trim "
        en_US.UTF-8 UTF-8
    ")
    (cat - > /etc/locale.conf) < <(trim '
        LANG="en_US.UTF-8"
        LC_COLLATE="C"
    ')
    # timezone setup
    ln -sT "/usr/share/zoneinfo/$(trim "$1")/$(trim "$2")" /etc/localtime
    hwclock --systohc
}

# initialize a user and add it to sudoers
# $1: username
# $2: password
setup-user() {
    add-prefix "USER ADD"
    useradd -m $(trim $1)
    passwd $(trim $1) < <(trim "
        $(trim $2)
        $(trim $2)
    ")
    (cat - > /etc/sudoers) < <(trim '
        root ALL=(ALL:ALL) ALL
        @includedir /etc/sudoers.d
    ')
    mkdir -p /etc/sudoers.d || tell "/etc/sudoers.d already exists"
    echo "$(trim $1) ALL=(ALL) ALL" > /etc/sudoers.d/$(trim $1)
    pop-prefix
}

# setup pacman mirror and update database
# $1: the mirrorlist file
setup-pacman() {
    trim "$1" > /etc/pacman.d/mirrorlist
    with-retry 3 pacman -Syy || fail "Cannot update pacman database. "
    with-retry 3 pacman-key --init
    with-retry 3 pacman-key --populate
    with-retry 3 pacman     --needed -S --noconfirm $(trim "$2")
}

###########################
#                         #
#   Program Entry Point   #
#                         #
###########################

if [[ "$1" =="post-install" ]]
then
    add-prefix          "POST-INSTALL"
    setup-pacman        "$MIRRORLIST"    "$PACKAGES"
    setup-network       "$HOSTNAME"      "$HOSTS"
    setup-localize      "$REGION"        "$CITY"
    setup-user          "$USERNAME"      "$PASSWORD"
    setup-systemd-boot
    pop-prefix
else
    add-prefix          "PRE-INSTALL" 
    trim                "$MIRRORLIST" > /etc/pacman.d/mirrorlist
    setup-disk-check    "$DEVICE"        
    setup-partition     "$DEVICE"     "$PARTITION" 
    setup-fs-format     "$DEVICE"     "$PARTITION" 
    setup-mount         "$DEVICE"     "$PARTITION" "$MOUNTPOINT"
    setup-pacstrap      "$MOUNTPOINT"
    pop-prefix
    cp $0 "$(trim "$MOUNTPOINT")/setup.sh" >& $(trim $LOGFILE) \
    || fail "cannot copy current script to $(trim "$MOUNTPOINT")/setup.sh"
    arch-chroot "$(trim "$MOUNTPOINT")" bash /setup.sh post-install \
    || fail "chroot & execute failed $(trim "$MOUNTPOINT")"
    rm "$(trim "$MOUNTPOINT")/setup.sh"
fi
