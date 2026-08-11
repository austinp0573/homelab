#!/bin/sh
# Patch Vaultwarden web-vault app/main.<hash>.js for Send access pages:
#   - Always save Sends with hideEmail=true (real email hidden from API)
#   - Never show the "sender hid their email" warning banner
#   - Show a fully custom subtitle message (no i18n / no placeholders)
#
# Workflow:
#   1. docker cp <container>:/web-vault/app/main.<hash>.js .
#   2. VAULTWARDEN_SEND_SUBTITLE='Your custom message here' ./patch-send-main.sh main.<hash>.js
#   3. docker cp main.<hash>.js <container>:/web-vault/app/main.<hash>.js
#
# Re-run safely: keeps main.<hash>.js.orig from the first run and patches from that.
#
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# FLUSH CLOUDFLARE CACHE FOR THE HOST
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

set -eu

usage() {
	echo "Usage: VAULTWARDEN_SEND_SUBTITLE='Your custom message' $0 [main.<hash>.js]" >&2
	echo "" >&2
	echo "If no file is given, searches ./main.*.js then ./app/main.*.js" >&2
	exit 1
}

js_escape() {
	# Escape for a double-quoted JavaScript string literal.
	printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

sed_repl_escape() {
	# Escape for the replacement side of sed s||| (only & and \ are special).
	printf '%s' "$1" | sed 's/\\/\\\\/g; s/&/\\&/g'
}

find_main_js() {
	for pattern in ./main.*.js ./app/main.*.js; do
		# shellcheck disable=SC2086
		set -- $pattern
		for f in "$@"; do
			case $f in
				*.map) ;;
				*) [ -f "$f" ] && printf '%s\n' "$f" && return 0 ;;
			esac
		done
	done
	return 1
}

MAIN_JS="${1:-}"
if [ -z "$MAIN_JS" ]; then
	MAIN_JS=$(find_main_js) || true
fi
[ -n "$MAIN_JS" ] || usage
[ -f "$MAIN_JS" ] || {
	echo "error: file not found: $MAIN_JS" >&2
	exit 1
}

TEXT="${VAULTWARDEN_SEND_SUBTITLE:-}"
[ -n "$TEXT" ] || usage

ESCAPED=$(js_escape "$TEXT")
SUBTITLE_PATCH="this.layoutWrapperDataService.setAnonLayoutWrapperData({pageSubtitle:\"${ESCAPED}\"})"
SUBTITLE_SED=$(sed_repl_escape "$SUBTITLE_PATCH")

ORIG="${MAIN_JS}.orig"
if [ ! -f "$ORIG" ]; then
	cp "$MAIN_JS" "$ORIG"
	echo "Saved pristine backup: $ORIG"
fi
cp "$ORIG" "$MAIN_JS"

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT INT HUP TERM

# Flexible regex patches:
# 1. Force hideEmail=true when saving sends
# 2. Force hideEmail getter/computed signal to return false (hides callout warning banner)
# 3. Replace sendAccessCreatorIdentifier i18n subtitle anchor (or prior custom text) with new custom plain-text subtitle
sed -E \
	-e 's/([a-zA-Z0-9_\$]+\.hideEmail=)[a-zA-Z0-9_\$]+\.hideEmail(,[a-zA-Z0-9_\$]+\.maxAccessCount)/\1!0\2/g' \
	-e 's/this\.hideEmail=\(0,([a-zA-Z0-9_\$]+)\.EW\)\(\(\)=>null!=this\.send\(\)&&null==this\.creatorIdentifier\(\)\)/this.hideEmail=(0,\1.EW)(()=>!1)/g' \
	-e 's|const [a-zA-Z0-9_\$]+=this\.creatorIdentifier\(\);null!=[a-zA-Z0-9_\$]+&&this\.layoutWrapperDataService\.setAnonLayoutWrapperData\(\{pageSubtitle:\{key:"sendAccessCreatorIdentifier",placeholders:\[[a-zA-Z0-9_\$]+\]\}\}\)|'"${SUBTITLE_SED}"'|g' \
	-e 's|this\.layoutWrapperDataService\.setAnonLayoutWrapperData\(\{pageSubtitle:"[^"]*"\}\)|'"${SUBTITLE_SED}"'|g' \
	"$MAIN_JS" > "$TMP"

mv "$TMP" "$MAIN_JS"

# Verify required changes landed
FAIL=0
grep -E -q '[a-zA-Z0-9_\$]+\.hideEmail=!0,[a-zA-Z0-9_\$]+\.maxAccessCount' "$MAIN_JS" || {
	echo "error: patch failed — could not force hideEmail on save" >&2
	FAIL=1
}
grep -E -q 'this\.hideEmail=\(0,[a-zA-Z0-9_\$]+\.EW\)\(\(\)=>!1\)' "$MAIN_JS" || {
	echo "error: patch failed — could not disable warning banner logic" >&2
	FAIL=1
}
grep -F -q "$SUBTITLE_PATCH" "$MAIN_JS" || {
	echo "error: patch failed — could not set custom subtitle text" >&2
	echo "       (sendAccessCreatorIdentifier anchor not found in bundle?)" >&2
	FAIL=1
}
grep -q 'sendAccessCreatorIdentifier' "$MAIN_JS" && {
	echo "error: patch failed — i18n subtitle anchor still present" >&2
	FAIL=1
}

if [ "$FAIL" -ne 0 ]; then
	cp "$ORIG" "$MAIN_JS"
	exit 1
fi

chmod 644 "$MAIN_JS"

echo "Patched: $MAIN_JS"
echo "Subtitle: $TEXT"

printf '\n\n%s\n%s\n%s\n' \
	'!!!!!!!!!!!!!!!!!!!!!!!!!!' \
	'FLUSH THE CLOUDFLARE CACHE' \
	'!!!!!!!!!!!!!!!!!!!!!!!!!!'

