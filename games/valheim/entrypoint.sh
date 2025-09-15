#!/bin/bash

clear
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Wait for the container to fully initialize
sleep 1

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Map Pterodactyl's SRCDS_APPID -> STEAM_APPID (falls nur SRCDS_APPID gesetzt ist)
if [ -n "${SRCDS_APPID:-}" ] && [ -z "${STEAM_APPID:-}" ]; then
    export STEAM_APPID="${SRCDS_APPID}"
fi
# Valheim-Binary erwartet SteamAppId (Game-App 892970)
export SteamAppId="${SteamAppId:-892970}"

# Information output
echo -e "${BLUE}---------------------------------------------------------------------${NC}"
echo -e "${RED}Valheim Image${NC}"
echo -e "${BLUE}---------------------------------------------------------------------${NC}"
echo -e "${YELLOW}$(lsb_release -a)${NC}"
echo -e "${YELLOW}Current timezone: ${RED} $(cat /etc/timezone)${NC}"
echo -e "${BLUE}---------------------------------------------------------------------${NC}"

# Set environment for Steam Proton
if [ -f "/usr/local/bin/proton" ]; then
    if [ -n "${STEAM_APPID:-}" ]; then
        mkdir -p "/home/container/.steam/steam/steamapps/compatdata/${STEAM_APPID}"
        export STEAM_COMPAT_CLIENT_INSTALL_PATH="/home/container/.steam/steam"
        export STEAM_COMPAT_DATA_PATH="/home/container/.steam/steam/steamapps/compatdata/${STEAM_APPID}"
        export WINETRICKS="/usr/sbin/winetricks"
    else
        echo -e "${BLUE}----------------------------------------------------------------------------------${NC}"
        echo -e "${RED}WARNING!!! Proton needs variable STEAM_APPID, else it will not work. Please add it${NC}"
        echo -e "${RED}Server stops now${NC}"
        echo -e "${BLUE}----------------------------------------------------------------------------------${NC}"
        exit 0
    fi
fi

# Switch to the container's working directory
cd /home/container || exit 1

echo -e "${BLUE}---------------------------------------------------------------------${NC}"
echo -e "${GREEN}Starting Server.... Please wait...${NC}"
echo -e "${BLUE}---------------------------------------------------------------------${NC}"

## just in case someone removed the defaults.
if [ -z "${STEAM_USER:-}" ]; then
    echo -e "${BLUE}---------------------------------------------------------------------${NC}"
    echo -e "${YELLOW}Steam user is not set. ${NC}"
    echo -e "${YELLOW}Using anonymous user.${NC}"
    echo -e "${BLUE}---------------------------------------------------------------------${NC}"
    STEAM_USER="anonymous"
    STEAM_PASS=""
    STEAM_AUTH=""
else
    echo -e "${BLUE}---------------------------------------------------------------------${NC}"
    echo -e "${YELLOW}user set to ${STEAM_USER} ${NC}"
    echo -e "${BLUE}---------------------------------------------------------------------${NC}"
fi

## if auto_update is not set or to 1 update
AUTO_UPDATE="${AUTO_UPDATE:-1}"

# SteamCMD (Update) nutzt idR die Dedicated-Server-App 896660, wenn nichts gesetzt ist
export STEAM_APPID="${STEAM_APPID:-896660}"

if [ "${AUTO_UPDATE}" = "1" ]; then
    # Update Source Server
    if [ -n "${STEAM_APPID}" ]; then
        # Login bauen
        if [ "${STEAM_USER}" = "anonymous" ]; then
            LOGIN="+login anonymous"
        else
            LOGIN="+login ${STEAM_USER} ${STEAM_PASS:-} ${STEAM_AUTH:-}"
        fi

        # Optional: Windows-Plattform für SteamCMD erzwingen
        FORCE_TYPE=""
        if [ "${WINDOWS_INSTALL:-0}" = "1" ]; then
            FORCE_TYPE="+@sSteamCmdForcePlatformType windows"
        fi

        # Optional: Beta / Betapass
        BETA_OPTS=""
        if [ -n "${STEAM_BETAID:-}" ]; then
            BETA_OPTS="${BETA_OPTS} -beta ${STEAM_BETAID}"
        fi
        if [ -n "${STEAM_BETAPASS:-}" ]; then
            BETA_OPTS="${BETA_OPTS} -betapassword ${STEAM_BETAPASS}"
        fi

        # Optional: HLDS Game Config
        HLDS_CFG=""
        if [ -n "${HLDS_GAME:-}" ]; then
            HLDS_CFG="+app_set_config 90 mod ${HLDS_GAME}"
        fi

        # Optional: validate
        VALIDATE_OPT=""
        if [ -n "${VALIDATE:-}" ]; then
            VALIDATE_OPT="validate"
        fi

        ./steamcmd/steamcmd.sh \
            +force_install_dir /home/container \
            ${LOGIN} \
            ${FORCE_TYPE} \
            +app_update "${STEAM_APPID}" ${BETA_OPTS} ${HLDS_CFG} ${VALIDATE_OPT} \
            +quit
    else
        echo -e "${BLUE}---------------------------------------------------------------------${NC}"
        echo -e "${YELLOW}No appid set. Starting Server${NC}"
        echo -e "${BLUE}---------------------------------------------------------------------${NC}"
    fi
else
    echo -e "${BLUE}---------------------------------------------------------------${NC}"
    echo -e "${YELLOW}Not updating game server as AUTO_UPDATE=0. Starting Server${NC}"
    echo -e "${BLUE}---------------------------------------------------------------${NC}"
fi

# Setup NSS Wrapper for use ($NSS_WRAPPER_PASSWD and $NSS_WRAPPER_GROUP have been set by the Dockerfile)
export USER_ID="$(id -u)"
export GROUP_ID="$(id -g)"
envsubst < /passwd.template > "${NSS_WRAPPER_PASSWD}"

# Achtung: LD_PRELOAD wird hier auf nss_wrapper gesetzt; dein Startup-Befehl kann es später überschreiben (z.B. doorstop)
export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libnss_wrapper.so

# Replace Startup Variables ({{VAR}} -> ${VAR}) und anzeigen
MODIFIED_STARTUP=$(printf '%s' "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo -e ":/home/container$ ${MODIFIED_STARTUP}"

# Run the Server
eval ${MODIFIED_STARTUP}
