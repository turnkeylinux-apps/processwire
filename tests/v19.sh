#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
app_password=${TKL_TEST_APP_PASS:?TKL_TEST_APP_PASS is required}
db_password=${TKL_TEST_DB_PASS:?TKL_TEST_DB_PASS is required}
base=https://127.0.0.1
admin=$base/admin/
cookie=/tmp/tkl-processwire-cookie.$$
page=/tmp/tkl-processwire-page.$$
headers=/tmp/tkl-processwire-headers.$$
policy=/tmp/tkl-processwire-policy.$$

report_error() {
    printf 'test_failure line=%s status=%s command=%q\n' \
        "$1" "$2" "$3" >&2
    exit "$2"
}
trap 'report_error "$LINENO" "$?" "$BASH_COMMAND"' ERR

cleanup() {
    rm -f -- "$cookie" "$page" "$headers" "$policy"
}
trap cleanup EXIT

systemctl --quiet is-active apache2.service mariadb.service postfix.service \
    cron.service multi-user.target
systemctl --quiet is-enabled apache2.service mariadb.service postfix.service \
    cron.service
apache2ctl -t
apache2ctl -M 2>/dev/null | grep -q ' rewrite_module '
grep -Fxq 'VERSION_CODENAME=trixie' /etc/os-release
grep -Eq '^turnkey-processwire-19\.0' /etc/turnkey_version

# shellcheck disable=SC1091
. /usr/local/share/processwire-release
test "$PROCESSWIRE_VERSION" = 3.0.258
test "$PROCESSWIRE_COMMIT" = 6b28a805c07d3b0509b53ce6632c03834fe38964
test "$PROCESSWIRE_SOURCE_SHA256" = \
    c073b4c44dcce711883cfa73b2d5b079f3547c9d810ab88f4ca657bb3d53adaf
test "$PROCESSWIRE_PROFILE_COMMIT" = \
    4e6cfd1f16c6aa926effaebd6bab25a44367d2bd
test "$PROCESSWIRE_PROFILE_SHA256" = \
    99b850c2d3db949e75ca014cd85cca66d35dfab2bcca415bf702ecd567e6733f

installed=$(php -r '
require $argv[1];
echo ProcessWire\ProcessWire::versionMajor, ".",
     ProcessWire\ProcessWire::versionMinor, ".",
     ProcessWire\ProcessWire::versionRevision;
' /var/www/processwire/wire/core/ProcessWire.php)
test "$installed" = "$PROCESSWIRE_VERSION"

php_version=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
test "$php_version" = 8.4
for module in curl gd mysqli pdo_mysql zip; do
    php -m | grep -Fxiq "$module"
done
apache_version=$(dpkg-query -W -f='${Version}' apache2)
mariadb_version=$(dpkg-query -W -f='${Version}' mariadb-server)

curl --insecure --fail --silent --show-error "$base/" >"$page"
grep -Fq 'What is ProcessWire?' "$page"
curl --insecure --fail --silent --show-error \
    --cookie-jar "$cookie" "$admin" >"$page"
grep -Fq 'ProcessWire' "$page"
readarray -t csrf < <(python3 - "$page" <<'PYTHON'
from html.parser import HTMLParser
import sys

class Inputs(HTMLParser):
    def __init__(self):
        super().__init__()
        self.token = None

    def handle_starttag(self, tag, attrs):
        if tag != "input":
            return
        item = dict(attrs)
        if "_post_token" in item.get("class", "").split():
            self.token = (item.get("name", ""), item.get("value", ""))

parser = Inputs()
parser.feed(open(sys.argv[1], encoding="utf-8").read())
assert parser.token and all(parser.token), "ProcessWire login CSRF token missing"
print(parser.token[0])
print(parser.token[1])
PYTHON
)
curl --insecure --silent --show-error \
    --cookie "$cookie" --cookie-jar "$cookie" \
    --data-urlencode "${csrf[0]}=${csrf[1]}" \
    --data-urlencode 'login_name=admin' \
    --data-urlencode "login_pass=$app_password" \
    --data-urlencode 'login_submit=Login' \
    --dump-header "$headers" --output "$page" "$admin"
grep -Eq '^HTTP/.* 30[12378]' "$headers"
curl --insecure --fail --silent --show-error --location \
    --cookie "$cookie" --cookie-jar "$cookie" "$admin" >"$page"
grep -Fq 'ProcessWire' "$page"
grep -Eqi 'Pages|Setup|Modules' "$page"
! grep -Fq 'login_name' "$page"

page_name="tkl-v19-$RANDOM-$$"
page_title="TurnKey v19 ProcessWire page $$"
page_body="ProcessWire page content round trip $$"
page_id=$(runuser -u www-data -- php \
    /run/tkl-v19-tests/tests/fixtures/create-page.php \
    "$page_name" "$page_title" "$page_body")
[[ $page_id =~ ^[1-9][0-9]*$ ]]
curl --insecure --fail --silent --show-error \
    "$base/$page_name/" >"$page"
grep -Fq "$page_title" "$page"
grep -Fq "$page_body" "$page"
test "$(mariadb --batch --skip-column-names --user=root \
    --password="$db_password" processwire --execute \
    "SELECT id FROM pages WHERE name='$page_name'")" = "$page_id"
mariadb --batch --skip-column-names --user=root \
    --password="$db_password" processwire --execute \
    "SELECT data FROM field_title WHERE pages_id=$page_id" | grep -Fxq "$page_title"
mariadb --batch --skip-column-names --user=root \
    --password="$db_password" processwire --execute \
    "SELECT data FROM field_body WHERE pages_id=$page_id" | grep -Fq "$page_body"
systemctl restart mariadb.service apache2.service
curl --insecure --fail --silent --show-error \
    "$base/$page_name/" >"$page"
grep -Fq "$page_body" "$page"

test "$(mariadb --batch --skip-column-names --user=root \
    --password="$db_password" processwire --execute \
    "SELECT data FROM pages JOIN field_email ON pages.id=field_email.pages_id WHERE pages.name='admin'")" = \
    admin@example.invalid

curl --insecure --fail --silent --show-error \
    https://127.0.0.1:12322/ | grep -qi Adminer
curl --insecure --fail --silent --show-error \
    https://127.0.0.1:12321/ >/dev/null
ss -ltn | grep -Eq '127\.0\.0\.1:25[[:space:]]'

update_result=$(processwire-update --check)
grep -Fq "installed=$installed" <<<"$update_result"
grep -Fq 'channel=official-stable' <<<"$update_result"
latest=$(sed -n 's/.* latest=\([^ ]*\).*/\1/p' <<<"$update_result")
[[ $latest =~ ^3\.0\.[0-9]+$ ]]
test "$(printf '%s\n%s\n' "$installed" "$latest" | sort -V | tail -n 1)" = \
    "$latest"

before="$apache_version|$mariadb_version"
apt-get update >/dev/null
for package in php apache2 mariadb-server; do
    apt-cache policy "$package" >"$policy"
    candidate=$(awk '/Candidate:/ {print $2}' "$policy")
    test -n "$candidate"
    test "$candidate" != '(none)'
    grep -Eq 'trixie|deb13' "$policy"
done
after="$(dpkg-query -W -f='${Version}' apache2)|$(dpkg-query -W -f='${Version}' mariadb-server)"
test "$after" = "$before"
grep -Rqs '^Suites: trixie' /etc/apt/sources.list.d
if grep -Rqi bookworm /etc/apt/sources.list.d; then
    exit 1
fi

cat >"$result" <<EOF
package_source=Official ProcessWire $PROCESSWIRE_VERSION archive at commit $PROCESSWIRE_COMMIT and official beginner profile at commit $PROCESSWIRE_PROFILE_COMMIT; PHP, Apache, MariaDB, Postfix and supporting extensions from Debian Trixie
installed_version=ProcessWire $installed; PHP $php_version; apache2 $apache_version; mariadb-server $mariadb_version
runtime_checks=normal init; HTTPS site; firstboot administrator HTTP login; ProcessWire API page create with public HTTPS and MariaDB readback after service restart; Adminer and Webmin endpoints; local Postfix listener
updater_command=processwire-update --check; apt-get update and apt-cache policy
updater_result=official stable ProcessWire channel reported $latest with installed $installed unchanged; signed Trixie metadata refreshed with installed packages unchanged
updater_channel=official ProcessWire stable releases through Packagist metadata and processwire/processwire commits; signed Debian and TurnKey Trixie repositories
integrity_evidence=official ProcessWire commit $PROCESSWIRE_COMMIT archive matched SHA-256 $PROCESSWIRE_SOURCE_SHA256; official site-beginner commit $PROCESSWIRE_PROFILE_COMMIT archive matched SHA-256 $PROCESSWIRE_PROFILE_SHA256; updater validates official Packagist and GitHub provenance and requires a caller-supplied archive SHA-256; APT accepted signed Trixie metadata
EOF
