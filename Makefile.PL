use Alien::gdal;
use ExtUtils::MakeMaker;
use Alien::Base::Wrapper qw( Alien::gdal !export );
use Config;
 
WriteMakefile(
    NAME => 'Geo::GDAL::FFI',
    Alien::Base::Wrapper->mm_args,
    CONFIGURE_REQUIRES => {
        'Alien::gdal' => 0
    },
    PREREQ_PM => {
        'FFI::Platypus' => 0
    },
    TEST_REQUIRES => {
        'Test::More' => 0,
    }
);
