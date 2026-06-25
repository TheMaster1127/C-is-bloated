# C-is-bloated

## cib — C Is Bloated? Not anymore.

**cib** is a tool that strips C binaries down to the bare minimum — removing libc, startup code, debug info, and section headers — to produce a tiny static Linux binary.

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

With `cib`, the same code compiles to **180 bytes** — statically linked, no libc, no startup overhead, no bullshit.

```bash
$ cib hello.c
✅ Done!
-rwxr-xr-x 1 user user 180 Jun 25 17:10 hello
$ ./hello
Hello, World!
```

---

## How It Works

1. **Injects a minimal runtime** — replaces libc with tiny syscall wrappers
2. **Compiles with extreme flags** — optimizes for size, removes all bloat
3. **Surgically strips the assembly** — removes debug info, directives, and metadata
4. **Removes the `ret` instruction** — replaces it with direct syscall exit
5. **Links with a custom linker script** — merges sections, discards GNU bloat
6. **Strips everything** — `strip` + `sstrip` remove symbols and section headers
7. **Truncates trailing garbage** — removes NOTE segments and null bytes

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
| `malloc()` | ✅⚠️ |
| `free()` | ✅⚠️ |

> ⚠️ `malloc()` and `free()` are implemented via `sys_brk()`. They work, but they're minimal — no heap consolidation, no free list merging. Use them for simple allocations.

---

### What's Not Supported

- `malloc()` / `free()` — use `sys_brk()` if you need custom allocation
- `FILE*` — use raw syscalls
- Floating point — add it yourself
- Any libc function not listed above

You can add more functions by editing the cib source, or by including them directly in your C code. Just don't rely on libc — otherwise your binary won't be small.

---

## Trade-offs

| Use cib if you want... | Use libc if you need... |
|------------------------|-------------------------|
| Tiny binaries | Full C standard library |
| Zero startup overhead | malloc() / free() |
| Your code runs on the first CPU cycle | Portable code |
| To own everything | To save time writing wrappers |

---

## Platform Support

- **Architecture:** x86-64 (64-bit)
- **Operating System:** Linux
- **Binary Format:** ELF64

It may work on ARM or other platforms with modifications — you'll need to adjust the syscall numbers and ABI.

---

## Requirements

- `gcc`
- `as` (GNU assembler)
- `ld` (GNU linker)
- `strip`
- `sstrip` (from [ELFkickers](https://github.com/BR903/ELFkickers))

---

## Installation

### Step 1.

```bash
sudo cp cib /usr/local/bin/
```

### Step 2.

```bash
sudo chmod +x /usr/local/bin/cib
```

Now you can run `cib` from anywhere.

---

## Usage

```bash
cib main.c               # Compile to tiny binary
cib -S main.c            # Generate assembly (.s) and stop
cib main.s -as           # Assemble existing .s file
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

### Becomes 180 bytes statically linked binary

---

## Example 2 `ttt.c` - From the project folder, it's a Tic-Tac-Toe written by me quickly, just to see if I can make it smaller.


```bash
cib ttt.c
```

### Becomes 1490 bytes statically linked binary

---

## C is or was bloated. You decide.

## License

This project is licensed under the [GNU General Public License v3.0 (GPLv3)](https://www.gnu.org/licenses/gpl-3.0.html).
