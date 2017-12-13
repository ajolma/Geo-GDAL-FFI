package Geo::GDAL::FFI;

use v5.10;
use strict;
use warnings;
use Carp;
use Alien::gdal;
use FFI::Platypus;

sub new {
    my $class = shift;
    my $ffi = FFI::Platypus->new;
    $ffi->load_custom_type('::StringPointer' => 'string_pointer');
    $ffi->lib(Alien::gdal->dynamic_libs);

    $ffi->type('(int,int,string)->void' => 'CPLErrorHandler');
    $ffi->attach('CPLPushErrorHandler' => ['CPLErrorHandler'] => 'void' );

    # these should come from a type helper (TBD)
    # perhaps the string_pointer is good for this?
    #$ffi->attach( 'CPLStringPointer' => [] => 'opaque' );
    #$ffi->attach( 'CPLStringPointer2String' => ['opaque'] => 'string' );
    #$ffi->attach( 'CPLStringPointerFree' => ['opaque'] => 'void' );
    
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
    $ffi->attach( 'OGR_G_CreateGeometry' => ['int'] => 'opaque' );
    $ffi->attach( 'OGR_G_ExportToWkt' => ['opaque', 'string_pointer'] => 'int' );
    my $self = {ffi => $ffi};
    return bless $self, $class;
}

sub PushErrorHandler {
    my ($self, $handler) = @_;
    $self->{CPLErrorHandler} = $self->{ffi}->closure($handler);
    CPLPushErrorHandler($self->{CPLErrorHandler});
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
use v5.10;
use strict;
use warnings;
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
    my $ds = Geo::GDAL::FFI::GDALCreate($$self, $name, $width, $height, $bands, $dt, $o);
    # how is error raised?
    return bless \$ds, 'Geo::GDAL::FFI::Dataset';
}

package Geo::GDAL::FFI::Dataset;
use v5.10;
use strict;
use warnings;
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
use v5.10;
use strict;
use warnings;
use Carp;

package Geo::GDAL::FFI::Geometry;
use v5.10;
use strict;
use warnings;
use Carp;

our %geometry_type = (
    Unknown => 0,
    Point => 1,
    LineString => 2,
    Polygon => 3,
    MultiPoint => 4,
    MultiLineString => 5,
    MultiPolygon => 6,
    GeometryCollection => 7,
    CircularString => 8,
    CompoundCurve => 9,
    CurvePolygon => 10,
    MultiCurve => 11,
    MultiSurface => 12,
    Curve => 13,
    Surface => 14,
    PolyhedralSurface => 15,
    TIN => 16,
    Triangle => 17,
    None => 100,
    LinearRing => 101,
    CircularStringZ => 1008,
    CompoundCurveZ => 1009,
    CurvePolygonZ => 1010,
    MultiCurveZ => 1011,
    MultiSurfaceZ => 1012,
    CurveZ => 1013,
    SurfaceZ => 1014,
    PolyhedralSurfaceZ => 1015,
    TINZ => 1016,
    TriangleZ => 1017,
    PointM => 2001,
    LineStringM => 2002,
    PolygonM => 2003,
    MultiPointM => 2004,
    MultiLineStringM => 2005,
    MultiPolygonM => 2006,
    GeometryCollectionM => 2007,
    CircularStringM => 2008,
    CompoundCurveM => 2009,
    CurvePolygonM => 2010,
    MultiCurveM => 2011,
    MultiSurfaceM => 2012,
    CurveM => 2013,
    SurfaceM => 2014,
    PolyhedralSurfaceM => 2015,
    TINM => 2016,
    TriangleM => 2017,
    PointZM => 3001,
    LineStringZM => 3002,
    PolygonZM => 3003,
    MultiPointZM => 3004,
    MultiLineStringZM => 3005,
    MultiPolygonZM => 3006,
    GeometryCollectionZM => 3007,
    CircularStringZM => 3008,
    CompoundCurveZM => 3009,
    CurvePolygonZM => 3010,
    MultiCurveZM => 3011,
    MultiSurfaceZM => 3012,
    CurveZM => 3013,
    SurfaceZM => 3014,
    PolyhedralSurfaceZM => 3015,
    TINZM => 3016,
    TriangleZM => 3017,
    Point25D => 0x80000001,
    LineString25D => 0x80000002,
    Polygon25D => 0x80000003,
    MultiPoint25D => 0x80000004,
    MultiLineString25D => 0x80000005,
    MultiPolygon25D => 0x80000006,
    GeometryCollection25D => 0x80000007
    );

sub new {
    my ($class, $type) = @_;
    my $tmp = $geometry_type{$type};
    confess "Unknown constant: $type\n" unless defined $tmp;
    $type = $tmp;
    my $g = Geo::GDAL::FFI::OGR_G_CreateGeometry($type);
    return bless \$g, $class;
}

sub ExportToWkt {
    my ($self) = @_;
    #my $wkt = Geo::GDAL::FFI::CPLStringPointer();
    my $wkt = '';
    Geo::GDAL::FFI::OGR_G_ExportToWkt($$self, \$wkt);
    #my $retval = Geo::GDAL::FFI::CPLStringPointer2String($wkt);
    #Geo::GDAL::FFI::CPLStringPointerFree($wkt);
    #return $retval;
    return $wkt;
}

1;
