use v5.10;
use Geo::GDAL::FFI;

say STDERR Geo::GDAL::FFI::GDALVersionInfo();
Geo::GDAL::FFI::GDALAllRegister();
my $ds = Geo::GDAL::FFI::GDALOpen('/home/ajolma/data/SmartSea/eusm2016-EPSG2393.tiff', 0);
say STDERR Geo::GDAL::FFI::GDALGetRasterXSize($ds);
