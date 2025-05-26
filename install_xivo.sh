#!/bin/bash
set -e

mirror_xivo="http://mirror.xivo.solutions"
update='apt-get update'
install='apt-get install --assume-yes'
download='apt-get install --assume-yes --download-only'
dcomp='/usr/bin/xivo-dcomp'

# Please update "default_lts_preinstallation" with archive installation steps when changing distribution
distribution='xivo-orion'
dev_lts='orion'
repo='debian'
debian_codename='bookworm'
debian_version='12'
debian_codename_dev='bookworm'
debian_version_dev='12'
not_installable_message='This version of XiVO is not installable on 32-bit systems.'

declare -A lts_version_table=([2017.03]="Five" [2017.11]="Polaris" [2018.05]="Aldebaran" [2018.16]="Borealis" [2019.05]="Callisto" [2019.12]="Deneb" [2020.07]="Electra" [2020.18]="Freya" [2021.07]="Gaia" [2021.15]="Helios" [2022.05]="Izar" [2022.10]="Jabbah" [2023.05]="Kuma" [2023.10]="Luna" [2024.05]="Maia" [2024.10]="Naos" [2025.05]="Orion")

# 6099 Force the usage of ipV4 on the wget commands to avoid infinite loop
if ! grep --quiet "inet4_only = on" /etc/wgetrc ; then
    echo "inet4_only = on" >> /etc/wgetrc
fi

get_system_architecture() {
    architecture=$(uname -m)
}

check_system() {
    local version_file='/etc/debian_version'
    if [ ! -f $version_file ]; then
        echo "You must install XiVO on a Debian $debian_version (\"$debian_codename\") system"
        echo "You do not seem to be on a Debian system"
        exit 1
    else
        your_version=$(cut -d '.' -f 1 "$version_file")
    fi

    if [ "$your_version" != $debian_version ]; then
        echo "You must install XiVO on a Debian $debian_version (\"$debian_codename\") system"
        echo "You are currently on a Debian $your_version system"
        exit 1
    fi
}

add_dependencies() {
    $update
    # dirmngr and gnupg is needed by apt-key in Debian 9-10
    $install wget \
        dirmngr \
        gnupg \
        curl
}

add_xivo_key() {
    local xivo_keyring_file="/etc/apt/trusted.gpg.d/mirror.xivo.solutions.gpg"
    add_key_in_keyring "http://mirror.xivo.solutions/xivo_current.key" "${xivo_keyring_file}"
}

is_key_in_keyring() {
    local keyid="${1}"; shift
    local keyringfile="${1}"; shift

    if gpg --batch --no-tty --keyring "${keyringfile}" --list-keys --with-colons | grep -q "${keyid}"; then
        return 0
    else
        return 1
    fi
}

add_key_in_keyring() {
    local keyurl="${1}"; shift
    local keyringfile="${1}"; shift

    echo "Removing file ${keyringfile}"
    rm -rf "${keyringfile}"
    touch "${keyringfile}"
    echo "Adding GPG key from ${keyurl} to ${keyringfile}..."
    curl -fsSL "${keyurl}" | gpg --dearmor | tee "${keyringfile}" >/dev/null
}


add_docker_key() {
    # For archive versions. From version 2019.11 docker key is installed by xivo-docker
    local docker_keyring_file="/etc/apt/trusted.gpg.d/download.docker.com.gpg"
    local docker_keyid="0EBFCD88"

    if ! is_key_in_keyring "${docker_keyid}" "${docker_keyring_file}"; then
        echo "Adding Docker GPG key..."
        add_key_in_keyring "https://download.docker.com/linux/debian/gpg" "${docker_keyring_file}"
    fi
}

add_docker-engine_key() {
    echo "Adding Docker Engine GPG key..."
    apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
}


add_xivo_apt_conf() {
    echo "Installing APT configuration file: /etc/apt/apt.conf.d/90xivo"

	cat > /etc/apt/apt.conf.d/90xivo <<-EOF
	Aptitude::Recommends-Important "false";
	APT::Install-Recommends "false";
	APT::Install-Suggests "false";
	EOF
}

add_mirror() {
    echo "Adding xivo mirrors"
    local mirror="deb $mirror_xivo/$repo $distribution main"
    apt_dir="/etc/apt"
    sources_list_dir="$apt_dir/sources.list.d"
    if ! grep -qr "$mirror" "$apt_dir"; then
        echo "$mirror" > $sources_list_dir/tmp-pf.sources.list
    fi
    add_xivo_key

    export DEBIAN_FRONTEND=noninteractive
    $update
    $install xivo-dist
    add_docker_key # Run after xivo-dist installation: therefore xivo-docker is installed which installs docker dependencies (among them: curl and ca-certificates)
    xivo-dist "$distribution"


    rm -f "$sources_list_dir/tmp-pf.sources.list"
    $update
}

add_pgdg_mirror() {
    $install ca-certificates lsb-release
    add_key_in_keyring "https://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc" "/etc/apt/trusted.gpg.d/apt.postgresql.org.gpg"
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    $update
}

check_source_exists() {
    local type="$1"; shift
    local distribution="$1"; shift
    local component="$1"; shift
    local list="$1"; shift

    grep -Prq "^\s*${type}\s.+\s${distribution}\s+${component}\b" "${list}"
}

add_backports_in_sources_list() {
    local distribution=${1}; shift

    echo "Adding ${distribution}-backports source"
    if ! check_source_exists deb ${distribution}-backports main "/etc/apt/sources.list*"; then
		cat >> /etc/apt/sources.list <<-EOF

			# ${distribution}-backports, previously on backports.debian.org
			deb http://ftp.fr.debian.org/debian ${distribution}-backports main
		EOF
    fi
    if ! check_source_exists deb-src ${distribution}-backports main "/etc/apt/sources.list*"; then
		cat >> /etc/apt/sources.list <<-EOF
			deb-src http://ftp.fr.debian.org/debian ${distribution}-backports main
		EOF
    fi
}

install_dahdi_modules() {
    flavour=$(echo $(uname -r) | cut -d\- -f3)
    kernel_release=$(ls /lib/modules/ | grep ${flavour})
    for kr in ${kernel_release}; do
        ${download} dahdi-linux-modules-${kr}
        ${install} dahdi-linux-modules-${kr}
    done
}

install_rabbitmq() {
    # Install xivo-config, docker-ce, xivo-docker-components and other requirements
    ${download} xivo-docker-components
    ${install} xivo-docker-components

    xivo-dcomp pull rabbitmq
    xivo-dcomp up -d rabbitmq
}

get_key_in_env() {
    local key_name="${1}"; shift
    local compose_path="${1}"; shift
    local custom_env_file="${1}"; shift
    local key_value

    if key_value=$(grep -oP -m 1 "${key_name}=\K.*" ${compose_path}/${custom_env_file}); then
        echo "${key_value}"
    else
        echo ""
    fi
}

get_usm_backend_token() {
    local usm_backend_url="${1}"; shift
    local xivo_uuid=$(cat /etc/default/xivo | grep -oP 'XIVO_UUID=(.*)$' | tail -n 1 | cut -d '=' -f 2)
    if token=$(curl --fail --connect-timeout 10 --max-time 20 "${usm_backend_url}/usm/token?xivo_uuid=${xivo_uuid}"); then
        echo "${token}"
    else
        echo "error"
    fi
}

add_key_in_env() {
    local key_name="${1}"; shift
    local key_value="${1}"; shift
    local compose_path="${1}"; shift
    local custom_env_file="${1}"; shift

    echo "${key_name}=${key_value}" >> "${compose_path}/${custom_env_file}"
}

install_xivo () {
    wget -q -O - $mirror_xivo/d-i/$debian_codename/pkg.cfg | debconf-set-selections

    kernel_release=$(uname -r)
    ${install} --purge postfix

    # Only install dahdi-linux-modules if the package dahdi-linux-dkms was not found
    dahdi_dkms_exists=$(apt-cache pkgnames | grep -q "dahdi-linux-dkms"; echo $?)
    if [ $dahdi_dkms_exists -eq 0 ]; then
      echo "DAHDI: dahdi-linux-dkms package found in repository"
    else
      echo "DAHDI: dahdi-linux-dkms package not found in repository"
      install_dahdi_modules
    fi

    if [ $do_install_rabbitmq_container -eq 1 ]; then
        install_rabbitmq
    fi

    ${download} xivo
    ${install} xivo

    # Install asterisk default moh
    ${install} asterisk-moh-opsound-g722 asterisk-moh-opsound-gsm asterisk-moh-opsound-wav

    # Get USM BACKEND TOKEN (we need to do it before the pull)
    if [ ${do_install_usm_backend_token} -eq 1 ]; then
        usm_backend_url=$(get_key_in_env "USM_BACKEND_URL" "/etc/docker/xivo" "custom.env")
        if [ -z "${usm_backend_url}" ]; then
            usm_backend_url=$(get_key_in_env "USM_BACKEND_URL" "/etc/docker/xivo" "factory.env")
        fi
        usm_backend_token=$(get_usm_backend_token "${usm_backend_url}")
        if [ "${usm_backend_token}" == "error" ];then
            echo -e "\e[1;33m WARNING: could not retrieve USM BACKEND TOKEN at ${usm_backend_url}/usm/token\e[0m"
            echo -e "\e[1;33m WARNING: USM will not be able to push data to the backend\e[0m"
        else
            add_key_in_env "USM_BACKEND_TOKEN" "${usm_backend_token}" "/etc/docker/xivo" "custom.env"
        fi
    fi

    if [ -f "${dcomp}" ]; then
        ${dcomp} pull
    fi
    xivo-service restart all

    if [ $? -eq 0 ]; then
        echo 'You must now finish the installation'
        xivo_ip=$(ip a s eth0 | grep -E 'inet.*eth0' | awk '{print $2}' | cut -d '/' -f 1 )
        echo "open https://$xivo_ip to configure XiVO"
    fi
}

check_distribution_is_32bit() {
    if [ "$distribution" = "xivo-polaris" ] || [ "$distribution" = "xivo-five" ]; then
        return 0
    else
        return 1
    fi
}

propose_polaris_installation() {
    echo $not_installable_message
    read -p 'Would you like to install XiVO Polaris [Y/n]? ' answer
    answer="${answer:-Y}"
    if [ "$answer" != 'y' -a "$answer" != 'Y' ]; then
        exit 0
    fi
    distribution="xivo-polaris"
}

check_system_is_64bit() {
    if [ "$architecture" != "x86_64" ]; then
        echo $not_installable_message
        exit 1
    fi
}

check_archive_prefix() {
    if [ "${1::5}" = "xivo-" ]; then
        echo 'Archive version must be typed without the prefix "xivo-"'
        exit 1
    fi
}

get_xivo_package_version_installed() {
    local xivo_version_installed="$(LANG='C' apt-cache policy xivo | grep Installed | grep -oE '[0-9]{2,4}\.[0-9]+(\.[0-9]+)?|1\.2\.[0-9]{1,2}' | head -n1)"
    echo $xivo_version_installed
}

postinst_actions() {
    # On Debian 9 Spawn-FCGI needs to be started at the end of installation (before webi was dockerized)
    if [ "$debian_version" \> "7" ] && [ "$(get_xivo_package_version_installed)" \< "2019.10.00" ]; then
        systemctl start spawn-fcgi
    fi
}

usage() {
    cat << EOF
    This script is used to install XiVO

    usage : $(basename $0) {-d|-a version}
        whitout arg : install production version
        -d          : install development version
        -a version  : install archived version (14.18 or later)

EOF
    exit 1
}

ask_before_proceeding_installation(){
    user_has_been_asked_before=1
    local option=$1
    local version=$2
    local version_prefix=${version:0:7}
    if [[ $# -eq 0 ]]; then
        echo "You are going to install production version : $distribution."
    elif [[ $version_prefix =~ ^[0-9]{4}\.[0-9]{2}+$ ]] && [[ $option == "-a" ]]; then
        echo "You are going to install xivo $(get_version_name $version_prefix) ($version)."
    elif [[ $option == "-d" ]]; then
        echo "You are going to install XiVO ${dev_lts} dev version."
        echo "To install production version, re-run the script without parameters."
    else
        echo "Be careful ! The version $option $version you choose was not recognized."
    fi

    echo "The installation will start in 5 seconds. Type Ctrl+C if you want to abort."
    for _ in $(seq 1 1 5); do
        sleep 1
        echo -n "."
    done
    echo "Go!"
    sleep 1
}

get_version_name() {
    if [[ -v lts_version_table[$1] ]]; then
        echo ${lts_version_table[$1]}
    else
        echo 'intermediate version'
    fi
}

recover_from_wrong_distrib_input(){
    if [ -f /etc/apt/sources.list.d/tmp-pf.sources.list ]; then
        rm /etc/apt/sources.list.d/tmp-pf.sources.list
    fi
}

default_lts_preinstallation() {
    check_system_is_64bit
    do_add_pgdg_mirror=1
    do_install_rabbitmq_container=0
}

do_install_rabbitmq_container=0
do_add_pgdg_mirror=0
do_install_usm_backend_token=0

get_system_architecture

user_has_been_asked_before=0
if [ -z $1 ] && [ "$architecture" != "x86_64" ]; then
    if ! check_distribution_is_32bit; then
        propose_polaris_installation
    fi
else
    if [[ $# -eq 0 ]]; then
        ask_before_proceeding_installation
        default_lts_preinstallation
    fi
    while getopts ':dra:' opt; do
        case ${opt} in
            d)
                ask_before_proceeding_installation -d
                check_system_is_64bit
                do_add_pgdg_mirror=1
                distribution="xivo-$dev_lts-dev"
                debian_codename=$debian_codename_dev
                debian_version=$debian_version_dev
                do_install_rabbitmq_container=1
                do_install_usm_backend_token=1
                ;;
            r)
                echo "xivo-rc distribution does not exist anymore"
                echo "use option -a VERSION (e.g. -a 2018.14.00) to install a RC"
                exit 1
                ;;
            a)
                check_archive_prefix $OPTARG
                ask_before_proceeding_installation -a $OPTARG
                distribution="xivo-$OPTARG"
                repo='archive'

                if [ "$OPTARG" \> "2018" ]; then
                    check_system_is_64bit
                fi
                if [ "${OPTARG::7}" = "2018.02" ]; then
                    add_docker-engine_key
                fi

                if dpkg --compare-versions "$OPTARG" ">=" "2023.05.00"; then
                    do_install_usm_backend_token=1
                fi
                if dpkg --compare-versions "$OPTARG" ">=" "2020.01.00"; then
                    do_install_rabbitmq_container=1
                fi

                if dpkg --compare-versions "$OPTARG" "ge" "2024.05"; then
                    debian_version=$debian_version
                    debian_codename=$debian_codename
                    do_add_pgdg_mirror=1
                elif dpkg --compare-versions "$OPTARG" "ge" "2022.04.00"; then
                    debian_version='11'
                    debian_codename='bullseye'
                    do_add_pgdg_mirror=1
                elif [ "$OPTARG" \> "2020.09" ]; then
                    debian_version='10'
                    debian_codename='buster'
                    do_add_pgdg_mirror=1
                elif [ "$OPTARG" \> "2018.13" ]; then
                    debian_version='9'
                    debian_codename='stretch'
                    do_add_pgdg_mirror=1
                elif [ "$OPTARG" \> "15.19" ]; then
                    debian_version='8'
                    debian_codename='jessie'
                elif [ "$OPTARG" \> "14.17" ]; then
                    debian_version='7'
                    debian_codename='wheezy'
                else
                    # 14.17 and earlier don't have xivo-dist available
                    echo "This script only supports installing XiVO 14.18 or later."
                    exit 1
                fi
                ;;
            *)
                usage
                ;;
        esac
    done
fi
if [[ ${user_has_been_asked_before} -eq 0 ]]; then
    # We need this to prompt the user if he runs script with wrong arg
    # e.g.: ./xivo_install.sh callisto
    ask_before_proceeding_installation $1 $2
fi
recover_from_wrong_distrib_input

check_system
add_xivo_apt_conf
add_dependencies
if [ "${debian_codename}" = "buster" ] || [ "${debian_codename}" = "bullseye" ]; then
    add_backports_in_sources_list ${debian_codename}
fi
if [ $do_add_pgdg_mirror -eq 1 ]; then
    add_pgdg_mirror
fi
add_mirror
install_xivo
postinst_actions
