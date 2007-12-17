#!/usr/bin/perl

use 5.006_000;

use strict;
use warnings FATAL => 'all';

# This environment will be relocatable and will contain all the
# Perl modules (and prereqs) necessary.
#
# Assumptions:
#   * The appropriate Perl version is installed globally.

use Cwd qw( abs_path );
use File::Path qw( mkpath );
use File::Spec::Functions qw( catdir splitdir );
use Getopt::Long;
use Pod::Usage qw( pod2usage );

my %opts = (
    directory => '.',
    perl_version => 'stable',
);
GetOptions( \%opts,
    'directory=s',
    'perl_version|v=s',
    'manifest|m=s',
    'help|?',
    'man',
) or pod2usage( 2 );
pod2usage( 1 ) if $opts{help};
pod2usage( -exitstatus => 0, -verbose => 2 ) if $opts{man};

if ( !defined $opts{directory} ) {
    pod2usage( -exitstatus => 1, -verbose => 1 );
}

my $path = abs_path( $opts{directory} );
unless ( $path || -e $path ) {
    pod2usage(
        -exitstatus => 1,
        -message => "\n-directory '$opts{directory}' doesn't exist",
    );
}

my @time = localtime(time);
my $timestamp = sprintf(
    "%04d%02d%02d_%02d%02d%02d",
    $time[5] + 1900, $time[4] + 1, @time[3,2,1,0],
);

my $base_dir = catdir( $path, $timestamp );
if ( -e $base_dir ) {
    pod2usage(
        -exitstatus => 1,
        -message => "\nenvironment directory '$base_dir' already exists",
    );
}

eval {
    mkpath( $base_dir );
}; if ( $@ ) {
    pod2usage(
        -exitstatus => 1,
        -message => "\nCannot create the environment within '$opts{directory}' (Make sure to clean up, if necessary)\n\t$@",
    );
}

my %apps = map {
    my $x = `which $_`;
    chomp $x;
    $_ => $x
} qw(
    gzip gpg ftp lynx make less bash unzip wget tar
);

unless ( $apps{wget} ) {
    pod2usage(
        -exitstatus => 1,
        -message => "\nCannot find wget application.\n",
    );
}

# $opts{directory} is now the root directory. We need to create the directory
# tree that Perl expects.

eval {
    mkpath(
        [
            (map {
                catdir( $base_dir, $_ )
            } qw(
                bin
                cpan/build cpan/sources
                lib
                man/man1 man/man3
                src
            ))
        ],
    );
}; if ( $@ ) {
    pod2usage(
        -exitstatus => 1,
        -message => "\nCannot create tree under '$opts{directory}' - is your umask ok?\n\t$@",
    );
}

my $perl_version;
eval {
    my ($file, $dir);
    if ( $opts{perl_version} =~ /\d/ ) {
        $file = "perl-$opts{perl_version}.tar.gz";
        $dir ="perl-$opts{perl_version}";
    }
    else {
        $file = "$opts{perl_version}.tar.gz";
        $dir = 'perl-*';
    }

    my $shell_cmd = <<"__END_SHELL__";
cd $base_dir/src;
$apps{wget} http://www.cpan.org/src/$file;
$apps{tar} zxf $file;
cd $dir;
sh ./Configure -Dprefix="$base_dir" -Dcc=/usr/bin/gcc -des -Dusedevel;
make && make install
__END_SHELL__
    $shell_cmd =~ s!$/!!g;
    system( $shell_cmd ) == 0
        or die "system() failed: $?\n";

    # Grab the actual perl version for later.
    ($perl_version = (splitdir( glob "$base_dir/src/$dir" ))[-1]) =~ s/perl-//;;

    unless ( -f "$base_dir/bin/perl" ) {
        system( "ln -s $base_dir/bin/perl${perl_version} $base_dir/bin/perl" );
    }
}; if ( $@ ) {
    die $@;
}

# Create the CPAN::Config file and put it into lib/
{
    my $filename = "$base_dir/lib/$perl_version/CPAN/Config.pm";
    open my $fh, '>', $filename
        or die "Cannot open '$filename' for writing: $!\n";

    my $cpan_dir = "$base_dir/cpan";
    my $lib_dir  = "$base_dir/lib";
    my $bin_dir  = "$base_dir/bin";
    my $man_dir  = "$base_dir/man";

    print $fh <<"__END_CPAN_CONFIG__";
\$CPAN::Config = {
    'auto_commit' => q[no],
    'build_cache' => q[10],
    'build_dir' => q[$cpan_dir/build],
    'cache_metadata' => q[1],
    'cpan_home' => q[$cpan_dir],
    'dontload_hash' => {},
    'ftp' => q[$apps{ftp}],
    'ftp_proxy' => q[],
    'getcwd' => q[cwd],
    'gpg' => q[$apps{gpg}],
    'gzip' => q[$apps{gzip}],
    'histfile' => q[$cpan_dir/histfile],
    'histsize' => q[100],
    'http_proxy' => q[],
    'inactivity_timeout' => q[0],
    'index_expire' => q[1],
    'inhibit_startup_message' => q[0],
    'keep_source_where' => q[$cpan_dir/sources],
    'lynx' => q[$apps{lynx}],
    'make' => q[$apps{make}],
    'make_arg' => q[],
    'make_install_arg' => q[], 
    'makepl_arg' => q[],
    'mbuild_arg' => q[],
    'mbuild_install_arg' => q[],
    'mbuild_install_build_command' => q[],
    'mbuildpl_arg' => q[],
    'ncftp' => q[],
    'ncftpget' => q[],
    'no_proxy' => q[],
    'pager' => q[$apps{less}],
    'prefer_installer' => q[MB],
    'prerequisites_policy' => q[follow],
    'scan_cache' => q[atstart],
    'shell' => q[$apps{bash}],
    'tar' => q[$apps{tar}],
    'term_is_latin' => q[1],
    'unzip' => q[$apps{unzip}],
    'urllist' => [
        q[ftp://carroll.cac.psu.edu/pub/CPAN/], q[ftp://cpan.pair.com/pub/CPAN/], q[ftp://cpan.uchicago.edu/pub/CPAN/],
    ],
    'wget' => q[$apps{wget}],
};

1;
__END__
__END_CPAN_CONFIG__

    close $fh;
}

# Upgrade CPAN now so we don't have to do the reload dance in the next script.
system(
    qq{$base_dir/bin/perl -MCPAN -e 'CPAN::Shell->install( "CPAN" )'},
);

# At this point, everything is prepared for CPAN installation.

if ( defined $opts{manifest} ) {
    (my $next_script = $0) =~ s!/[^/]*$!/install_cpan_modules.pl!;
    exec( "$base_dir/bin/perl $next_script -manifest $opts{manifest}" );
}

__END__

=head1 NAME

install_perl.pl

=head1 SYNOPSIS

install_perl.pl [-d directory] [-v perl_version] [-m manifest]

=head1 DESCRIPTION

Build a complete Perl and all CPAN modules in the specified directory. It takes the name
of a directory within which to install Perl. It then populates it with everything that
you specify.

=head1 OPTIONS

=over 4

=item directory (optional)

This is the directory within which the directory Perl is installed will be created. The
actual directory will be a subdirectory of this with a name of the timestamp of creation.
This defaults to '.'

=item * perl_version (optional)

This is the Perl version you wish to install. This defaults to 'stable'. If you choose to
specify a devel version, this script will still work as expected. (Tested using 5.9.5 to
exercise a bug in another module.)

=item manifest (optional)

This is the manifest of CPAN modules that will be passed to install_cpan_modules.pl
(provided with this distribution). That will install all the CPAN modules within the
just-built-perl's directory. If this is specified, then install_cpan_modules.pl will be
called. If it is not, then it will not be called. Please q.v. install_cpan_modules.pl for
the format of this file.

=back

=head1 SEE ALSO

install_cpan_modules.pl

=head1 AUTHOR

Rob Kinyon, L<rkinyon@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2007 Rob Kinyon. All Rights Reserved.
This is free software, you may use it and distribute it under the same terms
as Perl itself.

=cut
