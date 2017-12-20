package Geo::GDAL::FFI;

use v5.10;
use strict;
use warnings;
use Carp;
use Alien::gdal;
use FFI::Platypus;

use constant Warning => 2;
use constant Failure => 3;
use constant Fatal => 4;

use constant Read => 0;
use constant Write => 1;

our @errors;

our %access = (
    ReadOnly => 0,
    Update => 1
    );

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

our %data_types = (
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

our %color_interpretations = (
    Undefined => 0,
    GrayIndex => 1,
    PaletteIndex => 2,
    RedBand => 3,
    GreenBand => 4,
    BlueBand => 5,
    AlphaBand => 6,
    HueBand => 7,
    SaturationBand => 8,
    LightnessBand => 9,
    CyanBand => 10,
    MagentaBand => 11,
    YellowBand => 12,
    BlackBand => 13,
    YCbCr_YBand => 14,
    YCbCr_CbBand => 15,
    YCbCr_CrBand => 16,
    );
our %color_interpretations_reverse = reverse %color_interpretations;

our %geometry_types = (
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
our %geometry_types_reverse = reverse %geometry_types;

sub new {
    my $class = shift;
    my $ffi = FFI::Platypus->new;
    $ffi->load_custom_type('::StringPointer' => 'string_pointer');
    $ffi->lib(Alien::gdal->dynamic_libs);

    $ffi->type('(int,int,string)->void' => 'CPLErrorHandler');
    $ffi->attach('CPLPushErrorHandler' => ['CPLErrorHandler'] => 'void' );

    $ffi->attach( 'CSLDestroy' => ['opaque'] => 'void' );
    $ffi->attach( 'CSLAddString' => ['opaque', 'string'] => 'opaque' );
    $ffi->attach( 'CSLCount' => ['opaque'] => 'int' );
    $ffi->attach( 'CSLGetField' => ['opaque', 'int'] => 'string' );

    $ffi->attach( 'GDALAllRegister' => [] => 'void' );

    $ffi->attach( 'GDALGetMetadataDomainList' => ['opaque'] => 'opaque' );
    $ffi->attach( 'GDALGetMetadata' => ['opaque', 'string'] => 'opaque' );
    $ffi->attach( 'GDALSetMetadata' => ['opaque', 'opaque', 'string'] => 'int' );
    $ffi->attach( 'GDALGetMetadataItem' => ['opaque', 'string', 'string'] => 'string' );
    $ffi->attach( 'GDALSetMetadataItem' => ['opaque', 'string', 'string', 'string'] => 'int' );

    $ffi->attach( 'GDALGetDescription' => ['opaque'] => 'string' );
    $ffi->attach( 'GDALGetDriverCount' => [] => 'int' );
    $ffi->attach( 'GDALGetDriver' => ['int'] => 'opaque' );
    $ffi->attach( 'GDALGetDriverByName' => ['string'] => 'opaque' );
    $ffi->attach( 'GDALCreate' => ['opaque', 'string', 'int', 'int', 'int', 'int', 'opaque'] => 'opaque' );
    $ffi->attach( 'GDALVersionInfo' => ['string'] => 'string' );
    $ffi->attach( 'GDALOpen' => ['string', 'int'] => 'opaque' );
    $ffi->attach( 'GDALOpenEx' => ['string', 'unsigned int', 'opaque', 'opaque', 'opaque'] => 'opaque' );
    $ffi->attach( 'GDALClose' => ['opaque'] => 'void' );
    $ffi->attach( 'GDALGetRasterXSize' => ['opaque'] => 'int' );
    $ffi->attach( 'GDALGetRasterYSize' => ['opaque'] => 'int' );
    $ffi->attach( 'GDALGetRasterCount' => ['opaque'] => 'int' );
    $ffi->attach( 'GDALGetRasterBand' => ['opaque', 'int'] => 'opaque' );
    $ffi->attach( 'GDALFlushCache' => ['opaque'] => 'void' );

    $ffi->attach( 'GDALGetProjectionRef' => ['opaque'] => 'string' );
    $ffi->attach( 'GDALSetProjection' => ['opaque', 'string'] => 'int' );
    $ffi->attach( 'GDALGetGeoTransform' => ['opaque', 'double[6]'] => 'int' );
    $ffi->attach( 'GDALSetGeoTransform' => ['opaque', 'double[6]'] => 'int' );

    $ffi->attach( 'GDALGetRasterDataType' => ['opaque'] => 'int' );
    $ffi->attach( 'GDALGetRasterBandXSize' => ['opaque'] => 'int' );
    $ffi->attach( 'GDALGetRasterBandYSize' => ['opaque'] => 'int' );
    $ffi->attach( 'GDALGetRasterNoDataValue' => ['opaque', 'int*'] => 'double' );
    $ffi->attach( 'GDALSetRasterNoDataValue' => ['opaque', 'double'] => 'int' );
    $ffi->attach( 'GDALDeleteRasterNoDataValue' => ['opaque'] => 'int' );
    $ffi->attach( 'GDALGetRasterColorTable' => ['opaque'] => 'opaque' );
    $ffi->attach( 'GDALSetRasterColorTable' => ['opaque', 'opaque'] => 'int' );
    $ffi->attach( 'GDALGetBlockSize' => ['opaque', 'int*', 'int*'] => 'void' );
    $ffi->attach( 'GDALReadBlock' => ['opaque', 'int', 'int', 'string'] => 'int' );
    $ffi->attach( 'GDALWriteBlock' => ['opaque', 'int', 'int', 'string'] => 'int' );
    $ffi->attach( 'GDALRasterIO' => [qw/opaque int int int int int string int int int int int/] => 'int' );

    $ffi->attach( 'GDALGetRasterColorInterpretation' => ['opaque'] => 'int' );
    $ffi->attach( 'GDALSetRasterColorInterpretation' => ['opaque', 'int'] => 'int' );
    $ffi->attach( 'GDALCreateColorTable' => ['int'] => 'opaque' );
    $ffi->attach( 'GDALDestroyColorTable' => ['opaque'] => 'void' );
    $ffi->attach( 'GDALCloneColorTable' => ['opaque'] => 'opaque' );
    $ffi->attach( 'GDALGetPaletteInterpretation' => ['opaque'] => 'int' );
    $ffi->attach( 'GDALGetColorEntryCount' => ['opaque'] => 'int' );
    $ffi->attach( 'GDALGetColorEntry' => ['opaque', 'int'] => 'short[4]' );
    $ffi->attach( 'GDALSetColorEntry' => ['opaque', 'int', 'short[4]'] => 'void' );
    $ffi->attach( 'GDALCreateColorRamp' => ['opaque', 'int', 'short[4]', 'int', 'short[4]'] => 'void' );

    $ffi->attach( 'OSRNewSpatialReference' => ['string'] => 'opaque' );
    $ffi->attach( 'OSRDestroySpatialReference' => ['opaque'] => 'void' );
    $ffi->attach( 'OSRRelease' => ['opaque'] => 'void' );
    $ffi->attach( 'OSRClone' => ['opaque'] => 'opaque' );
    $ffi->attach( 'OSRImportFromEPSG' => ['opaque', 'int'] => 'int' );

    $ffi->attach( 'GDALDatasetGetLayer' => ['opaque', 'int'] => 'opaque' );
    $ffi->attach( 'GDALDatasetCreateLayer' => ['opaque', 'string', 'opaque', 'int', 'opaque'] => 'opaque' );
    $ffi->attach( 'GDALDatasetExecuteSQL' => ['opaque', 'string', 'opaque', 'string'] => 'opaque' );
    $ffi->attach( 'GDALDatasetReleaseResultSet' => ['opaque', 'opaque'] => 'void' );

    $ffi->attach( 'OGR_L_SyncToDisk' => ['opaque'] => 'int' );
    $ffi->attach( 'OGR_L_GetLayerDefn' => ['opaque'] => 'opaque' );
    $ffi->attach( 'OGR_L_ResetReading' => ['opaque'] => 'void' );
    $ffi->attach( 'OGR_L_GetNextFeature' => ['opaque'] => 'opaque' );
    $ffi->attach( 'OGR_L_CreateFeature' => ['opaque', 'opaque'] => 'int' );

    $ffi->attach( 'OGR_FD_Create' => ['string'] => 'opaque' );
    $ffi->attach( 'OGR_FD_Release' => ['opaque'] => 'void' );
    $ffi->attach( 'OGR_FD_GetGeomType' => ['opaque'] => 'int' );

    $ffi->attach( 'OGR_F_Create' => ['opaque'] => 'opaque' );
    $ffi->attach( 'OGR_F_Destroy' => ['opaque'] => 'void' );

    $ffi->attach( 'OGR_G_CreateGeometry' => ['int'] => 'opaque' );
    $ffi->attach( 'OGR_G_DestroyGeometry' => ['opaque'] => 'void' );
    $ffi->attach( 'OGR_G_GetGeometryType' => ['opaque'] => 'int' );
    $ffi->attach( 'OGR_G_GetPointCount' => ['opaque'] => 'int' );
    $ffi->attach( 'OGR_G_Is3D' => ['opaque'] => 'int' );
    $ffi->attach( 'OGR_G_IsMeasured' => ['opaque'] => 'int' );
    $ffi->attach( 'OGR_G_GetPointZM' => [qw/opaque int double* double* double* double*/] => 'void' );
    $ffi->attach( 'OGR_G_SetPointZM' => [qw/opaque int double double double double/] => 'void' );
    $ffi->attach( 'OGR_G_SetPointM' => [qw/opaque int double double double/] => 'void' );
    $ffi->attach( 'OGR_G_SetPoint' => [qw/opaque int double double double/] => 'void' );
    $ffi->attach( 'OGR_G_SetPoint_2D' => [qw/opaque int double double/] => 'void' );
    $ffi->attach( 'OGR_G_ImportFromWkt' => ['opaque', 'string_pointer'] => 'int' );
    $ffi->attach( 'OGR_G_ExportToWkt' => ['opaque', 'string_pointer'] => 'int' );
    $ffi->attach( 'OGR_G_TransformTo' => ['opaque', 'opaque'] => 'int' );

    $ffi->attach( 'OGR_G_Segmentize' => ['opaque', 'double'] => 'void' );
    $ffi->attach( 'OGR_G_Intersects' => [ 'opaque', 'opaque'] => 'int' );
    $ffi->attach( 'OGR_G_Equals' => [ 'opaque', 'opaque'] => 'int' );
    $ffi->attach( 'OGR_G_Disjoint' => [ 'opaque', 'opaque'] => 'int' );
    $ffi->attach( 'OGR_G_Touches' => [ 'opaque', 'opaque'] => 'int' );
    $ffi->attach( 'OGR_G_Crosses' => [ 'opaque', 'opaque'] => 'int' );
    $ffi->attach( 'OGR_G_Within' => [ 'opaque', 'opaque'] => 'int' );
    $ffi->attach( 'OGR_G_Contains' => [ 'opaque', 'opaque'] => 'int' );
    $ffi->attach( 'OGR_G_Overlaps' => [ 'opaque', 'opaque'] => 'int' );

    $ffi->attach( 'OGR_G_Boundary' => [ 'opaque' ] => 'opaque' );
    $ffi->attach( 'OGR_G_ConvexHull' => [ 'opaque' ] => 'opaque' );
    $ffi->attach( 'OGR_G_Buffer' => [ 'opaque', 'double', 'int' ] => 'opaque' );
    $ffi->attach( 'OGR_G_Intersection' => [ 'opaque', 'opaque' ] => 'opaque' );
    $ffi->attach( 'OGR_G_Union' => [ 'opaque', 'opaque' ] => 'opaque' );
    $ffi->attach( 'OGR_G_UnionCascaded' => [ 'opaque' ] => 'opaque' );
    $ffi->attach( 'OGR_G_PointOnSurface' => [ 'opaque' ] => 'opaque' );

    $ffi->attach( 'OGR_G_Difference' => [ 'opaque', 'opaque' ] => 'opaque' );
    $ffi->attach( 'OGR_G_SymDifference' => [ 'opaque', 'opaque' ] => 'opaque' );
    $ffi->attach( 'OGR_G_Distance' => [ 'opaque', 'opaque'] => 'double' );
    $ffi->attach( 'OGR_G_Distance3D' => [ 'opaque', 'opaque'] => 'double' );
    $ffi->attach( 'OGR_G_Length' => [ 'opaque'] => 'double' );
    $ffi->attach( 'OGR_G_Area' => [ 'opaque'] => 'double' );
    $ffi->attach( 'OGR_G_Centroid' => [ 'opaque', 'opaque'] => 'int' );
    $ffi->attach( 'OGR_G_Value' => [ 'opaque', 'double' ] => 'opaque' );

    $ffi->attach( 'OGR_G_Empty' => [ 'opaque'] => 'void' );
    $ffi->attach( 'OGR_G_IsEmpty' => [ 'opaque'] => 'int' );
    $ffi->attach( 'OGR_G_IsValid' => [ 'opaque'] => 'int' );
    $ffi->attach( 'OGR_G_IsSimple' => [ 'opaque'] => 'int' );
    $ffi->attach( 'OGR_G_IsRing' => [ 'opaque'] => 'int' );


    my $self = {};
    $self->{ffi} = $ffi;
    $self->{CPLErrorHandler} = $ffi->closure(
        sub {
            my ($err, $err_num, $msg) = @_;
            push @errors, $msg;
        });
    CPLPushErrorHandler($self->{CPLErrorHandler});
    return bless $self, $class;
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

sub Open {
    shift;
    my ($name, $access) = @_;
    $access //= 'ReadOnly';
    my $tmp = $access{$access};
    croak "Unknown constant: $access\n" unless defined $tmp;
    $access = $tmp;
    my $ds = GDALOpen($name, $access);
    if (@errors) {
        my $msg = join("\n", @errors);
        @errors = ();
        croak $msg;
    }
    return bless \$ds, 'Geo::GDAL::FFI::Dataset';
}

sub OpenEx {
    shift;
    my ($name, $flags, $drivers, $options, $files) = @_;
    $flags //= 0;
    $drivers //= 0;
    $options //= 0;
    $files //= 0;
    my $ds = GDALOpenEx($name, $flags, $drivers, $options, $files);
    if (@errors) {
        my $msg = join("\n", @errors);
        @errors = ();
        croak $msg;
    }
    return bless \$ds, 'Geo::GDAL::FFI::Dataset';
}

package Geo::GDAL::FFI::Object;
use v5.10;
use strict;
use warnings;
use Carp;

sub GetMetadataDomainList {
    my ($self) = @_;
    my $csl = Geo::GDAL::FFI::GDALGetMetadataDomainList($$self);
    my @list;
    for my $i (0..Geo::GDAL::FFI::CSLCount($csl)-1) {
        push @list, Geo::GDAL::FFI::CSLGetField($csl, $i);
    }
    Geo::GDAL::FFI::CSLDestroy($csl);
    return wantarray ? @list : \@list;
}

sub GetMetadata {
    my ($self, $domain) = @_;
    $domain //= "";
    my $csl = Geo::GDAL::FFI::GDALGetMetadata($$self, $domain);
    my %md;
    for my $i (0..Geo::GDAL::FFI::CSLCount($csl)-1) {
        my ($name, $value) = split /=/, Geo::GDAL::FFI::CSLGetField($csl, $i);
        $md{$name} = $value;
    }
    #Geo::GDAL::FFI::CSLDestroy($csl);
    return wantarray ? %md : \%md;
}

sub SetMetadata {
    my ($self, $metadata, $domain) = @_;
    my $csl = 0;
    for my $name (keys %$metadata) {
        $csl = Geo::GDAL::FFI::CSLAddString($csl, "$name=$metadata->{$name}");
    }
    $domain //= "";
    my $err = Geo::GDAL::FFI::GDALSetMetadata($$self, $csl, $domain);
    croak "" if $err == Geo::GDAL::FFI::Failure;
    warn "" if $err == Geo::GDAL::FFI::Warning;
}

sub GetMetadataItem {
    my ($self, $name, $domain) = @_;
    return Geo::GDAL::FFI::GDALGetMetadataItem($$self, $name, $domain);
}

sub SetMetadataItem {
    my ($self, $name, $value, $domain) = @_;
    Geo::GDAL::FFI::GDALSetMetadataItem($$self, $name, $value, $domain);
    if (@errors) {
        my $msg = join("\n", @errors);
        @errors = ();
        croak $msg;
    }
}

package Geo::GDAL::FFI::Driver;
use v5.10;
use strict;
use warnings;
use Carp;
use base 'Geo::GDAL::FFI::Object';

sub GetDescription {
    my $self = shift;
    return Geo::GDAL::FFI::GDALGetDescription($$self);
}

sub Create {
    my $self = shift;
    my ($name, $width, $height, $bands, $dt, $options) = @_;
    $name //= '';
    $width //= 256;
    $height //= 256;
    $bands //= 1;
    $dt //= 'Byte';
    my $tmp = $data_types{$dt};
    confess "Unknown constant: $dt\n" unless defined $tmp;
    $dt = $tmp;
    my $o = 0;
    for my $key (keys %$options) {
        $o = Geo::GDAL::FFI::CSLAddString($o, "$key=$options->{$key}");
    }
    my $ds = Geo::GDAL::FFI::GDALCreate($$self, $name, $width, $height, $bands, $dt, $o);
    if (@errors) {
        my $msg = join("\n", @errors);
        @errors = ();
        croak $msg;
    }
    return bless \$ds, 'Geo::GDAL::FFI::Dataset';
}

package Geo::GDAL::FFI::SpatialReference;
use v5.10;
use strict;
use warnings;
use Carp;

sub new {
    my ($class, $wkt) = @_;
    my $sr = Geo::GDAL::FFI::OSRNewSpatialReference($wkt);
    if (@errors) {
        my $msg = join("\n", @errors);
        @errors = ();
        croak $msg;
    }
    return bless \$sr, $class;
}

sub DESTROY {
    my $self = shift;
    Geo::GDAL::FFI::OSRDestroySpatialReference($$self);
}

sub Clone {
    my $self = shift;
    my $s = Geo::GDAL::FFI::OSRClone($$self);
    return bless \$s, 'Geo::GDAL::FFI::SpatialReference';
}

sub ImportFromEPSG {
    my ($self, $code) = @_;
    Geo::GDAL::FFI::OSRImportFromEPSG($$self, $code);
}

package Geo::GDAL::FFI::Dataset;
use v5.10;
use strict;
use warnings;
use Carp;
use base 'Geo::GDAL::FFI::Object';

sub DESTROY {
    my $self = shift;
    Geo::GDAL::FFI::GDALClose($$self);
}

sub FlushCache {
    my $self = shift;
    Geo::GDAL::FFI::GDALFlushCache($$self);
}

sub Width {
    my $self = shift;
    return Geo::GDAL::FFI::GDALGetRasterXSize($$self);
}

sub Height {
    my $self = shift;
    return Geo::GDAL::FFI::GDALGetRasterYSize($$self);
}

sub GetProjectionString {
    my ($self) = @_;
    return Geo::GDAL::FFI::GDALGetProjectionRef($$self);
}

sub SetProjectionString {
    my ($self, $proj) = @_;
    my $e = Geo::GDAL::FFI::GDALSetProjection($$self, $proj);
    if ($e != 0) {
        my $msg = join("\n", @errors);
        @errors = ();
        croak $msg;
    }
}

sub GetGeoTransform {
    my ($self) = @_;
    my $t = [0,0,0,0,0,0];
    Geo::GDAL::FFI::GDALGetGeoTransform($$self, $t);
    return wantarray ? @$t : $t;
}

sub SetGeoTransform {
    my $self = shift;
    my $t = @_ > 1 ? [@_] : shift;
    Geo::GDAL::FFI::GDALSetGeoTransform($$self, $t);
}

sub GetBandCount {
    my $self = shift;
    return Geo::GDAL::FFI::GDALGetRasterCount($$self);
}

sub GetBand {
    my ($self, $i) = @_;
    $i //= 1;
    my $b = Geo::GDAL::FFI::GDALGetRasterBand($$self, $i);
    return bless \$b, 'Geo::GDAL::FFI::Band';
}

sub GetLayer {
    my ($self, $i) = @_;
    my $l = Geo::GDAL::FFI::GDALDatasetGetLayer($$self, $i);
    return bless \$l, 'Geo::GDAL::FFI::Layer';
}

sub CreateLayer {
    my ($self, $name, $sr, $gt, $options) = @_;
    my $tmp = $geometry_types{$gt};
    confess "Unknown constant: $gt\n" unless defined $tmp;
    $gt = $tmp;
    my $o = 0;
    for my $key (keys %$options) {
        $o = Geo::GDAL::FFI::CSLAddString($o, "$key=$options->{$key}");
    }
    $sr = Geo::GDAL::FFI::OSRClone($$sr);
    my $l = Geo::GDAL::FFI::GDALDatasetCreateLayer($$self, $name, $sr, $gt, $o);
    Geo::GDAL::FFI::OSRRelease($sr);
    if (@errors) {
        my $msg = join("\n", @errors);
        @errors = ();
        croak $msg;
    }
    return bless \$l, 'Geo::GDAL::FFI::Layer';
}

package Geo::GDAL::FFI::Band;
use v5.10;
use strict;
use warnings;
use Carp;

sub GetDataType {
    my $self = shift;
    Geo::GDAL::FFI::GDALGetRasterDataType($$self);
}

sub Width {
    my $self = shift;
    Geo::GDAL::FFI::GDALGetRasterBandXSize($$self);
}

sub Height {
    my $self = shift;
    Geo::GDAL::FFI::GDALGetRasterBandYSize($$self);
}

sub GetNoDataValue {
    my $self = shift;
    my $b = 0;
    my $v = Geo::GDAL::FFI::GDALGetRasterNoDataValue($$self, \$b);
    return unless $b;
    return $v;
}

sub SetNoDataValue {
    my $self = shift;
    unless (@_) {
        Geo::GDAL::FFI::GDALDeleteRasterNoDataValue($$self);
        return;
    }
    my $v = shift;
    my $e = Geo::GDAL::FFI::GDALSetRasterNoDataValue($$self, $v);
    return unless $e;
    croak "SetNoDataValue not supported by the driver." unless @errors;
    my $msg = join("\n", @errors);
    @errors = ();
    croak $msg;
}

sub GetBlockSize {
    my $self = shift;
    my ($w, $h);
    Geo::GDAL::FFI::GDALGetBlockSize($$self, \$w, \$h);
    return ($w, $h);
}

sub PackCharacter {
    my $t = shift;
    my $is_big_endian = unpack("h*", pack("s", 1)) =~ /01/; # from Programming Perl
    return ('C', 1) if $t == 1;
    return ($is_big_endian ? ('n', 2) : ('v', 2)) if $t == 2;
    return ('s', 2) if $t == 3;
    return ($is_big_endian ? ('N', 4) : ('V', 4)) if $t == 4;
    return ('l', 4) if $t == 5;
    return ('f', 4) if $t == 6;
    return ('d', 8) if $t == 7;
    # CInt16 => 8,
    # CInt32 => 9,
    # CFloat32 => 10,
    # CFloat64 => 11
}

sub Read {
    my ($self, $xoff, $yoff, $xsize, $ysize, $bufxsize, $bufysize) = @_;
    $xoff //= 0;
    $yoff //= 0;
    my $t = Geo::GDAL::FFI::GDALGetRasterDataType($$self);
    my $buf;
    my ($pc, $bytes_per_cell) = PackCharacter($t);
    my $w;
    unless (defined $xsize) {
        Geo::GDAL::FFI::GDALGetBlockSize($$self, \$xsize, \$ysize);
        $bufxsize = $xsize;
        $bufysize = $ysize;
        $w = $bufxsize * $bytes_per_cell;
        $buf = ' ' x ($bufysize * $w);
        my $e = Geo::GDAL::FFI::GDALReadBlock($$self, $xoff, $yoff, $buf);
    } else {
        $bufxsize //= $xsize;
        $bufysize //= $ysize;
        $w = $bufxsize * $bytes_per_cell;
        $buf = ' ' x ($bufysize * $w);
        Geo::GDAL::FFI::GDALRasterIO($$self, Geo::GDAL::FFI::Read, $xoff, $yoff, $xsize, $ysize, $buf, $bufxsize, $bufysize, $t, 0, 0);
    }
    my $offset = 0;
    my @data;
    for my $y (0..$bufysize-1) {
        my @d = unpack($pc."[$bufxsize]", substr($buf, $offset, $w));
        push @data, \@d;
        $offset += $w;
    }
    return \@data;
}
*ReadBlock = *Read;

sub Write {
    my ($self, $data, $xoff, $yoff, $xsize, $ysize) = @_;
    $xoff //= 0;
    $yoff //= 0;
    my $bufxsize = @{$data->[0]};
    my $bufysize = @$data;
    $xsize //= $bufxsize;
    $ysize //= $bufysize;
    my $t = Geo::GDAL::FFI::GDALGetRasterDataType($$self);
    my ($pc, $bytes_per_cell) = PackCharacter($t);
    my $buf = '';
    for my $i (0..$bufysize-1) {
        $buf .= pack($pc."[$bufxsize]", @{$data->[$i]});
    }
    Geo::GDAL::FFI::GDALRasterIO($$self, Geo::GDAL::FFI::Write, $xoff, $yoff, $xsize, $ysize, $buf, $bufxsize, $bufysize, $t, 0, 0);
}

sub WriteBlock {
    my ($self, $data, $xoff, $yoff) = @_;
    my ($xsize, $ysize);
    Geo::GDAL::FFI::GDALGetBlockSize($$self, \$xsize, \$ysize);
    my $t = Geo::GDAL::FFI::GDALGetRasterDataType($$self);
    my ($pc, $bytes_per_cell) = PackCharacter($t);
    my $buf = '';
    for my $i (0..$ysize-1) {
        $buf .= pack($pc."[$xsize]", @{$data->[$i]});
    }
    Geo::GDAL::FFI::GDALWriteBlock($$self, $xoff, $yoff, $buf);
}

sub GetColorInterpretation {
    my $self = shift;
    return $color_interpretations_reverse{
        Geo::GDAL::FFI::GDALGetRasterColorInterpretation($$self)
    };
}

sub SetColorInterpretation {
    my ($self, $i) = @_;
    my $tmp = $color_interpretations{$i};
    confess "Unknown constant: $i\n" unless defined $tmp;
    $i = $tmp;
    Geo::GDAL::FFI::GDALSetRasterColorInterpretation($$self, $i);
}

sub GetColorTable {
    my $self = shift;
    my $ct = Geo::GDAL::FFI::GDALGetRasterColorTable($$self);
    return unless $ct;
    # color table is a table of [c1...c4]
    # the interpretation of colors is from next method
    my @table;
    for my $i (0..Geo::GDAL::FFI::GDALGetColorEntryCount($ct)-1) {
        my $c = Geo::GDAL::FFI::GDALGetColorEntry($ct, $i);
        push @table, $c;
    }
    return wantarray ? @table : \@table;
}

sub GetPaletteInterp {
    my $self = shift;
}

sub SetColorTable {
    my ($self, $table) = @_;
    my $ct = Geo::GDAL::FFI::GDALCreateColorTable();
    for my $i (0..$#$table) {
        Geo::GDAL::FFI::GDALSetColorEntry($ct, $i, $table->[$i]);
    }
    Geo::GDAL::FFI::GDALSetRasterColorTable($$self, $ct);
    Geo::GDAL::FFI::GDALDestroyColorTable($ct);
}

package Geo::GDAL::FFI::Layer;
use v5.10;
use strict;
use warnings;
use Carp;
use base 'Geo::GDAL::FFI::Object';

sub DESTROY {
    my $self = shift;
    Geo::GDAL::FFI::OGR_L_SyncToDisk($$self);
}

sub GetDefn {
    my $self = shift;
    my $d = Geo::GDAL::FFI::OGR_L_GetLayerDefn($$self);
    return bless \$d, 'Geo::GDAL::FFI::FeatureDefn';
}

sub ResetReading {
    my $self = shift;
    Geo::GDAL::FFI::OGR_L_ResetReading($$self);
}

sub GetNextFeature {
    my $self = shift;
    my $f = Geo::GDAL::FFI::OGR_L_GetNextFeature($$self);
    return bless \$f, 'Geo::GDAL::FFI::Feature';
}

sub CreateFeature {
    my ($self, $f) = @_;
    Geo::GDAL::FFI::OGR_L_CreateFeature($$self, $$f);
}

package Geo::GDAL::FFI::FeatureDefn;
use v5.10;
use strict;
use warnings;
use Carp;

sub new {
    my ($class, $name) = @_;
    my $f = Geo::GDAL::FFI::OGR_FD_Create($name);
    return bless \$f, $class;
}

sub DESTROY {
    my $self = shift;
    #Geo::GDAL::FFI::OGR_FD_Release($$self);
}

sub GetGeomType {
    my $self = shift;
    my $t = Geo::GDAL::FFI::OGR_FD_GetGeomType($$self);
    return $geometry_types_reverse{$t};
}

package Geo::GDAL::FFI::Feature;
use v5.10;
use strict;
use warnings;
use Carp;

our %defns = ();

sub new {
    my ($class, $def) = @_;
    $defns{$def} = $def;
    my $f = Geo::GDAL::FFI::OGR_F_Create($$def);
    return bless \$f, $class;
}

sub DESTROY {
    my $self = shift;
    Geo::GDAL::FFI::OGR_F_Destroy($$self);
}

package Geo::GDAL::FFI::Geometry;
use v5.10;
use strict;
use warnings;
use Carp;

sub new {
    my ($class, $type) = @_;
    my $tmp = $geometry_types{$type};
    confess "Unknown constant: $type\n" unless defined $tmp;
    $type = $tmp;
    my $g = Geo::GDAL::FFI::OGR_G_CreateGeometry($type);
    return bless \$g, $class;
}

sub DESTROY {
    my ($self) = @_;
    Geo::GDAL::FFI::OGR_G_DestroyGeometry($$self);
}

sub GetPointCount {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_G_GetPointCount($$self);
}

sub SetPoint {
    my $self = shift;
    my ($i, $x, $y, $z, $m);
    $i = shift if Geo::GDAL::FFI::OGR_G_GetPointCount($$self) > 1;
    if (@_ > 1) {
        ($x, $y, $z, $m) = @_;
    } elsif (@_) {
        ($x, $y, $z, $m) = @{$_[0]};
    }
    $x //= 0;
    $y //= 0;
    my $is3d = Geo::GDAL::FFI::OGR_G_Is3D($$self);
    my $ism = Geo::GDAL::FFI::OGR_G_IsMeasured($$self);
    if ($is3d && $ism) {
        $z //= 0;
        $m //= 0;
        Geo::GDAL::FFI::OGR_G_SetPointZM($$self, $i, $x, $y, $z, $m);
    } elsif ($ism) {
        $m //= 0;
        Geo::GDAL::FFI::OGR_G_SetPointM($$self, $i, $x, $y, $m);
    } elsif ($is3d) {
        $z //= 0;
        Geo::GDAL::FFI::OGR_G_SetPoint($$self, $i, $x, $y, $z);
    } else {
        Geo::GDAL::FFI::OGR_G_SetPoint_2D($$self, $i, $x, $y);
    }
}

sub GetPoint {
    my ($self, $i) = @_;
    $i //= 0;
    my ($x, $y, $z, $m) = (0, 0, 0, 0);
    Geo::GDAL::FFI::OGR_G_GetPointZM($$self, $i, \$x, \$y, \$z, \$m);
    my @point = ($x, $y);
    push @point, $z if Geo::GDAL::FFI::OGR_G_Is3D($$self);
    push @point, $m if Geo::GDAL::FFI::OGR_G_IsMeasured($$self);
    return wantarray ? @point : \@point;
}

sub ImportFromWkt {
    my ($self, $wkt) = @_;
    $wkt //= '';
    Geo::GDAL::FFI::OGR_G_ImportFromWkt($$self, \$wkt);
    return $wkt;
}

sub ExportToWkt {
    my ($self) = @_;
    my $wkt = '';
    Geo::GDAL::FFI::OGR_G_ExportToWkt($$self, \$wkt);
    return $wkt;
}

1;
