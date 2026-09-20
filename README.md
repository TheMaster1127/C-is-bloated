# C-is-bloated

## cib — C Is Bloated? Not anymore.

**cib** is a tool that strips C binaries down to the bare minimum — removing libc, startup code, debug info, and section headers — to produce a tiny static Linux binary.

It runs on **x86_64** and **aarch64**, and can cross-compile between the two.

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

With `cib`, the same code compiles to **169 bytes** on x86-64 — statically linked, no libc, no startup overhead, no bullshit.

```bash
$ cib hello.c
✅ Done!
-rwxr-xr-x 1 user user 169 Jun 25 17:10 hello
$ ./hello
Hello, World!
```

On aarch64 the byte count differs — the x86-64-specific tricks described below don't all translate — but the same order-of-magnitude reduction applies. See [Platform Support](#platform-support).

---

## How It Works

The following describes the x86-64 backend. The aarch64 backend performs the equivalent set of transforms against the ARM syscall ABI, with different byte-level tricks.

1. **Injects a minimal runtime** — replaces libc with tiny syscall wrappers
2. **Compiles with extreme flags** — optimizes for size, removes all bloat
3. **Surgically strips the assembly** — removes debug info, directives, and metadata
4. **Removes the `ret` instruction** — replaces it with direct syscall exit
5. **Links with a custom linker script** — merges sections, discards GNU bloat
6. **Strips everything** — `strip` + `sstrip` remove symbols and section headers
7. **Truncates trailing garbage** — removes NOTE segments and null bytes
8. **String-Literal Constraint Optimization** — Replaces local stack variables inside system call wrappers (like `char nl = '\n'`) with direct string-literal constraints (`"S"("\n")`). This prevents the compiler from generating instructions to allocate stack frames and write to memory at runtime, shaving off **3 bytes** of instruction bloat.
9. **The C ABI & C99 `main` Hijack** — Bypasses standard C calling conventions (which mandate returning values through the `EAX` register) by declaring a global register variable `register int _edi asm("edi")` and macro-redefining `return` to `_edi =`. By also renaming `main` to `_main` to bypass implicit C99 return-zero bloat, GCC is forced to write exit codes directly into the destination syscall register (`edi`) using an optimized `xor edi, edi`, shaving off **2 bytes**.
10. **Stack-Squeezed Exit Syscall** — Replaces the standard 5-byte `mov eax, 60` instruction (`B8 3C 00 00 00`) with a 3-byte `push 60; pop rax` sequence (`6A 3C 58`). Because the immediate value `60` is small, the CPU utilizes the highly compressed `push imm8` opcode, leaving a net-zero footprint on the stack pointer while shaving off **2 bytes** of machine code.

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
| `GET_PARAMETERS()` | ✅ (macro) |

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

Select a non-host architecture with `--target=`:

```bash
cib --target=aarch64 hello.c
file hello   # ELF 64-bit LSB executable, ARM aarch64
```

The syscall ABI differs between the two targets, and cib handles that transparently — same source, same CLI, just a different `--target`.

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

You only need these if you plan to use `--target` to build for an architecture other than your host.

#### x86_64 → aarch64 (the common case)

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

**Debian / Ubuntu:**
```bash
sudo apt install gcc-x86-64-linux-gnu binutils-x86-64-linux-gnu
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

If the cross-toolchain is missing, cib will tell you exactly which binary it couldn't find and what package to install.

---

## Usage

```bash
cib main.c               # Compile to tiny binary
cib -S main.c            # Generate assembly (.s) and stop
cib main.s -as           # Assemble existing .s file
cib -R main.c            # Print the generated raw C and stop
cib -RC main.c           # Compile the raw C as-is (no return mangling)
cib --target=aarch64 main.c   # Cross-compile to ARM64
```

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

---

## Example 2 `ttt.c` — From the project folder, it's a Tic-Tac-Toe written by me quickly, just to see if I can make it smaller.

```bash
cib ttt.c
```

### Becomes 1572 bytes statically linked binary (x86-64)

---

## Command-Line Arguments

cib automatically provides access to command-line arguments via a macro.

### `GET_PARAMETERS()`

Uses this macro in x86_64 at the **start** of `main()` to extract `argc` and `argv`:

```c
int __argc;
char **__argv;

#define GET_PARAMETERS() \
    __asm__ volatile ( \
        "mov rax, [rsp]\n" \
        "mov [__argc], rax\n" \
        "lea rax, [rsp+8]\n" \
        "mov [__argv], rax\n" \
    )

int main() {
    GET_PARAMETERS();
    
    if (__argc > 1) {
        printf("%s\n", __argv[1]);
    }
    
    return 0;
}
```

But you do not need to include that code. It's already included for you. So all you have to do is this:

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

---

## C is or was bloated. You decide.

## License

This project is licensed under the [GNU General Public License v3.0 (GPLv3)](https://www.gnu.org/licenses/gpl-3.0.html).
