# Build validation

Built on a Steam Deck (x86_64 Linux) on September 25–26, 2026.

## Configuration

- Upstream source: `25270df2615eb4da5b9d4a9a392226933fb096c5`.
- Port change: select `seccompiler::TargetArch::riscv64` for the existing network
  seccomp filter. No sandbox restrictions are removed.
- Rust 1.95.0; target `riscv64gc-unknown-linux-gnu`.
- Ubuntu 22.04 build container and GCC 11 RISC-V cross toolchain.
- Cargo release profile, LTO disabled, debug information stripped for packaging.

## Completed checks

- CLI and companion bubblewrap cross-compilation succeeded.
- Both packaged executables are stripped RISC-V ELF64, RVC, double-float ABI.
- Highest required glibc symbol version: `GLIBC_2.34`.
- Both `--version` commands pass under QEMU user emulation.
- CLI, sandbox, and device-login help commands were inspected under emulation.
- The final CLI embeds the SHA-256 of the packaged bubblewrap executable.
- `just fmt`, shell syntax checks, and `git diff --check` passed.
- Archive extracted successfully; both executable checksums passed.

## Sandbox test results

Command: `just test --locked --release --target riscv64gc-unknown-linux-gnu
-p codex-linux-sandbox --lib --test-threads 2`, using QEMU 6.2.0.

**162 tests ran: 160 passed, 2 failed, none skipped.** Both failures reproduced
when rerun sequentially. They are not hidden or marked passing in the build
script; its final exit status reflects the failed tests after the archive has
been created.

- `bwrap::wslg_tests::glob_ancestor_mask_in_no_rg_fallback`: the QEMU syscall
  trace shows the test's child `execve` returning `ENOEXEC` (Exec format error).
  This host has no transparent RISC-V binary-format handler. Directly running
  the isolated child branch also failed in the missing-ripgrep fallback. This
  case remains unvalidated.
- `proxy_lifecycle::tests::malformed_handoff_closes_all_received_descriptors::truncated_control_message`:
  an independent C reproduction transfers eight descriptors into a truncated
  receive buffer. Native x86_64 closes all excess descriptors; QEMU 6.2 for both
  x86_64 and riscv64 leaves six peers open and loses the truncation flag. This
  reproduces the failure without Codex or Rust and points to emulator behavior.

Reproduction: [diagnostics/fd-truncation.c](diagnostics/fd-truncation.c).
Compile with `cc` for a native baseline and `riscv64-linux-gnu-gcc` for RISC-V,
then run the latter with `qemu-riscv64 -L /usr/riscv64-linux-gnu`.

```text
Native x86_64: received=2 truncated=1 peers_still_open=0
QEMU x86_64:   received=2 truncated=0 peers_still_open=6
QEMU riscv64:  received=2 truncated=0 peers_still_open=6
```

The library tests do not replace native kernel sandbox integration tests. The
full integration suite and real-device sandbox checks have not been run.

## Device validation still required

The actual uConsole has not been accessed or tested. QEMU user emulation does
not validate RISC-V kernel namespace/seccomp behavior. Run
`check-on-uconsole.sh` on the device before agent work. Interactive login and a
complete model-driven session have not been tested on that device.

The optional V8-based `codex-code-mode-host` is not included.

## Artifact

`codex-uconsole-riscv64.tar.xz` SHA-256:

```text
d6eebc6455be81fba03487d6d9f42ace28eccba17c4a79fb46ae52fbbe900233
```
