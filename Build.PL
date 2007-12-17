use Module::Build;

use strict;

my $build = Module::Build->new(
    module_name => 'Perl::Install',
    dist_version => '0.01',
    dist_abstract => 'README',
    license => 'perl',
    requires => {
        'perl'                  => '5.006_000',
        'File::Path'            => '0.01',
        'File::Spec::Functions' => '0.01',
        'Cwd'                   => '0.01',
        'Getopt::Long'          => '1.00',
        'Pod::Usage'            => '0.05',
    },
    optional => {
    },
    build_requires => {
    },
    create_makefile_pl => 'traditional',
    add_to_cleanup => [
        'META.yml', '*.bak', '*.gz', 'Makefile.PL', 'cover_db',
    ],
    script_files => [
        (map { "script/$_" } qw( install_perl.pl install_cpan_modules.pl ))
    ],
    test_files => 't/???_*.t',
);

$build->create_build_script;
