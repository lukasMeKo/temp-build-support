#!/bin/sh
## extract semver from it
semver() {
  # extract semver with prerelease
  # The expression is working for us and tested.
  # However Semver recommends https://semver.org/spec/v2.0.0.html#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
  echo $1 | grep --extended-regexp --regexp='([0-9]+)(\.[0-9]+)?(\.[0-9]+)?(-[0-9A-Za-z\.]+)?' --only-matching
}

appver() {
  echo "$(sed -n "s/\(^appVersion:[[:blank:]]*\)\(\"\)\([[:graph:]]\+\)\(\"[[:blank:]]*\r\?\)/\3/p" \
    "$1")"
}

version() {
  echo "$(sed -n "s/\(^version:[[:blank:]]*\)\([[:graph:]]\+\)\([[:blank:]]*\r\?\)/\2/p" \
    "$1")"
}

check_release_version() {
  git fetch
  if echo `git branch -r` | grep -q "$1"; then
    local CURRENT_VERSION_SPLIT=(${1//\-/ })
    local EXISTING_RELEASES=`git branch -r | grep "${CURRENT_VERSION_SPLIT[0]}" | tr '\n' ',' | sed 's/,$//'`
    echo -e "${RED}Please use another release version. The following corresponding releases already exist: ${EXISTING_RELEASES}${NC}"
    return 1
  fi
  return 0
}

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
## Updates the Chart.yaml(ARG_1) appVersion to the version in ARG_2
## (chart) version is auto incremented
inc_chart() {
  local CURRENT_VERSION="$1"
  local TARGET_PATH="$2"
  # Validate Input
  if [ "$CURRENT_VERSION" == "" ] || [ "$TARGET_PATH" == "" ]; then
    echo "Could not find current version"
    exit 1
  fi
  local APP_VERSION="$(appver "$TARGET_PATH")"
  if [ "$APP_VERSION" == "" ]; then
    echo "Could not find current appVersion in HELM Chart"
    exit 1
  fi
  # Check for actual change
  if [ "$(semver "$CURRENT_VERSION")" == "$(semver "$APP_VERSION")" ]; then
    # nothing changed
    echo "Nothing to do for $TARGET_PATH"
    exit 0
  fi
  # Check for already existing release
  check_release_version "$CURRENT_VERSION"
  if [[ $? -eq 1 ]]; then
      exit 1
  fi

  echo -e "${GREEN}Upgrading${NC} $TARGET_PATH to ${CURRENT_VERSION}"
  NEW_APP_VERSION="\"$(semver "$CURRENT_VERSION")\""
  # Read and Increment CHART VERSION fields
  CHART_VERSION="$(version "$TARGET_PATH")"
  # I(nter)F(ield)S(eparator) where dot is the separator
  IFS=. read -r major minor patch <<<"$(semver "$CHART_VERSION")"
  ((patch++))
  echo "ChartVer: $CHART_VERSION"
  NEW_CHART_VERSION="${major}.${minor}.${patch}"
  # Update appVersion
#  echo "appV: $NEW_APP_VERSION"
  sed -i "s/\(^version:[[:blank:]]*\)\([[:graph:]]\+\)/\1${NEW_CHART_VERSION}/" $TARGET_PATH
  # Update chart version
  sed -i "s/\(^appVersion:[[:blank:]]*\)\([[:graph:]]\+\)/\1${NEW_APP_VERSION}/" $TARGET_PATH
  # add release changes to changelog/api-changes/changelog-0.x.md 
  ./changelog.sh -n
  exit 0
}

TAG="$1"
PATH_TO_CHART="$2"
if ! (inc_chart "$TAG" "$PATH_TO_CHART"); then
  exit 1
fi

git add "$PATH_TO_CHART"
exit 0
