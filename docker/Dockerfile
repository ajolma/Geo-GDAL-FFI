FROM ubuntu:latest

RUN apt update
RUN apt upgrade -y
RUN apt install -y git cpanminus bash-completion curl libssl-dev build-essential autoconf libtool pkg-config zlib1g-dev

RUN git clone https://github.com/ajolma/Geo-GDAL-FFI.git
