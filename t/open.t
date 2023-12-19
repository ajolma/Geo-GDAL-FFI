use v5.10;
use strict;
use warnings;
use Carp;
use Encode qw(decode encode);
use Geo::GDAL::FFI qw/GetDriver Open/;
use Test::More;
use Data::Dumper;
use JSON;
use FFI::Platypus::Buffer;
use Path::Tiny qw/path/;
use Test::TempDir::Tiny;

my $dir = tempdir();
my $testfile = path($dir, 'test.shp');

{
    my $ds = GetDriver('ESRI Shapefile')->Create($testfile);
    my $sr = Geo::GDAL::FFI::SpatialReference->new(EPSG => 3067);
    my $l = $ds->CreateLayer({Name => 'test', SpatialReference => $sr, GeometryType => 'Point'});
    my $d = $l->GetDefn();
    my $f = Geo::GDAL::FFI::Feature->new($d);
    $l->CreateFeature($f);
}

my $ds;

eval {
    $ds = Open($testfile, {
        Flags => [qw/READONLY VERBOSE_ERROR/], 
        AllowedDrivers => [('GML')]
    });
};
my @e = split /\n/, $@;
$e[0] =~ s/ at .*//;
ok($@, "Right driver not in AllowedDrivers: ".$e[0]);

eval {
    $ds = Open($testfile, {
        Flags => [qw/READONLY VERBOSE_ERROR/], 
        AllowedDrivers => [('GML', 'ESRI Shapefile')]
    });
};
ok(!@$, "Require right driver in AllowedDrivers");

done_testing();
