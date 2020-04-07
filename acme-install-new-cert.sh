#!/usr/bin/env bash

# usage function
function usage()
{
   cat << HEREDOC

   Usage: ${progname} <REQUIRED ARGUMENTS> <OPTIONAL ARGUMENTS>

   Required Arguments:
    -d, --domain          pass in <DOMAIN_NAME>

    ______________________________________________
    -a, --API-token        Cloudflare API Token
    -i, --Account-ID       Cloudflare Account ID
    ________________ or _________________________
    -e, --email            Cloudflare Account Email
    -g, --Global-API       Cloudflare Global API Key

   Optional Arguments:
     -h, --help           show this help message and exit
     -v, --verbose        increase the verbosity of the bash script
     --dry-run            List command line argments and exit
     --do-not-issue       do not Issue a Certificate (Useful when changing reload command)
     --do-not-install     do not Install issued certificate (Useful when using --test command)
     --force              Attempt to Force Let's Encrypt to issue a new certificate
     -c, --command        Reload command "STRING"
     -t, --test           Use Let's Encrypt staging servers to issue Test Certificates

HEREDOC
}  

function create_acme_service_file()
{ 
  file_contents="[Unit]
Description=Renew Let's Encrypt certificates using acme.sh for %I
After=network-online.target

[Service]
Type=oneshot
ExecStart="/root/.acme.sh"/acme.sh --home "/root/.acme.sh" --cron --issue --dns dns_cf -d %i --log

"
  echo "${file_contents}" > "${ACME_SERVICE_FILE}"
}

function create_acme_timer_file()
{
  file_contents="[Unit]
Description=Daily renewal of Let's Encrypt's certificates

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target

"

  echo "${file_contents}" > "${ACME_TIMER_FILE}"

}

# initialize variables
LE_DIR_PATH="/etc/letsencrypt"
SYSTEM_FILE_PATH="/etc/systemd/system"
ACME_SERVICE_BASE="acme_letsencrypt@"
ACME_SERVICE_FILE_EXTENSION="service"
ACME_TIMER_FILE_EXTENSION="timer"
ACME_PATH=/root/.acme.sh/acme.sh

ACME_SERVICE_FILE=""
ACME_SERVICE_FILE_EXISTS=0
ACME_TIMER_FILE=""
ACME_TIMER_FILE_EXISTS=0

LE_DIR_PATH_PREVIOUS_EXIST=0
ACME_OPTIONS=""
ENVIRONMENT_VARIABLES=0

progname=$(basename -- "$0")
verbose=0
dryrun=0
testrun=0
force=0
do_not_issue=0
do_not_install=0
DOMAIN_NAME=""
RELOAD_CMD=""
CF_ACCOUNT_ID=""
CF_API_TOKEN=""
CF_EMAIL=""
CF_GLOBAL_API=""

CF_GLOBAL_API_KEY_OPTION=0
CF_API_TOKEN_METHOD_OPTION=0


# use getopt and store the output into $OPTS
# note the use of -o for the short options, --long for the long name options
# and a : for any option that takes a parameter
OPTS=$(getopt -o "htd:a:i:e:g:c:v" --long "help,test,domain:,API-token:,Account-ID:,email:,Global-API:,command:,verbose,dry-run,do-not-issue,do-not-install,force" -n "$progname" -- "$@")
if [ $? != 0 ] ; then echo "Error in command line arguments." >&2 ; usage; exit 1 ; fi
eval set -- "$OPTS"

while true; do
  # uncomment the next line to see how shift is working
  # echo "\$1:\"$1\" \$2:\"$2\""
  case "$1" in
    -h | --help ) usage; exit; ;;
    -t | --test ) testrun=1; shift ;;
    -d | --domain ) DOMAIN_NAME="$2"; shift 2 ;;
    -a | --API-token ) CF_API_TOKEN="$2"; shift 2 ;;
    -i | --Account-ID ) CF_ACCOUNT_ID="$2"; shift 2 ;;
    -e | --email ) CF_EMAIL="$2"; shift 2 ;;
    -g | --Global-API ) CF_GLOBAL_API="$2"; shift 2 ;;
    -c | --comand ) RELOAD_CMD="$2"; shift 2 ;;
    --dry-run ) dryrun=1; shift ;;
    --do-not-issue ) do_not_issue=1; shift ;;
    --do-not-install ) do_not_install=1; shift ;;
    --force ) force=1; shift;;
    -v | --verbose ) verbose=$((verbose + 1)); shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [ "$verbose" -gt 0 ]; then

   # print out all the parameters we read in
   cat <<-EOM

Program Command Line Arguments:
   domain= ${DOMAIN_NAME}
   reload command= ${RELOAD_CMD}
   Cloudflare API Token: ${CF_API_TOKEN}
   Cloudflare Account ID: ${CF_ACCOUNT_ID}
   Cloudflare Email: ${CF_EMAIL}
   Cloudflare Global API: ${CF_GLOBAL_API}
   verbose=$verbose
   dryrun=$dryrun
   do_not_issue=$do_not_issue
   do_not_install=$do_not_install
   force=$force
EOM
fi

if [ ${dryrun} = 1 ]; then
  exit 0;
fi

## Test for Required Elements
# Test for Domain Name
if [ -z "${DOMAIN_NAME}" ]; then
  echo "ERROR: You must enter a <DOMAIN_NAME> for program to proceed"
  echo "...Exiting"
  exit 1;
else
  LE_DIR_PATH="${LE_DIR_PATH}/${DOMAIN_NAME}"
fi


#Test for either Either email/global-key or API-Token/Account-ID
if [ -n "${CF_EMAIL}" ] && [ -n "${CF_GLOBAL_API}" ]; then
  CF_GLOBAL_API_KEY_OPTION=1
fi

if [ -n "${CF_API_TOKEN}" ] && [ -n "${CF_ACCOUNT_ID}" ]; then
  CF_API_TOKEN_METHOD_OPTION=1
fi
  
if ! ( [ ${CF_GLOBAL_API_KEY_OPTION} -eq 1 ] || [ ${CF_API_TOKEN_METHOD_OPTION} -eq 1 ] ); then
  echo "ERROR: You must enter either a:"
  echo "   Cloudflare API-TOKEN/Cloudflare Account-ID OR "
  echo "   Cloudflare Email/Cloudflare Global API Key combination to continue."
  echo "...Exiting"
  exit 2;
fi

ACME_SERVICE_FILE="${SYSTEM_FILE_PATH}/${ACME_SERVICE_BASE}.${ACME_SERVICE_FILE_EXTENSION}"
ACME_TIMER_FILE="${SYSTEM_FILE_PATH}/${ACME_SERVICE_BASE}.${ACME_TIMER_FILE_EXTENSION}"

INSTALL_PATH="--key-file /etc/letsencrypt/${DOMAIN_NAME}/privkey.pem --fullchain-file /etc/letsencrypt/${DOMAIN_NAME}/fullchain.pem --cert-file /etc/letsencrypt/${DOMAIN_NAME}/cert.pem --ca-file /etc/letsencrypt/${DOMAIN_NAME}/chain.pem"

if [ ${testrun} -eq 1 ]; then
  if [ -z "${ACME_OPTIONS}" ]; then
    ACME_OPTIONS="--staging"
  else
    ACME_OPTIONS="${ACME_OPTIONS} --staging"
  fi
fi

if [ ${force} -eq 1 ]; then
  if [ -z "${ACME_OPTIONS}" ]; then
    ACME_OPTIONS="--force"
  else
    ACME_OPTIONS="${ACME_OPTIONS} --force"
  fi
fi

if [ ${CF_API_TOKEN_METHOD_OPTION} -eq 1 ]; then
  ENVIRONMENT_VARIABLES="CF_Token=${CF_API_TOKEN} CF_Account_ID=${CF_ACCOUNT_ID}"
elif [ ${CF_GLOBAL_API_KEY_OPTION} -eq 1 ]; then
  ENVIRONMENT_VARIABLES="CF_Key=${CF_GLOBAL_API} CF_Email=${CF_EMAIL}"
fi


if [ $verbose -ge 1 ]; then
  cat << EOM
   
Program Variables:
   Lets Encrypt Directory Path: ${LE_DIR_PATH}
   ACME PATH: ${ACME_PATH}
   ACME Systemd Service File: ${ACME_SERVICE_FILE}
   ACME Systemd Timer File: ${ACME_TIMER_FILE}
   ACME Options: ${ACME_OPTIONS}
   Environment Variables: ${ENVIRONMENT_VARIABLES}
   Install Path: ${INSTALL_PATH}

EOM
fi

## Begin Execution 
echo
echo "Begin Program Exectution"
if ! [ -d ${LE_DIR_PATH} ]; then 
  echo "   Creating directory: ${LE_DIR_PATH}"
  mkdir -p ${LE_DIR_PATH}
else
  LE_DIR_PATH_PREVIOUS_EXIST=1
fi

# Acme Install portion

#CF_Token="${CF_API_TOKEN}" CF_Account_ID="${CF_ACCOUNT_ID}" "/root/.acme.sh/acme.sh" ${ACME_OPTIONS} --issue --dns dns_cf -d ${DOMAIN_NAME}
if [ ${do_not_issue} -ne 1 ]; then
   env ${ENVIRONMENT_VARIABLES} ${ACME_PATH} ${ACME_OPTIONS} --issue --dns dns_cf -d ${DOMAIN_NAME}
fi

#"/root/.acme.sh/acme.sh" ${ACME_OPTIONS} --install-cert -d ${DOMAIN_NAME} ${INSTALL_PATH} --reloadcmd ${RELOAD_CMD}
if [ ${do_not_install} -ne 1 ]; then
   ${ACME_PATH} ${ACME_OPTIONS} --install-cert -d ${DOMAIN_NAME} ${INSTALL_PATH} --reloadcmd "${RELOAD_CMD}"
fi

if [ -d "${SYSTEM_FILE_PATH}" ]; then
  if [ ! -f "${ACME_SERVICE_FILE}" ]; then
    create_acme_service_file
  else
    ACME_SERVICE_FILE_EXISTS=1
  fi

  if [ ! -f "${ACME_TIMER_FILE}" ]; then
    create_acme_timer_file
  else
    ACME_TIMER_FILE_EXISTS=1
  fi
fi

#if [ ${testrun} -eq 1 ]; then
  systemctl start "${ACME_SERVICE_BASE}${DOMAIN_NAME}.${ACME_SERVICE_FILE_EXTENSION}"
  systemctl enable "${ACME_SERVICE_BASE}${DOMAIN_NAME}.${ACME_TIMER_FILE_EXTENSION}"
  systemctl start "${ACME_SERVICE_BASE}${DOMAIN_NAME}.${ACME_TIMER_FILE_EXTENSION}"
  systemctl daemon-reload
#fi

#SYS_FILE="acme_letsencrypt@${DOMAIN_NAME}.timer"
#
#systemctl enable ${SYS_FILE}
#systemctl start ${SYS_FILE}

if [ ${testrun} -eq 1 ]; then
  echo 
  echo "Removal Process:"
  if [ ${LE_DIR_PATH_PREVIOUS_EXIST} -eq 0 ]; then
    echo "   Removing staging Lets Encrypt Directory: ${LE_DIR_PATH}"
    rm -rf ${LE_DIR_PATH}
  fi

    echo "   Stopping and Disabling systemd timer: ${ACME_SERVICE_BASE}${DOMAIN_NAME}.${ACME_TIMER_FILE_EXTENSION}"
    systemctl stop "${ACME_SERVICE_BASE}${DOMAIN_NAME}.${ACME_TIMER_FILE_EXTENSION}"
    systemctl disable "${ACME_SERVICE_BASE}${DOMAIN_NAME}.${ACME_TIMER_FILE_EXTENSION}"
    
    echo "   Stopping and Disabling systemd service: ${ACME_SERVICE_BASE}${DOMAIN_NAME}.${ACME_SERVICE_FILE_EXTENSION}"
    systemctl stop "${ACME_SERVICE_BASE}${DOMAIN_NAME}.${ACME_SERVICE_FILE_EXTENSION}"
    systemctl disable "${ACME_SERVICE_BASE}${DOMAIN_NAME}.${ACME_SERVICE_FILE_EXTENSION}"

    systemctl daemon-reload
    systemctl reset-failed

fi

echo "Done"
