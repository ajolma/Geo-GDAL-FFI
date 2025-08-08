use v5.10;
use strict;
use warnings;
use Carp;
use Geo::GDAL::FFI qw/GetDriver HaveGEOS/;
use Test::More;
use Test::Exception;
use Data::Dumper;
use Test::TempDir::Tiny;
use Path::Tiny qw/path/;

my $dir = tempdir();
my $gpkg_file = path ($dir, 'test.gpkg');
my $ds = GetDriver('GPKG')->Create($gpkg_file);
my $sr = Geo::GDAL::FFI::SpatialReference->new(EPSG => 3067);
my @layernames;
foreach my $i (1..3) {
    my $name = "test$i";
    push @layernames, $name;
    my $l = $ds->CreateLayer({
        Name => $name,
        SpatialReference => $sr,
        GeometryType => 'Point',
    });
    my $d = $l->GetDefn();
    my $f = Geo::GDAL::FFI::Feature->new($d);
    $l->CreateFeature($f);

}


is ($ds->GetLayerCount, 3, 'Got expected number of layers');


{
    my $ds2 = Geo::GDAL::FFI::Open($gpkg_file);
    for my $i (0 .. $ds2->GetLayerCount - 1) {
        my $layer = $ds2->GetLayer($i);
        ok($layer, "Got layer $i");
        is ($layer->GetName, $layernames[$i], 'Layer has expected name');
    }

    for my $i (0 .. $ds2->GetLayerCount - 1) {
        my $layer = $ds2->GetLayerByIndex($i);
        ok($ds2, "Got layer by index $i");
        is ($layer->GetName, $layernames[$i], 'Layer has expected name');
    }

    for my $i (0 .. $ds2->GetLayerCount - 1) {
        my $name = $layernames[$i];
        my $layer = $ds2->GetLayerByName($name);
        ok($ds2, "Got layer by name $name, index $i");
        is ($layer->GetName, $name, 'Layer has expected name');
    }
}

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
if(0) { # dataset metadata test
    $ds->SetMetadata({'d' => {'a' => 'b'}});
    my $md = $ds->GetMetadata();
    for my $d (keys %$md) {
        say 'domain ',$d;
        for (keys %{$md->{$d}}) {
            say $_, '=>', $md->{$d}{$_};
        }
    }
}


done_testing();
