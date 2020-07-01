#!/bin/sh

sudo add-apt-repository ppa:ubuntugis/ubuntugis-unstable -y
sudo apt-get update
sudo apt-get install libgdal-dev

cpanm --notest -v Alien::gdal