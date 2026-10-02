#!/usr/bin/env bats
# The package ships no private key and no certificate: nothing under share/
# ending in .key or .pem, in the source tree and in the built .deb. A key in
# the package is a key every machine built from it would share; the keys of a
# machine are generated on the machine (keel-host-keys, 15regen-sslcert,
# turnkey-make-ssl-cert --default).
#
# The .deb comes from DEB when set, else the newest turnkey-ssl_*.deb beside
# the source tree or under dist/.

bats_require_minimum_version 1.5.0

REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

find_deb() {
    if [ -n "${DEB:-}" ]; then
        printf '%s\n' "$DEB"
        return
    fi
    ls -t "$REPO"/dist/turnkey-ssl_*.deb "$REPO"/../turnkey-ssl_*.deb 2>/dev/null | head -n 1
}

@test "the source tree keeps no .key or .pem under share/" {
    run bash -c "find '$REPO/share' \( -name '*.key' -o -name '*.pem' \) 2>/dev/null"
    [ -z "$output" ]
}

@test "debian/install installs nothing from share/" {
    run grep -E '^share' "$REPO/debian/install"
    [ "$status" -ne 0 ]
}

@test "debian/postinst copies no key into /etc/ssl/private" {
    run grep -E 'cp |cert\.key|cert\.pem|dhparams' "$REPO/debian/postinst"
    [ "$status" -ne 0 ]
}

@test "the built .deb contains no .key or .pem under share/" {
    deb="$(find_deb)"
    [ -n "$deb" ] || skip "no turnkey-ssl_*.deb built yet (set DEB)"
    run bash -c "dpkg-deb -c '$deb' | awk '{ print \$6 }' | grep -E 'share/.*\.(key|pem)$'"
    [ "$status" -ne 0 ]
    [ -z "$output" ]
    run bash -c "dpkg-deb -c '$deb' | awk '{ print \$6 }' | grep -E 'usr/bin/turnkey-make-ssl-cert$'"
    [ "$status" -eq 0 ]
}
