#!/bin/bash

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# This runs the system tests. It expects the following things to exist:
#
# * "python3" available in PATH
# * "virtualenv" available in PATH
#
# To run this from the root of this repository, do this:
#
#     $ ./tests/systemtests/run_tests.sh
#
# Set ANTENNA_ENV to the env file to use. It can be the same one used
# for running Antenna. It needs to have the S3 information in it.
#
# Set POSTURL to the url to post to.
#
# Set NONGINX=1 if you're running against a local dev environment. This
# will skip tests that require nginx.

set -ex

VENV_DIR=/tmp/antenna-systemtests-venv/
if [ -z "${POSTURL}" ]; then
    # This is the posturl when running against a local dev environment
    export POSTURL="http://web:8000/submit"
fi
echo "POSTURL: ${POSTURL}"
if [ -z "${ANTENNA_ENV}" ]; then
    # This is the env file for running against a local dev environment
    export ANTENNA_ENV="dev.env"
fi
echo "ANTENNA_ENV: ${ANTENNA_ENV}"

cmd_required() {
    command -v "$1" > /dev/null 2>&1 || { echo >&2 "$1 required, but not on PATH. Exiting."; exit 1; }
}

echo "Setting up system tests."
# Verify ANTENNA_ENV is defined
if [ -z "${ANTENNA_ENV}" ]; then
    echo "Please the ANTENNA_ENV variable to the path of a .env file with configuration. Exiting."
    exit 1
fi

# Verify python3 and virtualenv exist
cmd_required python3
cmd_required virtualenv
echo "Required commands available."

# If venv exists, exit
if [ -d "${VENV_DIR}" ]; then
    echo "${VENV_DIR} exists. Please remove it and try again. Exiting."
    exit 1
fi

# Create virtualenv
virtualenv -p python3 "${VENV_DIR}"

# Activate virtualenv
source "${VENV_DIR}/bin/activate"

# Install requirements into virtualenv
pip install --no-cache-dir -r tests/systemtest/requirements.txt

echo "Running tests."
# Run tests--this  uses configuration in the environment--and send everything to
# stdout
py.test -vv tests/systemtest/ 2>&1
