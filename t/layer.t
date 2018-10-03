use v5.10;
use strict;
use warnings;
use Carp;
use Geo::GDAL::FFI;
use Test::More;
use Data::Dumper;

my $gdal = Geo::GDAL::FFI->get_instance();

my $schema = {
    GeometryType => 'Polygon',
    Fields => [
        {
            Name => 'layer',
            Type => 'Integer'
        }
        ]
};

my $layer = $gdal->GetDriver('Memory')->Create->CreateLayer($schema);

my $f = Geo::GDAL::FFI::Feature->new($layer->GetDefn);
$f->SetField(layer => 1);
$f->SetGeomField([WKT => 'POLYGON ((1 1, 1 2, 3 2, 3 1, 1 1))']);
    
$layer->CreateFeature($f);

$schema->{Fields}[0]{Name} = 'method';

my $method = $gdal->GetDriver('Memory')->Create->CreateLayer($schema);

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
     skip "No GEOS support in GDAL.", 5 if $@ =~ /^UNSUPPORTED/;

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

done_testing();
