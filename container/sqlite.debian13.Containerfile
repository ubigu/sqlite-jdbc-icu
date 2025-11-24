FROM debian:13

RUN  export DEBIAN_FRONTEND=noninteractive && apt-get update \
  && apt-get install --no-install-recommends --no-install-suggests -y \
  build-essential libicu-dev python3 git ca-certificates \
  curl unzip zip tcl-dev tcl apt-transport-https gpg wget maven fossil pkg-config \
  default-jdk

WORKDIR /work

# Java permission tests fail when run with root
RUN useradd -m -u 1000 -s /bin/bash builder \
  && chown builder:builder /work
ADD maven/ /home/builder/.m2/
RUN chown -R builder /home/builder/.m2

USER builder

ARG SQLITE_VERSION=3.51.0.0
RUN git clone --depth 1 -b ${SQLITE_VERSION} https://github.com/xerial/sqlite-jdbc.git

WORKDIR /work/sqlite-jdbc
RUN mvn --no-transfer-progress --batch-mode dependency:resolve

# In newer gcc versions implicit function declarations are treated
# as errors. The `-Wno-error=implicit-function-declaration` should be removed
# when upstream is updated..
RUN fossil set manifest urt;\
   make clean-native native \
     LINKFLAGS="-shared -static-libgcc $(pkg-config --libs --static icu-uc icu-i18n icu-io)" \
     SQLITE_FLAGS="-DSQLITE_ENABLE_ICU $(pkg-config --libs --cflags icu-uc icu-i18n icu-io) -Wno-error=implicit-function-declaration"

# Git repo contains precompiled libraries. Remove them before building java package
RUN rm -Rf src/main/resources/org/sqlite/native && ls -laR  src/main/resources/org/sqlite/

RUN mvn --no-transfer-progress --batch-mode package