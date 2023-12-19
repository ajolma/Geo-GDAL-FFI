package Geo::GDAL::FFI;

use v5.10;
use strict;
use warnings;
use Carp;
use PDL::Types ();
use Config ();  #  needed to silence some FFI::Platypus warnings
use FFI::Platypus;
use FFI::Platypus::Buffer;
require Exporter;
require B;
use Sort::Versions;

use Geo::GDAL::FFI::VSI;
use Geo::GDAL::FFI::VSI::File;
use Geo::GDAL::FFI::SpatialReference;
use Geo::GDAL::FFI::Object;
use Geo::GDAL::FFI::Driver;
use Geo::GDAL::FFI::Dataset;
use Geo::GDAL::FFI::Band;
use Geo::GDAL::FFI::Layer;
use Geo::GDAL::FFI::FeatureDefn;
use Geo::GDAL::FFI::FieldDefn;
use Geo::GDAL::FFI::GeomFieldDefn;
use Geo::GDAL::FFI::Feature;
use Geo::GDAL::FFI::Geometry;

our $VERSION = 0.1200;
our $DEBUG = 0;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(@errors GetVersionInfo SetErrorHandling UnsetErrorHandling 
    Capabilities OpenFlags DataTypes ResamplingMethods 
    FieldTypes FieldSubtypes Justifications ColorInterpretations
    GeometryTypes GeometryFormats GridAlgorithms
    GetDriver GetDrivers IdentifyDriver Open
    HaveGEOS SetConfigOption GetConfigOption
    FindFile PushFinderLocation PopFinderLocation FinderClean);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

our $None = 0;
our $Debug = 1;
our $Warning = 2;
our $Failure = 3;
our $Fatal = 4;

our %ogr_errors = (
    1 => 'NOT_ENOUGH_DATA',
    2 => 'NOT_ENOUGH_MEMORY',
    3 => 'UNSUPPORTED_GEOMETRY_TYPE',
    4 => 'UNSUPPORTED_OPERATION',
    5 => 'CORRUPT_DATA',
    6 => 'FAILURE',
    7 => 'UNSUPPORTED_SRS',
    8 => 'INVALID_HANDLE',
    9 => 'NON_EXISTING_FEATURE',
    );

our $Read = 0;
our $Write = 1;

our @errors;
our %immutable;
my  %parent_ref_hash;

#say STDERR "XXX " . $ENV{LD_LIBRARY_PATH};
#my $instance = __PACKAGE__->new;
my $instance;

sub SetErrorHandling {
    return unless $instance;
    return if exists $instance->{CPLErrorHandler};
    $instance->{CPLErrorHandler} = $instance->{ffi}->closure(
        sub {
            my ($err_cat, $err_num, $msg) = @_;
            if ($err_cat == $None) {
            } elsif ($err_cat == $Debug) {
                if ($DEBUG) {
                    print STDERR $msg;
                }
            } elsif ($err_cat == $Warning) {
                warn $msg;
            } else {
                push @errors, $msg;
            }
        });
    $instance->{CPLErrorHandler}->sticky;
    CPLPushErrorHandler($instance->{CPLErrorHandler});
}

sub UnsetErrorHandling {
    return unless $instance;
    return unless exists $instance->{CPLErrorHandler};
    $instance->{CPLErrorHandler}->unstick;
    CPLPopErrorHandler($instance->{CPLErrorHandler});
    delete $instance->{CPLErrorHandler};
}

sub error_msg {
    my $args = shift;
    return unless @errors || $args;
    unless (@errors) {
        return $ogr_errors{$args->{OGRError}} if $args->{OGRError};
        return "Unknown error.";
    }
    my $msg = join("\n", @errors);
    @errors = ();
    return $msg;
}

#  internal methods
sub _register_parent_ref {
    my ($gdal_handle, $parent) = @_;
    #  ensure $gdal_handle is not blessed?
    confess "gdal handle is undefined"
      if !defined $gdal_handle;
    confess "Parent ref is undefined"
      if !$parent;
    $parent_ref_hash{$gdal_handle} = $parent;
}

sub _deregister_parent_ref {
    my ($gdal_handle) = @_;
    #  we get undef vals in global cleanup
    return if !$gdal_handle;  
    delete $parent_ref_hash{$gdal_handle};
}

sub _get_parent_ref {
    my ($gdal_handle) = @_;
    warn "Attempting to access non-existent parent"
      if !$parent_ref_hash{$gdal_handle}; 
    return $parent_ref_hash{$gdal_handle}
}


our %capabilities = (
    OPEN => 1,
    CREATE => 2,
    CREATECOPY => 3,
    VIRTUALIO => 4,
    RASTER => 5,
    VECTOR => 6,
    GNM => 7,
    NOTNULL_FIELDS => 8,
    DEFAULT_FIELDS => 9,
    NOTNULL_GEOMFIELDS => 10,
    NONSPATIAL => 11,
    FEATURE_STYLES => 12,
    );

sub Capabilities {
    return sort {$capabilities{$a} <=> $capabilities{$b}} keys %capabilities;
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

sub OpenFlags {
    return sort {$open_flags{$a} <=> $open_flags{$b}} keys %open_flags;
}

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
our %data_types_reverse = reverse %data_types;

sub DataTypes {
    return sort {$data_types{$a} <=> $data_types{$b}} keys %data_types;
}

our %rat_field_type = (
    Integer => 0,
    Real => 1,
    String => 2
    );

our %rat_field_usage = (
    Generic => 0,
    PixelCount => 1,
    Name => 2,
    Min => 3,
    Max => 4,
    MinMax => 5,
    Red => 6,
    Green => 7,
    Blue => 8,
    Alpha => 9,
    RedMin => 10,
    GreenMin => 11,
    BlueMin => 12,
    AlphaMin => 13,
    RedMax => 14,
    GreenMax => 15,
    BlueMax => 16,
    AlphaMax => 17,
    );

our %rat_table_type = (
    THEMATIC => 0,
    ATHEMATIC => 1
    );
 
our %resampling = (
    NearestNeighbour => 0,
    Bilinear => 1,
    Cubic => 2,
    CubicSpline => 3,
    ORA_Lanczos => 4,
    Average => 5,
    Mode => 6,
    Gauss => 7
    );

sub ResamplingMethods {
    return sort {$resampling{$a} <=> $resampling{$b}} keys %resampling;
}

our %data_type2pdl_data_type = (
    Byte => $PDL::Types::PDL_B,
    Int16 => $PDL::Types::PDL_S,
    UInt16 => $PDL::Types::PDL_US,
    Int32 => $PDL::Types::PDL_L,
    Float32 => $PDL::Types::PDL_F,
    Float64 => $PDL::Types::PDL_D,
    );
our %pdl_data_type2data_type = reverse %data_type2pdl_data_type;

our %field_types = (
    Integer => 0,
    IntegerList => 1,
    Real => 2,
    RealList => 3,
    String => 4,
    StringList => 5,
    #WideString => 6,     # do not use
    #WideStringList => 7, # do not use
    Binary => 8,
    Date => 9,
    Time => 10,
    DateTime => 11,
    Integer64 => 12,
    Integer64List => 13,
    );
our %field_types_reverse = reverse %field_types;

sub FieldTypes {
    return sort {$field_types{$a} <=> $field_types{$b}} keys %field_types;
}

our %field_subtypes = (
    None => 0,
    Boolean => 1,
    Int16 => 2,
    Float32 => 3
    );
our %field_subtypes_reverse = reverse %field_subtypes;

sub FieldSubtypes {
    return sort {$field_subtypes{$a} <=> $field_subtypes{$b}} keys %field_subtypes;
}

our %justification = (
    Undefined => 0,
    Left => 1,
    Right => 2
    );
our %justification_reverse = reverse %justification;

sub Justifications {
    return sort {$justification{$a} <=> $justification{$b}} keys %justification;
}

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

sub ColorInterpretations {
    return sort {$color_interpretations{$a} <=> $color_interpretations{$b}} keys %color_interpretations;
}

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

sub GeometryTypes {
    return sort {$geometry_types{$a} <=> $geometry_types{$b}} keys %geometry_types;
}

our %geometry_formats = (
    WKT => 1,
    );

sub GeometryFormats {
    return sort {$geometry_formats{$a} <=> $geometry_formats{$b}} keys %geometry_formats;
}

our %grid_algorithms = (
    InverseDistanceToAPower => 1,
    MovingAverage => 2,
    NearestNeighbor => 3,
    MetricMinimum => 4,
    MetricMaximum => 5,
    MetricRange => 6,
    MetricCount => 7,
    MetricAverageDistance => 8,
    MetricAverageDistancePts => 9,
    Linear => 10,
    InverseDistanceToAPowerNearestNeighbor => 11
    );

sub GridAlgorithms {
    return sort {$grid_algorithms{$a} <=> $grid_algorithms{$b}} keys %grid_algorithms;
}

sub isint {
    my $value = shift;
    my $b_obj = B::svref_2object(\$value);
    my $flags = $b_obj->FLAGS;
    return 1 if $flags & B::SVp_IOK() && !($flags & B::SVp_NOK()) && !($flags & B::SVp_POK());
}

sub new {
    my $class = shift;
    my $gdal = shift;

    return $instance if $instance;

    my $ffi = FFI::Platypus->new;
    my @libs = $gdal->dynamic_libs;
    $ffi->lib(@libs);

    $ffi->type('(pointer,size_t,size_t,opaque)->size_t' => 'VSIWriteFunction');
    $ffi->type('(int,int,string)->void' => 'CPLErrorHandler');
    $ffi->type('(double,string,pointer)->int' => 'GDALProgressFunc');
    $ffi->type('(pointer,int, pointer,int,int,unsigned int,unsigned int,int,int)->int' => 'GDALDerivedPixelFunc');
    $ffi->type('(pointer,int,int,pointer,pointer,pointer,pointer)->int' => 'GDALTransformerFunc');
    $ffi->type('(double,int,pointer,pointer,pointer)->int' => 'GDALContourWriter');
    $ffi->type('(string,string,sint64,sint64,pointer)->void' => 'GDALQueryLoggerFunc');

    $ffi->ignore_not_found(1);

    # from port/*.h
    $ffi->attach(VSIMalloc => [qw/uint/] => 'opaque');
    croak "Can't attach to GDAL methods. Problem with GDAL dynamic libs: '@libs'?" unless $class->can('VSIMalloc');
    $ffi->attach(VSIFree => ['opaque'] => 'void');
    $ffi->attach(CPLError => [qw/int int string/] => 'void');
    $ffi->attach(VSIFOpenL => [qw/string string/] => 'opaque');
    $ffi->attach(VSIFOpenExL => [qw/string string int/] => 'opaque');
    $ffi->attach(VSIFCloseL => ['opaque'] => 'int');
    $ffi->attach(VSIFWriteL => [qw/opaque uint uint opaque/] => 'uint');
    $ffi->attach(VSIFReadL => [qw/opaque uint uint opaque/] => 'uint');
    $ffi->attach(VSIIngestFile => [qw/opaque string string* uint64* sint64/] => 'int');
    $ffi->attach(VSIMkdir => [qw/string sint64/] => 'int');
    $ffi->attach(VSIRmdir => [qw/string/] => 'int');
    $ffi->attach(VSIReadDirEx => [qw/string int/] => 'opaque');
    $ffi->attach(VSIUnlink => [qw/string/] => 'int');
    $ffi->attach(VSIRename => [qw/string string/] => 'int');
    $ffi->attach(VSIStdoutSetRedirection => ['VSIWriteFunction', 'opaque'] => 'void');
    $ffi->attach(CPLSetErrorHandler => ['CPLErrorHandler'] => 'opaque');
    $ffi->attach(CPLPushErrorHandler => ['CPLErrorHandler'] => 'void');
    $ffi->attach(CPLPopErrorHandler => ['CPLErrorHandler'] => 'void');
    $ffi->attach(CSLDestroy => ['opaque'] => 'void');
    $ffi->attach(CSLAddString => ['opaque', 'string'] => 'opaque');
    $ffi->attach(CSLCount => ['opaque'] => 'int');
    $ffi->attach(CSLGetField => ['opaque', 'int'] => 'string');
    $ffi->attach(CPLGetConfigOption => ['string', 'string']  => 'string');
    $ffi->attach(CPLSetConfigOption => ['string', 'string']  => 'void');
    $ffi->attach(CPLFindFile => ['string', 'string']  => 'string');
    $ffi->attach(CPLPushFinderLocation => ['string'] => 'void');
    $ffi->attach(CPLPopFinderLocation => [] => 'void');
    $ffi->attach(CPLFinderClean => [] => 'void');

    # from ogr_core.h
    $ffi->attach( 'OGR_GT_Flatten' => ['unsigned int'] => 'unsigned int');

# generated with parse_h.pl
# from gcore/gdal.h
$ffi->attach('GDALGetDataTypeSize' => ['unsigned int'] => 'int');
$ffi->attach('GDALGetDataTypeSizeBits' => ['unsigned int'] => 'int');
$ffi->attach('GDALGetDataTypeSizeBytes' => ['unsigned int'] => 'int');
$ffi->attach('GDALDataTypeIsComplex' => ['unsigned int'] => 'int');
$ffi->attach('GDALDataTypeIsInteger' => ['unsigned int'] => 'int');
$ffi->attach('GDALDataTypeIsFloating' => ['unsigned int'] => 'int');
$ffi->attach('GDALDataTypeIsSigned' => ['unsigned int'] => 'int');
$ffi->attach('GDALGetDataTypeName' => ['unsigned int'] => 'string');
$ffi->attach('GDALGetDataTypeByName' => [qw/string/] => 'unsigned int');
$ffi->attach('GDALDataTypeUnion' => ['unsigned int','unsigned int'] => 'unsigned int');
$ffi->attach('GDALDataTypeUnionWithValue' => ['unsigned int','double','int'] => 'unsigned int');
$ffi->attach('GDALFindDataType' => [qw/int int int int/] => 'unsigned int');
$ffi->attach('GDALFindDataTypeForValue' => [qw/double int/] => 'unsigned int');
$ffi->attach('GDALAdjustValueToDataType' => ['unsigned int','double','int*','int*'] => 'double');
$ffi->attach('GDALGetNonComplexDataType' => ['unsigned int'] => 'unsigned int');
$ffi->attach('GDALDataTypeIsConversionLossy' => ['unsigned int','unsigned int'] => 'int');
$ffi->attach('GDALGetAsyncStatusTypeName' => ['unsigned int'] => 'string');
$ffi->attach('GDALGetAsyncStatusTypeByName' => [qw/string/] => 'unsigned int');
$ffi->attach('GDALGetColorInterpretationName' => ['unsigned int'] => 'string');
$ffi->attach('GDALGetColorInterpretationByName' => [qw/string/] => 'unsigned int');
$ffi->attach('GDALGetPaletteInterpretationName' => ['unsigned int'] => 'string');
$ffi->attach('GDALAllRegister' => [] => 'void');
$ffi->attach('GDALCreate' => ['opaque','string','int','int','int','unsigned int','opaque'] => 'opaque');
$ffi->attach('GDALCreateCopy' => [qw/opaque string opaque int opaque GDALProgressFunc opaque/] => 'opaque');
$ffi->attach('GDALIdentifyDriver' => [qw/string opaque/] => 'opaque');
$ffi->attach('GDALIdentifyDriverEx' => ['string','unsigned int','opaque','opaque'] => 'opaque');
$ffi->attach('GDALOpen' => ['string','unsigned int'] => 'opaque');
$ffi->attach('GDALOpenShared' => ['string','unsigned int'] => 'opaque');
$ffi->attach('GDALOpenEx' => ['string','unsigned int','opaque','opaque','opaque'] => 'opaque');
$ffi->attach('GDALDumpOpenDatasets' => [qw/opaque/] => 'int');
$ffi->attach('GDALGetDriverByName' => [qw/string/] => 'opaque');
$ffi->attach('GDALGetDriverCount' => [] => 'int');
$ffi->attach('GDALGetDriver' => [qw/int/] => 'opaque');
$ffi->attach('GDALCreateDriver' => [] => 'opaque');
$ffi->attach('GDALDestroyDriver' => [qw/opaque/] => 'void');
$ffi->attach('GDALRegisterDriver' => [qw/opaque/] => 'int');
$ffi->attach('GDALDeregisterDriver' => [qw/opaque/] => 'void');
$ffi->attach('GDALDestroyDriverManager' => [] => 'void');
$ffi->attach('GDALDestroy' => [] => 'void');
$ffi->attach('GDALDeleteDataset' => [qw/opaque string/] => 'int');
$ffi->attach('GDALRenameDataset' => [qw/opaque string string/] => 'int');
$ffi->attach('GDALCopyDatasetFiles' => [qw/opaque string string/] => 'int');
$ffi->attach('GDALValidateCreationOptions' => [qw/opaque opaque/] => 'int');
$ffi->attach('GDALGetDriverShortName' => [qw/opaque/] => 'string');
$ffi->attach('GDALGetDriverLongName' => [qw/opaque/] => 'string');
$ffi->attach('GDALGetDriverHelpTopic' => [qw/opaque/] => 'string');
$ffi->attach('GDALGetDriverCreationOptionList' => [qw/opaque/] => 'string');
$ffi->attach('GDALInitGCPs' => [qw/int opaque/] => 'void');
$ffi->attach('GDALDeinitGCPs' => [qw/int opaque/] => 'void');
$ffi->attach('GDALDuplicateGCPs' => [qw/int opaque/] => 'opaque');
$ffi->attach('GDALGCPsToGeoTransform' => [qw/int opaque double* int/] => 'int');
$ffi->attach('GDALInvGeoTransform' => [qw/double* double*/] => 'int');
$ffi->attach('GDALApplyGeoTransform' => [qw/double* double double double* double*/] => 'void');
$ffi->attach('GDALComposeGeoTransforms' => [qw/double* double* double*/] => 'void');
$ffi->attach('GDALGetMetadataDomainList' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALGetMetadata' => [qw/opaque string/] => 'opaque');
$ffi->attach('GDALSetMetadata' => [qw/opaque opaque string/] => 'int');
$ffi->attach('GDALGetMetadataItem' => [qw/opaque string string/] => 'string');
$ffi->attach('GDALSetMetadataItem' => [qw/opaque string string string/] => 'int');
$ffi->attach('GDALGetDescription' => [qw/opaque/] => 'string');
$ffi->attach('GDALSetDescription' => [qw/opaque string/] => 'void');
$ffi->attach('GDALGetDatasetDriver' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALGetFileList' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALClose' => [qw/opaque/] => 'int');
$ffi->attach('GDALGetRasterXSize' => [qw/opaque/] => 'int');
$ffi->attach('GDALGetRasterYSize' => [qw/opaque/] => 'int');
$ffi->attach('GDALGetRasterCount' => [qw/opaque/] => 'int');
$ffi->attach('GDALGetRasterBand' => [qw/opaque int/] => 'opaque');
$ffi->attach('GDALAddBand' => ['opaque','unsigned int','opaque'] => 'int');
$ffi->attach('GDALBeginAsyncReader' => ['opaque','int','int','int','int','opaque','int','int','unsigned int','int','int*','int','int','int','opaque'] => 'opaque');
$ffi->attach('GDALEndAsyncReader' => [qw/opaque opaque/] => 'void');
$ffi->attach('GDALDatasetRasterIO' => ['opaque','unsigned int','int','int','int','int','opaque','int','int','unsigned int','int','int*','int','int','int'] => 'int');
$ffi->attach('GDALDatasetRasterIOEx' => ['opaque','unsigned int','int','int','int','int','opaque','int','int','unsigned int','int','int*','sint64','sint64','sint64','opaque'] => 'int');
$ffi->attach('GDALDatasetAdviseRead' => ['opaque','int','int','int','int','int','int','unsigned int','int','int*','opaque'] => 'int');
$ffi->attach('GDALDatasetGetCompressionFormats' => [qw/opaque int int int int int int*/] => 'opaque');
$ffi->attach('GDALDatasetReadCompressedData' => [qw/opaque string int int int int int int* opaque size_t string*/] => 'int');
$ffi->attach('GDALGetProjectionRef' => [qw/opaque/] => 'string');
$ffi->attach('GDALGetSpatialRef' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALSetProjection' => [qw/opaque string/] => 'int');
$ffi->attach('GDALSetSpatialRef' => [qw/opaque opaque/] => 'int');
$ffi->attach('GDALGetGeoTransform' => [qw/opaque double[6]/] => 'int');
$ffi->attach('GDALSetGeoTransform' => [qw/opaque double[6]/] => 'int');
$ffi->attach('GDALGetGCPCount' => [qw/opaque/] => 'int');
$ffi->attach('GDALGetGCPProjection' => [qw/opaque/] => 'string');
$ffi->attach('GDALGetGCPSpatialRef' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALGetGCPs' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALSetGCPs' => [qw/opaque int opaque string/] => 'int');
$ffi->attach('GDALSetGCPs2' => [qw/opaque int opaque opaque/] => 'int');
$ffi->attach('GDALGetInternalHandle' => [qw/opaque string/] => 'opaque');
$ffi->attach('GDALReferenceDataset' => [qw/opaque/] => 'int');
$ffi->attach('GDALDereferenceDataset' => [qw/opaque/] => 'int');
$ffi->attach('GDALReleaseDataset' => [qw/opaque/] => 'int');
$ffi->attach('GDALBuildOverviews' => [qw/opaque string int int* int int* GDALProgressFunc opaque/] => 'int');
$ffi->attach('GDALBuildOverviewsEx' => [qw/opaque string int int* int int* GDALProgressFunc opaque opaque/] => 'int');
$ffi->attach('GDALGetOpenDatasets' => [qw/uint64* int*/] => 'void');
$ffi->attach('GDALGetAccess' => [qw/opaque/] => 'int');
$ffi->attach('GDALFlushCache' => [qw/opaque/] => 'int');
$ffi->attach('GDALCreateDatasetMaskBand' => [qw/opaque int/] => 'int');
$ffi->attach('GDALDatasetCopyWholeRaster' => [qw/opaque opaque opaque GDALProgressFunc opaque/] => 'int');
$ffi->attach('GDALRasterBandCopyWholeRaster' => [qw/opaque opaque opaque GDALProgressFunc opaque/] => 'int');
$ffi->attach('GDALRegenerateOverviews' => [qw/opaque int uint64* string GDALProgressFunc opaque/] => 'int');
$ffi->attach('GDALRegenerateOverviewsEx' => [qw/opaque int uint64* string GDALProgressFunc opaque opaque/] => 'int');
$ffi->attach('GDALDatasetGetLayerCount' => [qw/opaque/] => 'int');
$ffi->attach('GDALDatasetGetLayer' => [qw/opaque int/] => 'opaque');
$ffi->attach('GDALDatasetGetLayerByName' => [qw/opaque string/] => 'opaque');
$ffi->attach('GDALDatasetIsLayerPrivate' => [qw/opaque int/] => 'int');
$ffi->attach('GDALDatasetDeleteLayer' => [qw/opaque int/] => 'int');
$ffi->attach('GDALDatasetCreateLayer' => ['opaque','string','opaque','unsigned int','opaque'] => 'opaque');
$ffi->attach('GDALDatasetCopyLayer' => [qw/opaque opaque string opaque/] => 'opaque');
$ffi->attach('GDALDatasetResetReading' => [qw/opaque/] => 'void');
$ffi->attach('GDALDatasetGetNextFeature' => [qw/opaque uint64* double* GDALProgressFunc opaque/] => 'opaque');
$ffi->attach('GDALDatasetTestCapability' => [qw/opaque string/] => 'int');
$ffi->attach('GDALDatasetExecuteSQL' => [qw/opaque string opaque string/] => 'opaque');
$ffi->attach('GDALDatasetAbortSQL' => [qw/opaque/] => 'int');
$ffi->attach('GDALDatasetReleaseResultSet' => [qw/opaque opaque/] => 'void');
$ffi->attach('GDALDatasetGetStyleTable' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALDatasetSetStyleTableDirectly' => [qw/opaque opaque/] => 'void');
$ffi->attach('GDALDatasetSetStyleTable' => [qw/opaque opaque/] => 'void');
$ffi->attach('GDALDatasetStartTransaction' => [qw/opaque int/] => 'int');
$ffi->attach('GDALDatasetCommitTransaction' => [qw/opaque/] => 'int');
$ffi->attach('GDALDatasetRollbackTransaction' => [qw/opaque/] => 'int');
$ffi->attach('GDALDatasetClearStatistics' => [qw/opaque/] => 'void');
$ffi->attach('GDALDatasetGetFieldDomainNames' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALDatasetGetFieldDomain' => [qw/opaque string/] => 'opaque');
$ffi->attach('GDALDatasetAddFieldDomain' => [qw/opaque opaque string*/] => 'bool');
$ffi->attach('GDALDatasetDeleteFieldDomain' => [qw/opaque string string*/] => 'bool');
$ffi->attach('GDALDatasetUpdateFieldDomain' => [qw/opaque opaque string*/] => 'bool');
$ffi->attach('GDALDatasetGetRelationshipNames' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALDatasetGetRelationship' => [qw/opaque string/] => 'opaque');
$ffi->attach('GDALDatasetAddRelationship' => [qw/opaque opaque string*/] => 'bool');
$ffi->attach('GDALDatasetDeleteRelationship' => [qw/opaque string string*/] => 'bool');
$ffi->attach('GDALDatasetUpdateRelationship' => [qw/opaque opaque string*/] => 'bool');
$ffi->attach('GDALDatasetSetQueryLoggerFunc' => [qw/opaque GDALQueryLoggerFunc opaque/] => 'bool');
$ffi->attach('GDALGetRasterDataType' => [qw/opaque/] => 'unsigned int');
$ffi->attach('GDALGetBlockSize' => [qw/opaque int* int*/] => 'void');
$ffi->attach('GDALGetActualBlockSize' => [qw/opaque int int int* int*/] => 'int');
$ffi->attach('GDALRasterAdviseRead' => ['opaque','int','int','int','int','int','int','unsigned int','opaque'] => 'int');
$ffi->attach('GDALRasterIO' => ['opaque','unsigned int','int','int','int','int','opaque','int','int','unsigned int','int','int'] => 'int');
$ffi->attach('GDALRasterIOEx' => ['opaque','unsigned int','int','int','int','int','opaque','int','int','unsigned int','sint64','sint64','opaque'] => 'int');
$ffi->attach('GDALReadBlock' => [qw/opaque int int opaque/] => 'int');
$ffi->attach('GDALWriteBlock' => [qw/opaque int int opaque/] => 'int');
$ffi->attach('GDALGetRasterBandXSize' => [qw/opaque/] => 'int');
$ffi->attach('GDALGetRasterBandYSize' => [qw/opaque/] => 'int');
$ffi->attach('GDALGetRasterAccess' => [qw/opaque/] => 'unsigned int');
$ffi->attach('GDALGetBandNumber' => [qw/opaque/] => 'int');
$ffi->attach('GDALGetBandDataset' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALGetRasterColorInterpretation' => [qw/opaque/] => 'unsigned int');
$ffi->attach('GDALSetRasterColorInterpretation' => ['opaque','unsigned int'] => 'int');
$ffi->attach('GDALGetRasterColorTable' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALSetRasterColorTable' => [qw/opaque opaque/] => 'int');
$ffi->attach('GDALHasArbitraryOverviews' => [qw/opaque/] => 'int');
$ffi->attach('GDALGetOverviewCount' => [qw/opaque/] => 'int');
$ffi->attach('GDALGetOverview' => [qw/opaque int/] => 'opaque');
$ffi->attach('GDALGetRasterNoDataValue' => [qw/opaque int*/] => 'double');
$ffi->attach('GDALGetRasterNoDataValueAsInt64' => [qw/opaque int*/] => 'int');
$ffi->attach('GDALGetRasterNoDataValueAsUInt64' => [qw/opaque int*/] => 'uint64');
$ffi->attach('GDALSetRasterNoDataValue' => [qw/opaque double/] => 'int');
$ffi->attach('GDALSetRasterNoDataValueAsInt64' => [qw/opaque int/] => 'int');
$ffi->attach('GDALSetRasterNoDataValueAsUInt64' => [qw/opaque uint64/] => 'int');
$ffi->attach('GDALDeleteRasterNoDataValue' => [qw/opaque/] => 'int');
$ffi->attach('GDALGetRasterCategoryNames' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALSetRasterCategoryNames' => [qw/opaque opaque/] => 'int');
$ffi->attach('GDALGetRasterMinimum' => [qw/opaque int*/] => 'double');
$ffi->attach('GDALGetRasterMaximum' => [qw/opaque int*/] => 'double');
$ffi->attach('GDALGetRasterStatistics' => [qw/opaque int int double* double* double* double*/] => 'int');
$ffi->attach('GDALComputeRasterStatistics' => [qw/opaque int double* double* double* double* GDALProgressFunc opaque/] => 'int');
$ffi->attach('GDALSetRasterStatistics' => [qw/opaque double double double double/] => 'int');
$ffi->attach('GDALRasterBandAsMDArray' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALGetRasterUnitType' => [qw/opaque/] => 'string');
$ffi->attach('GDALSetRasterUnitType' => [qw/opaque string/] => 'int');
$ffi->attach('GDALGetRasterOffset' => [qw/opaque int*/] => 'double');
$ffi->attach('GDALSetRasterOffset' => [qw/opaque double/] => 'int');
$ffi->attach('GDALGetRasterScale' => [qw/opaque int*/] => 'double');
$ffi->attach('GDALSetRasterScale' => [qw/opaque double/] => 'int');
$ffi->attach('GDALComputeRasterMinMax' => [qw/opaque int double/] => 'int');
$ffi->attach('GDALFlushRasterCache' => [qw/opaque/] => 'int');
$ffi->attach('GDALGetRasterHistogram' => [qw/opaque double double int int* int int GDALProgressFunc opaque/] => 'int');
$ffi->attach('GDALGetRasterHistogramEx' => [qw/opaque double double int uint64* int int GDALProgressFunc opaque/] => 'int');
$ffi->attach('GDALGetDefaultHistogram' => [qw/opaque double* double* int* int* int GDALProgressFunc opaque/] => 'int');
$ffi->attach('GDALGetDefaultHistogramEx' => [qw/opaque double* double* int* uint64* int GDALProgressFunc opaque/] => 'int');
$ffi->attach('GDALSetDefaultHistogram' => [qw/opaque double double int int*/] => 'int');
$ffi->attach('GDALSetDefaultHistogramEx' => [qw/opaque double double int uint64*/] => 'int');
$ffi->attach('GDALGetRandomRasterSample' => [qw/opaque int float*/] => 'int');
$ffi->attach('GDALGetRasterSampleOverview' => [qw/opaque int/] => 'opaque');
$ffi->attach('GDALGetRasterSampleOverviewEx' => [qw/opaque uint64/] => 'opaque');
$ffi->attach('GDALFillRaster' => [qw/opaque double double/] => 'int');
$ffi->attach('GDALComputeBandStats' => [qw/opaque int double* double* GDALProgressFunc opaque/] => 'int');
$ffi->attach('GDALOverviewMagnitudeCorrection' => [qw/opaque int uint64* GDALProgressFunc opaque/] => 'int');
$ffi->attach('GDALGetDefaultRAT' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALSetDefaultRAT' => [qw/opaque opaque/] => 'int');
$ffi->attach('GDALAddDerivedBandPixelFunc' => [qw/string GDALDerivedPixelFunc/] => 'int');
$ffi->attach('GDALAddDerivedBandPixelFuncWithArgs' => [qw/string GDALDerivedPixelFunc string/] => 'int');
$ffi->attach('GDALGetMaskBand' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALGetMaskFlags' => [qw/opaque/] => 'int');
$ffi->attach('GDALCreateMaskBand' => [qw/opaque int/] => 'int');
$ffi->attach('GDALIsMaskBand' => [qw/opaque/] => 'bool');
$ffi->attach('GDALGetDataCoverageStatus' => [qw/opaque int int int int int double*/] => 'int');
$ffi->attach('GDALARGetNextUpdatedRegion' => [qw/opaque double int* int* int* int*/] => 'unsigned int');
$ffi->attach('GDALARLockBuffer' => [qw/opaque double/] => 'int');
$ffi->attach('GDALARUnlockBuffer' => [qw/opaque/] => 'void');
$ffi->attach('GDALGeneralCmdLineProcessor' => [qw/int string* int/] => 'int');
$ffi->attach('GDALSwapWords' => [qw/opaque int int int/] => 'void');
$ffi->attach('GDALSwapWordsEx' => [qw/opaque int size_t int/] => 'void');
$ffi->attach('GDALCopyWords' => ['opaque','unsigned int','int','opaque','unsigned int','int','int'] => 'void');
$ffi->attach('GDALCopyWords64' => ['opaque','unsigned int','int','opaque','unsigned int','int','int'] => 'void');
$ffi->attach('GDALCopyBits' => [qw/pointer int int pointer int int int int/] => 'void');
$ffi->attach('GDALDeinterleave' => ['opaque','unsigned int','int','opaque','unsigned int','size_t'] => 'void');
$ffi->attach('GDALLoadWorldFile' => [qw/string double*/] => 'int');
$ffi->attach('GDALReadWorldFile' => [qw/string string double*/] => 'int');
$ffi->attach('GDALWriteWorldFile' => [qw/string string double*/] => 'int');
$ffi->attach('GDALLoadTabFile' => [qw/string double* string* int* opaque/] => 'int');
$ffi->attach('GDALReadTabFile' => [qw/string double* string* int* opaque/] => 'int');
$ffi->attach('GDALLoadOziMapFile' => [qw/string double* string* int* opaque/] => 'int');
$ffi->attach('GDALReadOziMapFile' => [qw/string double* string* int* opaque/] => 'int');
$ffi->attach('GDALDecToDMS' => [qw/double string int/] => 'string');
$ffi->attach('GDALPackedDMSToDec' => [qw/double/] => 'double');
$ffi->attach('GDALDecToPackedDMS' => [qw/double/] => 'double');
$ffi->attach('GDALVersionInfo' => [qw/string/] => 'string');
$ffi->attach('GDALCheckVersion' => [qw/int int string/] => 'int');
$ffi->attach('GDALExtractRPCInfoV1' => [qw/opaque opaque/] => 'int');
$ffi->attach('GDALExtractRPCInfoV2' => [qw/opaque opaque/] => 'int');
$ffi->attach('GDALCreateColorTable' => ['unsigned int'] => 'opaque');
$ffi->attach('GDALDestroyColorTable' => [qw/opaque/] => 'void');
$ffi->attach('GDALCloneColorTable' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALGetPaletteInterpretation' => [qw/opaque/] => 'unsigned int');
$ffi->attach('GDALGetColorEntryCount' => [qw/opaque/] => 'int');
$ffi->attach('GDALGetColorEntry' => [qw/opaque int/] => 'short[4]');
$ffi->attach('GDALGetColorEntryAsRGB' => [qw/opaque int short[4]/] => 'int');
$ffi->attach('GDALSetColorEntry' => [qw/opaque int short[4]/] => 'void');
$ffi->attach('GDALCreateColorRamp' => [qw/opaque int short[4] int short[4]/] => 'void');
$ffi->attach('GDALCreateRasterAttributeTable' => [] => 'opaque');
$ffi->attach('GDALDestroyRasterAttributeTable' => [qw/opaque/] => 'void');
$ffi->attach('GDALRATGetColumnCount' => [qw/opaque/] => 'int');
$ffi->attach('GDALRATGetNameOfCol' => [qw/opaque int/] => 'string');
$ffi->attach('GDALRATGetUsageOfCol' => [qw/opaque int/] => 'unsigned int');
$ffi->attach('GDALRATGetTypeOfCol' => [qw/opaque int/] => 'unsigned int');
$ffi->attach('GDALRATGetColOfUsage' => ['opaque','unsigned int'] => 'int');
$ffi->attach('GDALRATGetRowCount' => [qw/opaque/] => 'int');
$ffi->attach('GDALRATGetValueAsString' => [qw/opaque int int/] => 'string');
$ffi->attach('GDALRATGetValueAsInt' => [qw/opaque int int/] => 'int');
$ffi->attach('GDALRATGetValueAsDouble' => [qw/opaque int int/] => 'double');
$ffi->attach('GDALRATSetValueAsString' => [qw/opaque int int string/] => 'void');
$ffi->attach('GDALRATSetValueAsInt' => [qw/opaque int int int/] => 'void');
$ffi->attach('GDALRATSetValueAsDouble' => [qw/opaque int int double/] => 'void');
$ffi->attach('GDALRATChangesAreWrittenToFile' => [qw/opaque/] => 'int');
$ffi->attach('GDALRATValuesIOAsDouble' => ['opaque','unsigned int','int','int','int','double*'] => 'int');
$ffi->attach('GDALRATValuesIOAsInteger' => ['opaque','unsigned int','int','int','int','int*'] => 'int');
$ffi->attach('GDALRATValuesIOAsString' => ['opaque','unsigned int','int','int','int','opaque'] => 'int');
$ffi->attach('GDALRATSetRowCount' => [qw/opaque int/] => 'void');
$ffi->attach('GDALRATCreateColumn' => ['opaque','string','unsigned int','unsigned int'] => 'int');
$ffi->attach('GDALRATSetLinearBinning' => [qw/opaque double double/] => 'int');
$ffi->attach('GDALRATGetLinearBinning' => [qw/opaque double* double*/] => 'int');
$ffi->attach('GDALRATSetTableType' => ['opaque','unsigned int'] => 'int');
$ffi->attach('GDALRATGetTableType' => [qw/opaque/] => 'unsigned int');
$ffi->attach('GDALRATInitializeFromColorTable' => [qw/opaque opaque/] => 'int');
$ffi->attach('GDALRATTranslateToColorTable' => [qw/opaque int/] => 'opaque');
$ffi->attach('GDALRATDumpReadable' => [qw/opaque opaque/] => 'void');
$ffi->attach('GDALRATClone' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALRATSerializeJSON' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALRATGetRowOfValue' => [qw/opaque double/] => 'int');
$ffi->attach('GDALRATRemoveStatistics' => [qw/opaque/] => 'void');
$ffi->attach('GDALRelationshipCreate' => ['string','string','string','unsigned int'] => 'opaque');
$ffi->attach('GDALDestroyRelationship' => [qw/opaque/] => 'void');
$ffi->attach('GDALRelationshipGetName' => [qw/opaque/] => 'string');
$ffi->attach('GDALRelationshipGetCardinality' => [qw/opaque/] => 'unsigned int');
$ffi->attach('GDALRelationshipGetLeftTableName' => [qw/opaque/] => 'string');
$ffi->attach('GDALRelationshipGetRightTableName' => [qw/opaque/] => 'string');
$ffi->attach('GDALRelationshipGetMappingTableName' => [qw/opaque/] => 'string');
$ffi->attach('GDALRelationshipSetMappingTableName' => [qw/opaque string/] => 'void');
$ffi->attach('GDALRelationshipGetLeftTableFields' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALRelationshipGetRightTableFields' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALRelationshipSetLeftTableFields' => [qw/opaque opaque/] => 'void');
$ffi->attach('GDALRelationshipSetRightTableFields' => [qw/opaque opaque/] => 'void');
$ffi->attach('GDALRelationshipGetLeftMappingTableFields' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALRelationshipGetRightMappingTableFields' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALRelationshipSetLeftMappingTableFields' => [qw/opaque opaque/] => 'void');
$ffi->attach('GDALRelationshipSetRightMappingTableFields' => [qw/opaque opaque/] => 'void');
$ffi->attach('GDALRelationshipGetType' => [qw/opaque/] => 'unsigned int');
$ffi->attach('GDALRelationshipSetType' => ['opaque','unsigned int'] => 'void');
$ffi->attach('GDALRelationshipGetForwardPathLabel' => [qw/opaque/] => 'string');
$ffi->attach('GDALRelationshipSetForwardPathLabel' => [qw/opaque string/] => 'void');
$ffi->attach('GDALRelationshipGetBackwardPathLabel' => [qw/opaque/] => 'string');
$ffi->attach('GDALRelationshipSetBackwardPathLabel' => [qw/opaque string/] => 'void');
$ffi->attach('GDALRelationshipGetRelatedTableType' => [qw/opaque/] => 'string');
$ffi->attach('GDALRelationshipSetRelatedTableType' => [qw/opaque string/] => 'void');
$ffi->attach('GDALSetCacheMax' => [qw/int/] => 'void');
$ffi->attach('GDALGetCacheMax' => [] => 'int');
$ffi->attach('GDALGetCacheUsed' => [] => 'int');
$ffi->attach('GDALSetCacheMax64' => [qw/sint64/] => 'void');
$ffi->attach('GDALGetCacheMax64' => [] => 'sint64');
$ffi->attach('GDALGetCacheUsed64' => [] => 'sint64');
$ffi->attach('GDALFlushCacheBlock' => [] => 'int');
$ffi->attach('GDALDatasetGetVirtualMem' => ['opaque','unsigned int','int','int','int','int','int','int','unsigned int','int','int*','int','sint64','sint64','size_t','size_t','int','opaque'] => 'opaque');
$ffi->attach('GDALRasterBandGetVirtualMem' => ['opaque','unsigned int','int','int','int','int','int','int','unsigned int','int','sint64','size_t','size_t','int','opaque'] => 'opaque');
$ffi->attach('GDALGetVirtualMemAuto' => ['opaque','unsigned int','int*','sint64*','opaque'] => 'opaque');
$ffi->attach('GDALDatasetGetTiledVirtualMem' => ['opaque','unsigned int','int','int','int','int','int','int','unsigned int','int','int*','unsigned int','size_t','int','opaque'] => 'opaque');
$ffi->attach('GDALRasterBandGetTiledVirtualMem' => ['opaque','unsigned int','int','int','int','int','int','int','unsigned int','size_t','int','opaque'] => 'opaque');
$ffi->attach('GDALCreatePansharpenedVRT' => [qw/string opaque int uint64*/] => 'opaque');
$ffi->attach('GDALGetJPEG2000Structure' => [qw/string opaque/] => 'opaque');
$ffi->attach('GDALCreateMultiDimensional' => [qw/opaque string opaque opaque/] => 'opaque');
$ffi->attach('GDALExtendedDataTypeCreate' => ['unsigned int'] => 'opaque');
$ffi->attach('GDALExtendedDataTypeCreateString' => [qw/size_t/] => 'opaque');
$ffi->attach('GDALExtendedDataTypeCreateStringEx' => [qw/size_t int/] => 'opaque');
$ffi->attach('GDALExtendedDataTypeCreateCompound' => [qw/string size_t size_t opaque/] => 'opaque');
$ffi->attach('GDALExtendedDataTypeRelease' => [qw/opaque/] => 'void');
$ffi->attach('GDALExtendedDataTypeGetName' => [qw/opaque/] => 'string');
$ffi->attach('GDALExtendedDataTypeGetClass' => [qw/opaque/] => 'int');
$ffi->attach('GDALExtendedDataTypeGetNumericDataType' => [qw/opaque/] => 'unsigned int');
$ffi->attach('GDALExtendedDataTypeGetSize' => [qw/opaque/] => 'size_t');
$ffi->attach('GDALExtendedDataTypeGetMaxStringLength' => [qw/opaque/] => 'size_t');
$ffi->attach('GDALExtendedDataTypeGetComponents' => [qw/opaque size_t/] => 'uint64*');
$ffi->attach('GDALExtendedDataTypeFreeComponents' => [qw/uint64* size_t/] => 'void');
$ffi->attach('GDALExtendedDataTypeCanConvertTo' => [qw/opaque opaque/] => 'int');
$ffi->attach('GDALExtendedDataTypeEquals' => [qw/opaque opaque/] => 'int');
$ffi->attach('GDALExtendedDataTypeGetSubType' => [qw/opaque/] => 'int');
$ffi->attach('GDALEDTComponentCreate' => [qw/string size_t opaque/] => 'opaque');
$ffi->attach('GDALEDTComponentRelease' => [qw/opaque/] => 'void');
$ffi->attach('GDALEDTComponentGetName' => [qw/opaque/] => 'string');
$ffi->attach('GDALEDTComponentGetOffset' => [qw/opaque/] => 'size_t');
$ffi->attach('GDALEDTComponentGetType' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALDatasetGetRootGroup' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALGroupRelease' => [qw/opaque/] => 'void');
$ffi->attach('GDALGroupGetName' => [qw/opaque/] => 'string');
$ffi->attach('GDALGroupGetFullName' => [qw/opaque/] => 'string');
$ffi->attach('GDALGroupGetMDArrayNames' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALGroupOpenMDArray' => [qw/opaque string opaque/] => 'opaque');
$ffi->attach('GDALGroupOpenMDArrayFromFullname' => [qw/opaque string opaque/] => 'opaque');
$ffi->attach('GDALGroupResolveMDArray' => [qw/opaque string string opaque/] => 'opaque');
$ffi->attach('GDALGroupGetGroupNames' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALGroupOpenGroup' => [qw/opaque string opaque/] => 'opaque');
$ffi->attach('GDALGroupOpenGroupFromFullname' => [qw/opaque string opaque/] => 'opaque');
$ffi->attach('GDALGroupGetVectorLayerNames' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALGroupOpenVectorLayer' => [qw/opaque string opaque/] => 'opaque');
$ffi->attach('GDALGroupGetDimensions' => [qw/opaque size_t opaque/] => 'uint64*');
$ffi->attach('GDALGroupGetAttribute' => [qw/opaque string/] => 'opaque');
$ffi->attach('GDALGroupGetAttributes' => [qw/opaque size_t opaque/] => 'uint64*');
$ffi->attach('GDALGroupGetStructuralInfo' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALGroupCreateGroup' => [qw/opaque string opaque/] => 'opaque');
$ffi->attach('GDALGroupCreateDimension' => [qw/opaque string string string uint64 opaque/] => 'opaque');
$ffi->attach('GDALGroupCreateMDArray' => [qw/opaque string size_t uint64* opaque opaque/] => 'opaque');
$ffi->attach('GDALGroupCreateAttribute' => [qw/opaque string size_t uint64* opaque opaque/] => 'opaque');
$ffi->attach('GDALMDArrayRelease' => [qw/opaque/] => 'void');
$ffi->attach('GDALMDArrayGetName' => [qw/opaque/] => 'string');
$ffi->attach('GDALMDArrayGetFullName' => [qw/opaque/] => 'string');
$ffi->attach('GDALMDArrayGetTotalElementsCount' => [qw/opaque/] => 'uint64');
$ffi->attach('GDALMDArrayGetDimensionCount' => [qw/opaque/] => 'size_t');
$ffi->attach('GDALMDArrayGetDimensions' => [qw/opaque size_t/] => 'uint64*');
$ffi->attach('GDALMDArrayGetDataType' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALMDArrayRead' => [qw/opaque uint64* size_t sint64 int* opaque opaque opaque size_t/] => 'int');
$ffi->attach('GDALMDArrayWrite' => [qw/opaque uint64* size_t sint64 int* opaque opaque opaque size_t/] => 'int');
$ffi->attach('GDALMDArrayAdviseRead' => [qw/opaque uint64* size_t/] => 'int');
$ffi->attach('GDALMDArrayAdviseReadEx' => [qw/opaque uint64* size_t opaque/] => 'int');
$ffi->attach('GDALMDArrayGetAttribute' => [qw/opaque string/] => 'opaque');
$ffi->attach('GDALMDArrayGetAttributes' => [qw/opaque size_t opaque/] => 'uint64*');
$ffi->attach('GDALMDArrayCreateAttribute' => [qw/opaque string size_t uint64* opaque opaque/] => 'opaque');
$ffi->attach('GDALMDArrayResize' => [qw/opaque uint64* opaque/] => 'bool');
$ffi->attach('GDALMDArrayGetRawNoDataValue' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALMDArrayGetNoDataValueAsDouble' => [qw/opaque int*/] => 'double');
$ffi->attach('GDALMDArrayGetNoDataValueAsInt64' => [qw/opaque int*/] => 'int');
$ffi->attach('GDALMDArrayGetNoDataValueAsUInt64' => [qw/opaque int*/] => 'uint64');
$ffi->attach('GDALMDArraySetRawNoDataValue' => [qw/opaque opaque/] => 'int');
$ffi->attach('GDALMDArraySetNoDataValueAsDouble' => [qw/opaque double/] => 'int');
$ffi->attach('GDALMDArraySetNoDataValueAsInt64' => [qw/opaque int/] => 'int');
$ffi->attach('GDALMDArraySetNoDataValueAsUInt64' => [qw/opaque uint64/] => 'int');
$ffi->attach('GDALMDArraySetScale' => [qw/opaque double/] => 'int');
$ffi->attach('GDALMDArraySetScaleEx' => ['opaque','double','unsigned int'] => 'int');
$ffi->attach('GDALMDArrayGetScale' => [qw/opaque int*/] => 'double');
$ffi->attach('GDALMDArrayGetScaleEx' => ['opaque','int*','unsigned int'] => 'double');
$ffi->attach('GDALMDArraySetOffset' => [qw/opaque double/] => 'int');
$ffi->attach('GDALMDArraySetOffsetEx' => ['opaque','double','unsigned int'] => 'int');
$ffi->attach('GDALMDArrayGetOffset' => [qw/opaque int*/] => 'double');
$ffi->attach('GDALMDArrayGetOffsetEx' => ['opaque','int*','unsigned int'] => 'double');
$ffi->attach('GDALMDArrayGetBlockSize' => [qw/opaque size_t/] => 'uint64');
$ffi->attach('GDALMDArraySetUnit' => [qw/opaque string/] => 'int');
$ffi->attach('GDALMDArrayGetUnit' => [qw/opaque/] => 'string');
$ffi->attach('GDALMDArraySetSpatialRef' => [qw/opaque opaque/] => 'int');
$ffi->attach('GDALMDArrayGetSpatialRef' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALMDArrayGetProcessingChunkSize' => [qw/opaque size_t size_t/] => 'size_t');
$ffi->attach('GDALMDArrayGetStructuralInfo' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALMDArrayGetView' => [qw/opaque string/] => 'opaque');
$ffi->attach('GDALMDArrayTranspose' => [qw/opaque size_t int*/] => 'opaque');
$ffi->attach('GDALMDArrayGetUnscaled' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALMDArrayGetMask' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALMDArrayAsClassicDataset' => [qw/opaque size_t size_t/] => 'opaque');
$ffi->attach('GDALMDArrayGetStatistics' => [qw/opaque opaque int int double* double* double* double* uint64 GDALProgressFunc opaque/] => 'int');
$ffi->attach('GDALMDArrayComputeStatistics' => [qw/opaque opaque int double* double* double* double* uint64 GDALProgressFunc opaque/] => 'int');
$ffi->attach('GDALMDArrayGetResampled' => [qw/opaque size_t opaque int opaque opaque/] => 'opaque');
$ffi->attach('GDALMDArrayGetGridded' => [qw/opaque string opaque opaque opaque/] => 'opaque');
$ffi->attach('GDALMDArrayGetCoordinateVariables' => [qw/opaque size_t/] => 'uint64*');
$ffi->attach('GDALReleaseArrays' => [qw/uint64* size_t/] => 'void');
$ffi->attach('GDALMDArrayCache' => [qw/opaque opaque/] => 'int');
$ffi->attach('GDALAttributeRelease' => [qw/opaque/] => 'void');
$ffi->attach('GDALReleaseAttributes' => [qw/uint64* size_t/] => 'void');
$ffi->attach('GDALAttributeGetName' => [qw/opaque/] => 'string');
$ffi->attach('GDALAttributeGetFullName' => [qw/opaque/] => 'string');
$ffi->attach('GDALAttributeGetTotalElementsCount' => [qw/opaque/] => 'uint64');
$ffi->attach('GDALAttributeGetDimensionCount' => [qw/opaque/] => 'size_t');
$ffi->attach('GDALAttributeGetDimensionsSize' => [qw/opaque size_t/] => 'uint64');
$ffi->attach('GDALAttributeGetDataType' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALAttributeReadAsRaw' => [qw/opaque size_t/] => 'pointer');
$ffi->attach('GDALAttributeFreeRawResult' => [qw/opaque pointer size_t/] => 'void');
$ffi->attach('GDALAttributeReadAsString' => [qw/opaque/] => 'string');
$ffi->attach('GDALAttributeReadAsInt' => [qw/opaque/] => 'int');
$ffi->attach('GDALAttributeReadAsDouble' => [qw/opaque/] => 'double');
$ffi->attach('GDALAttributeReadAsStringArray' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALAttributeReadAsIntArray' => [qw/opaque size_t/] => 'int*');
$ffi->attach('GDALAttributeReadAsDoubleArray' => [qw/opaque size_t/] => 'double*');
$ffi->attach('GDALAttributeWriteRaw' => [qw/opaque opaque size_t/] => 'int');
$ffi->attach('GDALAttributeWriteString' => [qw/opaque string/] => 'int');
$ffi->attach('GDALAttributeWriteStringArray' => [qw/opaque opaque/] => 'int');
$ffi->attach('GDALAttributeWriteInt' => [qw/opaque int/] => 'int');
$ffi->attach('GDALAttributeWriteDouble' => [qw/opaque double/] => 'int');
$ffi->attach('GDALAttributeWriteDoubleArray' => [qw/opaque double* size_t/] => 'int');
$ffi->attach('GDALDimensionRelease' => [qw/opaque/] => 'void');
$ffi->attach('GDALReleaseDimensions' => [qw/uint64* size_t/] => 'void');
$ffi->attach('GDALDimensionGetName' => [qw/opaque/] => 'string');
$ffi->attach('GDALDimensionGetFullName' => [qw/opaque/] => 'string');
$ffi->attach('GDALDimensionGetType' => [qw/opaque/] => 'string');
$ffi->attach('GDALDimensionGetDirection' => [qw/opaque/] => 'string');
$ffi->attach('GDALDimensionGetSize' => [qw/opaque/] => 'uint64');
$ffi->attach('GDALDimensionGetIndexingVariable' => [qw/opaque/] => 'opaque');
$ffi->attach('GDALDimensionSetIndexingVariable' => [qw/opaque opaque/] => 'int');
# from ogr/ogr_api.h
$ffi->attach('OGRGetGEOSVersion' => [qw/int* int* int*/] => 'bool');
$ffi->attach('OGR_G_CreateFromWkb' => [qw/string opaque uint64* int/] => 'int');
$ffi->attach('OGR_G_CreateFromWkbEx' => [qw/opaque opaque uint64* size_t/] => 'int');
$ffi->attach('OGR_G_CreateFromWkt' => [qw/string* opaque uint64*/] => 'int');
$ffi->attach('OGR_G_CreateFromFgf' => [qw/string opaque uint64* int int*/] => 'int');
$ffi->attach('OGR_G_DestroyGeometry' => [qw/opaque/] => 'void');
$ffi->attach('OGR_G_CreateGeometry' => ['unsigned int'] => 'opaque');
$ffi->attach('OGR_G_ApproximateArcAngles' => [qw/double double double double double double double double double/] => 'opaque');
$ffi->attach('OGR_G_ForceToPolygon' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_ForceToLineString' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_ForceToMultiPolygon' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_ForceToMultiPoint' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_ForceToMultiLineString' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_ForceTo' => ['opaque','unsigned int','opaque'] => 'opaque');
$ffi->attach('OGR_G_RemoveLowerDimensionSubGeoms' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_GetDimension' => [qw/opaque/] => 'int');
$ffi->attach('OGR_G_GetCoordinateDimension' => [qw/opaque/] => 'int');
$ffi->attach('OGR_G_CoordinateDimension' => [qw/opaque/] => 'int');
$ffi->attach('OGR_G_SetCoordinateDimension' => [qw/opaque int/] => 'void');
$ffi->attach('OGR_G_Is3D' => [qw/opaque/] => 'int');
$ffi->attach('OGR_G_IsMeasured' => [qw/opaque/] => 'int');
$ffi->attach('OGR_G_Set3D' => [qw/opaque int/] => 'void');
$ffi->attach('OGR_G_SetMeasured' => [qw/opaque int/] => 'void');
$ffi->attach('OGR_G_Clone' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_GetEnvelope' => [qw/opaque double[4]/] => 'void');
$ffi->attach('OGR_G_GetEnvelope3D' => [qw/opaque double[6]/] => 'void');
$ffi->attach('OGR_G_ImportFromWkb' => [qw/opaque string int/] => 'int');
$ffi->attach('OGR_G_ExportToWkb' => ['opaque','unsigned int','string'] => 'int');
$ffi->attach('OGR_G_ExportToIsoWkb' => ['opaque','unsigned int','string'] => 'int');
$ffi->attach('OGR_G_WkbSize' => [qw/opaque/] => 'int');
$ffi->attach('OGR_G_WkbSizeEx' => [qw/opaque/] => 'size_t');
$ffi->attach('OGR_G_ImportFromWkt' => [qw/opaque string*/] => 'int');
$ffi->attach('OGR_G_ExportToWkt' => [qw/opaque string*/] => 'int');
$ffi->attach('OGR_G_ExportToIsoWkt' => [qw/opaque string*/] => 'int');
$ffi->attach('OGR_G_GetGeometryType' => [qw/opaque/] => 'unsigned int');
$ffi->attach('OGR_G_GetGeometryName' => [qw/opaque/] => 'string');
$ffi->attach('OGR_G_DumpReadable' => [qw/opaque opaque string/] => 'void');
$ffi->attach('OGR_G_FlattenTo2D' => [qw/opaque/] => 'void');
$ffi->attach('OGR_G_CloseRings' => [qw/opaque/] => 'void');
$ffi->attach('OGR_G_CreateFromGML' => [qw/string/] => 'opaque');
$ffi->attach('OGR_G_ExportToGML' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_ExportToGMLEx' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('OGR_G_CreateFromGMLTree' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_ExportToGMLTree' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_ExportEnvelopeToGMLTree' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_ExportToKML' => [qw/opaque string/] => 'opaque');
$ffi->attach('OGR_G_ExportToJson' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_ExportToJsonEx' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('OGR_G_CreateGeometryFromJson' => [qw/string/] => 'opaque');
$ffi->attach('OGR_G_CreateGeometryFromEsriJson' => [qw/string/] => 'opaque');
$ffi->attach('OGR_G_AssignSpatialReference' => [qw/opaque opaque/] => 'void');
$ffi->attach('OGR_G_GetSpatialReference' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_Transform' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_G_TransformTo' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_GeomTransformer_Create' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('OGR_GeomTransformer_Transform' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('OGR_GeomTransformer_Destroy' => [qw/opaque/] => 'void');
$ffi->attach('OGR_G_Simplify' => [qw/opaque double/] => 'opaque');
$ffi->attach('OGR_G_SimplifyPreserveTopology' => [qw/opaque double/] => 'opaque');
$ffi->attach('OGR_G_DelaunayTriangulation' => [qw/opaque double int/] => 'opaque');
$ffi->attach('OGR_G_Segmentize' => [qw/opaque double/] => 'void');
$ffi->attach('OGR_G_Intersects' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_G_Equals' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_G_Disjoint' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_G_Touches' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_G_Crosses' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_G_Within' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_G_Contains' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_G_Overlaps' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_G_Boundary' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_ConvexHull' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_ConcaveHull' => [qw/opaque double bool/] => 'opaque');
$ffi->attach('OGR_G_Buffer' => [qw/opaque double int/] => 'opaque');
$ffi->attach('OGR_G_Intersection' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('OGR_G_Union' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('OGR_G_UnionCascaded' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_UnaryUnion' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_PointOnSurface' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_Difference' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('OGR_G_SymDifference' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('OGR_G_Distance' => [qw/opaque opaque/] => 'double');
$ffi->attach('OGR_G_Distance3D' => [qw/opaque opaque/] => 'double');
$ffi->attach('OGR_G_Length' => [qw/opaque/] => 'double');
$ffi->attach('OGR_G_Area' => [qw/opaque/] => 'double');
$ffi->attach('OGR_G_Centroid' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_G_Value' => [qw/opaque double/] => 'opaque');
$ffi->attach('OGR_G_Empty' => [qw/opaque/] => 'void');
$ffi->attach('OGR_G_IsEmpty' => [qw/opaque/] => 'int');
$ffi->attach('OGR_G_IsValid' => [qw/opaque/] => 'int');
$ffi->attach('OGR_G_MakeValid' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_MakeValidEx' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('OGR_G_Normalize' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_IsSimple' => [qw/opaque/] => 'int');
$ffi->attach('OGR_G_IsRing' => [qw/opaque/] => 'int');
$ffi->attach('OGR_G_Polygonize' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_Intersect' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_G_Equal' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_G_SymmetricDifference' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('OGR_G_GetArea' => [qw/opaque/] => 'double');
$ffi->attach('OGR_G_GetBoundary' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_G_GetPointCount' => [qw/opaque/] => 'int');
$ffi->attach('OGR_G_GetPoints' => [qw/opaque opaque int opaque int opaque int/] => 'int');
$ffi->attach('OGR_G_GetPointsZM' => [qw/opaque opaque int opaque int opaque int opaque int/] => 'int');
$ffi->attach('OGR_G_GetX' => [qw/opaque int/] => 'double');
$ffi->attach('OGR_G_GetY' => [qw/opaque int/] => 'double');
$ffi->attach('OGR_G_GetZ' => [qw/opaque int/] => 'double');
$ffi->attach('OGR_G_GetM' => [qw/opaque int/] => 'double');
$ffi->attach('OGR_G_GetPoint' => [qw/opaque int double* double* double*/] => 'void');
$ffi->attach('OGR_G_GetPointZM' => [qw/opaque int double* double* double* double*/] => 'void');
$ffi->attach('OGR_G_SetPointCount' => [qw/opaque int/] => 'void');
$ffi->attach('OGR_G_SetPoint' => [qw/opaque int double double double/] => 'void');
$ffi->attach('OGR_G_SetPoint_2D' => [qw/opaque int double double/] => 'void');
$ffi->attach('OGR_G_SetPointM' => [qw/opaque int double double double/] => 'void');
$ffi->attach('OGR_G_SetPointZM' => [qw/opaque int double double double double/] => 'void');
$ffi->attach('OGR_G_AddPoint' => [qw/opaque double double double/] => 'void');
$ffi->attach('OGR_G_AddPoint_2D' => [qw/opaque double double/] => 'void');
$ffi->attach('OGR_G_AddPointM' => [qw/opaque double double double/] => 'void');
$ffi->attach('OGR_G_AddPointZM' => [qw/opaque double double double double/] => 'void');
$ffi->attach('OGR_G_SetPoints' => [qw/opaque int opaque int opaque int opaque int/] => 'void');
$ffi->attach('OGR_G_SetPointsZM' => [qw/opaque int opaque int opaque int opaque int opaque int/] => 'void');
$ffi->attach('OGR_G_SwapXY' => [qw/opaque/] => 'void');
$ffi->attach('OGR_G_GetGeometryCount' => [qw/opaque/] => 'int');
$ffi->attach('OGR_G_GetGeometryRef' => [qw/opaque int/] => 'opaque');
$ffi->attach('OGR_G_AddGeometry' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_G_AddGeometryDirectly' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_G_RemoveGeometry' => [qw/opaque int int/] => 'int');
$ffi->attach('OGR_G_HasCurveGeometry' => [qw/opaque int/] => 'int');
$ffi->attach('OGR_G_GetLinearGeometry' => [qw/opaque double opaque/] => 'opaque');
$ffi->attach('OGR_G_GetCurveGeometry' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('OGRBuildPolygonFromEdges' => [qw/opaque int int double int*/] => 'opaque');
$ffi->attach('OGRSetGenerate_DB2_V72_BYTE_ORDER' => [qw/int/] => 'int');
$ffi->attach('OGRGetGenerate_DB2_V72_BYTE_ORDER' => [] => 'int');
$ffi->attach('OGRSetNonLinearGeometriesEnabledFlag' => [qw/int/] => 'void');
$ffi->attach('OGRGetNonLinearGeometriesEnabledFlag' => [] => 'int');
$ffi->attach('OGRHasPreparedGeometrySupport' => [] => 'int');
$ffi->attach('OGRCreatePreparedGeometry' => [qw/opaque/] => 'opaque');
$ffi->attach('OGRDestroyPreparedGeometry' => [qw/opaque/] => 'void');
$ffi->attach('OGRPreparedGeometryIntersects' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGRPreparedGeometryContains' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_Fld_Create' => ['string','unsigned int'] => 'opaque');
$ffi->attach('OGR_Fld_Destroy' => [qw/opaque/] => 'void');
$ffi->attach('OGR_Fld_SetName' => [qw/opaque string/] => 'void');
$ffi->attach('OGR_Fld_GetNameRef' => [qw/opaque/] => 'string');
$ffi->attach('OGR_Fld_SetAlternativeName' => [qw/opaque string/] => 'void');
$ffi->attach('OGR_Fld_GetAlternativeNameRef' => [qw/opaque/] => 'string');
$ffi->attach('OGR_Fld_GetType' => [qw/opaque/] => 'unsigned int');
$ffi->attach('OGR_Fld_SetType' => ['opaque','unsigned int'] => 'void');
$ffi->attach('OGR_Fld_GetSubType' => [qw/opaque/] => 'unsigned int');
$ffi->attach('OGR_Fld_SetSubType' => ['opaque','unsigned int'] => 'void');
$ffi->attach('OGR_Fld_GetJustify' => [qw/opaque/] => 'unsigned int');
$ffi->attach('OGR_Fld_SetJustify' => ['opaque','unsigned int'] => 'void');
$ffi->attach('OGR_Fld_GetWidth' => [qw/opaque/] => 'int');
$ffi->attach('OGR_Fld_SetWidth' => [qw/opaque int/] => 'void');
$ffi->attach('OGR_Fld_GetPrecision' => [qw/opaque/] => 'int');
$ffi->attach('OGR_Fld_SetPrecision' => [qw/opaque int/] => 'void');
$ffi->attach('OGR_Fld_Set' => ['opaque','string','unsigned int','int','int','unsigned int'] => 'void');
$ffi->attach('OGR_Fld_IsIgnored' => [qw/opaque/] => 'int');
$ffi->attach('OGR_Fld_SetIgnored' => [qw/opaque int/] => 'void');
$ffi->attach('OGR_Fld_IsNullable' => [qw/opaque/] => 'int');
$ffi->attach('OGR_Fld_SetNullable' => [qw/opaque int/] => 'void');
$ffi->attach('OGR_Fld_IsUnique' => [qw/opaque/] => 'int');
$ffi->attach('OGR_Fld_SetUnique' => [qw/opaque int/] => 'void');
$ffi->attach('OGR_Fld_GetDefault' => [qw/opaque/] => 'string');
$ffi->attach('OGR_Fld_SetDefault' => [qw/opaque string/] => 'void');
$ffi->attach('OGR_Fld_IsDefaultDriverSpecific' => [qw/opaque/] => 'int');
$ffi->attach('OGR_Fld_GetDomainName' => [qw/opaque/] => 'string');
$ffi->attach('OGR_Fld_SetDomainName' => [qw/opaque string/] => 'void');
$ffi->attach('OGR_Fld_GetComment' => [qw/opaque/] => 'string');
$ffi->attach('OGR_Fld_SetComment' => [qw/opaque string/] => 'void');
$ffi->attach('OGR_GetFieldTypeName' => ['unsigned int'] => 'string');
$ffi->attach('OGR_GetFieldSubTypeName' => ['unsigned int'] => 'string');
$ffi->attach('OGR_AreTypeSubTypeCompatible' => ['unsigned int','unsigned int'] => 'int');
$ffi->attach('OGR_GFld_Create' => ['string','unsigned int'] => 'opaque');
$ffi->attach('OGR_GFld_Destroy' => [qw/opaque/] => 'void');
$ffi->attach('OGR_GFld_SetName' => [qw/opaque string/] => 'void');
$ffi->attach('OGR_GFld_GetNameRef' => [qw/opaque/] => 'string');
$ffi->attach('OGR_GFld_GetType' => [qw/opaque/] => 'unsigned int');
$ffi->attach('OGR_GFld_SetType' => ['opaque','unsigned int'] => 'void');
$ffi->attach('OGR_GFld_GetSpatialRef' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_GFld_SetSpatialRef' => [qw/opaque opaque/] => 'void');
$ffi->attach('OGR_GFld_IsNullable' => [qw/opaque/] => 'int');
$ffi->attach('OGR_GFld_SetNullable' => [qw/opaque int/] => 'void');
$ffi->attach('OGR_GFld_IsIgnored' => [qw/opaque/] => 'int');
$ffi->attach('OGR_GFld_SetIgnored' => [qw/opaque int/] => 'void');
$ffi->attach('OGR_FD_Create' => [qw/string/] => 'opaque');
$ffi->attach('OGR_FD_Destroy' => [qw/opaque/] => 'void');
$ffi->attach('OGR_FD_Release' => [qw/opaque/] => 'void');
$ffi->attach('OGR_FD_GetName' => [qw/opaque/] => 'string');
$ffi->attach('OGR_FD_GetFieldCount' => [qw/opaque/] => 'int');
$ffi->attach('OGR_FD_GetFieldDefn' => [qw/opaque int/] => 'opaque');
$ffi->attach('OGR_FD_GetFieldIndex' => [qw/opaque string/] => 'int');
$ffi->attach('OGR_FD_AddFieldDefn' => [qw/opaque opaque/] => 'void');
$ffi->attach('OGR_FD_DeleteFieldDefn' => [qw/opaque int/] => 'int');
$ffi->attach('OGR_FD_ReorderFieldDefns' => [qw/opaque int*/] => 'int');
$ffi->attach('OGR_FD_GetGeomType' => [qw/opaque/] => 'unsigned int');
$ffi->attach('OGR_FD_SetGeomType' => ['opaque','unsigned int'] => 'void');
$ffi->attach('OGR_FD_IsGeometryIgnored' => [qw/opaque/] => 'int');
$ffi->attach('OGR_FD_SetGeometryIgnored' => [qw/opaque int/] => 'void');
$ffi->attach('OGR_FD_IsStyleIgnored' => [qw/opaque/] => 'int');
$ffi->attach('OGR_FD_SetStyleIgnored' => [qw/opaque int/] => 'void');
$ffi->attach('OGR_FD_Reference' => [qw/opaque/] => 'int');
$ffi->attach('OGR_FD_Dereference' => [qw/opaque/] => 'int');
$ffi->attach('OGR_FD_GetReferenceCount' => [qw/opaque/] => 'int');
$ffi->attach('OGR_FD_GetGeomFieldCount' => [qw/opaque/] => 'int');
$ffi->attach('OGR_FD_GetGeomFieldDefn' => [qw/opaque int/] => 'opaque');
$ffi->attach('OGR_FD_GetGeomFieldIndex' => [qw/opaque string/] => 'int');
$ffi->attach('OGR_FD_AddGeomFieldDefn' => [qw/opaque opaque/] => 'void');
$ffi->attach('OGR_FD_DeleteGeomFieldDefn' => [qw/opaque int/] => 'int');
$ffi->attach('OGR_FD_IsSame' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_F_Create' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_F_Destroy' => [qw/opaque/] => 'void');
$ffi->attach('OGR_F_GetDefnRef' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_F_SetGeometryDirectly' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_F_SetGeometry' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_F_GetGeometryRef' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_F_StealGeometry' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_F_StealGeometryEx' => [qw/opaque int/] => 'opaque');
$ffi->attach('OGR_F_Clone' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_F_Equal' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_F_GetFieldCount' => [qw/opaque/] => 'int');
$ffi->attach('OGR_F_GetFieldDefnRef' => [qw/opaque int/] => 'opaque');
$ffi->attach('OGR_F_GetFieldIndex' => [qw/opaque string/] => 'int');
$ffi->attach('OGR_F_IsFieldSet' => [qw/opaque int/] => 'int');
$ffi->attach('OGR_F_UnsetField' => [qw/opaque int/] => 'void');
$ffi->attach('OGR_F_IsFieldNull' => [qw/opaque int/] => 'int');
$ffi->attach('OGR_F_IsFieldSetAndNotNull' => [qw/opaque int/] => 'int');
$ffi->attach('OGR_F_SetFieldNull' => [qw/opaque int/] => 'void');
$ffi->attach('OGR_F_GetRawFieldRef' => [qw/opaque int/] => 'opaque');
$ffi->attach('OGR_RawField_IsUnset' => [qw/opaque/] => 'int');
$ffi->attach('OGR_RawField_IsNull' => [qw/opaque/] => 'int');
$ffi->attach('OGR_RawField_SetUnset' => [qw/opaque/] => 'void');
$ffi->attach('OGR_RawField_SetNull' => [qw/opaque/] => 'void');
$ffi->attach('OGR_F_GetFieldAsInteger' => [qw/opaque int/] => 'int');
$ffi->attach('OGR_F_GetFieldAsInteger64' => [qw/opaque int/] => 'sint64');
$ffi->attach('OGR_F_GetFieldAsDouble' => [qw/opaque int/] => 'double');
$ffi->attach('OGR_F_GetFieldAsString' => [qw/opaque int/] => 'string');
$ffi->attach('OGR_F_GetFieldAsISO8601DateTime' => [qw/opaque int opaque/] => 'string');
$ffi->attach('OGR_F_GetFieldAsIntegerList' => [qw/opaque int int*/] => 'pointer');
$ffi->attach('OGR_F_GetFieldAsInteger64List' => [qw/opaque int int*/] => 'pointer');
$ffi->attach('OGR_F_GetFieldAsDoubleList' => [qw/opaque int int*/] => 'pointer');
$ffi->attach('OGR_F_GetFieldAsStringList' => [qw/opaque int/] => 'opaque');
$ffi->attach('OGR_F_GetFieldAsBinary' => [qw/opaque int int*/] => 'pointer');
$ffi->attach('OGR_F_GetFieldAsDateTime' => [qw/opaque int int* int* int* int* int* int* int*/] => 'int');
$ffi->attach('OGR_F_GetFieldAsDateTimeEx' => [qw/opaque int int* int* int* int* int* float* int*/] => 'int');
$ffi->attach('OGR_F_SetFieldInteger' => [qw/opaque int int/] => 'void');
$ffi->attach('OGR_F_SetFieldInteger64' => [qw/opaque int sint64/] => 'void');
$ffi->attach('OGR_F_SetFieldDouble' => [qw/opaque int double/] => 'void');
$ffi->attach('OGR_F_SetFieldString' => [qw/opaque int string/] => 'void');
$ffi->attach('OGR_F_SetFieldIntegerList' => [qw/opaque int int int[]/] => 'void');
$ffi->attach('OGR_F_SetFieldInteger64List' => [qw/opaque int int sint64[]/] => 'void');
$ffi->attach('OGR_F_SetFieldDoubleList' => [qw/opaque int int double[]/] => 'void');
$ffi->attach('OGR_F_SetFieldStringList' => [qw/opaque int opaque/] => 'void');
$ffi->attach('OGR_F_SetFieldRaw' => [qw/opaque int opaque/] => 'void');
$ffi->attach('OGR_F_SetFieldBinary' => [qw/opaque int int opaque/] => 'void');
$ffi->attach('OGR_F_SetFieldDateTime' => [qw/opaque int int int int int int int int/] => 'void');
$ffi->attach('OGR_F_SetFieldDateTimeEx' => [qw/opaque int int int int int int float int/] => 'void');
$ffi->attach('OGR_F_GetGeomFieldCount' => [qw/opaque/] => 'int');
$ffi->attach('OGR_F_GetGeomFieldDefnRef' => [qw/opaque int/] => 'opaque');
$ffi->attach('OGR_F_GetGeomFieldIndex' => [qw/opaque string/] => 'int');
$ffi->attach('OGR_F_GetGeomFieldRef' => [qw/opaque int/] => 'opaque');
$ffi->attach('OGR_F_SetGeomFieldDirectly' => [qw/opaque int opaque/] => 'int');
$ffi->attach('OGR_F_SetGeomField' => [qw/opaque int opaque/] => 'int');
$ffi->attach('OGR_F_GetFID' => [qw/opaque/] => 'sint64');
$ffi->attach('OGR_F_SetFID' => [qw/opaque sint64/] => 'int');
$ffi->attach('OGR_F_DumpReadable' => [qw/opaque opaque/] => 'void');
$ffi->attach('OGR_F_SetFrom' => [qw/opaque opaque int/] => 'int');
$ffi->attach('OGR_F_SetFromWithMap' => [qw/opaque opaque int int*/] => 'int');
$ffi->attach('OGR_F_GetStyleString' => [qw/opaque/] => 'string');
$ffi->attach('OGR_F_SetStyleString' => [qw/opaque string/] => 'void');
$ffi->attach('OGR_F_SetStyleStringDirectly' => [qw/opaque string/] => 'void');
$ffi->attach('OGR_F_GetStyleTable' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_F_SetStyleTableDirectly' => [qw/opaque opaque/] => 'void');
$ffi->attach('OGR_F_SetStyleTable' => [qw/opaque opaque/] => 'void');
$ffi->attach('OGR_F_GetNativeData' => [qw/opaque/] => 'string');
$ffi->attach('OGR_F_SetNativeData' => [qw/opaque string/] => 'void');
$ffi->attach('OGR_F_GetNativeMediaType' => [qw/opaque/] => 'string');
$ffi->attach('OGR_F_SetNativeMediaType' => [qw/opaque string/] => 'void');
$ffi->attach('OGR_F_FillUnsetWithDefault' => [qw/opaque int opaque/] => 'void');
$ffi->attach('OGR_F_Validate' => [qw/opaque int int/] => 'int');
$ffi->attach('OGR_FldDomain_Destroy' => [qw/opaque/] => 'void');
$ffi->attach('OGR_FldDomain_GetName' => [qw/opaque/] => 'string');
$ffi->attach('OGR_FldDomain_GetDescription' => [qw/opaque/] => 'string');
$ffi->attach('OGR_FldDomain_GetDomainType' => [qw/opaque/] => 'int');
$ffi->attach('OGR_FldDomain_GetFieldType' => [qw/opaque/] => 'unsigned int');
$ffi->attach('OGR_FldDomain_GetFieldSubType' => [qw/opaque/] => 'unsigned int');
$ffi->attach('OGR_FldDomain_GetSplitPolicy' => [qw/opaque/] => 'int');
$ffi->attach('OGR_FldDomain_SetSplitPolicy' => [qw/opaque int/] => 'void');
$ffi->attach('OGR_FldDomain_GetMergePolicy' => [qw/opaque/] => 'int');
$ffi->attach('OGR_FldDomain_SetMergePolicy' => [qw/opaque int/] => 'void');
$ffi->attach('OGR_CodedFldDomain_Create' => ['string','string','unsigned int','unsigned int','int'] => 'opaque');
$ffi->attach('OGR_CodedFldDomain_GetEnumeration' => [qw/opaque/] => 'int');
$ffi->attach('OGR_RangeFldDomain_Create' => ['string','string','unsigned int','unsigned int','opaque','bool','opaque','bool'] => 'opaque');
$ffi->attach('OGR_RangeFldDomain_GetMin' => [qw/opaque bool/] => 'opaque');
$ffi->attach('OGR_RangeFldDomain_GetMax' => [qw/opaque bool/] => 'opaque');
$ffi->attach('OGR_GlobFldDomain_Create' => ['string','string','unsigned int','unsigned int','string'] => 'opaque');
$ffi->attach('OGR_GlobFldDomain_GetGlob' => [qw/opaque/] => 'string');
$ffi->attach('OGR_L_GetName' => [qw/opaque/] => 'string');
$ffi->attach('OGR_L_GetGeomType' => [qw/opaque/] => 'unsigned int');
$ffi->attach('OGR_L_GetGeometryTypes' => [qw/opaque int int int* GDALProgressFunc opaque/] => 'opaque');
$ffi->attach('OGR_L_GetSpatialFilter' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_L_SetSpatialFilter' => [qw/opaque opaque/] => 'void');
$ffi->attach('OGR_L_SetSpatialFilterRect' => [qw/opaque double double double double/] => 'void');
$ffi->attach('OGR_L_SetSpatialFilterEx' => [qw/opaque int opaque/] => 'void');
$ffi->attach('OGR_L_SetSpatialFilterRectEx' => [qw/opaque int double double double double/] => 'void');
$ffi->attach('OGR_L_SetAttributeFilter' => [qw/opaque string/] => 'int');
$ffi->attach('OGR_L_ResetReading' => [qw/opaque/] => 'void');
$ffi->attach('OGR_L_GetNextFeature' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_L_GetArrowStream' => [qw/opaque opaque opaque/] => 'bool');
$ffi->attach('OGR_L_SetNextByIndex' => [qw/opaque sint64/] => 'int');
$ffi->attach('OGR_L_GetFeature' => [qw/opaque sint64/] => 'opaque');
$ffi->attach('OGR_L_SetFeature' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_L_CreateFeature' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_L_DeleteFeature' => [qw/opaque sint64/] => 'int');
$ffi->attach('OGR_L_UpsertFeature' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_L_UpdateFeature' => [qw/opaque opaque int int* int int* bool/] => 'int');
$ffi->attach('OGR_L_GetLayerDefn' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_L_GetSpatialRef' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_L_GetSupportedSRSList' => [qw/opaque int int*/] => 'uint64*');
$ffi->attach('OGR_L_SetActiveSRS' => [qw/opaque int opaque/] => 'int');
$ffi->attach('OGR_L_FindFieldIndex' => [qw/opaque string int/] => 'int');
$ffi->attach('OGR_L_GetFeatureCount' => [qw/opaque int/] => 'sint64');
$ffi->attach('OGR_L_GetExtent' => [qw/opaque double[4] int/] => 'int');
$ffi->attach('OGR_L_GetExtentEx' => [qw/opaque int double[4] int/] => 'int');
$ffi->attach('OGR_L_TestCapability' => [qw/opaque string/] => 'int');
$ffi->attach('OGR_L_CreateField' => [qw/opaque opaque int/] => 'int');
$ffi->attach('OGR_L_CreateGeomField' => [qw/opaque opaque int/] => 'int');
$ffi->attach('OGR_L_DeleteField' => [qw/opaque int/] => 'int');
$ffi->attach('OGR_L_ReorderFields' => [qw/opaque int*/] => 'int');
$ffi->attach('OGR_L_ReorderField' => [qw/opaque int int/] => 'int');
$ffi->attach('OGR_L_AlterFieldDefn' => [qw/opaque int opaque int/] => 'int');
$ffi->attach('OGR_L_AlterGeomFieldDefn' => [qw/opaque int opaque int/] => 'int');
$ffi->attach('OGR_L_StartTransaction' => [qw/opaque/] => 'int');
$ffi->attach('OGR_L_CommitTransaction' => [qw/opaque/] => 'int');
$ffi->attach('OGR_L_RollbackTransaction' => [qw/opaque/] => 'int');
$ffi->attach('OGR_L_Rename' => [qw/opaque string/] => 'int');
$ffi->attach('OGR_L_Reference' => [qw/opaque/] => 'int');
$ffi->attach('OGR_L_Dereference' => [qw/opaque/] => 'int');
$ffi->attach('OGR_L_GetRefCount' => [qw/opaque/] => 'int');
$ffi->attach('OGR_L_SyncToDisk' => [qw/opaque/] => 'int');
$ffi->attach('OGR_L_GetFeaturesRead' => [qw/opaque/] => 'sint64');
$ffi->attach('OGR_L_GetFIDColumn' => [qw/opaque/] => 'string');
$ffi->attach('OGR_L_GetGeometryColumn' => [qw/opaque/] => 'string');
$ffi->attach('OGR_L_GetStyleTable' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_L_SetStyleTableDirectly' => [qw/opaque opaque/] => 'void');
$ffi->attach('OGR_L_SetStyleTable' => [qw/opaque opaque/] => 'void');
$ffi->attach('OGR_L_SetIgnoredFields' => [qw/opaque string/] => 'int');
$ffi->attach('OGR_L_Intersection' => [qw/opaque opaque opaque opaque GDALProgressFunc opaque/] => 'int');
$ffi->attach('OGR_L_Union' => [qw/opaque opaque opaque opaque GDALProgressFunc opaque/] => 'int');
$ffi->attach('OGR_L_SymDifference' => [qw/opaque opaque opaque opaque GDALProgressFunc opaque/] => 'int');
$ffi->attach('OGR_L_Identity' => [qw/opaque opaque opaque opaque GDALProgressFunc opaque/] => 'int');
$ffi->attach('OGR_L_Update' => [qw/opaque opaque opaque opaque GDALProgressFunc opaque/] => 'int');
$ffi->attach('OGR_L_Clip' => [qw/opaque opaque opaque opaque GDALProgressFunc opaque/] => 'int');
$ffi->attach('OGR_L_Erase' => [qw/opaque opaque opaque opaque GDALProgressFunc opaque/] => 'int');
$ffi->attach('OGR_DS_Destroy' => [qw/opaque/] => 'void');
$ffi->attach('OGR_DS_GetName' => [qw/opaque/] => 'string');
$ffi->attach('OGR_DS_GetLayerCount' => [qw/opaque/] => 'int');
$ffi->attach('OGR_DS_GetLayer' => [qw/opaque int/] => 'opaque');
$ffi->attach('OGR_DS_GetLayerByName' => [qw/opaque string/] => 'opaque');
$ffi->attach('OGR_DS_DeleteLayer' => [qw/opaque int/] => 'int');
$ffi->attach('OGR_DS_GetDriver' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_DS_CreateLayer' => ['opaque','string','opaque','unsigned int','opaque'] => 'opaque');
$ffi->attach('OGR_DS_CopyLayer' => [qw/opaque opaque string opaque/] => 'opaque');
$ffi->attach('OGR_DS_TestCapability' => [qw/opaque string/] => 'int');
$ffi->attach('OGR_DS_ExecuteSQL' => [qw/opaque string opaque string/] => 'opaque');
$ffi->attach('OGR_DS_ReleaseResultSet' => [qw/opaque opaque/] => 'void');
$ffi->attach('OGR_DS_Reference' => [qw/opaque/] => 'int');
$ffi->attach('OGR_DS_Dereference' => [qw/opaque/] => 'int');
$ffi->attach('OGR_DS_GetRefCount' => [qw/opaque/] => 'int');
$ffi->attach('OGR_DS_GetSummaryRefCount' => [qw/opaque/] => 'int');
$ffi->attach('OGR_DS_SyncToDisk' => [qw/opaque/] => 'int');
$ffi->attach('OGR_DS_GetStyleTable' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_DS_SetStyleTableDirectly' => [qw/opaque opaque/] => 'void');
$ffi->attach('OGR_DS_SetStyleTable' => [qw/opaque opaque/] => 'void');
$ffi->attach('OGR_Dr_GetName' => [qw/opaque/] => 'string');
$ffi->attach('OGR_Dr_Open' => [qw/opaque string int/] => 'opaque');
$ffi->attach('OGR_Dr_TestCapability' => [qw/opaque string/] => 'int');
$ffi->attach('OGR_Dr_CreateDataSource' => [qw/opaque string opaque/] => 'opaque');
$ffi->attach('OGR_Dr_CopyDataSource' => [qw/opaque opaque string opaque/] => 'opaque');
$ffi->attach('OGR_Dr_DeleteDataSource' => [qw/opaque string/] => 'int');
$ffi->attach('OGROpen' => [qw/string int uint64*/] => 'opaque');
$ffi->attach('OGROpenShared' => [qw/string int uint64*/] => 'opaque');
$ffi->attach('OGRReleaseDataSource' => [qw/opaque/] => 'int');
$ffi->attach('OGRRegisterDriver' => [qw/opaque/] => 'void');
$ffi->attach('OGRDeregisterDriver' => [qw/opaque/] => 'void');
$ffi->attach('OGRGetDriverCount' => [] => 'int');
$ffi->attach('OGRGetDriver' => [qw/int/] => 'opaque');
$ffi->attach('OGRGetDriverByName' => [qw/string/] => 'opaque');
$ffi->attach('OGRGetOpenDSCount' => [] => 'int');
$ffi->attach('OGRGetOpenDS' => [qw/int/] => 'opaque');
$ffi->attach('OGRRegisterAll' => [] => 'void');
$ffi->attach('OGRCleanupAll' => [] => 'void');
$ffi->attach('OGR_SM_Create' => [qw/opaque/] => 'opaque');
$ffi->attach('OGR_SM_Destroy' => [qw/opaque/] => 'void');
$ffi->attach('OGR_SM_InitFromFeature' => [qw/opaque opaque/] => 'string');
$ffi->attach('OGR_SM_InitStyleString' => [qw/opaque string/] => 'int');
$ffi->attach('OGR_SM_GetPartCount' => [qw/opaque string/] => 'int');
$ffi->attach('OGR_SM_GetPart' => [qw/opaque int string/] => 'opaque');
$ffi->attach('OGR_SM_AddPart' => [qw/opaque opaque/] => 'int');
$ffi->attach('OGR_SM_AddStyle' => [qw/opaque string string/] => 'int');
$ffi->attach('OGR_ST_Create' => ['unsigned int'] => 'opaque');
$ffi->attach('OGR_ST_Destroy' => [qw/opaque/] => 'void');
$ffi->attach('OGR_ST_GetType' => [qw/opaque/] => 'unsigned int');
$ffi->attach('OGR_ST_GetUnit' => [qw/opaque/] => 'unsigned int');
$ffi->attach('OGR_ST_SetUnit' => ['opaque','unsigned int','double'] => 'void');
$ffi->attach('OGR_ST_GetParamStr' => [qw/opaque int int*/] => 'string');
$ffi->attach('OGR_ST_GetParamNum' => [qw/opaque int int*/] => 'int');
$ffi->attach('OGR_ST_GetParamDbl' => [qw/opaque int int*/] => 'double');
$ffi->attach('OGR_ST_SetParamStr' => [qw/opaque int string/] => 'void');
$ffi->attach('OGR_ST_SetParamNum' => [qw/opaque int int/] => 'void');
$ffi->attach('OGR_ST_SetParamDbl' => [qw/opaque int double/] => 'void');
$ffi->attach('OGR_ST_GetStyleString' => [qw/opaque/] => 'string');
$ffi->attach('OGR_ST_GetRGBFromString' => [qw/opaque string int* int* int* int*/] => 'int');
$ffi->attach('OGR_STBL_Create' => [] => 'opaque');
$ffi->attach('OGR_STBL_Destroy' => [qw/opaque/] => 'void');
$ffi->attach('OGR_STBL_AddStyle' => [qw/opaque string string/] => 'int');
$ffi->attach('OGR_STBL_SaveStyleTable' => [qw/opaque string/] => 'int');
$ffi->attach('OGR_STBL_LoadStyleTable' => [qw/opaque string/] => 'int');
$ffi->attach('OGR_STBL_Find' => [qw/opaque string/] => 'string');
$ffi->attach('OGR_STBL_ResetStyleStringReading' => [qw/opaque/] => 'void');
$ffi->attach('OGR_STBL_GetNextStyle' => [qw/opaque/] => 'string');
$ffi->attach('OGR_STBL_GetLastStyleName' => [qw/opaque/] => 'string');
# from ogr/ogr_srs_api.h
$ffi->attach('OSRAxisEnumToName' => ['unsigned int'] => 'string');
$ffi->attach('OSRSetPROJSearchPaths' => [qw/opaque/] => 'void');
$ffi->attach('OSRGetPROJSearchPaths' => [] => 'opaque');
$ffi->attach('OSRSetPROJAuxDbPaths' => [qw/opaque/] => 'void');
$ffi->attach('OSRGetPROJAuxDbPaths' => [] => 'opaque');
$ffi->attach('OSRSetPROJEnableNetwork' => [qw/int/] => 'void');
$ffi->attach('OSRGetPROJEnableNetwork' => [] => 'int');
$ffi->attach('OSRGetPROJVersion' => [qw/int* int* int*/] => 'void');
$ffi->attach('OSRNewSpatialReference' => [qw/string/] => 'opaque');
$ffi->attach('OSRCloneGeogCS' => [qw/opaque/] => 'opaque');
$ffi->attach('OSRClone' => [qw/opaque/] => 'opaque');
$ffi->attach('OSRDestroySpatialReference' => [qw/opaque/] => 'void');
$ffi->attach('OSRReference' => [qw/opaque/] => 'int');
$ffi->attach('OSRDereference' => [qw/opaque/] => 'int');
$ffi->attach('OSRRelease' => [qw/opaque/] => 'void');
$ffi->attach('OSRValidate' => [qw/opaque/] => 'int');
$ffi->attach('OSRImportFromEPSG' => [qw/opaque int/] => 'int');
$ffi->attach('OSRImportFromEPSGA' => [qw/opaque int/] => 'int');
$ffi->attach('OSRImportFromWkt' => [qw/opaque string*/] => 'int');
$ffi->attach('OSRImportFromProj4' => [qw/opaque string/] => 'int');
$ffi->attach('OSRImportFromESRI' => [qw/opaque opaque/] => 'int');
$ffi->attach('OSRImportFromPCI' => [qw/opaque string string double*/] => 'int');
$ffi->attach('OSRImportFromUSGS' => [qw/opaque long long double* long/] => 'int');
$ffi->attach('OSRImportFromXML' => [qw/opaque string/] => 'int');
$ffi->attach('OSRImportFromDict' => [qw/opaque string string/] => 'int');
$ffi->attach('OSRImportFromPanorama' => [qw/opaque long long long double*/] => 'int');
$ffi->attach('OSRImportFromOzi' => [qw/opaque opaque/] => 'int');
$ffi->attach('OSRImportFromMICoordSys' => [qw/opaque string/] => 'int');
$ffi->attach('OSRImportFromERM' => [qw/opaque string string string/] => 'int');
$ffi->attach('OSRImportFromUrl' => [qw/opaque string/] => 'int');
$ffi->attach('OSRExportToWkt' => [qw/opaque string*/] => 'int');
$ffi->attach('OSRExportToWktEx' => [qw/opaque string* opaque/] => 'int');
$ffi->attach('OSRExportToPrettyWkt' => [qw/opaque string* int/] => 'int');
$ffi->attach('OSRExportToPROJJSON' => [qw/opaque string* opaque/] => 'int');
$ffi->attach('OSRExportToProj4' => [qw/opaque string*/] => 'int');
$ffi->attach('OSRExportToPCI' => [qw/opaque string* string* double*/] => 'int');
$ffi->attach('OSRExportToUSGS' => [qw/opaque long* long* double* long*/] => 'int');
$ffi->attach('OSRExportToXML' => [qw/opaque string* string/] => 'int');
$ffi->attach('OSRExportToPanorama' => [qw/opaque long* long* long* long* double*/] => 'int');
$ffi->attach('OSRExportToMICoordSys' => [qw/opaque string*/] => 'int');
$ffi->attach('OSRExportToERM' => [qw/opaque string string string/] => 'int');
$ffi->attach('OSRMorphToESRI' => [qw/opaque/] => 'int');
$ffi->attach('OSRMorphFromESRI' => [qw/opaque/] => 'int');
$ffi->attach('OSRStripVertical' => [qw/opaque/] => 'int');
$ffi->attach('OSRConvertToOtherProjection' => [qw/opaque string opaque/] => 'opaque');
$ffi->attach('OSRGetName' => [qw/opaque/] => 'string');
$ffi->attach('OSRSetAttrValue' => [qw/opaque string string/] => 'int');
$ffi->attach('OSRGetAttrValue' => [qw/opaque string int/] => 'string');
$ffi->attach('OSRSetAngularUnits' => [qw/opaque string double/] => 'int');
$ffi->attach('OSRGetAngularUnits' => [qw/opaque string*/] => 'double');
$ffi->attach('OSRSetLinearUnits' => [qw/opaque string double/] => 'int');
$ffi->attach('OSRSetTargetLinearUnits' => [qw/opaque string string double/] => 'int');
$ffi->attach('OSRSetLinearUnitsAndUpdateParameters' => [qw/opaque string double/] => 'int');
$ffi->attach('OSRGetLinearUnits' => [qw/opaque string*/] => 'double');
$ffi->attach('OSRGetTargetLinearUnits' => [qw/opaque string string*/] => 'double');
$ffi->attach('OSRGetPrimeMeridian' => [qw/opaque string*/] => 'double');
$ffi->attach('OSRIsGeographic' => [qw/opaque/] => 'int');
$ffi->attach('OSRIsDerivedGeographic' => [qw/opaque/] => 'int');
$ffi->attach('OSRIsLocal' => [qw/opaque/] => 'int');
$ffi->attach('OSRIsProjected' => [qw/opaque/] => 'int');
$ffi->attach('OSRIsCompound' => [qw/opaque/] => 'int');
$ffi->attach('OSRIsGeocentric' => [qw/opaque/] => 'int');
$ffi->attach('OSRIsVertical' => [qw/opaque/] => 'int');
$ffi->attach('OSRIsDynamic' => [qw/opaque/] => 'int');
$ffi->attach('OSRIsSameGeogCS' => [qw/opaque opaque/] => 'int');
$ffi->attach('OSRIsSameVertCS' => [qw/opaque opaque/] => 'int');
$ffi->attach('OSRIsSame' => [qw/opaque opaque/] => 'int');
$ffi->attach('OSRIsSameEx' => [qw/opaque opaque opaque/] => 'int');
$ffi->attach('OSRSetCoordinateEpoch' => [qw/opaque double/] => 'void');
$ffi->attach('OSRGetCoordinateEpoch' => [qw/opaque/] => 'double');
$ffi->attach('OSRSetLocalCS' => [qw/opaque string/] => 'int');
$ffi->attach('OSRSetProjCS' => [qw/opaque string/] => 'int');
$ffi->attach('OSRSetGeocCS' => [qw/opaque string/] => 'int');
$ffi->attach('OSRSetWellKnownGeogCS' => [qw/opaque string/] => 'int');
$ffi->attach('OSRSetFromUserInput' => [qw/opaque string/] => 'int');
$ffi->attach('OSRCopyGeogCSFrom' => [qw/opaque opaque/] => 'int');
$ffi->attach('OSRSetTOWGS84' => [qw/opaque double double double double double double double/] => 'int');
$ffi->attach('OSRGetTOWGS84' => [qw/opaque double* int/] => 'int');
$ffi->attach('OSRAddGuessedTOWGS84' => [qw/opaque/] => 'int');
$ffi->attach('OSRSetCompoundCS' => [qw/opaque string opaque opaque/] => 'int');
$ffi->attach('OSRPromoteTo3D' => [qw/opaque string/] => 'int');
$ffi->attach('OSRDemoteTo2D' => [qw/opaque string/] => 'int');
$ffi->attach('OSRSetGeogCS' => [qw/opaque string string string double double string double string double/] => 'int');
$ffi->attach('OSRSetVertCS' => [qw/opaque string string int/] => 'int');
$ffi->attach('OSRGetSemiMajor' => [qw/opaque int*/] => 'double');
$ffi->attach('OSRGetSemiMinor' => [qw/opaque int*/] => 'double');
$ffi->attach('OSRGetInvFlattening' => [qw/opaque int*/] => 'double');
$ffi->attach('OSRSetAuthority' => [qw/opaque string string int/] => 'int');
$ffi->attach('OSRGetAuthorityCode' => [qw/opaque string/] => 'string');
$ffi->attach('OSRGetAuthorityName' => [qw/opaque string/] => 'string');
$ffi->attach('OSRGetAreaOfUse' => [qw/opaque double* double* double* double* string/] => 'int');
$ffi->attach('OSRSetProjection' => [qw/opaque string/] => 'int');
$ffi->attach('OSRSetProjParm' => [qw/opaque string double/] => 'int');
$ffi->attach('OSRGetProjParm' => [qw/opaque string double int*/] => 'double');
$ffi->attach('OSRSetNormProjParm' => [qw/opaque string double/] => 'int');
$ffi->attach('OSRGetNormProjParm' => [qw/opaque string double int*/] => 'double');
$ffi->attach('OSRSetUTM' => [qw/opaque int int/] => 'int');
$ffi->attach('OSRGetUTMZone' => [qw/opaque int*/] => 'int');
$ffi->attach('OSRSetStatePlane' => [qw/opaque int int/] => 'int');
$ffi->attach('OSRSetStatePlaneWithUnits' => [qw/opaque int int string double/] => 'int');
$ffi->attach('OSRAutoIdentifyEPSG' => [qw/opaque/] => 'int');
$ffi->attach('OSRFindMatches' => [qw/opaque opaque int* int*/] => 'uint64*');
$ffi->attach('OSRFreeSRSArray' => [qw/uint64*/] => 'void');
$ffi->attach('OSREPSGTreatsAsLatLong' => [qw/opaque/] => 'int');
$ffi->attach('OSREPSGTreatsAsNorthingEasting' => [qw/opaque/] => 'int');
$ffi->attach('OSRGetAxis' => ['opaque','string','int','unsigned int'] => 'string');
$ffi->attach('OSRGetAxesCount' => [qw/opaque/] => 'int');
$ffi->attach('OSRSetAxes' => ['opaque','string','string','unsigned int','string','unsigned int'] => 'int');
$ffi->attach('OSRGetAxisMappingStrategy' => [qw/opaque/] => 'int');
$ffi->attach('OSRSetAxisMappingStrategy' => [qw/opaque int/] => 'void');
$ffi->attach('OSRGetDataAxisToSRSAxisMapping' => [qw/opaque int*/] => 'int*');
$ffi->attach('OSRSetDataAxisToSRSAxisMapping' => [qw/opaque int int*/] => 'int');
$ffi->attach('OSRSetACEA' => [qw/opaque double double double double double double/] => 'int');
$ffi->attach('OSRSetAE' => [qw/opaque double double double double/] => 'int');
$ffi->attach('OSRSetBonne' => [qw/opaque double double double double/] => 'int');
$ffi->attach('OSRSetCEA' => [qw/opaque double double double double/] => 'int');
$ffi->attach('OSRSetCS' => [qw/opaque double double double double/] => 'int');
$ffi->attach('OSRSetEC' => [qw/opaque double double double double double double/] => 'int');
$ffi->attach('OSRSetEckert' => [qw/opaque int double double double/] => 'int');
$ffi->attach('OSRSetEckertIV' => [qw/opaque double double double/] => 'int');
$ffi->attach('OSRSetEckertVI' => [qw/opaque double double double/] => 'int');
$ffi->attach('OSRSetEquirectangular' => [qw/opaque double double double double/] => 'int');
$ffi->attach('OSRSetEquirectangular2' => [qw/opaque double double double double double/] => 'int');
$ffi->attach('OSRSetGS' => [qw/opaque double double double/] => 'int');
$ffi->attach('OSRSetGH' => [qw/opaque double double double/] => 'int');
$ffi->attach('OSRSetIGH' => [qw/opaque/] => 'int');
$ffi->attach('OSRSetGEOS' => [qw/opaque double double double double/] => 'int');
$ffi->attach('OSRSetGaussSchreiberTMercator' => [qw/opaque double double double double double/] => 'int');
$ffi->attach('OSRSetGnomonic' => [qw/opaque double double double double/] => 'int');
$ffi->attach('OSRSetHOM' => [qw/opaque double double double double double double double/] => 'int');
$ffi->attach('OSRSetHOMAC' => [qw/opaque double double double double double double double/] => 'int');
$ffi->attach('OSRSetHOM2PNO' => [qw/opaque double double double double double double double double/] => 'int');
$ffi->attach('OSRSetIWMPolyconic' => [qw/opaque double double double double double/] => 'int');
$ffi->attach('OSRSetKrovak' => [qw/opaque double double double double double double double/] => 'int');
$ffi->attach('OSRSetLAEA' => [qw/opaque double double double double/] => 'int');
$ffi->attach('OSRSetLCC' => [qw/opaque double double double double double double/] => 'int');
$ffi->attach('OSRSetLCC1SP' => [qw/opaque double double double double double/] => 'int');
$ffi->attach('OSRSetLCCB' => [qw/opaque double double double double double double/] => 'int');
$ffi->attach('OSRSetMC' => [qw/opaque double double double double/] => 'int');
$ffi->attach('OSRSetMercator' => [qw/opaque double double double double double/] => 'int');
$ffi->attach('OSRSetMercator2SP' => [qw/opaque double double double double double/] => 'int');
$ffi->attach('OSRSetMollweide' => [qw/opaque double double double/] => 'int');
$ffi->attach('OSRSetNZMG' => [qw/opaque double double double double/] => 'int');
$ffi->attach('OSRSetOS' => [qw/opaque double double double double double/] => 'int');
$ffi->attach('OSRSetOrthographic' => [qw/opaque double double double double/] => 'int');
$ffi->attach('OSRSetPolyconic' => [qw/opaque double double double double/] => 'int');
$ffi->attach('OSRSetPS' => [qw/opaque double double double double double/] => 'int');
$ffi->attach('OSRSetRobinson' => [qw/opaque double double double/] => 'int');
$ffi->attach('OSRSetSinusoidal' => [qw/opaque double double double/] => 'int');
$ffi->attach('OSRSetStereographic' => [qw/opaque double double double double double/] => 'int');
$ffi->attach('OSRSetSOC' => [qw/opaque double double double double/] => 'int');
$ffi->attach('OSRSetTM' => [qw/opaque double double double double double/] => 'int');
$ffi->attach('OSRSetTMVariant' => [qw/opaque string double double double double double/] => 'int');
$ffi->attach('OSRSetTMG' => [qw/opaque double double double double/] => 'int');
$ffi->attach('OSRSetTMSO' => [qw/opaque double double double double double/] => 'int');
$ffi->attach('OSRSetTPED' => [qw/opaque double double double double double double/] => 'int');
$ffi->attach('OSRSetVDG' => [qw/opaque double double double/] => 'int');
$ffi->attach('OSRSetWagner' => [qw/opaque int double double double/] => 'int');
$ffi->attach('OSRSetQSC' => [qw/opaque double double/] => 'int');
$ffi->attach('OSRSetSCH' => [qw/opaque double double double double/] => 'int');
$ffi->attach('OSRSetVerticalPerspective' => [qw/opaque double double double double double double/] => 'int');
$ffi->attach('OSRCalcInvFlattening' => [qw/double double/] => 'double');
$ffi->attach('OSRCalcSemiMinorFromInvFlattening' => [qw/double double/] => 'double');
$ffi->attach('OSRCleanup' => [] => 'void');
$ffi->attach('OSRGetCRSInfoListFromDatabase' => [qw/string opaque int*/] => 'opaque');
$ffi->attach('OSRDestroyCRSInfoList' => [qw/opaque/] => 'void');
$ffi->attach('OCTNewCoordinateTransformation' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('OCTNewCoordinateTransformationOptions' => [] => 'opaque');
$ffi->attach('OCTCoordinateTransformationOptionsSetOperation' => [qw/opaque string int/] => 'int');
$ffi->attach('OCTCoordinateTransformationOptionsSetAreaOfInterest' => [qw/opaque double double double double/] => 'int');
$ffi->attach('OCTCoordinateTransformationOptionsSetDesiredAccuracy' => [qw/opaque double/] => 'int');
$ffi->attach('OCTCoordinateTransformationOptionsSetBallparkAllowed' => [qw/opaque int/] => 'int');
$ffi->attach('OCTDestroyCoordinateTransformationOptions' => [qw/opaque/] => 'void');
$ffi->attach('OCTNewCoordinateTransformationEx' => [qw/opaque opaque opaque/] => 'opaque');
$ffi->attach('OCTClone' => [qw/opaque/] => 'opaque');
$ffi->attach('OCTGetSourceCS' => [qw/opaque/] => 'opaque');
$ffi->attach('OCTGetTargetCS' => [qw/opaque/] => 'opaque');
$ffi->attach('OCTGetInverse' => [qw/opaque/] => 'opaque');
$ffi->attach('OCTDestroyCoordinateTransformation' => [qw/opaque/] => 'void');
$ffi->attach('OCTTransform' => [qw/opaque int double* double* double*/] => 'int');
$ffi->attach('OCTTransformEx' => [qw/opaque int double* double* double* int*/] => 'int');
$ffi->attach('OCTTransform4D' => [qw/opaque int double* double* double* double* int*/] => 'int');
$ffi->attach('OCTTransform4DWithErrorCodes' => [qw/opaque int double* double* double* double* int*/] => 'int');
$ffi->attach('OCTTransformBounds' => [qw/opaque double double double double double* double* double* double* int/] => 'int');
# from apps/gdal_utils.h
$ffi->attach('GDALInfoOptionsNew' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALInfoOptionsFree' => [qw/opaque/] => 'void');
$ffi->attach('GDALInfo' => [qw/opaque opaque/] => 'string');
$ffi->attach('GDALTranslateOptionsNew' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALTranslateOptionsFree' => [qw/opaque/] => 'void');
$ffi->attach('GDALTranslateOptionsSetProgress' => [qw/opaque GDALProgressFunc opaque/] => 'void');
$ffi->attach('GDALTranslate' => [qw/string opaque opaque int*/] => 'opaque');
$ffi->attach('GDALWarpAppOptionsNew' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALWarpAppOptionsFree' => [qw/opaque/] => 'void');
$ffi->attach('GDALWarpAppOptionsSetProgress' => [qw/opaque GDALProgressFunc opaque/] => 'void');
$ffi->attach('GDALWarpAppOptionsSetQuiet' => [qw/opaque int/] => 'void');
$ffi->attach('GDALWarpAppOptionsSetWarpOption' => [qw/opaque string string/] => 'void');
$ffi->attach('GDALWarp' => [qw/string opaque int opaque[] opaque int*/] => 'opaque');
$ffi->attach('GDALVectorTranslateOptionsNew' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALVectorTranslateOptionsFree' => [qw/opaque/] => 'void');
$ffi->attach('GDALVectorTranslateOptionsSetProgress' => [qw/opaque GDALProgressFunc opaque/] => 'void');
$ffi->attach('GDALVectorTranslate' => [qw/string opaque int opaque[] opaque int*/] => 'opaque');
$ffi->attach('GDALDEMProcessingOptionsNew' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALDEMProcessingOptionsFree' => [qw/opaque/] => 'void');
$ffi->attach('GDALDEMProcessingOptionsSetProgress' => [qw/opaque GDALProgressFunc opaque/] => 'void');
$ffi->attach('GDALDEMProcessing' => [qw/string opaque string string opaque int*/] => 'opaque');
$ffi->attach('GDALNearblackOptionsNew' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALNearblackOptionsFree' => [qw/opaque/] => 'void');
$ffi->attach('GDALNearblackOptionsSetProgress' => [qw/opaque GDALProgressFunc opaque/] => 'void');
$ffi->attach('GDALNearblack' => [qw/string opaque opaque opaque int*/] => 'opaque');
$ffi->attach('GDALGridOptionsNew' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALGridOptionsFree' => [qw/opaque/] => 'void');
$ffi->attach('GDALGridOptionsSetProgress' => [qw/opaque GDALProgressFunc opaque/] => 'void');
$ffi->attach('GDALGrid' => [qw/string opaque opaque int*/] => 'opaque');
$ffi->attach('GDALRasterizeOptionsNew' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALRasterizeOptionsFree' => [qw/opaque/] => 'void');
$ffi->attach('GDALRasterizeOptionsSetProgress' => [qw/opaque GDALProgressFunc opaque/] => 'void');
$ffi->attach('GDALRasterize' => [qw/string opaque opaque opaque int*/] => 'opaque');
$ffi->attach('GDALBuildVRTOptionsNew' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALBuildVRTOptionsFree' => [qw/opaque/] => 'void');
$ffi->attach('GDALBuildVRTOptionsSetProgress' => [qw/opaque GDALProgressFunc opaque/] => 'void');
$ffi->attach('GDALBuildVRT' => [qw/string int opaque[] opaque opaque int*/] => 'opaque');
$ffi->attach('GDALMultiDimInfoOptionsNew' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALMultiDimInfoOptionsFree' => [qw/opaque/] => 'void');
$ffi->attach('GDALMultiDimInfo' => [qw/opaque opaque/] => 'string');
$ffi->attach('GDALMultiDimTranslateOptionsNew' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALMultiDimTranslateOptionsFree' => [qw/opaque/] => 'void');
$ffi->attach('GDALMultiDimTranslateOptionsSetProgress' => [qw/opaque GDALProgressFunc opaque/] => 'void');
$ffi->attach('GDALMultiDimTranslate' => [qw/string opaque int uint64* opaque int*/] => 'opaque');
$ffi->attach('GDALVectorInfoOptionsNew' => [qw/opaque opaque/] => 'opaque');
$ffi->attach('GDALVectorInfoOptionsFree' => [qw/opaque/] => 'void');
$ffi->attach('GDALVectorInfo' => [qw/opaque opaque/] => 'string');
# end of generated code

    if ($gdal eq 'Alien::gdal' and versioncmp($gdal->version, '2.3.1') <= 0) {
        # we do not use Alien::gdal->data_dir since it issues warnings due to GDAL bug
        my $pc = PkgConfig->find('gdal');
        if ($pc->errmsg) {
            my $dir = Alien::gdal->dist_dir;
            my %options = (search_path_override => ["$dir/lib/pkgconfig", "$dir/lib64/pkgconfig"]);
            $pc = PkgConfig->find('gdal', %options);
        }
        if ($pc->errmsg) {
            warn $pc->errmsg;
        } else {
            my $dir = $pc->get_var('datadir');
            # this gdal.pc bug was fixed in GDAL 2.3.1
            # we just hope the one configuring GDAL did not change it to something that ends '/data'
            $dir =~ s/\/data$//;
            if (opendir(my $dh, $dir)) {
                CPLSetConfigOption(GDAL_DATA => $dir);
            } else {
                my $dist_data_dir = Alien::gdal->dist_dir . '/share/gdal';
                if (-d $dist_data_dir) {
                    CPLSetConfigOption(GDAL_DATA => $dist_data_dir);
                }
                else {
                    warn "GDAL data directory ($dir) doesn't exist. Maybe Alien::gdal is not installed?";
                }
            }
        }
    } else {
        CPLSetConfigOption(GDAL_DATA => $gdal->data_dir);
    }

    $instance = {};
    $instance->{ffi} = $ffi;
    $instance->{gdal} = $gdal;
    SetErrorHandling();
    GDALAllRegister();
    return bless $instance, $class;
}

sub get_instance {
    my $class = shift;
    $instance = $class->new() unless $instance;
    return $instance;
}

sub DESTROY {
    UnsetErrorHandling();
}

sub GetVersionInfo {
    my $request = shift // 'VERSION_NUM';
    if ($request eq 'SEMANTIC') {
        my $version = GDALVersionInfo('VERSION_NUM') / 100;
        my $ret = '';
        while ($version > 0) {
            my $v = $version % 100;
            $ret = ".$ret" if $ret ne '';
            $ret = "$v$ret";
            $version = int($version/100);
        }
        return $ret;
    }
    return GDALVersionInfo($request);
}

sub GetDriver {
    my ($i) = @_;
    my $d = isint($i) ? GDALGetDriver($i) : GDALGetDriverByName($i);
    confess error_msg() // "Driver '$i' not found." unless $d;
    return bless \$d, 'Geo::GDAL::FFI::Driver';
}

sub GetDrivers {
    my @drivers;
    for my $i (0..GDALGetDriverCount()-1) {
        push @drivers, GetDriver($i);
    }
    return @drivers;
}

sub IdentifyDriver {
    my ($filename, $args) = @_;
    my $flags = 0;
    my $a = $args->{Flags} // [];
    for my $f (@$a) {
        print "$f\n";
        $flags |= $open_flags{$f};
    }
    print "$flags\n";
    my $drivers = 0;
    for my $o (@{$args->{AllowedDrivers}}) {
        $drivers = Geo::GDAL::FFI::CSLAddString($drivers, $o);
    }
    my $list = 0;
    for my $o (@{$args->{FileList}}) {
        $list = Geo::GDAL::FFI::CSLAddString($list, $o);
    }
    my $d;
    if ($flags or $drivers) {
        $d = GDALIdentifyDriverEx($filename, $flags, $drivers, $list);
    } else {
        $d = GDALIdentifyDriver($filename, $list);
    }
    Geo::GDAL::FFI::CSLDestroy($drivers);
    Geo::GDAL::FFI::CSLDestroy($list);
    return bless \$d, 'Geo::GDAL::FFI::Driver';
}

sub Open {
    my ($name, $args) = @_;
    $name //= '';
    $args //= {};
    my $flags = 0;
    my $a = $args->{Flags} // [];
    for my $f (@$a) {
        $flags |= $open_flags{$f};
    }
    my $drivers = 0;
    for my $o (@{$args->{AllowedDrivers}}) {
        $drivers = Geo::GDAL::FFI::CSLAddString($drivers, $o);
    }
    my $options = 0;
    for my $o (@{$args->{Options}}) {
        $options = Geo::GDAL::FFI::CSLAddString($options, $o);
    }
    my $files = 0;
    for my $o (@{$args->{SiblingFiles}}) {
        $files = Geo::GDAL::FFI::CSLAddString($files, $o);
    }
    my $ds = GDALOpenEx($name, $flags, $drivers, $options, $files);
    Geo::GDAL::FFI::CSLDestroy($drivers);
    Geo::GDAL::FFI::CSLDestroy($options);
    Geo::GDAL::FFI::CSLDestroy($files);
    if (@errors) {
        my $msg = join("\n", @errors);
        @errors = ();
        confess $msg;
    }
    unless ($ds) { # no VERBOSE_ERROR in options and fail
        confess "Open failed for '$name'. Hint: add VERBOSE_ERROR to open_flags.";
    }
    return bless \$ds, 'Geo::GDAL::FFI::Dataset';
}

sub write {
    print STDOUT $_[0];
}

sub close {
}

sub SetWriter {
    my ($self, $writer) = @_;
    $writer = $self unless $writer;
    my $w = $writer->can('write');
    my $c = $writer->can('close');
    confess "$writer must be able to write and close." unless $w && $c;
    #$self->{write} = $w;
    $self->{close} = $c;
    $self->{writer} = $self->{ffi}->closure(sub {
        my ($buf, $size, $count, $stream) = @_;
        my $retval = $w->(buffer_to_scalar($buf, $size*$count)) // 1;
        return $retval;
    });
    VSIStdoutSetRedirection($self->{writer}, 0);
}

sub CloseWriter {
    my $self = shift;
    $self->{close}->() if $self->{close};
    $self->SetWriter;
}

sub get_importer {
    my ($self, $format) = @_;
    my $importer = $self->can('OSRImportFrom' . $format);
    confess "Spatial reference importer for format '$format' not found!" unless $importer;
    return $importer;
}

sub get_exporter {
    my ($self, $format) = @_;
    my $exporter = $self->can('OSRExportTo' . $format);
    confess "Spatial reference exporter for format '$format' not found!" unless $exporter;
    return $exporter;
}

sub get_setter {
    my ($self, $proj) = @_;
    my $setter = $self->can('OSRSet' . $proj);
    confess "Parameter setter for projection '$proj' not found!" unless $setter;
    return $setter;
}

sub HaveGEOS {
    my $t = $geometry_types{Point};
    my $g = OGR_G_CreateGeometry($t);
    OGR_G_SetPoint($g, 0, 0, 0, 0);
    my $c = OGR_G_CreateGeometry($t);
    my $n = @errors;
    OGR_G_Centroid($g, $c);
    if (@errors > $n) {
        pop @errors;
        return undef;
    } else {
        return 1;
    }
}

sub SetConfigOption {
    my ($key, $default) = @_;
    CPLSetConfigOption($key, $default);
}

sub GetConfigOption {
    my ($key, $default) = @_;
    return CPLGetConfigOption($key, $default);
}

sub FindFile {
    my ($class, $basename) = @_ == 2 ? @_ : ('', @_);
    $class //= '';
    $basename //= '';
    return CPLFindFile($class, $basename);
}

sub PushFinderLocation {
    my ($location) = @_;
    $location //= '';
    CPLPushFinderLocation($location);
}

sub PopFinderLocation {
    CPLPopFinderLocation();
}

sub FinderClean {
    CPLFinderClean();
}

BEGIN {
    require PkgConfig;
    PkgConfig->import;
    my $gdal;
    eval {
        require Geo::GDAL::gdal;
        $gdal = Geo::GDAL::gdal->new();
    };
    if ($@) {
        require Alien::gdal;
        no strict 'subs';
        $gdal = Alien::gdal;
    }
    $instance = Geo::GDAL::FFI->new($gdal);
}

{
    #  avoid some used only once warnings
    local $FFI::Platypus::keep;
    local $FFI::Platypus::TypeParser::ffi_type;
}

#
# The next two subs are required for thread-safety, because GDAL error handling must be set per thread.
# So, it is disabled just before starting a new thread and renabled after in the thread.
# See perlmod and issue #53 for more information.
#

sub CLONE {
    SetErrorHandling();
}

sub CLONE_SKIP {
    UnsetErrorHandling();
    return 0;
}

1;

=pod

=encoding UTF-8

=head1 NAME

Geo::GDAL::FFI - A foreign function interface to GDAL

=head1 VERSION

Version 0.11

=head1 SYNOPSIS

This is an example of creating a vector dataset.

 use Geo::GDAL::FFI qw/GetDriver/;

 my $sr = Geo::GDAL::FFI::SpatialReference->new(EPSG => 3067);
 my $layer = GetDriver('ESRI Shapefile')
     ->Create('test.shp')
     ->CreateLayer({
         Name => 'test',
         SpatialReference => $sr,
         GeometryType => 'Point',
         Fields => [
         {
             Name => 'name',
             Type => 'String'
         }
         ]
     });
 my $f = Geo::GDAL::FFI::Feature->new($layer->GetDefn);
 $f->SetField(name => 'a');
 my $g = Geo::GDAL::FFI::Geometry->new('Point');
 $g->SetPoint(1, 2);
 $f->SetGeomField($g);
 $layer->CreateFeature($f);

This is an example of reading a vector dataset.

 use Geo::GDAL::FFI qw/Open/;

 my $layer = Open('test.shp')->GetLayer;
 $layer->ResetReading;
 while (my $feature = $layer->GetNextFeature) {
     my $value = $feature->GetField('name');
     my $geom = $feature->GetGeomField;
     say $value, ' ', $geom->AsText;
 }

This is an example of creating a raster dataset.

 use Geo::GDAL::FFI qw/GetDriver/;

 my $tiff = GetDriver('GTiff')->Create('test.tiff', 3, 2);
 my $ogc_wkt = 
        'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS84",6378137,298.257223563,'.
        'AUTHORITY["EPSG","7030"]],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,'.
        'AUTHORITY["EPSG","8901"]],UNIT["degree",0.01745329251994328,'.
        'AUTHORITY["EPSG","9122"]],AUTHORITY["EPSG","4326"]]';
 $tiff->SetProjectionString($ogc_wkt);
 my $transform = [10,2,0,20,0,3];
 $tiff->SetGeoTransform($transform);
 my $data = [[0,1,2],[3,4,5]];
 $tiff->GetBand->Write($data);

This is an example of reading a raster dataset. Note that using L<PDL>
and L<MCE::Shared> can greatly reduce the time needed to process large
raster datasets.

 use Geo::GDAL::FFI qw/Open/;

 my $band = Open($ARGV[0])->GetBand;
 my ($w_band, $h_band) = $band->GetSize;
 my ($w_block, $h_block) = $band->GetBlockSize;
 my $nodata = $band->GetNoDataValue;
 my ($xoff, $yoff) = (0,0);
 my ($min, $max);

 while (1) {
     if ($xoff >= $w_band) {
         $xoff = 0;
         $yoff += $h_block;
         last if $yoff >= $h_band;
     }
     my $w_real = $w_band - $xoff;
     $w_real = $w_block if $w_real > $w_block;
     my $h_real = $h_band - $yoff;
     $h_real = $h_block if $h_real > $h_block;

     my $data = $band->Read($xoff, $yoff, $w_real, $h_real);

     for my $y (0..$#$data) {
         my $row = $data->[$y];
         for my $x (0..$#$row) {
             my $value = $row->[$x];
             next if defined $nodata && $value == $nodata;
             $min = $value if !defined $min || $value < $min;
             $max = $value if !defined $max || $value > $max;
         }
     }
     
     $xoff += $w_block;
 }

 say "min = $min, max = $max";

=head1 DESCRIPTION

This is a foreign function interface to the GDAL geospatial data
access library.

=head1 IMPORTABLE FUNCTIONS

The most important importable functions are GetDriver and Open, which
return a driver and a dataset objects respectively. GetDrivers returns
all available drivers as objects.

Other importable functions include error handling configuration
(SetErrorHandling and UnsetErrorHandling), functions that return lists
of strings that are used in methods (Capabilities, OpenFlags,
DataTypes, ResamplingMethods, FieldTypes, FieldSubtypes,
Justifications, ColorInterpretations, GeometryTypes, GeometryFormats,
GridAlgorithms), also functions GetVersionInfo, HaveGEOS,
SetConfigOption, GetConfigOption, FindFile, PushFinderLocation,
PopFinderLocation, and FinderClean can be imported.

:all imports all above functions.

=head2 GetVersionInfo

 my $info = GetVersionInfo($request);

Returns the version information from the underlying GDAL
library. $request is optional and by default 'VERSION_NUM'.

=head2 GetDriver

 my $driver = GetDriver($name);

Returns the specific driver object.

=head2 GetDrivers

Returns a list of all available driver objects.

=head2 Open

 my $dataset = Open($name, {Flags => [qw/READONLY/], ...});

Open a dataset. $name is the name of the dataset. Named arguments are
the following.

=over 4

=item C<Flags>

Optional, default is a reference to an empty array. Note that some
drivers can open both raster and vector datasets.

=item C<AllowedDrivers>

Optional, default is all drivers. Use a reference to an array of
driver names to limit which drivers to test.

=item C<SiblingFiles>

Optional, default is to probe the file system. You may use a reference
to an array of auxiliary file names.

=item C<Options>

Optional, a reference to an array of driver specific open
options. Consult the main GDAL documentation for open options.

=back

=head2 Capabilities

Returns the list of capabilities (strings) a GDAL major object
(Driver, Dataset, Band, or Layer in Geo::GDAL::FFI) can have.

=head2 OpenFlags

Returns the list of opening flags to be used in the Open method.

=head2 DataTypes

Returns the list of raster cell data types to be used in e.g. the
CreateDataset method of the Driver class.

=head2 FieldTypes

Returns the list of field types.

=head2 FieldSubtypes

Returns the list of field subtypes.

=head2 Justifications

Returns the list of field justifications.

=head2 ColorInterpretations

Returns the list of color interpretations.

=head2 GeometryTypes

Returns the list of geometry types.

=head2 SetErrorHandling

Set a Perl function to catch errors reported within GDAL with
CPLError. The errors are collected into @Geo::GDAL::FFI::errors and
confessed if a method fails. This is the default.

=head2 UnsetErrorHandling

Unset the Perl function to catch GDAL errors. If no other error
handler is set, GDAL prints the errors into stderr.

=head1 NOTES ABOUT THREAD-SAFETY

This module is thread-safe provided the error handling is taken care of.
To ensure thread-safety GDAL error handling is automatically disabled
before creating a new thread and re-enabled after that in the just
created thread. The main thread needs to renable it via C<SetErrorHandling>,
after all thread creations and before eventually using any GDAL function. This
must be done explicitly in the main thread because there is no way
to do that automatically as for other threads.

=head1 METHODS

=head2 get_instance

 my $gdal = Geo::GDAL::FFI->get_instance;

Obtain the Geo::GDAL::FFI singleton object. The object is usually not needed.

=head1 LICENSE

This software is released under the Artistic License. See
L<perlartistic>.

=head1 AUTHOR

Ari Jolma - Ari.Jolma at gmail.com

=head1 SEE ALSO

L<Geo::GDAL::FFI::Object>

L<Geo::GDAL::FFI::Driver>

L<Geo::GDAL::FFI::SpatialReference>

L<Geo::GDAL::FFI::Dataset>

L<Geo::GDAL::FFI::Band>

L<Geo::GDAL::FFI::FeatureDefn>

L<Geo::GDAL::FFI::FieldDefn>

L<Geo::GDAL::FFI::GeomFieldDefn>

L<Geo::GDAL::FFI::Layer>

L<Geo::GDAL::FFI::Feature>

L<Geo::GDAL::FFI::Geometry>

L<Geo::GDAL::FFI::VSI>

L<Geo::GDAL::FFI::VSI::File>

L<Alien::gdal>, L<FFI::Platypus>, L<http://www.gdal.org>

=cut

__END__;
