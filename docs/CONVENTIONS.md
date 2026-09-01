# Conventions across the four

Rules that hold in Orbistoun, obSCEne, Prosperous and SELFish alike. Each project states
only what it *adds* to these, or where it deliberately differs and why.

If you are changing one project, read this and then that project's own principles file.
Neither restates the other.

## 1. Provenance is a hard boundary

None of these repositories contains firmware bytes, vendor keys, decrypted title files,
disassembly, or code written while reading a vendor binary. Where a project has a provenance
gate in CI, it fails the build on any of it.

This is not caution theatre. Reimplementation-from-disassembly converges on the original -
same constants, same odd control flow, same enum ordering - and that convergence is
evidence. The cost is not a courtroom; it is that the work could never be shared, packaged
or accepted from a contributor. **Publishable is the whole point**, so the boundary is the
thing that makes the collection possible rather than a tax on it.

**Where a lawful reference exists, cite it.** The kernel is FreeBSD-derived, so much of its
C library has a documented analogue: name it. If you cannot explain where a behaviour came
from, that is the signal.

**Other projects are reference-only, and get credited.** Never lift code. Anything consulted
goes in that project's `ACKNOWLEDGEMENTS.md` **in the same change** - recording it is better
hygiene than silence, because it keeps the question answerable later.

### Reading someone else's source, which all four do

An earlier wording of this section said that reading another project's source and reproducing
its structure was convergence by another route, full stop. That is not the rule any of these
projects actually holds, and it never was - SELFish's format tables name four open-source
readers and a writer by commit hash, obSCEne's name eleven, and both say so in a header at the
top of the file. A shared rule that forbids what all four deliberately do is worse than no
rule, because the first person to notice has to guess which half is real.

The line is **what is taken, not whether the file was opened**:

- **A format fact may be read from anyone's source.** An offset, a field name, an enum value,
  the order fields are written in - these are facts about a file that exists, they are the same
  fact whoever writes it down, and two projects agreeing on one is evidence rather than
  copying. Reading a *writer* is often the only way to get facts no reader ever looks at, and
  that has now been decisive three times.
- **Expression may not.** Control flow, decomposition, naming, the shape of an implementation.
  This is the part that converges, and it is what "never lift code" has always meant.

**The indirection is what makes the distinction checkable rather than a promise.** A fact read
from someone's source is recorded in `data/` as text with a header naming exactly where it came
from, and the implementation is written from that record. Anyone holding the same inputs can
re-derive the table and get the same thing, or fail to and say so. That is why the rule is
survivable: it does not ask anybody to prove what they did or did not read.

That is the arrangement `obscene#D182` wrote down after finding it already in use, and the same
reasoning covers `selfish#D049`-`D053`.

**Keys are narrower than "no keys".** Vendor keys are out, unconditionally. Community keysets
that are already published, that only read and write files built with them, and that unlock
nothing which was not already unlocked are a different object - `selfish/data/pkg-keys.toml`
carries one, states its origin, and says in its own header what it cannot do. The test is
whether possessing it grants access to something the vendor protected. If it does, it does not
belong here.

**Firmware is a permitted input and never a tracked file.** Names and identifiers derived from
firmware trees enter as text with per-row provenance; the trees themselves stay outside every
repository and no build reads them. obSCEne's mined tables hold no row whose only source is
firmware - every name is corroborated by at least one public database, which is what makes the
table re-derivable by someone who has no firmware at all.

**A model in the loop is a third route to the same problem.** Facts now often arrive by way
of something that has read the public internet, including other projects in this space and
the databases they ship. "This is what the function does" can be *recalled* and then dressed
as reasoning, which is convergence again with no reading step to point at. Abstinence is
unenforceable and unprovable; **accounting is the mechanism**. Record how a fact is known,
in a vocabulary that has no value meaning "I already knew it".

**The siblings are not third parties.** Reading another OOPS project's own notes is ordinary
engineering, and its documents are a better source than rediscovering the same thing next
door. The boundary in this section is about *other people's source*.

## 2. Naming: no vendor brands in prose or in our own API

Not concealment - what these target is obvious from the first paragraph of any file, and
that is fine. The goal is a **low profile**: none of this is advertised or sold, so there is
no reason to repeat brand names, and a project that reads like marketing invites attention
it has no use for. These are trademarks rather than copyright, so descriptive use would
generally be lawful anyway. The convention costs nothing to hold, so hold it.

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

**Say what the hardware is, not what kind of thing it is.** This table used to prescribe "the
target console", and following it produced openings like *the console's file formats* - which
names no brand and also tells a reader nothing. Someone arriving cold could not say what the
subject was, which is the failure the paragraph above claims this convention does not have.

**Prospero** and **Orbis** are the platform's own generation names, not brands or model numbers,
and they are the precise term where "hardware" was a vague one. They are already load-bearing here:
two of the four projects are puns on them. Use **Prospero-generation hardware** on first mention
and "the hardware" after, rather than repeating it.

Where a sentence wants to be exact rather than short, the underlying facts are all nameable
outright: **x86-64 hardware running a FreeBSD-derived operating system**.

**"Console" is not a banned word - it is a useless one.** It still means a terminal, and
`console output` or `wrote it to the console` stay exactly as they are.

**Fine to name**: FreeBSD, POSIX, Vulkan, SPIR-V, ELF, x86-64 - open standards and open
source, each a genuine dependency or citable reference.

**The unavoidable exception.** Symbol names, library names and format identifiers are **ABI
facts**. A guest imports by those exact strings and hashes are computed from them, so
renaming them stops the tools working. They stay in code. Prose describing them does not
have to repeat them.

The project names themselves are the other exception, and they are puns on this vocabulary -
see [the naming section in the README](../README.md#the-names). Write them stylised:
**Orbistoun**, **obSCEne**, **Prosperous**, **SELFish**.

### The words for our own layers

Everything above is about not naming the vendor's things. This is about naming ours, and it
exists because the same word already means two things in two repositories - which nobody
noticed until somebody went looking for a word the collection had all along.

| Word | Means | Watch for |
|---|---|---|
| **guest** | the code being run: a commercial title, or obSCEne | |
| **host** | the ordinary machine the work happens on - the far side of a guest/host boundary, and obSCEne's `make host` stub build | **never the hardware being emulated.** The compatibility table has a `host` column and it is a peer of shadPS4, not a machine under a television |
| **loader** | whatever runs a guest: the hardware, an emulator, or the host build | orbistoun calls its own ELF-loading component "the loader" too. Where both senses are live, write "the ELF loader" for the component |
| **target** | one machine Prosperous has registered, by name and address | |
| **implementation** | the semantics behind a call, whoever provides them | a loader is a thing that runs; an implementation is a set of answers |

**`loader` is the collective noun for "hardware or emulator".** It is the axis obSCEne's
compatibility table is built on - results are reported *per loader*, the hardware's own
loader is one of them, and D062 turns on the loaders disagreeing. Reach for it before
inventing a word: `host` is the one that looks right and is not, because it is already
spoken for one level up.

**"The hardware" is not a loader-neutral term either.** It means the real thing
specifically. A sentence that has to cover both says "loader", or names them both.

## 3. Honest failure over plausible output

A stub that returns success is indistinguishable from working code until forty thousand
frames later. So an unimplemented thing says so, a placeholder value can never be mistaken
for a real one, and an empty result is an error rather than a shrug - "needs nothing" is
never true.

Never invent a constant, an error code or an arity to make something compile quietly. An
explicit "not handled yet" is worth more than a wrong answer and costs the same to write.

**It applies to tools as much as to the thing being built.** A guard, a verdict or a report
is as capable of plausible output as a stub is. Three rules fall out of it, each cheap:

- **A guard is not finished until somebody has made it fail.** A guard nobody has watched
  reject something is a guard nobody knows anything about.
- **A message naming a cause must come from the branch that determined it.**
- **An intervention that changes the program is not a diagnosis.** It needs a second
  observation, of a different kind, saying what actually happened.

Counting successes is not checking for failures: assert on the failure, never on the count
of passes.

## 4. Decision logs

Every project keeps `docs/DECISIONS.md`: numbered, append-only, with the **reasoning** and
not merely the choice. The reasoning is what stops a decision being re-litigated.

- `## Dnnn - sentence-case title`, numbered from `D001` within that project
- A status and a **date**, plus a short note on how it was found
- Cited inline from prose and from code as a bare `(D217)` **within its own repository**

**Across repositories, qualify the citation.** Each project numbers from `D001`
independently, so a bare `D049` is ambiguous the moment two are open at once - and this has
already gone wrong, with one file citing another project's `D049` and its own `(D049-D053)`
ten lines apart.

```
orbistoun#D242        not     orbistoun's D242
selfish#D049          not     D049
```

**Dates are not optional.** None of these repositories has commit history that predates its
first push, so the date on a decision is the only record of when it was made. Every project
here has started dating entries and then quietly stopped; the convention is only worth
having if it survives the fiftieth entry.

### When two sessions write the same log

Both `D118` and `D118` are valid to whoever wrote them, and neither knows about the other until
the numbers meet. This has happened twice here. What works:

- **Whoever has not published moves.** Renumbering something already cited elsewhere trades one
  ambiguity for a worse one.
- **Never renumber the other side's entries.** An entry you did not write may be cited from
  files you cannot see.
- **Say so at the fork**, so the gap does not read as a lost decision later.

Duplicates that survive this are a known cost, not drift. Cite them by heading rather than by
number until they are resolved.

## 5. Do not write down anything that goes stale

**A number that changes when the code changes does not belong in prose.** Either generate it
or leave it out. There is no third option where somebody remembers to update it, and every
one of these repositories has proved that: crate counts off by three, "eleven subcommands"
against twenty, a test count off by fifteen, a name count off by a factor of forty, a model
family that was renamed everywhere except the docs.

Every one of those was true when written. That is the point - staleness is not carelessness,
it is the default behaviour of a fact copied out of the thing that owns it.

**What this rules out of prose:**

- counts of anything the build knows - crates, tests, commands, subcommands, symbols, files
- percentages and totals derived from those
- lists that must enumerate something the code defines - every subcommand, every provider,
  every supported format
- "currently N of M" progress statements

**What to do instead**, in order of preference:

1. **Generate it.** A block written by a tool, fenced so it is obviously not hand-written,
   and a gate that fails when it is out of date. Orbistoun does this with
   `orbistoun-cli status --write`, and its generated numbers are the only ones in the
   collection that have stayed right.
2. **Point at the thing that owns it.** "The workspace members are in `Cargo.toml`" needs no
   maintenance and cannot be wrong.
3. **Say the shape without the number.** "A handful of crates, one per subsystem" survives
   any amount of change. "34 crates" was wrong within a week.

**A count inside a decision or worklog entry is different and stays.** Those are dated
records of what was true at a moment, not claims about the present - "276 runs planted
nothing" is history and remains accurate forever. The rule is about documents that describe
the current state.

## 6. Worklogs

`docs/WORKLOG.md` is what was done, in order, plus **surprises especially** - they are what
a fresh reader cannot re-derive. Append at the end of a completed unit of work rather than
at the end of a session, because a session may not end cleanly.

Entries carry a date, for the same reason decisions do.

## 7. Greenfield: no legacy, no compatibility shims

Nothing has shipped. Edit the original, change the format, wipe the file. No migrations, no
deprecated aliases, no back-compatibility paths until tagged binaries exist and somebody has
data in the wild.

## 8. Gates

Each project has one command that runs everything CI runs, in CI's order, so "is the tree
sound" has a single answer. Lints belong in a workspace table rather than only in CI flags,
so an editor applies them while you type; CI adds `-D warnings` on top.

**Check the branch your CI triggers on.** All four are on `main`. A workflow naming any other
branch never fires on push, and a gate that never fires is indistinguishable from a gate that
passes - which is how this went unnoticed once already.

**Four gates span the collection**, run from the OOPS root because none can be answered from
inside a single project:

- `tools/check-decisions.sh` - holds every decision log to section 4: order, unique numbers,
  titles, dates. It fails on the current tree, which is the point; it was written against
  defects that were already there.
- `tools/check-links.sh` - resolves every relative link and anchor, across repositories as
  well as within them.
- `tools/check-workflows.sh` - every workflow that touches a project's source checks the
  collection out around it. A workflow checks *itself* out, so whether the layout is there is
  invisible from inside that repository.
- `tools/check-dashes.sh` - the house dash style, above.

They are shell, like `bin/oops` and the rest of `tools/`. All four were Python first, which
was nobody's decision: the collection is Rust, C and bash, and four files in one directory are
a poor guide to that next to the five hundred beside them.

### Line endings are pinned, in every repository

`core.autocrlf` is a per-machine setting, so a repository without a `.gitattributes` checks
out differently on two people's disks and the difference arrives as a diff nobody made. Every
project here carries one, and `* text=auto eol=lf` is the baseline - `text=auto` because git
detects binary content itself, and an extension list only protects the extensions somebody
remembered.

Two sharp edges, both already paid for once:

- **A shell script with a CR on its shebang line** is unrunnable outside Windows, and the error
  names the interpreter rather than the line ending. obSCEne builds in a Linux VM over a
  Windows mount, which is where this was found.
- **A fixture compared byte for byte needs `-text`, not `eol=lf`**, which would still rewrite
  one that legitimately contains CRLF - a captured line protocol, say. orbistoun's file has
  the worked example, including that the last matching line wins.

### Dashes are hyphens

**Use ` - ` where a sentence needs a break. Not an em-dash, not an en-dash.**

There is no typographic argument here - an em-dash is the better mark and everyone knows it.
The argument is that two marks were in use for the same job, the split ran roughly along
repository lines without anybody deciding it, and prose that reads as one voice is worth more
than the better dash. Ranges take a hyphen too: `D001-D023`, `phases 1-6`.

The moment to settle this was before anything was published, because the alternative is a
diff across every document in the collection to change punctuation, competing with real work.

Three places keep their dashes, and each is a fact rather than prose:

- **Captured output, and material quoted from somewhere else.** A recorded session or a line
  lifted from another project's source is evidence, and editing it makes it evidence of
  nothing. A fence is not automatically exempt: a hand-written comment inside an illustrative
  block is prose and takes a hyphen like any other prose.
- **In a string literal.** `tools/check-decisions.sh` strips `" -—"` because it parses
  headings that already contain both; rewriting that set breaks the parser.
- **In a generated block.** Fix the generator, not what it wrote - the file is regenerated on
  the next run and a hand-edit is lost without trace.

## 9. Logging

Every tool uses [`oops-log`](https://github.com/project-oops/oops-libs), which is `tracing` with the
setup done once. Turn it up with `OOPS_LOG` (or `RUST_LOG`), per-module if you want:
`OOPS_LOG=warn,pros_core::fetch=trace`.

**Levels describe what happened, not how loud it feels.**

| level | what belongs there | shown by default |
|---|---|---|
| `error` | the tool could not do what was asked and is giving up | yes |
| `warn` | something surprising that did not stop the work - a fallback taken, a check failed the caller may tolerate | yes |
| `info` | an action with a side effect, in the user's own terms: fetched, registered, installed | yes |
| `debug` | resolved configuration and the decisions behind an action | no |
| `trace` | per-item and wire detail | no |

Two rules that do the real work:

**A library logs facts; a binary logs outcomes.** A function returning `Err` has not decided
anything yet - the caller might expect that failure and handle it. So a library says `warn` for
a digest that did not match and lets the command say `error` when it gives up. A library that
logs `error` for a value it handed back as `Err` reports one problem twice, at the wrong
severity, from the layer that knows least about it.

**Logging is not printing.** A library must not write to the terminal - that decides the
interface of every tool using it - but `tracing` is a facade the binary points wherever it
likes, including nowhere. The distinction is what makes it safe for a crate that has a rule
against printing.

A tool's own startup line belongs at `debug`: which build, and where it is writing. Those are
the two facts every bug report needs and nobody remembers to ask for, and an ordinary run should
still be silent.

## Where a project differs

Divergence is fine when it is deliberate and stated. SELFish, for instance, holds a stricter
provenance rule than the rest: a format fact must come from a citable public source, and a
real file may be used to *check* a fact but never to *supply* one. That is stronger than
section 1 and it is written down in SELFish rather than here, because it is not shared.

What is not fine is a project quietly drifting from a rule it still claims to hold.
