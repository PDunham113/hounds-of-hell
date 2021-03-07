#!/bin/bash
set -e
# A library of shared utility functions

# Wrapper for seeding debconf database
#
# Arguments: <selection>
util_set_selection () {
  echo "${1}" | debconf-set-selections
}

# Updates/Inserts a line of text in a config file based on a keyphrase.
#
# This function will search FILE for a line containing KEY. If it exists, the
# line is replaced with LINE. Otherwise, LINE is appended to the file.
#
# Arguments: <file> <key> <line>
util_update_on_key () {
  local -r FILE=$1; local -r KEY=$2; local -r LINE=$3

  if grep -Fq "${KEY}" "${FILE}"; then
    sed -i "s~.*${KEY}.*~${LINE}~" "${FILE}"
  else
    echo "${LINE}" >> "${FILE}"
  fi
}
