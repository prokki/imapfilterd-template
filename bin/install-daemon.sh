#!/bin/sh
# -----------------------------------------------------------------------------
#
#   Creates an imapfilter daemon in /etc/init.d and install
#
#   Copyright (C) 2019, Falko Matthies
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# -----------------------------------------------------------------------------

# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")

# all required destination directories
INIT_DIR="/etc/init.d"

IMAPFILTER_DAEMON_TEMPLATE="${SCRIPTPATH}/../templates/imapfilterd.dist"

####################################################################################

check_not_root () {
    if [ "$(id -u)" = "0" ]
    then
        echo "Error #1: Do not run ${SCRIPT} as root user!" >&2
        exit 1
    fi
}

check_initd_directory () {

    if [ ! -d "${INIT_DIR}" ]
    then
        echo "Error: Not able to access directory \"${INIT_DIR}\". Please check directory properties." >&2
        exit 11
    fi
}

check_template () {
    if [ ! -f "${IMAPFILTER_DAEMON_TEMPLATE}" ]
    then
        echo "Error: Template \"${IMAPFILTER_DAEMON_TEMPLATE}\" was not found." >&2
        exit 1
    elif [ ! -r "${IMAPFILTER_DAEMON_TEMPLATE}" ]
    then
        echo "Error: Template \"${IMAPFILTER_DAEMON_TEMPLATE}\" is not readable." >&2
        exit 2
    fi
}

check_requirements () {
    check_not_root
    check_initd_directory
    check_template
}


option_check_log_directory () {

    if [ -z "${2}" ]
    then
        echo "Error #30: Passed log directory \"${1}\" does not exists. Please check option \"--log-dir\"."
        exit 30
    fi

    if [ ! -d "${2}" ]
    then
        echo -n "Log directory \"${2}\" does not exists. Creating directory"

        parent_dir="$(dirname ${2})"
        if [ ! -w "${parent_dir}" ]
        then
            echo " with root permissions... " >&2
            sudo mkdir -p "${2}" 2>/dev/null
        else
            echo -n "... " >&2
            mkdir -p "${2}" 2>/dev/null
        fi

        if [ $? -eq 0 ]
        then
            echo "done." >&2
        else
            echo
            echo "Error #21: Not able to create directory \"${1}\"." >&2
            exit 21
        fi

        if [ ! -w "${parent_dir}" ]
        then
            sudo chown "${3}":"$(id -g -n ${3})" "${2}" 2>/dev/null
        else
            chown "${3}":"$(id -g -n ${3})" "${2}" 2>/dev/null
        fi

        if [ $? -ne 0 ]
        then
            echo "Error #22: Not able to set directory permissions for user \"${3}\" to \"${2}\"" >&2
            exit 22
        fi
#    elif [ ! -w "${1}" ]
#    then
#        echo "Error #25: Directory \"${2}\" is not writeable. Please check file permissions." >&2
#        exit 25
    fi
}

option_check_config_file () {
    if [ ! -f "${1}" ]
    then
        echo "Error: Passed imapfilter config file \"${1}\" was not found. Please check option \"--config\"." >&2
        exit 1
#    elif [ ! -r "${1}" ]
#    then
#        echo "Error: Passed imapfilter config file \"${1}\" is not readable. Please check option \"--config\"." >&2
#        exit 2
    fi
}

option_check_log_mode () {
    if [ "${1}" != "0" ] && [ "${1}" != "1" ] && [ "${1}" != "2" ] && [ "${1}" != "3" ]
    then
        echo "Error #11: Passed log mode \"${1}\" is invalid. Please check option \"--log-mode\"." >&2
        exit 1
    fi
}

option_check_user () {
    if [ -z "${1}" ]
    then
        echo "Error #12: No valid user passed. Please check option \"--user\"." >&2
        exit 12
    elif [ "${1}" = "0" ] || [ "${1}" = "root" ]
    then
        echo "\nIt is strongly recommend to NOT run the daemon with user root."
        echo -n "Are you sure to use user root? (y/n) [n]: "

        read inp

        local lower_inp="$(echo "${inp}" | sed -e "s/\(.*\)/\L\1/")"

        if [ -z "${lower_inp}" ] || [ "${lower_inp}" != "y" -a "${lower_inp}" != "yes" ]
        then
            echo "Not sure :-) Good Bye!"
            echo
            exit 0
        fi
    else
        id "${1}" 1>/dev/null
        if [ $? -ne 0 ]
        then
            echo "\nWARNING: User \"${1}\" does not exist. Please check option \"--user\"." 2>/dev/null

            echo -n "Are you sure you want to proceed? (y/n) [n]: "

            read inp

            local lower_inp="$(echo "${inp}" | sed -e "s/\(.*\)/\L\1/")"

            if [ -z "${lower_inp}" ] || [ "${lower_inp}" != "y" -a "${lower_inp}" != "yes" ]
            then
                echo "Not sure :-) Good Bye!"
                echo
                exit 0
            fi
        fi
    fi
}

copy_daemon () {
    local src=${1}
    local dest=$(readlink -f "${2}")
    if [ -f "${dest}" ]
    then
        echo "\nFile ${dest} already exists."
        echo -n "Are you sure to overwrite the existing file? (y/n) [n]: "

        read inp

        local lower_inp="$(echo "${inp}" | sed -e "s/\(.*\)/\L\1/")"

        if [ -z "${lower_inp}" ] || [ "${lower_inp}" != "y" -a "${lower_inp}" != "yes" ]
        then
            echo "Not sure :-) Good Bye!"
            echo
            exit 0
        fi

        if [ ! -w "${dest}" ]
        then
            echo "Overwriting file ${dest} with root permissions... " >&2
            sudo cp "${src}" "${dest}"  2>/dev/null
            sudo chmod +x "${dest}" 2>/dev/null
        else
            echo -n "Overwriting file ${dest}... "
            cp "${src}" "${dest}"  2>/dev/null
            chmod +x "${dest}" 2>/dev/null
        fi
    else
        echo -n "Creating file ${dest}"

        parent_dir="$(dirname ${dest})"
        if [ ! -w "${parent_dir}" ]
        then
            echo " with root permissions... " >&2
            sudo cp "${src}" "${dest}"  2>/dev/null
            sudo chmod +x "${dest}" 2>/dev/null
        else
            echo -n "... " >&2
            cp "${src}" "${dest}"  2>/dev/null
            chmod +x "${dest}" 2>/dev/null
        fi
    fi

    echo "done." >&2
}

display_help () {
    cat << EOL
Usage: ./$(basename ${SCRIPT}) --config=PATH
       [--mail=ADDRESS] [--log-dir=PATH] [--log-mode=MODE] [--user=USER]
       [--autostart] [--verbose]

Installs an imapfilter daemon for the specified imapfilter config file.

-a, --autostart       [optional]
                      Installs the created daemon script in the related
                      runlevels 2, 3, 4 and 5. You are also able to install the
                      script manually later by your own.
                      (see command insserv)

-c, --config=PATH     [REQUIRED]
                      The lua configuration file used for imapfilter

-d, --log-dir=PATH    [optional, default=/var/log/imapfilter]
                      A directory to save the log files in. If not passed the
                      log files are saved in the default log directory.

-h, --help            Displays this help.

-l, --log-mode=MODE   [optional, default=3]
                      Sets the log mode of the imapfitler daemon:
                        0 = do not log anything
                        1 = log all output in a log file
                        2 = log errors in a separate error log file
                        3 = log all output AND all errors in the related files
                            (similar to log-mode 1 AND 2)

-m, --mail=ADDRESS    [optional]
                      A mail address to describe the daemon

-u, --user=USER       [optional, default=current user]
                      By default, the user which runs this command
                      is used to execute the daemon. To use a different user
                      specify the --user option.
                      Take care of permissions, if your are running multiple
                      imapfilter daemons!

-v, --verbose         [optional]
                      Runs the script in verbose mode.
                      Will print out each step of execution.

Examples:

1. Basic example:

   ./$(basename ${SCRIPT}) --config=/home/john_doe/.imapfilter/imapfilter.lua

2. Create the daemon for user john.doe with mail address john.doe@example.com.
   The daemon should not write any log files. Both statements are equivalent:

   ./$(basename ${SCRIPT}) \\
       --config=/home/john_doe/.imapfilter/imapfilter.lua \\
       --mail=john.doe@example.com \\
       --user=imapfilter
       --log-mode=0

   ./$(basename ${SCRIPT}) \\
       -c/home/john_doe/.imapfilter/imapfilter.lua \\
       -mjohn.doe@example.com -uimapfilter -l0

3. Create the daemon with a custom log directory and installs the daemon
   to start automatically at the end of the boot process as
   user "imapfilter":

   ./$(basename ${SCRIPT}) \\
       --config=/home/john_doe/.imapfilter/imapfilter.lua \\
       --log-dir=/home/john_doe/.imapfilter/logs \\
       --user=imapfilter \\
       --autostart

EOL
    exit 0
}

install_autostart () {
    echo "Autostart: Installing daemon to default runlevels... " >&2
    sudo insserv -d -"${1}" defaults 2>/dev/null
    echo "done." >&2
}


####################################################################################


# check if option "help" was passed
for arg in "${@}"
do
    if [ "${arg}" = "--help" ] || [ "${arg}" = "-h" ]
    then
        display_help
    fi
done

IMAPFILTER_DAEMON_USER="$(id -u -n)"
IMAPFILTER_AUTOSTART=0
IMAPFILTER_VERBOSE=0
IMAPFILTER_FILTER_CONFIG=""
IMAPFILTER_MAIL_ADDRESS=""
IMAPFILTER_LOG_DIR="/var/log/imapfilter"
IMAPFILTER_LOG_MODE="3"

# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "autostart,config:,mail::,log-dir::,log-mode::,user::,verbose" -o "ac:d::l::m::u::v" -- "${@}")

# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "${options}"

while true
do
    case "${1}" in
        "-a"|"--autostart")
            IMAPFILTER_AUTOSTART=1
            ;;
        "-c"|"--config")
            shift
            IMAPFILTER_FILTER_CONFIG="${1}"
            ;;
        "-d"|"--log-dir")
            shift
            IMAPFILTER_LOG_DIR="${1}"
            ;;
        "-l"|"--log-mode")
            shift
            IMAPFILTER_LOG_MODE="${1}"
            ;;
        "-m"|"--mail")
            shift
            IMAPFILTER_MAIL_ADDRESS="${1}"
            ;;
        "-u"|"--user")
            shift
            IMAPFILTER_DAEMON_USER="${1}"
            ;;
        "-v"|"--verbose")
            IMAPFILTER_VERBOSE=1
            set -xv  # Set xtrace and verbose mode.
            ;;
        "--")
            shift
            break
            ;;
    esac
    shift
done

check_requirements

###### options_check #######


option_check_user "${IMAPFILTER_DAEMON_USER}"

# absolute path of imapfilter config file, i.e. "/path/to/filter/john_doe_example_com.lua"
if [ -z "${IMAPFILTER_FILTER_CONFIG}" ]
then
    echo
    echo "Error: Option --config is required."
    echo
    display_help
else
    IMAPFILTER_FILTER_CONFIG=$(readlink -f "${IMAPFILTER_FILTER_CONFIG}")
    option_check_config_file "${IMAPFILTER_FILTER_CONFIG}"
fi

option_check_log_mode "${IMAPFILTER_LOG_MODE}"

if [ ${IMAPFILTER_LOG_MODE} != "0" ]
then
    LINK_IMAPFILTER_LOG_DIR=$(readlink -f "${IMAPFILTER_LOG_DIR}")
    option_check_log_directory "${IMAPFILTER_LOG_DIR}" "${LINK_IMAPFILTER_LOG_DIR}" "${IMAPFILTER_DAEMON_USER}"
else
    LINK_IMAPFILTER_LOG_DIR="${IMAPFILTER_LOG_DIR}"
fi

# file base name without extension, i.e. "john_doe_example_com"
IMAPFILTER_FILTER_CONFIG_BASENAME="$(basename ${IMAPFILTER_FILTER_CONFIG} | sed -E -e 's/(.*)\.[^\.]+$/\1/g')"

# converted base name to use as binary file name, i.e. "john-doe-example-com"
IMAPFILTER_FILTER_CONFIG_BASENAME_MINUS="$(echo ${IMAPFILTER_FILTER_CONFIG_BASENAME} | sed -e 's/_/-/g')"


if [ -z "${IMAPFILTER_MAIL_ADDRESS}" ]
then
    IMAPFILTER_MAIL_ADDRESS="${IMAPFILTER_FILTER_CONFIG_BASENAME_MINUS}"
fi



# daemon name
DAEMON_FILE_NAME="imapfilterd-${IMAPFILTER_FILTER_CONFIG_BASENAME_MINUS}"

DAEMON_TEMP_FILE=$(mktemp)
cp "${IMAPFILTER_DAEMON_TEMPLATE}" "${DAEMON_TEMP_FILE}"

sed -i -e "s/user@domain\.tld/${IMAPFILTER_MAIL_ADDRESS}/g" "${DAEMON_TEMP_FILE}"
sed -i -e "s/imapfilterd-user-domain-tld/${DAEMON_FILE_NAME}/g" "${DAEMON_TEMP_FILE}"
sed -i -E -e "s/^(# Provides:\s+)[^\s].*$/\1${DAEMON_FILE_NAME}/g" "${DAEMON_TEMP_FILE}"
sed -i -e "s/2019, Falko Matthies/$(date '+%Y')/g" "${DAEMON_TEMP_FILE}"
sed -i -E -e "s/^(CONFIG_FILE)=.*$/\1=\"$(echo "${IMAPFILTER_FILTER_CONFIG}" | sed -e "s/\//\\\\\//g")\"/g" "${DAEMON_TEMP_FILE}"

DISABLE=""
if [ "${IMAPFILTER_DAEMON_USER}" = "0" ] || [ "${IMAPFILTER_DAEMON_USER}" = "root" ]
then
    IMAPFILTER_DAEMON_USER=""
    DISABLE="#"
fi
sed -i -E -e "s/^\s*#?\s*(USER)=.*$/${DISABLE}\1=\"${IMAPFILTER_DAEMON_USER}\"/g" "${DAEMON_TEMP_FILE}"

DISABLE=""
if [ "${IMAPFILTER_LOG_MODE}" != "1" ] && [ "${IMAPFILTER_LOG_MODE}" != "3" ]
then
    DISABLE="#"
fi
sed -i -E -e "s/^\s*#?\s*(LOG_FILE)=.*$/${DISABLE}\1=\"$(echo "${LINK_IMAPFILTER_LOG_DIR}" | sed -e "s/\//\\\\\//g")\/${IMAPFILTER_FILTER_CONFIG_BASENAME}.log\"/g" "${DAEMON_TEMP_FILE}"

DISABLE=""
if [ "${IMAPFILTER_LOG_MODE}" != "2" ] && [ "${IMAPFILTER_LOG_MODE}" != "3" ]
then
    DISABLE="#"
fi
sed -i -E -e "s/^\s*#?\s*(ERROR_LOG_FILE)=.*$/${DISABLE}\1=\"$(echo "${LINK_IMAPFILTER_LOG_DIR}" | sed -e "s/\//\\\\\//g")\/${IMAPFILTER_FILTER_CONFIG_BASENAME}.error.log\"/g" "${DAEMON_TEMP_FILE}"

# destination file in /etc/init.d
DAEMON_FILE=$(readlink -f "${INIT_DIR}/${DAEMON_FILE_NAME}")
copy_daemon "${DAEMON_TEMP_FILE}" "${DAEMON_FILE}"

rm "${DAEMON_TEMP_FILE}"


if [ ${IMAPFILTER_AUTOSTART} -eq 1 ]
then
    install_autostart "${DAEMON_FILE}"
fi


echo "--------------------------"
echo "How to proceed?"
echo "1. Optional: Check the created daemon file and probably adapt settings"
echo "   ${DAEMON_FILE}"
echo "2. Enable daemon and check status"
echo "   sudo ${DAEMON_FILE} start && sudo ${DAEMON_FILE} status"
echo "3. If not done with installation binary: Enable autostart / install to rc"
echo "4. On changes: use restart"
echo "4. Remove: insserv -d + delete script"
echo
exit 0