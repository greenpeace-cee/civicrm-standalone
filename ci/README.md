# CI for the GP standalone project

Everything in this directory is also usable locally; the GitHub workflow in
`.github/workflows/build.yml` only glues it together on a runner.

## civibuild type `standalone-gp`

`ci/civibuild/standalone-gp` is a [civibuild](https://docs.civicrm.org/dev/en/latest/tools/civibuild/)
build type that builds this project the way it is defined here: dependencies
exactly as pinned in `composer.lock` (core, patches, extensions), then
`post-install.sh`. Unlike buildkit's `standalone-composer` type it does not
clone upstream `civicrm/civicrm-standalone`, and `--civi-ver` has no effect
because the core version comes from the lock file.

From a checkout of this repository:

```sh
CIVIBUILD_PATH="$PWD/ci/civibuild" GP_STANDALONE_SRC="$PWD" \
  civibuild create mysite --type standalone-gp --url http://mysite.localhost:8080
```

`GP_STANDALONE_SRC` is cloned, so only committed changes are built. Without it,
the type clones `greenpeace-cee/civicrm-standalone` at `--cms-ver` (default
`gpat`; `{owner}/{branch}` works too).

## Smoke checks

`ci/smoke.sh` checks that a built site is usable: the login page answers,
schema and code versions match with no pending extension upgrades, every
extension in `ext/` is installed, system checks report no errors beyond the
expected ones for a disposable site, and a login over HTTP followed by a page
that needs a session works. Run it from the built site:

```sh
cd ~/buildkit/build/mysite/web && DEMO_USER=demo DEMO_PASS=demo ./ci/smoke.sh
```

## GitHub Actions

`build.yml` runs on pull requests, pushes to `gpat` and manually. It installs
PHP, Apache and buildkit on the runner (the same recipe as
[greenpeace-cee/civi-ci](https://github.com/greenpeace-cee/civi-ci)), builds
the checked-out commit with `standalone-gp` and runs the smoke checks. Logs are
uploaded as an artifact when it fails.

Private repositories referenced from `composer.json` (currently the core and
packages forks and `iap_auth`) need the `COMPOSER_GITHUB_TOKEN` secret: a token
with read access to those repositories. The workflow configures git to use it
for all `github.com` URLs, including the `git@github.com:` SSH URLs, so the
runner needs no SSH key and `composer.json` stays as it is.
