#!/bin/bash

# Ensure the script exits on errors
set -e

# Check for input arguments
if [ "$#" -ne 1 ]; then
  echo "Usage: ./move_up_stable_tag.sh <target-tag-without-v>"
  exit 1
fi

SOURCE_TAG="$1"
ALIAS_TAG="stable"

# List of images to retag
IMAGES=(
  "pglombardo/pwpush"
  "pglombardo/pwpush-worker"
  "pglombardo/pwpush-public-gateway"
)

for IMAGE in "${IMAGES[@]}"; do
  echo "Retrieving digests for ${IMAGE}:${SOURCE_TAG}..."

  # Use docker manifest inspect to parse platform-specific digests
  MANIFEST_JSON=$(docker manifest inspect "${IMAGE}:${SOURCE_TAG}")

  AMD64_DIGEST=$(echo "${MANIFEST_JSON}" | jq -r '.manifests[] | select(.platform.architecture == "amd64") | .digest')
  ARM64_DIGEST=$(echo "${MANIFEST_JSON}" | jq -r '.manifests[] | select(.platform.architecture == "arm64") | .digest')

  if [ -z "${AMD64_DIGEST}" ] || [ -z "${ARM64_DIGEST}" ]; then
    echo "Error: Could not retrieve digests for ${IMAGE}:${SOURCE_TAG}"
    exit 1
  fi

  echo "Creating manifest for ${IMAGE}:${ALIAS_TAG}..."
  docker manifest create "${IMAGE}:${ALIAS_TAG}" \
    --amend "${IMAGE}@${AMD64_DIGEST}" \
    --amend "${IMAGE}@${ARM64_DIGEST}"

  echo "Annotating platforms for ${IMAGE}:${ALIAS_TAG}..."
  docker manifest annotate "${IMAGE}:${ALIAS_TAG}" "${IMAGE}@${AMD64_DIGEST}" --arch amd64
  docker manifest annotate "${IMAGE}:${ALIAS_TAG}" "${IMAGE}@${ARM64_DIGEST}" --arch arm64

  echo "Pushing manifest for ${IMAGE}:${ALIAS_TAG}..."
  docker manifest push "${IMAGE}:${ALIAS_TAG}"
done

echo "All images have been tagged as '${ALIAS_TAG}' successfully."