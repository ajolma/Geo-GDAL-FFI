package Geo::GDAL::FFI::Layer;
use v5.10;
use strict;
use warnings;
use Carp;
use base 'Geo::GDAL::FFI::Object';

our $VERSION = '0.13_002';

sub DESTROY {
    my $self = shift;
    Geo::GDAL::FFI::OGR_L_SyncToDisk($$self);
    #say STDERR "delete parent $parent{$$self}";
    Geo::GDAL::FFI::_deregister_parent_ref ($$self);
    #say STDERR "destroy $self";
}

sub GetParentDataset {
    my ($self) = @_;
    return Geo::GDAL::FFI::_get_parent_ref ($$self);
}

sub GetDefn {
    my $self = shift;
    my $d = Geo::GDAL::FFI::OGR_L_GetLayerDefn($$self);
    return bless \$d, 'Geo::GDAL::FFI::FeatureDefn';
}

sub CreateField {
    my $self = shift;
    my $def = shift;
    unless (ref $def) {
        # name => type calling syntax
        my $name = $def;
        my $type = shift;
        $def = Geo::GDAL::FFI::FieldDefn->new({Name => $name, Type => $type})
    } elsif (ref $def eq 'HASH') {
        $def = Geo::GDAL::FFI::FieldDefn->new($def)
    }
    my $approx_ok = shift // 1;
    my $e = Geo::GDAL::FFI::OGR_L_CreateField($$self, $$def, $approx_ok);
    return unless $e;
    confess Geo::GDAL::FFI::error_msg({OGRError => $e});
}

sub CreateGeomField {
    my $self = shift;
    my $def = shift;
    unless (ref $def) {
        # name => type calling syntax
        my $name = $def;
        my $type = shift;
        $def = Geo::GDAL::FFI::GeomFieldDefn->new({Name => $name, Type => $type});
    } elsif (ref $def eq 'HASH') {
        $def = Geo::GDAL::FFI::GeomFieldDefn->new($def)
    }
    my $approx_ok = shift // 1;
    my $e = Geo::GDAL::FFI::OGR_L_CreateGeomField($$self, $$def, $approx_ok);
    return unless $e;
    confess Geo::GDAL::FFI::error_msg({OGRError => $e});
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
    confess unless $f;
    return bless \$f, 'Geo::GDAL::FFI::Feature';
}

sub GetFeatureCount {
    my ($self, $force) = @_;
    Geo::GDAL::FFI::OGR_L_GetFeatureCount($$self, !!$force);
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
    confess Geo::GDAL::FFI::error_msg({OGRError => $e});
}

__PACKAGE__->_make_overlay_methods();

sub _make_overlay_methods {
    my ($pkg) = @_;
    my @methods = (qw /
            Intersection Union  SymDifference
            Identity     Update Clip    Erase
        /);
    
    no strict 'refs';
    foreach my $method_name (@methods) {
        *{$pkg . '::' . $method_name} =
            sub {
                my ($self, $method, $args) = @_;
                confess "Method layer missing." unless $method;
                $args //= {};
                my $result = $args->{Result};
                unless ($result) {
                    my $schema = {
                        GeometryType => 'Unknown'
                    };
                    state $mem_driver = Geo::GDAL::FFI::get_memory_driver();
                    $result = Geo::GDAL::FFI::GetDriver($mem_driver)->Create->CreateLayer($schema);
                }
                my $o = 0;
                for my $key (keys %{$args->{Options}}) {
                    $o = Geo::GDAL::FFI::CSLAddString($o, "$key=$args->{Options}{$key}");
                }
                my $p = 0;
                $p = FFI::Platypus->new->closure($args->{Progress}) if $args->{Progress};
                my $e = &{'Geo::GDAL::FFI::OGR_L_'.$method_name} ($$self, $$method, $$result, $o, $p, $args->{ProgressData});
                Geo::GDAL::FFI::CSLDestroy($o);
                return $result unless $e;
                confess Geo::GDAL::FFI::error_msg({OGRError => $e});
            };
    }

    return;
}

sub GetExtent {
    my ($self, $force) = @_;
    my $extent = [0,0,0,0];
    $force = $force ? \1 : \0;  #  ensure $force is a ref
    my $e = Geo::GDAL::FFI::OGR_L_GetExtent ($$self, $extent, $force);
    return $extent unless $e;
    confess Geo::GDAL::FFI::error_msg({OGRError => $e});
}

sub GetName {
    my ($self) = @_;
    return $self->GetDefn->GetName;
}

1;

=pod

=encoding UTF-8

=head1 NAME

Geo::GDAL::FFI::Layer - A collection of vector features in GDAL

=head1 SYNOPSIS

=head1 DESCRIPTION

A set of (vector) features having a same schema (the same Defn
object). Obtain a layer object by the CreateLayer or GetLayer method
of a vector dataset object.

Note that the system stores a reference to the parent dataset for
each layer object to ensure layer objects remain viable.
If you are relying on a dataset object's destruction to
flush its dataset cache and then close it then you need to ensure
all associated child layers are also destroyed.  Failure to do so could
lead to corrupt data when reading in newly written files.

=head1 METHODS

=head2 GetDefn

 my $defn = $layer->GetDefn;

Returns the FeatureDefn object for this layer.

=head2 ResetReading

 $layer->ResetReading;

=head2 GetNextFeature

 my $feature = $layer->GetNextFeature;

=head2 GetFeature

 my $feature = $layer->GetFeature($fid);

=head2 SetFeature

 $layer->SetFeature($feature);

=head2 CreateFeature

 $layer->CreateFeature($feature);

=head2 DeleteFeature

 $layer->DeleteFeature($fid);

=head2 GetFeatureCount

 my $count = $layer->GetFeatureCount();
 
=head2 GetExtent
 $layer->GetExtent();
 $layer->GetExtent(1);

Returns an array ref with [minx, miny, maxx, maxy].
Argument is a boolean to force calculation even
if it is expensive.

=head2 Intersection, Union, SymDifference, Identity, Update, Clip, Erase

 $result = $layer-><Method>($method, $args);

Runs the <method> algorithm between layer and method layer. Named
arguments are the following.

=over 4

=item C<Result>

Optional, allows the user to define the result layer.

=item C<Options>

Optional, allows the user to define the options (see GDAL docs).

=item C<Progress>

Optional, the progress indicator callback.

=item C<ProgressData>

Optional, data for the progress callback.

=back

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
