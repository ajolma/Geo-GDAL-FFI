#!/bin/sh

sudo apt-get install cpanminus
sudo cpanm --installdeps --notest git://github.com/shawnlaffan/perl-alien-gdal
sudo cpanm --notest Alien::Build::MM
git clone --depth=50 --branch=master https://github.com/shawnlaffan/perl-alien-gdal.git 
cd perl-alien-gdal
perl Makefile.PL
make | perl -ne 'BEGIN {$|=1; open our $log, ">", "build.log"}; print "\n" if 0 == ($. % 90); print "."; print {$log} $_;' || cat build.log
sudo make install
