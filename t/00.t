use v5.10;
use Geo::GDAL::FFI;
use Test::More;

my $info = Geo::GDAL::FFI::GDALVersionInfo();
ok($info, "Got info: $info");
#Geo::GDAL::FFI::GDALAllRegister();
#my $ds = Geo::GDAL::FFI::GDALOpen('/home/ajolma/data/SmartSea/eusm2016-EPSG2393.tiff', 0);
#say STDERR Geo::GDAL::FFI::GDALGetRasterXSize($ds);

done_testing();
