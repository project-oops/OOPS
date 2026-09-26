<!-- oops:profile -->
<p align="center">
  <img src="assets/logo.svg" alt="OOPS" width="180">
</p>

# OOPS

OOPS (**O**rbistoun, **o**bSCEne, **P**rosperous, **S**ELFish) is an open toolchain and
emulation platform for Orbis- and Prospero-generation hardware. It builds native homebrew,
packages it into the platform's own file formats, runs it on real hardware or in an emulator,
and uses the difference between the two to work out how the platform behaves.

Site: [project-oops.github.io/OOPS](https://project-oops.github.io/OOPS/)

## The loop

Every project checks its siblings. An application whose source is ours runs on the hardware
and in the emulator, and where the two disagree is where something is still unknown.
[docs/THE_LOOP.md](docs/THE_LOOP.md) describes the loop in full.

## The collection

This repository holds every project as a submodule, arranged so they build against each other.
Each project also has its own repository, with its releases, issues and a README for its users.

| Repository | What it is |
|---|---|
| [Orbistoun](https://github.com/project-oops/Orbistoun) | The emulator. Runs guest code natively and reimplements the operating system beneath it. |
| [obSCEne](https://github.com/project-oops/obSCEne) | The hardware probe. A guest that asks the platform questions and reports what it measured. |
| [Prosperous](https://github.com/project-oops/Prosperous) | Remote management. Registers a target, deploys to it, launches, and streams its logs. |
| [SELFish](https://github.com/project-oops/SELFish) | The file formats. One reader and writer for the platform's executables, titles and packages. |
| [oops-sdk](https://github.com/project-oops/oops-sdk) | The freestanding C runtime that target software is built on. |
| [oops-apps](https://github.com/project-oops/oops-apps) | Homebrew and graphics demos of known source, the testbed the rest is measured against. |
| [oops-mesa](https://github.com/project-oops/oops-mesa) | Desktop-class OpenGL on the target, from upstream Mesa. |
| [oops-libs](https://github.com/project-oops/oops-libs) | Shared Rust crates for the host-side tools. |

## Provenance

Everything here is written from public documentation or measured on hardware, and where a
fact came from is recorded beside it, so every behaviour can be explained from a lawful source
and the code can be shared. That constraint is why the work is split into separate projects.
<!-- /oops:profile -->

## Building

```bash
git clone --recurse-submodules https://github.com/project-oops/OOPS
cd OOPS
./bin/oops setup      # the C toolchain (WSL on Windows)
./bin/oops doctor     # check this machine can build the collection
./bin/oops build      # build every project
```

[docs/BUILDING.md](docs/BUILDING.md) covers the verbs, the dependencies between projects,
Windows and CI.

## Using it

[docs/USER_GUIDE.md](docs/USER_GUIDE.md) walks through building an app, running it on
hardware and running it in the emulator.

## Documents

- [docs/THE_LOOP.md](docs/THE_LOOP.md) - how the projects feed each other.
- [docs/USER_GUIDE.md](docs/USER_GUIDE.md) - building, deploying and emulating a title.
- [docs/BUILDING.md](docs/BUILDING.md) - `bin/oops`, dependencies, WSL and CI.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - what crosses the boundaries between projects.
- [docs/PUBLISHING.md](docs/PUBLISHING.md) - the repositories and the submodules.
- [docs/CONVENTIONS.md](docs/CONVENTIONS.md) - the rules every repository follows.
- [docs/STYLE.md](docs/STYLE.md) - how code, comments and documents are written.
- [docs/GLOSSARY.md](docs/GLOSSARY.md) - platform terminology.
- [tools/README.md](tools/README.md) - the collection gates and site tools.

## License

Dual-licensed under [MIT](LICENSE-MIT) or [Apache-2.0](LICENSE-APACHE), at your option.
