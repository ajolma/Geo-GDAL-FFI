package Geo::GDAL::FFI::Dataset;
use v5.10;
use strict;
use warnings;
use Carp;
use base 'Geo::GDAL::FFI::Object';
use Scalar::Util qw /blessed looks_like_number/;

our $VERSION = '0.15';

sub DESTROY {
    my $self = shift;
    $self->FlushCache;
    #say STDERR "DESTROY $self";
    Geo::GDAL::FFI::GDALClose($$self);
}

sub GetName {
    my $self = shift;
    return $self->GetDescription;
}

sub FlushCache {
    my $self = shift;
    Geo::GDAL::FFI::GDALFlushCache($$self);
}

sub GetDriver {
    my $self = shift;
    my $dr = Geo::GDAL::FFI::GDALGetDatasetDriver($$self);
    return bless \$dr, 'Geo::GDAL::FFI::Driver';
}

sub GetWidth {
    my $self = shift;
    return Geo::GDAL::FFI::GDALGetRasterXSize($$self);
}

sub GetHeight {
    my $self = shift;
    return Geo::GDAL::FFI::GDALGetRasterYSize($$self);
}

sub GetSize {
    my $self = shift;
    return (
        Geo::GDAL::FFI::GDALGetRasterXSize($$self),
        Geo::GDAL::FFI::GDALGetRasterYSize($$self)
        );
}

sub GetProjectionString {
    my ($self) = @_;
    return Geo::GDAL::FFI::GDALGetProjectionRef($$self);
}

sub SetProjectionString {
    my ($self, $proj) = @_;
    my $e = Geo::GDAL::FFI::GDALSetProjection($$self, $proj);
    if ($e != 0) {
        confess Geo::GDAL::FFI::error_msg();
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

sub GetBand {
    my ($self, $i) = @_;
    $i //= 1;
    my $b = Geo::GDAL::FFI::GDALGetRasterBand($$self, $i);
    Geo::GDAL::FFI::_register_parent_ref ($b, $self);
    return bless \$b, 'Geo::GDAL::FFI::Band';
}

sub GetBands {
    my $self = shift;
    my @bands;
    for my $i (1..Geo::GDAL::FFI::GDALGetRasterCount($$self)) {
        push @bands, $self->GetBand($i);
    }
    return @bands;
}

sub GetLayerCount {
    my ($self) = @_;
    return Geo::GDAL::FFI::GDALDatasetGetLayerCount($$self);
}

sub GetLayerNames {
    my ($self) = @_;

    my @layernames;
    for my $i (0 .. $self->GetLayerCount - 1) {
        push @layernames, $self->GetLayerByIndex($i)->GetName;
    }
    return wantarray ? @layernames : \@layernames;
}

sub GetLayerByName {
    my ($self, $name) = @_;
    confess "Name arg is undefined" if !defined $name;
    my $layer = Geo::GDAL::FFI::GDALDatasetGetLayerByName($$self, $name);
    if (!$layer) {
        my $msg = Geo::GDAL::FFI::error_msg()
            // "Could not access layer $name in data set.";
        confess $msg if $msg;
    }
    Geo::GDAL::FFI::_register_parent_ref ($layer, $self);
    return bless \$layer, 'Geo::GDAL::FFI::Layer';
}

sub GetLayerByIndex {
    my ($self, $index) = @_;
    $index //= 0;
    croak "Index $index is not numeric" if !looks_like_number $index;
    my $layer = Geo::GDAL::FFI::GDALDatasetGetLayer($$self, int $index);
    if (!$layer) {
        my $msg = Geo::GDAL::FFI::error_msg()
            // "Could not access layer $index in data set.";
        confess $msg if $msg;
    }
    Geo::GDAL::FFI::_register_parent_ref ($layer, $self);
    return bless \$layer, 'Geo::GDAL::FFI::Layer';
}


sub GetLayer {
    my ($self, $i) = @_;
    $i //= 0;
    my $l = Geo::GDAL::FFI::isint($i)
      ? Geo::GDAL::FFI::GDALDatasetGetLayer($$self, $i)
      : Geo::GDAL::FFI::GDALDatasetGetLayerByName($$self, $i);
    unless ($l) {
        my $msg = Geo::GDAL::FFI::error_msg()
          // "Could not access layer $i in data set.";
        confess $msg if $msg;
    }
    Geo::GDAL::FFI::_register_parent_ref ($l, $self);
    return bless \$l, 'Geo::GDAL::FFI::Layer';
}

sub CreateLayer {
    my ($self, $args) = @_;
    $args //= {};
    my $name = $args->{Name} // '';
    my ($gt, $sr);
    if ($args->{GeometryFields}) {
        $gt = $Geo::GDAL::FFI::geometry_types{None};
    } else {
        $gt = $args->{GeometryType} // 'Unknown';
        $gt = $Geo::GDAL::FFI::geometry_types{$gt};
        confess "Unknown geometry type: '$args->{GeometryType}'." unless defined $gt;
        $sr = Geo::GDAL::FFI::OSRClone(${$args->{SpatialReference}}) if $args->{SpatialReference};
    }
    my $o = 0;
    if ($args->{Options}) {
        for my $key (keys %{$args->{Options}}) {
            $o = Geo::GDAL::FFI::CSLAddString($o, "$key=$args->{Options}->{$key}");
        }
    }
    my $l = Geo::GDAL::FFI::GDALDatasetCreateLayer($$self, $name, $sr, $gt, $o);
    Geo::GDAL::FFI::CSLDestroy($o);
    Geo::GDAL::FFI::OSRRelease($sr) if $sr;
    my $msg = Geo::GDAL::FFI::error_msg();
    confess $msg if $msg;
    Geo::GDAL::FFI::_register_parent_ref ($l, $self);
    my $layer = bless \$l, 'Geo::GDAL::FFI::Layer';
    if ($args->{Fields}) {
        for my $f (@{$args->{Fields}}) {
            $layer->CreateField($f);
        }
    }
    if ($args->{GeometryFields}) {
        for my $f (@{$args->{GeometryFields}}) {
            $layer->CreateGeomField($f);
        }
    }
    return $layer;
}

sub CopyLayer {
    my ($self, $layer, $name, $options) = @_;
    $name //= '';
    my $o = 0;
    for my $key (keys %$options) {
        $o = Geo::GDAL::FFI::CSLAddString($o, "$key=$options->{$key}");
    }
    my $l = Geo::GDAL::FFI::GDALDatasetCopyLayer($$self, $$layer, $name, $o);
    Geo::GDAL::FFI::CSLDestroy($o);
    unless ($l) {
        my $msg = Geo::GDAL::FFI::error_msg() // "GDALDatasetCopyLayer failed.";
        confess $msg if $msg;
    }
    Geo::GDAL::FFI::_register_parent_ref ($l, $self);
    return bless \$l, 'Geo::GDAL::FFI::Layer';
}


sub ExecuteSQL {
    my ($self, $sql, $filter, $dialect) = @_;
        
    my $lyr = Geo::GDAL::FFI::GDALDatasetExecuteSQL(
        $$self, $sql, $$filter, $dialect
    );
    
    if ($lyr) {
        if (defined wantarray) {
            Geo::GDAL::FFI::_register_parent_ref ($lyr, $self);
            return bless \$lyr, 'Geo::GDAL::FFI::Layer::ResultSet';
        }
        else {
            Geo::GDAL::FFI::GDALDatasetReleaseResultSet ($lyr, $$self);            
        }
    }

    #  This is perhaps unnecessary, but ensures
    #  internal  details do not leak if spatial
    #  index is built in non-void context.
    return undef;
}


## utilities

sub new_options {
    my ($constructor, $options) = @_;
    $options //= [];
    confess "The options must be a reference to an array." unless ref $options;
    my $csl = 0;
    for my $s (@$options) {
        $csl = Geo::GDAL::FFI::CSLAddString($csl, $s);
    }
    $options = $constructor->($csl, 0);
    Geo::GDAL::FFI::CSLDestroy($csl);
    return $options;
}

sub GetInfo {
    my ($self, $options) = @_;
    $options = new_options(\&Geo::GDAL::FFI::GDALInfoOptionsNew, $options);
    my $info = Geo::GDAL::FFI::GDALInfo($$self, $options);
    Geo::GDAL::FFI::GDALInfoOptionsFree($options);
    return $info;
}
*Info = *GetInfo;

sub set_progress {
    my ($options, $args, $setter) = @_;
    return unless $args->{Progress};
    my $ffi = FFI::Platypus->new;
    $setter->($options, $ffi->closure($args->{Progress}), $args->{ProgressData});
}

sub Translate {
    my ($self, $path, $options, $progress, $data) = @_;
    $options = new_options(\&Geo::GDAL::FFI::GDALTranslateOptionsNew, $options);
    my $args = {Progress => $progress, ProgressData => $data};
    set_progress($options, $args, \&Geo::GDAL::FFI::GDALTranslateOptionsSetProgress);
    my $e = 0;
    my $ds = Geo::GDAL::FFI::GDALTranslate($path, $$self, $options, \$e);
    Geo::GDAL::FFI::GDALTranslateOptionsFree($options);
    return bless \$ds, 'Geo::GDAL::FFI::Dataset' if $ds && ($e == 0);
    my $msg = Geo::GDAL::FFI::error_msg() // 'Translate failed.';
    confess $msg;
}

sub destination {
    my ($dst) = @_;
    confess "Destination missing." unless $dst;
    my $path;
    if (ref $dst) {
        $dst = $$dst;
    } else {
        $path = $dst;
        undef $dst;
    }
    return ($path, $dst);
}

sub dataset_input {
    my ($self, $input) = @_;
    $input //= [];
    confess "The input must be a reference to an array of datasets." unless ref ($input) =~ /ARRAY/;
    my @datasets = ($$self);
    for my $ds (@$input) {
        push @datasets, $$ds;
    }
    return \@datasets;
}

sub Warp {
    my ($self, $args) = @_;
    
    my ($path, $dst) = destination($args->{Destination});
    confess "Destination object should not be passed for non-void context"
      if defined wantarray && blessed $dst;

    my $input = $self->dataset_input($args->{Input});

    my $options = new_options(\&Geo::GDAL::FFI::GDALWarpAppOptionsNew, $args->{Options});
    set_progress($options, $args, \&Geo::GDAL::FFI::GDALWarpAppOptionsSetProgress);
    
    my $e = 0;
    my $result;
    if (blessed($dst)) {
        Geo::GDAL::FFI::GDALWarp($path, $dst, scalar @$input, $input, $options, \$e);
    } else {
        $result = Geo::GDAL::FFI::GDALWarp($path, undef, scalar @$input, $input, $options, \$e);
    }
    Geo::GDAL::FFI::GDALWarpAppOptionsFree($options);
    if (defined $result) {
        confess Geo::GDAL::FFI::error_msg() // 'Warp failed.' if !$result || $e != 0;
        return bless \$result, 'Geo::GDAL::FFI::Dataset';
    }
}

sub VectorTranslate {
    my ($self, $args) = @_;
    my ($path, $dst) = destination($args->{Destination});
    confess "Destination object should not be passed for non-void context"
      if defined wantarray && blessed $dst;

    my $input = $self->dataset_input($args->{Input});

    my $options = new_options(\&Geo::GDAL::FFI::GDALVectorTranslateOptionsNew, $args->{Options});
    set_progress($options, $args, \&Geo::GDAL::FFI::GDALVectorTranslateOptionsSetProgress);
    
    my $e = 0;
    my $result;
    if (blessed($dst)) {
        Geo::GDAL::FFI::GDALVectorTranslate(undef, $$dst, scalar @$input, $input, $options, \$e);
    }
    else {
        my $result = Geo::GDAL::FFI::GDALVectorTranslate($path, undef, scalar @$input, $input, $options, \$e);
    }
    Geo::GDAL::FFI::GDALVectorTranslateOptionsFree($options);
    confess Geo::GDAL::FFI::error_msg() // 'VectorTranslate failed.' if $e != 0;
    if (defined $result) {
        return bless \$result, 'Geo::GDAL::FFI::Dataset';
    }
}

sub DEMProcessing {
    my ($self, $path, $args) = @_;
    my $processing = $args->{Processing} // 'hillshade';
    my $colorfile = $args->{ColorFilename};
    my $options = new_options(\&Geo::GDAL::FFI::GDALDEMProcessingOptionsNew, $args->{Options});
    set_progress($options, $args, \&Geo::GDAL::FFI::GDALDEMProcessingOptionsSetProgress);
    my $e = 0;
    my $result = Geo::GDAL::FFI::GDALDEMProcessing($path, $$self, $processing, $colorfile, $options, \$e);
    Geo::GDAL::FFI::GDALDEMProcessingOptionsFree($options);
    confess Geo::GDAL::FFI::error_msg() // 'DEMProcessing failed.' if !$result || $e != 0;
    return bless \$result, 'Geo::GDAL::FFI::Dataset';
}

sub NearBlack {
    my ($self, $args) = @_;
    
    my ($path, $dst) = destination($args->{Destination});
    confess "Destination object should not be passed for non-void context"
      if defined wantarray && blessed $dst;

    my $input = $self->dataset_input($args->{Input});

    my $options = new_options(\&Geo::GDAL::FFI::GDALNearblackOptionsNew, $args->{Options});
    set_progress($options, $args, \&Geo::GDAL::FFI::GDALNearblackOptionsSetProgress);
    
    my $e = 0;
    my $result;
    if (blessed($dst)) {
        Geo::GDAL::FFI::GDALNearblack($path, $$dst, $$self, $options, \$e);
    } else {
        $result = Geo::GDAL::FFI::GDALNearblack($path, undef, $$self, $options, \$e);
    }
    Geo::GDAL::FFI::GDALNearblackOptionsFree($options);

    confess Geo::GDAL::FFI::error_msg() // 'NearBlack failed.' if $e != 0;
    if (defined $result) {
        return bless \$result, 'Geo::GDAL::FFI::Dataset';
    }

}

sub Grid {
    my ($self, $path, $options, $progress, $data) = @_;
    $options = new_options(\&Geo::GDAL::FFI::GDALGridOptionsNew, $options);
    my $args = {Progress => $progress, ProgressData => $data};
    set_progress($options, $args, \&Geo::GDAL::FFI::GDALGridOptionsSetProgress);
    my $e = 0;
    my $result = Geo::GDAL::FFI::GDALGrid($path, $$self, $options, \$e);
    Geo::GDAL::FFI::GDALGridOptionsFree($options);
    confess Geo::GDAL::FFI::error_msg() // 'Grid failed.' if !$result || $e != 0;
    return bless \$result, 'Geo::GDAL::FFI::Dataset';
}

sub Rasterize {
    my ($self, $args) = @_;
    
    my $dst = $args->{Destination};
    confess "Destination argument should not be passed for non-void context"
      if defined wantarray && blessed $dst;

    my $options = new_options(\&Geo::GDAL::FFI::GDALRasterizeOptionsNew, $args->{Options});
    set_progress($options, $args, \&Geo::GDAL::FFI::GDALRasterizeOptionsSetProgress);
    
    my $e = 0;
    my $result;
    if (blessed($dst)) {
        Geo::GDAL::FFI::GDALRasterize(undef, $$dst, $$self, $options, \$e);
    } else {
        $result = Geo::GDAL::FFI::GDALRasterize($dst, undef, $$self, $options, \$e);
    }
    Geo::GDAL::FFI::GDALRasterizeOptionsFree($options);
    
    confess Geo::GDAL::FFI::error_msg() // 'Rasterize failed.' if $e != 0;
    if (defined $result) {
        return bless \$result, 'Geo::GDAL::FFI::Dataset';
    }
}

sub BuildVRT {
    my ($self, $path, $args) = @_;
    my $input = $self->dataset_input($args->{Input});
    my $options = new_options(\&Geo::GDAL::FFI::GDALBuildVRTOptionsNew, $args->{Options});
    set_progress($options, $args, \&Geo::GDAL::FFI::GDALBuildVRTOptionsSetProgress);
    my $e = 0;
    my $result = Geo::GDAL::FFI::GDALBuildVRT($path, scalar @$input, $input, 0, $options, \$e);
    Geo::GDAL::FFI::GDALBuildVRTOptionsFree($options);
    confess Geo::GDAL::FFI::error_msg() // 'BuildVRT failed.' if !$result || $e != 0;
    return bless \$result, 'Geo::GDAL::FFI::Dataset';
}

1;

{
    #  dummy class for result sets from ExecuteSQL
    #  allows specialised destroy method
    package Geo::GDAL::FFI::Layer::ResultSet;
    use base qw /Geo::GDAL::FFI::Layer/;
    
    sub DESTROY {
        my ($self) = @_;
        my $parent = Geo::GDAL::FFI::_get_parent_ref ($$self);
        Geo::GDAL::FFI::GDALDatasetReleaseResultSet ($$parent, $$self);
        Geo::GDAL::FFI::_deregister_parent_ref ($$self);
    }
    
    1;
}



=pod

=encoding UTF-8

=head1 NAME

Geo::GDAL::FFI::Dataset - A GDAL dataset

=head1 SYNOPSIS

=head1 DESCRIPTION

A collection of raster bands or vector layers. Obtain a dataset object
by opening it with the Open method of Geo::GDAL::FFI object or by
creating it with the Create method of a Driver object.

=head1 METHODS

=head2 GetDriver

 my $driver = $dataset->GetDriver;

=head2 GetWidth

 my $w = $dataset->GetWidth;

=head2 GetHeight

 my $h = $dataset->GetHeight;

=head2 GetSize

 my @size = $dataset->GetSize;

Returns the size (width, height) of the bands of this raster dataset.

=head2 GetBand

 my $band = $dataset->GetBand($i);

Get the ith (by default the first) band of a raster dataset.

=head2 GetBands

 my @bands = $dataset->GetBands;

Returns a list of Band objects representing the bands of this raster
dataset.

=head2 CreateLayer

 my $layer = $dataset->CreateLayer({Name => 'layer', ...});

Create a new vector layer into this vector dataset.

Named arguments are the following.

=over 4

=item C<Name>

Optional, string, default is ''.

=item C<GeometryType>

Optional, default is 'Unknown', the type of the first geometry field;
note: if type is 'None', the layer schema does not initially contain
any geometry fields.

=item C<SpatialReference>

Optional, a SpatialReference object, the spatial reference for the
first geometry field.

=item C<Options>

Optional, driver specific options in an anonymous hash.

=item C<Fields>

Optional, a reference to an array of Field objects or schemas, the
fields to create into the layer.

=item C<GeometryFields>

Optional, a reference to an array of GeometryField objects or schemas,
the geometry fields to create into the layer; note that if this
argument is defined then the arguments GeometryType and
SpatialReference are ignored.

=back

=head2 GetLayerCount

 my $count = $dataset->GetLayerCount();


=head2 GetLayer

 my $layer = $dataset->GetLayer($name);

If $name is strictly an integer, then returns the (name-1)th layer in
the dataset, otherwise returns the layer whose name is $name. Without
arguments returns the first layer.

If there is any risk of ambiguity, e.g. the fourth layer is called "2",
then L</GetLayerByName> or L</GetLayerByIndex> can be used.

=head2 GetLayerByName

 my $layer = $dataset->GetLayerByName($name);

Returns the layer whose name is C<$name>. Without arguments returns the first layer.

=head2 GetLayerByIndex

 my $layer = $dataset->GetLayerByIndex($i);

Returns the ith layer in the dataset. Without arguments returns the first layer.
Throws an exception on non-numeric input and integerises any non-integer numbers.

=head2 GetLayerNames

 my @array = $dataset->GetLayerNames();
 my $aref  = $dataset->GetLayerNames();

Returns an array of the layer names, in index order.
Returns an array ref in scalar context.


=head2 CopyLayer

 my $copy = $dataset->CopyLayer($layer, $name, {DST_SRSWKT => 'WKT of a SRS', ...});

Copies the given layer into this dataset using the name $name and
returns the new layer. The options hash is mostly driver specific.

=head2 ExecuteSQL
 $dataset->ExecuteSQL ($sql, $filter, $dialect);

 #  build a spatial index
 $dataset->ExecuteSQL (qq{CREATE SPATIAL INDEX ON "$some_layer_name"});
 
 #  filter a data set using the SQLite dialect and a second geometry
 my $filtered = $dataset->ExecuteSQL (
   qq{SELECT "$fld1", "$fld2" FROM "$some_layer_name"},
   $some_geometry,
   'SQLite',
 );
 
=head2 Info

 my $info = $dataset->Info($options);
 my $info = $dataset->Info(['-json', '-stats']);

This is the same as gdalinfo utility. $options is a reference to an
array.  Valid options are as per the L<gdalinfo|https://www.gdal.org/gdalinfo.html> utility.

=head2 Translate

 my $target = $source->Translate($path, $options, $progress, $progress_data);

Convert a raster dataset into another raster dataset. This is the same
as the L<gdal_translate|https://www.gdal.org/gdal_translate.html> utility. $name is the name of the target
dataset. $options is a reference to an array of switches.

=head2 Warp

 my $result = $dataset->Warp($args);

$args is a hashref, keys may be Destination, Input, Options, Progress,
ProgressData.

Valid options are as per the L<gdalwarp|https://www.gdal.org/gdalwarp.html> utility.

=head2 VectorTranslate

 my $result = $dataset->VectorTranslate($args);

$args is a hashref, keys may be Destination, Input, Options, Progress,
ProgressData.

Valid options are as per the L<ogr2ogr|https://www.gdal.org/ogr2ogr.html> utility.  

=head2 DEMProcessing

 my $result = $dataset->DEMProcessing($path, $args);

$args is a hashref, keys may be Processing, ColorFilename, Options,
Progress, ProgressData.

See also L<gdaldem|https://www.gdal.org/gdaldem.html>.

=head2 NearBlack

 my $result = $dataset->NearBlack($args);

$args is a hashref, keys may be Destination, Options, Progress,
ProgressData.

Valid options are as per the L<nearblack|https://www.gdal.org/nearblack.html> utility.  

=head2 Grid

 my $result = $dataset->Grid($path, $options, $progress, $progress_data);
 
Valid options are as per the L<gdal_grid|https://www.gdal.org/gdal_grid.html> utility.  

=head2 Rasterize

 my $result = $dataset->Rasterize($args);
 my $result = $dataset->Rasterize({Options => [-b => 1, -at]});

$args is a hashref, keys may be Destination, Options, Progress,
ProgressData.

Valid options are as per the L<gdal_rasterize|https://www.gdal.org/gdal_rasterize.html> utility.  

=head2 BuildVRT

 my $result = $dataset->BuildVRT($path, $args);

$args is a hashref, keys may be Input, Options, Progress,
ProgressData.

=head1 LICENSE

This software is released under the Artistic License. See
L<perlartistic>.

=head1 AUTHOR

Ari Jolma - Ari.Jolma at gmail.com

=head1 SEE ALSO

L<Geo::GDAL::FFI>

L<Alien::gdal>, L<FFI::Platypus>, L<http://www.gdal.org>

=cut

__END__;
