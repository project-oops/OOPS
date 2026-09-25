# Conventions

Rules that hold in every OOPS repository. How code, comments and documents are written is in
[STYLE](STYLE.md). A repository's own `AGENTS.md` or `CLAUDE.md` states only what it adds to
these two, or where it deliberately differs and why.

## 1. Provenance is a hard boundary

No repository contains firmware bytes, vendor keys, decrypted title files, disassembly, or
code written while reading a vendor binary. A provenance gate in CI fails the build on any of
it. Reimplementation from disassembly converges on the original, and the collection exists to
be publishable.

- **Cite lawful references.** The kernel is FreeBSD-derived, so much of its C library has a
  documented analogue: name it. A behaviour with no explainable source is a defect.
- **Facts may be read from any source; expression may not.** An offset, a field name, an enum
  value or a field order is a fact about a file, and may be taken from anyone's reader or
  writer. Control flow, decomposition, naming and the shape of an implementation are
  expression and are never taken.
- **Facts go through `data/`.** A fact read from someone's source is recorded in `data/` as
  text, with a header naming exactly where it came from, and the implementation is written
  from that record. Anyone with the same inputs can re-derive the table (`obscene#D182`,
  `selfish#D049`-`D053`).
- **Credit what was consulted** in that repository's `ACKNOWLEDGEMENTS.md`, in the same change.
- **Keys.** Vendor keys are excluded unconditionally. A community keyset that is already
  published, reads and writes only files built with it, and unlocks nothing the vendor
  protected is allowed, with its origin in its own header (`selfish/data/pkg-keys.toml`).
- **Firmware is an input, never a tracked file.** Names derived from firmware enter as text
  with per-row provenance, and every mined name is corroborated by at least one public
  database. No build reads a firmware tree.
- **A model's recall is not a source.** Record how each fact is known, in a vocabulary with no
  value meaning "already known".
- **Sibling repositories are not third parties.** Reading another OOPS project's code and
  notes is ordinary engineering.

## 2. Naming: no vendor brands in prose or in our own API

### Vendor terms

No vendor brand names in prose or in our own API. The collection keeps a low profile.

| Avoid | Use |
|---|---|
| The vendor's name | "the vendor", "the platform vendor" |
| The hardware's brand and model numbers | "Prospero-generation hardware", then "the hardware" |
| The previous generation | "Orbis-generation hardware", "the previous generation" |
| Vendor graphics API names | "the vendor command-stream format" |
| Vendor shader language name | "the vendor shader bytecode" |
| Vendor streaming-layer name | "the vendor async streaming layer" |
| Vendor controller brand | "the vendor controller" |
| Other named emulator projects | "other projects in this space" |

- **Prospero** and **Orbis** are the platform's generation names and are the precise terms.
  Exact form: x86-64 hardware running a FreeBSD-derived operating system.
- "Console" means a terminal. It does not name the hardware.
- FreeBSD, POSIX, Vulkan, SPIR-V, ELF and x86-64 are named freely.
- Symbol names, library names and format identifiers are ABI facts and stay in code
  unchanged. Prose describing them does not repeat them.
- Project names are written **Orbistoun**, **obSCEne**, **Prosperous**, **SELFish**.

### The words for our own layers

| Word | Means | Note |
|---|---|---|
| **guest** | the code being run: a commercial title, or obSCEne | |
| **host** | the ordinary machine the work happens on; obSCEne's `make host` build | never the emulated hardware |
| **loader** | whatever runs a guest: the hardware, an emulator, or the host build | orbistoun's component is "the ELF loader" |
| **target** | see the axes below | always qualified |
| **implementation** | the semantics behind a call, whoever provides them | |

"The hardware" means the real machine only. A sentence covering both says "loader".

### The four axes of a build and a run

| Axis | Values | Meaning | Owner |
|---|---|---|---|
| **target** | `orbis`, `neo`, `prospero`, `trinity` | the machine an artifact is built for | `oops-sdk/include/oops/target.h`, `selfish --target` |
| **format** | `elf`, `eboot`, `title`, `pkg` | the shape an artifact is delivered as | `selfish --format` |
| **category** | `BIG_APP`, `SYSTEM_APP`, `MINI_APP`, `DAEMON`, `MEDIA_APP` | what a title declares itself to be | the title manifest, `selfish --category` |
| **context** | `<delivery>/<generation>`, e.g. `payload/orbis-compat` | the environment a run landed in | measured at run time, obSCEne's `OBS\|context` (`obscene#D275`) |

- **Qualify `target`.** "Build target" for the axis above, "registered target" for a machine
  Prosperous knows (`pros register`), "install target" for a download manifest's destination,
  and "host-side" for the host/target boundary. The full list is in
  [the glossary](GLOSSARY.md#part-three-one-word-two-meanings).
- `neo` and `trinity` are the mid-generation refreshes of `orbis` and `prospero`. An artifact
  for any previous-generation machine is `orbis`; `neo` means Pro-specific.
- **Context is measured, never chosen.** The same machine answers differently depending on the
  environment a run lands in (`obscene#D276`), so an artifact carries no context and `selfish`
  has no `--mode`.
- **Category is the build-side lever on context.** The loader denies a previous-generation
  category the current generation's libraries.
- The target type is `oops_target_t`, read with `oops_get_target()`, with enumerators
  `OOPS_ORBIS`, `OOPS_NEO`, `OOPS_PROSPERO`, `OOPS_TRINITY`. `OOPS_TARGET` is what a binary
  was compiled for, not where it runs.
- Terms quoted from a cited source in `data/` keep the source's wording.

## 3. Honest failure over plausible output

A stub that returns success is indistinguishable from working code until it corrupts
something much later.

- An unimplemented thing says so. A placeholder can never be mistaken for a real value. An
  empty result is an error.
- Never invent a constant, an error code or an arity to make something compile.
- A guard is finished when it has been seen to fail.
- A message naming a cause comes from the branch that determined it.
- An intervention that changes the program is not a diagnosis; confirm it with a second
  observation of a different kind.
- Assert on the failure, never on a count of passes.

## 4. Greenfield

Nothing has shipped. Edit the original, change the format, delete the file. No migrations,
deprecated aliases or compatibility paths until tagged binaries exist and somebody has data
in the wild.

## 5. Gates

- Each repository has one command, `./bin/<project> check`, that runs everything its CI runs,
  in CI's order, including the formatter check from [STYLE](STYLE.md#formatting).
- Lints live in the workspace table, not only in CI flags; CI adds `-D warnings`.
- Every workflow triggers on `main`.
- Every repository's `.gitattributes` starts with `* text=auto eol=lf`. A shell script with a
  CR on its shebang line does not run outside Windows. A fixture compared byte for byte is
  marked `-text`.

Collection gates, run from the OOPS root:

| Gate | Checks |
|---|---|
| `tools/check-decisions.sh` | decision files against [STYLE](STYLE.md#decisions), with a baseline that may only shrink |
| `tools/check-links.sh` | every relative link and anchor, across repositories |
| `tools/check-workflows.sh` | every workflow that touches a project's source checks the collection out around it |
| `tools/check-dashes.sh` | the dash rule |
| `tools/check-toolchain.sh` | every C repository pins the same clang major |

## 6. Logging

Rust tools use [`oops-log`](https://github.com/project-oops/oops-libs): `tracing`, configured
once, turned up with `OOPS_LOG` or `RUST_LOG` (`OOPS_LOG=warn,pros_core::fetch=trace`). C code
uses `oops_log_*` from oops-sdk.

| Level | For | Shown by default |
|---|---|---|
| `error` | the tool could not do what was asked and is giving up | yes |
| `warn` | something surprising that did not stop the work: a fallback taken, a tolerable failed check | yes |
| `info` | an action with a side effect, in the user's terms: fetched, registered, installed | yes |
| `debug` | resolved configuration and the reasons for an action | no |
| `trace` | per-item and wire detail | no |

- A library logs facts; a binary logs outcomes. A library returning `Err` logs at most `warn`
  and leaves `error` to the caller that gives up.
- A library never prints to the terminal.
- A tool's startup line (its build, and where it writes) is `debug`.

## 7. First-party tooling

Every workflow uses the collection's own tools through their canonical interfaces:

| Job | Tool |
|---|---|
| Build an app or title | `make elf`, `make eboot`, `make title` via `oops-apps/common/app.mk` |
| Containers, title layouts, packages | `selfish --format eboot`, `--format title`, `--format pkg` |
| Symbol census, module tagging, probes | `obscene-tool` |
| Hardware | `pros check`, `pros launch`, `pros send`, `pros logs`, `pros titles`, `pros close` |

- Never route around a tool with a scratch script: no hand-built ELF headers, no faked
  `param.json`, `keystone` or `nptitle.dat`, no binaries borrowed from a sibling's build tree,
  no raw FTP.
- A tool that lacks a flag or fails is fixed, tested and committed, in its own repository.

## 8. Toolchain

- **C:** clang 21. `silkeh/clang:21` is the authoritative runner; the WSL `oops-builder`
  distribution is a permitted faster runner while it reports the same version. Each C
  repository's `toolchain.mk` refuses the wrong major, and `tools/check-toolchain.sh` checks
  them together (`oops-mesa#D013`). `CC` exists for a compiler cache and is never used to get
  past the pin.
- **orbistoun's shader fixtures** are reproduced by a reference LLVM 18 toolchain
  (`orbistoun#D681`). That pin is independent of the build compiler.
- Toolchains run in a container first, a portable install second, and a system install only
  when neither works.

## 9. Working across repositories

- A session works in one repository. A change another repository needs is filed on that
  project's request inbox (the bus) with **wants**, **why** and **acceptance**, and the
  session implements only its own half. The bus lives outside every repository.
- Other sessions edit the same working trees. Commit with an explicit pathspec, never
  `git add -A` or `commit -a`, and check the result with `git show --stat`.
- Decisions are cited within a repository as `(D123)` and across repositories as
  `orbistoun#D123`.
