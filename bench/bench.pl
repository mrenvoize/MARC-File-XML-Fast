#!/usr/bin/env perl
# Time one MARCXML decoder over the corpus built by make-corpus.pl.
#
#   perl bench/bench.pl --impl IMPL --corpus FILE.corpus [--repeat N] [--rounds N]
#
# IMPL is one of: new_from_xml, fast_reader, fast_dom. Each round decodes the
# whole corpus (repeated --repeat times, default 5, so a round is long enough
# to time). One untimed warm-up pass runs first. Prints the best and median
# round. Run each IMPL in its own process (bench/run.sh does) so they cannot
# affect one another.
use strict;
use warnings;

use Getopt::Long;
use Time::HiRes qw( time );

use MARC::Record;
use MARC::File::XML ( BinaryEncoding => 'UTF-8' );

my ( $impl, $corpus );
my ( $repeat, $rounds ) = ( 5, 20 );
GetOptions( 'impl=s' => \$impl, 'corpus=s' => \$corpus, 'repeat=i' => \$repeat, 'rounds=i' => \$rounds )
    or die "bad options\n";
die "usage: $0 --impl IMPL --corpus FILE.corpus [--repeat N] [--rounds N]\n" unless $impl && $corpus;

my %decoder = ( new_from_xml => sub { MARC::Record->new_from_xml( $_[0], 'UTF-8' ) } );
if ( $impl =~ /^fast_/ ) {
    require MARC::File::XML::Fast;
    $decoder{fast_reader} = \&MARC::File::XML::Fast::decode_reader;
    $decoder{fast_dom}    = \&MARC::File::XML::Fast::decode_dom;
}
my $decode = $decoder{$impl} or die "unknown --impl '$impl'\n";

open my $fh, '<:encoding(UTF-8)', $corpus or die "cannot read $corpus: $!\n";
my @xml = ( split /\0/, do { local $/; <$fh> } ) x $repeat;
close $fh;

$decode->($_) for @xml;    # warm-up

my @times;
for ( 1 .. $rounds ) {
    my $start = time;
    $decode->($_) for @xml;
    push @times, time - $start;
}
@times = sort { $a <=> $b } @times;

printf "%-13s best %.3fs  median %.3fs  %5.0f records/s (best)\n",
    $impl, $times[0], $times[ @times / 2 ], @xml / $times[0];
