#!/bin/bash
## extract semver from it
semver() {
  # extract semver with prerelease
  # The expression is working for us and tested.
  # However Semver recommends https://semver.org/spec/v2.0.0.html#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
  echo $1 | grep --extended-regexp --regexp='([0-9]+)(\.[0-9]+)?(\.[0-9]+)?(-[0-9A-Za-z\.]+)?' --only-matching
}


GREEN='\033[0;32m'
NC='\033[0m' # No Color
## Updates the Chart.yaml(ARG_1) appVersion to the version in ARG_2
## (chart) version is auto incremented
inc_package() {
  local CURRENT_VERSION=$(semver "$1")
  local LAST_VERSION=$(semver "$2")
  # Validate Input
  if [ "$CURRENT_VERSION" == "" ]; then
    echo "Could not find current version"
    exit 1
  fi

  if [ "$LAST_VERSION" == "" ]; then
    echo "Could not find last version"
    exit 1
  fi
  # Check for actual change
  if [ "$CURRENT_VERSION" == "$LAST_VERSION" ]; then
    # nothing changed
    echo "Nothing to do for $CURRENT_VERSION"
    exit 0
  fi

  echo -e "${GREEN}Upgrading Repo${NC} ${LAST_VERSION} to ${CURRENT_VERSION}"
  if ! (git tag -a "$CURRENT_VERSION" -m "release Version ${CURRENT_VERSION}"); then
    exit 1
  fi
  if ! (git push origin "$CURRENT_VERSION"); then
    exit 1
  fi
  exit 0
}

CURRENT_VERSION="$1"
TAG="$(git describe --tags --abbrev=0 $(git rev-list --tags='^[^0-9]*(([0-9]+\.)*[0-9]+).*' --max-count=1))"
if ! (inc_package "$CURRENT_VERSION" "$TAG"); then
  exit 1
fi

exit 0
