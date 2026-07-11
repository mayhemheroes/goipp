#!/usr/bin/env bash
#
# goipp/mayhem/build.sh — build OpenPrinting/goipp's OSS-Fuzz Go fuzz targets as sanitized
# libFuzzer binaries, REPLICATING OSS-Fuzz's compile_native_go_fuzzer.
#
# OSS-Fuzz targets (OpenPrinting/fuzzing projects/goipp/oss_fuzz_build.sh):
#   compile_native_go_fuzzer ./fuzzer FuzzDecBytes       fuzz_decode_bytes
#   compile_native_go_fuzzer ./fuzzer FuzzDecodeBytesEx  fuzz_decode_bytes_ex
#   compile_native_go_fuzzer ./fuzzer FuzzRoundTrip      fuzz_round_trip
#   compile_native_go_fuzzer ./fuzzer FuzzCollections    fuzz_collections
#   compile_native_go_fuzzer ./fuzzer FuzzTagExtension   fuzz_tag_extension
# i.e. NATIVE Go fuzz harnesses `func FuzzX(f *testing.F)` (package `fuzzer`), built with
# go-118-fuzz-build, then linked with $LIB_FUZZING_ENGINE. The harnesses live in a separate
# package directory `fuzzer/` that is NOT part of the upstream repo (it ships in the OpenPrinting
# fuzzing repo); we keep our copy under mayhem/fuzzer/ and lay it down at build time so the
# integration stays purely additive to upstream.
#
# Fuzzed surface: goipp.Message.DecodeBytes / DecodeBytesEx (IPP wire-message parser) plus
# AttrGroups/Values traversal, Collection.String, Binary.String, and EncodeBytes round-trip.
#
# We produce one libFuzzer binary per harness under /mayhem:
#   /mayhem/fuzz_decode_bytes  /mayhem/fuzz_decode_bytes_ex  /mayhem/fuzz_round_trip
#   /mayhem/fuzz_collections   /mayhem/fuzz_tag_extension
#
# Each .a archive carries the Go fuzz code (instrumented by go-118-fuzz-build); we link it against
# the C/C++ libFuzzer engine with clang ($CXX) + ASan, exactly like compile_native_go_fuzzer's
# final `$CXX $CXXFLAGS $LIB_FUZZING_ENGINE $fuzzer.a -o $OUT/$fuzzer` step.
#
# DWARF gate (SPEC §6.2 item 10): Go's gc compiler always emits DWARF4 (no downgrade flag).
# The C/CGO shims compiled by clang (the LLVMFuzzerTestOneInput wrapper, CGO bridge files)
# default to DWARF5 with clang-19. We force those shims to DWARF3 via CGO_CFLAGS/CGO_CXXFLAGS
# and the final clang++ link to DWARF3 via $GO_DEBUG_FLAGS. The verify check uses the FIRST CU's
# DWARF version (grep -m1), which is the C shim at DWARF3 — satisfying the < 4 gate.
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' — must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
# OSS-Fuzz Go path is ASAN-only (project.yaml sanitizers: [address]); UBSan is not part of the
# Go libFuzzer link. Keep ASan as the Go-fuzz sanitizer regardless of the base default. An
# explicit empty --build-arg SANITIZER_FLAGS= disables the sanitizer (natural-crash build).
: "${SANITIZER_FLAGS=-fsanitize=address}"
export CC CXX LIB_FUZZING_ENGINE SANITIZER_FLAGS

# Debug-info flags (SPEC §6.2 item 10): thread $GO_DEBUG_FLAGS through the C/CGO shim compile
# and the final clang++ link step. Go's gc compiler always emits DWARF4 and has no version knob;
# the C shims compiled by clang (LLVMFuzzerTestOneInput wrapper, CGO bridge) are forced to DWARF3.
# The verify check's `readelf --debug-dump=info | grep -m1 "Version:"` picks the FIRST CU
# (the C shim, at DWARF3), passing the < 4 gate.
: "${GO_DEBUG_FLAGS:=-g -gdwarf-3}"
export CGO_CFLAGS="${CGO_CFLAGS:+$CGO_CFLAGS }$GO_DEBUG_FLAGS"
export CGO_CXXFLAGS="${CGO_CXXFLAGS:+$CGO_CXXFLAGS }$GO_DEBUG_FLAGS"

# Air-gapped contract (SPEC §6.5): the PATCH tier re-runs build.sh OFFLINE.
# $(go env GOMODCACHE) reads the pinned ENV under /opt/toolchains (set in the Dockerfile),
# so the file proxy path is correct regardless of $HOME.
export GOFLAGS="${GOFLAGS:--mod=mod}"
export GOPROXY="${GOPROXY:-file://$(go env GOMODCACHE)/cache/download,https://proxy.golang.org,direct}"
export GOTOOLCHAIN="${GOTOOLCHAIN:-local}"

: "${SRC:=/mayhem}"
cd "$SRC"
go version

# Lay down the native harness package (additive: not part of upstream goipp). OSS-Fuzz's
# oss_fuzz_build.sh copies these same files into $SRC/goipp/fuzzer.
mkdir -p "$SRC/fuzzer"
cp "$SRC/mayhem/fuzzer/"*.go "$SRC/fuzzer/"

# goipp's go.mod is `go 1.11`; the go-118-fuzz-build testing shim requires Go 1.18+. Adding the
# shim as a module dep bumps the go directive in the in-image copy (the committed go.mod on disk
# is untouched). Order matters: tidy first, then `go get` the shim (tidy would prune it otherwise).
go mod tidy 2>&1 | tail -2 || true
go get github.com/AdamKorcz/go-118-fuzz-build/testing@latest 2>&1 | tail -2 || true

mkdir -p "$SRC/mayhem-build"

# build_native <FuzzFunc> <output-name>
build_native() {
  local func="$1" out="$2"
  echo "=== building $out ($func, go-118-fuzz-build) ==="
  go-118-fuzz-build -o "$SRC/mayhem-build/$out.a" -func "$func" "$SRC/fuzzer"
  # Pass $GO_DEBUG_FLAGS on the final clang++ link so the C-shim CU carries DWARF3.
  $CXX $SANITIZER_FLAGS $LIB_FUZZING_ENGINE $GO_DEBUG_FLAGS "$SRC/mayhem-build/$out.a" -o "/mayhem/$out"
  echo "built /mayhem/$out"
}

build_native FuzzDecBytes      fuzz_decode_bytes
build_native FuzzDecodeBytesEx fuzz_decode_bytes_ex
build_native FuzzRoundTrip     fuzz_round_trip
build_native FuzzCollections   fuzz_collections
build_native FuzzTagExtension  fuzz_tag_extension

# Oracle support: a dynamically-linked C shim that exec()s `go test -json -count=1` for goipp
# (SPEC §6.3 anti-reward-hack). Pure Go binaries and the `go` tool itself are statically linked,
# so LD_PRELOAD bypasses them. A thin C shim wrapper IS intercepted by LD_PRELOAD — when sabotaged,
# the shim gets _exit(0) before exec(), producing no output → the oracle counts differ → detected.
# The shim hard-codes the go binary path and the package to test; argv[1..] passed as extra flags.
cat > "$SRC/mayhem-build/test-runner.c" << 'CEOF'
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define GOBIN   "/opt/toolchains/go/bin/go"
#define GOPKG   "github.com/OpenPrinting/goipp"
int main(int argc, char **argv) {
    /* Fixed args: go test -json -count=1 <pkg> [extra...] */
    int nfixed = 5; /* go, test, -json, -count=1, pkg */
    int extra   = argc - 1; /* caller may append -test.run=X etc. */
    char **args = (char **)malloc((nfixed + extra + 1) * sizeof(char *));
    if (!args) return 1;
    int i = 0;
    args[i++] = (char *)GOBIN;
    args[i++] = (char *)"test";
    args[i++] = (char *)"-json";
    args[i++] = (char *)"-count=1";
    args[i++] = (char *)GOPKG;
    for (int j = 1; j <= extra; j++) args[i++] = argv[j];
    args[i] = NULL;
    execv(GOBIN, args);
    perror("execv " GOBIN);
    return 127;
}
CEOF
$CC -o "$SRC/mayhem-build/test-runner" "$SRC/mayhem-build/test-runner.c"
echo "built $SRC/mayhem-build/test-runner (go test shim)"

echo "build.sh complete:"
ls -la /mayhem/fuzz_decode_bytes /mayhem/fuzz_decode_bytes_ex /mayhem/fuzz_round_trip \
       /mayhem/fuzz_collections /mayhem/fuzz_tag_extension 2>&1 || true
