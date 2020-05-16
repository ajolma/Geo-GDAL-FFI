use v5.10;
use strict;
use warnings;
use Carp;
use Encode qw(decode encode);
use Geo::GDAL::FFI;
use Test::More;
use Data::Dumper;
use JSON;
use FFI::Platypus::Buffer;

my $gdal = Geo::GDAL::FFI->get_instance();

{
    SKIP: {
      skip "GDAL support files not found.", 1 if !$gdal->FindFile('gcs.csv');
      my $sr = Geo::GDAL::FFI::SpatialReference->new(EPSG => 3067);
      ok($sr->Export('Wkt') =~ /^PROJCS/, 'SpatialReference constructor and WKT export');
    }
}

done_testing();
