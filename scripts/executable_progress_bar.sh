#!/usr/bin/env bash

# This is a script that helps create some better progress/spinner TUI. Pulled mostly as-is from the Proxmox VE Helper Scripts.

variables() {
  NSAPP=$(echo ${APP,,} | tr -d ' ')                # This function sets the NSAPP variable by converting the value of the APP variable to lowercase and removing any spaces.
  var_install="${NSAPP}-install"                    # sets the var_install variable by appending "-install" to the value of NSAPP.
  INTEGER='^[0-9]+([.][0-9]+)?$'                    # it defines the INTEGER regular expression pattern.
  PVEHOST_NAME=$(hostname)                          # gets the Proxmox Hostname and sets it to Uppercase
  DIAGNOSTICS="yes"                                 # sets the DIAGNOSTICS variable to "yes", used for the API call.
  METHOD="default"                                  # sets the METHOD variable to "default", used for the API call.
  RANDOM_UUID="$(cat /proc/sys/kernel/random/uuid)" # generates a random UUID and sets it to the RANDOM_UUID variable.
}

# This function sets various color variables using ANSI escape codes for formatting text in the terminal.
color() {
  # Colors
  YW=$(echo "\033[33m")
  YWB=$(echo "\033[93m")
  BL=$(echo "\033[36m")
  RD=$(echo "\033[01;31m")
  BGN=$(echo "\033[4;92m")
  GN=$(echo "\033[1;92m")
  DGN=$(echo "\033[32m")

  # Formatting
  CL=$(echo "\033[m")
  UL=$(echo "\033[4m")
  BOLD=$(echo "\033[1m")
  BFR="\\r\\033[K"
  HOLD=" "
  TAB="  "

  # Icons
  CM="${TAB}✔️${TAB}${CL}"
  CROSS="${TAB}✖️${TAB}${CL}"
  INFO="${TAB}💡${TAB}${CL}"
  OS="${TAB}🖥️${TAB}${CL}"
  OSVERSION="${TAB}🌟${TAB}${CL}"
  CONTAINERTYPE="${TAB}📦${TAB}${CL}"
  DISKSIZE="${TAB}💾${TAB}${CL}"
  CPUCORE="${TAB}🧠${TAB}${CL}"
  RAMSIZE="${TAB}🛠️${TAB}${CL}"
  SEARCH="${TAB}🔍${TAB}${CL}"
  VERIFYPW="${TAB}🔐${TAB}${CL}"
  CONTAINERID="${TAB}🆔${TAB}${CL}"
  HOSTNAME="${TAB}🏠${TAB}${CL}"
  BRIDGE="${TAB}🌉${TAB}${CL}"
  NETWORK="${TAB}📡${TAB}${CL}"
  GATEWAY="${TAB}🌐${TAB}${CL}"
  DISABLEIPV6="${TAB}🚫${TAB}${CL}"
  DEFAULT="${TAB}⚙️${TAB}${CL}"
  MACADDRESS="${TAB}🔗${TAB}${CL}"
  VLANTAG="${TAB}🏷️${TAB}${CL}"
  ROOTSSH="${TAB}🔑${TAB}${CL}"
  CREATING="${TAB}🚀${TAB}${CL}"
  ADVANCED="${TAB}🧩${TAB}${CL}"
}

# This function enables error handling in the script by setting options and defining a trap for the ERR signal.
catch_errors() {
  set -Eeuo pipefail
  trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
}

# This function is called when an error occurs. It receives the exit code, line number, and command that caused the error, and displays an error message.
error_handler() {
  source /dev/stdin <<<$(wget -qLO - https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/api.func)
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID >/dev/null; then kill $SPINNER_PID >/dev/null; fi
  printf "\e[?25h"
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  post_update_to_api "failed" "${command}"
  echo -e "\n$error_message\n"
}

# This function displays an informational message with logging support.
start_spinner() {
  local msg="$1"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local spin_i=0
  local interval=0.1
  local term_width=$(tput cols)

  {
    while [ "${SPINNER_ACTIVE:-1}" -eq 1 ]; do
      printf "\r\e[2K${frames[spin_i]} ${YW}%b${CL}" "$msg" >&2
      spin_i=$(((spin_i + 1) % ${#frames[@]}))
      sleep "$interval"
    done
  } &

  SPINNER_PID=$!
}

msg_info() {
  local msg="$1"
  if [ "${SPINNER_ACTIVE:-0}" -eq 1 ]; then
    return
  fi

  SPINNER_ACTIVE=1
  start_spinner "$msg"
}

msg_ok() {
  if [ -n "${SPINNER_PID:-}" ] && ps -p "$SPINNER_PID" >/dev/null 2>&1; then
    kill "$SPINNER_PID" >/dev/null 2>&1
    wait "$SPINNER_PID" 2>/dev/null || true
  fi

  local msg="$1"
  printf "\r\e[2K${CM}${GN}%b${CL}\n" "$msg" >&2
  unset SPINNER_PID
  SPINNER_ACTIVE=0

  log_message "OK" "$msg"
}

msg_error() {
  if [ -n "${SPINNER_PID:-}" ] && ps -p "$SPINNER_PID" >/dev/null 2>&1; then
    kill "$SPINNER_PID" >/dev/null 2>&1
    wait "$SPINNER_PID" 2>/dev/null || true
  fi

  local msg="$1"
  printf "\r\e[2K${CROSS}${RD}%b${CL}\n" "$msg" >&2
  unset SPINNER_PID
  SPINNER_ACTIVE=0
  log_message "ERROR" "$msg"
}

log_message() {
  local level="$1"
  local message="$2"
  local timestamp
  local logdate
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  logdate=$(date '+%Y-%m-%d')

  LOGDIR="/usr/local/community-scripts/logs"
  LOGDIR="/tmp"
  mkdir -p "$LOGDIR"

  LOGFILE="${LOGDIR}/${logdate}_${NSAPP}.log"
  echo "$timestamp - $level: $message" >>"$LOGFILE"
}

msg_info "Running..."
sleep 3
msg_error "Uh oh!"
sleep 1
msg_info "Running 2..."
sleep 3
msg_ok "Done!"
