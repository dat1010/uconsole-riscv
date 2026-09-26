# Codex CLI for a RISC-V uConsole

Experimental source port for a **riscv64 Linux uConsole**, cross-compiled on an
x86_64 Steam Deck. This is a community build, not an official OpenAI binary.

Upstream: <https://github.com/openai/codex>, commit
`25270df2615eb4da5b9d4a9a392226933fb096c5`.
The source version is `0.0.0`; use the commit above to identify this build.

## Target and scope

- Rust target: `riscv64gc-unknown-linux-gnu` (RV64GC, LP64D ABI).
- Build sysroot: Ubuntu 22.04, glibc 2.35.
- Includes the native CLI and its companion RISC-V bubblewrap executable.
- Adds RISC-V selection to the existing seccomp filter compiler. Sandbox
  restrictions remain enabled. The build embeds the bundled bubblewrap SHA-256.
- Does not include the optional V8-based `codex-code-mode-host` executable.
- Building and running version checks under QEMU does not establish that the
  uConsole kernel supports the required namespaces and seccomp. Run the device
  check below before using the build for agent work.

## Run on the uConsole

Confirm `uname -m` prints `riscv64` and check `/etc/os-release` on the device.
This package targets Ubuntu 22.04; it is not an ARM package.

On Ubuntu 22.04, install the runtime libraries and tools if missing:

```sh
sudo apt update
sudo apt install libssl3 libcap2 libgcc-s1 ca-certificates git ripgrep python3 xz-utils
```

Both executables require glibc symbols up to `GLIBC_2.34`; Ubuntu 22.04 provides
glibc 2.35. A compatible userspace does not guarantee compatible kernel sandbox
features.

Download the [archive](https://github.com/dat1010/uconsole-riscv/blob/main/uconsole/artifacts/codex-uconsole-riscv64.tar.xz) and
[archive checksum](https://github.com/dat1010/uconsole-riscv/blob/main/uconsole/artifacts/codex-uconsole-riscv64.tar.xz.sha256) from this
repository. In the download directory:

```sh
sha256sum -c codex-uconsole-riscv64.tar.xz.sha256
tar -xJf codex-uconsole-riscv64.tar.xz
cd codex-uconsole-riscv64
```

Keep `codex-resources/bwrap` next to the `codex` executable.

```sh
sha256sum -c SHA256SUMS
./codex --version
./check-on-uconsole.sh
./codex login --device-auth
./codex
```

The device check runs a read-only, network-restricted subprocess. It must report
that filesystem writes and IPv4 sockets are blocked. If it fails, preserve the
error output and investigate the kernel or missing libraries before continuing.

## Build on an x86_64 Linux machine

Install Podman using your host's supported package mechanism. The container
contains Rust 1.95.0, the Ubuntu RISC-V cross toolchain, and QEMU. The initial
build downloads many dependencies and can take a long time on a Steam Deck.
Two compilation jobs limit memory use; retain the build directory for retries.

From the repository root:

```sh
mkdir -p uconsole/build
podman build -t localhost/codex-riscv64-builder:ubuntu22 -f uconsole/Containerfile .
podman run --rm \
  -v "$PWD:/src" \
  -v "$PWD/uconsole/build:/build" \
  localhost/codex-riscv64-builder:ubuntu22 bash /src/uconsole/build.sh
```

The script builds and strips bubblewrap before embedding its hash, builds the
CLI, checks executable startup, and creates an archive plus checksums in
`uconsole/build/`. It then runs the Linux sandbox library tests under QEMU.
With Ubuntu 22.04's QEMU 6.2, 160 of 162 tests passed; two failed in emulator
process-launch and file-descriptor handling. The script preserves the test
failure status, but the archive remains available. See the
[validation report](https://github.com/dat1010/uconsole-riscv/blob/main/uconsole/VALIDATION.md)
for diagnostics and the remaining device checks.

Cargo uses the pinned
repository lockfile. Container packages and auxiliary test tools are not pinned
to immutable versions, so this is a repeatable procedure, not a claim of
bit-for-bit reproducibility.

The root `LICENSE` and `NOTICE` apply to the upstream source. Preserve them with
redistributed binaries and source.
