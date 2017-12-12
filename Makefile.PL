use Alien::gdal;
use ExtUtils::MakeMaker;
use Alien::Base::Wrapper qw( Alien::gdal !export );
use Config;
 
WriteMakefile(
    NAME => 'Geo::GDAL::FFI',
    Alien::Base::Wrapper->mm_args,
    );
