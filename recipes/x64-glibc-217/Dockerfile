# syntax=docker/dockerfile:1
FROM centos:7

ARG GID=1000
ARG UID=1000

RUN groupadd --gid $GID node \
    && adduser --gid $GID --uid $UID node

RUN ulimit -n 1024 \
    && sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* \
    && sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-* \
    && yum upgrade -y \
    && yum install -y \
         git \
         curl \
         make \
         ccache \
         gcc \
         gcc-c++ \
         bzip2 \
         bzip2-devel \
         xz \
         wget \
         zlib-devel \
         libffi-devel \
         openssl-devel \
         glibc-devel \
         texinfo \
         file \
         patch

# Build Python 3.12 from source (https://www.python.org)
RUN --mount=type=tmpfs,target=/usr/src \
    cd /usr/src \
    && curl -fsSL https://www.python.org/ftp/python/3.12.11/Python-3.12.11.tar.xz | tar -xJ \
    && cd Python-3.12.11 \
    && ./configure --prefix=/opt/python312 --enable-optimizations \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install

# Build GCC 13 from source (https://gcc.gnu.org)
RUN --mount=type=tmpfs,target=/usr/src \
    cd /usr/src \
    && curl -fsSL https://gcc.gnu.org/pub/gcc/releases/gcc-13.3.0/gcc-13.3.0.tar.xz | tar -xJ \
    && cd gcc-13.3.0 \
    && ./contrib/download_prerequisites \
    && mkdir build && cd build \
    && ../configure \
         --prefix=/opt/gcc13 \
         --enable-languages=c,c++ \
         --disable-multilib \
         --disable-bootstrap \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install \
    && cat > /opt/gcc13/enable << 'EOF'
export PATH=/opt/gcc13/bin:${PATH}
export LD_LIBRARY_PATH=/opt/gcc13/lib64:/opt/gcc13/lib:${LD_LIBRARY_PATH}
export MANPATH=/opt/gcc13/share/man:${MANPATH}
export INFOPATH=/opt/gcc13/share/info:${INFOPATH}
EOF

COPY --chown=node:node run.sh /home/node/run.sh

VOLUME /home/node/.ccache
VOLUME /out
VOLUME /home/node/node.tar.xz

USER node

ENTRYPOINT [ "/home/node/run.sh" ]
