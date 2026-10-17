#!/usr/bin/env perl
# Build the MARCXML corpus the benchmarks decode.
#
#   perl bench/make-corpus.pl OUTPUT.corpus FILE.usmarc [FILE.usmarc ...]
#
# Reads binary MARC, serialises each record to a standalone MARCXML <record>
# with MARC::File::XML, and writes them as UTF-8 text separated by NUL bytes
# (which cannot occur in XML). Plain text is used, not Storable, so reading a
# corpus never deserialises untrusted data.
use strict;
use warnings;

use MARC::Batch;
use MARC::File::XML ( BinaryEncoding => 'UTF-8' );

my ( $out, @files ) = @ARGV;
die "usage: $0 OUTPUT.corpus FILE.usmarc [FILE.usmarc ...]\n" unless $out && @files;

my @xml;
for my $file (@files) {
    my $batch = MARC::Batch->new( 'USMARC', $file );
    $batch->warnings_off;
    $batch->strict_off;
    while ( my $record = eval { $batch->next } ) {
        my $xml = eval { $record->as_xml_record } or next;
        push @xml, $xml;
    }
}

die "no records read from: @files\n" unless @xml;
open my $fh, '>:encoding(UTF-8)', $out or die "cannot write $out: $!\n";
print {$fh} join( "\0", @xml );
close $fh or die "cannot write $out: $!\n";
printf "%d records -> %s\n", scalar @xml, $out;
