use 5.010;
use Geo::GDAL::FFI;

use Test::More;

local $| = 1;


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
$target_ds->SetProjectionString($sr->Export('Wkt'));

#  void context was causing crash due to destroy methods
$source_ds->Rasterize({
    Destination => $target_ds,
    Options     => [
        -b    => 1,
        -burn => 1,
        -at,
    ],
});


my $band_r1 = $target_ds->GetBand;

my $arr_ref = $band_r1->Read;

ok (1, 'Read band data without crashing');

$fname = '/vsimem/test_' . (time()+1) . '.tiff';
my $target_ds2 = Geo::GDAL::FFI::GetDriver('GTiff')->Create($fname, 3, 2);
my $transform2 = [$x_min, $pixel_size, 0, $y_max, 0, -$pixel_size];
$target_ds2->SetGeoTransform($transform2);
$target_ds2->SetProjectionString($sr->Export('Wkt'));

#  make sure we get a ref back
my $target_ds2b = eval {
    $source_ds->Rasterize({
        Destination => $target_ds2,
        Options     => [
            -b    => 1,
            -burn => 1,
            -at,
        ],
    })
};
my $e = $@;
ok ($e, 'Rasterize dies if called in non-void context and destination is set');


done_testing();
