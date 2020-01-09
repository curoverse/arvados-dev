#!/bin/bash
# Copyright (C) The Arvados Authors. All rights reserved.
#
# SPDX-License-Identifier: AGPL-3.0

# This script publishes packages from our dev repo to the prod repo (#11572)
# Parameters: list of packages, space separated, to move from *-testing to *
# under /var/lib/freight/apt/ in host public.curoverse.com

set -x

APT_REPO_SERVER="apt.arvados.org"
RPM_REPO_SERVER="rpm.arvados.org"

DEBUG=1
SSH_PORT=2222
ECODE=0

# Convert package list into a regex for publising
# Make sure the variables are set or provide an example of how to use them
if [ -z "${PACKAGES_TO_PUBLISH}" ]; then
  echo "You must provide a list of packages to publish, as obtained with https://dev.arvados.org/projects/ops/wiki/Updating_clusters#Gathering-package-versions."
  exit 254
fi
if [ -z "${LSB_DISTRIB_CODENAMES}" ]; then
  echo "You must provide a space-separated list of LSB distribution codenames to which you want to publish to, ie."
  echo "* Debian: jessie, xenial, stretch, etc."
  echo "* Centos: centos7 (the only one currently supported.)"
  exit 255
fi

# Sanitize the vars in a way suitable to be used by the remote 'publish_packages.sh' script
# Just to make copying a single line, and not having to loop over it
PACKAGES_LIST=$(echo ${PACKAGES_TO_PUBLISH} | sed 's/versions://g; s/\([a-z-]*\):[[:blank:]]*\([0-9.-]*\)/\1*\2*,/g; s/[[:blank:]]//g; s/,$//g;')

DISTROS=$(echo "${LSB_DISTRIB_CODENAMES}"|sed s/[[:space:]]/,/g |tr '[:upper:]' '[:lower:]')

if ( echo ${LSB_DISTRIB_CODENAMES} |grep -q centos ); then
  REPO_SERVER=${RPM_REPO_SERVER}
else
  REPO_SERVER=${APT_REPO_SERVER}
fi

REMOTE_CMD="/usr/local/bin/testing_to_stable_publish_packages.sh --distros ${DISTROS} --packages ${PACKAGES_LIST}"

# Now we execute it remotely
TMP_FILE=`mktemp`

ssh -t \
    -l jenkinsapt \
    -p $SSH_PORT \
    -o "StrictHostKeyChecking no" \
    -o "ConnectTimeout 5" \
    ${REPO_SERVER} \
    "${REMOTE_CMD}" | tee ${TMP_FILE}
ECODE=$?

grep -q "FAILED TO PUBLISH" ${TMP_FILE}
if [ $? -eq 0 ]; then
  ECODE=1
fi
rm -f ${TMP_FILE}
exit ${ECODE}
