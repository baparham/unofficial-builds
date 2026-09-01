#!/usr/bin/env bash

# Guards the promise made by this recipe's name: the binary must run on a stock
# CentOS 7 userland. `glibc-217` only ever described the glibc floor, but a
# toolchain that links against a newer shared libstdc++ produces a binary that
# still satisfies GLIBC_2.17 while being unusable on the very systems this
# variation exists for. Check every runtime ABI floor, not just glibc.
#
# The defaults are what CentOS 7 itself provides:
#   glibc 2.17        -> GLIBC_2.17
#   libstdc++ 4.8.5   -> GLIBCXX_3.4.19, CXXABI_1.3.7
# The devtoolset toolchain links anything newer than these out of
# libstdc++_nonshared.a, so a reference above a floor means the build silently
# fell back to a plain shared libstdc++ and the artifact must not be shipped.

set -e

max_glibc="${MAX_GLIBC:-2.17}"
max_glibcxx="${MAX_GLIBCXX:-3.4.19}"
max_cxxabi="${MAX_CXXABI:-1.3.7}"

tarball="$1"

if [ -z "$tarball" ] || [ ! -f "$tarball" ]; then
  echo "usage: $0 <node tarball>" >&2
  exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

tar -xf "$tarball" -C "$workdir"

binary="$(find "$workdir" -type f -path '*/bin/node' -print -quit)"
if [ -z "$binary" ]; then
  echo "verify-abi: no bin/node found inside ${tarball}" >&2
  exit 1
fi

# Highest version of a given symbol-version prefix referenced by the binary.
# Prints nothing when the binary references the prefix not at all.
max_referenced() {
  local prefix="$1"
  objdump -p "$binary" \
    | grep -oE "${prefix}_[0-9]+(\.[0-9]+)*" \
    | sed "s/^${prefix}_//" \
    | sort -uV \
    | tail -1
}

failed=0

check_floor() {
  local prefix="$1"
  local max="$2"
  local found

  found="$(max_referenced "$prefix")"

  if [ -z "$found" ]; then
    echo "verify-abi: ${prefix}: no references (ok)"
    return 0
  fi

  # `found` is within the floor when the floor still sorts last of the two.
  if [ "$(printf '%s\n%s\n' "$max" "$found" | sort -V | tail -1)" = "$max" ]; then
    echo "verify-abi: ${prefix}: needs at most ${prefix}_${found}, floor is ${prefix}_${max} (ok)"
    return 0
  fi

  echo "verify-abi: ERROR: ${prefix}_${found} required but this variation only guarantees ${prefix}_${max}" >&2
  echo "verify-abi: offending symbols:" >&2
  nm -D --undefined-only "$binary" \
    | grep -oE "[^ ]+@${prefix}_[0-9]+(\.[0-9]+)*" \
    | sort -u \
    | while read -r symbol; do
        version="${symbol##*@"${prefix}"_}"
        if [ "$(printf '%s\n%s\n' "$max" "$version" | sort -V | tail -1)" != "$max" ]; then
          echo "    ${symbol}"
        fi
      done >&2
  failed=1
}

check_floor GLIBC "$max_glibc"
check_floor GLIBCXX "$max_glibcxx"
check_floor CXXABI "$max_cxxabi"

if [ "$failed" -ne 0 ]; then
  echo "verify-abi: refusing to publish ${tarball}" >&2
  exit 1
fi

# Strongest available proof: run the binary against this image's own CentOS 7
# runtime. LD_LIBRARY_PATH is cleared because the build environment points it at
# the devtoolset libraries, which would mask exactly the failure we are hunting.
echo "verify-abi: smoke testing against the CentOS 7 runtime"
env -u LD_LIBRARY_PATH -u LD_PRELOAD "$binary" -e 'console.log("verify-abi: " + process.version + " runs on " + process.platform + "/" + process.arch)'

echo "verify-abi: ${tarball} is within the CentOS 7 ABI floors"
