use v5.10;
use strict;
use warnings;
use Carp;
use Geo::GDAL::FFI;
use Test::More;
use Data::Dumper;

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

# test dataset

if(1){
    my $dr = $gdal->GetDriverByName('GTiff');
    my $ds = $dr->Create('/vsimem/test.tiff');
    my $ogc_wkt = 
        'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS84",6378137,298.257223563,'.
        'AUTHORITY["EPSG","7030"]],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,'.
        'AUTHORITY["EPSG","8901"]],UNIT["degree",0.01745329251994328,'.
        'AUTHORITY["EPSG","9122"]],AUTHORITY["EPSG","4326"]]';
    $ds->SetProjectionString($ogc_wkt);
    my $p = $ds->GetProjectionString;
    ok($p eq $ogc_wkt, "Set/get projection string");
    my $transform = [10,2,0,20,0,3];
    $ds->SetGeoTransform($transform);
    my $t = $ds->GetGeoTransform;
    is_deeply($t, $transform, "Set/get geotransform");
    
}
#done_testing();
#exit;

# test band
if(1){
    my $dr = $gdal->GetDriverByName('GTiff');
    my $ds = $dr->Create('/vsimem/test.tiff');
    my $b = $ds->GetBand;
    #say STDERR $b;
    my @size = $b->GetBlockSize;
    #say STDERR "block size = @size";
    ok($size[0] == 256 && $size[1] == 32, "Band block size.");
    my @data = (
        [1, 2, 3],
        [4, 5, 6]
        );
    $b->Write(\@data);
    my $data = $b->Read(0, 0, 3, 2);
    is_deeply(\@data, $data, "Raster i/o");

    $ds->FlushCache;
    my $block = $b->ReadBlock();
    for my $ln (@$block) {
        #say STDERR "@$ln";
    }
    ok(@{$block->[0]} == 256 && @$block == 32 && $block->[1][2] == 6, "Read block ($block->[1][2])");
    $block->[1][2] = 7;
    $b->WriteBlock($block);
    $block = $b->ReadBlock();
    ok($block->[1][2] == 7, "Write block ($block->[1][2])");

    my $v = $b->GetNoDataValue;
    ok(!defined($v), "Get nodata value.");
    $b->SetNoDataValue(13);
    $v = $b->GetNoDataValue;
    ok($v == 13, "Set nodata value.");
    $b->SetNoDataValue();
    $v = $b->GetNoDataValue;
    ok(!defined($v), "Delete nodata value.");
    # the color table test with GTiff fails with
    # Cannot modify tag "PhotometricInterpretation" while writing at (a line afterwards this).
    # should investigate why
    #$b->SetColorTable([[1,2,3,4],[5,6,7,8]]);
}
if(1) {
    my $dr = $gdal->GetDriverByName('MEM');
    my $ds = $dr->Create();
    my $b = $ds->GetBand;
    my $table = [[1,2,3,4],[5,6,7,8]];
    $b->SetColorTable($table);
    my $t = $b->GetColorTable;
    is_deeply($t, $table, "Set/get color table");
    $b->SetColorInterpretation('PaletteIndex');
    $ds->FlushCache;
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
    $g->ImportFromWkt('POINT (1 2)');
    ok($g->ExportToWkt eq 'POINT (1 2)', "Import from WKT");
    ok($g->GetPointCount == 1, "Point count");
    my @p = $g->GetPoint;
    ok(@p == 2 && $p[0] == 1 && $p[1] == 2, "Get point");
    $g->SetPoint(2, 3, 4, 5);
    @p = $g->GetPoint;
    ok(@p == 2 && $p[0] == 2 && $p[1] == 3, "Set point: @p");
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
