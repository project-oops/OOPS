# Glossary

The vocabulary the projects are written in, for a reader new to systems or emulator work.

Part one is standard ELF, the format Linux and BSD use, specified in the System V ABI. Part two
is the vendor's extensions to it, which have no public specification. Part three lists words
the collection uses in more than one sense.

The words for our own layers (guest, host, loader, target, implementation) are defined in
[CONVENTIONS section 2](CONVENTIONS.md#the-words-for-our-own-layers). Format facts, such as
what `DT_SCE_FINGERPRINT` holds, are in
[SELFish's glossary](https://github.com/project-oops/SELFish/blob/main/docs/GLOSSARY.md) and its
`data/*.tsv` tables.

## Part one: ELF, which is standard

An ELF file is a program or a library.

### Prefixes

| Prefix | Stands for | What it is |
|---|---|---|
| `PT_` | Program header Type | An instruction to the loader: "map this stretch of the file at this address, with these permissions." One entry per **segment**. |
| `DT_` | Dynamic Table tag | One entry in a list of `(tag, value)` pairs that tells the runtime linker how to finish wiring the program up. |
| `SHT_` | Section Header Type | The linker's view of the file. Mostly irrelevant once the thing is running. |
| `ET_` | ELF Type | What kind of object this is: `ET_EXEC` a program, `ET_DYN` a shared object or position-independent program, `ET_REL` an object file. |
| `SCE_` inside any of the above | the vendor's own | An extension using the same mechanism with private numbers. Part two. |

Segments and sections are two views of the same bytes. Sections (`.text`, `.bss`) are how
the linker thinks; segments (`PT_LOAD`) are how the loader thinks. A segment usually contains
several sections. When a report talks about "segment 0's copied run", it means the bytes a
`PT_LOAD` told the loader to map.

### Dynamic tags

The `.dynamic` section is a list that ends at `DT_NULL`. The runtime linker walks it.

| Tag | Plain English |
|---|---|
| `DT_NEEDED` | "This needs library X." One entry per library. |
| `DT_INIT` | "Call this one function before `main`." |
| `DT_INIT_ARRAY` / `DT_INIT_ARRAYSZ` | "Call each function in this list first." The address, and how many bytes long the list is. Constructors. |
| `DT_PREINIT_ARRAY` | The same, earlier still, and only legal in the main program. |
| `DT_FINI` / `DT_FINI_ARRAY` | The mirror image: run at teardown. Destructors. |
| `DT_STRTAB` / `DT_SYMTAB` | Where the strings and the symbols live. Every name in the file is an offset into the string table. |
| `DT_NULL` | End of the list. |

`DT_INIT_ARRAY / SZ - both 0x0` means the file declares a list of startup functions and gives
it no entries.

### Sections

| Name | What is in it |
|---|---|
| `.text` | The code. |
| `.rodata` | Constants - string literals, lookup tables. |
| `.data` | Variables that start at some value, so their bytes are in the file. |
| `.bss` | Variables that start at zero. No bytes in the file: a size to reserve and zero at load. |

### Other fields

- **Entry point** (`e_entry`) - the address of the first instruction. `0x0` means the file
  declines to name one, which is normal for a library and notable for a program.
- **`EI_ABIVERSION`** - one byte near the start of the file. Standard ELF barely uses it; the
  vendor does, and obSCEne's artifact table shows it.

### Where to read more

The System V ABI and the ELF specification are the primary sources; `man 5 elf` on any Linux
machine is a short reference.

## Part two: the vendor's extensions

The same mechanisms with private numbers. They are defined in SELFish, whose tables establish
them:

| Term | One line | Defined in |
|---|---|---|
| `PT_SCE_*`, `DT_SCE_*` | Vendor segment and dynamic-tag types, using the standard mechanism with vendor numbers | SELFish `data/self-format.tsv` |
| **NID** | A hash standing in for a symbol name. The vendor's modules do not carry readable names, so a lookup is a hash lookup | SELFish `selfish-nid` |
| **fSELF** | A "fake" signed executable container - the shape a non-retail build takes | SELFish `selfish-container` |
| **PFS** | The filesystem inside a package | SELFish `selfish-pfs` |
| **keystone**, **playgo**, **param.sfo**, **param.json** | Pieces a package or title directory carries besides the program itself | SELFish `selfish-pkg`, `selfish-title` |
| **`applicationCategoryType`** | An integer in `param.json` (`CATEGORY` in `param.sfo`) governing hardware budget (DMEM) and HDMI scanout ownership (`0` = Big App, `65536` = System App, `131072` = Mini App) | SELFish `selfish-title` |
| **`paid`** (Program Authority ID) | A 64-bit value in the SELF header governing process privilege tier (`app`, `system`, `root`). Orthogonal to application category | SELFish `selfish-container` |

[SELFish's glossary](https://github.com/project-oops/SELFish/blob/main/docs/GLOSSARY.md) has
them in full.

## Part three: one word, two meanings

Ordinary words the collection uses in more than one technical sense.

| Word | In obSCEne | In orbistoun | Elsewhere |
|---|---|---|---|
| **check** | the unit of measurement: one question asked of a loader, with a verdict. A check whose prerequisites failed is skipped, not failed | | `oops check <project>` - the CI gate. Unrelated |
| **shape** | one of the artifact forms - payload, injector, module, title directory, package - told apart by two bytes at offset 16 | an instruction shape: an opcode's operand layout (orbistoun#D123) | |
| **corpus** | the mined NID corpus, or the golden GPU corpus | the test corpus of titles (orbistoun#D042), or the shader corpus (orbistoun#D088) | |
| **probe** | obSCEne itself, and `obscene-probe.*` the artifacts | | in SELFish, a diagnostic program under `examples/` that prints and ships nothing |
| **section** | a group of related checks in the report, ordered base to high level | | in ELF, a named region of the file. Both senses are live in obSCEne |
| **payload** | a plain ELF a homebrew loader maps and runs | | Prosperous sends payloads; Porthole is one |
| **target** | the machine an artifact is built for: `orbis`, `neo`, `prospero`, `trinity` (oops-sdk's `target.h`) | same, when naming an artifact | Prosperous: a machine it has registered, by name and address. Download manifests: where a fetched artifact is installed. oops-libs docs: the far side of the host/target boundary |
| **Orbis** | a build-target value: the previous hardware generation (with `neo` its mid-generation refresh) | the platform's operating system, which Orbistoun reimplements and is named for | "Orbis software" means software for that operating system on either generation |

Say Orbis-generation for the hardware; bare Orbis is the operating system. Write build target,
registered target or install target wherever two senses of `target` could be read, and
host-side for the boundary ([CONVENTIONS section 2](CONVENTIONS.md#the-four-axes-of-a-build-and-a-run)).

A build names four axes: target (built for), format (`elf`, `eboot`, `title`, `pkg`), category
(`applicationCategoryType`, part two) and context (the environment a run is measured to be in,
obSCEne's `OBS|context`). An artifact can carry the first three in its name, never the fourth.

Census and sweep are obSCEne's words: a census is the list of platform symbols it knows
about, and a sweep is a repeated run that narrows something down.

## Per-project glossaries

Vocabulary that belongs to one project lives with that project:

- [orbistoun](https://github.com/project-oops/Orbistoun/blob/main/docs/GLOSSARY.md) - guest execution, thunks, stubs, HLE
- [obSCEne](https://github.com/project-oops/obSCEne/blob/main/docs/GLOSSARY.md) - checks, sections, the census, the harness and its sinks
- [Prosperous](https://github.com/project-oops/Prosperous/blob/main/docs/GLOSSARY.md) - targets, the chain, autoload, scan roots
- [SELFish](https://github.com/project-oops/SELFish/blob/main/docs/GLOSSARY.md) - the formats, and part two of this page in full
