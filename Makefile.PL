use strict;
use warnings;


use ExtUtils::MakeMaker 6.52;


use Config;
my %args = (
    AUTHOR => ['Ari Jolma <ari.jolma at gmail.com>'],
    NAME => 'Geo::GDAL::FFI',
    ABSTRACT_FROM => "lib/Geo/GDAL/FFI.pm",
    VERSION_FROM => "lib/Geo/GDAL/FFI.pm",
    LICENSE => "artistic_2",
    CONFIGURE_REQUIRES => {
        'Alien::gdal' => 0,
    },
    PREREQ_PM => {
        'PkgConfig' => 0.23026,
        'FFI::Platypus' => 0.61,
        'PDL' => 0,
        'Sort::Versions' => 0,
        'Alien::gdal' => 0,
    },
    TEST_REQUIRES => {
        'Test::More'          => 0,
        'Test::Exception'     => 0,
        'JSON'                => 0,
        'Data::Dumper'        => 0,
        'Path::Tiny'          => 0,
        'Test::TempDir::Tiny' => 0,
    },
    META_MERGE => {
        "meta-spec" => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url => 'git://github.com/ajolma/Geo-GDAL-FFI.git',
                web => 'https://github.com/ajolma/Geo-GDAL-FFI',
            },
            bugtracker => {
                web => 'https://github.com/ajolma/Geo-GDAL-FFI/issues/',
            },
        },
    },
);

WriteMakefile(%args);
