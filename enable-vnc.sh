#!/bin/bash -e

USER_NAME=appveyor
LOCK_FILE="${HOME}/Desktop/Delete me to continue build.txt"

YELLOW='\033[0;33m'
NC='\033[0m'

if [[ -z "${APPVEYOR_VNC_PASSWORD}" ]]; then
    echo -e "${YELLOW}APPVEYOR_VNC_PASSWORD${NC} variable is not defined!"
    echo "Generating one..."
    USER_PASSWORD_LENGTH=20
    echo $LC_CTYPE
    APPVEYOR_VNC_PASSWORD=$(export LC_CTYPE=C; cat /dev/urandom | tr -dc _A-Z-a-z-0-9 | head -c${USER_PASSWORD_LENGTH};)
    echo $LC_CTYPE
    echo -e "Password set to ${YELLOW}'${APPVEYOR_VNC_PASSWORD}'${NC}"
fi

/usr/bin/dscl -u "$USER_NAME" -P "appveyor" . -passwd "/Users/$USER_NAME" "$APPVEYOR_VNC_PASSWORD" &&
security set-keychain-password -o appveyor -p "$APPVEYOR_VNC_PASSWORD" "/Users/$USER_NAME/Library/Keychains/login.keychain" ||
    { echo "Failed to change user's password! Aborting" ; exit 1; }


# trap 'sudo ufw deny OpenSSH >/dev/null' EXIT SIGHUP SIGINT SIGQUIT SIGTERM ERR

# open 5900 port for management network interface
# sudo ufw allow OpenSSH > /dev/null 2>&1

# get external IP address via https://www.appveyor.com/tools/my-ip.aspx
EXT_IP=$(curl -sf https://www.appveyor.com/tools/my-ip.aspx)

# get ip address of management network interface and figure out corresponding port on NAT
#INT_IP=$(ip -o -4 addr show up primary scope global | ( read -r num dev fam addr rest; echo ${addr%/*}; ))
INT_IP=$(ipconfig getifaddr en0)
IFS='.' read -r -a INT_IP_ARR <<< "$INT_IP"
PORT=$(( 59000 + INT_IP_ARR[3] ))

# print out connection command
echo "Connect to ${EXT_IP} port $PORT with ${USER_NAME} user:"
echo -e "${YELLOW}    vnc ${USER_NAME}@${EXT_IP} -p ${PORT}${NC}"
if [[ -n "${USERKEY_MD5}" ]]; then
    echo ""
    echo "RSA key fingerprint:"
    echo "    ${USERKEY_SHA256}"
    echo "    ${USERKEY_MD5}"
fi

if [[ -n "${APPVEYOR_VNC_BLOCK}" ]] && ${APPVEYOR_VNC_BLOCK}; then
    # create "lock" file.
    touch "${LOCK_FILE}"
    echo -e "Build paused. To resume it, open a VNC session and delete ${YELLOW}'${LOCK_FILE}'${NC} file from desktop."
    # wait until "lock" file is deleted by user.
    while [ -f "${LOCK_FILE}" ]; do
        sleep 1
    done
    echo "Build lock file has been deleted. Resuming build."
fi
