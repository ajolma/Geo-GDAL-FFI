![Linux bin workflow](https://github.com/ajolma/Geo-GDAL-FFI/actions/workflows/linux_bin_build.yml/badge.svg)<br/>
![Linux share workflow](https://github.com/ajolma/Geo-GDAL-FFI/actions/workflows/linux_share_build.yml/badge.svg)<br/>
![Linus sys workflow](https://github.com/ajolma/Geo-GDAL-FFI/actions/workflows/linux_sys_build.yml/badge.svg)<br/>
![MacOS share workflow](https://github.com/ajolma/Geo-GDAL-FFI/actions/workflows/macos_share_builds.yml/badge.svg)<br/>
![MacOS workflow](https://github.com/ajolma/Geo-GDAL-FFI/actions/workflows/macos.yml/badge.svg)<br/>
![Windows workflow](https://github.com/ajolma/Geo-GDAL-FFI/actions/workflows/windows.yml/badge.svg)

Geo-GDAL-FFI
=======================

Perl FFI to GDAL using FFI::Platypus

INSTALLATION FROM CPAN DISTRIBUTION

To build, test and install this module the basic steps are

perl Makefile.PL
make
make test
make install

DEPENDENCIES

FFI::Platypus
PDL
Alien::gdal

Alien::gdal downloads and compiles GDAL. This package will try to use
an existing GDAL in the system if Alien::gdal is not found or GDAL
location prefix is specified as an argument to Makefile.PL, for
example

perl Makefile.PL GDAL=/usr/local

DOCUMENTATION

COPYRIGHT AND LICENCE

Copyright (C) 2017- by Ari Jolma.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
