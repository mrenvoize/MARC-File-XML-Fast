use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'MARC::File::XML::Fast',
    VERSION_FROM     => 'lib/MARC/File/XML/Fast.pm',
    ABSTRACT_FROM    => 'lib/MARC/File/XML/Fast.pm',
    AUTHOR           => 'Martin Renvoize <martin.renvoize@openfifth.co.uk>',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.010',

    PREREQ_PM => {
        'Carp'         => 0,
        'Exporter'     => 0,
        'XML::LibXML'  => 0,

        # Direct-bless construction depends on MARC::Field internals. This is
        # the lowest version those internals have been verified against; the
        # upper bound is enforced structurally by t/02-internals-compat.t.
        'MARC::Record' => '2.0.7',
    },

    TEST_REQUIRES => {
        'Test::More' => 0,
    },

    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/mrenvoize/MARC-File-XML-Fast.git',
                web  => 'https://github.com/mrenvoize/MARC-File-XML-Fast',
            },
        },
        # MARC::Record releases whose MARC::Field internals this version is
        # known to be compatible with. Update when verified against new ones.
        x_marc_record_compat => ['2.0.7'],
    },
);
