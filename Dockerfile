# Reproducible build environment for IsoApplet.
#
# IsoApplet's build.xml downloads a pinned ant-javacard.jar at build time,
# verifies its SHA-256 checksum, and reads the JavaCard SDK from ext/sdks (a git submodule of
# martinpaljak/oracle_javacard_sdks). JDK 8 is required because the JC
# converter (com.sun.javacard.converter.Main) reflectively uses classes that
# only run on JDK 8.
#
# Usage (from the repo root, with submodules initialized):
#
#   docker build -t isoapplet-builder .
#   docker run --rm -v "$PWD/out:/out" isoapplet-builder \
#       cp /build/IsoApplet/IsoApplet.cap /out/
#
# Or use the bundled build.sh wrapper:
#
#   ./build.sh                # default
#   ./build.sh -k 32          # override KEY_MAX_COUNT to 32
FROM eclipse-temurin:8-jdk-jammy AS builder

# Build-time configuration.
#
# KEY_MAX_COUNT: maximum number of key slots the applet allocates at install
# time. The upstream default is 16. Increasing it costs a small amount of
# EEPROM per unused slot; decreasing it forbids more keys than the chosen
# value at runtime. Must be a positive short (<= 32767).
ARG KEY_MAX_COUNT=16

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ant \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build/IsoApplet

# Copy the source tree. .dockerignore keeps .git and build artifacts out.
COPY . .

# Patch KEY_MAX_COUNT if the build arg differs from the upstream default.
# The match is anchored so only the constant declaration is touched, never
# the array allocation or boundary check that reference the name.
RUN set -eu; \
    if [ "${KEY_MAX_COUNT}" != "16" ]; then \
        echo "==> Setting KEY_MAX_COUNT = ${KEY_MAX_COUNT}"; \
        sed -i -E \
            "s|(private static final short KEY_MAX_COUNT\s*=\s*)[0-9]+(\s*;)|\1${KEY_MAX_COUNT}\2|" \
            src/xyz/wendland/javacard/pki/isoapplet/IsoApplet.java; \
        grep -n "private static final short KEY_MAX_COUNT" \
            src/xyz/wendland/javacard/pki/isoapplet/IsoApplet.java; \
    fi

# Run the Ant build; produces IsoApplet.cap in the project root.
RUN ant -v dist

# Minimal artifact-only stage so `docker create` + cp is cheap.
FROM scratch AS artifact
COPY --from=builder /build/IsoApplet/IsoApplet.cap /IsoApplet.cap
