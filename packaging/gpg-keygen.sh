#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Generate a dedicated pacman repository signing key and print the values that
# belong in the GitHub Actions secrets PACMAN_GPG_KEY and PACMAN_GPG_KEY_ID.
#
# Run this on a trusted machine, add the secrets, then delete packaging/dist/.
# The CI key is intentionally passphrase-less: `repo-add --sign` inside the
# publish job cannot prompt. The private key is protected by the GitHub secret
# store, so keep an offline backup and rotate it if it is ever exposed.
#
# You do not have to run this: an existing signing key (for example the Wire
# Flatpak key in that project's flatpak/dist/) can be reused instead — this
# repository's workflow accepts both the armoured key and its base64 form.

set -euo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/packaging/dist"
mkdir -p "$OUT_DIR"

GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
trap 'rm -rf "$GNUPGHOME"' EXIT

gpg --batch --passphrase '' --quick-generate-key \
    "Lumo pacman repository (unofficial) <pacman@nichu42.github.io>" ed25519 sign 5y

KEY_ID="$(gpg --list-secret-keys --with-colons | awk -F: '/^sec:/ {print $5; exit}')"
if [ -z "$KEY_ID" ]; then
    echo "gpg-keygen: key generation failed" >&2
    exit 1
fi
FINGERPRINT="$(gpg --with-colons --fingerprint "$KEY_ID" | awk -F: '/^fpr:/ {print $10; exit}')"

gpg --armor --export-secret-keys "$KEY_ID" > "$OUT_DIR/pacman-private-key.asc"
base64 -w0 "$OUT_DIR/pacman-private-key.asc" > "$OUT_DIR/pacman-private-key.b64"
gpg --armor --export "$KEY_ID" > "$OUT_DIR/lumo-repo.gpg"

cat <<EOF
Generated pacman repository signing key:
  key id:      $KEY_ID
  fingerprint: $FINGERPRINT

GitHub Actions secrets for this repository:
  PACMAN_GPG_KEY_ID  = $KEY_ID
  PACMAN_GPG_KEY     = contents of $OUT_DIR/pacman-private-key.b64

Files written:
  $OUT_DIR/pacman-private-key.asc   armoured private key
  $OUT_DIR/pacman-private-key.b64   same, base64 (convenient for a secret)
  $OUT_DIR/lumo-repo.gpg            public key, for users to import

Users then trust it with:
  curl -fsSL https://nichu42.github.io/lumo-desktop/arch/x86_64/lumo.gpg | sudo pacman-key --add -
  sudo pacman-key --lsign-key $KEY_ID

Delete packaging/dist/ once the secrets are stored.
EOF
