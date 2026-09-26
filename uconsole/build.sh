#!/bin/bash
set -euo pipefail

# Run in the companion container with the repository at /src and a writable
# output/cache directory at /build. Keep both mounts between builds.
cd /src/codex-rs
export CARGO_TARGET_DIR=/build/target
export CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS:-2}
target=riscv64gc-unknown-linux-gnu

cargo build --locked --release --target-dir /build/bwrap-target \
    --target "$target" -p codex-bwrap --bin bwrap 2>&1 | tee /build/bwrap-build.log
riscv64-linux-gnu-strip --strip-debug --strip-unneeded \
    "/build/bwrap-target/$target/release/bwrap"
CODEX_BWRAP_SHA256=$(sha256sum "/build/bwrap-target/$target/release/bwrap" | cut -d ' ' -f 1)
export CODEX_BWRAP_SHA256
cargo build --locked --release --target "$target" -p codex-cli --bin codex \
    2>&1 | tee /build/build.log

package_dir=/build/package/codex-uconsole-riscv64
mkdir -p "$package_dir/codex-resources"
cp "/build/target/$target/release/codex" "$package_dir/codex"
riscv64-linux-gnu-strip --strip-debug --strip-unneeded "$package_dir/codex"
cp "/build/bwrap-target/$target/release/bwrap" "$package_dir/codex-resources/bwrap"
cp /src/LICENSE /src/NOTICE /src/uconsole/README.md "$package_dir/"
cp /src/codex-rs/vendor/bubblewrap/COPYING "$package_dir/BUBBLEWRAP-LICENSE"
cp /src/uconsole/check-on-uconsole.sh "$package_dir/"
chmod +x "$package_dir/check-on-uconsole.sh"
file "$package_dir/codex" "$package_dir/codex-resources/bwrap" | tee /build/binary-info.txt
qemu-riscv64 -L /usr/riscv64-linux-gnu "$package_dir/codex" --version
qemu-riscv64 -L /usr/riscv64-linux-gnu "$package_dir/codex-resources/bwrap" --version
(
    cd "$package_dir"
    sha256sum codex codex-resources/bwrap > SHA256SUMS
)
tar -C /build/package -cf - codex-uconsole-riscv64 | xz -T2 > /build/codex-uconsole-riscv64.tar.xz
cd /build
sha256sum codex-uconsole-riscv64.tar.xz > codex-uconsole-riscv64.tar.xz.sha256

# Keep a usable archive even when the emulator cannot run every test. Preserve
# the failing test exit status; see VALIDATION.md for QEMU 6.2 limitations.
cd /src/codex-rs
export CARGO_TARGET_RISCV64GC_UNKNOWN_LINUX_GNU_RUNNER='qemu-riscv64 -L /usr/riscv64-linux-gnu'
just test --locked --release --target "$target" -p codex-linux-sandbox --lib \
    --test-threads 2 2>&1 | tee /build/sandbox-tests.log
