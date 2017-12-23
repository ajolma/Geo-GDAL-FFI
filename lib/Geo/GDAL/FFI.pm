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
our %immutable;

our %capabilities = (
    OPEN => 1,
    CREATE => 1,
    CREATECOPY => 1,
    VIRTUALIO => 1,
    RASTER => 1,
    VECTOR => 1,
    GNM => 1,
    NOTNULL_FIELDS => 1,
    DEFAULT_FIELDS => 1,
    NOTNULL_GEOMFIELDS => 1,
    NONSPATIAL => 1,
    FEATURE_STYLES => 1,
    );

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

our %field_types = (
    Integer => 0,
    IntegerList => 1,
    Real => 2,
    RealList => 3,
    String => 4,
    StringList => 5,
    WideString => 6,     # do not use
    WideStringList => 7, # do not use
    Binary => 8,
    Date => 9,
    Time => 10,
    DateTime => 11,
    Integer64 => 12,
    Integer64List => 13,
    );
our %field_types_reverse = reverse %field_types;

our %field_subtypes = (
    None => 0,
    Boolean => 1,
    Int16 => 2,
    Float32 => 3
    );
our %field_subtypes_reverse = reverse %field_subtypes;

our %justification = (
    Undefined => 0,
    Left => 1,
    Right => 2
    );
our %justification_reverse = reverse %justification;

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
    $ffi->type('(double,string,pointer)->int' => 'GDALProgressFunc');

    # from port/*.h
    $ffi->attach('CPLPushErrorHandler' => ['CPLErrorHandler'] => 'void');
    $ffi->attach('CSLDestroy' => ['opaque'] => 'void');
    $ffi->attach('CSLAddString' => ['opaque', 'string'] => 'opaque');
    $ffi->attach('CSLCount' => ['opaque'] => 'int');
    $ffi->attach('CSLGetField' => ['opaque', 'int'] => 'string');

    # from ogr_core.h
    $ffi->attach( 'OGR_GT_Flatten' => ['unsigned int'] => 'unsigned int');

# created with parse_h.pl
# from /home/ajolma/src/gdal/gdal/gcore/gdal.h
eval{$ffi->attach('GDALGetDataTypeSize' => ['unsigned int'] => 'int');};
eval{$ffi->attach('GDALGetDataTypeSizeBits' => ['unsigned int'] => 'int');};
eval{$ffi->attach('GDALGetDataTypeSizeBytes' => ['unsigned int'] => 'int');};
eval{$ffi->attach('GDALDataTypeIsComplex' => ['unsigned int'] => 'int');};
eval{$ffi->attach('GDALDataTypeIsInteger' => ['unsigned int'] => 'int');};
eval{$ffi->attach('GDALDataTypeIsFloating' => ['unsigned int'] => 'int');};
eval{$ffi->attach('GDALDataTypeIsSigned' => ['unsigned int'] => 'int');};
eval{$ffi->attach('GDALGetDataTypeName' => ['unsigned int'] => 'string');};
eval{$ffi->attach('GDALGetDataTypeByName' => [qw/string/] => 'unsigned int');};
eval{$ffi->attach('GDALDataTypeUnion' => ['unsigned int','unsigned int'] => 'unsigned int');};
eval{$ffi->attach('GDALDataTypeUnionWithValue' => ['unsigned int','double','int'] => 'unsigned int');};
eval{$ffi->attach('GDALFindDataType' => [qw/int int int int/] => 'unsigned int');};
eval{$ffi->attach('GDALFindDataTypeForValue' => [qw/double int/] => 'unsigned int');};
eval{$ffi->attach('GDALAdjustValueToDataType' => ['unsigned int','double','int*','int*'] => 'double');};
eval{$ffi->attach('GDALGetNonComplexDataType' => ['unsigned int'] => 'unsigned int');};
eval{$ffi->attach('GDALGetAsyncStatusTypeName' => ['unsigned int'] => 'string');};
eval{$ffi->attach('GDALGetAsyncStatusTypeByName' => [qw/string/] => 'unsigned int');};
eval{$ffi->attach('GDALGetColorInterpretationName' => ['unsigned int'] => 'string');};
eval{$ffi->attach('GDALGetColorInterpretationByName' => [qw/string/] => 'unsigned int');};
eval{$ffi->attach('GDALGetPaletteInterpretationName' => ['unsigned int'] => 'string');};
eval{$ffi->attach('GDALAllRegister' => [] => 'void');};
eval{$ffi->attach('GDALCreate' => ['opaque','string','int','int','int','unsigned int','opaque'] => 'opaque');};
eval{$ffi->attach('GDALCreateCopy' => [qw/opaque string opaque int opaque GDALProgressFunc opaque/] => 'opaque');};
eval{$ffi->attach('GDALIdentifyDriver' => [qw/string opaque/] => 'opaque');};
eval{$ffi->attach('GDALIdentifyDriverEx' => ['string','unsigned int','string_pointer','string_pointer'] => 'opaque');};
eval{$ffi->attach('GDALOpen' => ['string','unsigned int'] => 'opaque');};
eval{$ffi->attach('GDALOpenShared' => ['string','unsigned int'] => 'opaque');};
eval{$ffi->attach('GDALOpenEx' => ['string','unsigned int','opaque','opaque','opaque'] => 'opaque');};
eval{$ffi->attach('GDALDumpOpenDatasets' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetDriverByName' => [qw/string/] => 'opaque');};
eval{$ffi->attach('GDALGetDriverCount' => [] => 'int');};
eval{$ffi->attach('GDALGetDriver' => [qw/int/] => 'opaque');};
eval{$ffi->attach('GDALCreateDriver' => [] => 'opaque');};
eval{$ffi->attach('GDALDestroyDriver' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALRegisterDriver' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALDeregisterDriver' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALDestroyDriverManager' => [] => 'void');};
eval{$ffi->attach('GDALDestroy' => [] => 'void');};
eval{$ffi->attach('GDALDeleteDataset' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('GDALRenameDataset' => [qw/opaque string string/] => 'int');};
eval{$ffi->attach('GDALCopyDatasetFiles' => [qw/opaque string string/] => 'int');};
eval{$ffi->attach('GDALValidateCreationOptions' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('GDALGetDriverShortName' => [qw/opaque/] => 'string');};
eval{$ffi->attach('GDALGetDriverLongName' => [qw/opaque/] => 'string');};
eval{$ffi->attach('GDALGetDriverHelpTopic' => [qw/opaque/] => 'string');};
eval{$ffi->attach('GDALGetDriverCreationOptionList' => [qw/opaque/] => 'string');};
eval{$ffi->attach('GDALInitGCPs' => [qw/int opaque/] => 'void');};
eval{$ffi->attach('GDALDeinitGCPs' => [qw/int opaque/] => 'void');};
eval{$ffi->attach('GDALDuplicateGCPs' => [qw/int opaque/] => 'opaque');};
eval{$ffi->attach('GDALGCPsToGeoTransform' => [qw/int opaque double* int/] => 'int');};
eval{$ffi->attach('GDALInvGeoTransform' => [qw/double* double*/] => 'int');};
eval{$ffi->attach('GDALApplyGeoTransform' => [qw/double* double double double* double*/] => 'void');};
eval{$ffi->attach('GDALComposeGeoTransforms' => [qw/double* double* double*/] => 'void');};
eval{$ffi->attach('GDALGetMetadataDomainList' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALGetMetadata' => [qw/opaque string/] => 'opaque');};
eval{$ffi->attach('GDALSetMetadata' => [qw/opaque opaque string/] => 'int');};
eval{$ffi->attach('GDALGetMetadataItem' => [qw/opaque string string/] => 'string');};
eval{$ffi->attach('GDALSetMetadataItem' => [qw/opaque string string string/] => 'int');};
eval{$ffi->attach('GDALGetDescription' => [qw/opaque/] => 'string');};
eval{$ffi->attach('GDALSetDescription' => [qw/opaque string/] => 'void');};
eval{$ffi->attach('GDALGetDatasetDriver' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALGetFileList' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALClose' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALGetRasterXSize' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterYSize' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterBand' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('GDALAddBand' => ['opaque','unsigned int','opaque'] => 'int');};
eval{$ffi->attach('GDALBeginAsyncReader' => ['opaque','int','int','int','int','opaque','int','int','unsigned int','int','int*','int','int','int','string_pointer'] => 'opaque');};
eval{$ffi->attach('GDALEndAsyncReader' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('GDALDatasetRasterIO' => ['opaque','unsigned int','int','int','int','int','opaque','int','int','unsigned int','int','int*','int','int','int'] => 'int');};
eval{$ffi->attach('GDALDatasetRasterIOEx' => ['opaque','unsigned int','int','int','int','int','opaque','int','int','unsigned int','int','int*','unsigned int','unsigned int','unsigned int','opaque'] => 'int');};
eval{$ffi->attach('GDALDatasetAdviseRead' => ['opaque','int','int','int','int','int','int','unsigned int','int','int*','string_pointer'] => 'int');};
eval{$ffi->attach('GDALGetProjectionRef' => [qw/opaque/] => 'string');};
eval{$ffi->attach('GDALSetProjection' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('GDALGetGeoTransform' => [qw/opaque double[6]/] => 'int');};
eval{$ffi->attach('GDALSetGeoTransform' => [qw/opaque double[6]/] => 'int');};
eval{$ffi->attach('GDALGetGCPCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetGCPProjection' => [qw/opaque/] => 'string');};
eval{$ffi->attach('GDALGetGCPs' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALSetGCPs' => [qw/opaque int opaque string/] => 'int');};
eval{$ffi->attach('GDALGetInternalHandle' => [qw/opaque string/] => 'opaque');};
eval{$ffi->attach('GDALReferenceDataset' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALDereferenceDataset' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALReleaseDataset' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALBuildOverviews' => [qw/opaque string int int* int int* GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALGetOpenDatasets' => [qw/opaque int*/] => 'void');};
eval{$ffi->attach('GDALGetAccess' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALFlushCache' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALCreateDatasetMaskBand' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('GDALDatasetCopyWholeRaster' => [qw/opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALRasterBandCopyWholeRaster' => [qw/opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALRegenerateOverviews' => [qw/opaque int opaque string GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALDatasetGetLayerCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALDatasetGetLayer' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('GDALDatasetGetLayerByName' => [qw/opaque string/] => 'opaque');};
eval{$ffi->attach('GDALDatasetDeleteLayer' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('GDALDatasetCreateLayer' => ['opaque','string','opaque','unsigned int','opaque'] => 'opaque');};
eval{$ffi->attach('GDALDatasetCopyLayer' => [qw/opaque opaque string string_pointer/] => 'opaque');};
eval{$ffi->attach('GDALDatasetResetReading' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALDatasetGetNextFeature' => [qw/opaque opaque double* GDALProgressFunc opaque/] => 'opaque');};
eval{$ffi->attach('GDALDatasetTestCapability' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('GDALDatasetExecuteSQL' => [qw/opaque string opaque string/] => 'opaque');};
eval{$ffi->attach('GDALDatasetReleaseResultSet' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('GDALDatasetGetStyleTable' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALDatasetSetStyleTableDirectly' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('GDALDatasetSetStyleTable' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('GDALDatasetStartTransaction' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('GDALDatasetCommitTransaction' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALDatasetRollbackTransaction' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterDataType' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('GDALGetBlockSize' => [qw/opaque int* int*/] => 'void');};
eval{$ffi->attach('GDALGetActualBlockSize' => [qw/opaque int int int* int*/] => 'int');};
eval{$ffi->attach('GDALRasterAdviseRead' => ['opaque','int','int','int','int','int','int','unsigned int','string_pointer'] => 'int');};
eval{$ffi->attach('GDALRasterIO' => ['opaque','unsigned int','int','int','int','int','opaque','int','int','unsigned int','int','int'] => 'int');};
eval{$ffi->attach('GDALRasterIOEx' => ['opaque','unsigned int','int','int','int','int','opaque','int','int','unsigned int','unsigned int','unsigned int','opaque'] => 'int');};
eval{$ffi->attach('GDALReadBlock' => [qw/opaque int int opaque/] => 'int');};
eval{$ffi->attach('GDALWriteBlock' => [qw/opaque int int opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterBandXSize' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterBandYSize' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterAccess' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('GDALGetBandNumber' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetBandDataset' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALGetRasterColorInterpretation' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('GDALSetRasterColorInterpretation' => ['opaque','unsigned int'] => 'int');};
eval{$ffi->attach('GDALGetRasterColorTable' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALSetRasterColorTable' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('GDALHasArbitraryOverviews' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetOverviewCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetOverview' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('GDALGetRasterNoDataValue' => [qw/opaque int*/] => 'double');};
eval{$ffi->attach('GDALSetRasterNoDataValue' => [qw/opaque double/] => 'int');};
eval{$ffi->attach('GDALDeleteRasterNoDataValue' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterCategoryNames' => [qw/opaque/] => 'string_pointer');};
eval{$ffi->attach('GDALSetRasterCategoryNames' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('GDALGetRasterMinimum' => [qw/opaque int*/] => 'double');};
eval{$ffi->attach('GDALGetRasterMaximum' => [qw/opaque int*/] => 'double');};
eval{$ffi->attach('GDALGetRasterStatistics' => [qw/opaque int int double* double* double* double*/] => 'int');};
eval{$ffi->attach('GDALComputeRasterStatistics' => [qw/opaque int double* double* double* double* GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALSetRasterStatistics' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('GDALGetRasterUnitType' => [qw/opaque/] => 'string');};
eval{$ffi->attach('GDALSetRasterUnitType' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('GDALGetRasterOffset' => [qw/opaque int*/] => 'double');};
eval{$ffi->attach('GDALSetRasterOffset' => [qw/opaque double/] => 'int');};
eval{$ffi->attach('GDALGetRasterScale' => [qw/opaque int*/] => 'double');};
eval{$ffi->attach('GDALSetRasterScale' => [qw/opaque double/] => 'int');};
eval{$ffi->attach('GDALComputeRasterMinMax' => [qw/opaque int double/] => 'void');};
eval{$ffi->attach('GDALFlushRasterCache' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterHistogram' => [qw/opaque double double int int* int int GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALGetRasterHistogramEx' => [qw/opaque double double int uint64* int int GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALGetDefaultHistogram' => [qw/opaque double* double* int* int* int GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALGetDefaultHistogramEx' => [qw/opaque double* double* int* uint64* int GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALSetDefaultHistogram' => [qw/opaque double double int int*/] => 'int');};
eval{$ffi->attach('GDALSetDefaultHistogramEx' => [qw/opaque double double int uint64*/] => 'int');};
eval{$ffi->attach('GDALGetRandomRasterSample' => [qw/opaque int float*/] => 'int');};
eval{$ffi->attach('GDALGetRasterSampleOverview' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('GDALGetRasterSampleOverviewEx' => [qw/opaque uint64/] => 'opaque');};
eval{$ffi->attach('GDALFillRaster' => [qw/opaque double double/] => 'int');};
eval{$ffi->attach('GDALComputeBandStats' => [qw/opaque int double* double* GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALOverviewMagnitudeCorrection' => [qw/opaque int opaque GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('GDALGetDefaultRAT' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALSetDefaultRAT' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('GDALAddDerivedBandPixelFunc' => [qw/string opaque/] => 'int');};
eval{$ffi->attach('GDALGetMaskBand' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALGetMaskFlags' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALCreateMaskBand' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('GDALGetDataCoverageStatus' => [qw/opaque int int int int int double*/] => 'int');};
eval{$ffi->attach('GDALARGetNextUpdatedRegion' => [qw/opaque double int* int* int* int*/] => 'unsigned int');};
eval{$ffi->attach('GDALARLockBuffer' => [qw/opaque double/] => 'int');};
eval{$ffi->attach('GDALARUnlockBuffer' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALGeneralCmdLineProcessor' => [qw/int string_pointer int/] => 'int');};
eval{$ffi->attach('GDALSwapWords' => [qw/opaque int int int/] => 'void');};
eval{$ffi->attach('GDALSwapWordsEx' => [qw/opaque int size_t int/] => 'void');};
eval{$ffi->attach('GDALCopyWords' => ['opaque','unsigned int','int','opaque','unsigned int','int','int'] => 'void');};
eval{$ffi->attach('GDALCopyBits' => [qw/pointer int int pointer int int int int/] => 'void');};
eval{$ffi->attach('GDALLoadWorldFile' => [qw/string double*/] => 'int');};
eval{$ffi->attach('GDALReadWorldFile' => [qw/string string double*/] => 'int');};
eval{$ffi->attach('GDALWriteWorldFile' => [qw/string string double*/] => 'int');};
eval{$ffi->attach('GDALLoadTabFile' => [qw/string double* string_pointer int* opaque/] => 'int');};
eval{$ffi->attach('GDALReadTabFile' => [qw/string double* string_pointer int* opaque/] => 'int');};
eval{$ffi->attach('GDALLoadOziMapFile' => [qw/string double* string_pointer int* opaque/] => 'int');};
eval{$ffi->attach('GDALReadOziMapFile' => [qw/string double* string_pointer int* opaque/] => 'int');};
eval{$ffi->attach('GDALDecToDMS' => [qw/double string int/] => 'string');};
eval{$ffi->attach('GDALPackedDMSToDec' => [qw/double/] => 'double');};
eval{$ffi->attach('GDALDecToPackedDMS' => [qw/double/] => 'double');};
eval{$ffi->attach('GDALVersionInfo' => [qw/string/] => 'string');};
eval{$ffi->attach('GDALCheckVersion' => [qw/int int string/] => 'int');};
eval{$ffi->attach('GDALExtractRPCInfo' => [qw/string_pointer opaque/] => 'int');};
eval{$ffi->attach('GDALCreateColorTable' => ['unsigned int'] => 'opaque');};
eval{$ffi->attach('GDALDestroyColorTable' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALCloneColorTable' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALGetPaletteInterpretation' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('GDALGetColorEntryCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALGetColorEntry' => [qw/opaque int/] => 'short[4]');};
eval{$ffi->attach('GDALGetColorEntryAsRGB' => [qw/opaque int short[4]/] => 'int');};
eval{$ffi->attach('GDALSetColorEntry' => [qw/opaque int short[4]/] => 'void');};
eval{$ffi->attach('GDALCreateColorRamp' => [qw/opaque int short[4] int short[4]/] => 'void');};
eval{$ffi->attach('GDALCreateRasterAttributeTable' => [] => 'opaque');};
eval{$ffi->attach('GDALDestroyRasterAttributeTable' => [qw/opaque/] => 'void');};
eval{$ffi->attach('GDALRATGetColumnCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALRATGetNameOfCol' => [qw/opaque int/] => 'string');};
eval{$ffi->attach('GDALRATGetUsageOfCol' => [qw/opaque int/] => 'unsigned int');};
eval{$ffi->attach('GDALRATGetTypeOfCol' => [qw/opaque int/] => 'unsigned int');};
eval{$ffi->attach('GDALRATGetColOfUsage' => ['opaque','unsigned int'] => 'int');};
eval{$ffi->attach('GDALRATGetRowCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALRATGetValueAsString' => [qw/opaque int int/] => 'string');};
eval{$ffi->attach('GDALRATGetValueAsInt' => [qw/opaque int int/] => 'int');};
eval{$ffi->attach('GDALRATGetValueAsDouble' => [qw/opaque int int/] => 'double');};
eval{$ffi->attach('GDALRATSetValueAsString' => [qw/opaque int int string/] => 'void');};
eval{$ffi->attach('GDALRATSetValueAsInt' => [qw/opaque int int int/] => 'void');};
eval{$ffi->attach('GDALRATSetValueAsDouble' => [qw/opaque int int double/] => 'void');};
eval{$ffi->attach('GDALRATChangesAreWrittenToFile' => [qw/opaque/] => 'int');};
eval{$ffi->attach('GDALRATValuesIOAsDouble' => ['opaque','unsigned int','int','int','int','double*'] => 'int');};
eval{$ffi->attach('GDALRATValuesIOAsInteger' => ['opaque','unsigned int','int','int','int','int*'] => 'int');};
eval{$ffi->attach('GDALRATValuesIOAsString' => ['opaque','unsigned int','int','int','int','string_pointer'] => 'int');};
eval{$ffi->attach('GDALRATSetRowCount' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('GDALRATCreateColumn' => ['opaque','string','unsigned int','unsigned int'] => 'int');};
eval{$ffi->attach('GDALRATSetLinearBinning' => [qw/opaque double double/] => 'int');};
eval{$ffi->attach('GDALRATGetLinearBinning' => [qw/opaque double* double*/] => 'int');};
eval{$ffi->attach('GDALRATInitializeFromColorTable' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('GDALRATTranslateToColorTable' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('GDALRATDumpReadable' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('GDALRATClone' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALRATSerializeJSON' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('GDALRATGetRowOfValue' => [qw/opaque double/] => 'int');};
eval{$ffi->attach('GDALSetCacheMax' => [qw/int/] => 'void');};
eval{$ffi->attach('GDALGetCacheMax' => [] => 'int');};
eval{$ffi->attach('GDALGetCacheUsed' => [] => 'int');};
eval{$ffi->attach('GDALSetCacheMax64' => [qw/sint64/] => 'void');};
eval{$ffi->attach('GDALGetCacheMax64' => [] => 'sint64');};
eval{$ffi->attach('GDALGetCacheUsed64' => [] => 'sint64');};
eval{$ffi->attach('GDALFlushCacheBlock' => [] => 'int');};
eval{$ffi->attach('GDALDatasetGetVirtualMem' => ['opaque','unsigned int','int','int','int','int','int','int','unsigned int','int','int*','int','sint64','sint64','size_t','size_t','int','string_pointer'] => 'opaque');};
eval{$ffi->attach('GDALRasterBandGetVirtualMem' => ['opaque','unsigned int','int','int','int','int','int','int','unsigned int','int','sint64','size_t','size_t','int','string_pointer'] => 'opaque');};
eval{$ffi->attach('GDALGetVirtualMemAuto' => ['opaque','unsigned int','int*','sint64*','string_pointer'] => 'opaque');};
eval{$ffi->attach('GDALDatasetGetTiledVirtualMem' => ['opaque','unsigned int','int','int','int','int','int','int','unsigned int','int','int*','unsigned int','size_t','int','string_pointer'] => 'opaque');};
eval{$ffi->attach('GDALRasterBandGetTiledVirtualMem' => ['opaque','unsigned int','int','int','int','int','int','int','unsigned int','size_t','int','string_pointer'] => 'opaque');};
eval{$ffi->attach('GDALCreatePansharpenedVRT' => [qw/string opaque int opaque/] => 'opaque');};
eval{$ffi->attach('GDALGetJPEG2000Structure' => [qw/string string_pointer/] => 'opaque');};
# from /home/ajolma/src/gdal/gdal/ogr/ogr_api.h
eval{$ffi->attach('OGR_G_CreateFromWkb' => [qw/string opaque opaque int/] => 'int');};
eval{$ffi->attach('OGR_G_CreateFromWkt' => [qw/string_pointer opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_CreateFromFgf' => [qw/string opaque opaque int int*/] => 'int');};
eval{$ffi->attach('OGR_G_DestroyGeometry' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_G_CreateGeometry' => ['unsigned int'] => 'opaque');};
eval{$ffi->attach('OGR_G_ApproximateArcAngles' => [qw/double double double double double double double double double/] => 'opaque');};
eval{$ffi->attach('OGR_G_ForceToPolygon' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ForceToLineString' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ForceToMultiPolygon' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ForceToMultiPoint' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ForceToMultiLineString' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ForceTo' => ['opaque','unsigned int','string_pointer'] => 'opaque');};
eval{$ffi->attach('OGR_G_GetDimension' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_GetCoordinateDimension' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_CoordinateDimension' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_SetCoordinateDimension' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_G_Is3D' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_IsMeasured' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Set3D' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_G_SetMeasured' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_G_Clone' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_GetEnvelope' => [qw/opaque double[4]/] => 'void');};
eval{$ffi->attach('OGR_G_GetEnvelope3D' => [qw/opaque double[6]/] => 'void');};
eval{$ffi->attach('OGR_G_ImportFromWkb' => [qw/opaque string int/] => 'int');};
eval{$ffi->attach('OGR_G_ExportToWkb' => ['opaque','unsigned int','string'] => 'int');};
eval{$ffi->attach('OGR_G_ExportToIsoWkb' => ['opaque','unsigned int','string'] => 'int');};
eval{$ffi->attach('OGR_G_WkbSize' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_ImportFromWkt' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OGR_G_ExportToWkt' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OGR_G_ExportToIsoWkt' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OGR_G_GetGeometryType' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_G_GetGeometryName' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_G_DumpReadable' => [qw/opaque opaque string/] => 'void');};
eval{$ffi->attach('OGR_G_FlattenTo2D' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_G_CloseRings' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_G_CreateFromGML' => [qw/string/] => 'opaque');};
eval{$ffi->attach('OGR_G_ExportToGML' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_G_ExportToGMLEx' => [qw/opaque string_pointer/] => 'string');};
eval{$ffi->attach('OGR_G_CreateFromGMLTree' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ExportToGMLTree' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ExportEnvelopeToGMLTree' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ExportToKML' => [qw/opaque string/] => 'string');};
eval{$ffi->attach('OGR_G_ExportToJson' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_G_ExportToJsonEx' => [qw/opaque string_pointer/] => 'string');};
eval{$ffi->attach('OGR_G_CreateGeometryFromJson' => [qw/string/] => 'opaque');};
eval{$ffi->attach('OGR_G_AssignSpatialReference' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_G_GetSpatialReference' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_Transform' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_TransformTo' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Simplify' => [qw/opaque double/] => 'opaque');};
eval{$ffi->attach('OGR_G_SimplifyPreserveTopology' => [qw/opaque double/] => 'opaque');};
eval{$ffi->attach('OGR_G_DelaunayTriangulation' => [qw/opaque double int/] => 'opaque');};
eval{$ffi->attach('OGR_G_Segmentize' => [qw/opaque double/] => 'void');};
eval{$ffi->attach('OGR_G_Intersects' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Equals' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Disjoint' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Touches' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Crosses' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Within' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Contains' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Overlaps' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Boundary' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_ConvexHull' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_Buffer' => [qw/opaque double int/] => 'opaque');};
eval{$ffi->attach('OGR_G_Intersection' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_Union' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_UnionCascaded' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_PointOnSurface' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_Difference' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_SymDifference' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_Distance' => [qw/opaque opaque/] => 'double');};
eval{$ffi->attach('OGR_G_Distance3D' => [qw/opaque opaque/] => 'double');};
eval{$ffi->attach('OGR_G_Length' => [qw/opaque/] => 'double');};
eval{$ffi->attach('OGR_G_Area' => [qw/opaque/] => 'double');};
eval{$ffi->attach('OGR_G_Centroid' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Value' => [qw/opaque double/] => 'opaque');};
eval{$ffi->attach('OGR_G_Empty' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_G_IsEmpty' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_IsValid' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_IsSimple' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_IsRing' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Polygonize' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_Intersect' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_Equal' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_SymmetricDifference' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_GetArea' => [qw/opaque/] => 'double');};
eval{$ffi->attach('OGR_G_GetBoundary' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_G_GetPointCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_GetPoints' => [qw/opaque opaque int opaque int opaque int/] => 'int');};
eval{$ffi->attach('OGR_G_GetPointsZM' => [qw/opaque opaque int opaque int opaque int opaque int/] => 'int');};
eval{$ffi->attach('OGR_G_GetX' => [qw/opaque int/] => 'double');};
eval{$ffi->attach('OGR_G_GetY' => [qw/opaque int/] => 'double');};
eval{$ffi->attach('OGR_G_GetZ' => [qw/opaque int/] => 'double');};
eval{$ffi->attach('OGR_G_GetM' => [qw/opaque int/] => 'double');};
eval{$ffi->attach('OGR_G_GetPoint' => [qw/opaque int double* double* double*/] => 'void');};
eval{$ffi->attach('OGR_G_GetPointZM' => [qw/opaque int double* double* double* double*/] => 'void');};
eval{$ffi->attach('OGR_G_SetPointCount' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_G_SetPoint' => [qw/opaque int double double double/] => 'void');};
eval{$ffi->attach('OGR_G_SetPoint_2D' => [qw/opaque int double double/] => 'void');};
eval{$ffi->attach('OGR_G_SetPointM' => [qw/opaque int double double double/] => 'void');};
eval{$ffi->attach('OGR_G_SetPointZM' => [qw/opaque int double double double double/] => 'void');};
eval{$ffi->attach('OGR_G_AddPoint' => [qw/opaque double double double/] => 'void');};
eval{$ffi->attach('OGR_G_AddPoint_2D' => [qw/opaque double double/] => 'void');};
eval{$ffi->attach('OGR_G_AddPointM' => [qw/opaque double double double/] => 'void');};
eval{$ffi->attach('OGR_G_AddPointZM' => [qw/opaque double double double double/] => 'void');};
eval{$ffi->attach('OGR_G_SetPoints' => [qw/opaque int opaque int opaque int opaque int/] => 'void');};
eval{$ffi->attach('OGR_G_SetPointsZM' => [qw/opaque int opaque int opaque int opaque int opaque int/] => 'void');};
eval{$ffi->attach('OGR_G_SwapXY' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_G_GetGeometryCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_G_GetGeometryRef' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_G_AddGeometry' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_AddGeometryDirectly' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_G_RemoveGeometry' => [qw/opaque int int/] => 'int');};
eval{$ffi->attach('OGR_G_HasCurveGeometry' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_G_GetLinearGeometry' => [qw/opaque double string_pointer/] => 'opaque');};
eval{$ffi->attach('OGR_G_GetCurveGeometry' => [qw/opaque string_pointer/] => 'opaque');};
eval{$ffi->attach('OGRBuildPolygonFromEdges' => [qw/opaque int int double int*/] => 'opaque');};
eval{$ffi->attach('OGRSetGenerate_DB2_V72_BYTE_ORDER' => [qw/int/] => 'int');};
eval{$ffi->attach('OGRGetGenerate_DB2_V72_BYTE_ORDER' => [] => 'int');};
eval{$ffi->attach('OGRSetNonLinearGeometriesEnabledFlag' => [qw/int/] => 'void');};
eval{$ffi->attach('OGRGetNonLinearGeometriesEnabledFlag' => [] => 'int');};
eval{$ffi->attach('OGR_Fld_Create' => ['string','unsigned int'] => 'opaque');};
eval{$ffi->attach('OGR_Fld_Destroy' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_Fld_SetName' => [qw/opaque string/] => 'void');};
eval{$ffi->attach('OGR_Fld_GetNameRef' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_Fld_GetType' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_Fld_SetType' => ['opaque','unsigned int'] => 'void');};
eval{$ffi->attach('OGR_Fld_GetSubType' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_Fld_SetSubType' => ['opaque','unsigned int'] => 'void');};
eval{$ffi->attach('OGR_Fld_GetJustify' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_Fld_SetJustify' => ['opaque','unsigned int'] => 'void');};
eval{$ffi->attach('OGR_Fld_GetWidth' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_Fld_SetWidth' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_Fld_GetPrecision' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_Fld_SetPrecision' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_Fld_Set' => ['opaque','string','unsigned int','int','int','unsigned int'] => 'void');};
eval{$ffi->attach('OGR_Fld_IsIgnored' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_Fld_SetIgnored' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_Fld_IsNullable' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_Fld_SetNullable' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_Fld_GetDefault' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_Fld_SetDefault' => [qw/opaque string/] => 'void');};
eval{$ffi->attach('OGR_Fld_IsDefaultDriverSpecific' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_GetFieldTypeName' => ['unsigned int'] => 'string');};
eval{$ffi->attach('OGR_GetFieldSubTypeName' => ['unsigned int'] => 'string');};
eval{$ffi->attach('OGR_AreTypeSubTypeCompatible' => ['unsigned int','unsigned int'] => 'int');};
eval{$ffi->attach('OGR_GFld_Create' => ['string','unsigned int'] => 'opaque');};
eval{$ffi->attach('OGR_GFld_Destroy' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_GFld_SetName' => [qw/opaque string/] => 'void');};
eval{$ffi->attach('OGR_GFld_GetNameRef' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_GFld_GetType' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_GFld_SetType' => ['opaque','unsigned int'] => 'void');};
eval{$ffi->attach('OGR_GFld_GetSpatialRef' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_GFld_SetSpatialRef' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_GFld_IsNullable' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_GFld_SetNullable' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_GFld_IsIgnored' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_GFld_SetIgnored' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_FD_Create' => [qw/string/] => 'opaque');};
eval{$ffi->attach('OGR_FD_Destroy' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_FD_Release' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_FD_GetName' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_FD_GetFieldCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_FD_GetFieldDefn' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_FD_GetFieldIndex' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_FD_AddFieldDefn' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_FD_DeleteFieldDefn' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_FD_ReorderFieldDefns' => [qw/opaque int*/] => 'int');};
eval{$ffi->attach('OGR_FD_GetGeomType' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_FD_SetGeomType' => ['opaque','unsigned int'] => 'void');};
eval{$ffi->attach('OGR_FD_IsGeometryIgnored' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_FD_SetGeometryIgnored' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_FD_IsStyleIgnored' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_FD_SetStyleIgnored' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_FD_Reference' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_FD_Dereference' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_FD_GetReferenceCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_FD_GetGeomFieldCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_FD_GetGeomFieldDefn' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_FD_GetGeomFieldIndex' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_FD_AddGeomFieldDefn' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_FD_DeleteGeomFieldDefn' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_FD_IsSame' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_F_Create' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_F_Destroy' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_F_GetDefnRef' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_F_SetGeometryDirectly' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_F_SetGeometry' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_F_GetGeometryRef' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_F_StealGeometry' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_F_Clone' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_F_Equal' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_F_GetFieldCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_F_GetFieldDefnRef' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_F_GetFieldIndex' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_F_IsFieldSet' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_F_UnsetField' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_F_IsFieldNull' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_F_IsFieldSetAndNotNull' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_F_SetFieldNull' => [qw/opaque int/] => 'void');};
eval{$ffi->attach('OGR_F_GetRawFieldRef' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_RawField_IsUnset' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_RawField_IsNull' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_RawField_SetUnset' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_RawField_SetNull' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_F_GetFieldAsInteger' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_F_GetFieldAsInteger64' => [qw/opaque int/] => 'sint64');};
eval{$ffi->attach('OGR_F_GetFieldAsDouble' => [qw/opaque int/] => 'double');};
eval{$ffi->attach('OGR_F_GetFieldAsString' => [qw/opaque int/] => 'string');};
eval{$ffi->attach('OGR_F_GetFieldAsIntegerList' => [qw/opaque int int*/] => 'pointer');};
eval{$ffi->attach('OGR_F_GetFieldAsInteger64List' => [qw/opaque int int*/] => 'pointer');};
eval{$ffi->attach('OGR_F_GetFieldAsDoubleList' => [qw/opaque int int*/] => 'pointer');};
eval{$ffi->attach('OGR_F_GetFieldAsStringList' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_F_GetFieldAsBinary' => [qw/opaque int int*/] => 'pointer');};
eval{$ffi->attach('OGR_F_GetFieldAsDateTime' => [qw/opaque int int* int* int* int* int* int* int*/] => 'int');};
eval{$ffi->attach('OGR_F_GetFieldAsDateTimeEx' => [qw/opaque int int* int* int* int* int* float* int*/] => 'int');};
eval{$ffi->attach('OGR_F_SetFieldInteger' => [qw/opaque int int/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldInteger64' => [qw/opaque int sint64/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldDouble' => [qw/opaque int double/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldString' => [qw/opaque int string/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldIntegerList' => [qw/opaque int int int[]/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldInteger64List' => [qw/opaque int int sint64[]/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldDoubleList' => [qw/opaque int int double[]/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldStringList' => [qw/opaque int opaque/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldRaw' => [qw/opaque int opaque/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldBinary' => [qw/opaque int int pointer/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldDateTime' => [qw/opaque int int int int int int int int/] => 'void');};
eval{$ffi->attach('OGR_F_SetFieldDateTimeEx' => [qw/opaque int int int int int int float int/] => 'void');};
eval{$ffi->attach('OGR_F_GetGeomFieldCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_F_GetGeomFieldDefnRef' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_F_GetGeomFieldIndex' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_F_GetGeomFieldRef' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_F_SetGeomFieldDirectly' => [qw/opaque int opaque/] => 'int');};
eval{$ffi->attach('OGR_F_SetGeomField' => [qw/opaque int opaque/] => 'int');};
eval{$ffi->attach('OGR_F_GetFID' => [qw/opaque/] => 'sint64');};
eval{$ffi->attach('OGR_F_SetFID' => [qw/opaque sint64/] => 'int');};
eval{$ffi->attach('OGR_F_DumpReadable' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_F_SetFrom' => [qw/opaque opaque int/] => 'int');};
eval{$ffi->attach('OGR_F_SetFromWithMap' => [qw/opaque opaque int int*/] => 'int');};
eval{$ffi->attach('OGR_F_GetStyleString' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_F_SetStyleString' => [qw/opaque string/] => 'void');};
eval{$ffi->attach('OGR_F_SetStyleStringDirectly' => [qw/opaque string/] => 'void');};
eval{$ffi->attach('OGR_F_GetStyleTable' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_F_SetStyleTableDirectly' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_F_SetStyleTable' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_F_GetNativeData' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_F_SetNativeData' => [qw/opaque string/] => 'void');};
eval{$ffi->attach('OGR_F_GetNativeMediaType' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_F_SetNativeMediaType' => [qw/opaque string/] => 'void');};
eval{$ffi->attach('OGR_F_FillUnsetWithDefault' => [qw/opaque int string_pointer/] => 'void');};
eval{$ffi->attach('OGR_F_Validate' => [qw/opaque int int/] => 'int');};
eval{$ffi->attach('OGR_L_GetName' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_L_GetGeomType' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_L_GetSpatialFilter' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_L_SetSpatialFilter' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_L_SetSpatialFilterRect' => [qw/opaque double double double double/] => 'void');};
eval{$ffi->attach('OGR_L_SetSpatialFilterEx' => [qw/opaque int opaque/] => 'void');};
eval{$ffi->attach('OGR_L_SetSpatialFilterRectEx' => [qw/opaque int double double double double/] => 'void');};
eval{$ffi->attach('OGR_L_SetAttributeFilter' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_L_ResetReading' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_L_GetNextFeature' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_L_SetNextByIndex' => [qw/opaque sint64/] => 'int');};
eval{$ffi->attach('OGR_L_GetFeature' => [qw/opaque sint64/] => 'opaque');};
eval{$ffi->attach('OGR_L_SetFeature' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_L_CreateFeature' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_L_DeleteFeature' => [qw/opaque sint64/] => 'int');};
eval{$ffi->attach('OGR_L_GetLayerDefn' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_L_GetSpatialRef' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_L_FindFieldIndex' => [qw/opaque string int/] => 'int');};
eval{$ffi->attach('OGR_L_GetFeatureCount' => [qw/opaque int/] => 'sint64');};
eval{$ffi->attach('OGR_L_GetExtent' => [qw/opaque double[4] int/] => 'int');};
eval{$ffi->attach('OGR_L_GetExtentEx' => [qw/opaque int double[4] int/] => 'int');};
eval{$ffi->attach('OGR_L_TestCapability' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_L_CreateField' => [qw/opaque opaque int/] => 'int');};
eval{$ffi->attach('OGR_L_CreateGeomField' => [qw/opaque opaque int/] => 'int');};
eval{$ffi->attach('OGR_L_DeleteField' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_L_ReorderFields' => [qw/opaque int*/] => 'int');};
eval{$ffi->attach('OGR_L_ReorderField' => [qw/opaque int int/] => 'int');};
eval{$ffi->attach('OGR_L_AlterFieldDefn' => [qw/opaque int opaque int/] => 'int');};
eval{$ffi->attach('OGR_L_StartTransaction' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_L_CommitTransaction' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_L_RollbackTransaction' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_L_Reference' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_L_Dereference' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_L_GetRefCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_L_SyncToDisk' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_L_GetFeaturesRead' => [qw/opaque/] => 'sint64');};
eval{$ffi->attach('OGR_L_GetFIDColumn' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_L_GetGeometryColumn' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_L_GetStyleTable' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_L_SetStyleTableDirectly' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_L_SetStyleTable' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_L_SetIgnoredFields' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_L_Intersection' => [qw/opaque opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('OGR_L_Union' => [qw/opaque opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('OGR_L_SymDifference' => [qw/opaque opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('OGR_L_Identity' => [qw/opaque opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('OGR_L_Update' => [qw/opaque opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('OGR_L_Clip' => [qw/opaque opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('OGR_L_Erase' => [qw/opaque opaque opaque string_pointer GDALProgressFunc opaque/] => 'int');};
eval{$ffi->attach('OGR_DS_Destroy' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_DS_GetName' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_DS_GetLayerCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_DS_GetLayer' => [qw/opaque int/] => 'opaque');};
eval{$ffi->attach('OGR_DS_GetLayerByName' => [qw/opaque string/] => 'opaque');};
eval{$ffi->attach('OGR_DS_DeleteLayer' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OGR_DS_GetDriver' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_DS_CreateLayer' => ['opaque','string','opaque','unsigned int','string_pointer'] => 'opaque');};
eval{$ffi->attach('OGR_DS_CopyLayer' => [qw/opaque opaque string string_pointer/] => 'opaque');};
eval{$ffi->attach('OGR_DS_TestCapability' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_DS_ExecuteSQL' => [qw/opaque string opaque string/] => 'opaque');};
eval{$ffi->attach('OGR_DS_ReleaseResultSet' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_DS_Reference' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_DS_Dereference' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_DS_GetRefCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_DS_GetSummaryRefCount' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_DS_SyncToDisk' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGR_DS_GetStyleTable' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_DS_SetStyleTableDirectly' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_DS_SetStyleTable' => [qw/opaque opaque/] => 'void');};
eval{$ffi->attach('OGR_Dr_GetName' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_Dr_Open' => [qw/opaque string int/] => 'opaque');};
eval{$ffi->attach('OGR_Dr_TestCapability' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_Dr_CreateDataSource' => [qw/opaque string string_pointer/] => 'opaque');};
eval{$ffi->attach('OGR_Dr_CopyDataSource' => [qw/opaque opaque string string_pointer/] => 'opaque');};
eval{$ffi->attach('OGR_Dr_DeleteDataSource' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGROpen' => [qw/string int opaque/] => 'opaque');};
eval{$ffi->attach('OGROpenShared' => [qw/string int opaque/] => 'opaque');};
eval{$ffi->attach('OGRReleaseDataSource' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OGRRegisterDriver' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGRDeregisterDriver' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGRGetDriverCount' => [] => 'int');};
eval{$ffi->attach('OGRGetDriver' => [qw/int/] => 'opaque');};
eval{$ffi->attach('OGRGetDriverByName' => [qw/string/] => 'opaque');};
eval{$ffi->attach('OGRGetOpenDSCount' => [] => 'int');};
eval{$ffi->attach('OGRGetOpenDS' => [qw/int/] => 'opaque');};
eval{$ffi->attach('OGRRegisterAll' => [] => 'void');};
eval{$ffi->attach('OGRCleanupAll' => [] => 'void');};
eval{$ffi->attach('OGR_SM_Create' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OGR_SM_Destroy' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_SM_InitFromFeature' => [qw/opaque opaque/] => 'string');};
eval{$ffi->attach('OGR_SM_InitStyleString' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_SM_GetPartCount' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_SM_GetPart' => [qw/opaque int string/] => 'opaque');};
eval{$ffi->attach('OGR_SM_AddPart' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OGR_SM_AddStyle' => [qw/opaque string string/] => 'int');};
eval{$ffi->attach('OGR_ST_Create' => ['unsigned int'] => 'opaque');};
eval{$ffi->attach('OGR_ST_Destroy' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_ST_GetType' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_ST_GetUnit' => [qw/opaque/] => 'unsigned int');};
eval{$ffi->attach('OGR_ST_SetUnit' => ['opaque','unsigned int','double'] => 'void');};
eval{$ffi->attach('OGR_ST_GetParamStr' => [qw/opaque int int*/] => 'string');};
eval{$ffi->attach('OGR_ST_GetParamNum' => [qw/opaque int int*/] => 'int');};
eval{$ffi->attach('OGR_ST_GetParamDbl' => [qw/opaque int int*/] => 'double');};
eval{$ffi->attach('OGR_ST_SetParamStr' => [qw/opaque int string/] => 'void');};
eval{$ffi->attach('OGR_ST_SetParamNum' => [qw/opaque int int/] => 'void');};
eval{$ffi->attach('OGR_ST_SetParamDbl' => [qw/opaque int double/] => 'void');};
eval{$ffi->attach('OGR_ST_GetStyleString' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_ST_GetRGBFromString' => [qw/opaque string int* int* int* int*/] => 'int');};
eval{$ffi->attach('OGR_STBL_Create' => [] => 'opaque');};
eval{$ffi->attach('OGR_STBL_Destroy' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_STBL_AddStyle' => [qw/opaque string string/] => 'int');};
eval{$ffi->attach('OGR_STBL_SaveStyleTable' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_STBL_LoadStyleTable' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OGR_STBL_Find' => [qw/opaque string/] => 'string');};
eval{$ffi->attach('OGR_STBL_ResetStyleStringReading' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OGR_STBL_GetNextStyle' => [qw/opaque/] => 'string');};
eval{$ffi->attach('OGR_STBL_GetLastStyleName' => [qw/opaque/] => 'string');};
# from /home/ajolma/src/gdal/gdal/ogr/ogr_srs_api.h
eval{$ffi->attach('OSRAxisEnumToName' => ['unsigned int'] => 'string');};
eval{$ffi->attach('OSRNewSpatialReference' => [qw/string/] => 'opaque');};
eval{$ffi->attach('OSRCloneGeogCS' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OSRClone' => [qw/opaque/] => 'opaque');};
eval{$ffi->attach('OSRDestroySpatialReference' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OSRReference' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRDereference' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRRelease' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OSRValidate' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRFixupOrdering' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRFixup' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRStripCTParms' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRImportFromEPSG' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OSRImportFromEPSGA' => [qw/opaque int/] => 'int');};
eval{$ffi->attach('OSRImportFromWkt' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OSRImportFromProj4' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRImportFromESRI' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OSRImportFromPCI' => [qw/opaque string string double*/] => 'int');};
eval{$ffi->attach('OSRImportFromUSGS' => [qw/opaque long long double* long/] => 'int');};
eval{$ffi->attach('OSRImportFromXML' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRImportFromDict' => [qw/opaque string string/] => 'int');};
eval{$ffi->attach('OSRImportFromPanorama' => [qw/opaque long long long double*/] => 'int');};
eval{$ffi->attach('OSRImportFromOzi' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OSRImportFromMICoordSys' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRImportFromERM' => [qw/opaque string string string/] => 'int');};
eval{$ffi->attach('OSRImportFromUrl' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRExportToWkt' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OSRExportToPrettyWkt' => [qw/opaque string_pointer int/] => 'int');};
eval{$ffi->attach('OSRExportToProj4' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OSRExportToPCI' => [qw/opaque string_pointer string_pointer double*/] => 'int');};
eval{$ffi->attach('OSRExportToUSGS' => [qw/opaque long long double* long/] => 'int');};
eval{$ffi->attach('OSRExportToXML' => [qw/opaque string_pointer string/] => 'int');};
eval{$ffi->attach('OSRExportToPanorama' => [qw/opaque long long long long double*/] => 'int');};
eval{$ffi->attach('OSRExportToMICoordSys' => [qw/opaque string_pointer/] => 'int');};
eval{$ffi->attach('OSRExportToERM' => [qw/opaque string string string/] => 'int');};
eval{$ffi->attach('OSRMorphToESRI' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRMorphFromESRI' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRConvertToOtherProjection' => [qw/opaque string string_pointer/] => 'opaque');};
eval{$ffi->attach('OSRSetAttrValue' => [qw/opaque string string/] => 'int');};
eval{$ffi->attach('OSRGetAttrValue' => [qw/opaque string int/] => 'string');};
eval{$ffi->attach('OSRSetAngularUnits' => [qw/opaque string double/] => 'int');};
eval{$ffi->attach('OSRGetAngularUnits' => [qw/opaque string_pointer/] => 'double');};
eval{$ffi->attach('OSRSetLinearUnits' => [qw/opaque string double/] => 'int');};
eval{$ffi->attach('OSRSetTargetLinearUnits' => [qw/opaque string string double/] => 'int');};
eval{$ffi->attach('OSRSetLinearUnitsAndUpdateParameters' => [qw/opaque string double/] => 'int');};
eval{$ffi->attach('OSRGetLinearUnits' => [qw/opaque string_pointer/] => 'double');};
eval{$ffi->attach('OSRGetTargetLinearUnits' => [qw/opaque string string_pointer/] => 'double');};
eval{$ffi->attach('OSRGetPrimeMeridian' => [qw/opaque string_pointer/] => 'double');};
eval{$ffi->attach('OSRIsGeographic' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRIsLocal' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRIsProjected' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRIsCompound' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRIsGeocentric' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRIsVertical' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRIsSameGeogCS' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OSRIsSameVertCS' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OSRIsSame' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OSRSetLocalCS' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRSetProjCS' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRSetGeocCS' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRSetWellKnownGeogCS' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRSetFromUserInput' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRCopyGeogCSFrom' => [qw/opaque opaque/] => 'int');};
eval{$ffi->attach('OSRSetTOWGS84' => [qw/opaque double double double double double double double/] => 'int');};
eval{$ffi->attach('OSRGetTOWGS84' => [qw/opaque double* int/] => 'int');};
eval{$ffi->attach('OSRSetCompoundCS' => [qw/opaque string opaque opaque/] => 'int');};
eval{$ffi->attach('OSRSetGeogCS' => [qw/opaque string string string double double string double string double/] => 'int');};
eval{$ffi->attach('OSRSetVertCS' => [qw/opaque string string int/] => 'int');};
eval{$ffi->attach('OSRGetSemiMajor' => [qw/opaque int*/] => 'double');};
eval{$ffi->attach('OSRGetSemiMinor' => [qw/opaque int*/] => 'double');};
eval{$ffi->attach('OSRGetInvFlattening' => [qw/opaque int*/] => 'double');};
eval{$ffi->attach('OSRSetAuthority' => [qw/opaque string string int/] => 'int');};
eval{$ffi->attach('OSRGetAuthorityCode' => [qw/opaque string/] => 'string');};
eval{$ffi->attach('OSRGetAuthorityName' => [qw/opaque string/] => 'string');};
eval{$ffi->attach('OSRSetProjection' => [qw/opaque string/] => 'int');};
eval{$ffi->attach('OSRSetProjParm' => [qw/opaque string double/] => 'int');};
eval{$ffi->attach('OSRGetProjParm' => [qw/opaque string double int*/] => 'double');};
eval{$ffi->attach('OSRSetNormProjParm' => [qw/opaque string double/] => 'int');};
eval{$ffi->attach('OSRGetNormProjParm' => [qw/opaque string double int*/] => 'double');};
eval{$ffi->attach('OSRSetUTM' => [qw/opaque int int/] => 'int');};
eval{$ffi->attach('OSRGetUTMZone' => [qw/opaque int*/] => 'int');};
eval{$ffi->attach('OSRSetStatePlane' => [qw/opaque int int/] => 'int');};
eval{$ffi->attach('OSRSetStatePlaneWithUnits' => [qw/opaque int int string double/] => 'int');};
eval{$ffi->attach('OSRAutoIdentifyEPSG' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRFindMatches' => [qw/opaque string_pointer int* int*/] => 'opaque');};
eval{$ffi->attach('OSRFreeSRSArray' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OSREPSGTreatsAsLatLong' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSREPSGTreatsAsNorthingEasting' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRGetAxis' => ['opaque','string','int','unsigned int'] => 'string');};
eval{$ffi->attach('OSRSetAxes' => ['opaque','string','string','unsigned int','string','unsigned int'] => 'int');};
eval{$ffi->attach('OSRSetACEA' => [qw/opaque double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetAE' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetBonne' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetCEA' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetCS' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetEC' => [qw/opaque double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetEckert' => [qw/opaque int double double double/] => 'int');};
eval{$ffi->attach('OSRSetEckertIV' => [qw/opaque double double double/] => 'int');};
eval{$ffi->attach('OSRSetEckertVI' => [qw/opaque double double double/] => 'int');};
eval{$ffi->attach('OSRSetEquirectangular' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetEquirectangular2' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetGS' => [qw/opaque double double double/] => 'int');};
eval{$ffi->attach('OSRSetGH' => [qw/opaque double double double/] => 'int');};
eval{$ffi->attach('OSRSetIGH' => [qw/opaque/] => 'int');};
eval{$ffi->attach('OSRSetGEOS' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetGaussSchreiberTMercator' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetGnomonic' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetHOM' => [qw/opaque double double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetHOMAC' => [qw/opaque double double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetHOM2PNO' => [qw/opaque double double double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetIWMPolyconic' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetKrovak' => [qw/opaque double double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetLAEA' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetLCC' => [qw/opaque double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetLCC1SP' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetLCCB' => [qw/opaque double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetMC' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetMercator' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetMercator2SP' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetMollweide' => [qw/opaque double double double/] => 'int');};
eval{$ffi->attach('OSRSetNZMG' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetOS' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetOrthographic' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetPolyconic' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetPS' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetRobinson' => [qw/opaque double double double/] => 'int');};
eval{$ffi->attach('OSRSetSinusoidal' => [qw/opaque double double double/] => 'int');};
eval{$ffi->attach('OSRSetStereographic' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetSOC' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetTM' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetTMVariant' => [qw/opaque string double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetTMG' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRSetTMSO' => [qw/opaque double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetTPED' => [qw/opaque double double double double double double/] => 'int');};
eval{$ffi->attach('OSRSetVDG' => [qw/opaque double double double/] => 'int');};
eval{$ffi->attach('OSRSetWagner' => [qw/opaque int double double double/] => 'int');};
eval{$ffi->attach('OSRSetQSC' => [qw/opaque double double/] => 'int');};
eval{$ffi->attach('OSRSetSCH' => [qw/opaque double double double double/] => 'int');};
eval{$ffi->attach('OSRCalcInvFlattening' => [qw/double double/] => 'double');};
eval{$ffi->attach('OSRCalcSemiMinorFromInvFlattening' => [qw/double double/] => 'double');};
eval{$ffi->attach('OSRCleanup' => [] => 'void');};
eval{$ffi->attach('OCTNewCoordinateTransformation' => [qw/opaque opaque/] => 'opaque');};
eval{$ffi->attach('OCTDestroyCoordinateTransformation' => [qw/opaque/] => 'void');};
eval{$ffi->attach('OCTTransform' => [qw/opaque int double* double* double*/] => 'int');};
eval{$ffi->attach('OCTTransformEx' => [qw/opaque int double* double* double* int*/] => 'int');};
eval{$ffi->attach('OCTProj4Normalize' => [qw/string/] => 'string');};
eval{$ffi->attach('OCTCleanupProjMutex' => [] => 'void');};
eval{$ffi->attach('OPTGetProjectionMethods' => [] => 'string_pointer');};
eval{$ffi->attach('OPTGetParameterList' => [qw/string string_pointer/] => 'string_pointer');};
eval{$ffi->attach('OPTGetParameterInfo' => [qw/string string string_pointer string_pointer double*/] => 'int');};
    
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

sub Drivers {
    my $self = shift;
    my @retval;
    for my $i (0..$self->GetDriverCount-1) {
        push @retval, $self->GetDriver($i);
    }
    return wantarray ? @retval : \@retval;
}

sub GetDriverByName {
    #my $this_subs_name = (caller(0))[3];
    #say STDERR "called $this_subs_name";
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

sub HasCapability {
    my ($self, $cap) = @_;
    my $tmp = $capabilities{$cap};
    croak "Unknown constant: $cap\n" unless defined $tmp;
    my $md = $self->GetMetadata('');
    return $md->{'DCAP_'.$cap};
}

sub GetMetadataDomainList {
    my ($self) = @_;
    #my $this_subs_name = (caller(0))[3];
    #say STDERR "called $this_subs_name";
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
    my %md;
    unless (defined $domain) {
        for $domain ($self->GetMetadataDomainList) {
            $md{$domain} = $self->GetMetadata($domain);
        }
        return wantarray ? %md : \%md;
    }
    my $csl = Geo::GDAL::FFI::GDALGetMetadata($$self, $domain);    
    for my $i (0..Geo::GDAL::FFI::CSLCount($csl)-1) {
        my ($name, $value) = split /=/, Geo::GDAL::FFI::CSLGetField($csl, $i);
        $md{$name} = $value;
    }
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
*Name = *GetDescription;

sub Create {
    #my $this_subs_name = (caller(0))[3];
    #say STDERR "called $this_subs_name";
    my ($self, $name, $width, $height, $bands, $dt, $options) = @_;
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
    if (!$ds || @errors) {
        my $msg;
        if (@errors) {
            $msg = join("\n", @errors);
            @errors = ();
        }
        $msg //= 'Create failed. (Driver = '.$self->GetDescription.')';
        croak $msg;
    }
    return bless \$ds, 'Geo::GDAL::FFI::Dataset';
}

sub CreateCopy {
    my ($self, $name, $ds, $strict, $options, $progress, $progress_data) = @_;
    my $o = 0;
    for my $key (keys %$options) {
        $o = Geo::GDAL::FFI::CSLAddString($o, "$key=$options->{$key}");
    }
    my $copy = Geo::GDAL::FFI::GDALCreateCopy($$self, $name, $$ds, $strict, $o, $progress, $progress_data);
    if (!$copy || @errors) {
        my $msg;
        if (@errors) {
            $msg = join("\n", @errors);
            @errors = ();
        }
        $msg //= 'CreateCopy failed. (Driver = '.$self->GetDescription.')';
        croak $msg;
    }
    return bless \$copy, 'Geo::GDAL::FFI::Dataset';
}

sub CreateVector {
    my ($self, $name, $options) = @_;
    $self->Create($name, 0, 0, 0, undef, $options);
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
use FFI::Platypus::Buffer;

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
        my ($pointer, $size) = scalar_to_buffer $buf;
        my $e = Geo::GDAL::FFI::GDALReadBlock($$self, $xoff, $yoff, $pointer);
    } else {
        $bufxsize //= $xsize;
        $bufysize //= $ysize;
        $w = $bufxsize * $bytes_per_cell;
        $buf = ' ' x ($bufysize * $w);
        my ($pointer, $size) = scalar_to_buffer $buf;
        Geo::GDAL::FFI::GDALRasterIO($$self, Geo::GDAL::FFI::Read, $xoff, $yoff, $xsize, $ysize, $pointer, $bufxsize, $bufysize, $t, 0, 0);
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
    my ($pointer, $size) = scalar_to_buffer $buf;
    Geo::GDAL::FFI::GDALRasterIO($$self, Geo::GDAL::FFI::Write, $xoff, $yoff, $xsize, $ysize, $pointer, $bufxsize, $bufysize, $t, 0, 0);
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
    my ($pointer, $size) = scalar_to_buffer $buf;
    Geo::GDAL::FFI::GDALWriteBlock($$self, $xoff, $yoff, $pointer);
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

sub CreateField {
    my ($self, $d, $approx_ok) = @_;
    $approx_ok //= 1;
    my $e = Geo::GDAL::FFI::OGR_L_CreateField($$self, $$d, $approx_ok);
    return unless $e;
}

sub GetSpatialRef {
    my ($self) = @_;
    my $sr = Geo::GDAL::FFI::OGR_L_GetSpatialRef($$self);
    return unless $sr;
    return bless \$sr, 'Geo::GDAL::FFI::SpatialReference';
}

sub ResetReading {
    my $self = shift;
    Geo::GDAL::FFI::OGR_L_ResetReading($$self);
}

sub GetNextFeature {
    my $self = shift;
    my $f = Geo::GDAL::FFI::OGR_L_GetNextFeature($$self);
    return unless $f;
    return bless \$f, 'Geo::GDAL::FFI::Feature';
}

sub GetFeature {
    my ($self, $fid) = @_;
    my $f = Geo::GDAL::FFI::OGR_L_GetFeature($$self, $fid);
    croak unless $f;
    return bless \$f, 'Geo::GDAL::FFI::Feature';
}

sub SetFeature {
    my ($self, $f) = @_;
    Geo::GDAL::FFI::OGR_L_SetFeature($$self, $$f);
}

sub CreateFeature {
    my ($self, $f) = @_;
    my $e = Geo::GDAL::FFI::OGR_L_CreateFeature($$self, $$f);
    return $f unless $e;
}

sub DeleteFeature {
    my ($self, $fid) = @_;
    my $e = Geo::GDAL::FFI::OGR_L_DeleteFeature($$self, $fid);
    return unless $e;
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

sub GetFieldCount {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_FD_GetFieldCount($$self);
}

sub GetGeomFieldCount {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_FD_GetGeomFieldCount($$self);
}

sub GetField {
    my ($self, $i) = @_;
    my $d = Geo::GDAL::FFI::OGR_FD_GetFieldDefn($$self, $i);
    croak "No such field: $i" unless $d;
    ++$immutable{$d};
    #say STDERR "$d immutable";
    return bless \$d, 'Geo::GDAL::FFI::FieldDefn';
}

sub GetGeomField {
    my ($self, $i) = @_;
    my $d = Geo::GDAL::FFI::OGR_FD_GetGeomFieldDefn($$self, $i);
    croak "No such field: $i" unless $d;
    ++$immutable{$d};
    #say STDERR "$d immutable";
    return bless \$d, 'Geo::GDAL::FFI::GeomFieldDefn';
}

sub GetFieldIndex {
    my ($self, $name) = @_;
    return Geo::GDAL::FFI::OGR_FD_GetFieldIndex($$self, $name);
}

sub GetGeomFieldIndex {
    my ($self, $name) = @_;
    return Geo::GDAL::FFI::OGR_FD_GetGeomFieldIndex($$self, $name);
}

sub AddField {
    my ($self, $d) = @_;
    Geo::GDAL::FFI::OGR_FD_AddFieldDefn($$self, $$d);
}

sub AddGeomField {
    my ($self, $d) = @_;
    Geo::GDAL::FFI::OGR_FD_AddGeomFieldDefn($$self, $$d);
}

sub DeleteField {
    my ($self, $i) = @_;
    Geo::GDAL::FFI::OGR_FD_DeleteFieldDefn($$self, $i);
}

sub DeleteGeomField {
    my ($self, $i) = @_;
    Geo::GDAL::FFI::OGR_FD_DeleteGeomFieldDefn($$self, $i);
}

sub GetGeomType {
    my ($self) = @_;
    return $geometry_types_reverse{Geo::GDAL::FFI::OGR_FD_GetGeomType($$self)};
}

sub SetGeomType {
    my ($self, $type) = @_;
    $type //= 'String';
    my $tmp = $geometry_types{$type};
    confess "Unknown constant: $type\n" unless defined $tmp;
    $type = $tmp;
    Geo::GDAL::FFI::OGR_FD_SetGeomType($$self, $type);
}

sub IsGeometryIgnored {
    my ($self) = @_;
    Geo::GDAL::FFI::OGR_FD_IsGeometryIgnored($$self);
}

sub SetGeometryIgnored {
    my ($self, $i) = @_;
    Geo::GDAL::FFI::OGR_FD_SetGeometryIgnored($$self, $i);
}

sub IsStyleIgnored {
    my ($self) = @_;
    Geo::GDAL::FFI::OGR_FD_IsStyleIgnored($$self);
}

sub SetStyleIgnored {
    my ($self, $i) = @_;
    Geo::GDAL::FFI::OGR_FD_SetStyleIgnored($$self, $i);
}


package Geo::GDAL::FFI::FieldDefn;
use v5.10;
use strict;
use warnings;
use Carp;

sub new {
    my ($class, $name, $type) = @_;
    $name //= 'Unnamed';
    $type //= 'String';
    my $tmp = $field_types{$type};
    confess "Unknown constant: $type\n" unless defined $tmp;
    $type = $tmp;
    my $f = Geo::GDAL::FFI::OGR_Fld_Create($name, $type);
    return bless \$f, $class;
}

sub DESTROY {
    my $self = shift;
    #say STDERR "destroy $self => $$self";
    if ($immutable{$$self}) {
        #say STDERR "remove it from immutable";
        $immutable{$$self}--;
        delete $immutable{$$self} if $immutable{$$self} == 0;
    } else {
        #say STDERR "destroy it";
        Geo::GDAL::FFI::OGR_Fld_Destroy($$self);
    }
}

sub SetName {
    my ($self, $name) = @_;
    croak "Can't modify an immutable object." if $immutable{$$self};
    $name //= '';
    Geo::GDAL::FFI::OGR_Fld_SetName($$self, $name);
}

sub GetName {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_Fld_GetNameRef($$self);
}
*Name = *GetName;

sub SetType {
    my ($self, $type) = @_;
    croak "Can't modify an immutable object." if $immutable{$$self};
    $type //= 'String';
    my $tmp = $field_types{$type};
    confess "Unknown constant: $type\n" unless defined $tmp;
    $type = $tmp;
    Geo::GDAL::FFI::OGR_Fld_SetType($$self, $type);
}

sub GetType {
    my ($self) = @_;
    return $field_types_reverse{Geo::GDAL::FFI::OGR_Fld_GetType($$self)};
}
*Type = *GetType;

sub SetSubtype {
    my ($self, $subtype) = @_;
    croak "Can't modify an immutable object." if $immutable{$$self};
    $subtype //= 'None';
    my $tmp = $field_subtypes{$subtype};
    confess "Unknown constant: $subtype\n" unless defined $tmp;
    $subtype = $tmp;
    Geo::GDAL::FFI::OGR_Fld_SetSubType($$self, $subtype);
}

sub GetSubtype {
    my ($self) = @_;
    return $field_subtypes_reverse{Geo::GDAL::FFI::OGR_Fld_GetSubType($$self)};
}
*Subtype = *GetSubtype;

sub SetJustify {
    my ($self, $justify) = @_;
    croak "Can't modify an immutable object." if $immutable{$$self};
    $justify //= 'Undefined';
    my $tmp = $justification{$justify};
    confess "Unknown constant: $justify\n" unless defined $tmp;
    $justify = $tmp;
    Geo::GDAL::FFI::OGR_Fld_SetJustify($$self, $justify);
}

sub GetJustify {
    my ($self) = @_;
    return $justification_reverse{Geo::GDAL::FFI::OGR_Fld_GetJustify($$self)};
}
*Justify = *GetJustify;

sub SetWidth {
    my ($self, $width) = @_;
    croak "Can't modify an immutable object." if $immutable{$$self};
    $width //= '';
    Geo::GDAL::FFI::OGR_Fld_SetWidth($$self, $width);
}

sub GetWidth {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_Fld_GetWidth($$self);
}
*Width = *GetWidth;

sub SetPrecision {
    my ($self, $precision) = @_;
    croak "Can't modify an immutable object." if $immutable{$$self};
    $precision //= '';
    Geo::GDAL::FFI::OGR_Fld_SetPrecision($$self, $precision);
}

sub GetPrecision {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_Fld_GetPrecision($$self);
}
*Precision = *GetPrecision;

sub SetIgnored {
    my ($self, $ignored) = @_;
    croak "Can't modify an immutable object." if $immutable{$$self};
    $ignored //= 0;
    Geo::GDAL::FFI::OGR_Fld_SetIgnored($$self, $ignored);
}

sub IsIgnored {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_Fld_IsIgnored($$self);
}

sub SetNullable {
    my ($self, $nullable) = @_;
    croak "Can't modify an immutable object." if $immutable{$$self};
    $nullable //= 0;
    Geo::GDAL::FFI::OGR_Fld_SetNullable($$self, $nullable);
}

sub IsNullable {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_Fld_IsNullable($$self);
}

package Geo::GDAL::FFI::GeomFieldDefn;
use v5.10;
use strict;
use warnings;
use Carp;

sub new {
    my ($class, $name, $type) = @_;
    $name //= 'Unnamed';
    $type //= 'String';
    my $tmp = $geometry_types{$type};
    confess "Unknown constant: $type\n" unless defined $tmp;
    $type = $tmp;
    my $f = Geo::GDAL::FFI::OGR_GFld_Create($name, $type);
    return bless \$f, $class;
}

sub DESTROY {
    my $self = shift;
    if ($immutable{$$self}) {
        $immutable{$$self}--;
        delete $immutable{$$self} if $immutable{$$self} == 0;
    } else {
        Geo::GDAL::FFI::OGR_GFld_Destroy($$self);
    }
}

sub SetName {
    my ($self, $name) = @_;
    croak "Can't modify an immutable object." if $immutable{$$self};
    $name //= '';
    Geo::GDAL::FFI::OGR_GFld_SetName($$self, $name);
}

sub GetName {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_GFld_GetNameRef($$self);
}
*Name = *GetName;

sub SetType {
    my ($self, $type) = @_;
    croak "Can't modify an immutable object." if $immutable{$$self};
    $type //= 'String';
    my $tmp = $geometry_types{$type};
    confess "Unknown constant: $type\n" unless defined $tmp;
    $type = $tmp;
    Geo::GDAL::FFI::OGR_GFld_SetType($$self, $type);
}

sub GetType {
    my ($self) = @_;
    return $geometry_types_reverse{Geo::GDAL::FFI::OGR_GFld_GetType($$self)};
}
*Type = *GetType;

sub SetSpatialRef {
    my ($self, $sr) = @_;
    croak "Can't modify an immutable object." if $immutable{$$self};
    Geo::GDAL::FFI::OGR_GFld_SetSpatialRef($$self, $sr);
}

sub GetSpatialRef {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_GFld_GetSpatialRef($$self);
}
*SpatialRef = *GetSpatialRef;

sub SetIgnored {
    my ($self, $ignored) = @_;
    croak "Can't modify an immutable object." if $immutable{$$self};
    $ignored //= 0;
    Geo::GDAL::FFI::OGR_GFld_SetIgnored($$self, $ignored);
}

sub IsIgnored {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_GFld_IsIgnored($$self);
}

sub SetNullable {
    my ($self, $nullable) = @_;
    croak "Can't modify an immutable object." if $immutable{$$self};
    $nullable //= 0;
    Geo::GDAL::FFI::OGR_GFld_SetNullable($$self, $nullable);
}

sub IsNullable {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_GFld_IsNullable($$self);
}

package Geo::GDAL::FFI::Feature;
use v5.10;
use strict;
use warnings;
use Carp;
use Encode qw(decode encode);
use FFI::Platypus::Buffer;

sub new {
    my ($class, $def) = @_;
    my $f = Geo::GDAL::FFI::OGR_F_Create($$def);
    return bless \$f, $class;
}

sub DESTROY {
    my $self = shift;
    Geo::GDAL::FFI::OGR_F_Destroy($$self);
}

sub GetFID {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_F_GetFID($$self);
}

sub SetFID {
    my ($self, $fid) = @_;
    $fid //= 0;
    Geo::GDAL::FFI::OGR_F_GetFID($$self, $fid);
}

sub GetDefn {
    my ($self) = @_;
    my $d = Geo::GDAL::FFI::OGR_F_GetDefnRef($$self);
    ++$immutable{$d};
    #say STDERR "$d immutable";
    return bless \$d, 'Geo::GDAL::FFI::FeatureDefn';
}

sub Clone {
    my ($self) = @_;
    my $f = Geo::GDAL::FFI::OGR_F_Clone($$self);
    return bless \$f, 'Geo::GDAL::FFI::Feature';
}

sub Equal {
    my ($self, $f) = @_;
    return Geo::GDAL::FFI::OGR_F_Equal($$self, $$f);
}

sub GetFieldCount {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_F_GetFieldCount($$self);
}

sub SetField {
    my ($self, $field_name, $value) = @_;
    my $i = GetFieldIndex($self, $field_name);
    $self->SetFieldNull($i) unless defined $value;
    my $t = $self->GetFieldDefn($i)->Type;
    $self->SetFieldInteger($i, $value) if $t eq 'Integer';
    $self->SetFieldInteger64($i, $value) if $t eq 'Integer64';
    $self->SetFieldDouble($i, $value) if $t eq 'Real';
    $self->SetFieldString($i, $value) if $t eq 'String';
    # Binary
    if ($t eq 'IntegerList') {
        $self->SetFieldIntegerList($i, $value);
    } elsif ($t eq 'Integer64List') {
        $self->SetFieldInteger64List($i, $value);
    } elsif ($t eq 'RealList') {
        $self->SetFieldRealList($i, $value);
    } elsif ($t eq 'StringList') {
        $self->SetFieldStringList($i, $value);
    } elsif ($t eq 'Date') {
        $self->SetFieldDateTimeEx($i, $value);
    } elsif ($t eq 'Time') {
        my @dt = (0, 0, 0, @$value);
        $self->SetFieldDateTimeEx($i, \@dt);
    } elsif ($t eq 'DateTime') {
        $self->SetFieldDateTimeEx($i, $value);
    }
}

sub GetField {
    my ($self, $field_name) = @_;
    my $i = GetFieldIndex($self, $field_name);
    return unless $self->IsFieldSetAndNotNull($i);
    my $t = $self->GetFieldDefn($i)->Type;
    return $self->GetFieldAsInteger($i) if $t eq 'Integer';
    return $self->GetFieldAsInteger64($i) if $t eq 'Integer64';
    return $self->GetFieldAsDouble($i) if $t eq 'Real';
    return $self->GetFieldAsString($i) if $t eq 'String';
    # Binary
    my $list;
    if ($t eq 'IntegerList') {
        $list = $self->GetFieldAsIntegerList($i);
    } elsif ($t eq 'Integer64List') {
        $list = $self->GetFieldAsInteger64List($i);
    } elsif ($t eq 'RealList') {
        $list = $self->GetFieldAsRealList($i);
    } elsif ($t eq 'StringList') {
        $list = $self->GetFieldAsStringList($i);
    } elsif ($t eq 'Date') {
        $list = $self->GetFieldAsDateTimeEx($i);
        $list = [@$list[0..2]];
    } elsif ($t eq 'Time') {
        $list = $self->GetFieldAsDateTimeEx($i);
        $list = [@$list[3..6]];
    } elsif ($t eq 'DateTime') {
        $list = $self->GetFieldAsDateTimeEx($i);
    }
    return wantarray ? @$list : $list;
}

sub GetFieldDefn {
    my ($self, $i) = @_;
    $i //= 0;
    my $d = Geo::GDAL::FFI::OGR_F_GetFieldDefnRef($$self, $i);
    croak unless $d;
    ++$immutable{$d};
    return bless \$d, 'Geo::GDAL::FFI::FieldDefn';
}

sub GetFieldIndex {
    my ($self, $name) = @_;
    $name //= '';
    return Geo::GDAL::FFI::OGR_F_GetFieldIndex($$self, $name);
}

sub IsFieldSet {
    my ($self, $i) = @_;
    $i //= 0;
    return Geo::GDAL::FFI::OGR_F_IsFieldSet($$self, $i);
}

sub UnsetField {
    my ($self, $i) = @_;
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_UnsetField($$self, $i);
}

sub IsFieldNull {
    my ($self, $i) = @_;
    $i //= 0;
    return Geo::GDAL::FFI::OGR_F_IsFieldNull($$self, $i);
}

sub IsFieldSetAndNotNull {
    my ($self, $i) = @_;
    $i //= 0;
    return Geo::GDAL::FFI::OGR_F_IsFieldSetAndNotNull($$self, $i);
}

sub SetFieldNull {
    my ($self, $i) = @_;
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldNull($$self, $i);
}

sub GetFieldAsInteger {
    my ($self, $i) = @_;
    $i //= 0;
    return Geo::GDAL::FFI::OGR_F_GetFieldAsInteger($$self, $i);
}

sub GetFieldAsInteger64 {
    my ($self, $i) = @_;
    $i //= 0;
    return Geo::GDAL::FFI::OGR_F_GetFieldAsInteger64($$self, $i);
}

sub GetFieldAsDouble {
    my ($self, $i) = @_;
    $i //= 0;
    return Geo::GDAL::FFI::OGR_F_GetFieldAsDouble($$self, $i);
}

sub GetFieldAsString {
    my ($self, $i, $encoding) = @_;
    $i //= 0;
    my $retval = Geo::GDAL::FFI::OGR_F_GetFieldAsString($$self, $i);
    $retval = decode $encoding => $retval if defined $encoding;
    return $retval;
}

sub GetFieldAsIntegerList {
    my ($self, $i) = @_;
    $i //= 0;
    my (@list, $len);
    my $p = Geo::GDAL::FFI::OGR_F_GetFieldAsIntegerList($$self, $i, \$len);
    @list = unpack("l[$len]", buffer_to_scalar($p, $len*4));
    return wantarray ? @list : \@list;
}

sub GetFieldAsInteger64List {
    my ($self, $i) = @_;
    $i //= 0;
    my (@list, $len);
    my $p = Geo::GDAL::FFI::OGR_F_GetFieldAsInteger64List($$self, $i, \$len);
    @list = unpack("q[$len]", buffer_to_scalar($p, $len*8));
    return wantarray ? @list : \@list;
}

sub GetFieldAsDoubleList {
    my ($self, $i) = @_;
    $i //= 0;
    my (@list, $len);
    my $p = Geo::GDAL::FFI::OGR_F_GetFieldAsDoubleList($$self, $i, \$len);
    @list = unpack("d[$len]", buffer_to_scalar($p, $len*8));
    return wantarray ? @list : \@list;
}

sub GetFieldAsStringList {
    my ($self, $i) = @_;
    $i //= 0;
    my $p = Geo::GDAL::FFI::OGR_F_GetFieldAsStringList($$self, $i);
    my @list;
    for my $i (0..Geo::GDAL::FFI::CSLCount($p)-1) {
        push @list, Geo::GDAL::FFI::CSLGetField($p, $i);
    }
    return wantarray ? @list : \@list;
}

sub GetFieldAsBinary {
    my ($self, $i) = @_;
    $i //= 0;
    return Geo::GDAL::FFI::OGR_F_GetFieldAsBinary($$self, $i);
}

sub GetFieldAsDateTime {
    my ($self, $i) = @_;
    $i //= 0;
    return Geo::GDAL::FFI::OGR_F_GetFieldAsDateTime($$self, $i);
}

sub GetFieldAsDateTimeEx {
    my ($self, $i) = @_;
    $i //= 0;
    my ($y, $m, $d, $h, $min, $s, $tz) = (0, 0, 0, 0, 0, 0.0, 0);
    Geo::GDAL::FFI::OGR_F_GetFieldAsDateTimeEx($$self, $i, \$y, \$m, \$d, \$h, \$min, \$s, \$tz);
    $s = sprintf("%.3f", $s) + 0;
    return wantarray ? ($y, $m, $d, $h, $min, $s, $tz) : [$y, $m, $d, $h, $min, $s, $tz];
}

sub SetFieldInteger {
    my ($self, $i, $value) = @_;
    $i //= 0;
    $value //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldInteger($$self, $i, $value);
}

sub SetFieldInteger64 {
    my ($self, $i, $value) = @_;
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldInteger64($$self, $i, $value);
}

sub SetFieldDouble {
    my ($self, $i, $value) = @_;
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldDouble($$self, $i, $value);
}

sub SetFieldString {
    my ($self, $i, $value) = @_;
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldString($$self, $i, $value);
}

sub SetFieldIntegerList {
    my ($self, $i, $list) = @_;
    $list //= [];
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldIntegerList($$self, $i, scalar @$list, $list);
}

sub SetFieldInteger64List {
    my ($self, $i, $list) = @_;
    $list //= [];
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldInteger64List($$self, $i, scalar @$list, $list);
}

sub SetFieldDoubleList {
    my ($self, $i, $list) = @_;
    $list //= [];
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldDoubleList($$self, $i, scalar @$list, $list);
}

sub SetFieldStringList {
    my ($self, $i, $list) = @_;
    $list //= [];
    $i //= 0;
    my $csl = 0;
    for my $s (@$list) {
        $csl = Geo::GDAL::FFI::CSLAddString($csl, $s);
    }
    Geo::GDAL::FFI::OGR_F_SetFieldStringList($$self, $i, $csl);
    Geo::GDAL::FFI::CSLDestroy($csl);
}

sub SetFieldDateTime {
    my ($self, $i, $value) = @_;
    $i //= 0;
    Geo::GDAL::FFI::OGR_F_SetFieldDateTime($$self, $i, $value);
}

sub SetFieldDateTimeEx {
    my ($self, $i, $dt) = @_;
    $dt //= [];
    $i //= 0;
    my @dt = @$dt;
    $dt[0] //= 2000; # year
    $dt[0] //= 1; # month 1-12
    $dt[0] //= 1; # day 1-31
    $dt[0] //= 0; # hour 0-23
    $dt[0] //= 0; # minute 0-59
    $dt[0] //= 0.0; # second with millisecond accuracy
    $dt[0] //= 100; # TZ
    Geo::GDAL::FFI::OGR_F_SetFieldDateTimeEx($$self, $i, @dt);
}

sub GetGeomFieldCount {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_F_GetGeomFieldCount($$self);
}

sub GetGeomFieldIndex {
    my ($self, $name) = @_;
    $name //= '';
    return $name if $name =~ /^\d+$/;
    return Geo::GDAL::FFI::OGR_F_GetGeomFieldIndex($$self, $name);
}

sub GetGeomFieldDefn {
    my ($self, $i) = @_;
    $i //= 0;
}

sub GetGeomField {
    my ($self, $name) = @_;
    my $i = defined $name ? $self->GetGeomFieldIndex($name) : 0;
    my $g = Geo::GDAL::FFI::OGR_F_GetGeomFieldRef($$self, $i);
    croak "No such field: $i" unless $g;
    $immutable{$g} = exists $immutable{$g} ? $immutable{$g} + 1 : 1;
    #say STDERR "$g immutable";
    return bless \$g, 'Geo::GDAL::FFI::Geometry';
}
*GetGeometry = *GetGeomField;

sub SetGeomField {
    my $self = shift;
    my $g = pop;
    my $name = shift;
    my $i = defined $name ? $self->GetGeomFieldIndex($name) : 0;
    $immutable{$$g} = exists $immutable{$$g} ? $immutable{$$g} + 1 : 1;
    #say STDERR "$$g immutable";
    Geo::GDAL::FFI::OGR_F_SetGeomFieldDirectly($$self, $i, $$g);
}
*SetGeometry = *SetGeomField;

package Geo::GDAL::FFI::Geometry;
use v5.10;
use strict;
use warnings;
use Carp;

sub new {
    my ($class, $type) = @_;
    $type //= 'Unknown';
    my $m = $type =~ /M$/;
    my $z = $type =~ /ZM$/ || $type =~ /25D$/;
    my $tmp = $geometry_types{$type};
    confess "Unknown constant: $type\n" unless defined $tmp;
    $type = $tmp;
    my $g = Geo::GDAL::FFI::OGR_G_CreateGeometry($type);
    Geo::GDAL::FFI::OGR_G_SetMeasured($g, 1) if $m;
    Geo::GDAL::FFI::OGR_G_Set3D($g, 1) if $z;
    return bless \$g, $class;
}

sub DESTROY {
    my ($self) = @_;
    if ($immutable{$$self}) {
        #say STDERR "forget $$self $immutable{$$self}";
        $immutable{$$self}--;
        delete $immutable{$$self} if $immutable{$$self} == 0;
    } else {
        #say STDERR "destroy $$self";
        Geo::GDAL::FFI::OGR_G_DestroyGeometry($$self);
    }
}

sub Type {
    my ($self, $mode) = @_;
    $mode //= '';
    my $t = Geo::GDAL::FFI::OGR_G_GetGeometryType($$self);
    Geo::GDAL::FFI::OGR_GT_Flatten($t) if $mode =~ /flatten/i;
    #say STDERR "type is $t";
    return $geometry_types_reverse{$t};
}

sub GetPointCount {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_G_GetPointCount($$self);
}

sub SetPoint {
    my $self = shift;
    croak "Can't modify an immutable object." if $immutable{$$self};
    my ($i, $x, $y, $z, $m);
    $i = shift if 
        Geo::GDAL::FFI::OGR_GT_Flatten(
            Geo::GDAL::FFI::OGR_G_GetGeometryType($$self)) != 1; # a point
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

sub GetCount {
    my ($self) = @_;
    return Geo::GDAL::FFI::OGR_G_GetGeometryCount($$self);
}

sub GetGeometry {
    my ($self, $i) = @_;
    my $g = Geo::GDAL::FFI::OGR_G_Clone(Geo::GDAL::FFI::OGR_G_GetGeometryRef($$self, $i));
    return bless \$g, 'Geo::GDAL::FFI::Geometry';
}

sub AddGeometry {
    my ($self, $g) = @_;
    croak "Can't modify an immutable object." if $immutable{$$self};
    my $e = Geo::GDAL::FFI::OGR_G_GetGeometryRef($$self, $$g);
    return unless $e;
    my $msg = join("\n", @errors);
    @errors = ();
    croak $msg;
}

sub RemoveGeometry {
    my ($self, $i) = @_;
    croak "Can't modify an immutable object." if $immutable{$$self};
    my $e = Geo::GDAL::FFI::OGR_G_GetGeometryRef($$self, $i, 1);
    return unless $e;
    my $msg = join("\n", @errors);
    @errors = ();
    croak $msg;
}

sub ImportFromWkt {
    my ($self, $wkt) = @_;
    croak "Can't modify an immutable object." if $immutable{$$self};
    $wkt //= '';
    Geo::GDAL::FFI::OGR_G_ImportFromWkt($$self, \$wkt);
    return $wkt;
}

sub ExportToWkt {
    my ($self, $mode) = @_;
    $mode //= '';
    my $wkt = '';
    if ($mode =~ /ISO/i) {
        Geo::GDAL::FFI::OGR_G_ExportToIsoWkt($$self, \$wkt);
    } else {
        Geo::GDAL::FFI::OGR_G_ExportToWkt($$self, \$wkt);
    }
    return $wkt;
}

1;
