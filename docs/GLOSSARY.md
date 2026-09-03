# Glossary

The vocabulary these four projects are written in, for somebody who has not done systems or
emulator work before.

It is in two halves, and they are not equally hard. Most of what looks like jargon is
**standard ELF** - a file format from about 1990 that Linux, BSD and Android all use, written
down in the System V ABI and explained in a hundred places outside this collection. Learn it
once and it pays off everywhere. The rest is **the vendor's extensions to it**, which have no
public specification at all, and that half is what this collection had to work out.

Knowing which half a term belongs to is most of the battle, so that is how this file is
arranged.

## What is deliberately not here

**The five words for our own layers** - guest, host, loader, target, implementation - are
[CONVENTIONS.md §2](CONVENTIONS.md#the-words-for-our-own-layers). They are a *rule* about what
to write, not a reference for what you are reading, and repeating them here would give one
fact two homes.

**The format facts** - what `DT_SCE_FINGERPRINT` holds, which magic belongs to which
generation - are [SELFish's glossary](https://github.com/project-oops/SELFish/blob/main/docs/GLOSSARY.md)
and the `data/*.tsv` tables beside it. That repository exists to be the single home for format
knowledge (D200), so this page links to it rather than restating it.

---

## Part one: ELF, which is standard

An ELF file is a program or a library. The parts of it you will see named in these projects:

### The prefixes, which is the thing nobody tells you

| Prefix | Stands for | What it is |
|---|---|---|
| `PT_` | **P**rogram header **T**ype | An instruction to the loader: "map this stretch of the file at this address, with these permissions." One entry per **segment**. |
| `DT_` | **D**ynamic **T**able tag | One entry in a list of `(tag, value)` pairs that tells the runtime linker how to finish wiring the program up. |
| `SHT_` | **S**ection **H**eader **T**ype | The linker's view of the file. Mostly irrelevant once the thing is running. |
| `ET_` | **E**LF **T**ype | What kind of object this is: `ET_EXEC` a program, `ET_DYN` a shared object or position-independent program, `ET_REL` an object file. |
| `SCE_` inside any of the above | the vendor's own | An extension using the same mechanism with private numbers. Part two. |

**Segments against sections.** Two views of the same bytes. Sections (`.text`, `.bss`) are how
the linker thinks; segments (`PT_LOAD`) are how the loader thinks. A segment usually contains
several sections. When a report talks about "segment 0's copied run", it means the bytes a
`PT_LOAD` told the loader to map.

### The dynamic tags you will actually meet

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

So a line like `DT_INIT_ARRAY / SZ - both 0x0` means: the file declares it has startup
functions, and then says there are none. Whether that is "nothing runs at load" or "the tag is
a formality" is exactly the sort of question these projects have to settle by measurement.

### Sections you will see named

| Name | What is in it |
|---|---|
| `.text` | The code. |
| `.rodata` | Constants - string literals, lookup tables. |
| `.data` | Variables that start at some value, so their bytes are in the file. |
| `.bss` | Variables that start at **zero**. No bytes in the file at all: just a note saying "reserve this much and zero it". This is why "the `.bss` is filled by the game calling in" is a claim worth testing - something has to do that zeroing. |

### Two more you will meet

- **Entry point** (`e_entry`) - the address of the first instruction. `0x0` means the file
  declines to name one, which is normal for a library and notable for a program.
- **`EI_ABIVERSION`** - one byte near the start of the file. Standard ELF barely uses it; the
  vendor does, which is why it appears in obSCEne's artifact table.

### Where to read more

The System V ABI and the ELF specification are the primary sources, and `man 5 elf` on any
Linux machine is a good first stop. Nothing in part one is specific to this collection, so a
general answer found elsewhere is a trustworthy answer.

---

## Part two: the vendor's extensions

Same mechanisms, private numbers, no public specification. These are defined in **SELFish**,
because that is where the tables that establish them live:

| Term | One line | Defined in |
|---|---|---|
| `PT_SCE_*`, `DT_SCE_*` | Vendor segment and dynamic-tag types, using the standard mechanism with vendor numbers | SELFish `data/self-format.tsv` |
| **NID** | A hash standing in for a symbol name. The vendor's modules do not carry readable names, so a lookup is a hash lookup | SELFish `selfish-nid` |
| **fSELF** | A "fake" signed executable container - the shape a non-retail build takes | SELFish `selfish-container` |
| **PFS** | The filesystem inside a package | SELFish `selfish-pfs` |
| **keystone**, **playgo**, **param.sfo** | Pieces a package carries besides the program itself | SELFish `selfish-pkg` |

Follow those to [SELFish's glossary](https://github.com/project-oops/SELFish/blob/main/docs/GLOSSARY.md);
this page does not restate them.

---

## Part three: one word, two meanings

These are ordinary English words the collection uses in more than one technical sense. This is
the part most likely to mislead, because nothing looks wrong.

| Word | In obSCEne | In orbistoun | Elsewhere |
|---|---|---|---|
| **check** | *the* unit of measurement: one question asked of a loader, with a verdict. A check whose prerequisites failed is **skipped, not failed** | | `oops check <project>` - the CI gate. Unrelated |
| **shape** | one of the artifact forms - payload, injector, module, title directory, package - told apart by two bytes at offset 16 | an **instruction** shape: an opcode's operand layout (D123, D264) | |
| **corpus** | the mined NID corpus, or the golden GPU corpus | the test corpus of titles (D042), or the shader corpus (D088) | |
| **probe** | obSCEne itself, and `obscene-probe.*` the artifacts | | in SELFish, a diagnostic program under `examples/` that prints and ships nothing |
| **section** | a group of related checks in the report, ordered base to high level | | in ELF, a named region of the file. Both senses are live in obSCEne |
| **payload** | a plain ELF a homebrew loader maps and runs | | Prosperous sends payloads; Porthole is one that is not finished |

**census** and **sweep** are obSCEne's alone: a census is the list of platform symbols it knows
about, and a sweep is a repeated run that narrows something down.

---

## The rest

Vocabulary that belongs to exactly one project lives with that project:

- [orbistoun](https://github.com/project-oops/Orbistoun/blob/main/docs/GLOSSARY.md) - guest execution, thunks, stubs, HLE
- [obSCEne](https://github.com/project-oops/obSCEne/blob/main/docs/GLOSSARY.md) - checks, sections, the census, the harness and its sinks
- [Prosperous](https://github.com/project-oops/Prosperous/blob/main/docs/GLOSSARY.md) - targets, the chain, autoload, scan roots
- [SELFish](https://github.com/project-oops/SELFish/blob/main/docs/GLOSSARY.md) - the formats, and part two of this page in full
