use v5.10;
use strict;
use warnings;
use Carp;
use Geo::GDAL::FFI qw/GetDriver HaveGEOS/;
use Test::More;
use Test::Exception;
use Data::Dumper;

my $ds = GetDriver('GPKG')->Create('test.gpkg');
my $sr = Geo::GDAL::FFI::SpatialReference->new(EPSG => 3067);
foreach my $i (1..3) {
    my $l = $ds->CreateLayer({
        Name => "test$i",
        SpatialReference => $sr,
        GeometryType => 'Point',
    });
    my $d = $l->GetDefn();
    my $f = Geo::GDAL::FFI::Feature->new($d);
    $l->CreateFeature($f);
}


is ($ds->GetLayerCount, 3, 'Got expected number of layers');

dies_ok (
    sub {$ds->GetLayer ('not_exists')},
    'GetLayer exception for non-existent layer name',
);
dies_ok (
    sub {$ds->GetLayer (23)},
    'GetLayer exception for too large index',
);
dies_ok (
    sub {$ds->GetLayer (-1)},
    'GetLayer exception for negative index',
);


done_testing();
