use v5.10;
use strict;
use warnings;
use Carp;
use Geo::GDAL::FFI qw/GetDriver/;
use Test::More;
use Data::Dumper;

my $schema = {
    Name => 'test',
    Fields => [
        {
            Name => 'f1',
            Type => 'Integer',
            Width => 7,
            Ignored => 1,
            Default => 23
        },
        {
            Name => 'f2',
            Type => 'String',
            NotNullable => 1
        }
        ],
    GeometryFields => [
        {
            Name => 'g1',
            Type => 'LineString',
            NotNullable => 1
        },
        {
            Name => 'g2',
            Type => 'Polygon',
            Ignored => 1,
        }
        ]
};

my $layer = GetDriver('Memory')->Create->CreateLayer($schema);

my $schema2 = {
    Name => 'test',
    Fields => [
        {
            Name => 'f1',
            Type => 'Integer',
            Width => 7,
            #Ignored => 1,
            Default => 23,
            Subtype => 'None',
            Justify => 'Undefined',
            Precision => 0,
        },
        {
            Name => 'f2',
            Type => 'String',
            NotNullable => 1,
            Subtype => 'None',
            Width => 0,
            Justify => 'Undefined',
            Precision => 0
        }
        ],
    GeometryFields => [
        {
            Name => 'g1',
            Type => 'LineString',
            NotNullable => 1,
            #SpatialReference => undef
        },
        {
            Name => 'g2',
            Type => 'Polygon',
            #Ignored => 1,
            #SpatialReference => undef
        }
        ]
};

$schema = $layer->GetDefn->GetSchema;
#print Dumper $schema;

is_deeply($schema, $schema2, "Create layer based on a schema");

done_testing();
