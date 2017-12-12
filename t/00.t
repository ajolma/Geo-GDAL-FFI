use v5.10;
use Geo::GDAL::FFI;
use Test::More;

my $csl = Geo::GDAL::FFI::CSLAddString(0, 'foo');

$gdal = Geo::GDAL::FFI->new();
$gdal->AllRegister;

my $info = $gdal->VersionInfo;
say STDERR "info=$info";

ok($info, "Got info: $info");

my $ds = $gdal->Open('/home/ajolma/data/SmartSea/eusm2016-EPSG2393.tiff', 'ReadOnly');

say STDERR "Width = ",$ds->Width;

my $n = $gdal->GetDriverCount;
say STDERR $n;
for my $i (0..$n-1) {
    #say STDERR $gdal->GetDriver($i)->GetDescription;
}

my $dr = $gdal->GetDriverByName('GTiff');
$ds = $dr->Create('test.tiff', 20, 10, 2, 'UInt32', {TFW => 'YES'});
say STDERR $ds;

my $f;
{
    my $ds = $gdal->OpenEx('/home/ajolma/data/SmartSea/Liikennevirasto/vaylaalueet.shp');
    my $l = $ds->GetLayer;
    $l->ResetReading;
    say STDERR $l;
    $f = $l->GetNextFeature;
}
say STDERR $f;

done_testing();
