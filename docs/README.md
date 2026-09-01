# OOPS documentation

The rules and the arrangement the four projects share. Each project states only what it
*adds* to these, or where it deliberately differs and why - so nothing here is repeated next
door, and nothing next door contradicts it silently.

Looking for a project rather than the collection? [orbistoun](https://github.com/project-oops/Orbistoun),
[obSCEne](https://github.com/project-oops/obSCEne),
[Prosperous](https://github.com/project-oops/Prosperous),
[SELFish](https://github.com/project-oops/SELFish) each carry their own `docs/`. The
[root README](../README.md) has the shape of the whole thing, including the oracle problem
that explains why there are four projects instead of one.

## The four documents

**[CONVENTIONS.md](CONVENTIONS.md)** - the rules that hold everywhere, in nine numbered
sections. Read 1, 2 and 3 before changing anything:

| | |
|---|---|
| §1 | **Provenance is a hard boundary** - no firmware, keys, decrypted titles or disassembly. What may be read from someone else's source, and what may not. |
| §2 | **Naming** - no vendor brands in prose or in our own API, plus the vocabulary for our own layers: guest, host, loader, target, implementation. |
| §3 | **Honest failure over plausible output** - a stub that returns success is indistinguishable from working code until forty thousand frames later. |
| §4 | Decision logs, and what to do when two sessions write the same one |
| §5 | Do not write down anything that goes stale |
| §6 | Worklogs |
| §7 | Greenfield: no legacy, no compatibility shims |
| §8 | Gates - including that a guard is not finished until somebody has made it fail |
| §9 | Logging |

Sections are cited by number and by anchor from all five repositories, so they are stable:
renaming one breaks links in code comments, `.gitattributes` files and CI workflows.

**[ARCHITECTURE.md](ARCHITECTURE.md)** - how the four fit together. What crosses a boundary
and what does not, the one duplication that is a question rather than a bug, the open
licence question, and how to cite a decision in another project.

**[BUILDING.md](BUILDING.md)** - one vocabulary over four projects that do not share one.
Every verb `bin/oops` takes, what each maps to per project, what depends on what, and why
obSCEne needs WSL when the other three build anywhere.

**[PUBLISHING.md](PUBLISHING.md)** - the repositories, the submodule wiring, and the order
to do it in.

## The tools in this repository

Checks that only the meta-repository can run, because they need every project checked out at
once. See [tools/README.md](../tools/README.md).

| | |
|---|---|
| `check-decisions.sh` | holds every `docs/DECISIONS.md` to §4, against a baseline that can only shrink |
| `check-links.sh` | resolves every relative link and `#anchor` across all five repositories |
| `build-docs.sh` | renders each project's `docs/` for its Pages site - this page included |
| `publish-profile.sh` | assembles the organisation's landing page from the root README |

## Diagrams

Fenced ` ```mermaid ` blocks render as diagrams on every published site. The script is
loaded only on pages that contain one, and takes the project's accent colour, so a diagram
matches the site it is on. Where the script cannot load, the diagram's source shows as
text - visible and obviously incomplete, rather than a blank space.
