#!/bin/bash
set -e
# This script will configure a device to be a Kerberized NFS server
#
# It is assumed that the Kerberos environment has already been set up.
readonly SCRIPT_DIR=$(cd `dirname $0` && pwd)
source "${SCRIPT_DIR}/util.sh"

readonly ADMIN="${ADMIN:-vagrant/admin}"
readonly ADMIN_P="${ADMIN_P:-vagrant}"

main () {
  # Hostname of host running script
  local -r HOST="${HOST:-$(hostname --fqdn)}"
  # Name of Kerberos realm. Typically all-uppercase version of domain.
  local -r REALM="${REALM:-$(dnsdomainname | tr [:lower:] [:upper:])}"
  echo "Configuring for realm ${REALM}"
  # NFS server hostname
  local -r SERVER="$1"

  # If the host's role has not been explicitly specified, determine from
  # hostname.
  if [[ ! ("${ROLE}" && "PRIMARY CLIENT" == *${ROLE}*) ]]; then
    if [[ "${SERVER}" == ${HOST}* ]]; then
      local -r ROLE="PRIMARY"
    else
      local -r ROLE="CLIENT"
    fi
    echo "Identified host as role ${ROLE}"
  fi

  # Do the thing
  apt-get update
  echo "Configuring as ${ROLE}"
  nfs_shared_config "${REALM}" "${HOST}"
  case "${ROLE}" in
    "PRIMARY")
      nfs_config_server "/srv/nfs"
      ;;
    "CLIENT")
      nfs_config_client
      ;;
  esac
  echo "Configured!"
}

# Install nfs-common & add Kerberos principals
# First arguiment is the realm, second argument is the host's hostname.
# ADMIN and ADMIN_P must be set with an admin principal's credentials
nfs_shared_config () {
  local -r HOSTSTR="$2@$1"

  DEBIAN_FRONTEND=noninteractive apt-get install -y nfs-common

  # Add NFS & host principal, create keytab (server + client)
  kadmin -p "${ADMIN}" -w "${ADMIN_P}" -q "addprinc -randkey host/${HOSTSTR}"
  kadmin -p "${ADMIN}" -w "${ADMIN_P}" -q "addprinc -randkey nfs/${HOSTSTR}"
  kadmin -p "${ADMIN}" -w "${ADMIN_P}" -q "ktadd host/${HOSTSTR} nfs/${HOSTSTR}"
}

# Install & configure NFS server packages. Create share directory
# First argument is directory to share
nfs_config_server () {
  local -r SHAREDIR="$1"
  local -r NFS_CFG_FILE="/etc/default/nfs-kernel-server"

  DEBIAN_FRONTEND=noninteractive apt-get install -y nfs-kernel-server

  # Configure NFS server
  util_update_on_key "${NFS_CFG_FILE}" NEED_IDMAPD 'NEED_IDMAPD="yes"'
  util_update_on_key "${NFS_CFG_FILE}" NEED_STATD 'NEED_STATD="no"'
  util_update_on_key "${NFS_CFG_FILE}" NEED_SVCGSSD 'NEED_SVCGSSD="yes"'
  util_update_on_key "${NFS_CFG_FILE}" RPCMOUNTDOPTS 'RPCMOUNTDOPTS="-g -N 2 -N 3"'
  util_update_on_key "${NFS_CFG_FILE}" RPCNFSDOPTS 'RPCNFSDOPTS="-N 2 -N 3"'
  systemctl restart nfs-kernel-server

  # Create & export share (server)
  mkdir -p "${SHAREDIR}"
  # Possibly needed to work for now - will remove once we have an LDAP server
  chown nobody "${SHAREDIR}"
  chgrp nogroup "${SHAREDIR}"
  echo "${SHAREDIR} *(rw,sync,fsid=0,crossmnt,no_subtree_check,sec=krb5i)" > /etc/exports
  exportfs -rva
}

# Configure NFS client
nfs_config_client () {
  local -r NFS_CFG_FILE="/etc/default/nfs-common"

  # Configure NFS client
  util_update_on_key "${NFS_CFG_FILE}" NEED_GSSD 'NEED_GSSD="yes"'
  util_update_on_key "${NFS_CFG_FILE}" NEED_IDMAPD 'NEED_IDMAPD="yes"'

  # rpc.gssd isn't available immediately after. Not sure why, but there's no
  # issue after restarting it.
  systemctl restart rpc-gssd
}

main $@
