#!/usr/bin/env bash

HEREcon=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
APPDIR="${HEREcon}/.."
APPROOT="${APPDIR}/.."

# shellcheck disable=SC2034
app_name="wizbat"
if [ -f "${APPROOT}/.${app_name}.branch" ]; then
    branch_name=$(<"${APPROOT}/.${app_name}.branch")
else
    branch_name=$(git symbolic-ref --short -q HEAD)
fi

# determine machine identity
host_name=$(hostname)

# construct database paths
database_local_root="/srv/rmt/_databases"
database_remote_root="remote:raspi/_databases"
database_filename="wizbat.sqlite3"
db_full_path="${database_local_root}/${app_name}/${database_filename}"
# website_dir="/tmp/${app_name}/site"
website_dir="/run/${app_name}/site"
website_image_dir="${website_dir}/img"

constants_sh_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)

# list of timers provided
declare -a wizbat_timers=("wizbat.trend.day.timer"
    "wizbat.trend.month.timer"
    "wizbat.trend.year.timer")
  # "wizbat.update.timer" (incl. the .service) is not installed
# list of services provided
declare -a wizbat_services=("wizbat.service")
# Install python3 and develop packages
# Support for matplotlib & numpy needs to be installed seperately
# Support for serial port
# SQLite3 support (incl python3)
declare -a wizbat_apt_packages=("build-essential" "python3" "python3-dev" "python3-pip"
    "libatlas-base-dev" "libxcb1" "libopenjp2-7" "libtiff5"
    "sqlite3")
# placeholders for trendgraphs to make website work regardless of the state of the graphs.
declare -a wizbat_graphs=('wtr_pastdays_bat.png'
    'wtr_pasthours_bat.png'
    'wtr_pastmonths_bat.png'
    'wtr_pastyears_bat.png')

# start the application
start_wizbat() {
    echo "*** $app_name running on $host_name >>>>>>: start $1 $2"
    GRAPH=$2
    ROOT_DEAR=$1
    echo "Starting ${app_name} on $(date)"
    # make sure /tmp environment exists
    boot_wizbat
    if [ "${GRAPH}" == "-graph" ]; then
        graph_wizbat "${ROOT_DEAR}"
    fi
    action_timers start
    action_services start
}

# stop the application
stop_wizbat() {
    echo "*** $app_name running on $host_name >>>>>>: stop"
    echo "Stopping ${app_name} on $(date)"
    action_timers stop
    action_services stop
    # sync the database into the cloud
    if command -v rclone &> /dev/null; then
        rclone copyto -v \
               "${database_local_root}/${app_name}/${database_filename}" \
               "${database_remote_root}/${app_name}/${database_filename}"
    fi
}

# update the repository
update_wizbat() {
    echo "*** $app_name running on $host_name >>>>>>: update"
    git fetch origin || sleep 60
    git fetch origin
    git pull
    git fetch origin
    git checkout "${branch_name}"
    git reset --hard "origin/${branch_name}" && git clean -f -d
    echo "pip update..."
    python -m pip install --upgrade pip -r "${APPDIR}/requirements.txt" \
        |  grep -v "Requirement already satisfied"
}

# create graphs
graph_wizbat() {
    echo "*** $app_name running on $host_name >>>>>>: graph $1"
    ROOT_DIR=$1

    echo "Creating graphs [1]"
    . "${ROOT_DIR}/src/pastday.sh"
    echo "Creating graphs [2]"
    . "${ROOT_DIR}/src/pastmonth.sh"
    echo "Creating graphs [3]"
    . "${ROOT_DIR}/src/pastyear.sh"
}

# stop, update the repo and start the application
# do some additional stuff when called by systemd
restart_wizbat() {
    echo "*** $app_name running on $host_name >>>>>>: restart $1 $2"
    ROOT_DIR=$1

    # restarted by --systemd flag
    SYSTEMD_REQUEST=$2

    echo "Restarting ${app_name} on $(date)"
    stop_wizbat

    update_wizbat

    if [ "${SYSTEMD_REQUEST}" -eq 1 ]; then
        SYSTEMD_REQUEST="-graph"
    else
        echo "Skipping graph creation"
        SYSTEMD_REQUEST="-nograph"
    fi

    # re-install services and timers in case they were changed
    sudo cp "${ROOT_DIR}"/services/*.service /usr/lib/systemd/system/
    sudo cp "${ROOT_DIR}"/services/*.timer /usr/lib/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
    echo "...systemd updated"; sleep 60

    start_wizbat "${ROOT_DIR}" "${SYSTEMD_REQUEST}"
    echo "...$app_name started"
}

# uninstall the application
unstall_wizbat() {
    echo "*** $app_name running on $host_name >>>>>>: uninstall"
    echo "Uninstalling ${app_name} on $(date)"
    stop_wizbat
    action_timers disable
    action_services disable
    action_timers rm
    action_services rm
    rm "${APPROOT}/.${app_name}.branch"
    sudo rm /var/www/water
}

# install the application
install_wizbat() {
    echo "*** $app_name running on $host_name >>>>>>: install $1"
    ROOT_DIR=$1

    # to suppress git detecting changes by chmod
    git config core.fileMode false
    # note the branchname being used
    if [ ! -e "${APPROOT}/.${app_name}.branch" ]; then
        echo "${branch_name}" >"${APPROOT}/.${app_name}.branch"
    fi

    echo "Installing ${app_name} on $(date)"
    # install APT packages
    for PKG in "${wizbat_apt_packages[@]}"; do
        action_apt_install "${PKG}"
    done
    # install Python3 stuff
    pyenv virtualenv 3.12  "${app_name}"
    pyenv local  "${app_name}"
    python3 -m pip install --upgrade pip setuptools wheel
    python3 -m pip install --upgrade -r requirements.txt
    echo

    echo "Fetching existing database from cloud."
    # sync the database from the cloud
    if command -v rclone &> /dev/null; then
        rclone copyto -v \
               "${database_remote_root}/${app_name}/${database_filename}" \
               "${database_local_root}/${app_name}/${database_filename}"
    fi

    # install services and timers
    echo "Installing timers & services."
    # remove execute-bit from services and timers
    sudo chmod -x "${ROOT_DIR}"/services/*
    sudo cp "${ROOT_DIR}"/services/*.service /usr/lib/systemd/system/
    sudo cp "${ROOT_DIR}"/services/*.timer /usr/lib/systemd/system/
    sudo systemctl daemon-reload
    action_timers enable
    action_services enable

    # install a link to the website on /tmp/....
    sudo ln -s "${website_dir}" /var/www/water

    echo "Installation complete. To start the application use:"
    echo "   wizbat --go"
}

# set-up the application
boot_wizbat() {
    echo "*** $app_name running on $host_name >>>>>>: boot"
    # make sure website filetree exists
    if [ ! -d "${website_image_dir}" ]; then
        sudo mkdir -p "${website_image_dir}"
        sudo chown -R pi:users "${website_dir}"
        sudo chmod -R 755 "${website_dir}/.."
    fi
    # allow website to work even if the graphics have not yet been created
    for GRPH in "${wizbat_graphs[@]}"; do
        create_graphic "${website_image_dir}/${GRPH}"
    done
    cp "${constants_sh_dir}/../www/index.html" "${website_dir}"
    cp "${constants_sh_dir}/../www/favicon.ico" "${website_dir}"
}

# perform systemctl actions on all timers
action_timers() {
    echo "*** wizbat >>>>>>: action_timers $1"
    ACTION=$1
    for TMR in "${wizbat_timers[@]}"; do
        if [ "${ACTION}" != "rm" ]; then
            sudo systemctl "${ACTION}" "${TMR}"
        else
            sudo rm "/usr/lib/systemd/system/${TMR}"
        fi
    done
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
}

# perform systemctl actions on all services
action_services() {
    echo "*** $app_name running on $host_name >>>>>>: action services $1"
    ACTION=$1
    for SRVC in "${wizbat_services[@]}"; do
        if [ "${ACTION}" != "rm" ]; then
            sudo systemctl "${ACTION}" "${SRVC}"
        else
            sudo rm "/usr/lib/systemd/system/${SRVC}"
        fi
    done
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
}

# See if packages are installed and install them using apt-get
action_apt_install() {
    PKG=$1
    echo "***************************************************(APT)*"
    echo "* $app_name running on $host_name requesting ${PKG}"
    status=$(dpkg -l | awk '{print $2}' | grep -c -e "^${PKG}*")
    if [ "${status}" -eq 0 ]; then
        echo -n "* Installing ${PKG} "
        sudo apt-get -yqq install "${PKG}" && echo " ... [OK]"
        echo "***************************************************(APT)*"
    else
        echo "* Already installed !!!"
        echo "***************************************************(APT)*"
    fi
    echo
}

# create a placeholder graphic for Fles if it doesn't exist already
create_graphic() {
    IMAGE="$1"
    if [ ! -f "${IMAGE}" ]; then
        cp "${constants_sh_dir}/../www/empty.png" "${IMAGE}"
    fi
}
