use v5.10;
use strict;
use warnings;
use Carp;
use Encode qw(decode encode);
use Geo::GDAL::FFI qw/GetVersionInfo HaveGEOS/;
use Test::More;
use Data::Dumper;
use JSON;

my $version = GetVersionInfo() / 100;
my $have_geos = HaveGEOS;

{
    my $geometry = Geo::GDAL::FFI::Geometry->new(WKT => 'POINT(1 1)');
    ok($geometry->GetType eq 'Point', "Create Point from WKT (1).");
    ok($geometry->AsText eq 'POINT (1 1)', "Create point from WKT (2).");
}

{
    my $geometry = Geo::GDAL::FFI::Geometry->new(WKT => 'POINTM(1 2 3)');
    my $type = $geometry->GetType;
    ok($type eq 'PointM', "Create PointM from WKT: $type");
    my $wkt = $geometry->AsText;
    ok($wkt eq 'POINT M (1 2 3)', "Create point from WKT: $wkt");
}

{
    my $g = Geo::GDAL::FFI::Geometry->new('Point');
    $g->SetPoint(5, 8);
    my @p = $g->GetPoint;
    ok($p[0] == 5, "Set/GetPoint");
}

SKIP: {
    skip "No GEOS support", 1 unless $have_geos;

    my $geometry = Geo::GDAL::FFI::Geometry->new(WKT => 'POINT(1 1)');
    my $c = $geometry->Centroid;
    ok($geometry->AsText eq 'POINT (1 1)', "Centroid");
}

{
    my $g = Geo::GDAL::FFI::Geometry->new(WKT => 'POLYHEDRALSURFACE Z ( '.
    '((0 0 0, 0 1 0, 1 1 0, 1 0 0, 0 0 0)), '.
    '((0 0 0, 0 1 0, 0 1 1, 0 0 1, 0 0 0)), '.
    '((0 0 0, 1 0 0, 1 0 1, 0 0 1, 0 0 0)), '.
    '((1 1 1, 1 0 1, 0 0 1, 0 1 1, 1 1 1)), '.
    '((1 1 1, 1 0 1, 1 0 0, 1 1 0, 1 1 1)), '.
    '((1 1 1, 1 1 0, 0 1 0, 0 1 1, 1 1 1))) ');
    my $p = $g->GetPoints;
    ok(@$p == 6, "GetPoints");
    $p->[0][0][0][0] = 2;
    $g->SetPoints($p);
    $p = $g->GetPoints;
    ok($p->[0][0][0][0] == 2, "SetPoints");
}

#  GetEnvelope
{
    my $geom = Geo::GDAL::FFI::Geometry->new(
        WKT => 'POLYGON ((0 -1 0, -1 0 0, 0 1 1, 1 0 1, 0 -1 1))',
    );

    my $envelope = $geom->GetEnvelope;
    is_deeply ($envelope, [-1,1,-1,1], 'correct geometry envelope');

    my $envelope3d = $geom->GetEnvelope3D;
    is_deeply ($envelope3d, [-1,1,-1,1,0,1], 'correct 3D geometry envelope');
}

 SKIP: {
     skip "No GEOS support in GDAL.", 5 unless $have_geos;
     skip "Needs version >= 3.0", 1 unless $version >= 30000;
     my $wkt = 'POLYGON ((0 -1,-1 0,0 1,1 0,0 -1))';
     my $geom = Geo::GDAL::FFI::Geometry->new(WKT => $wkt);
     my $test = $geom->MakeValid(METHOD => 'LINEWORK');
     ok($wkt eq $test->AsText);
}

SKIP: {
    skip "No GEOS support in GDAL.", 5 unless $have_geos;
    skip "Needs version >= 3.3", 1 unless $version >= 30300;
    my $wkt = 'POLYGON ((0 -1,-1 0,0 1,1 0,0 -1))';
    my $geom = Geo::GDAL::FFI::Geometry->new(WKT => $wkt);
    my $test = $geom->Normalize();
    ok($test->AsText eq 'POLYGON ((-1 0,0 1,1 0,0 -1,-1 0))');
}

SKIP: {
    skip "No GEOS support in GDAL.", 5 unless $have_geos;
    skip "Needs version >= 3.6", 1 unless $version >= 30600;
    my $wkt = 'MULTIPOINT ((0 -1),(-1 0),(0 1),(1 0),(0 -1))';
    my $geom = Geo::GDAL::FFI::Geometry->new(WKT => $wkt);
    my $test = $geom->ConcaveHull(0.5)->Normalize;
    is($test->AsText, 'POLYGON ((-1 0,0 1,1 0,0 -1,-1 0))', 'ConcaveHull');
}

{
    my $wkt = 'MULTIPOLYGON (((0 0, 0 1, 1 1, 1 0, 0 0)),((1 0, 1 1, 2 1, 2 0, 1 0)))';
    my $geom = Geo::GDAL::FFI::Geometry->new(WKT => $wkt);
    my $test = $geom->UnaryUnion()->Normalize;
    is($test->AsText, 'POLYGON ((0 0,0 1,1 1,2 1,2 0,1 0,0 0))', 'UnaryUnion');
}

done_testing();
