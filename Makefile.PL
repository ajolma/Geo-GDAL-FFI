use strict;
use warnings;

<<<<<<< HEAD

use ExtUtils::MakeMaker 6.52;


=======
my $have_alien;
BEGIN {
    my $gdal = 'Alien::gdal';
    my @argv = ();
    for (@ARGV) {
        if (/GDAL=(.+)/) {
            $gdal = $1;
        } else {
            push @argv, $_;
        }
    }
    @ARGV = @argv;
    eval "use Alien::gdal" if $gdal eq 'Alien::gdal';
    if ($gdal ne 'Alien::gdal' or $@) {
        if ($gdal eq 'Alien::gdal') {
            print "I can't find Alien::gdal.\n";
            $gdal = '/usr';
        }
        print "Trying GDAL from '$gdal'.\n";
        $have_alien = 0;
        my $version = `$gdal/bin/gdalinfo --version`;
        unless ($version) {
            print "I can't find gdal in '$gdal', I'm sorry.\n";
            exit(1);
        }
        $version = $1 if $version =~ /(\d+\.\d+\.\d+)/;
        my @a = (grep {-l} glob("$gdal/lib/libgdal*"));
        my $lib = $a[0];
        my $data = "$gdal/share/gdal";
        print "I'm creating Geo::GDAL::gdal as a wrapper to $lib, which I believe is GDAL $version.\n";
        my $fh = IO::File->new;
        $fh->open("lib/Geo/GDAL/gdal.pm","w");
        print $fh <<EOF;
package Geo::GDAL::gdal;
use strict;
use warnings;
sub new {
    return shift;
}
sub version {
    return '$version';
}
sub data_dir {
    return ('$data');
}
sub dynamic_libs {
    return '$lib';
}
1;
EOF
    } else {
        eval "use Alien::Base::Wrapper qw(Alien::gdal !export)";
        $have_alien = 1;
        my $fh = IO::File->new;
        $fh->open("lib/Geo/GDAL/gdal.pm","w");
        print $fh <<EOF;
package Geo::GDAL::gdal;
use strict;
use warnings;
1;
EOF
    }
}
use ExtUtils::MakeMaker;
>>>>>>> 2bc66d6 (use strict and warnings in Makefile.PL)
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
if ($have_alien) {
    %args = (%args, Alien::Base::Wrapper->mm_args);
}

WriteMakefile(%args);
