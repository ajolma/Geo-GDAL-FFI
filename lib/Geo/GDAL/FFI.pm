package Geo::GDAL::FFI;

use v5.10;
use Carp;
use Alien::gdal;
use FFI::Platypus;

my $ffi = FFI::Platypus->new;
$ffi->lib(Alien::gdal->dynamic_libs);

$ffi->attach( 'CSLAddString' => ['opaque', 'string'] => 'opaque' );

$ffi->attach( 'GDALAllRegister' => [] => 'void' );
$ffi->attach( 'GDALGetDescription' => ['opaque'] => 'string' );
$ffi->attach( 'GDALGetDriverCount' => [] => 'int' );
$ffi->attach( 'GDALGetDriver' => ['int'] => 'opaque' );
$ffi->attach( 'GDALGetDriverByName' => ['string'] => 'opaque' );
$ffi->attach( 'GDALCreate' => ['opaque', 'string', 'int', 'int', 'int', 'int', 'opaque'] => 'opaque' );
$ffi->attach( 'GDALVersionInfo' => ['string'] => 'string' );
$ffi->attach( 'GDALOpen' => ['string', 'int'] => 'opaque' );
$ffi->attach( 'GDALOpenEx' => ['string', 'unsigned int', 'opaque', 'opaque', 'opaque'] => 'opaque' );
$ffi->attach( 'GDALGetRasterXSize' => ['opaque'] => 'int' );
$ffi->attach( 'GDALDatasetGetLayer' => ['opaque', 'int'] => 'opaque' );
$ffi->attach( 'OGR_L_ResetReading' => ['opaque'] => 'void' );
$ffi->attach( 'OGR_L_GetNextFeature' => ['opaque'] => 'opaque' );

sub new {
    my $class = shift;
    return bless {}, $class;
}

*AllRegister = *GDALAllRegister;

sub VersionInfo {
    shift;
    return GDALVersionInfo(@_);
}

sub GetDriverCount {
    return GDALGetDriverCount();
}

sub GetDriver {
    my ($self, $i) = @_;
    my $d = GDALGetDriver($i);
    return bless \$d, 'Geo::GDAL::FFI::Driver';
}

sub GetDriverByName {
    shift;
    my $d = GDALGetDriverByName(@_);
    return bless \$d, 'Geo::GDAL::FFI::Driver';
}

our %access = (
    ReadOnly => 0,
    Update => 1
    );

sub Open {
    shift;
    my ($name, $access) = @_;
    $access //= 'ReadOnly';
    my $tmp = $access{$access};
    confess "Unknown constant: $access\n" unless defined $tmp;
    $access = $tmp;
    my $ds = GDALOpen($name, $access);
    return bless \$ds, 'Geo::GDAL::FFI::Dataset';
}

our %open_flags = (
    READONLY => 0x00,
    UPDATE   => 0x01,
    ALL      => 0x00,
    RASTER   => 0x02,
    VECTOR   => 0x04,
    GNM      => 0x08,
    SHARED   => 0x20,
    VERBOSE_ERROR =>  0x40,
    INTERNAL      =>  0x80,
    ARRAY_BLOCK_ACCESS   =>    0x100,
    HASHSET_BLOCK_ACCESS =>    0x200,
    );

sub OpenEx {
    shift;
    my ($name, $flags, $drivers, $options, $files) = @_;
    $flags //= 0;
    $drivers //= 0;
    $options //= 0;
    $files //= 0;
    my $ds = GDALOpenEx($name, $flags, $drivers, $options, $files);
    return bless \$ds, 'Geo::GDAL::FFI::Dataset';
}

our %data_type = (
    Unknown => 0,
    Byte => 1,
    UInt16 => 2,
    Int16 => 3,
    UInt32 => 4,
    Int32 => 5,  
    Float32 => 6,
    Float64 => 7,
    CInt16 => 8,
    CInt32 => 9,    
    CFloat32 => 10,
    CFloat64 => 11
    );

package Geo::GDAL::FFI::Driver;
use Carp;

sub GetDescription {
    my $self = shift;
    return Geo::GDAL::FFI::GDALGetDescription($$self);
}

sub Create {
    my $self = shift;
    my ($name, $width, $height, $bands, $dt, $options) = @_;
    $dt //= 'Byte';
    my $tmp = $Geo::GDAL::FFI::data_type{$dt};
    confess "Unknown constant: $dt\n" unless defined $tmp;
    $dt = $tmp;
    my $o = 0;
    for my $key (keys %$options) {
        $o = Geo::GDAL::FFI::CSLAddString($o, "$key=$options->{$key}");
    }
    say STDERR "$width, $height, $bands, $dt";
    my $ds = Geo::GDAL::FFI::GDALCreate($$self, $name, $width, $height, $bands, $dt, $o);
    # how is error raised?
    return bless \$ds, 'Geo::GDAL::FFI::Dataset';
}

package Geo::GDAL::FFI::Dataset;
use Carp;

sub Width {
    my $self = shift;
    return Geo::GDAL::FFI::GDALGetRasterXSize($$self);
}

sub GetLayer {
    my ($self, $i) = @_;
    my $l = Geo::GDAL::FFI::GDALDatasetGetLayer($$self, $i);
    return bless \$l, 'Geo::GDAL::FFI::Layer';
}

package Geo::GDAL::FFI::Layer;
use Carp;

sub ResetReading {
    my $self = shift;
    Geo::GDAL::FFI::OGR_L_ResetReading($$self);
}

sub GetNextFeature {
    my $self = shift;
    my $f = Geo::GDAL::FFI::OGR_L_GetNextFeature($$self);
    return bless \$f, 'Geo::GDAL::FFI::Feature';
}

package Geo::GDAL::FFI::Feature;
use Carp;

1;
