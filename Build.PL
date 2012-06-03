use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'SQL::Abstract::FromQuery',
    license             => 'perl',
    dist_author         => q{Laurent Dami <laurent.dami AT justice.ge.ch>},
    dist_version_from   => 'lib/SQL/Abstract/FromQuery.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'perl'             => 5.010,
        'Module::Load'     => 0,
        'Params::Validate' => 0,
        'Regexp::Grammars' => 0,
        'Scalar::Util'     => 0,
        'UNIVERSAL::DOES'  => 0,
        'namespace::clean' => 0,
    },
    add_to_cleanup      => [ 'SQL-Abstract-FromQuery-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
