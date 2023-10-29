LISTPORTS="misc/foo"
OVERLAYS="overlay"
. common.bulk.sh

do_bulk -n ${LISTPORTS}
assert 0 $? "Bulk should pass"

# Assert that we found the right misc/foo
ret=0
hash_get originspec-pkgname "misc/foo" pkgname || ret=$?
assert 0 "${ret}" "Cannot find pkgname for misc/foo"
assert "foo-OVERLAY-20231026" "${pkgname}" "misc/foo didn't find the overlay version"

EXPECTED_QUEUED="misc/foo ports-mgmt/pkg"
EXPECTED_LISTED="misc/foo"

assert_bulk_queue_and_stats
