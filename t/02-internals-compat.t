use strict;
use warnings;

use Test::More tests => 4;

use MARC::Record;
use MARC::Field;

# MARC::File::XML::Fast builds MARC::Field objects by direct bless, which
# depends on MARC::Field's PRIVATE internal hash representation. If a future
# MARC::Record release changes that representation, the assertions below fail --
# a deliberate, loud signal that MARC::File::XML::Fast must be updated (and that
# the new MARC::Record should not be trusted with it) before upgrading.

diag("Checking MARC::Field internals against MARC::Record $MARC::Record::VERSION");

my $cf = MARC::Field->new( '001', 'data' );
is_deeply(
    [ sort keys %$cf ],
    [ sort qw( _tag _data _is_control_field _warnings ) ],
    'control MARC::Field internal keys are as expected',
);

my $df = MARC::Field->new( '245', '1', '0', 'a', 'Title', 'b', 'sub' );
is_deeply(
    [ sort keys %$df ],
    [ sort qw( _tag _ind1 _ind2 _is_control_field _subfields _warnings ) ],
    'data MARC::Field internal keys are as expected',
);

is( ref $df->{_subfields}, 'ARRAY', '_subfields is an arrayref' );

is_deeply(
    $df->{_subfields},
    [ 'a', 'Title', 'b', 'sub' ],
    '_subfields is a flat [ code, value, ... ] list',
);
