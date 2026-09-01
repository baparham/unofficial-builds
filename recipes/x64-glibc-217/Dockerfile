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

# Node.js 24 requires Python >= 3.9 to configure, but CentOS 7 only offers 3.6
# and the SCL `rh-python38` is both EOL and too old. Python is only ever used to
# run the build scripts, never linked into the Node.js binary, so building it
# with the system compiler has no effect on the ABI of what we ship.
RUN --mount=type=tmpfs,target=/usr/src \
    cd /usr/src \
    && curl -fsSL https://www.python.org/ftp/python/3.12.11/Python-3.12.11.tar.xz | tar -xJ \
    && cd Python-3.12.11 \
    && ./configure --prefix=/opt/python312 \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install

# Build binutils 2.42 from source (CentOS 7's as/ld are too old for AVX-512 VBMI)
RUN --mount=type=tmpfs,target=/usr/src \
    cd /usr/src \
    && curl -fsSL https://ftp.gnu.org/gnu/binutils/binutils-2.42.tar.xz | tar -xJ \
    && cd binutils-2.42 \
    && ./configure --prefix=/opt/gcc13 --disable-nls --disable-werror \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install

# Build GCC 13 from source (https://gcc.gnu.org).
#
# CentOS 7 ships GCC 4.8 and there is no devtoolset for el7 that can build
# Node.js 24: devtoolset-12 is GCC 12.1.1 (below Node's 12.2 floor) and, more
# fundamentally, Red Hat hard-disables the dual std::string ABI on el7
# (`_GLIBCXX_USE_DUAL_ABI 0`, which then #undefs any _GLIBCXX_USE_CXX11_ABI you
# pass), leaving only the COW string. Node 24's bundled `ada` needs a constexpr
# std::string, which the COW implementation cannot provide.
#
# A stock from-source GCC has no libstdc++_nonshared.a, so it would link against
# a shared libstdc++ far newer than CentOS 7's. run.sh compensates by passing
# --partly-static to configure; verify-abi.sh is the gate that proves it worked.
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
         --with-as=/opt/gcc13/bin/as \
         --with-ld=/opt/gcc13/bin/ld \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install \
    && cat > /opt/gcc13/enable << 'EOF'
export PATH=/opt/gcc13/bin:${PATH}
export LD_LIBRARY_PATH=/opt/gcc13/lib64:/opt/gcc13/lib:${LD_LIBRARY_PATH}
export MANPATH=/opt/gcc13/share/man:${MANPATH}
export INFOPATH=/opt/gcc13/share/info:${INFOPATH}
EOF

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
