use 5.010;
use Geo::GDAL::FFI;

local $| = 1;

use Test::More;


my $sr = Geo::GDAL::FFI::SpatialReference->new(EPSG => 3067);
my $source_ds = Geo::GDAL::FFI::GetDriver('ESRI Shapefile')
    ->Create('/vsimem/test.shp');
my $layer = $source_ds->CreateLayer({
        Name => 'test',
        SpatialReference => $sr,
        GeometryType => 'Polygon',
        Fields => [
        {
            Name => 'name',
            Type => 'String'
        }
        ]
    });
my $f = Geo::GDAL::FFI::Feature->new($layer->GetDefn);
$f->SetField(name => 'a');
my $g = Geo::GDAL::FFI::Geometry->new('Polygon');
my $poly = 'POLYGON ((1 2, 2 2, 2 1, 1 1, 1 2))';
$f->SetGeomField([WKT => $poly]);
$layer->CreateFeature($f);


my $x_min = 0;
my $y_max = 2;
my $pixel_size = 1;

my $fname = '/vsimem/test_' . time() . '.tiff';
my $target_ds = Geo::GDAL::FFI::GetDriver('GTiff')->Create($fname, 3, 2);
my $transform = [$x_min, $pixel_size, 0, $y_max, 0, -$pixel_size];
$target_ds->SetGeoTransform($transform);

#### COMMENT OUT THIS LINE TO CRASH
#my $target_ds2 =
$source_ds->Rasterize({
    Destination => $target_ds,
    Options     => [
        -b    => 1,
        -burn => 1,
        -at,
    ],
});


my $band_r1 = $target_ds->GetBand;

say 'Reading band data';
my $arr_ref = $band_r1->Read;

say 'Got to end';

ok ('got to end without crashing');

done_testing();
