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

# Default the IMAGE_PROMPT environment variable to something nice
IMAGE_PROMPT=${IMAGE_PROMPT:-$'\033[1m\033[33mcontainer@gameservertech~ \033[0m'}
export IMAGE_PROMPT

# Information output
echo -e "${BLUE}---------------------------------------------------------------------${NC}"
echo -e "${YELLOW}Image from gOOvER${NC}"
echo -e "${BLUE}---------------------------------------------------------------------${NC}"

cd /home/container

# Replace Startup Variables
MODIFIED_STARTUP=$(echo -e ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo -e ":/home/container$ ${MODIFIED_STARTUP}"

# Run the Server
eval ${MODIFIED_STARTUP}
