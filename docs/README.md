# OOPS documentation

The rules and the arrangement the eight repositories share. Each project states only what it
*adds* to these, or where it deliberately differs and why - so nothing here is repeated next
door, and nothing next door contradicts it silently.

Looking for a project rather than the collection? [orbistoun](https://github.com/project-oops/Orbistoun),
[obSCEne](https://github.com/project-oops/obSCEne),
[Prosperous](https://github.com/project-oops/Prosperous),
[SELFish](https://github.com/project-oops/SELFish),
[oops-sdk](https://github.com/project-oops/oops-sdk),
[oops-apps](https://github.com/project-oops/oops-apps),
[oops-libs](https://github.com/project-oops/oops-libs),
[oops-mesa](https://github.com/project-oops/oops-mesa) each carry their own `docs/`. The
[root README](../README.md) has the shape of the whole thing, including the oracle problem
that explains why there are separate projects instead of one.

## The documents

**[CONVENTIONS.md](CONVENTIONS.md)** - the rules that hold everywhere. Read 1, 2 and 3
before changing anything:

| | |
|---|---|
| §1 | Provenance: no firmware, keys, decrypted titles or disassembly; what may be read from someone else's source |
| §2 | Naming: no vendor brands; the words for our own layers; the four axes of a build and a run |
| §3 | Honest failure over plausible output |
| §4 | Greenfield: no legacy, no compatibility shims |
| §5 | Gates |
| §6 | Logging |
| §7 | First-party tooling |
| §8 | Toolchain |
| §9 | Working across repositories |

Sections are cited by number and anchor from every repository; keep headings stable.

**[STYLE.md](STYLE.md)** - how code, comments, documents and commit messages are written:
formatting, size, one owner per thing, comment rules, which documents a repository holds,
decisions, worklog.

**[ARCHITECTURE.md](ARCHITECTURE.md)** - how the four fit together. What crosses a boundary
and what does not, the one duplication that is a question rather than a bug, the open
licence question, and how to cite a decision in another project.

**[BUILDING.md](BUILDING.md)** - one vocabulary over members that do not share one build.
Every verb `bin/oops` takes, what each maps to per project, what depends on what, and why the C
repositories (obSCEne, oops-sdk, oops-apps, oops-mesa) need WSL while the rest builds anywhere.

**[PUBLISHING.md](PUBLISHING.md)** - the repositories, the submodule wiring, and the order
to do it in.

**[GLOSSARY.md](GLOSSARY.md)** - the vocabulary, for somebody who has not done systems or
emulator work before. Two halves: standard ELF, which is a 1990 format Linux and BSD use too
and which is documented everywhere outside this collection, and the vendor extensions to it,
which are documented nowhere else. Also the words that mean different things in different
repositories - `check`, `shape`, `corpus`, `probe` and several more each carry two senses, and
nothing looks wrong when you read the wrong one. The glossary's own table is the full list.

**[THE_LOOP.md](THE_LOOP.md)** - the closed-loop oracle in full: the stages a build and run
pass through, the escape-hatch triggers that stop a runaway loop, and the sibling dependencies
that carry the work between projects. The root README has the shape; this has the specification.

**[USER_GUIDE.md](USER_GUIDE.md)** - the end-to-end workflows for building, packaging, deploying
and emulating, written for somebody using the tools rather than changing them.

## The tools in this repository

Checks that only the meta-repository can run, because they need every project checked out at
once. See [tools/README.md](../tools/README.md).

| | |
|---|---|
| `check-decisions.sh` | holds every `docs/DECISIONS.md` to §4, against a baseline that can only shrink |
| `check-links.sh` | resolves every relative link and `#anchor` across all eight repositories |
| `check-workflows.sh` | every workflow that touches a project's source begins with the standard preamble |
| `check-dashes.sh` | the house hyphen style, across the collection |
| `split-decisions.sh`, `split-doc.sh` | regenerate a project's decision/worklog/backlog index from its per-entry files |
| `build-docs.sh` | renders each project's `docs/` for its Pages site - this page included |
| `publish-profile.sh` | assembles the organisation's landing page from the root README |
| `setup-wsl.sh` | makes a Windows machine able to build the C repositories: WSL, an `oops-builder` distribution, the toolchain inside it. `./bin/oops setup` |

## Diagrams

Fenced ` ```mermaid ` blocks render as diagrams on every published site. The script is
loaded only on pages that contain one, and takes the project's accent colour, so a diagram
matches the site it is on. Where the script cannot load, the diagram's source shows as
text - visible and obviously incomplete, rather than a blank space.
