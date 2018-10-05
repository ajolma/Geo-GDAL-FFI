package Geo::GDAL::FFI::VSI;
use v5.10;
use strict;
use warnings;
use Carp;
use FFI::Platypus::Buffer;
require Exporter;

our $VERSION = 0.05_03;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(ReadDir);

sub ReadDir {
    my ($dir, $max_files) = @_;
    $max_files //= 0;
    my $csl = Geo::GDAL::FFI::ReadDirEx($dir, $max_files);
    my @dir;
    for my $i (0 .. Geo::GDAL::FFI::CSLCount($csl)-1) {
        push @dir, Geo::GDAL::FFI::CSLGetField($csl, $i);
    }
    return @dir;
}

1;

=pod

=encoding UTF-8

=head1 NAME

Geo::GDAL::FFI::VSI - A GDAL virtual file system

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 ReadDir

=head1 LICENSE

This software is released under the Artistic License. See
L<perlartistic>.

=head1 AUTHOR

Ari Jolma - Ari.Jolma at gmail.com

=head1 SEE ALSO

L<Geo::GDAL::FFI>

L<Alien::gdal>, L<FFI::Platypus>, L<http://www.gdal.org>

=cut

__END__;
