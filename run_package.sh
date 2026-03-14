#!/usr/bin/env bash

# This script executes a Linux binary from previously generated package
# using litebox_runner_linux_userland, which is a part of LiteBox.

usage() {
    cat <<EOF >&2
Usage: $(basename "$0") <binary_path> arguments...

  <binary_path>   The path to the binary file to be executed.
  arguments...    Arguments to pass to the executed binary.

Example:
  $ $(basename "$0") /usr/bin/date
EOF
    exit 1
}

# Check if the number of arguments is larger or equal to 1
if [[ $# -lt 1 ]]; then          # less than 1?
    usage                        # show help and quit
fi

BINARY_PATH="$1"
shift # Remove the first argument (binary path) from the list of arguments, so that $@ now contains only the arguments to be passed to the executed binary.

# Check if this is running on Linux, otherwise exit
if [[ "$(uname -s)" != "Linux" ]]; then
    echo "[X] Error: This script is intended to be run on Linux, as it uses litebox_runner_linux_userland which is designed for Linux Userland. Exiting."
    exit 1
fi

# Create a package name using the binary path, e.g., /usr/bin/date -> litebox-_usr_bin_date.tar
PACKAGE_NAME="litebox-$(echo "$BINARY_PATH" | tr '/' '_').tar"

# Check if the package exists, otherwise exit
if [ ! -e "$PACKAGE_NAME" ]; then
    echo "[X] Error: Package $PACKAGE_NAME does not exist. Please generate the package using gen_package.sh before running this script."
    exit 1
fi

# Check if litebox_runner_linux_userland exists, otherwise exit
if [ ! -e "litebox_runner_linux_userland" ]; then
    echo "[X] Error: litebox_runner_linux_userland does not exist. Executing the gen_package.sh script should also generate the runner."
    exit 1
fi

# Run the binary using litebox_runner_linux_userland
./litebox_runner_linux_userland --unstable --interception-backend rewriter --initial-files "$PACKAGE_NAME" --program-from-tar "$BINARY_PATH" "$@"