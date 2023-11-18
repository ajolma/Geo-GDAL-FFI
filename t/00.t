use v5.10;
use strict;
use warnings;
use Config;
use Carp;
use Encode qw(decode encode);
use Test::More;
use Data::Dumper;
use JSON;

BEGIN { use_ok('Geo::GDAL::FFI', qw/:all/); }

if(1){
    Geo::GDAL::FFI::UnsetErrorHandling();
    print STDERR "test a - GDAL error messages without Geo::GDAL::FFI error handling:\n";
    my $err_cat = $Geo::GDAL::FFI::Debug;
    Geo::GDAL::FFI::CPLError(
        $err_cat, 1, "A GDAL Debug message.");
    $err_cat = $Geo::GDAL::FFI::Warning;
    Geo::GDAL::FFI::CPLError(
        $err_cat, 1, "A GDAL Warning message.");
    $err_cat = $Geo::GDAL::FFI::Failure;
    Geo::GDAL::FFI::CPLError(
        $err_cat, 1, "A GDAL Failure error message.");
    print STDERR "Fatal GDAL error ends the program even when run inside eval.\n";
    # Fatal error dumps core
    #eval {
    #    $err_cat = $Geo::GDAL::FFI::Fatal;
    #    Geo::GDAL::FFI::CPLError(
    #        $err_cat, 1, "This is GDAL Fatal error ($Geo::GDAL::FFI::Fatal) without Geo::GDAL::FFI error handling...");
    #};
    #print STDERR "run in Perl eval {};\n";
    Geo::GDAL::FFI::SetErrorHandling();
    print STDERR "test b - GDAL error messages with Geo::GDAL::FFI error handling:\n";
    $err_cat = $Geo::GDAL::FFI::Debug;
    print STDERR "GDAL Debug message requires \$Geo::GDAL::FFI::DEBUG set to true.\n";
    Geo::GDAL::FFI::CPLError(
        $err_cat, 1, "You don't see this.");
    $Geo::GDAL::FFI::DEBUG = 1;
    Geo::GDAL::FFI::CPLError(
        $err_cat, 1, "\$Geo::GDAL::FFI::DEBUG is now true.\n");
    $Geo::GDAL::FFI::DEBUG = 0;
    $err_cat = $Geo::GDAL::FFI::Warning;
    $SIG{'__WARN__'} = sub {
        print STDERR "Perl warning: $_[0]";
    };
    Geo::GDAL::FFI::CPLError(
        $err_cat, 1, "A GDAL Warning is converted into a Perl warn call.");
    $err_cat = $Geo::GDAL::FFI::Failure;
    Geo::GDAL::FFI::CPLError(
        $err_cat, 1, "A GDAL Failure.");
    print STDERR "GDAL Failures are stored in \@Geo::GDAL::FFI::errors:\n@Geo::GDAL::FFI::errors\n";
}

# test the singleton

if(1){
    my $gdal = Geo::GDAL::FFI->get_instance();
    $gdal->{favourite_animal} = 'llama';
    my $gdal2 = Geo::GDAL::FFI->get_instance();
    ok($gdal->{favourite_animal} eq $gdal2->{favourite_animal}, "Instance is a singleton 1/2.");
    $gdal2 = Geo::GDAL::FFI->new();
    ok($gdal->{favourite_animal} eq $gdal2->{favourite_animal}, "Instance is a singleton 2/2.");
}

# test unavailable function
if(1){
    my $gdal = Geo::GDAL::FFI->get_instance();
    my $can = $gdal->can('is_not_available');
    ok(!$can, "Can't call missing functions.");
}

# test error handler:
if(1){
    eval {
        my $ds = Open('itsnotthere.tiff');
    };
    ok(defined $@, "Got error: '$@'.");
}

# test CSL
if(1){
    ok(Geo::GDAL::FFI::CSLCount(0) == 0, "empty CSL");
    my @list;
    my $csl = Geo::GDAL::FFI::CSLAddString(0, 'foo');
    for my $i (0..Geo::GDAL::FFI::CSLCount($csl)-1) {
        push @list, Geo::GDAL::FFI::CSLGetField($csl, $i);
    }
    ok(@list == 1 && $list[0] eq 'foo', "list with one string: '@list'");
}

# test file finder
if(1){
    my $gdal_data_dir = GetConfigOption(GDAL_DATA => '');
    SKIP: {
        skip "GDAL (Alien::gdal) is not properly installed; GDAL support files are not available.", 3 unless $gdal_data_dir;

        my $target_file= 'stateplane.csv';

        my $path = FindFile($target_file);
        ok(defined $path, "GDAL support files found.");

        my $version = Geo::GDAL::FFI::GetVersionInfo('SEMANTIC');
        say STDERR "FYI: Your GDAL is version $version";

        say STDERR "FYI: GDAL_DATA = $gdal_data_dir";
        if (!$path) {
            # what's wrong with GDAL_DATA??
            if (opendir(my $dh, $gdal_data_dir)) {
                my @contents = grep { -f "$gdal_data_dir/$_" } readdir($dh);
                closedir $dh;
                @contents = sort @contents;
                say STDERR "Contents of GDAL_DATA: @contents";
            } else {
                say STDERR "Can't opendir $gdal_data_dir: $!";
            }
        }

        PopFinderLocation(); #FinderClean;
        my $path2 = FindFile($target_file);
        ok(not(defined $path2), "GDAL support files not found after popping finder.");

        $path =~ s/[\w.]+$//;
        PushFinderLocation($path);
        $path = FindFile($target_file);
        ok(defined $path, "GDAL support files found when working path inserted.");
    }
}

# test VersionInfo
if(1){
    my $info = GetVersionInfo();
    ok($info, "Got info: '$info'.");
}

# test driver count
if(1){
    my $n = GetDrivers();
    ok($n > 0, "Have $n drivers.");
}

# test metadata
if(1){
    my $dr;
    eval {$dr = GetDriver('NITF');};
  SKIP: {
      skip "metadata tests. NITF driver not found." unless defined $dr;

      my $ds = $dr->Create('/vsimem/test.nitf', 10);

      my @d = $ds->GetMetadataDomainList;
      ok(@d > 0, "GetMetadataDomainList"); # DERIVED_SUBDATASETS NITF_METADATA CGM

      my %d = $ds->GetMetadata;
      is_deeply([sort keys %d], [sort @d], "GetMetadata");

      %d = $ds->GetMetadata('NITF_METADATA');
      @d = keys %d; # NITFFileHeader NITFImageSubheader
      ok(@d == 2, "GetMetadata(\$domain)");

      $ds->SetMetadata({x => {a => 'b'}});
      %d = $ds->GetMetadata('x');
      is_deeply(\%d, {a => 'b'}, "SetMetadata");
    }
}

# test progress function
if(1){
    my $dr = GetDriver('GTiff');
    my $ds = $dr->Create('/vsimem/test.tiff', 10);
    my $was_at_fct = 0;
    my $progress = sub {
        my ($fraction, $msg, $data) = @_;
        #say STDERR "$fraction $data";
        ++$was_at_fct;
    };
    my $data = 'whoa';
    my $ds2 = $dr->Create('/vsimem/copy.tiff', {Source => $ds, Progress => $progress, ProgressData => \$data});
    ok($was_at_fct > 0, "Progress callback called $was_at_fct times.");
}

# test Info
if(1){
    my $dr = GetDriver('GTiff');
    my $ds = $dr->Create('/vsimem/test.tiff', 10);
    my $info = decode_json $ds->GetInfo(['-json']);
    ok($info->{files}[0] eq '/vsimem/test.tiff', "Info");
}

# test dataset
if(1){
    my $ffi = Geo::GDAL::FFI->new;
    my $dr = GetDriver('GTiff');
    my $ds = $dr->Create('/vsimem/test.tiff', 10);
    my $ogc_wkt =
        'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS84",6378137,298.257223563,'.
        'AUTHORITY["EPSG","7030"]],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,'.
        'AUTHORITY["EPSG","8901"]],UNIT["degree",0.01745329251994328,'.
        'AUTHORITY["EPSG","9122"]],AUTHORITY["EPSG","4326"]]';
    if ($ffi->{gdal}->version ge '3') {
        $ogc_wkt =
            'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS84",6378137,298.257223563,'.
            'AUTHORITY["EPSG","7030"]],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,'.
            'AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,'.
            'AUTHORITY["EPSG","9122"]],AXIS["Latitude",NORTH],AXIS["Longitude",EAST],'.
            'AUTHORITY["EPSG","4326"]]';
    }
    $ds->SetProjectionString($ogc_wkt);
    my $p = $ds->GetProjectionString;
    is($p, $ogc_wkt, "Set/get projection string");
    my $transform = [10,2,0,20,0,3];
    $ds->SetGeoTransform($transform);
    my $inv = [0,0,0,0,0,0];
    ok(Geo::GDAL::FFI::GDALInvGeoTransform($transform, $inv) && "@$inv" eq "-5 0.5 0 -6.66666666666667 0 0.333333333333333", "Invert geotransform");
    my ($x, $y);
    Geo::GDAL::FFI::GDALApplyGeoTransform($transform,5,5,\$x,\$y);
    ok($x == 20 && $y == 35, "Applied geotransform to pixel coords");
    my $t = $ds->GetGeoTransform;
    is_deeply($t, $transform, "Set/get geotransform");

}

# test band
if(1){
    my $dr = GetDriver('GTiff');
    my $ds = $dr->Create('/vsimem/test.tiff', 256);
    my $b = $ds->GetBand;
    #say STDERR $b;
    my @size = $b->GetBlockSize;
    #say STDERR "block size = @size";
    ok($size[0] == 256 && $size[1] == 32, "Band block size.");
    my @data = (
        [1, 2, 3],
        [4, 5, 6]
        );
    $b->Write(\@data);
    my $data = $b->Read(0, 0, 3, 2);
    is_deeply(\@data, $data, "Raster i/o");

    $ds->FlushCache;
    my $block = $b->ReadBlock();
    for my $ln (@$block) {
        #say STDERR "@$ln";
    }
    ok(@{$block->[0]} == 256 && @$block == 32 && $block->[1][2] == 6, "Read block ($block->[1][2])");
    $block->[1][2] = 7;
    $b->WriteBlock($block);
    $block = $b->ReadBlock();
    ok($block->[1][2] == 7, "Write block ($block->[1][2])");

    $b->SetCategoryNames('a', 'b');
    my @names = $b->GetCategoryNames;
    is_deeply(\@names, ['a', 'b'], "Set and get raster category names (got '@names').");

    my $v = $b->GetNoDataValue;
    ok(!defined($v), "Get nodata value.");
    $b->SetNoDataValue(13);
    $v = $b->GetNoDataValue;
    ok($v == 13, "Set nodata value.");
    $b->SetNoDataValue();
    $v = $b->GetNoDataValue;
    ok(!defined($v), "Delete nodata value.");
    # the color table test with GTiff fails with
    # Cannot modify tag "PhotometricInterpretation" while writing at (a line afterwards this).
    # should investigate why
    #$b->SetColorTable([[1,2,3,4],[5,6,7,8]]);

    if(0){ # band metadata test
        $b->SetMetadata({'d' => {'a' => 'b'}});
        my $md = $b->GetMetadata();
        for my $d (keys %$md) {
            say 'domain ',$d;
            for (keys %{$md->{$d}}) {
                say $_, '=>', $md->{$d}{$_};
            }
        }
    }
}

if(1){
    my $dr = GetDriver('MEM');
    my $ds = $dr->Create('', 10);
    my $b = $ds->GetBand;
    my $table = [[1,2,3,4],[5,6,7,8]];
    $b->SetColorTable($table);
    my $t = $b->GetColorTable;
    is_deeply($t, $table, "Set/get color table");
    $b->SetColorInterpretation('PaletteIndex');
    $ds->FlushCache;
}

# test creating a shapefile
if(1){
    my $dr = GetDriver('ESRI Shapefile');
    my $ds = $dr->Create('test.shp');
    my @sr = ();
    if (FindFile('gcs.csv')) {  #  should be version checked? GDAL 3 does not use gcs.csv
        @sr = (SpatialReference => Geo::GDAL::FFI::SpatialReference->new(EPSG => 3067));
    }
    my $l = $ds->CreateLayer({Name => 'test', GeometryType => 'Point', @sr});
    my $d = $l->GetDefn();
    my $f = Geo::GDAL::FFI::Feature->new($d);
    $l->CreateFeature($f);
    undef $l; #  otherwise $ds is not flushed due to parent ref
    $ds = Open('test.shp');
    $l = $ds->GetLayer;
    $d = $l->GetDefn();
    ok($d->GetGeomType eq 'Point', "Create point shapefile and open it.");
    unlink qw/test.dbf test.prj test.shp test.shx/;
}

# test field definitions
if(1){
    my $f = Geo::GDAL::FFI::FieldDefn->new({Name => 'test', Type => 'Integer'});
    ok($f->GetName eq 'test', "Field definition: get name");
    ok($f->GetType eq 'Integer', "Field definition: get type");

    $f->SetName('test2');
    ok($f->GetName eq 'test2', "Field definition: name");

    $f->SetType('Real');
    ok($f->GetType eq 'Real', "Field definition: type");

    $f->SetSubtype('Float32');
    ok($f->GetSubtype eq 'Float32', "Field definition: subtype");

    $f->SetJustify('Left');
    ok($f->GetJustify eq 'Left', "Field definition: Justify");

    $f->SetWidth(10);
    ok($f->GetWidth == 10, "Field definition: Width");

    $f->SetPrecision(10);
    ok($f->GetPrecision == 10, "Field definition: Precision");

    $f->SetIgnored;
    ok($f->IsIgnored, "Field definition: Ignored ");

    $f->SetIgnored(0);
    ok(!$f->IsIgnored, "Field definition: not Ignored");

    $f->SetNullable(1);
    ok($f->IsNullable, "Field definition: Nullable");

    $f->SetNullable;
    ok(!$f->IsNullable, "Field definition: Nullable");

    $f = Geo::GDAL::FFI::GeomFieldDefn->new({Name => 'test', GeometryType => 'Point'});
    ok($f->GetName eq 'test', "Geometry field definition: get name");
    ok($f->GetType eq 'Point', "Geometry field definition: get type");

    $f->SetName('test2');
    ok($f->GetName eq 'test2', "Geometry field definition: name");

    $f->SetType('LineString');
    ok($f->GetType eq 'LineString', "Geometry field definition: type");

    $f->SetIgnored;
    ok($f->IsIgnored, "Geometry field definition: Ignored");

    $f->SetIgnored(0);
    ok(!$f->IsIgnored, "Geometry field definition: not Ignored");

    $f->SetNullable(1);
    ok($f->IsNullable, "Geometry field definition: Nullable");

    $f->SetNullable;
    ok(!$f->IsNullable, "Geometry field definition: Nullable");
}

# test feature definitions
if(1){
    my $d = Geo::GDAL::FFI::FeatureDefn->new;
    ok($d->GetFieldDefns == 0, "GetFieldCount");
    ok($d->GetGeomFieldDefns == 1, "GetGeomFieldCount ".(scalar $d->GetGeomFieldDefns));

    $d->SetGeometryIgnored(1);
    ok($d->IsGeometryIgnored, "IsGeometryIgnored");
    $d->SetGeometryIgnored(0);
    ok(!$d->IsGeometryIgnored, "IsGeometryIgnored");

    $d->SetStyleIgnored(1);
    ok($d->IsStyleIgnored, "IsStyleIgnored");
    $d->SetStyleIgnored(0);
    ok(!$d->IsStyleIgnored, "IsStyleIgnored");

    $d->SetGeomType('Polygon');
    ok($d->GetGeomType eq 'Polygon', "GeomType");

    $d->AddFieldDefn(Geo::GDAL::FFI::FieldDefn->new({Name => 'test', Type => 'Integer'}));
    ok($d->GetFieldDefns == 1, "GetFieldCount");
    $d->DeleteFieldDefn(0);
    ok($d->GetFieldDefns == 0, "DeleteFieldDefn");

    $d->AddGeomFieldDefn(Geo::GDAL::FFI::GeomFieldDefn->new({Name => 'test', GeometryType => 'Point'}));
    ok($d->GetGeomFieldDefns == 2, "GetGeomFieldCount");
    $d->DeleteGeomFieldDefn(1);
    ok($d->GetGeomFieldDefns == 1, "DeleteGeomFieldDefn");
}

# test creating a geometry object
if(1){
    my $g = Geo::GDAL::FFI::Geometry->new('Point');
    my $wkt = $g->AsText;
    ok($wkt eq 'POINT EMPTY', "Got WKT: '$wkt'.");
    $g = Geo::GDAL::FFI::Geometry->new(WKT => 'POINT (1 2)');
    ok($g->AsText eq 'POINT (1 2)', "Import from WKT");
    ok($g->GetPointCount == 1, "Point count");
    my @p = $g->GetPoint;
    ok(@p == 2 && $p[0] == 1 && $p[1] == 2, "Get point");
    $g->SetPoint(2, 3, 4, 5);
    @p = $g->GetPoint;
    ok(@p == 2 && $p[0] == 2 && $p[1] == 3, "Set point: @p");

    $g = Geo::GDAL::FFI::Geometry->new('PointZM');
    ok($g->GetType eq 'PointZM', "Geom constructor respects M & Z");
    $g = Geo::GDAL::FFI::Geometry->new('Point25D');
    ok($g->GetType eq 'Point25D', "Geom constructor respects M & Z");
    $g = Geo::GDAL::FFI::Geometry->new('PointM');
    ok($g->GetType eq 'PointM', "Geom constructor respects M & Z");
    $wkt = $g->AsText;
    ok($wkt eq 'POINT M EMPTY', "Got WKT: '$wkt'.");
    $g = Geo::GDAL::FFI::Geometry->new(WKT => 'POINTM (1 2 3)');
    ok($g->AsText eq 'POINT M (1 2 3)', "Import PointM from WKT");
}

# test features
if(1){
    my $d = Geo::GDAL::FFI::FeatureDefn->new();
    # geometry type checking is not implemented in GDAL
    #$d->SetGeomType('PointM');
    $d->AddGeomFieldDefn(Geo::GDAL::FFI::GeomFieldDefn->new({Name => 'test2', GeometryType => 'LineString'}));
    my $f = Geo::GDAL::FFI::Feature->new($d);
    ok($d->GetGeomFieldDefns == 2, "GetGeometryCount");
    #GetGeomFieldDefnRef
    my $g = Geo::GDAL::FFI::Geometry->new('PointM');
    $g->SetPoint(1,2,3,4);
    $f->SetGeomField($g);
    my $h = $f->GetGeomField();
    ok($h->AsText eq 'POINT M (1 2 4)', "GetGeometry");

    $g = Geo::GDAL::FFI::Geometry->new('LineString');
    $g->SetPoint(0, 5,6,7,8);
    $g->SetPoint(1, [7,8]);
    $f->SetGeomField(1 => $g);
    $h = $f->GetGeomField(1);
    ok($h->AsText eq 'LINESTRING (5 6,7 8)', "2nd geom field");
}

# test setting field
if(1){
    my $types = \%Geo::GDAL::FFI::field_types;
    my $d = Geo::GDAL::FFI::FeatureDefn->new();
    for my $t (sort {$types->{$a} <=> $types->{$b}} keys %$types) {
        $d->AddFieldDefn(Geo::GDAL::FFI::FieldDefn->new({Name => $t, Type => $t}));
    }

    my $f = Geo::GDAL::FFI::Feature->new($d);
    my $n = 'Integer';

    my $x = $f->IsFieldSet($n) ? 'set' : 'not set';
    ok($x eq 'not set', "Not set");
    $x = $f->IsFieldNull($n) ? 'null' : 'not null';
    ok($x eq 'not null', "Not null");

    $f->SetField($n, undef);

    $x = $f->IsFieldSet($n) ? 'set' : 'not set';
    ok($x eq 'set', "Set");
    $x = $f->IsFieldNull($n) ? 'null' : 'not null';
    ok($x eq 'null', "Null");

    $f->SetField($n);

    $x = $f->IsFieldSet($n) ? 'set' : 'not set';
    ok($x eq 'not set', "Not set");
    $x = $f->IsFieldNull($n) ? 'null' : 'not null';
    ok($x eq 'not null', "Not null");

    # scalar types
    $f->SetField($n, 13);
    $x = $f->GetField($n);
    ok($x == 13, "Set/get Integer field: $x");

  SKIP: {
      skip "64 bit integers not supported in this Perl.",1 unless $Config{use64bitint} eq 'define';
      $n = 'Integer64';
      $f->SetField($n, 0x90000001);
      $x = $f->GetField($n);
      ok($x == 0x90000001, "Set/get Integer64 field: $x");
    }

    $f->SetField(Real => 1.123);
    $x = $f->GetField('Real');
    $x = sprintf("%.3f", $x);
    ok($x eq '1.123', "Set/get Real field: $x");

    my $s = decode utf8 => 'åäö';
    $f->SetField(String => $s);
    $x = $f->GetField(String => 'utf8');
    ok($x eq $s, "Set/get String field: $x");

    # WideString not tested

    #$f->SetFieldBinary(Binary}, 1);

    my @s = (13, 21, 7, 5);
    $f->SetField(IntegerList => @s);
    my @x = $f->GetField('IntegerList');
    is_deeply(\@x, \@s, "Set/get IntegerList field: @x");

  SKIP: {
      skip "64 bit integers not supported in this Perl.",1 unless $Config{use64bitint} eq 'define';
      $n = 'Integer64List';
      @s = (0x90000001, 21, 7, 5);
      $f->SetField($n, @s);
      @x = $f->GetField($n);
      is_deeply(\@x, \@s, "Set/get Integer64List field: @s => @x");
    }

    @s = (3, 21.2, 7.4, 5.5);
    $f->SetField(RealList => @s);
    @x = $f->GetField('RealList');
    for (@s) {
        $_ = sprintf("%.3f", $_);
    }
    for (@x) {
        $_ = sprintf("%.3f", $_);
    }
    is_deeply(\@x, \@s, "Set/get DoubleList field: @x");

    @s = ('a', 'gdal', 'perl');
    $f->SetField(StringList => @s);
    @x = $f->GetField('StringList');
    is_deeply(\@x, \@s, "Set/get StringList field: @x");

    @s = (1962, 4, 23);
    $f->SetField(Date => @s);
    @x = $f->GetField('Date');
    is_deeply(\@x, \@s, "Set/get Date field: @x");

    $n = 'Time';
    @s = (15, 23, 23.34, 1);
    $f->SetField($n, @s);
    @x = $f->GetField($n);
    is_deeply(\@x, \@s, "Set/get Time field: @x");

    $n = 'DateTime';
    @s = (1962, 4, 23, 15, 23, 23.34, 1);
    $f->SetField($n, @s);
    @x = $f->GetField($n);
    is_deeply(\@x, \@s, "Set/get DateTime field: @x");

#    Binary => 8,

    @s = (1962, 4, 23);
    $f->SetField(Date => @s);
    @x = $f->GetField('Date');
    is_deeply(\@x, \@s, "Set/get Date field: @x");
}

# test layer feature manipulation
if(1){
    my $dr = GetDriver('Memory');
    my $ds = $dr->Create({Name => 'test'});
    my @sr = ();
    if (FindFile('stateplane.csv')) {
        @sr = (SpatialReference => Geo::GDAL::FFI::SpatialReference->new(EPSG => 3067));
    }
    my $l = $ds->CreateLayer({Name => 'test', GeometryType => 'Point', @sr});
    $l->CreateField(Geo::GDAL::FFI::FieldDefn->new({Name => 'int', Type => 'Integer'}));
    my $f = Geo::GDAL::FFI::Feature->new($l->GetDefn);
    $f->SetField(int => 5);
    my $g = Geo::GDAL::FFI::Geometry->new('Point');
    $g->SetPoint(3, 5);
    $f->SetGeomField($g);
    $l->CreateFeature($f);
    my $fid = $f->GetFID;
    ok($fid == 0, "FID of first feature");
    $f = $l->GetFeature($fid);
    ok($f->GetField('int') == 5, "Field was set");
    ok($f->GetGeomField->AsText eq 'POINT (3 5)', "Geom Field was set");
}

done_testing();
