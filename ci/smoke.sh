#!/usr/bin/env bash
## smoke.sh -- Sanity checks for a freshly built GP standalone site.
##
## Run from anywhere; it operates on the project this file belongs to (the
## directory holding composer.json), which must be a site created with the
## standalone-gp civibuild type (or any installed site with `cv` working).
## Exits non-zero if any check fails.
##
## Environment: DEMO_USER / DEMO_PASS (default demo/demo) for the login check.
set -u
cd "$(dirname "$0")/.." || exit 1
fail=0
ok()  { echo "ok    $*"; }
bad() { echo "FAIL  $*"; fail=1; }

## 1. Login page answers over HTTP.
url=$(cv url civicrm/login | tr -d '"')
status=$(curl -sS -o /dev/null -w '%{http_code}' "$url" || true)
if [ "$status" = 200 ]; then ok "GET $url -> $status"; else bad "GET $url -> $status"; fi

## 2. Database schema matches the code (no pending core or extension upgrades).
code=$(cv ev 'return CRM_Utils_System::version();' | tr -d '"')
db=$(cv ev 'return CRM_Core_BAO_Domain::version();' | tr -d '"')
if [ "$code" = "$db" ]; then ok "core version $code, database $db"; else bad "core version $code but database $db"; fi
pending=$(cv ev 'return CRM_Extension_Upgrades::hasPending();')
if [ "$pending" = false ]; then ok "no pending extension upgrades"; else bad "pending extension upgrades (hasPending=$pending)"; fi

## 3. Every extension shipped in ext/ is installed.
not_installed=$(cv ext:list --local --out=json \
  | php -r '$x = json_decode(stream_get_contents(STDIN), TRUE); $root = getcwd() . "/ext/";
      foreach ($x as $e) { if (strpos($e["path"] ?? "", $root) === 0 && $e["status"] !== "installed") { echo $e["key"], " (", $e["status"], ")\n"; } }')
if [ -z "$not_installed" ]; then ok "all extensions in ext/ are installed"; else bad "extensions in ext/ not installed:"$'\n'"$not_installed"; fi

## 4. System checks: nothing at error level or above, except for checks that
##    are expected to fire on a disposable site (debug mode, no mail, no cron,
##    core and extensions not being the latest release).
expected='["checkDebug","checkOutboundMail","checkDefaultMailbox","checkLastCron","checkVersion_patch","checkVersion_upgrade","checkExtensionsUpdates"]'
problems=$(cv api4 System.check "{\"where\":[[\"severity_id\",\">=\",4],[\"name\",\"NOT IN\",$expected]],\"select\":[\"name\",\"severity\",\"title\"]}" --out=json \
  | php -r '$x = json_decode(stream_get_contents(STDIN), TRUE); foreach ($x as $c) { echo $c["name"], " [", $c["severity"], "] ", $c["title"], "\n"; }')
if [ -z "$problems" ]; then ok "no unexpected system-check errors"; else bad "system checks:"$'\n'"$problems"; fi

## 5. Log in over HTTP (standaloneusers User.login) and load a page that needs
##    a session.
base=${url%/civicrm/login}
user=${DEMO_USER:-demo}
jar=$(mktemp)
login=$(curl -sS -c "$jar" -b "$jar" -X POST "$base/civicrm/ajax/api4/User/login" \
  -d "params={\"identifier\":\"$user\",\"password\":\"${DEMO_PASS:-demo}\"}" || true)
status=$(curl -sS -b "$jar" -o /dev/null -w '%{http_code}' "$base/civicrm/dashboard" || true)
rm -f "$jar"
if echo "$login" | grep -q '"url"' && [ "$status" = 200 ]; then
  ok "login as $user, GET /civicrm/dashboard -> $status"
else
  bad "login as $user: $(echo "$login" | cut -c1-120); GET /civicrm/dashboard -> $status"
fi

exit $fail
