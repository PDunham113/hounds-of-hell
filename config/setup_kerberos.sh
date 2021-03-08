#!/bin/bash
set -e
# This script will configure a device for use within a Kerberos realm.
#
# A whitespace-separated list of all Kerberos servers in the realm is required
# as an argument. The realm name is derived from the DNS domain name, unless the
# REALM variable is set.
#
# The PRIMARY_PW variable must be set - this is used for the Kerberos primary
# password
#
# Unless the ROLE variable is explicitly set, the host's role will be determined
# by the hostname's presence in the provided Kerberos server list. Possible
# values are:
#     PRIMARY
#         Primary Kerberos KDC & admin server. Installs Kerberos server packages
#         and configures for use as the primary.
#
#     SECONDARY
#         Secondary Kerberos KDC. Installs Kerberos server packages and
#         configures for use as the secondary.
#
#     CLIENT
#         Kerberos client. Installs and configures Kerberos client packages.
#
# Direction from:
# -   https://help.ubuntu.com/lts/serverguide/kerberos.html
# -   https://web.mit.edu/kerberos/krb5-1.12/doc/admin/install.html
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/util.sh"

main () {
  # Not-so-secure secrets
  local -r ADMIN_USER="${ADMIN_USER:-vagrant/admin}"
  local -r ADMIN_PW="${ADMIN_PW:-vagrant}"
  local -r PRIMARY_PW="${PRIMARY_PW:-not_a_secure_password}"
  # Hostname of host running script
  local -r HOST="${HOST:-$(hostname --fqdn)}"
  # Name of Kerberos realm. Typically all-uppercase version of domain.
  local -r REALM="${REALM:-$(dnsdomainname | tr '[:lower:]' '[:upper:]')}"
  echo "Configuring for realm ${REALM}"
  # List of all Kerberos servers. First is the admin server, all others are
  # secondary.
  local -r SERVERS=("$@")

  # If the host's role has not been explicitly specified, determine from
  # hostname.
  if [[ ! ("${ROLE}" && "PRIMARY SECONDARY CLIENT" == *${ROLE}*) ]]; then
    if [[ "${SERVERS[0]}" == "${HOST}" ]]; then
      local -r ROLE="PRIMARY"
    elif [[ "${SERVERS[*]}" == *${HOST}* ]]; then
      local -r ROLE="SECONDARY"
    else
      local -r ROLE="CLIENT"
    fi
    echo "Identified host as role ${ROLE}"
  fi

  # Do the thing
  apt-get update
  echo "Configuring as ${ROLE}"
  krb_install_config "${REALM}" "${SERVERS[@]}"
  case "${ROLE}" in
    "PRIMARY")
      krb_config_server "${SERVERS[@]}"
      krb_create_realm "${REALM}" "${PRIMARY_PW}"
      kadmin.local -q "addprinc -pw ${ADMIN_PW} ${ADMIN_USER}"
      ;;
    "SECONDARY")
      krb_config_server "${SERVERS[@]}"
      ;;
    "CLIENT")
      krb_config_client
      ;;
  esac
  echo "Configured!"
}

# Install Kerberos for a client
krb_config_client () {
  # libpam-krb5 libpam-ccreds auth-client-config also recommended
  DEBIAN_FRONTEND="noninteractive" apt-get install -y krb5-user
}

# Create Kerberos Realm
# First argument is realm name, second is used as primary password
krb_create_realm () {
  local -r REALM="$1"; local -r PRIMARY_PW="$2"

  kdb5_util create -r "${REALM}" -P "${PRIMARY_PW}" -s
  systemctl start krb5-kdc || true
  systemctl start krb5-admin-server || true
  if [ ! -r /etc/krb5kdc/kadm5.acl ] ; then
    cat <<EOF >/etc/krb5kdc/kadm5.acl
# This file is the access control list for krb5 administration.
# When this file is edited run systemctl restart krb5-admin-server to activate
# One common way to set up Kerberos administration is to allow any principal
# ending in /admin  is given full administrative rights.
# To enable this, uncomment the following line:
*/admin *
EOF
  fi

}

# Install Kerberos for a server
# Arguments are a whitespace-separated list of Kerberos servers
krb_config_server () {
  local -r _SERVERS=("$@")
  util_set_selection "krb5-admin-server krb5-admin-server/newrealm note"
  util_set_selection "krb5-kdc krb5-kdc/purge_data_too boolean false"
  util_set_selection "krb5-kdc krb5-kdc/debconf boolean true"

  DEBIAN_FRONTEND="noninteractive" apt-get install -y \
  krb5-admin-server \
  krb5-kdc \
  krb5-kpropd

  # Create a list of all KDCs in realm for kpropd
  printf "%s\n" "${_SERVERS[@]}" > /etc/krb5kdc/kpropd.acl
}

# Install Kerberos configuration package
# First argument is the realm, second argument is the Kerberos admin server,
# remaining are secondary servers
krb_install_config () {
  local -r KRB_CFG_FILE="/etc/krb5.conf"
  local -r REALM="$1"; shift; local -ar SERVERS=("$@")

  util_set_selection "krb5-config krb5-config/add_servers_realm string ${REALM}"
  util_set_selection "krb5-config krb5-config/admin_server string ${SERVERS[0]}"
  util_set_selection "krb5-config krb5-config/kerberos_servers string ${SERVERS[*]}"
  util_set_selection "krb5-config krb5-config/read_conf boolean true"
  util_set_selection "krb5-config krb5-config/default_realm string ${REALM}"
  util_set_selection "krb5-config krb5-config/add_servers boolean true"

  DEBIAN_FRONTEND="noninteractive" apt-get install -y krb5-config

  # Set up Kerberos config file
  cp "${SCRIPT_DIR}/files/etc_krb5.conf" "${KRB_CFG_FILE}"
  sed -i "s~#{ADMIN_SERVER}~${SERVERS[0]}~g" "${KRB_CFG_FILE}"
  sed -i "s~#{DNSDOMAIN}~$(dnsdomainname)~g" "${KRB_CFG_FILE}"
  sed -i "s~#{KDC_LIST}~$(printf '\t\tkdc = %s\n' "${SERVERS[@]}")~g" "${KRB_CFG_FILE}"
  sed -i "s~#{REALM}~${REALM}~g" "${KRB_CFG_FILE}"
}

main "$@"
