use strict;
use warnings;
use utf8;

use Test::More tests => 7;

use MARC::Record;
use MARC::Field;
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'MARC21' );

use MARC::File::XML::Fast qw( decode decode_reader decode_dom );

# Build a representative record programmatically, then serialise it to MARCXML
# (control field with significant spaces, indicators, repeated subfields, UTF-8).
sub build_marcxml {
    my $record = MARC::Record->new;
    $record->leader('01344cam a22003014i 4500');
    $record->append_fields(
        MARC::Field->new( '001', '17446121' ),
        MARC::Field->new( '008', '120829t20132012nyu      b    001 0 eng  ' ),
        MARC::Field->new( '245', '1', '0', 'a', 'Café déjà vu /', 'c', 'by Renée Müller.' ),
        MARC::Field->new( '650', ' ', '0', 'a', 'Cooking.', 'x', 'History' ),
        MARC::Field->new( '999', ' ', ' ', 'c', '17446121' ),
    );
    return $record->as_xml_record('MARC21');
}

my $marcxml = build_marcxml();

# Fresh baseline each call: as_usmarc() rewrites the leader, so a shared object
# would leak that mutation between assertions.
sub baseline { return MARC::Record->new_from_xml( $marcxml, 'UTF-8' ); }

is( decode_reader($marcxml)->as_formatted, baseline()->as_formatted, 'reader: as_formatted matches new_from_xml' );
is( decode_reader($marcxml)->as_usmarc,    baseline()->as_usmarc,    'reader: as_usmarc matches new_from_xml' );
is( decode_dom($marcxml)->as_formatted,    baseline()->as_formatted, 'dom: as_formatted matches new_from_xml' );
is( decode_dom($marcxml)->as_usmarc,       baseline()->as_usmarc,    'dom: as_usmarc matches new_from_xml' );

is( decode($marcxml)->subfield( '245', 'a' ), 'Café déjà vu /', 'UTF-8 subfield preserved' );

# Empty indicator attribute must be coerced to a space, as MARC::Field->new does.
( my $empty_ind = $marcxml ) =~ s/(<datafield tag="999" ind1=)" "/$1""/;
is( decode($empty_ind)->field('999')->indicator(1), ' ', 'empty indicator coerced to space' );

# Malformed input (raw 0x1F) must croak so callers can fall back.
( my $bad = $marcxml ) =~ s/17446121/17\x{1F}446121/;
ok( !eval { decode($bad) }, 'malformed MARCXML croaks' );
