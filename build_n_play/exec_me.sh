#!/usr/bin/env bash

# This script builds the Docker image for LiteBox,
# runs a container from that image, and then
# opens an interactive shell inside the container.
# After exiting the shell, it stops and removes the container.

REPO_OWNER="microsoft"
REPO_NAME="litebox"
EXPECTED_COMMIT="380364d63202e1d4d119641f5b07e7a43a72c29b" # Replace with the actual expected commit hash
NAME_IMAGE="$REPO_NAME:latest"
NAME_CONTAINER="$REPO_NAME-container"

# Preserve the current directory and change to the parent directory of the script
DIR_SCRIPT="$(pwd)"
cd ..

# Clone the repo if it doesn't exist
if [ ! -d "$REPO_NAME" ]; then
    git clone https://github.com/$REPO_OWNER/$REPO_NAME.git

    # Check if the latest commit is what this script expects
    ACTUAL_COMMIT=$(git -C "$REPO_NAME" rev-parse HEAD)
    if [ "$ACTUAL_COMMIT" != "$EXPECTED_COMMIT" ]; then
        echo "[!] Warning: The latest commit in the $REPO_NAME repository is $ACTUAL_COMMIT, which does not match the expected commit $EXPECTED_COMMIT."
        echo "[*] Resetting the repository to the expected commit..."
        git -C "$REPO_NAME" reset --hard "$EXPECTED_COMMIT"
    fi
fi

# Patch litebox_runner_linux_userland/tests/efault.c to include stdlib.h for abort() function
# Note: This is a temporary workaround for the build failure due to the missing abort() declaration.
FILE_EFAULT="$REPO_NAME/litebox_runner_linux_userland/tests/efault.c"
if ! grep -q "#include <stdlib.h>" "$FILE_EFAULT"; then
    echo "[!] Warning: $FILE_EFAULT does not include stdlib.h, which may cause build failures due to missing abort() declaration."
    echo "[+] Patching $FILE_EFAULT to include stdlib.h..."
    { printf '#include <stdlib.h>\n' | cat - "$FILE_EFAULT" > temp && mv temp "$FILE_EFAULT"; }
fi

# Build the image if it doesn't exist
# Note: --cap-add=NET_ADMIN is required to run the container with network capabilities,
#   which may be necessary for certain applications or
#   services that require network access or manipulation.
#   i.e., the container needs TUN device for LiteBox.
if [ ! "$(docker image ls -q "$NAME_IMAGE")" ]; then
    docker build --platform linux/amd64 -t "$NAME_IMAGE" -f "$DIR_SCRIPT/Dockerfile" .
fi

# If the container exists...
if [ "$(docker ps -aq -f name="$NAME_CONTAINER")" ]; then
  echo container $NAME_CONTAINER exists
  # and if running...
  if [ "$(docker ps -q -f name="$NAME_CONTAINER")" ]; then
    echo container $NAME_CONTAINER running
    # Stop the container
    docker stop "$NAME_CONTAINER"
  fi
  # Remove the container
  docker rm "$NAME_CONTAINER"
fi

# Run the container
docker run  --cap-add=NET_ADMIN --device /dev/net/tun:/dev/net/tun --detach --name "$NAME_CONTAINER" "$NAME_IMAGE"

# Exec into the container
docker exec -it "$NAME_CONTAINER" /bin/bash

# Stop and remove the container after use
echo "[-] Stopping and removing container $NAME_CONTAINER..."
docker stop "$NAME_CONTAINER"
docker rm "$NAME_CONTAINER"

# Return to the original directory
cd "$DIR_SCRIPT"