#!/usr/bin/env bats
# debian/postinst closes /etc/ssl/private to everyone but root, except that
# the ssl-cert group keeps its search bit. ssl-cert ships the directory as
# root:ssl-cert 0710, and PostgreSQL, a member of ssl-cert, reads the
# snakeoil key through it. A plain `chmod 700` made every upgrade of
# turnkey-ssl stop PostgreSQL with "could not access private key file"
# (inithooks#64).
#
# The postinst runs with -e, as dpkg runs it. SSL_CERT_GROUP stands for
# ssl-cert: the test directory belongs to the user's own group.

REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    export SSL_PRIVATE_DIR="$BATS_TEST_TMPDIR/private"
    mkdir -p "$SSL_PRIVATE_DIR"
    OWN_GROUP=$(stat -c %G "$SSL_PRIVATE_DIR")
}

postinst() {
    run sh -e "$REPO/debian/postinst" configure 3.1.1+keel3
    [ "$status" -eq 0 ]
}

mode() {
    stat -c %a "$SSL_PRIVATE_DIR"
}

@test "an ssl-cert directory at 0710 stays 0710" {
    export SSL_CERT_GROUP=$OWN_GROUP
    chmod 0710 "$SSL_PRIVATE_DIR"
    postinst
    [ "$(mode)" = 710 ]
}

@test "an ssl-cert directory left at 0700 by keel1 or keel2 is repaired to 0710" {
    export SSL_CERT_GROUP=$OWN_GROUP
    chmod 0700 "$SSL_PRIVATE_DIR"
    postinst
    [ "$(mode)" = 710 ]
}

@test "an ssl-cert directory open to others becomes 0710" {
    export SSL_CERT_GROUP=$OWN_GROUP
    chmod 0777 "$SSL_PRIVATE_DIR"
    postinst
    [ "$(mode)" = 710 ]
}

@test "a directory of another group becomes 0700" {
    export SSL_CERT_GROUP=no-such-group-keel
    chmod 0755 "$SSL_PRIVATE_DIR"
    postinst
    [ "$(mode)" = 700 ]
}

@test "a missing directory fails the configure step" {
    rmdir "$SSL_PRIVATE_DIR"
    run sh -e "$REPO/debian/postinst" configure 3.1.1+keel3
    [ "$status" -ne 0 ]
    [ ! -e "$SSL_PRIVATE_DIR" ]
}
