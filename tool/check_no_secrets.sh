#!/usr/bin/env bash
# Testing Protocol · control C5: no secret on the client.
#
# Looks for server-only keys in the files tracked by git and, when given,
# inside a built app (APK or IPA): the Supabase service_role key, secret
# keys and AI provider keys. Only the public anon / publishable key may
# ship with the app.
#
#   tool/check_no_secrets.sh                       # the repository
#   tool/check_no_secrets.sh build/app/outputs/flutter-apk/app-release.apk
#
# Exit code 1 and the offending places when something is found.
set -euo pipefail

# A JWT whose payload says "role":"service_role" (base64 of the claim),
# Supabase secret keys, and the usual AI / cloud key prefixes.
PATTERNS=(
  # "service_role" inside a base64 JWT payload, at its three alignments
  'c2VydmljZV9yb2xl'
  'NlcnZpY2Vfcm9sZ'
  'ZXJ2aWNlX3JvbG'
  # A real key mixes digits in; the SDK only holds the bare prefix.
  'sb_secret_[A-Za-z_-]*[0-9][A-Za-z0-9_-]{8,}'
  'sk-ant-[A-Za-z0-9_-]{8,}'
  'sk-[A-Za-z0-9]{32,}'
  'AIza[0-9A-Za-z_-]{30,}'
  'SUPABASE_SERVICE_ROLE_KEY *= *[^ $]'
)
regex=$(IFS='|'; echo "${PATTERNS[*]}")
found=0

# The repository. This script and the docs that name the patterns are not
# secrets themselves.
if git ls-files -z \
  | grep -zv -e '^tool/check_no_secrets.sh$' \
  | xargs -0 grep -nIE "$regex" -- 2>/dev/null; then
  found=1
fi

# A built app: every file inside the archive, binary included.
for app in "$@"; do
  tmp=$(mktemp -d)
  unzip -q -o "$app" -d "$tmp"
  if grep -rlaE "$regex" "$tmp" | sed "s|$tmp/|$app: |"; then
    found=1
  fi
  rm -rf "$tmp"
done

if [ "$found" -ne 0 ]; then
  echo "C5 failed: a server-only key is in the repository or the app." >&2
  exit 1
fi
echo "C5 passed: no server-only key in the repository${1:+ nor in $*}."
