#!/bin/sh

# bug in Alien::gdal Makefile.PL requires
cpanm --notest Sort::Versions

#  SWL - this gets picked up later, but avoid throwing an error now
cpanm --notest Alien::geos::af

cpanm --installdeps --notest git://github.com/shawnlaffan/perl-alien-gdal
cpanm --notest Alien::Build::MM
git clone --depth=50 --branch=master https://github.com/shawnlaffan/perl-alien-gdal.git 
cd perl-alien-gdal
perl Makefile.PL
make
make install
cd ..
rm -rf perl-alien-gdal
