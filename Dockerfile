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
RUN cd QGIS && patch -p1 < ../patches/debug-wfs3.patch

RUN rm -rf /src/QGIS/debian
ADD debian/* /src/QGIS/debian/
#RUN rm QGIS/debian/control
RUN cd QGIS && touch debian/*.in && make -f debian/rules
RUN (export DEBIAN_FRONTEND=noninteractive; cd QGIS && yes | mk-build-deps --install --remove debian/control)
RUN cd QGIS && dpkg-buildpackage -us -uc
RUN --mount=type=cache,target=/io mkdir /io/release && mkdir /io/debug && mv /src/*-dbg_*.deb /io/debug && mv /src/*.deb /io/release && touch /tmp/.lock

## RELEASE
FROM ubuntu:20.04 AS release
# wait for builder to finish
# COPY --from=builder /tmp/.lock /tmp/.lock
RUN --mount=type=cache,target=/io (export DEBIAN_FRONTEND=noninteractive; apt-get update && apt install -y /io/release/*.deb xvfb nginx spawn-fcgi)

ADD conf/qgis-server-nginx.conf /etc/nginx/nginx.conf
ADD start-xvfb-nginx.sh /usr/local/bin/start-xvfb-nginx.sh

ENV QGIS_PREFIX_PATH /usr
ENV QGIS_PLUGINPATH /io/plugins
ENV QGIS_SERVER_LOG_LEVEL 1
ENV QGIS_SERVER_LOG_STDERR true
ENV QGIS_SERVER_PARALLEL_RENDERING true
ENV QGIS_SERVER_MAX_THREADS 2
ENV QGIS_AUTH_DB_DIR_PATH /tmp/

ENV QT_GRAPHICSSYSTEM raster
ENV DISPLAY :99
ENV HOME /var/lib/qgis

RUN mkdir $HOME && \
    chmod 1777 $HOME
WORKDIR $HOME

EXPOSE 80/tcp 9993/tcp
CMD /usr/local/bin/start-xvfb-nginx.sh

## DEBUG
FROM ubuntu:20.04 AS debug
# wait for builder to finish
# COPY --from=builder /tmp/.lock /tmp/.lock
RUN --mount=type=cache,target=/io (export DEBIAN_FRONTEND=noninteractive; apt-get update && apt install -y /io/release/*.deb /io/debug/*.deb xvfb nginx spawn-fcgi)

ADD conf/qgis-server-nginx.conf /etc/nginx/nginx.conf
ADD start-xvfb-nginx.sh /usr/local/bin/start-xvfb-nginx.sh

ENV QGIS_PREFIX_PATH /usr
ENV QGIS_PLUGINPATH /io/plugins
ENV QGIS_SERVER_LOG_LEVEL 1
ENV QGIS_SERVER_LOG_STDERR true
ENV QGIS_SERVER_PARALLEL_RENDERING true
ENV QGIS_SERVER_MAX_THREADS 2
ENV QGIS_AUTH_DB_DIR_PATH /tmp/

ENV QT_GRAPHICSSYSTEM raster
ENV DISPLAY :99
ENV HOME /var/lib/qgis

RUN mkdir $HOME && \
    chmod 1777 $HOME
WORKDIR $HOME

EXPOSE 80/tcp 9993/tcp
CMD /usr/local/bin/start-xvfb-nginx.sh
