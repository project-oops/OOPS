# Architecture

How the projects meet: what crosses a boundary between them, and how the separate
repositories relate to the one working copy. [README.md](../README.md) says what each project
is; [BUILDING.md](BUILDING.md#dependencies) lists the dependency edges.

## Compile-time edges

obSCEne's host tooling reaches three siblings by relative path: SELFish for the formats,
Prosperous for the link layer and process control, and oops-libs for the build stamp, logging
and paths every tool shares.

```toml
selfish-abi       = { path = "../../selfish/crates/selfish-abi" }
selfish-nid       = { path = "../../selfish/crates/selfish-nid" }
selfish-elf       = { path = "../../selfish/crates/selfish-elf" }
selfish-container = { path = "../../selfish/crates/selfish-container" }
pros-link         = { path = "../../prosperous/crates/pros-link" }
pros-core         = { path = "../../prosperous/crates/pros-core" }
oops-build        = { path = "../../oops-libs/crates/oops-build" }
oops-log          = { path = "../../oops-libs/crates/oops-log" }
oops-paths        = { path = "../../oops-libs/crates/oops-paths" }
```

The C edges do not appear in a manifest. obSCEne's `Makefile` compiles oops-sdk's sources into
its module, eboot and payloads. Every app in oops-apps includes `../../oops-sdk/oops-sdk.mk`
and compiles the SDK into its own payload. oops-mesa carries upstream Mesa's radeonsi route
onto the target to give applications OpenGL, builds on oops-sdk's runtime through
`oops-mesa.mk`, and supplies the generated preamble a GL app such as gl1-cube includes.
oops-sdk's own `gl.h` is a fixed-function instrument, and the two GL implementations never link
into one title (oops-sdk#D007).

A path out of the repository works because the submodules sit side by side. A lone clone of
obSCEne does not build without SELFish beside it. A git dependency on SELFish is not an
alternative for individual crates: several of them read data files outside their own package
root,

```rust
const FORMAT: &str = include_str!("../../../data/self-format.tsv");
```

and every crate is `publish = false`, so `cargo package`, `cargo vendor` and `cargo publish`
cannot work on one crate. Only a path dependency or a whole-repository git dependency does.
This follows from SELFish's rule that its format tables are the source of truth and the code
reads them.

## Artefact edges

- obSCEne builds a guest module, and Orbistoun loads it as it loads any title. No code is
  shared; the interface is the platform's module format.
- Prosperous delivers the same module to the hardware and reads back what it printed.
- obSCEne's reports are data to Orbistoun, compared across loaders.
- Porthole, in oops-apps, is the target half of Prosperous's capture-and-input path, and
  Prosperous is the host half. What crosses is the payload and its wire protocol.

## Two ELF readers

SELFish and Orbistoun each parse the ELF, ABI and NID formats. Orbistoun's reader loads
guests; `selfish-elf` is its dev-dependency, used only by a differential test that runs both
readers over the corpus and reports every field on which they disagree (orbistoun#D653).

## Separate repositories, one working copy

Development happens in this repository, where every project is present and builds against
the others. Each project has its own repository because it has its own audience, releases and
issue tracker: obSCEne is a conformance suite that can run against any loader, Prosperous is a
hardware instrument, SELFish is a format library worth depending on from outside.

A cross-repository dependency therefore costs nothing structural. What each repository owes
its audience is a release, a binary or a versioned library, not a checkout that builds alone.

## Citing across projects

Each project numbers its decisions from `D001`. A citation of another project's decision names
the project: `orbistoun#D242`, never a bare `D242` (CONVENTIONS section 9). `prosperity` is a
third-party project; `prosperous` is ours.
