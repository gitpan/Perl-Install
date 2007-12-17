#!/usr/bin/perl

use 5.006_000;

use strict;
use warnings FATAL => 'all';

use CPAN 1.9; # The notest() method is 1.9+

use File::Spec::Functions qw( catfile updir );
use Getopt::Long;
use Pod::Usage qw( pod2usage );

my %opts = (
);
GetOptions( \%opts,
    'manifest|m=s',
    'help|?',
    'man',
) or pod2usage( 2 );
pod2usage( 1 ) if $opts{help};
pod2usage( -exitstatus => 0, -verbose => 2 ) if $opts{man};

if ( !defined $opts{manifest} ) {
    pod2usage( -exitstatus => 1, -verbose => 1 );
}

unless ( -f $opts{manifest} ) {
    pod2usage(
        -exitstatus => 1,
        -message => "\n-manifest '$opts{manifest}' isn't a file",
    );
}

my @modules;
{
    open my $fh, '<', $opts{manifest}
        or die "Cannot open '$opts{manifest}' for reading: $!\n";

    while (defined( my $line = <$fh>)) {
        next if $line =~ /^\s*#/;

        chomp $line;
        next unless $line;

        my ($name) = $line =~ /(\S+)/;

        push @modules, {
            name => $name,
        };
    }
    close $fh;
}

{
    local $ENV{PERL_MM_USE_DEFAULT} = 1;

    foreach my $module ( @modules ) {
        my $name = $module->{name};
        eval {
            print "Attempting to install $name\n";
            my $obj = CPAN::Shell->expandany( $name );

            unless ( $obj->uptodate ) {
                CPAN::Shell->notest( install => $obj );
                unless ( $obj->uptodate ) {
                    die "Installation of $name appears to have failed";
                }
            }
        }; if ( $@ ) {
            print "\n********\n";
            die "Install of $name failed: $@\n";
        }
    }
}

__END__

=head1 NAME

install_cpan_modules.pl

=head1 SYNOPSIS

install_cpan_modules.pl [OPTIONS]

=head1 DESCRIPTION

Install all the specified CPAN modules listed in a file.

=head1 OPTIONS

=over 4

=item manifest (optional)

This is the file that contains all the modules to be installed in order. It has
no default.

=back

=head1 MANIFEST FILE

The manifest file is a simple list of module names you want to install. The modules
will be installed in the order listed. If a line starts with a #, it will be ignored.
An example could be:

  # Handle Catalyst needs
  Catalyst
  Catalyst::Plugin::Session::Store::File
  Catalyst::Plugin::Session::State::Cookie

  # Handle DBIx::Class
  DBIx::Class
  
  # Other stuff below here

=head1 AUTHOR

Rob Kinyon, L<rkinyon@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2007 Rob Kinyon. All Rights Reserved.
This is free software, you may use it and distribute it under the same terms
as Perl itself.

=cut
