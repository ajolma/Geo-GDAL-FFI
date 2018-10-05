use v5.10;
use strict;
use warnings;
use Carp;
use Encode qw(decode encode);
use Geo::GDAL::FFI;
use Test::More;

my $f = Geo::GDAL::FFI::VSI::File->Open('/vsicurl/http://example.com/');
my $html = $f->Read(1,80);
ok($html =~  /Example Domain/, "Test example.com with vsicurl");
$f->Close;

done_testing();
