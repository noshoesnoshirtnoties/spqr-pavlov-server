#!/bin/bash

VERSION=1.0.0
SUBJECT=deploy-cfg
USAGE="Usage: $0 -s srcpath -d dsthost -u sshuser -v\n
-s source path\n
-d destination host\n
-u ssh/scp user\n
-v verbose output"

# --- options processing -------------------------------------------

if [ $# == 0 ] ; then
    echo -e $USAGE
    exit 1;
fi

while getopts ":s:d:u:v" optname
  do
    case "$optname" in
      "v")
        echo "[INFO] verbose mode active"
        VERBOSE=true
        ;;
      "s")
        SRCPATH=$OPTARG
        ;;
      "d")
        DSTHOST=$OPTARG
        ;;
      "u")
        SSHUSER=$OPTARG
        ;;
      "?")
        echo "[ERROR] unknown option $OPTARG - exiting"
        exit 1;
        ;;
      ":")
        echo "[ERROR] no argument value for option $OPTARG - exiting"
        exit 1;
        ;;
      *)
        echo "[ERROR] unknown error while processing options - exiting"
        exit 1;
        ;;
    esac
  done

shift $(($OPTIND - 1))

# --- body --------------------------------------------------------

read -s -n 1 -p "[WAIT] press any key to continue..." && echo ""
if [ $VERBOSE ]; then echo "[INFO] starting config deployment"; fi

if [ $VERBOSE ]; then echo "[INFO] setting defaults"; fi
SSH="$(which ssh) -q -o StrictHostKeyChecking=no -A -F /home/${USER}/.ssh/config -l ${SSHUSER} "
SCP="$(which scp) -F /home/${USER}/.ssh/config "
PAVBASEPATH="/home/steam/pavlovserver/Pavlov/Saved/Config"
FILES=(
  "LinuxServer/Game.ini"
  "mods.txt"
  "whitelist.txt"
  "blacklist.txt"
  "RconSettings.txt"
)

if [ ! -d "${SRCPATH}" ]; then
  echo "[ERROR] given source path is invalid - exiting"; exit 1
fi

if [ ! -n "${DSTHOST}" ]; then
  echo "[ERROR] given destination host is invalid - exiting"; exit 1
fi

if [ $VERBOSE ]; then echo "[INFO] stopping the server"; fi
$SSH $DSTHOST "/usr/bin/systemctl stop pavlovserver.service"
sleep 5

if [ $VERBOSE ]; then echo "[INFO] transferring files"; fi
for FILE in "${FILES[@]}"; do
  $SCP "${SRCPATH}/${FILE}" ${SSHUSER}@${DSTHOST}:${PAVBASEPATH}/${FILE}
  $SSH $DSTHOST "/usr/bin/chmod 664 ${PAVBASEPATH}/${FILE}; /usr/bin/chown steam:steam ${PAVBASEPATH}/${FILE}"
done

if [ $VERBOSE ]; then echo "[INFO] starting the server"; fi
$SSH $DSTHOST "/usr/bin/systemctl start pavlovserver.service"
sleep 5
$SSH $DSTHOST "/usr/bin/systemctl status pavlovserver.service | grep 'Active:'"

if [ $VERBOSE ]; then echo "[INFO] exiting without errors"; fi

exit 0
