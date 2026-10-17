#!/usr/bin/env bash
# Compare MARCXML decoders: MARC::Record->new_from_xml in one or more marc-perl
# checkouts, and this module's two backends.
#
#   bench/run.sh [-r ROUNDS] MARC_PERL [OTHER_MARC_PERL ...]
#
# MARC_PERL is a checkout of https://github.com/perl4lib/marc-perl. It supplies
# the corpus (marc-record/t/*.usmarc), the MARC::Record that this module is
# measured against, and the first "new_from_xml" row. Each OTHER_MARC_PERL (a
# branch worktree, say) adds a further "new_from_xml" row. marc-charset must
# have its character database built in each checkout:
#
#   (cd MARC_PERL/marc-charset && perl -Ilib build_db.PL)
set -euo pipefail

rounds=20
if [[ ${1:-} == -r ]]; then rounds=$2; shift 2; fi
[[ $# -ge 1 ]] || { sed -n '2,13p' "$0"; exit 2; }

here=$(cd "$(dirname "$0")/.." && pwd)
corpus=$(mktemp -t marc-xml-fast-corpus.XXXXXX)
trap 'rm -f "$corpus"' EXIT

libs() {
    local d=$1
    echo "$d/marc-record/lib:$d/marc-xml/lib:$d/marc-charset/lib"
}
label() {
    local d=$1
    printf '%s @ %s' "$(git -C "$d" rev-parse --abbrev-ref HEAD)" "$(git -C "$d" rev-parse --short HEAD)"
}

base=$(cd "$1" && pwd); shift

echo "perl $(perl -e 'print $^V') | $(uname -sm) | $(date -u +%Y-%m-%d)"
echo "this module: $(git -C "$here" rev-parse --short HEAD)"
echo "MARC::Record: $(PERL5LIB=$(libs "$base") perl -MMARC::Record -e 'print $MARC::Record::VERSION')"
echo

PERL5LIB=$(libs "$base") perl "$here/bench/make-corpus.pl" "$corpus" "$base"/marc-record/t/*.usmarc
echo

echo "Output identical to new_from_xml:"
PERL5LIB="$(libs "$base"):$here/lib" perl "$here/bench/check.pl" "$corpus"
echo

echo "Throughput (best of $rounds rounds):"
printf '%-38s ' "new_from_xml [$(label "$base")]"
PERL5LIB=$(libs "$base") perl "$here/bench/bench.pl" --impl new_from_xml --corpus "$corpus" --rounds "$rounds"
for other in "$@"; do
    other=$(cd "$other" && pwd)
    printf '%-38s ' "new_from_xml [$(label "$other")]"
    PERL5LIB=$(libs "$other") perl "$here/bench/bench.pl" --impl new_from_xml --corpus "$corpus" --rounds "$rounds"
done
for impl in fast_dom fast_reader; do
    printf '%-38s ' "$impl [on $(label "$base")]"
    PERL5LIB="$(libs "$base"):$here/lib" perl "$here/bench/bench.pl" --impl "$impl" --corpus "$corpus" --rounds "$rounds"
done
