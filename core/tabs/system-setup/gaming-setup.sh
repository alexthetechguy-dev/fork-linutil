#!/bin/sh -e

# shellcheck disable=SC2086

. ../common-script.sh

installDepend() {
    DEPENDENCIES='wine dbus git'
    printf "%b\n" "${YELLOW}Installing dependencies...${RC}"
    case "$PACKAGER" in
        pacman)
            #Check for multilib
            if ! grep -q "^\s*\[multilib\]" /etc/pacman.conf; then
                echo "[multilib]" | "$ESCALATION_TOOL" tee -a /etc/pacman.conf
                echo "Include = /etc/pacman.d/mirrorlist" | "$ESCALATION_TOOL" tee -a /etc/pacman.conf
                "$ESCALATION_TOOL" "$PACKAGER" -Syu
            else
                printf "%b\n" "${GREEN}Multilib is already enabled.${RC}"
            fi

            DISTRO_DEPS="gnutls lib32-gnutls base-devel gtk2 gtk3 lib32-gtk2 lib32-gtk3 libpulse lib32-libpulse alsa-lib lib32-alsa-lib \
                alsa-utils alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib giflib lib32-giflib libpng lib32-libpng \
                libldap lib32-libldap openal lib32-openal libxcomposite lib32-libxcomposite libxinerama lib32-libxinerama \
                ncurses lib32-ncurses vulkan-icd-loader lib32-vulkan-icd-loader ocl-icd lib32-ocl-icd libva lib32-libva \
                gst-plugins-base-libs lib32-gst-plugins-base-libs sdl2 lib32-sdl2 v4l-utils lib32-v4l-utils sqlite lib32-sqlite"

            $AUR_HELPER -S --needed --noconfirm $DEPENDENCIES $DISTRO_DEPS
            ;;
        apt-get | nala)
            DISTRO_DEPS="libasound2-plugins:i386 libsdl2-2.0-0:i386 libdbus-1-3:i386 libsqlite3-0:i386 wine64 wine32"

            "$ESCALATION_TOOL" dpkg --add-architecture i386

            if [ "$DTYPE" != "pop" ]; then
                "$ESCALATION_TOOL" "$PACKAGER" install -y software-properties-common
                "$ESCALATION_TOOL" apt-add-repository contrib -y
            fi

            "$ESCALATION_TOOL" "$PACKAGER" update
            "$ESCALATION_TOOL" "$PACKAGER" install -y $DEPENDENCIES $DISTRO_DEPS
            ;;
        dnf)
            printf "%b\n" "${CYAN}Installing rpmfusion repos.${RC}"
            "$ESCALATION_TOOL" "$PACKAGER" install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-"$(rpm -E %fedora)".noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-"$(rpm -E %fedora)".noarch.rpm -y
            "$ESCALATION_TOOL" "$PACKAGER" config-manager setopt --repo fedora-cisco-openh264 enabled=1
    
            "$ESCALATION_TOOL" "$PACKAGER" install -y $DEPENDENCIES
            ;;
        zypper)
            "$ESCALATION_TOOL" "$PACKAGER" -n install $DEPENDENCIES
            ;;
        eopkg)
            DISTRO_DEPS="libgnutls libgtk-2 libgtk-3 pulseaudio alsa-lib alsa-plugins giflib libpng openal-soft libxcomposite libxinerama ncurses vulkan ocl-icd libva gst-plugins-base sdl2 v4l-utils sqlite3"

            "$ESCALATION_TOOL" "$PACKAGER" install -y $DEPENDENCIES $DISTRO_DEPS
            ;;
        *)
            printf "%b\n" "${RED}Unsupported package manager ${PACKAGER}${RC}"
            exit 1
            ;;
    esac
}

installAdditionalDepend() {
    case "$PACKAGER" in
        pacman)
            DISTRO_DEPS='steam lutris goverlay'
            "$ESCALATION_TOOL" "$PACKAGER" -S --needed --noconfirm $DISTRO_DEPS
            ;;
        apt-get | nala)
            version=$(git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' https://github.com/lutris/lutris |
                grep -v 'beta' |
                tail -n1 |
                cut -d '/' --fields=3)

            version_no_v=$(echo "$version" | tr -d v)
            curl -sSLo "lutris_${version_no_v}_all.deb" "https://github.com/lutris/lutris/releases/download/${version}/lutris_${version_no_v}_all.deb"

            printf "%b\n" "${YELLOW}Installing Lutris...${RC}"
            "$ESCALATION_TOOL" "$PACKAGER" install -y ./lutris_"${version_no_v}"_all.deb

            rm lutris_"${version_no_v}"_all.deb

            printf "%b\n" "${GREEN}Lutris Installation complete.${RC}"
            printf "%b\n" "${YELLOW}Installing steam...${RC}"

            if lsb_release -i | grep -qi Debian; then
                "$ESCALATION_TOOL" apt-add-repository non-free -y
                "$ESCALATION_TOOL" "$PACKAGER" install steam-installer -y
            else
                "$ESCALATION_TOOL" "$PACKAGER" install -y steam
            fi
            ;;
        dnf)
            DISTRO_DEPS='steam lutris'
            "$ESCALATION_TOOL" "$PACKAGER" install -y $DISTRO_DEPS
            ;;
        zypper)
            DISTRO_DEPS='lutris'
            "$ESCALATION_TOOL" "$PACKAGER" -n install $DISTRO_DEPS
            ;;
        eopkg)
            DISTRO_DEPS='steam lutris'
            "$ESCALATION_TOOL" "$PACKAGER" install -y $DISTRO_DEPS
            ;;
        *)
            printf "%b\n" "${RED}Unsupported package manager ${PACKAGER}${RC}"
            exit 1
            ;;
    esac
}

checkEnv
checkAURHelper
checkEscalationTool
installDepend
installAdditionalDepend
