#!/bin/bash

VERSION=1.1.0
SUBJECT=deploy-srv
USAGE="Usage: $0 -d <dsthost> -v\n
-d destination host\n
-v verbose output"

# --- options processing -------------------------------------------

if [ $# == 0 ] ; then
    echo -e $USAGE
    exit 1;
fi

while getopts ":d:v" optname
  do
    case "$optname" in
      "v")
        echo "[INFO] verbose mode active"
        VERBOSE=true
        ;;
      "d")
        DSTHOST=$OPTARG
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
if [ $VERBOSE ]; then echo "[INFO] starting server deployment"; fi

if [ $VERBOSE ]; then echo "[INFO] setting defaults"; fi
SSH="$(which ssh) -q -o StrictHostKeyChecking=no -A -F /home/${USER}/.ssh/config -l root "
PAVBASEPATH="/home/steam/pavlovserver/Pavlov/Saved/Config"

if [ ! -n "${DSTHOST}" ]; then
  echo "[ERROR] given destination host is invalid - exiting"; exit 1
fi

if [ $VERBOSE ]; then echo "[INFO] checking if lsb_release is available"; fi
RESPONSE=$($SSH $DSTHOST "which lsb_release")
if [ -z $RESPONSE ]; then
  echo "[WARN] could not find lsb_release - trying to install it"
  $SSH $DSTHOST "apt install -y lsb_release"
  if [ $VERBOSE ]; then echo "[INFO] checking if lsb_release is available (after trying to install it)"; fi
  RESPONSE=$($SSH $DSTHOST "which lsb_release")
  if [ -z $RESPONSE ]; then
    echo "[ERROR] unable to get the required lsb_release info - exiting"; exit 1
  fi
fi

if [ $VERBOSE ]; then echo "[INFO] checking output of lsb_release"; fi
RESPONSE=$($SSH $DSTHOST "/usr/bin/lsb_release -a")
if [[ $RESPONSE == *"Ubuntu"* ]]; then
  if [ $VERBOSE ]; then echo "[INFO] os identified as ubuntu"; fi
elif [[ $RESPONSE == *"Debian"* ]]; then
  if [ $VERBOSE ]; then echo "[INFO] os identified as debian"; fi
else
  echo "[ERROR] os could not be identified - exiting"; exit 1
fi

if [ $VERBOSE ]; then echo "[INFO] installing required packages"; fi
$SSH $DSTHOST "apt install -y -q gdb curl lib32gcc-s1 libc++-dev unzip"

if [ $VERBOSE ]; then echo "[INFO] doing some weird shit with libc++.so (required since update 29 it seems)"; fi
$SSH $DSTHOST "mv /usr/lib/x86_64-linux-gnu/libc++.so /usr/lib/x86_64-linux-gnu/libc++.so.backup"
$SSH $DSTHOST "ln -s /usr/lib/x86_64-linux-gnu/libc++.so.1 /usr/lib/x86_64-linux-gnu/libc++.so"

if [ $VERBOSE ]; then echo "[INFO] checking if service user exists"; fi
RESPONSE=$($SSH $DSTHOST "grep '^steam:' /etc/passwd")
if [ -z $RESPONSE ]; then
  if [ $VERBOSE ]; then echo "[INFO] could not find service user - trying to create it"; fi
  $SSH $DSTHOST "useradd -m steam"
fi

if [ $VERBOSE ]; then echo "[INFO] checking for service users home folder"; fi
if $SSH $DSTHOST '[ ! -d /home/steam ]'; then
  if [ $VERBOSE ]; then echo "[INFO] could not find service users home folder - trying to create it"; fi
  $SSH $DSTHOST "mkdir /home/steam"
fi

if [ $VERBOSE ]; then echo "[INFO] checking if pavbasepath exists"; fi
if $SSH $DSTHOST '[ ! -d $PAVBASEPATH ]'; then
  if [ $VERBOSE ]; then echo "[INFO] could not find pavbasepath - trying to create it"; fi
  $SSH $DSTHOST "mkdir -p $PAVBASEPATH"
fi

if [ $VERBOSE ]; then echo "[INFO] setting owner of /home/steam to steam:steam"; fi
$SSH $DSTHOST "chown -R steam:steam /home/steam/"

if [ $VERBOSE ]; then echo "[INFO] checking if steam is installed"; fi
if $SSH $DSTHOST '[ ! -d /home/steam/Steam ]'; then
  if [ $VERBOSE ]; then echo "[INFO] could not find steam - trying to install it"; fi
  $SSH $DSTHOST "sudo su steam -c 'mkdir ~/Steam && cd ~/Steam && curl -sqL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar zxvf -'"
fi

if [ $VERBOSE ]; then echo "[INFO] doing some weird shit with steamclient.so"; fi
SSHCMD="mkdir -p /home/steam/.steam/sdk64"
$SSH $DSTHOST "sudo su - steam -c ${SSHCMD}"
SSHCMD="cp /home/steam/Steam/steamapps/common/Steamworks\ SDK\ Redist/linux64/steamclient.so /home/steam/.steam/sdk64/steamclient.so"
$SSH $DSTHOST "sudo su - steam -c ${SSHCMD}"
SSHCMD="cp /home/steam/Steam/steamapps/common/Steamworks\ SDK\ Redist/linux64/steamclient.so /home/steam/pavlovserver/Pavlov/Binaries/Linux/steamclient.so"
$SSH $DSTHOST "sudo su - steam -c ${SSHCMD}"

if [ $VERBOSE ]; then echo "[INFO] checking if a pavlovserver is installed"; fi
if $SSH $DSTHOST '[ ! -d /home/steam/pavlovserver ]'; then
  if [ $VERBOSE ]; then echo "[WARN] could not find a pavlovserver - trying to install it"; fi
  $SSH $DSTHOST "sudo su steam -c '~/Steam/steamcmd.sh +force_install_dir /home/steam/pavlovserver +login anonymous +app_update 622970 -beta default +exit'"
fi

if [ $VERBOSE ]; then echo "[INFO] updating the steamclient"; fi
$SSH $DSTHOST "sudo su steam -c 'cd ~/Steam && ~/Steam/steamcmd.sh +login anonymous +app_update 1007 +quit'"

if [ $VERBOSE ]; then echo "[INFO] making start script executable"; fi
$SSH $DSTHOST "touch /home/steam/pavlovserver/PavlovServer.sh; chmod +x /home/steam/pavlovserver/PavlovServer.sh"

if [ $VERBOSE ]; then echo "[INFO] creating some folders and files"; fi
$SSH $DSTHOST "mkdir -p /home/steam/pavlovserver/Pavlov/Saved/Logs"
$SSH $DSTHOST "mkdir -p /home/steam/pavlovserver/Pavlov/Saved/Config/LinuxServer"
$SSH $DSTHOST "mkdir -p /home/steam/pavlovserver/Pavlov/Saved/maps"
$SSH $DSTHOST "touch /home/steam/pavlovserver/Pavlov/Saved/Config/mods.txt"
$SSH $DSTHOST "touch /home/steam/pavlovserver/Pavlov/Saved/Config/blacklist.txt"
$SSH $DSTHOST "touch /home/steam/pavlovserver/Pavlov/Saved/Config/whitelist.txt"
$SSH $DSTHOST "touch /home/steam/pavlovserver/Pavlov/Saved/Config/RconSettings.txt"
$SSH $DSTHOST "touch /home/steam/pavlovserver/Pavlov/Saved/Config/LinuxServer/Game.ini"

if [ $VERBOSE ]; then echo "[INFO] setting owner of /home/steam to steam:steam (again...)"; fi
$SSH $DSTHOST "chown -R steam:steam /home/steam/"

if [ $VERBOSE ]; then echo "[INFO] checking if ufw is active"; fi
RESPONSE=$($SSH $DSTHOST "ufw status")
if [[ $RESPONSE == *"active"* ]]; then
  if [ $VERBOSE ]; then echo "[INFO] ufw is active - setting rules now"; fi
  $SSH $DSTHOST "ufw allow 7777"
  $SSH $DSTHOST "ufw allow 8177"
  $SSH $DSTHOST "ufw allow 9100"
else
  if [ $VERBOSE ]; then echo "[WARN] ufw is inactive - please check if this what you want"; fi
fi
$SSH $DSTHOST "ufw status"

if [ $VERBOSE ]; then echo "[INFO] checking if systemd file exists"; fi
if $SSH $DSTHOST '[ ! -f /etc/systemd/system/pavlovserver.service ]'; then
  if [ $VERBOSE ]; then echo "[INFO] could not find systemd file - trying to create it"; fi
  $SSH $DSTHOST "cat > /etc/systemd/system/pavlovserver.service <<EOL
[Unit]
Description=Pavlov VR dedicated server

[Service]
Type=simple
WorkingDirectory=/home/steam/pavlovserver
ExecStart=/home/steam/pavlovserver/PavlovServer.sh

RestartSec=1
Restart=always
User=steam
Group=steam

[Install]
WantedBy = multi-user.target
EOL"
fi

if [ $VERBOSE ]; then echo "[INFO] enabling the pavlovserver systemd service"; fi
$SSH $DSTHOST "systemctl enable pavlovserver.service"
$SSH $DSTHOST "systemctl status pavlovserver.service"

if [ $VERBOSE ]; then echo "[INFO] exiting without errors"; fi
exit 0
