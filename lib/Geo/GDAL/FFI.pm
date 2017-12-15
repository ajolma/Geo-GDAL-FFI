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

our @errors;

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
    $ffi->attach( 'OSRNewSpatialReference' => ['string'] => 'opaque' );
    $ffi->attach( 'OSRDestroySpatialReference' => ['opaque'] => 'void' );
    $ffi->attach( 'OSRRelease' => ['opaque'] => 'void' );
    $ffi->attach( 'OSRClone' => ['opaque'] => 'opaque' );
    $ffi->attach( 'OSRImportFromEPSG' => ['opaque', 'int'] => 'int' );
    
    $ffi->attach( 'GDALDatasetGetLayer' => ['opaque', 'int'] => 'opaque' );
    $ffi->attach( 'GDALDatasetCreateLayer' => ['opaque', 'string', 'opaque', 'int', 'opaque'] => 'opaque' );
    
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
    $ffi->attach( 'OGR_G_ExportToWkt' => ['opaque', 'string_pointer'] => 'int' );
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

our %access = (
    ReadOnly => 0,
    Update => 1
    );

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
    if (@errors) {
        my $msg = join("\n", @errors);
        @errors = ();
        croak $msg;
    }
    return bless \$ds, 'Geo::GDAL::FFI::Dataset';
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
    $width //= 256;
    $height //= 256;
    $bands //= 1;
    $dt //= 'Byte';
    my $tmp = $Geo::GDAL::FFI::data_types{$dt};
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

sub Width {
    my $self = shift;
    return Geo::GDAL::FFI::GDALGetRasterXSize($$self);
}

sub GetLayer {
    my ($self, $i) = @_;
    my $l = Geo::GDAL::FFI::GDALDatasetGetLayer($$self, $i);
    return bless \$l, 'Geo::GDAL::FFI::Layer';
}

sub CreateLayer {
    my ($self, $name, $sr, $gt, $options) = @_;
    my $tmp = $Geo::GDAL::FFI::Geometry::types{$gt};
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
    return $Geo::GDAL::FFI::Geometry::types_reverse{$t};
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

our %types = (
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

our %types_reverse = reverse %types;

sub new {
    my ($class, $type) = @_;
    my $tmp = $types{$type};
    confess "Unknown constant: $type\n" unless defined $tmp;
    $type = $tmp;
    my $g = Geo::GDAL::FFI::OGR_G_CreateGeometry($type);
    return bless \$g, $class;
}

sub DESTROY {
    my ($self) = @_;
    Geo::GDAL::FFI::OGR_G_DestroyGeometry($$self);
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
