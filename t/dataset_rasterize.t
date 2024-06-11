use 5.010;
use strict;
use warnings;

use Geo::GDAL::FFI;

use Test::More;

local $| = 1;

test_VectorTranslate();
test_NearBlack();
test_Warp();
test_Rasterize();

sub test_VectorTranslate {
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

    my $result = eval {
        $source_ds->VectorTranslate ({
            Destination => '/vsimem/test_VectorTranslate',
            Options => [-f => "GML"],
        })
    };
    my $e = $@;
    
    diag $e if $e;
    ok (!$e, 'Ran basic VectorTranslate call without raising exception');

}

sub test_NearBlack {
    my $raster = get_test_raster();

    my $nb = eval {
        $raster->NearBlack({
            Destination => '/vsimem/test_near_black', 
            Options     => [
                '-white',
            ],
        })
    };
    my $e = $@;

    diag $e if $e;
    ok (!$e, 'ran NearBlack without raising exception');
    
}

sub test_Warp {
    SKIP: {
        skip 'need to ensure Proj4 is available before running this test';

        my $raster = get_test_raster();

        #  should use a coord sys with a domain that contains the data...
        my $srs = 'EPSG:3577';
        my $warped = eval {
            $raster->Warp({
                Destination => '/vsimem/test_warp', 
                Options     => [
                    -t_srs => $srs,
                ],
            })
        };
        my $e = $@;

        diag $e if $e;
        ok (!$e, 'ran Warp without exception');
        
        #  more tests needed
    }
}


sub test_Rasterize {
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
}


sub get_test_raster {
    my $name = 'test_ras' . (time() + rand()) . '.tiff';
    my $tiff = Geo::GDAL::FFI::GetDriver('GTiff')->Create('test.tiff', 3, 2);
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
    return $tiff;
}

done_testing();
