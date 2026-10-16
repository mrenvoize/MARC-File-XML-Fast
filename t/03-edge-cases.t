use strict;
use warnings;

use Test::More tests => 14;

use MARC::Record;
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'MARC21' );

use MARC::File::XML::Fast qw( decode_reader decode_dom );

my %backend = ( reader => \&decode_reader, dom => \&decode_dom );

sub record {
    my ($title) = @_;
    return '<record><leader>00000nam a2200000 a 4500</leader>'
        . qq{<datafield tag="245" ind1="1" ind2="0"><subfield code="a">$title</subfield></datafield>}
        . '</record>';
}

my $ns = 'xmlns="http://www.loc.gov/MARC21/slim"';

# A <collection> of several records decodes to the first, as new_from_xml does.
( my $collection = "<collection $ns>" . record('One') . record('Two') . '</collection>' );
my $expected = MARC::Record->new_from_xml( $collection, 'UTF-8' );
is( scalar( () = $expected->field('245') ), 1, 'baseline: new_from_xml returns only the first record' );

for my $name ( sort keys %backend ) {
    my $r = $backend{$name}->($collection);
    is_deeply( [ map { $_->as_string } $r->field('245') ], ['One'], "$name: a collection decodes to its first record only" );
}

# Problems MARC::Field->new rejects must croak, so callers can fall back to
# new_from_xml. Both backends must agree.
my $header = qq{<record $ns><leader>00000nam a2200000 a 4500</leader>};
my %bad = (
    'self-closed datafield'       => '<datafield tag="500" ind1=" " ind2=" "/>',
    'datafield with no subfields' => '<datafield tag="500" ind1=" " ind2=" "></datafield>',
    'missing indicators'          => '<datafield tag="500"><subfield code="a">x</subfield></datafield>',
);

for my $case ( sort keys %bad ) {
    my $xml = "$header$bad{$case}</record>";
    ok( !eval { MARC::Record->new_from_xml( $xml, 'UTF-8' ); 1 }, "baseline: new_from_xml dies on a $case" );
    for my $name ( sort keys %backend ) {
        ok( !eval { $backend{$name}->($xml); 1 }, "$name: $case croaks" );
    }
}

# An indicator that is present but empty is still coerced to a space.
my $empty_ind = qq{${header}<datafield tag="500" ind1="" ind2=" "><subfield code="a">x</subfield></datafield></record>};
is( $backend{$_}->($empty_ind)->field('500')->indicator(1), ' ', "$_: empty indicator coerced to space" ) for sort keys %backend;
