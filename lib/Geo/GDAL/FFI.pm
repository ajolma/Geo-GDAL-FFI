package Geo::GDAL::FFI;

use v5.10;

use Alien::gdal;
use FFI::Platypus;

my $ffi = FFI::Platypus->new;
$ffi->lib(Alien::gdal->dynamic_libs);

$ffi->attach( 'GDALAllRegister' => [] => 'void' );
$ffi->attach( 'GDALVersionInfo' => ['string'] => 'string' );
$ffi->attach( 'GDALOpen' => ['string', 'sint32'] => 'opaque' );
$ffi->attach( 'GDALGetRasterXSize' => ['opaque'] => 'int' );

1;
