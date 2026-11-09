use strict;
use warnings;

use SemVer;
use FFI::CheckLib;
use FFI::Platypus;

my $MINIMUM_GDAL = '3.12.2';
my $ok = 0;
my ($version, $lib);
my $skip_alien = 0;

for (@ARGV) {
    $skip_alien = 1, last if /--skip-alient/;
}

unless ($skip_alien) {
    eval {
        require Alien::gdal;
        $lib = (Alien::gdal->dynamic_libs())[0];
        $version = Alien::gdal->version();
        print STDERR "You seem to have Alien::gdal ($lib, version $version). Will use that.\n";
        $lib = 'Alien::gdal';
        $ok = 1;
    };
    if ($@) {
        print STDERR "$@\n";
    }
}

for (@ARGV) {
    $ok = 1, last if /--skip-check/;
}

if (!$ok) {
    # Find the latest with shortest filename
    my $versions = my_find_lib();
    for my $fn (sort keys %$versions) {
        my $ver = $versions->{$fn};
        if (!$version or $ver > $version or ($ver == $version and length($fn) < length($lib))) {
            $version = $ver;
            $lib = $fn;
        }
        #print "$lib => $versions->{$lib}\n";
    }
    my $minimum = SemVer->new($MINIMUM_GDAL);
    if (!$version) {
        print "GDAL was NOT found.\n";
    } elsif ($version < $minimum) {
        print "Version $version GDAL was found in $lib, but it is too old.\n";
    } else {
        print "Usable version $version GDAL was found in $lib.\n";
        $ok = 1;
    }
    if (!$ok) {
        print "Either install libgdal or install Alien::gdal.\n";
        print "You can skip this step with --skip-check.\n";
        exit(1);
    }
}

if ($lib) {
    open(FH, '>', 'lib/Geo/GDAL/FFI/lib.pm') or die $!;
    print FH "package Geo::GDAL::FFI::lib;\nour \$libgdal = '$lib';\n";
    close(FH);
} else {
    unlink('lib/Geo/GDAL/FFI/lib.pm');
    unlink('blib/lib/Geo/GDAL/FFI/lib.pm')
}

use ExtUtils::MakeMaker 6.52;


use Config;
my %args = (
    AUTHOR => ['Ari Jolma <ari.jolma at gmail.com>'],
    NAME => 'Geo::GDAL::FFI',
    ABSTRACT_FROM => "lib/Geo/GDAL/FFI.pm",
    VERSION_FROM => "lib/Geo/GDAL/FFI.pm",
    LICENSE => "artistic_2",
    MIN_PERL_VERSION => '5.010',
    CONFIGURE_REQUIRES => {
        'SemVer' => 0,
        'FFI::CheckLib' => 0,
        'FFI::Platypus' => 0,
    },
    PREREQ_PM => {
        'PkgConfig' => 0.23026,
        'FFI::CheckLib' => 0,
        'FFI::Platypus' => 0,
        'SemVer' => 0,
    },
    TEST_REQUIRES => {
        'JSON'                => 0,
        'Data::Dumper'        => 0,
        'Path::Tiny'          => 0,
        'Test::More'          => 0,
        'Test::Exception'     => 0,
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

sub my_find_lib {
    my %versions;
    my ($lib) = find_lib(
        lib => 'gdal',
        verify => sub {
            my($name, $libpath) = @_;
            my $ffi = FFI::Platypus->new;
            $ffi->lib($libpath);
            my $f = $ffi->function('GDALVersionInfo', [qw/string/] => 'string');
            my $gdal_version = SemVer->new($f->call('RELEASE_NAME'));
            $versions{$libpath} = $gdal_version;
            return 0;
        },
    );
    return \%versions;
}
