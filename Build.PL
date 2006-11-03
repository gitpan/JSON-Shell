use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'JSON::Shell',
    license             => 'perl',
    dist_author         => 'Mark Paschal <mark@sixapart.com>',
    dist_version_from   => 'lib/JSON/Shell.pm',
    requires => {
        'Test::More'  => 0,
        'version'     => 0,
        'Shell::Base' => 0,
        'JSON'        => 0,
    },
    add_to_cleanup      => [ 'JSON-Shell-*' ],
);

$builder->create_build_script();
