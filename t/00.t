use v5.10;
use strict;
use warnings;
use Geo::GDAL::FFI;
use Test::More;

my @errors;

my $gdal = Geo::GDAL::FFI->new();

$gdal->PushErrorHandler(
    sub { 
        my ($err, $err_num, $msg) = @_;
        push @errors, $msg;
    }
);

$gdal->AllRegister;

# test error handler:
{
    my $ds = $gdal->Open('itsnotthere.tiff');
    ok(@errors == 1, "Got error: '$errors[0]'.");
    @errors = ();
}

# test CSL
{
    my $csl = Geo::GDAL::FFI::CSLAddString(0, 'foo');
    # actual test missing
}

# test VersionInfo
{
    my $info = $gdal->VersionInfo;
    ok($info, "Got info: '$info'.");
}

# test driver count
{
    my $n = $gdal->GetDriverCount;
    ok($n > 0, "Have $n drivers.");
    for my $i (0..$n-1) {
        #say STDERR $gdal->GetDriver($i)->GetDescription;
    }
}

# test creating a geometry object
{
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
