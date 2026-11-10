#!/usr/bin/env bash

## download.sh -- Put the GP standalone project into $WEB_ROOT/web and install
## its composer dependencies from composer.lock.
##
## Source of the project:
##   GP_STANDALONE_SRC  Path of a local checkout (e.g. $GITHUB_WORKSPACE in CI).
##                      Its committed HEAD is cloned; uncommitted changes are
##                      not included.
##   CMS_VERSION        Otherwise: branch/tag of greenpeace-cee/civicrm-standalone
##                      (default: gpat). "{owner}/{branch}" is also accepted.
##
## Usage (from a checkout of this repository):
##   CIVIBUILD_PATH="$PWD/ci/civibuild" GP_STANDALONE_SRC="$PWD" \
##     civibuild create mysite --type standalone-gp --url http://mysite.localhost:8080

###############################################################################

[ -z "$CMS_VERSION" ] && CMS_VERSION=gpat

if [ -n "$GP_STANDALONE_SRC" ]; then
  echo "Cloning local checkout $GP_STANDALONE_SRC ($(git -C "$GP_STANDALONE_SRC" rev-parse --short HEAD))"
  git clone --quiet "$GP_STANDALONE_SRC" "$WEB_ROOT/web"
  ## Point origin at GitHub rather than the local path.
  git -C "$WEB_ROOT/web" remote set-url origin https://github.com/greenpeace-cee/civicrm-standalone.git
else
  git clone https://github.com/greenpeace-cee/civicrm-standalone.git "$WEB_ROOT/web"
  pushd "$WEB_ROOT/web" >> /dev/null
    git_checkout "$CMS_VERSION"
  popd >> /dev/null
fi

pushd "$WEB_ROOT/web" >> /dev/null
  amp datadir "./private" "./public" "./ext"

  ## Always install exactly what composer.lock says. Core version, patches and
  ## extensions are all defined there; --civi-ver is ignored for this type.
  composer install --no-interaction --no-progress

  composer civicrm:publish
popd >> /dev/null
