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


my $exp_extent = [1,3,1,2];
is_deeply $layer->GetExtent(0), $exp_extent, 'Got correct layer extent, no forcing';
is_deeply $layer->GetExtent(1), $exp_extent, 'Got correct layer extent when forced';



{
    #  need to test more than just the spatial index creation
    my $ds = GetDriver ('ESRI Shapefile')->Create ('/vsimem/test_sql');
    my $layer_name = 'test_sql_layer';
    my $layer = $ds->CreateLayer ({%$schema, Name => $layer_name});
    
    my $f = Geo::GDAL::FFI::Feature->new($layer->GetDefn);
    #$f->SetField(layer => 1);
    $f->SetGeomField([WKT => 'POLYGON ((1 1, 1 2, 3 2, 3 1, 1 1))']);
        
    $layer->CreateFeature($f);
    
    my $result = eval {
        $ds->ExecuteSQL (qq{CREATE SPATIAL INDEX ON "$layer_name"});
    };
    my $e = $@;
    #  we expect 
    ok (!$result, 'ExecuteSQL ran spatial index');
    ok (!$e,      'ExecuteSQL did not error');

}

done_testing();
