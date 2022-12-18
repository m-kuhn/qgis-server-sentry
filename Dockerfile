FROM ubuntu:20.04 AS builder

ARG QGIS_VERSION=final-3_22_14

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
  build-essential \
  wget \
  devscripts \
  equivs \
  python3-dev \
  libprotobuf-dev \
  protobuf-compiler \
  pkg-config

WORKDIR /src
RUN git clone --depth 1 https://github.com/qgis/QGIS.git -b ${QGIS_VERSION}

ADD patches patches
RUN cd QGIS && patch -p1 < ../patches/sentry.patch

RUN rm -rf /src/QGIS/debian
ADD debian/* /src/QGIS/debian/
#RUN rm QGIS/debian/control
RUN cd QGIS && touch debian/*.in && make -f debian/rules
RUN (export DEBIAN_FRONTEND=noninteractive; cd QGIS && yes | mk-build-deps --install --remove debian/control)
RUN cd QGIS && dpkg-buildpackage -us -uc
RUN ls /src/*.deb

FROM ubuntu:22.04
COPY --from=builder /src/*.deb /src/
RUN ls /src/*.deb
RUN (export DEBIAN_FRONTEND=noninteractive; apt-get update && apt install -y /src/*.deb)
