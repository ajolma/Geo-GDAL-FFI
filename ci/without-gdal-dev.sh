#!/bin/sh

# bug in Alien::gdal Makefile.PL requires
cpanm --notest Sort::Versions

# the -v ensures the progress dots are sent to stdout
# and avoids travis timeouts
cpanm --installdeps --notest Alien::geos::af
cpanm --notest -v Alien::geos::af
cpanm --installdeps --notest Alien::gdal
cpanm --notest -v Alien::gdal

#cpanm --installdeps --notest git://github.com/shawnlaffan/perl-alien-gdal
#cpanm --notest Alien::Build::MM
#git clone --depth=50 --branch=master https://github.com/shawnlaffan/perl-alien-gdal.git 
#cd perl-alien-gdal
#perl Makefile.PL
#make
#make install
#cd ..
#rm -rf perl-alien-gdal
