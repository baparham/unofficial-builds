# syntax=docker/dockerfile:1
FROM centos:7

ARG GID=1000
ARG UID=1000

RUN groupadd --gid $GID node \
    && adduser --gid $GID --uid $UID node

RUN cat <<EOF | tee -a /etc/yum.repos.d/devtoolset-12.repo
[devtoolset-12]
name=Devtoolset 12
baseurl=https://buildlogs.centos.org/c7-devtoolset-12.x86_64/
enabled=1
gpgcheck=0
EOF

RUN ulimit -n 1024 \
    && sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* \
    && sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-* \
    && yum install -y epel-release \
    && yum install -y centos-release-scl-rh \
    && sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo \
    && sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo \
    && yum upgrade -y \
    && yum install -y \
         git \
         curl \
         make \
         python2 \
         ccache \
         xz \
         devtoolset-12 \
         glibc-devel \
         gcc \
         gcc-c++ \
         bzip2 \
         bzip2-devel \
         zlib-devel \
         libffi-devel \
         openssl-devel \
         wget \
         patch \
         file

# Node.js 24 requires Python >= 3.9 to configure, but CentOS 7 only offers 3.6 and
# the SCL `rh-python38` is both EOL and too old. Python is only ever used to run
# the build scripts, never linked into the Node.js binary, so building it from
# source with the system compiler has no effect on the ABI of what we ship.
RUN --mount=type=tmpfs,target=/usr/src \
    cd /usr/src \
    && curl -fsSL https://www.python.org/ftp/python/3.12.11/Python-3.12.11.tar.xz | tar -xJ \
    && cd Python-3.12.11 \
    && ./configure --prefix=/opt/python312 \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install

# Let ccache shim `gcc`/`g++` so CC/CXX stay single words; Node.js 24's
# configure.py cannot cope with a multi-word CC such as `ccache gcc`.
RUN mkdir -p /usr/lib/ccache \
    && ln -s /usr/bin/ccache /usr/lib/ccache/gcc \
    && ln -s /usr/bin/ccache /usr/lib/ccache/g++ \
    && ln -s /usr/bin/ccache /usr/lib/ccache/cc \
    && ln -s /usr/bin/ccache /usr/lib/ccache/c++

COPY --chown=node:node verify-abi.sh /home/node/verify-abi.sh
COPY --chown=node:node run.sh /home/node/run.sh

VOLUME /home/node/.ccache
VOLUME /out
VOLUME /home/node/node.tar.xz

USER node

ENTRYPOINT [ "/home/node/run.sh" ]
