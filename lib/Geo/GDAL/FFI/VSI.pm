package Geo::GDAL::FFI::VSI;
use v5.10;
use strict;
use warnings;
use Carp;
use FFI::Platypus::Buffer;
require Exporter;

our $VERSION = 0.05_03;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(Mkdir ReadDir FOpen);

sub FOpen {
    return Geo::GDAL::FFI::VSI::File->Open(@_);
}

sub Mkdir {
    my ($path, $mode) = @_;
    $mode //= hex '0x0666';
    my $e = Geo::GDAL::FFI::VSIMkdir($path, $mode);
    confess Geo::GDAL::FFI::error_msg() // "Failed to mkdir '$path'." if $e == -1;
}

sub ReadDir {
    my ($path, $max_files) = @_;
    $max_files //= 0;
    my $csl = Geo::GDAL::FFI::VSIReadDirEx($path, $max_files);
    my @dir;
    for my $i (0 .. Geo::GDAL::FFI::CSLCount($csl)-1) {
        push @dir, Geo::GDAL::FFI::CSLGetField($csl, $i);
    }
    Geo::GDAL::FFI::CSLDestroy($csl);
    return @dir;
}

1;

=pod

=encoding UTF-8

=head1 NAME

Geo::GDAL::FFI::VSI - A GDAL virtual file system

=head1 SYNOPSIS

use Geo::GDAL::FFI::VSI qw/FOpen Mkdir ReadDir/;

=head1 DESCRIPTION

=head1 METHODS

=head2 FOpen($path, $access)

 my $file = FOpen('/vsimem/file', 'w');

Short for Geo::GDAL::FFI::VSI::File::Open

=head2 Mkdir($path, $mode)

$mode is optional and by default 0x0666.

=head2 ReadDir($path, $max_files)

$max_files is optional and by default 0, i.e., read all names of files
in the dir.

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
