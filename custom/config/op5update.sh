#!/bin/bash

###
# This script is designed for RHEL/CentOS to install all the nessissary
# check commands and NRPE configuration for an OP5 proxy. Run this script
# on new installs or to update existing proxies.
#
# Created by: Larry Titus
# Last Updated: July 2 2018
###

### Formatting ###
TIMESTAMP=`date +%Y%m%d-%H%M%S`
NC='\033[0m' # No Color
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'

### Detect if repo has already been cloned ###
if [ -d /opt/plugins ]

then
  ### Update existing files from repo ###
  echo -e "${YELLOW}Existing repo detected. Updating existing check commands from TAM-OP5 repo.${NC}\n"
  cd /opt/plugins && git pull
  [ $? != 0 ] && echo -e "${RED}A problem has occured updating from repo.${NC}" && exit 1

else
  ### Check out code from OP5 repo ###
  echo -e "${GREEN}No existing check commands found. Cloning commands from TAM-OP5 repo.${NC}\n"
  #git clone git@github.com:greenpeace/TAM-OP5.git /opt/plugins/
  git clone https://github.com/greenpeace/TAM-OP5.git /opt/plugins/
  [ $? != 0 ] && echo -e "${RED}A problem has occured cloning the repo.${NC}" && exit 1
fi

### Fix SUID permissions because git will drop the SUID bit ###
echo -e "${GREEN}Setting SUID bit on the /opt/plugins/suid/ directory and commands.${NC}\n"
chmod -R 4755 /opt/plugins/suid/
[ $? != 0 ] && echo -e "${RED}A problem has occured setting SUID permissions.${NC}" && exit 1

### Detect if config exists ###
if [ -f /etc/nrpe.d/op5_commands.cfg ]

then
  ### Backup/rename existing config if it differs from the repo version ###
  DIFF=$(diff /etc/nrpe.d/op5_commands.cfg /opt/plugins/custom/config/op5_commands.cfg)
  if [ "$DIFF" != "" ]
  then
    echo -e "${YELLOW}A local op5_commands.cfg file was found and differs from the repo version. Backing up existing configuration as op5_commands.cfg.${TIMESTAMP}.${NC}\n"
    mv -f /etc/nrpe.d/op5_commands.cfg /etc/nrpe.d/op5_commands.cfg.${TIMESTAMP}
    [ $? != 0 ] && echo -e "${RED}A problem has occured backing up the existing configuration.${NC}" && exit 1

  else
    ### No changes have been made to op5_commands.cfg. Bail out successfully. ###
    echo -e "${YELLOW}A local op5_commands.cfg file was found but is the same as the repo version.${NC}"
    echo -e "${GREEN}Update complete.${NC}" && exit 0
  fi

else
  echo -e "${GREEN}No existing op5_commands.cfg detected.${NC}\n"
fi

### Create new op5_commands.cfg after renaming old one (if needed) ###
echo -e "${GREEN}Creating new op5_commands.cfg from repo.${NC}\n"
cp /opt/plugins/custom/config/op5_commands.cfg /etc/nrpe.d/
[ $? != 0 ] && echo -e "${RED}A problem has occured creating op5_commands.cfg.${NC}" && exit 1

### Restart NRPE ###
echo -e "${GREEN}Restarting the NRPE service.${NC}\n"
service nrpe stop
service nrpe start
[ $? != 0 ] && echo -e "${RED}A problem has occured starting the NRPE service.${NC}" && exit 1

echo -e "${GREEN}Update complete.${NC}"
