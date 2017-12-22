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
    $ffi->attach('CPLPushErrorHandler' => ['CPLErrorHandler'] => 'void');

    $ffi->attach( 'CSLDestroy' => ['opaque'] => 'void');
    $ffi->attach( 'CSLAddString' => ['opaque', 'string'] => 'opaque');
    $ffi->attach( 'CSLCount' => ['opaque'] => 'int');
    $ffi->attach( 'CSLGetField' => ['opaque', 'int'] => 'string');

    $ffi->attach( 'GDALAllRegister' => [] => 'void');

    $ffi->attach( 'GDALGetMetadataDomainList' => ['opaque'] => 'opaque');
    $ffi->attach( 'GDALGetMetadata' => ['opaque', 'string'] => 'opaque');
    $ffi->attach( 'GDALSetMetadata' => ['opaque', 'opaque', 'string'] => 'int');
    $ffi->attach( 'GDALGetMetadataItem' => ['opaque', 'string', 'string'] => 'string');
    $ffi->attach( 'GDALSetMetadataItem' => ['opaque', 'string', 'string', 'string'] => 'int');

    $ffi->attach( 'GDALGetDescription' => ['opaque'] => 'string');
    $ffi->attach( 'GDALGetDriverCount' => [] => 'int');
    $ffi->attach( 'GDALGetDriver' => ['int'] => 'opaque');
    $ffi->attach( 'GDALGetDriverByName' => ['string'] => 'opaque');
    $ffi->attach( 'GDALCreate' => ['opaque', 'string', 'int', 'int', 'int', 'int', 'opaque'] => 'opaque');
    $ffi->attach( 'GDALVersionInfo' => ['string'] => 'string');
    $ffi->attach( 'GDALOpen' => ['string', 'int'] => 'opaque');
    $ffi->attach( 'GDALOpenEx' => ['string', 'unsigned int', 'opaque', 'opaque', 'opaque'] => 'opaque');
    $ffi->attach( 'GDALClose' => ['opaque'] => 'void');
    $ffi->attach( 'GDALGetRasterXSize' => ['opaque'] => 'int');
    $ffi->attach( 'GDALGetRasterYSize' => ['opaque'] => 'int');
    $ffi->attach( 'GDALGetRasterCount' => ['opaque'] => 'int');
    $ffi->attach( 'GDALGetRasterBand' => ['opaque', 'int'] => 'opaque');
    $ffi->attach( 'GDALFlushCache' => ['opaque'] => 'void');

    $ffi->attach( 'GDALGetProjectionRef' => ['opaque'] => 'string');
    $ffi->attach( 'GDALSetProjection' => ['opaque', 'string'] => 'int');
    $ffi->attach( 'GDALGetGeoTransform' => ['opaque', 'double[6]'] => 'int');
    $ffi->attach( 'GDALSetGeoTransform' => ['opaque', 'double[6]'] => 'int');

    $ffi->attach( 'GDALGetRasterDataType' => ['opaque'] => 'int');
    $ffi->attach( 'GDALGetRasterBandXSize' => ['opaque'] => 'int');
    $ffi->attach( 'GDALGetRasterBandYSize' => ['opaque'] => 'int');
    $ffi->attach( 'GDALGetRasterNoDataValue' => ['opaque', 'int*'] => 'double');
    $ffi->attach( 'GDALSetRasterNoDataValue' => ['opaque', 'double'] => 'int');
    $ffi->attach( 'GDALDeleteRasterNoDataValue' => ['opaque'] => 'int');
    $ffi->attach( 'GDALGetRasterColorTable' => ['opaque'] => 'opaque');
    $ffi->attach( 'GDALSetRasterColorTable' => ['opaque', 'opaque'] => 'int');
    $ffi->attach( 'GDALGetBlockSize' => ['opaque', 'int*', 'int*'] => 'void');
    $ffi->attach( 'GDALReadBlock' => ['opaque', 'int', 'int', 'string'] => 'int');
    $ffi->attach( 'GDALWriteBlock' => ['opaque', 'int', 'int', 'string'] => 'int');
    $ffi->attach( 'GDALRasterIO' => [qw/opaque int int int int int string int int int int int/] => 'int');

    $ffi->attach( 'GDALGetRasterColorInterpretation' => ['opaque'] => 'int');
    $ffi->attach( 'GDALSetRasterColorInterpretation' => ['opaque', 'int'] => 'int');
    $ffi->attach( 'GDALCreateColorTable' => ['int'] => 'opaque');
    $ffi->attach( 'GDALDestroyColorTable' => ['opaque'] => 'void');
    $ffi->attach( 'GDALCloneColorTable' => ['opaque'] => 'opaque');
    $ffi->attach( 'GDALGetPaletteInterpretation' => ['opaque'] => 'int');
    $ffi->attach( 'GDALGetColorEntryCount' => ['opaque'] => 'int');
    $ffi->attach( 'GDALGetColorEntry' => ['opaque', 'int'] => 'short[4]');
    $ffi->attach( 'GDALSetColorEntry' => ['opaque', 'int', 'short[4]'] => 'void');
    $ffi->attach( 'GDALCreateColorRamp' => ['opaque', 'int', 'short[4]', 'int', 'short[4]'] => 'void');

    $ffi->attach( 'OSRNewSpatialReference' => ['string'] => 'opaque');
    $ffi->attach( 'OSRDestroySpatialReference' => ['opaque'] => 'void');
    $ffi->attach( 'OSRRelease' => ['opaque'] => 'void');
    $ffi->attach( 'OSRClone' => ['opaque'] => 'opaque');
    $ffi->attach( 'OSRImportFromEPSG' => ['opaque', 'int'] => 'int');

    $ffi->attach( 'GDALDatasetGetLayer' => ['opaque', 'int'] => 'opaque');
    $ffi->attach( 'GDALDatasetCreateLayer' => ['opaque', 'string', 'opaque', 'int', 'opaque'] => 'opaque');
    $ffi->attach( 'GDALDatasetExecuteSQL' => ['opaque', 'string', 'opaque', 'string'] => 'opaque');
    $ffi->attach( 'GDALDatasetReleaseResultSet' => ['opaque', 'opaque'] => 'void');

    $ffi->attach( 'OGR_L_SyncToDisk' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_L_GetLayerDefn' => ['opaque'] => 'opaque');
    $ffi->attach( 'OGR_L_CreateField' => ['opaque', 'opaque', 'int'] => 'opaque');
    $ffi->attach( 'OGR_L_ResetReading' => ['opaque'] => 'void');
    $ffi->attach( 'OGR_L_GetNextFeature' => ['opaque'] => 'opaque');
    $ffi->attach( 'OGR_L_GetFeature' => [ 'opaque', 'sint64' ] => 'opaque');
    $ffi->attach( 'OGR_L_SetFeature' => [ 'opaque', 'opaque' ] => 'int');
    $ffi->attach( 'OGR_L_CreateFeature' => [ 'opaque', 'opaque' ] => 'int');
    $ffi->attach( 'OGR_L_DeleteFeature' => [ 'opaque', 'sint64' ] => 'int');
    $ffi->attach( 'OGR_L_GetSpatialRef' => [ 'opaque' ] => 'opaque');

    $ffi->attach( 'OGR_FD_Create' => ['string'] => 'opaque');
    $ffi->attach( 'OGR_FD_Release' => ['opaque'] => 'void');
    $ffi->attach( 'OGR_FD_GetFieldCount' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_FD_GetGeomFieldCount' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_FD_GetFieldDefn' => ['opaque', 'int'] => 'opaque');
    $ffi->attach( 'OGR_FD_GetGeomFieldDefn' => ['opaque', 'int'] => 'opaque');
    $ffi->attach( 'OGR_FD_GetFieldIndex' => ['opaque', 'string'] => 'int');
    $ffi->attach( 'OGR_FD_GetGeomFieldIndex' => ['opaque', 'string'] => 'int');
    $ffi->attach( 'OGR_FD_AddFieldDefn' => ['opaque', 'opaque'] => 'void');
    $ffi->attach( 'OGR_FD_AddGeomFieldDefn' => ['opaque', 'opaque'] => 'void');
    $ffi->attach( 'OGR_FD_DeleteFieldDefn' => ['opaque', 'int'] => 'int');
    $ffi->attach( 'OGR_FD_DeleteGeomFieldDefn' => ['opaque', 'int'] => 'int');
    $ffi->attach( 'OGR_FD_GetGeomType' => ['opaque'] => 'unsigned int');
    $ffi->attach( 'OGR_FD_SetGeomType' => ['opaque', 'unsigned int'] => 'void');
    $ffi->attach( 'OGR_FD_IsGeometryIgnored' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_FD_SetGeometryIgnored' => ['opaque', 'int'] => 'void');
    $ffi->attach( 'OGR_FD_IsStyleIgnored' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_FD_SetStyleIgnored' => ['opaque', 'int'] => 'void');

    $ffi->attach( 'OGR_F_Create' => ['opaque'] => 'opaque');
    $ffi->attach( 'OGR_F_Destroy' => ['opaque'] => 'void');
    $ffi->attach( 'OGR_F_GetDefnRef' => ['opaque'] => 'opaque');
    $ffi->attach( 'OGR_F_Clone' => ['opaque'] => 'opaque');
    $ffi->attach( 'OGR_F_Equal' => ['opaque', 'opaque'] => 'int');
    $ffi->attach( 'OGR_F_GetFieldCount' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_F_GetFieldDefnRef' => ['opaque', 'int'] => 'opaque');
    $ffi->attach( 'OGR_F_GetFieldIndex' => ['opaque', 'string'] => 'int');
    $ffi->attach( 'OGR_F_IsFieldSet' => ['opaque', 'int'] => 'int');
    $ffi->attach( 'OGR_F_UnsetField' => ['opaque', 'int'] => 'void');
    $ffi->attach( 'OGR_F_IsFieldNull' => ['opaque', 'int'] => 'int');
    $ffi->attach( 'OGR_F_IsFieldSetAndNotNull' => ['opaque', 'int'] => 'int');
    $ffi->attach( 'OGR_F_SetFieldNull' => ['opaque', 'int'] => 'void');
    $ffi->attach( 'OGR_F_GetFieldAsInteger' => ['opaque', 'int'] => 'int');
    $ffi->attach( 'OGR_F_GetFieldAsInteger64' => ['opaque', 'int'] => 'sint64');
    $ffi->attach( 'OGR_F_GetFieldAsDouble' => ['opaque', 'int'] => 'double');
    $ffi->attach( 'OGR_F_GetFieldAsString' => ['opaque', 'int'] => 'string');
    $ffi->attach( 'OGR_F_GetFieldAsIntegerList' => ['opaque', 'int', 'int*'] => 'pointer');
    $ffi->attach( 'OGR_F_GetFieldAsInteger64List' => ['opaque', 'int', 'int*'] => 'pointer');
    $ffi->attach( 'OGR_F_GetFieldAsDoubleList' => ['opaque', 'int', 'int*'] => 'pointer');
    $ffi->attach( 'OGR_F_GetFieldAsStringList' => ['opaque', 'int'] => 'opaque');
    $ffi->attach( 'OGR_F_GetFieldAsBinary' => ['opaque', 'int', 'int*'] => 'char*');
    $ffi->attach( 'OGR_F_GetFieldAsDateTime' => [qw/opaque int int* int* int* int* int* int* int*/]  => 'int');
    $ffi->attach( 'OGR_F_GetFieldAsDateTimeEx' => [qw/opaque int int* int* int* int* int* float* int*/] => 'int');
    $ffi->attach( 'OGR_F_SetFieldInteger' => ['opaque', 'int', 'int'] => 'void');
    $ffi->attach( 'OGR_F_SetFieldInteger64' => ['opaque', 'int', 'sint64'] => 'void');
    $ffi->attach( 'OGR_F_SetFieldDouble' => [qw/opaque int double/] => 'void');
    $ffi->attach( 'OGR_F_SetFieldString' => [qw/opaque int string/] => 'void');
    $ffi->attach( 'OGR_F_SetFieldIntegerList' => [qw/opaque int int sint32[]/] => 'void');
    $ffi->attach( 'OGR_F_SetFieldInteger64List' => ['opaque', 'int', 'int', 'sint64[]'] => 'void');
    $ffi->attach( 'OGR_F_SetFieldDoubleList' => ['opaque', 'int', 'int', 'double[]'] => 'void');
    $ffi->attach( 'OGR_F_SetFieldStringList' => ['opaque', 'int', 'opaque'] => 'void');
    $ffi->attach( 'OGR_F_SetFieldBinary' => [qw/opaque int int char*/] => 'void');
    $ffi->attach( 'OGR_F_SetFieldDateTime' => [qw/opaque int int int int int int int int/] => 'void');
    $ffi->attach( 'OGR_F_SetFieldDateTimeEx' => [qw/opaque int int int int int int float int/] => 'void');
    $ffi->attach( 'OGR_F_GetGeomFieldCount' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_F_GetGeomFieldDefnRef' => ['opaque', 'int'] => 'opaque');
    $ffi->attach( 'OGR_F_GetGeomFieldIndex' => ['opaque', 'string'] => 'int');
    $ffi->attach( 'OGR_F_GetGeomFieldRef' => ['opaque', 'int'] => 'opaque');
    $ffi->attach( 'OGR_F_SetGeomFieldDirectly' => ['opaque', 'int', 'opaque'] => 'int');
    $ffi->attach( 'OGR_F_SetGeomField' => ['opaque', 'int', 'opaque'] => 'int');
    $ffi->attach( 'OGR_F_GetFID' => ['opaque'] => 'sint64');
    $ffi->attach( 'OGR_F_SetFID' => ['opaque', 'long long'] => 'int');    
    
    $ffi->attach( 'OGR_Fld_Create' => ['string', 'int'] => 'opaque');
    $ffi->attach( 'OGR_Fld_Destroy' => ['opaque'] => 'void');
    $ffi->attach( 'OGR_Fld_SetName' => ['opaque', 'string'] => 'void');
    $ffi->attach( 'OGR_Fld_GetNameRef' => ['opaque'] => 'string');
    $ffi->attach( 'OGR_Fld_GetType' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_Fld_SetType' => ['opaque', 'int'] => 'void');
    $ffi->attach( 'OGR_Fld_GetSubType' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_Fld_SetSubType' => ['opaque', 'int'] => 'void');
    $ffi->attach( 'OGR_Fld_GetJustify' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_Fld_SetJustify' => ['opaque', 'int'] => 'void');
    $ffi->attach( 'OGR_Fld_GetWidth' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_Fld_SetWidth' => ['opaque', 'int'] => 'void');
    $ffi->attach( 'OGR_Fld_GetPrecision' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_Fld_SetPrecision' => ['opaque', 'int'] => 'void');
    $ffi->attach( 'OGR_Fld_IsIgnored' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_Fld_SetIgnored' => ['opaque', 'int'] => 'void');
    $ffi->attach( 'OGR_Fld_IsNullable' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_Fld_SetNullable' => ['opaque', 'int'] => 'void');

    $ffi->attach( 'OGR_GFld_Create' => ['string', 'int'] => 'opaque');
    $ffi->attach( 'OGR_GFld_Destroy' => ['opaque'] => 'void');
    $ffi->attach( 'OGR_GFld_SetName' => ['opaque', 'string'] => 'void');
    $ffi->attach( 'OGR_GFld_GetNameRef' => ['opaque'] => 'string');
    $ffi->attach( 'OGR_GFld_GetType' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_GFld_SetType' => ['opaque', 'int'] => 'void');
    $ffi->attach( 'OGR_GFld_GetSpatialRef' => ['opaque'] => 'opaque');
    $ffi->attach( 'OGR_GFld_SetSpatialRef' => ['opaque', 'opaque'] => 'void');
    $ffi->attach( 'OGR_GFld_IsNullable' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_GFld_SetNullable' => ['opaque', 'int'] => 'void');
    $ffi->attach( 'OGR_GFld_IsIgnored' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_GFld_SetIgnored' => ['opaque', 'int'] => 'void');

    $ffi->attach( 'OGR_G_CreateGeometry' => ['unsigned int'] => 'opaque');
    $ffi->attach( 'OGR_G_DestroyGeometry' => ['opaque'] => 'void');
    $ffi->attach( 'OGR_G_Clone' => ['opaque'] => 'opaque');
    $ffi->attach( 'OGR_G_GetGeometryType' => ['opaque'] => 'unsigned int');
    $ffi->attach( 'OGR_G_GetPointCount' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_G_Is3D' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_G_IsMeasured' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_G_Set3D' => ['opaque', 'int'] => 'void');
    $ffi->attach( 'OGR_G_SetMeasured' => ['opaque', 'int'] => 'void');
    $ffi->attach( 'OGR_G_GetPointZM' => [qw/opaque int double* double* double* double*/] => 'void');
    $ffi->attach( 'OGR_G_SetPointZM' => [qw/opaque int double double double double/] => 'void');
    $ffi->attach( 'OGR_G_SetPointM' => [qw/opaque int double double double/] => 'void');
    $ffi->attach( 'OGR_G_SetPoint' => [qw/opaque int double double double/] => 'void');
    $ffi->attach( 'OGR_G_SetPoint_2D' => [qw/opaque int double double/] => 'void');

    $ffi->attach( 'OGR_G_GetGeometryCount' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_G_GetGeometryRef' => ['opaque', 'int'] => 'opaque');
    $ffi->attach( 'OGR_G_AddGeometry' => ['opaque', 'opaque'] => 'int');
    $ffi->attach( 'OGR_G_RemoveGeometry' => ['opaque', 'int', 'int'] => 'int');

    $ffi->attach( 'OGR_G_ImportFromWkt' => ['opaque', 'string_pointer'] => 'int');
    $ffi->attach( 'OGR_G_ExportToWkt' => ['opaque', 'string_pointer'] => 'int');
    $ffi->attach( 'OGR_G_ExportToIsoWkt' => ['opaque', 'string_pointer'] => 'int');
    $ffi->attach( 'OGR_G_TransformTo' => ['opaque', 'opaque'] => 'int');

    $ffi->attach( 'OGR_G_Segmentize' => ['opaque', 'double'] => 'void');
    $ffi->attach( 'OGR_G_Intersects' => ['opaque', 'opaque'] => 'int');
    $ffi->attach( 'OGR_G_Equals' => ['opaque', 'opaque'] => 'int');
    $ffi->attach( 'OGR_G_Disjoint' => ['opaque', 'opaque'] => 'int');
    $ffi->attach( 'OGR_G_Touches' => ['opaque', 'opaque'] => 'int');
    $ffi->attach( 'OGR_G_Crosses' => ['opaque', 'opaque'] => 'int');
    $ffi->attach( 'OGR_G_Within' => ['opaque', 'opaque'] => 'int');
    $ffi->attach( 'OGR_G_Contains' => ['opaque', 'opaque'] => 'int');
    $ffi->attach( 'OGR_G_Overlaps' => ['opaque', 'opaque'] => 'int');

    $ffi->attach( 'OGR_G_Boundary' => ['opaque'] => 'opaque');
    $ffi->attach( 'OGR_G_ConvexHull' => ['opaque'] => 'opaque');
    $ffi->attach( 'OGR_G_Buffer' => ['opaque', 'double', 'int'] => 'opaque');
    $ffi->attach( 'OGR_G_Intersection' => ['opaque', 'opaque'] => 'opaque');
    $ffi->attach( 'OGR_G_Union' => ['opaque', 'opaque'] => 'opaque');
    $ffi->attach( 'OGR_G_UnionCascaded' => ['opaque'] => 'opaque');
    $ffi->attach( 'OGR_G_PointOnSurface' => ['opaque'] => 'opaque');

    $ffi->attach( 'OGR_G_Difference' => ['opaque', 'opaque'] => 'opaque');
    $ffi->attach( 'OGR_G_SymDifference' => ['opaque', 'opaque'] => 'opaque');
    $ffi->attach( 'OGR_G_Distance' => ['opaque', 'opaque'] => 'double');
    $ffi->attach( 'OGR_G_Distance3D' => ['opaque', 'opaque'] => 'double');
    $ffi->attach( 'OGR_G_Length' => ['opaque'] => 'double');
    $ffi->attach( 'OGR_G_Area' => ['opaque'] => 'double');
    $ffi->attach( 'OGR_G_Centroid' => ['opaque', 'opaque'] => 'int');
    $ffi->attach( 'OGR_G_Value' => ['opaque', 'double'] => 'opaque');

    $ffi->attach( 'OGR_G_Empty' => ['opaque'] => 'void');
    $ffi->attach( 'OGR_G_IsEmpty' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_G_IsValid' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_G_IsSimple' => ['opaque'] => 'int');
    $ffi->attach( 'OGR_G_IsRing' => ['opaque'] => 'int');

    $ffi->attach( 'OGR_GT_Flatten' => ['unsigned int'] => 'unsigned int');

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
