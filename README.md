# C-is-bloated

## cib — C Is Bloated? Not anymore.

**cib** is a tool that strips C binaries down to the bare minimum — removing libc, startup code, debug info, and section headers — to produce a tiny static Linux binary.

It runs natively on **x86_64** and **aarch64**, and can cross-compile between the two.

---

## Table of Contents

- [The Problem](#the-problem)
- [The Solution](#the-solution)
- [How It Works](#how-it-works)
- [Supported Functions](#supported-functions)
  - [What's Not Supported](#whats-not-supported)
- [Trade-offs](#trade-offs)
- [Platform Support](#platform-support)
- [Requirements](#requirements)
  - [Native Toolchain](#native-toolchain)
  - [sstrip (Optional, Recommended)](#sstrip-optional-recommended)
  - [Cross-Compilation Toolchains](#cross-compilation-toolchains)
- [Installation](#installation)
  - [Verifying the Installation](#verifying-the-installation)
- [Usage](#usage)
- [Optimization Tiers](#optimization-tiers)
  - [Notes](#notes)
  - [Reference Data](#reference-data)
  - [Choosing a Tier](#choosing-a-tier)
  - [Default](#default)
- [Assembly Output Flags](#assembly-output-flags)
  - [Incompatibility with -Zx](#incompatibility-with--zx)
- [Example `hello.c`](#example-helloc)
- [Example 2 `ttt.c`](#example-2-tttc)
- [Command-Line Arguments](#command-line-arguments)
  - [GET_PARAMETERS()](#get_parameters)
  - [Variables](#variables)
  - [Example](#example)
- [License](#license)

---

## The Problem

When you compile a simple C program:

```c
int main() {
    puts("Hello, World!");
    return 0;
}
```

With default GCC, you get a binary that's **~900KB**. Most of that is:

- The C runtime (`_start`, `__libc_start_main`, etc.)
- libc overhead (stdio, locale, atexit handlers, etc.)
- Debug info, symbols, and section headers
- Alignment padding and metadata

**cib removes all of it.**

---

## The Solution

With `cib`, the same code compiles to **169 bytes** on x86-64 or **192 bytes** on aarch64 — statically linked, no libc, no startup overhead, no bloat.

```bash
$ cib hello.c
✅ Done!
-rwxr-xr-x 1 user user 169 Jun 25 17:10 hello
$ ./hello
Hello, World!
```

```bash
$ cib --target=aarch64 hello.c
🔎 Platform: Linux ELF x86_64  →  cross-compiling for aarch64
✅ Done!
-rwxr-xr-x 1 user user 192 Jun 25 17:10 hello
$ qemu-aarch64 ./hello
Hello, World!
```

The aarch64 byte count is higher because the byte-level tricks described below are x86-64-specific. The general technique — removing libc, injecting a minimal runtime, hijacking the exit path, stripping sections — applies equally to both. The order-of-magnitude reduction is the same.

---

## How It Works

The pipeline applies to both architectures. Steps 8–10 describe x86-64-specific byte optimizations; the aarch64 backend performs an equivalent set of transforms against the ARM syscall ABI.

1. **Injects a minimal runtime** — replaces libc with tiny syscall wrappers
2. **Compiles with extreme flags** — optimizes for size, removes all bloat
3. **Surgically strips the assembly** — removes debug info, directives, and metadata
4. **Removes the `ret` instruction** — replaces it with direct syscall exit
5. **Links with a custom linker script** — merges sections, discards GNU bloat
6. **Strips everything** — `strip` + `sstrip` remove symbols and section headers
7. **Truncates trailing garbage** — removes NOTE segments and null bytes

The remaining steps are x86-64 specific:

8. **String-Literal Constraint Optimization** — Replaces local stack variables inside system call wrappers (like `char nl = '\n'`) with direct string-literal constraints (`"S"("\n")`). This prevents the compiler from generating instructions to allocate stack frames and write to memory at runtime, shaving off **3 bytes** of instruction bloat.
9. **The C ABI & C99 `main` Hijack** — Bypasses the standard C calling convention (which mandates returning values through the `EAX` register) by rewriting every `return EXPR;` inside `main` into an inline-asm block that loads the exit code directly into the syscall destination register (`edi`) and issues `sys_exit` — `xor edi, edi` for `return 0`, `mov edi, EXPR` otherwise. Combined with renaming `main` to `_main` to suppress C99's implicit return-zero epilogue, this removes the standard function-exit sequence entirely, shaving off **2 bytes**. The rewrite is performed by an awk pass during source injection; control never returns through the C ABI.
10. **Stack-Squeezed Exit Syscall** — Replaces the standard 5-byte `mov eax, 60` instruction (`B8 3C 00 00 00`) with a 3-byte `push 60; pop rax` sequence (`6A 3C 58`). Because the immediate value `60` is small, the CPU utilizes the highly compressed `push imm8` opcode, leaving a net-zero footprint on the stack pointer while shaving off **2 bytes** of machine code.

The aarch64 backend uses a different set of byte-level tricks against its own syscall ABI (`svc #0` with `x8` for the syscall number, `x0`–`x5` for arguments, `exit = 93`, `write = 64`, `read = 63`, `brk = 214`), but the structural approach is identical.

---

## Supported Functions

cib provides a minimal set of functions. Use them as-is, or add your own.

| Function | Supported |
|----------|-----------|
| `sys_write()` | ✅ |
| `sys_read()` | ✅ |
| `sys_brk()` | ✅ |
| `puts()` | ✅ |
| `printf()` | ✅ But only - (`%c`, `%d`, `%s`) |
| `scanf()` | ✅ (basic) |
| `strlen()` | ✅ |
| `GET_PARAMETERS()` | ✅ (macro, both architectures) |

### What's Not Supported

- Anything below `main` — all helpers must go above it, never write code below `main`
- `FILE*` — use raw syscalls
- Any libc function not listed above

You can add more functions by editing the cib source, or by including them directly in your C code. Just don't rely on libc — otherwise your binary won't be small.

---

## Trade-offs

| Use cib if you want... | Use libc if you need... |
|------------------------|-------------------------|
| Tiny binaries | Full C standard library |
| Zero startup overhead | easy Multi-threading |
| Your code runs on the first CPU cycle | Portable code |
| To own everything | To save time writing wrappers |

---

## Platform Support

cib runs on Linux, targeting ELF64. Two architectures are supported:

| Architecture | Native | Cross-compile |
|--------------|--------|---------------|
| `x86_64`     | ✅     | ✅ (from aarch64) |
| `aarch64`    | ✅     | ✅ (from x86_64)  |

Both are first-class targets. `cib` auto-detects the host architecture and selects the native toolchain by default. Use `--target=` to pick a different one:

```bash
cib --target=aarch64 hello.c   # build ARM64 (from x86_64 or on aarch64 host)
cib --target=x86_64 hello.c    # build x86_64 (from aarch64 or on x86_64 host)
file hello                     # reports the actual target
```

The `--target=` flag accepts `x86_64`, `aarch64`, and the aliases `amd64` and `arm64`. The syscall ABI differs between the two targets, and cib handles that transparently — same source, same CLI, just a different `--target`.

**A note on size:** the byte-level optimizations described in *How It Works* (the `push 60; pop rax` exit sequence, the `edi` register-return trick, the literal-constraint stack squeeze) are **x86-64 specific**. The same program on aarch64 will be somewhat larger, though still far smaller than a libc build. If you cross-compile and see different sizes than the README's numbers, that's expected.

Anything else — 32-bit hosts, macOS, BSD, Windows, other ISAs — is rejected at startup.

---

## Requirements

### Native Toolchain

You need these on every machine that runs cib, regardless of target.

**Arch / Artix:**
```bash
sudo pacman -S gcc binutils
```

**Debian / Ubuntu:**
```bash
sudo apt install build-essential
```

**Fedora / RHEL:**
```bash
sudo dnf install gcc binutils
```

This gives you `gcc`, `as`, `ld`, and `strip`.

**Windows:** cib does not run on Windows directly. Use WSL (Windows Subsystem for Linux) with a Linux distribution, then follow the Debian/Ubuntu or Arch instructions above inside WSL.

### sstrip (Optional, Recommended)

`sstrip` strips the ELF section header table, which `strip` alone does not remove. Without it, cib still works but the binary is slightly larger.

**Arch / Artix:**
```bash
sudo pacman -S elfkickers
```

**Debian / Ubuntu / Fedora:**
Not packaged. Build from source:
```bash
git clone https://github.com/BR903/ELFkickers.git
cd ELFkickers/sstrip
make
sudo make install
```

If `sstrip` is not found, cib prints a warning and continues.

### Cross-Compilation Toolchains

You only need these if you plan to use `--target` to build for an architecture other than your host. Both directions are supported.

#### x86_64 → aarch64

Building ARM64 binaries on an x86_64 machine.

**Arch / Artix:**
```bash
sudo pacman -S aarch64-linux-gnu-gcc
```

This package provides the entire cross-toolchain: `aarch64-linux-gnu-gcc`, `aarch64-linux-gnu-as`, `aarch64-linux-gnu-ld`, and `aarch64-linux-gnu-strip`.

**Debian / Ubuntu:**
```bash
sudo apt install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu
```

**Fedora / RHEL:**
```bash
sudo dnf install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu
```

#### aarch64 → x86_64

Building x86_64 binaries on an ARM64 machine.

**Arch / Artix:**
```bash
yay -S x86_64-linux-gnu-gcc    # AUR; provides the full x86_64 cross-toolchain
```

**Debian / Ubuntu:**
```bash
sudo apt install gcc-x86-64-linux-gnu binutils-x86-64-linux-gnu
```

**Fedora / RHEL:**
```bash
sudo dnf install gcc-x86-64-linux-gnu binutils-x86-64-linux-gnu
```

---

## Installation

```bash
sudo cp cib /usr/local/bin/cib
sudo chmod +x /usr/local/bin/cib
```

Or copy it anywhere on your `PATH`. It is a single self-contained bash script with no other dependencies.

### Verifying the Installation

Compile the bundled `hello.c`:

```bash
cib hello.c
```

Then run the result:

```bash
./hello
```

If you installed a cross-toolchain, verify that too:

```bash
cib --target=aarch64 hello.c
file hello       # should report: ELF 64-bit LSB executable, ARM aarch64
```

Or, from an ARM host:

```bash
cib --target=x86_64 hello.c
file hello       # should report: ELF 64-bit LSB executable, x86-64
```

If the cross-toolchain is missing, cib will tell you exactly which binary it couldn't find and what package to install.

---

## Usage

```bash
# Basic compilation (native host, default tier)
cib main.c                    # Compile to tiny binary (default -Z0)
cib main.s -as                # Assemble an existing .s file

# Architecture selection
cib --target=aarch64 main.c   # Cross-compile to ARM64
cib --target=x86_64 main.c    # Cross-compile to x86_64

# Optimization tiers
cib -Z0 main.c                # Smallest-priority (default)
cib -Z1 main.c                # Size-priority, normal encodings
cib -Z2 main.c                # Compile-speed priority (-O0)
cib -Z3 main.c                # Light runtime optimization (-O1)
cib -Z4 main.c                # Balanced (-O2)
cib -Z5 main.c                # Max runtime optimization (-O3)

# Assembly output
cib -S main.c                 # Emit assembly at current -Z tier and stop
cib -E main.c                 # Emit readable assembly (-Og) and stop
cib -EC main.c                # Emit readable assembly (-Og) and continue to binary

# Raw C inspection
cib -R main.c                 # Print the generated raw C and stop
cib -RC main.c                # Compile the raw C as-is (no return mangling)
```

---

## Optimization Tiers

cib exposes six optimization tiers through `-Z0` through `-Z5`. Each tier
trades binary size, compile time, and runtime performance differently.

| Flag | GCC flag | Description |
|------|----------|-------------|
| `-Z0` | `-Oz` | Prioritizes small binary size. The compiler is allowed to emit more instructions if they encode in fewer bytes. This is the default. |
| `-Z1` | `-Os` | Optimizes for size, but the compiler is no longer allowed to shrink individual instructions on purpose. Uses normal-size encodings. |
| `-Z2` | `-O0` | Size no longer matters. Optimization for compiler speed. GCC runs no optimization passes at all. Fastest compile, largest and slowest output. |
| `-Z3` | `-O1` | Size no longer matters. Prioritizes compiler speed with a small amount of runtime optimization. |
| `-Z4` | `-O2` | Size no longer matters. Balanced between compiler speed and execution speed. |
| `-Z5` | `-O3` | Size no longer matters. Maximum runtime optimization, at the cost of longer compile times. |

### Notes

- **`-Z0` and `-Z1` are the size-priority tiers.** Everything from `-Z2` up assumes binary size is not a concern.
- **`-Z0` is not guaranteed to be the smallest.** `-Oz` optimizes aggressively for size, but not optimally. GCC's `-Oz` heuristic makes per-instruction decisions that can be globally suboptimal. On a program with many identical loops, `-Z4` (`-O2`) has been measured to produce a binary ~8% smaller than `-Z0`, because `-Oz` allocates the loop counter to an extended register (`r8`–`r15`) which requires a REX prefix on every instruction that touches it, while `-O2` allocates to a legacy register (`rbx`/`rcx`/`rdx`) which does not. This finding is specific to x86-64; aarch64 register allocation does not have the same REX-prefix cost. If binary size is critical, benchmark `-Z0` and `-Z4` for your specific program.
- **`-Z0` emits more instructions than `-Z4`/`-Z5`.** The `push imm8; pop reg` substitution that saves bytes at `-Z0` costs an extra instruction and two stack operations per use. For syscall-bound programs the difference is invisible; for compute-bound code it matters.
- **`-Z3` can be an awkward middle ground.** GCC's `-O1` occasionally produces output that is neither small nor fast — for example, emitting a runtime loop to compute a value the compiler could have constant-folded. This is a GCC phase-ordering artifact, not a cib issue.
- **`-Z4` and `-Z5` may produce identical output** for simple programs that have nothing to unroll or vectorize. They diverge on workloads with loops and math.
- **Bigger binary does not always mean slower execution.** A `-Z5` binary can be larger on disk than a `-Z4` binary while executing fewer instructions and fewer cycles per run, because `-O3`'s extra passes produce tighter dynamic code at the cost of static size.
- **Smaller binary does not always mean faster wall-clock execution.** For programs launched repeatedly (thousands of times per second), the smaller binary wins on process startup cost. For programs launched once and run for a long time, the binary with fewer instructions per iteration wins. Neither tier dominates across all usage patterns.
- The tier names (`-Z0` … `-Z5`) are cib-specific. They do not match GCC's `-O` levels, though each maps to one.

### Reference Data

The following was measured on x86-64, Artix Linux, GCC 16.2.1, using a
1000-line C test file with 332 identical 5-iteration loops. The relative
ordering of tiers is expected to hold on aarch64, but absolute numbers
will differ.

**Compile time (1000 iterations):**

| Tier | Total | Per compile |
|------|------:|------------:|
| `-Z2` | 83.2s | 83ms |
| `-EC` | 99.6s | 100ms |
| `-Z3` | 159.8s | 160ms |
| `-Z1` | 218.3s | 218ms |
| `-Z0` | 220.7s | 221ms |
| `-Z4` | 225.3s | 225ms |
| `-Z5` | 237.2s | 237ms |

**Binary size (x86-64):**

| Tier | Bytes |
|------|------:|
| `-Z4` | 8682 |
| `-Z0` | 9466 |
| `-Z1` | 9466 |
| `-Z5` | 10025 |
| `-Z3` | 10674 |
| `-EC` | 11282 |
| `-Z2` | 17589 |

**Runtime** (`perf stat -r 10000`, output to /dev/null, x86-64):

| Tier | Task-clock | Instructions | Cycles |
|------|-----------:|-------------:|-------:|
| `-Z4` | **9.545ms** | 443,565 | 1,358,308 |
| `-Z0` | 9.571ms | 445,224 | 1,382,819 |
| `-Z5` | 9.594ms | **433,604** | **1,334,310** |

All three tiers show 1 page fault per run.

### Choosing a Tier

| Goal | Tier |
|------|------|
| Fastest compile | `-Z2` |
| Smallest binary on typical code | `-Z0` |
| Smallest binary on loop-heavy code | benchmark `-Z0` vs `-Z4` (x86-64) |
| Fastest wall-clock for a repeatedly launched binary | `-Z4` |
| Fewest instructions per run for a long-running binary | `-Z5` |
| Readable assembly | `-E` or `-EC` |

No tier is best at everything. The only way to know which tier wins for a
specific program is to compile each candidate and measure. cib does not
choose for you.

### Default

If no `-Z` flag is given, cib uses `-Z0`.

---

## Assembly Output Flags

`-E` and `-EC` control whether cib stops after generating assembly or continues to a full binary. They are separate from the optimization tier.

| Flag | What it does |
|------|--------------|
| `-E` | Generate assembly using `-Og`, write it to a `.s` file, and stop. The `.s` file is kept for inspection. |
| `-EC` | Same as `-E`, but continue past the assembly step: assemble, link, strip, and produce the executable. The `.s` file is still kept. |

The `C` in `-EC` means "continue" — the same convention used by `-RC`, which prints the raw C and optionally continues to compile it.

`-E` uses `-Og` internally. `-Og` is GCC's "optimize for debugging" level: it performs light optimization but deliberately avoids passes that obscure the relationship between source lines and generated instructions. Breakpoints land where you set them, variables are not optimized out, and the assembly is far closer to a one-to-one mapping with your source. The trade-off is that `-Og` does not constant-fold loops, so output is bigger and slower than `-Z4` or `-Z5`. It is, however, fast to compile — `-EC` was the second-fastest tier in the reference measurements above, behind only `-Z2`.

Use `-E` when you want to read what the compiler actually did. Use `-EC` when you want to read it *and* run it.

### Incompatibility with -Zx

`-E` and `-EC` are **mutually exclusive with `-Z0` through `-Z5`.** Passing both produces an error:

```
cib: error: -E/-EC and -Zx are mutually exclusive
```

The reason is that `-E` and `-EC` hardcode `-Og`, while `-Zx` selects a different optimization level. There is no way to combine "readable debugger-friendly assembly" with "maximum runtime speed" — they are opposite goals. If you want assembly output at a specific `-Z` tier, use `-S` instead:

| Flag | Optimization | Output |
|------|--------------|--------|
| `-S` | current `-Z` tier (or `-Z0` default) | `.s` file, stop |
| `-E` | `-Og` | `.s` file, stop |
| `-EC` | `-Og` | `.s` file, continue to binary |

---

## Example `hello.c`

```c
int main() {
    puts("Hello, World!");
    return 0;
}
```

```bash
cib hello.c
```

### Becomes 169 bytes statically linked binary (x86-64)

```bash
cib --target=aarch64 hello.c
```

### Becomes 192 bytes statically linked binary (aarch64)

---

## Example 2 `ttt.c`

From the project folder, it's a Tic-Tac-Toe written by me quickly, just to see if I can make it smaller.

```bash
cib ttt.c
```

### Becomes 1572 bytes statically linked binary (x86-64)

---

## Command-Line Arguments

cib automatically provides access to command-line arguments via a macro. The macro is architecture-specific and cib selects the right one automatically.

### `GET_PARAMETERS()`

On **x86_64**, the macro extracts `argc` and `argv` from the stack at process entry:

```c
#define GET_PARAMETERS() \
    __asm__ volatile ( \
        "mov rax, [rsp]\n" \
        "mov [__argc], rax\n" \
        "lea rax, [rsp+8]\n" \
        "mov [__argv], rax\n" \
    )
```

On **aarch64**, it uses `adrp` / `:lo12:` to reach the globals:

```c
#define GET_PARAMETERS() \
    __asm__ volatile ( \
        "ldr x9, [sp]\n" \
        "adrp x10, __argc\n" \
        "str x9, [x10, :lo12:__argc]\n" \
        "add x9, sp, #8\n" \
        "adrp x10, __argv\n" \
        "str x9, [x10, :lo12:__argv]\n" \
        : : : "x9", "x10", "memory" \
    )
```

You don't need to include either of them — cib injects the correct one for the target. All you write is:

```c
int main() {
    GET_PARAMETERS();
    
    if (__argc > 1) {
        printf("%s\n", __argv[1]);
    }
    
    return 0;
}
```

### Variables

- `__argc` — number of command-line arguments (int)
- `__argv` — array of argument strings (char**)

### Example

```bash
$ cib hello.c
✅ Done!
$ ./hello world
world
$ ./hello 42
42
```

Same source, same behavior on aarch64:

```bash
$ cib --target=aarch64 hello.c
✅ Done!
$ qemu-aarch64 ./hello world
world
```

---

## C is or was bloated. You decide.

## License

This project is licensed under the [GNU General Public License v3.0 (GPLv3)](https://www.gnu.org/licenses/gpl-3.0.html).
