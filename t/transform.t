use v5.10;
use strict;
use warnings;
use Carp;
use Geo::GDAL::FFI;
use Test::More;

# test about SRS transformations API by using a simple extent (4 points) in UTM33 -> WGS84

#  some systems return high precision values so standardise at 6dp
sub set_precision {
    map {sprintf "%.6f", $_} @_;
}

if(1) {
    my $source_srs = Geo::GDAL::FFI::SpatialReference->new( EPSG => 4326 );
    my $target_srs = Geo::GDAL::FFI::SpatialReference->new( EPSG => 32633 );
    my $ct = Geo::GDAL::FFI::OCTNewCoordinateTransformation($$source_srs, $$target_srs);

    my @extent = (16.509888, 41.006911, 17.084248, 41.370581);

    my @ul = ($extent[0], $extent[1]);
    my @lr = ($extent[2], $extent[3]);
	my @ur = ($lr[0],$ul[1]);
	my @ll = ($ul[0],$lr[1]);
    my @result = set_precision (qw/3358768.81711923 3391240.32068776 3348976.84626544 3401215.87353221 2019470.50927319 2094945.30821076 2088830.64307375 2025411.23009774/);

    my @x = ($ul[0], $lr[0], $ur[0], $ll[0]);
    my @y = ($ul[1], $lr[1], $ur[1], $ll[1]);
    my $z = undef;
    my $res = Geo::GDAL::FFI::OCTTransform($ct, 4, \@x, \@y, \@$z);
    is($res, 1, "Coordinate transformation 3D worked");
    is_deeply([set_precision (@x, @y)], \@result, "Checking resulting coordinates");

    @x = ($ul[0], $lr[0], $ur[0], $ll[0]);
    @y = ($ul[1], $lr[1], $ur[1], $ll[1]);
    $z = undef;
    my @ps = (0,0,0,0);
    $res = Geo::GDAL::FFI::OCTTransformEx($ct, 4, \@x, \@y, \@$z, \@ps);
    is($res, 1, "Coordinate transformation 3D with pabSuccess worked");
    is_deeply([set_precision (@x, @y)], \@result, "Checking resulting coordinates");
    is(scalar @ps, 4, "Resulting pabSuccess is an array of size 4");
    is_deeply(\@ps, [1, 1, 1, 1], "Resulting pabSuccess is TRUE x 4" );

    @x = ($ul[0], $lr[0], $ur[0], $ll[0]);
    @y = ($ul[1], $lr[1], $ur[1], $ll[1]);
    $z = undef;
    my $t = undef;
    @ps = (0,0,0,0);
    $res = Geo::GDAL::FFI::OCTTransform4D($ct, 4, \@x, \@y, \@$z, \@$t, \@ps);
    is($res, 1, "Coordinate transformation 4D worked");
    is_deeply([set_precision (@x, @y), @ps], [@result, 1, 1, 1, 1], "Checking resulting coordinates");

    @x = ($ul[0], $lr[0], $ur[0], $ll[0]);
    @y = ($ul[1], $lr[1], $ur[1], $ll[1]);
    $z = undef;
    $t = undef;
    @ps = (0,0,0,0);
    $res = Geo::GDAL::FFI::OCTTransform4DWithErrorCodes($ct, 4, \@x, \@y, \@$z, \@$t, \@ps);
    is($res, 1, "Coordinate transformation 4D worked");
    is_deeply([set_precision (@x, @y)], \@result, "Checking resulting coordinates");
    is(scalar @ps, 4, "Resulting pabSuccess is an array of size 4");
    is_deeply(\@ps, [0, 0, 0, 0], "Resulting pabSuccess is SUCCESS(i.e. 0) x 4" );
}

done_testing();
