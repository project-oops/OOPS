# OOPS documentation

The rules and the arrangement every repository in the collection shares. A project's own
documents state only what it adds to these. Each project keeps its own `docs/`:
[Orbistoun](https://github.com/project-oops/Orbistoun),
[obSCEne](https://github.com/project-oops/obSCEne),
[Prosperous](https://github.com/project-oops/Prosperous),
[SELFish](https://github.com/project-oops/SELFish),
[oops-sdk](https://github.com/project-oops/oops-sdk),
[oops-apps](https://github.com/project-oops/oops-apps),
[oops-libs](https://github.com/project-oops/oops-libs),
[oops-mesa](https://github.com/project-oops/oops-mesa).

| Document | Subject |
|---|---|
| [CONVENTIONS.md](CONVENTIONS.md) | the rules that hold everywhere: provenance, naming, honest failure, greenfield, gates, logging, first-party tooling, toolchain, working across repositories. Sections are cited by number and anchor from every repository, so their headings stay stable |
| [STYLE.md](STYLE.md) | how code, comments, documents and commit messages are written |
| [THE_LOOP.md](THE_LOOP.md) | how the projects feed each other, and when the loop stops for a person |
| [USER_GUIDE.md](USER_GUIDE.md) | building an app, running it on hardware and in the emulator |
| [BUILDING.md](BUILDING.md) | `bin/oops`, its verbs, the dependencies between projects, WSL and CI |
| [ARCHITECTURE.md](ARCHITECTURE.md) | what crosses the boundaries between projects |
| [PUBLISHING.md](PUBLISHING.md) | the repositories, the submodules and cloning |
| [GLOSSARY.md](GLOSSARY.md) | ELF, the vendor's extensions, and words with two meanings |

The collection gates and the site tools are described in [tools/README.md](../tools/README.md).

## Diagrams

A fenced ` ```mermaid ` block renders as a diagram on every published site, in the site's
accent colour. The script loads only on pages that contain one; without it, the diagram's
source shows as text.
