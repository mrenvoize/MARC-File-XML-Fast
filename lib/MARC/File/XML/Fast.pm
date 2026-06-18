package MARC::File::XML::Fast;

use strict;
use warnings;

use Carp qw( croak );
use XML::LibXML;
use XML::LibXML::Reader;
use MARC::Record;
use MARC::Field;

use Exporter 'import';
our @EXPORT_OK = qw( decode decode_reader decode_dom );

our $VERSION = '0.01';

=head1 NAME

MARC::File::XML::Fast - faster MARCXML decoding into MARC::Record objects

=head1 SYNOPSIS

    use MARC::File::XML::Fast qw( decode );

    my $record = decode( $marcxml );   # a genuine MARC::Record

=head1 DESCRIPTION

C<MARC::File::XML::Fast> decodes MARCXML into ordinary L<MARC::Record> objects,
faster than C<< MARC::Record->new_from_xml >>. The speed comes from two places:

=over

=item * a streaming L<XML::LibXML::Reader> parse instead of building a DOM, and

=item * constructing C<MARC::Field> objects by direct bless, skipping the
per-field validation C<< MARC::Field->new >> performs.

=back

The output is byte-identical to C<< MARC::Record->new_from_xml >> for
well-formed UTF-8 MARCXML (it replicates that constructor's indicator
coercion). Malformed input causes a croak, so callers can fall back to the
standard parser.

=head1 WHEN TO USE IT

This module is for B<reading already-validated MARCXML> at speed -- e.g.
records loaded from a store that validated them on write. It deliberately skips
the validation C<< MARC::Field->new >> does (tag shape, indicator legality, "at
least one subfield"). B<Do not> use it as a first line of defence against
untrusted input; for that, keep C<< MARC::Record->new_from_xml >>.

It does B<not> implement the MARC-8 transcode branch -- input is assumed UTF-8.

=head1 COMPATIBILITY

The direct-bless construction depends on the B<internal> hash representation of
L<MARC::Field>. That is private API, so this distribution is version-locked: it
ships a structural compatibility test (F<t/02-internals-compat.t>) that fails
loudly if a future MARC::Record release changes that representation. If that
test fails against a newer MARC::Record, do not upgrade until this module is
updated to match.

=head1 FUNCTIONS

=head2 decode

    my $record = decode( $marcxml );

Decode MARCXML into a L<MARC::Record> using the fastest backend (currently
L</decode_reader>). The recommended entry point.

=cut

# Reusable DOM parser for the dom backend.
my $PARSER = XML::LibXML->new();

sub decode { return decode_reader(@_); }

=head3 _ind

Replicate C<< MARC::Field->new >> indicator handling (without the warning): an
invalid, empty, or undefined indicator becomes a single space.

=cut

sub _ind {
    my $v = shift;
    return ' ' if !defined $v || $v !~ /^[0-9A-Za-z ]\z/;
    return $v;
}

=head3 _control_field

Build a control C<MARC::Field> by direct bless.

=cut

sub _control_field {
    my ( $tag, $data ) = @_;
    return bless {
        _tag              => $tag,
        _data             => ( defined $data ? $data : '' ),
        _is_control_field => 1,
        _warnings         => [],
        },
        'MARC::Field';
}

=head3 _data_field

Build a data C<MARC::Field> by direct bless.

=cut

sub _data_field {
    my ( $tag, $ind1, $ind2, $subs ) = @_;
    return bless {
        _tag              => $tag,
        _ind1             => _ind($ind1),
        _ind2             => _ind($ind2),
        _is_control_field => 0,
        _subfields        => $subs,         # flat [ code, val, code, val, ... ]
        _warnings         => [],
        },
        'MARC::Field';
}

=head2 decode_reader

    my $record = decode_reader( $marcxml );

Streaming (pull-parser) decode; never materializes the full DOM. Fastest path.

=cut

sub decode_reader {
    my ($xml) = @_;

    my $r = XML::LibXML::Reader->new( string => $xml )
        or croak('MARC::File::XML::Fast: could not create XML::LibXML::Reader');

    my $rec = MARC::Record->new();
    my @fields;

    my $leaf;    # 'leader' | 'ctrl' | 'sub' | undef
    my $text = '';
    my ( $tag, $ind1, $ind2, $code, @subs );

    # nodeType: ELEMENT=1 TEXT=3 CDATA=4 SIG_WS=14 END_ELEMENT=15
    # read() returns 1=ok, 0=end, -1=error. MUST NOT loop on -1 (truthy!) or a
    # malformed record spins forever instead of failing cleanly. Croak on error.
    my $rv;
    while ( ( $rv = $r->read ) == 1 ) {
        my $type = $r->nodeType;

        if ( $type == 1 ) {
            my $name  = $r->localName;
            my $empty = $r->isEmptyElement;

            if ( $name eq 'subfield' ) {
                $code = $r->getAttribute('code');
                $text = '';
                $leaf = 'sub';
            } elsif ( $name eq 'controlfield' ) {
                $tag  = $r->getAttribute('tag');
                $text = '';
                $leaf = 'ctrl';
            } elsif ( $name eq 'leader' ) {
                $text = '';
                $leaf = 'leader';
            } elsif ( $name eq 'datafield' ) {
                $tag  = $r->getAttribute('tag');
                $ind1 = $r->getAttribute('ind1');
                $ind2 = $r->getAttribute('ind2');
                @subs = ();
                $leaf = undef;
            }

            if ( $empty && defined $leaf ) {    # e.g. <subfield code="a"/>
                if    ( $leaf eq 'sub' )    { push @subs, $code, '' }
                elsif ( $leaf eq 'ctrl' )   { push @fields, _control_field( $tag, '' ) }
                elsif ( $leaf eq 'leader' ) { $rec->leader('') }
                $leaf = undef;
            }
        } elsif ( $type == 3 || $type == 4 || $type == 14 ) {
            $text .= $r->value if defined $leaf;
        } elsif ( $type == 15 ) {
            my $name = $r->localName;
            if ( $name eq 'subfield' ) {
                push @subs, $code, $text;
                $leaf = undef;
            } elsif ( $name eq 'controlfield' ) {
                push @fields, _control_field( $tag, $text );
                $leaf = undef;
            } elsif ( $name eq 'leader' ) {
                $rec->leader($text);
                $leaf = undef;
            } elsif ( $name eq 'datafield' ) {
                push @fields, _data_field( $tag, $ind1, $ind2, [@subs] );
            }
        }
    }

    croak('MARC::File::XML::Fast: XML read error') if $rv < 0;

    $rec->append_fields(@fields) if @fields;
    return $rec;
}

=head2 decode_dom

    my $record = decode_dom( $marcxml );

DOM decode (same traversal as C<MARC::File::XML::decode>) with direct-bless
field construction. Kept for comparison; L</decode_reader> is faster.

=cut

sub decode_dom {
    my ($xml) = @_;

    my $doc  = $PARSER->parse_string($xml);
    my $root = $doc->documentElement;
    croak('MARC::File::XML::Fast: MARCXML document has no root element') unless defined $root;
    if ( $root->localname eq 'collection' ) {
        ($root) = $root->getChildrenByLocalName('record');
        croak('MARC::File::XML::Fast: MARCXML document has no record element') unless defined $root;
    }

    my $rec     = MARC::Record->new();
    my @leaders = $root->getElementsByLocalName('leader');
    $rec->leader( $leaders[0]->textContent ) if @leaders;

    my @fields;
    for my $elt ( $root->getChildrenByLocalName('*') ) {
        my $ln = $elt->localname;
        if ( $ln eq 'controlfield' ) {
            push @fields, _control_field( $elt->getAttribute('tag'), $elt->textContent );
        } elsif ( $ln eq 'datafield' ) {
            my @sfs;
            for my $sf ( $elt->getChildrenByLocalName('subfield') ) {
                push @sfs, $sf->getAttribute('code'), $sf->textContent;
            }
            push @fields,
                _data_field(
                $elt->getAttribute('tag'), $elt->getAttribute('ind1'), $elt->getAttribute('ind2'),
                \@sfs
                );
        }
    }
    $rec->append_fields(@fields);
    return $rec;
}

1;

__END__

=head1 SEE ALSO

L<MARC::Record>, L<MARC::File::XML>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
