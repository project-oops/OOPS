<!-- oops:profile -->
<p align="center">
  <img src="assets/logo.svg" alt="OOPS" width="180">
</p>

# OOPS

**O**rbistoun, **o**bSCEne, **P**rosperous, **S**ELFish.

Four projects aimed at one platform: an emulator, a conformance probe, remote management,
and the file formats underneath them.

Site: **[project-oops.github.io/OOPS](https://project-oops.github.io/OOPS/)** - the hub, and
each project's own site from there.

| | | |
|---|---|---|
| **[Orbistoun](https://github.com/project-oops/Orbistoun)** | the emulator | attempts to reimplement what a title runs on, so its code can run natively |
| **[obSCEne](https://github.com/project-oops/obSCEne)** | the probe | a guest that interrogates whatever runs it and reports what it found |
| **[Prosperous](https://github.com/project-oops/Prosperous)** | the instrument | remote management for anything that runs Orbis software |
| **[SELFish](https://github.com/project-oops/SELFish)** | the formats | read, write and build tools for the platform's own file formats |

Underneath them, **[oops-libs](https://github.com/project-oops/oops-libs)** - the build stamp,
logging, paths and the in-app documentation viewer. A fifth repository and **not** a fifth
project: OOPS is still the four above. Things go in it because they were already being written
twice, not because they might be shared.

**This is the development entry point.** Clone it and you have everything, arranged so it
builds - which matters because the four depend on each other and that is expected to
increase rather than decrease.

The separate repositories are how each project reaches the people who *use* it: releases,
binaries, issues, and a README aimed at someone who wants that one thing. A person who
wants to run a conformance probe against their emulator downloads it; a person changing
how the probe works clones this.
<!-- /oops:profile -->

## Layout

```
OOPS/                ← this meta-repo: the shared rules, the cross-project gates
  orbistoun/         ← submodule - the emulator
  obscene/           ← submodule - the probe
  prosperous/        ← submodule - the instrument
  selfish/           ← submodule - the formats
  docs/              ← conventions, architecture, publishing
  tools/             ← the checks that need all four checked out at once
```

**The arrangement is load-bearing rather than cosmetic.** obSCEne finds its siblings by
relative path - `obscene/tool/Cargo.toml` resolves `../../selfish/crates/selfish-abi` and
`../../prosperous/crates/pros-link` - so a renamed or re-nested checkout does not build.
Cloning with `--recurse-submodules` makes it right by construction; cloning obSCEne on its
own leaves those paths pointing at nothing, which is a missing sibling rather than a broken
dependency.

Directory names are lower-case because those build paths depend on it - see
[docs/PUBLISHING.md](docs/PUBLISHING.md).

## Quickstart

Prerequisite: a Rust toolchain. obSCEne's C targets additionally need `clang` and `lld` under
WSL or Linux; the other three build anywhere.

```bash
git clone --recurse-submodules https://github.com/project-oops/OOPS
cd OOPS
```

Then `bin/oops`, the one vocabulary over four projects that do not share one:

```bash
./bin/oops doctor          # can this machine build all four
./bin/oops build           # everything, or: ./bin/oops build orbistoun
./bin/oops test            # everything, or: ./bin/oops test prosperous
./bin/oops all             # the meta gates, then every project's own gate
```

Names can be shortened as long as they stay unambiguous, so `./bin/oops test pros` works. On
Windows outside Git Bash, `bin\oops.cmd` is the same script.

**Every project carries the same seven verbs at `bin/<project>`, and this relays to them** -
`oops check selfish` is `selfish/bin/selfish check`. So there is one command reached two ways,
and this repository knows nothing about how any of them builds. CI runs it too, for the same
reason: the moment the command CI runs and the command a person runs are different commands,
one of them is untested. `./bin/oops --help` lists the rest.

A failing project does not stop the others; failures are collected and reported at the end, so
one run tells you everything that is broken rather than only the first thing.

**[docs/BUILDING.md](docs/BUILDING.md)** has the rest: every verb, what it maps to in each
project, what depends on what, and the Windows and WSL handling.

The meta-repo holds the shared rules, those checks, and this entry point. The building happens
inside each project.

## Who clones what

| you are | you want | you get |
|---|---|---|
| developing any of it | `OOPS` | all four, side by side, building against each other |
| running the emulator | Orbistoun's releases | a binary |
| testing your own emulator | obSCEne's releases | the probe module and its reports |
| talking to the hardware | Prosperous's releases | a binary |
| parsing these formats in your own project | SELFish | a git dependency on the repository |

The consequence worth stating: **a cross-repository dependency is not friction here.** The
development layout always has all four, so a project reaching into a sibling costs nothing
structural, and the collection should not be shaped around avoiding it.

## The names

Each is a pun on the platform's own vocabulary, and the capitalisation is the joke:

- **Orbistoun** - **Orbis**, the platform's operating system. The thing being reimplemented.
- **obSCEne** - **SCE**, the prefix carried by every function the platform exports. It is
  in the middle of the word because it is in the middle of every symbol.
- **Prosperous** - **Prospero**, the current-generation hardware's development codename.
  Its command is `pros`.
- **SELFish** - **SELF**, the signed executable container every module on the platform
  arrives in.

Write them that way. `obSCEne` and `SELFish` are not typos and the shape carries the
meaning; flattened to "Obscene" and "Selfish" they are just two ordinary adjectives.

Directory and submodule names are lower-case (`obscene`, `selfish`) because a build path
depends on it - see [docs/PUBLISHING.md](docs/PUBLISHING.md).

<!-- oops:profile -->
## What the collection is for

**Running Orbis software on an ordinary computer, from a codebase that can be published.**

The second half is the constraint that shapes everything. It is not difficult to make an
emulator work by copying what the hardware does; it is difficult to make one whose every
behaviour can be explained from a lawful source, and only that kind can be shared, packaged
or accepted from a contributor. So no firmware, no keys, no decrypted titles, no
disassembly - and where a fact came from is recorded beside the fact.

That constraint is why there are four projects instead of one.
<!-- /oops:profile -->

<!-- oops:profile -->
## The oracle problem, which is the whole shape of it

An emulator of an undocumented platform can tell you *that* a guest died and almost never
*whether an answer was right*. A function returns a number; the guest carries on or it does
not; forty thousand frames later something is wrong. There is no specification to test
against, because the specification is the thing being reconstructed.

Each project exists to remove one unknown from that question:

```
                        SELFish
              what is actually in the file
                            |
        +-------------------+-------------------+
        |                   |                   |
   Orbistoun            obSCEne            Prosperous
   what should       what does the       what does the
   happen here       platform do         real one do
```

- **obSCEne removes the guest.** It is a program *we* wrote, so what it asks for is known
  exactly and what came back can be judged. A commercial title can only ever tell you it
  stopped.
- **Prosperous removes the emulator.** The same probe on real hardware answers what the
  platform does, rather than what some reimplementation of it does.
- **SELFish removes the parser.** When two projects disagree about a file, one shared and
  cited reader is a better answer than two independent readings.
<!-- /oops:profile -->

The order matters. A probe with nothing to run on compares emulators to each other; a
parser with no probe has nothing to check itself against.

## What each one is, at length

**Orbistoun** is a high-level emulator. Guest instructions are x86-64 and run natively -
there is no interpreter and no recompiler - so the work is entirely the operating system
beneath them: the loader, the address space, threads, filesystem, and the graphics command
stream translated to Vulkan. Interception is linking rather than hooking: a guest imports
by hash, the loader resolves it, and the whole import list is therefore known before
anything executes.

**obSCEne** is a conformance probe shaped like a guest. Orbistoun loads it exactly as it
loads a commercial title, and because every call it makes was written deliberately, its
report is ground truth rather than inference. The same binary runs on other emulators and
on real hardware, so the same questions get put to every implementation and the answers
line up in one table.

**Prosperous** is the instrument for a running target, and a library before it is a tool. It
delivers a payload, supervises it, reads back the log, runs commands, and moves files both
ways - titles, saves, packages - from a command line or a window. `pros-link`, the transport
underneath it, is a path dependency of obSCEne and orbistoun rather than a copy in each. It
is what gives obSCEne somewhere to run that is not an emulator; it is what makes a save from
real hardware into a tree Orbistoun can mount; and it is useful to anyone with a payload of
their own.

**SELFish** is the format layer: signed executables, containers, symbol hashing, packages,
the filesystem inside them, and the linking that produces a loadable module. Its discipline
is stricter than the others' - a format fact must come from a citable public source, and a
real file may be used to *check* a fact but never to *supply* one.

## What is actually wired up today

The diagram above is the intent. This is the state:

| edge | today |
|---|---|
| obSCEne → SELFish | **real** - path dependencies on the format crates |
| obSCEne → Prosperous | **real** - a path dependency on the link layer |
| Orbistoun → SELFish | **none** - Orbistoun carries its own `orbistoun-abi`, `-elf`, `-nid` |
| Prosperous → SELFish | **none** |
| Orbistoun ↔ obSCEne | by artefact and document: Orbistoun runs the probe and reads its report |
| Prosperous ↔ obSCEne | by artefact: Prosperous delivers the payload to hardware |

So the shared foundation is shared by one of three. Whether the overlap between
`selfish-elf` and `orbistoun-elf` should be resolved is an **open question with arguments on
both sides**, not an oversight - see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Status

**The four are here as plain directories, not yet as submodules.** Each keeps its own
`.git`, and this arrangement is the same one submodules will produce - so what builds now
will build after publication.

**Nothing is published yet.** None of the four has a commit or a remote, so the links above
are where they will be rather than where they are, and the submodules are not wired up - a
submodule pins a remote and a revision and there are neither.
[docs/PUBLISHING.md](docs/PUBLISHING.md) has the order.

## One directory, shared

Every tool writes to the same place: `%APPDATA%\OOPS\` on Windows, `~/.local/share/OOPS/` on
Linux, the equivalent on macOS. Not a subdirectory each - **one directory.**

That is the point rather than a convenience. A save Prosperous pulls off real hardware is the
tree Orbistoun mounts as that title's overlay, because both are keyed by the guest's own path
and neither has to learn the other's format. A target registered once is reachable from every
tool that can talk to one. A report obSCEne measured is where Orbistoun looks for it.

Bulk that can be rebuilt - models, runtimes, compiled shaders, downloads, traces, logs - goes to
`%LOCALAPPDATA%\OOPS\` instead, so a roaming profile does not carry four gigabytes it could
fetch again. A portable run puts both in one directory beside the binary.

The rules live in [oops-paths](https://github.com/project-oops/oops-libs); the reasoning, including
why this started as a directory per tool and should not have, is in its decision log.

## Licence

Dual-licensed under [MIT](LICENSE-MIT) or [Apache-2.0](LICENSE-APACHE), at your option -
the Rust ecosystem convention, and the same terms every project in the collection carries.

## Where to read next

- [docs/BUILDING.md](docs/BUILDING.md) - `bin/oops` in full: every verb, what it maps to in
  each project, what depends on what, the Windows and WSL handling, and how CI uses it
- [docs/CONVENTIONS.md](docs/CONVENTIONS.md) - the rules that hold in all four: provenance,
  naming, decision logs, worklogs, gates. Each project states only what it adds
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - how the four meet, what crosses a
  boundary, and how to cite one project's decisions from another
- [docs/PUBLISHING.md](docs/PUBLISHING.md) - publishing the four and wiring up submodules
- [tools/](tools/) - the checks that need every project checked out at once, which is the
  only thing this repository can do that none of them can
- [oops-libs](https://github.com/project-oops/oops-libs) - the shared crates, and the rule about
  what is allowed into them

Each project carries its own decision log, worklog and workflow, and states the principles
it adds to [CONVENTIONS.md](docs/CONVENTIONS.md). Read this and then the one you are working
in; neither restates the other.
