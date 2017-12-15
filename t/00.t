use v5.10;
use strict;
use warnings;
use Carp;
use Geo::GDAL::FFI;
use Test::More;

my $gdal = Geo::GDAL::FFI->new();

$gdal->AllRegister;

# test error handler:
if(1){
    eval {
        my $ds = $gdal->Open('itsnotthere.tiff');
    };
    ok(defined $@, "Got error: '$@'.");
}

# test CSL
if(1){
    ok(Geo::GDAL::FFI::CSLCount(0) == 0, "empty CSL");
    my @list;
    my $csl = Geo::GDAL::FFI::CSLAddString(0, 'foo');
    for my $i (0..Geo::GDAL::FFI::CSLCount($csl)-1) {
        push @list, Geo::GDAL::FFI::CSLGetField($csl, $i);
    }
    ok(@list == 1 && $list[0] eq 'foo', "list with one string: '@list'");
}

# test VersionInfo
if(1){
    my $info = $gdal->VersionInfo;
    ok($info, "Got info: '$info'.");
}

# test driver count
if(1){
    my $n = $gdal->GetDriverCount;
    ok($n > 0, "Have $n drivers.");
    for my $i (0..$n-1) {
        #say STDERR $gdal->GetDriver($i)->GetDescription;
    }
}

# test metadata
if(1){
    my $dr = $gdal->GetDriverByName('NITF');
    my $ds = $dr->Create('/vsimem/test.nitf');
    my @d = $ds->GetMetadataDomainList;
    ok(@d > 0, "GetMetadataDomainList");
    @d = $ds->GetMetadata('NITF_METADATA');
    ok(@d > 0, "GetMetadata");
    $ds->SetMetadata({a => 'b'});
    @d = $ds->GetMetadata();
    ok("@d" eq "a b", "GetMetadata");
    #say STDERR join(',', @d);
}

# test creating a shapefile
if(1){
    my $dr = $gdal->GetDriverByName('ESRI Shapefile');
    my $ds = $dr->Create('test.shp');
    my $sr = Geo::GDAL::FFI::SpatialReference->new();
    $sr->ImportFromEPSG(3067);
    my $l = $ds->CreateLayer('test', $sr, 'Point');
    my $d = $l->GetDefn();
    my $f = Geo::GDAL::FFI::Feature->new($d);
    $l->CreateFeature($f);
}
if(1){
    my $ds = $gdal->OpenEx('test.shp');
    my $l = $ds->GetLayer;
    my $d = $l->GetDefn();
    ok($d->GetGeomType eq 'Point', "Create point shapefile and open it.");
}

# test creating a geometry object
if(1){
    my $g = Geo::GDAL::FFI::Geometry->new('Point');
    my $wkt = $g->ExportToWkt;
    ok($wkt eq 'POINT EMPTY', "Got WKT: '$wkt'.");
}

done_testing();
exit;

my $ds = $gdal->Open('/home/ajolma/data/SmartSea/eusm2016-EPSG2393.tiff', 'ReadOnly');
say STDERR "Width = ",$ds->Width;

my $dr = $gdal->GetDriverByName('GTiff');
$ds = $dr->Create('test.tiff', 20, 10, 2, 'UInt32', {TFW => 'YES'});
say STDERR $ds;

my $f;
{
    my $ds = $gdal->OpenEx('/home/ajolma/data/SmartSea/Liikennevirasto/vaylaalueet.shp2');
    my $l = $ds->GetLayer;
    $l->ResetReading;
    say STDERR $l;
    $f = $l->GetNextFeature;
}
say STDERR $f;

done_testing();
