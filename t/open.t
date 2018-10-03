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

{
    my $gdal = Geo::GDAL::FFI->get_instance();
    my $ds = $gdal->GetDriver('ESRI Shapefile')->Create('test.shp');
    my $sr = Geo::GDAL::FFI::SpatialReference->new(EPSG => 3067);
    my $l = $ds->CreateLayer({Name => 'test', SpatialReference => $sr, GeometryType => 'Point'});
    my $d = $l->GetDefn();
    my $f = Geo::GDAL::FFI::Feature->new($d);
    $l->CreateFeature($f);
}

my $ds;

eval {
    my $gdal = Geo::GDAL::FFI->get_instance();
    $ds = $gdal->Open('test.shp', {
        Flags => [qw/READONLY VERBOSE_ERROR/], 
        AllowedDrivers => [('GML')]
    });
};
my @e = split /\n/, $@;
$e[0] =~ s/ at .*//;
ok($@, "Right driver not in AllowedDrivers: ".$e[0]);

eval {
    my $gdal = Geo::GDAL::FFI->get_instance();
    $ds = $gdal->Open('test.shp', {
        Flags => [qw/READONLY VERBOSE_ERROR/], 
        AllowedDrivers => [('GML', 'ESRI Shapefile')]
    });
};
ok(!@$, "Require right driver in AllowedDrivers");

unlink qw/test.dbf test.prj test.shp test.shx/;

done_testing();
