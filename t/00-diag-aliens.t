use strict;
use warnings;
use Test::More;

diag '';
diag 'Aliens:';
my %alien_versions;
my @aliens = qw /
    Alien::gdal   Alien::geos::af  Alien::sqlite
    Alien::proj   Alien::libtiff   Alien::spatialite
    Alien::freexl
/;
my %optional = map {$_ => 1} qw /Alien::spatialite Alien::freexl/;
#  use our own in case List::Util is not installed, although it should be...
my $longest_name = 0;
foreach my $len (map {length} @aliens) {
    $longest_name = $len if $len > $longest_name;
}
foreach my $alien (@aliens) {
    eval "require $alien; 1";
    if ($@) {
        #diag "$alien not installed";
        my $optional_text = $optional{$alien} ? "(optional module)" : '';
        diag sprintf "%-${longest_name}s: not installed $optional_text", $alien;
        next;
    }
    diag sprintf "%-${longest_name}s: version:%7s, install type: %s",
        $alien,
        $alien->version // 'unknown',
        $alien->install_type;
    $alien_versions{$alien} = $alien->version;
}

if ($alien_versions{'Alien::gdal'} ge 3) {
    if ($alien_versions{'Alien::proj'} lt 7) {
        diag 'Alien proj is <7 when gdal >=3';
    }
}
else {
    if ($alien_versions{'Alien::proj'} ge 7) {
        diag 'Alien proj is >=7 when gdal <3';
    }
}

my $have_ldd = ($^O ne 'MSWin32' && $^O !~ /darwin/i) && !!`ldd --help`;
if (Alien::gdal->install_type eq 'share' && $have_ldd) {
    my $dylib = Alien::gdal->dist_dir . '/lib/libgdal.so';
    if (-e $dylib) {
        my @deps = `ldd $dylib`;
        my %collated;

        #  https://gdal.org/en/latest/development/building_from_source.html#conflicting-proj-libraries
        #  blunt approach but proj is the main culprit and there seem to be some legit double ups.
        foreach my $line (@deps) {
            $line =~ s/[\r\n]+//g;
            # diag $line;
            $line =~ s/^\s+//;
            my ($lib, $path) = split /\s+=>\s+/, $line, 2;
            # diag "$lib --- $path";
            next if !$path;
            $lib =~ s/\.so.+//;
            next if $path =~ m{^/lib};
            my $aref = $collated{$lib} //= [];
            push @$aref, $path;
        }
        foreach my $key (keys %collated) {
            my $aref = $collated{$key} // [];
            if (@$aref <= 1) {
                delete $collated{$key};
            }
        }
        # my $res = is (scalar keys %collated, 0, "No duplicate dependencies.");
        if (keys %collated) {
            diag "Potentially clashing dynamic libs detected, segfaults are possible.";
            foreach my $key (sort keys %collated) {
                diag "$key => " . join ' ', @{$collated{$key}};
            }
        }
    }
}

ok (1);
done_testing();

