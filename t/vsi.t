use v5.10;
use strict;
use warnings;
use utf8;
use Carp;
use Encode qw(decode encode);
use Geo::GDAL::FFI;
use Geo::GDAL::FFI::VSI qw/FOpen Mkdir ReadDir/;
use Test::More;

{
    Mkdir('/vsimem/x');
    FOpen('/vsimem/x/1', 'w');
    FOpen('/vsimem/x/2', 'w');
    FOpen('/vsimem/x/ä', 'w');
    my @dir = ReadDir('/vsimem/x');
    is_deeply(\@dir, [1, 2, 'ä'], "Mkdir FOpen ReadDir with UTF8");
}

{
    my $f = FOpen('/vsimem/x/1', 'a');
    my $n = $f->Write('My test writing something in UTF8. Eli tätä.');
    $f->Close;
    ok($n == 46, "Write a UTF8 string.");
}

{
    my $f = FOpen('/vsimem/x/2', 'a');
    my $n = $f->Write("Test writing \0 Perl string");
    ok($n == 26, "Write a string containing null.");
    $f->Close;
    $f = FOpen('/vsimem/x/2', 'r');
    my $buf = $f->Read(80);
    $n = do {use bytes; length($buf)};
    ok($n == 26, "Read a string containing null.");
    ok($buf =~ /Perl string/, "Write and Read Perl string.");
}

{
    my $f = FOpen('/vsimem/x/1', 'r');
    my $buf = $f->Read(80);
    my $utf8 = decode(utf8 => $buf);
    ok($utf8 =~ /tätä/, "Write Read");
}

#$f = Geo::GDAL::FFI::VSI::File->Open('/vsicurl/http://example.com/');
#my $html = $f->Read(80);
#ok($html =~  /Example Domain/, "Test example.com with vsicurl");
#$f->Close;

done_testing();
