use v5.18;
<<<<<<< HEAD
use warnings;
use strict;
use Config;
use Test::More;

BEGIN {
    use_ok('Geo::GDAL::FFI', qw/:all/);
}

SKIP: {

skip "skip multi-thread test", 4 unless $Config{useithreads};

use_ok('threads');
use_ok('threads::shared');
use_ok('Thread::Queue');
=======
use threads;
use threads::shared;
use warnings;
use strict;
use Test::More;

BEGIN { use_ok('Geo::GDAL::FFI', qw/:all/); }

use Thread::Queue;
>>>>>>> d130384 (Changed string_pointer into standard string* and changed new() to be thread-safe.)

my $q = Thread::Queue->new();
my @in_thrds = ();
my @out_thrds = ();
my $nt = 10;

for my $i (1..$nt) {
    my $t = threads->create(
        sub {
            while (my $h = $q->dequeue()) {
                say "thread out$i: popped $h->{value}";
            }
        }
    );
    push @out_thrds, $t;
}

for my $i (1..$nt) {
    my $t = threads->create(
        sub {
            my $v = rand(100);
            say "thread in$i: pushed $v";
            $q->enqueue({ value => $v });
        }
    );
    push @in_thrds, $t;
}

# try different timing too... :-/
sleep(3);

$q->end();

for my $w (@in_thrds) {
    $w->join();
}

for my $w (@out_thrds) {
    $w->join();
}

ok(1, "threading seems ok");

}

done_testing();
