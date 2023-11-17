use v5.10;
use strict;
use warnings;
use Carp;
use Geo::GDAL::FFI;
use Test::More;

# test about SRS transformations API by using a simple extent (4 points) in UTM33 -> WGS84

if(1) {
    my $source_srs = Geo::GDAL::FFI::SpatialReference->new( EPSG => 4326 );
    my $target_srs = Geo::GDAL::FFI::SpatialReference->new( EPSG => 32633 );
    my $ct = Geo::GDAL::FFI::OCTNewCoordinateTransformation($$source_srs, $$target_srs);

    my @extent = (16.509888, 41.006911, 17.084248, 41.370581);

    my @ul = ($extent[0], $extent[1]);
    my @lr = ($extent[2], $extent[3]);
	my @ur = ($lr[0],$ul[1]);
	my @ll = ($ul[0],$lr[1]);
    my $result = "3358768.81711923 3391240.32068776 3348976.84626544 3401215.87353221 2019470.50927319 2094945.30821076 2088830.64307375 2025411.23009774";

    my @x = ($ul[0], $lr[0], $ur[0], $ll[0]);
    my @y = ($ul[1], $lr[1], $ur[1], $ll[1]);
    my $z = undef;
    ok(Geo::GDAL::FFI::OCTTransform($ct, 4, \@x, \@y, \@$z), "Coordinate transformation 3D worked");
    ok(qq/@x @y/ eq $result, "Resulting coordinates");

    @x = ($ul[0], $lr[0], $ur[0], $ll[0]);
    @y = ($ul[1], $lr[1], $ur[1], $ll[1]);
    $z = undef;
    my @ps = (0,0,0,0);
    ok(Geo::GDAL::FFI::OCTTransformEx($ct, 4, \@x, \@y, \@$z, \@ps), "Coordinate transformation 3D with pabSuccess worked");
    ok(qq/@x @y/ eq $result, "Resulting coordinates");
    ok(scalar @ps == 4 && qq/@ps/ eq qq/1 1 1 1/, "Resulting pabSuccess is TRUE x 4" );

    @x = ($ul[0], $lr[0], $ur[0], $ll[0]);
    @y = ($ul[1], $lr[1], $ur[1], $ll[1]);
    $z = undef;
    my $t = undef;
    @ps = (0,0,0,0);
    ok(Geo::GDAL::FFI::OCTTransform4D($ct, 4, \@x, \@y, \@$z, \@$t, \@ps), "Coordinate transformation 4D worked");
    ok(qq/@x @y/ eq $result && qq/@ps/ eq qq/1 1 1 1/, "Resulting coordinates");

    @x = ($ul[0], $lr[0], $ur[0], $ll[0]);
    @y = ($ul[1], $lr[1], $ur[1], $ll[1]);
    $z = undef;
    $t = undef;
    @ps = (0,0,0,0);
    ok(Geo::GDAL::FFI::OCTTransform4DWithErrorCodes($ct, 4, \@x, \@y, \@$z, \@$t, \@ps), "Coordinate transformation 4D worked");
    ok(qq/@x @y/ eq $result, "Resulting coordinates");
    ok(scalar @ps == 4 && qq/@ps/ eq qq/0 0 0 0/, "Resulting pabSuccess is SUCCESS(i.e. 0) x 4" );
}

done_testing();
