# MARC::File::XML::Fast

Faster MARCXML decoding into genuine [MARC::Record](https://metacpan.org/pod/MARC::Record)
objects.

```perl
use MARC::File::XML::Fast qw( decode );
my $record = decode( $marcxml );   # a MARC::Record
```

## Why

`MARC::Record->new_from_xml` builds a full DOM and runs `MARC::Field->new`
validation for every field. For records read from a store that already
validated them on write, that work is redundant. This module:

- parses with a streaming `XML::LibXML::Reader` instead of a DOM, and
- builds `MARC::Field` objects by direct bless, skipping per-field validation.

Output is byte-identical to `new_from_xml` for well-formed UTF-8 MARCXML
(indicator coercion is replicated). Malformed input croaks so callers can fall
back to the standard parser.

## When NOT to use it

This trades validation for speed. It is for **reading trusted, already-valid
MARCXML**. For untrusted input (Z39.50, imports, OAI, plugins), keep
`MARC::Record->new_from_xml`.

## Benchmarks

Decoding throughput against `MARC::Record->new_from_xml`, on 200 records per
round (40 sample MARC records from marc-perl's `marc-record/t/`, repeated 5
times), best of 20 rounds, each decoder in its own process. Measured on
Intel(R) Core(TM) i5-9400 CPU @ 2.90GHz, Perl 5.42.3, MARC::Record 2.0.7,
2026-10-17. The figures are the range over three complete runs of
`bench/run.sh`.

| Decoder                                                   |   Records/s   | vs master |
|-----------------------------------------------------------|--------------:|----------:|
| `new_from_xml`, marc-perl `master` (1f50502)              | 3,580 - 3,677 |  baseline |
| `new_from_xml`, marc-perl `performance` branch (d16aec5)  | 4,026 - 4,092 |  +10-13%  |
| `decode_dom` (this module)                                | 4,340 - 4,412 |  +20-21%  |
| `decode_reader` (this module)                             | 4,422 - 4,557 |  +22-27%  |

The output of both backends was identical to `new_from_xml` (compared with
`as_usmarc`) for all 40 records.

What to take from it:

- Most of the gain comes from skipping per-field validation. The streaming
  reader adds only 1-5% over the DOM backend, which uses the same direct-bless
  construction, and that gap is within the run-to-run noise.
- The `performance` branch of
  [gmcharlt/marc-perl2](https://github.com/gmcharlt/marc-perl2) keeps its
  validation and still recovers about half of this module's gain.
- These are small fixture records on one machine, so treat the percentages as
  directional. Absolute numbers will vary; compare rows within one run.

### Reproducing

You need a checkout of [marc-perl](https://github.com/perl4lib/marc-perl), with
`XML::LibXML` installed. It supplies the sample records and the `MARC::Record`
the module is measured against. Build its character database once, then run:

```sh
(cd /path/to/marc-perl/marc-charset && perl -Ilib build_db.PL)

bench/run.sh /path/to/marc-perl
```

To add another marc-perl revision as a further `new_from_xml` row, such as a
branch checked out in a worktree, pass it as an extra argument:

```sh
git -C /path/to/marc-perl worktree add --detach /tmp/mp-perf gmcharlt/performance
bench/run.sh /path/to/marc-perl /tmp/mp-perf
```

`bench/run.sh -r 50 ...` changes the number of rounds. It first builds the
corpus, then checks the output matches `new_from_xml`, then times each decoder.
The three scripts it uses can also be run on their own: `bench/make-corpus.pl`,
`bench/check.pl` and `bench/bench.pl` (see the comment at the top of each).

Note that the `performance` branch changes `MARC::Field`'s internal layout, so
this module's `t/02-internals-compat.t` is expected to fail against it. The
benchmark only runs the module against the first checkout you pass.

## Compatibility / version-locking

The direct-bless construction depends on `MARC::Field`'s **private** internal
representation. `t/02-internals-compat.t` asserts that representation and will
fail loudly if a future `MARC::Record` release changes it — at which point this
module must be updated before the newer `MARC::Record` is trusted. Known-good:
MARC::Record 2.0.7.

## Roadmap

The clean parts (streaming decode; an opt-in no-validation field constructor)
are intended for upstreaming into `MARC::Record` / `MARC::File::XML`. Once
landed, this distribution can become a thin shim over the public fast path and
shed the internals dependency.

## License

Same terms as Perl itself.
