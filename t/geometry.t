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

my $gdal = Geo::GDAL::FFI->new();
$gdal->AllRegister;

{
    my $geometry = Geo::GDAL::FFI::Geometry->new('Point');
    $geometry->ImportFromWkt('POINT(1 1)');
    ok($geometry->Type eq 'Point', "Create Point.");
    ok($geometry->AsWKT eq 'POINT (1 1)', "Import and export WKT");
}

{
    my $geometry = Geo::GDAL::FFI::Geometry->new(WKT => 'POINT(1 1)');
    ok($geometry->Type eq 'Point', "Create Point from WKT (1).");
    ok($geometry->AsWKT eq 'POINT (1 1)', "Create point from WKT (2).");
}

{
    my $geometry = Geo::GDAL::FFI::Geometry->new(WKT => 'POINTM(1 2 3)');
    my $type = $geometry->Type;
    ok($type eq 'PointM', "Create PointM from WKT: $type");
    my $wkt = $geometry->AsWKT;
    ok($wkt eq 'POINT M (1 2 3)', "Create point from WKT: $wkt");
}

done_testing();
