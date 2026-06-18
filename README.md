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
