package Geo::GDAL::FFI::VSI::File;
use v5.10;
use strict;
use warnings;
use Carp;
use FFI::Platypus::Buffer;

our $VERSION = 0.05_03;

sub Open {
    my ($class, $name, $access) = @_;
    $access //= 'r';
    my $self = Geo::GDAL::FFI::VSIFOpenExL($name, $access, 1);
    unless ($self) {
        confess Geo::GDAL::FFI::error_msg() // "Failed to open '$name' with access '$access'.";
    }
    return bless \$self, $class;
}

sub Close {
    my ($self) = @_;
    my $e = Geo::GDAL::FFI::VSIFCloseL($$self);
    confess Geo::GDAL::FFI::error_msg() // "Failed to close a VSIFILE." if $e == -1;
}

sub Read {
    my ($self, $size, $count) = @_;
    my $buf = ' ' x ($size * $count);
    my ($pointer, $x) = scalar_to_buffer $buf;
    my $n = Geo::GDAL::FFI::VSIFReadL($pointer, $size, $count, $$self);
    return substr $buf, 0, $n;
}

sub Ingest {
    my ($self) = @_;
    my $s;
    my $e = Geo::GDAL::FFI::VSIIngestFile($$self, '', \$s, 0, -1);
    return $s;
}

1;

=pod

=encoding UTF-8

=head1 NAME

Geo::GDAL::FFI::VSI::File - A GDAL virtual file

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 Open

 my $vsifile = Geo::GDAL::FFI::VSI::File->Open($name, $access);

Open a virtual file. $name is the name of the file to open. $access is
'r', 'r+', 'a', or 'w'. 'r' is the default.

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
