#!/usr/bin/env perl
# Confirm the Fast decoders produce the same records as new_from_xml.
#
#   perl bench/check.pl FILE.corpus
#
# Compares as_usmarc() output record by record and exits non-zero on any
# difference.
use strict;
use warnings;


use MARC::Record;
use MARC::File::XML ( BinaryEncoding => 'UTF-8' );
use MARC::File::XML::Fast qw( decode_reader decode_dom );

my $corpus = shift or die "usage: $0 FILE.corpus\n";
open my $fh, '<:encoding(UTF-8)', $corpus or die "cannot read $corpus: $!\n";
my $xml = [ split /\0/, do { local $/; <$fh> } ];
close $fh;

my ( $reader, $dom ) = ( 0, 0 );
for my $x (@$xml) {
    my $want = MARC::Record->new_from_xml( $x, 'UTF-8' )->as_usmarc;
    $reader++ if decode_reader($x)->as_usmarc eq $want;
    $dom++    if decode_dom($x)->as_usmarc eq $want;
}

printf "records=%d  fast_reader identical=%d  fast_dom identical=%d\n", scalar @$xml, $reader, $dom;
exit( $reader == @$xml && $dom == @$xml ? 0 : 1 );
