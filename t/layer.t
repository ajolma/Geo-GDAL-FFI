use v5.10;
use strict;
use warnings;
use Carp;
use Geo::GDAL::FFI qw/GetDriver HaveGEOS/;
use Test::More;
use Data::Dumper;

my $schema = {
    GeometryType => 'Polygon',
    Fields => [
        {
            Name => 'layer',
            Type => 'Integer'
        }
        ]
};

my $layer = GetDriver('Memory')->Create->CreateLayer($schema);

my $f = Geo::GDAL::FFI::Feature->new($layer->GetDefn);
$f->SetField(layer => 1);
$f->SetGeomField([WKT => 'POLYGON ((1 1, 1 2, 3 2, 3 1, 1 1))']);
    
$layer->CreateFeature($f);

$schema->{Fields}[0]{Name} = 'method';

my $method = GetDriver('Memory')->Create->CreateLayer($schema);

$f = Geo::GDAL::FFI::Feature->new($method->GetDefn);
$f->SetField(method => 2);
$f->SetGeomField([WKT => 'POLYGON ((2 1, 2 2, 4 2, 4 1, 2 1))']);

$method->CreateFeature($f);

my $progress;

my $result;
eval {
    $result = $layer->Intersection($method, {Progress => sub {$progress = 1}});
};
 SKIP: {
     skip "No GEOS support in GDAL.", 5 unless HaveGEOS();

     ok($progress == 1, "Intersection progress.");

     my $count = 0;
     $result->ResetReading;
     while (my $f = $result->GetNextFeature) {
         ok($f->GetField('layer') == 1, "Field 1");
         ok($f->GetField('method') == 2, "Field 2");
         ok($f->GetGeomField->AsText eq 'POLYGON ((2 2,3 2,3 1,2 1,2 2))', "GeomField");
         $count++;
     }
     ok($count == 1, "Intersection result.");
     
     $result = $layer->Union($method);
     $result = $layer->SymDifference($method);
     $result = $layer->Identity($method);
     $result = $layer->Update($method);
     $result = $layer->Clip($method);
     $result = $layer->Erase($method);
};


#  GetName
{
    my $name = $layer->GetName;
    is ($name, '', 'Got correct default name for anonymous layer');
    my $test_name = 'test_name';
    my $named_layer = GetDriver('Memory')->Create->CreateLayer({Name => $test_name});
    $name = $named_layer->GetName;
    is ($name, $test_name, 'Got correct name for named layer');
}

my $exp_extent = [1,3,1,2];
is_deeply $layer->GetExtent(0), $exp_extent, 'Got correct layer extent, no forcing';
is_deeply $layer->GetExtent(1), $exp_extent, 'Got correct layer extent when forced';



{
    #  need to test more than just the spatial index creation
    my $ds = GetDriver ('ESRI Shapefile')->Create ('/vsimem/test_sql');
    my $layer_name = 'test_sql_layer';
    my $layer = $ds->CreateLayer ({
        Name => $layer_name,
        GeometryType => 'Polygon',
        Fields => [
            {
                Name => 'int_fld',
                Type => 'Integer'
            }
        ],
    });
    
    my $f = Geo::GDAL::FFI::Feature->new($layer->GetDefn);
    $f->SetField(int_fld => 1);
    $f->SetGeomField([WKT => 'POLYGON ((1 1, 1 2, 3 2, 3 1, 1 1))']);
    $layer->CreateFeature($f);
    my $g = Geo::GDAL::FFI::Feature->new($layer->GetDefn);
    $g->SetField(int_fld => 10);
    $g->SetGeomField([WKT => 'POLYGON ((10 10, 10 20, 30 20, 30 10, 10 10))']);
    $layer->CreateFeature($g);
    
    my $result = eval {
        $ds->ExecuteSQL (qq{CREATE SPATIAL INDEX ON "$layer_name"});
    };
    my $e = $@;
    ok (!defined $result, 'ExecuteSQL ran spatial index and undef was returned');
    ok (!$e, 'ExecuteSQL did not error');
    
    my $feature_count;
    
    my $filter1 = $ds->ExecuteSQL (
        qq{SELECT * FROM "$layer_name" WHERE int_fld > 2},
    );
    $feature_count = 0;
    while (my $feat = $filter1->GetNextFeature) {
        $feature_count++;
    }
    is ($feature_count, 1, 'selected correct number of features');
    
    $filter1->ResetReading;
    my $feat = $filter1->GetNextFeature;
    is ($feat->GetField ('int_fld'), 10, 'correct field value from selection');

    my $filt_poly = Geo::GDAL::FFI::Geometry->new(
        WKT => 'POLYGON ((0 0, 0 4, 4 4, 4 0, 0 0))',
    );

    #  debug, but envelope method also fails
    #my $ptlist = $filt_poly->GetPoints;
    #my $env = [0,0,0,0];
    #Geo::GDAL::FFI::OGR_G_GetEnvelope ($filt_poly, $env);

    #  currently crashes when $filt_poly is passed
    my $filter2 = $ds->ExecuteSQL (
        qq{SELECT * FROM "$layer_name"},
        $filt_poly,
    );
    $feature_count = 0;
    while (my $feat = $filter2->GetNextFeature) {
        $feature_count++;
    }
    is ($feature_count, 1, 'spatial filter selected correct number of features');
    $filter2->ResetReading;
    my $feat2 = $filter2->GetNextFeature;
    is ($feat2->GetField ('int_fld'), 1, 'correct field value from spatial filter selection');
    
}

done_testing();
