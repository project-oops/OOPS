# How the four fit together

[README.md](../README.md) says what each project is. This says how they meet, what crosses
a boundary between them, and which of those crossings is a decision nobody has made yet.

The oracle problem - why there are four rather than one - is in
[the README](../README.md#the-oracle-problem-which-is-the-whole-shape-of-it) and is not
restated here.

## What crosses a boundary

**By dependency - the compile-time edges:**

obSCEne's tooling reaches into **two** siblings by relative path - SELFish for the formats,
and Prosperous for the link layer that talks to hardware:

```toml
selfish-abi       = { path = "../../selfish/crates/selfish-abi" }
selfish-nid       = { path = "../../selfish/crates/selfish-nid" }
selfish-elf       = { path = "../../selfish/crates/selfish-elf" }
selfish-container = { path = "../../selfish/crates/selfish-container" }
pros-link         = { path = "../../prosperous/crates/pros-link" }
```

A relative path out of the repository is unusual and worth being explicit about. It works
under this repository because submodules sit side by side, and it works in the development
layout because the checkouts are siblings. It does **not** work in a lone clone of obSCEne,
which needs SELFish beside it.

The alternative is a git dependency on the whole of SELFish, which would make obSCEne
clone-and-build on its own at the cost of pinning a revision in two places. Neither is
obviously right; the path dependency is what exists.

**What is not an alternative**, and this is a harder constraint than it looks: six of
SELFish's crates read data files from *outside their own package root* -

```rust
const FORMAT: &str = include_str!("../../../data/self-format.tsv");
```

- and every crate is `publish = false`. So `cargo package`, `cargo vendor` and
`cargo publish` cannot work on an individual SELFish crate. Only a **path dependency** or a
**whole-repository git dependency** does.

That is a deliberate consequence of SELFish's own rule that its format tables are the source
of truth and the code reads them rather than carrying a copy. It is worth stating here
because it removes the option a reader would otherwise reach for first, and because it means
the sibling layout is not a convenience - it is one of only two arrangements that work.

**By artefact - the edges that carry the actual work:**

- obSCEne builds a guest module. Orbistoun loads it exactly as it loads a commercial title.
  No code is shared in either direction; the interface is the platform's own module format.
- Prosperous delivers that same module to real hardware and reads back what it printed.
- obSCEne's reports are consumed as data by Orbistoun and compared across emulators.

**By document:**

Findings that matter on both sides belong in a document rather than in one project's
decision log. obSCEne's handover notes answered questions about the platform's dynamic
table before Orbistoun spent an afternoon rediscovering them.

## The one duplication, and why it is a question rather than a bug

SELFish and Orbistoun both have crates called `abi`, `elf` and `nid`. The same three
formats, parsed twice, in two repositories.

The tidy-minded answer is that Orbistoun should depend on SELFish and delete its own. That
may well be right, and it is not obviously right, because:

- **Orbistoun's parsers are bound by a provenance rule.** Everything in that repository has
  to be explicable from a lawful source, and its parsers were written under that rule with
  that history recorded. Adopting another lineage of the same format means adopting - and
  re-verifying - its provenance too.
- **SELFish's rule is stricter in a different direction**: formats from citable sources
  only, with real files as an oracle and never a source. That is a stronger claim than
  Orbistoun makes, and inheriting it may be a gain rather than a cost.
- **Two independent readings of one format have value.** Where they disagree, one of them
  is wrong, and nothing else in this collection can tell you that. Merging them removes a
  check that has already been useful elsewhere.

**The structural objection has gone, which sharpens the question rather than settling it.**
Development happens with all four checked out, so Orbistoun depending on SELFish would cost
nothing in build arrangement - there is no friction argument left on either side. What
remains is entirely about provenance: whether two lineages should be merged, whose rule the
merged one inherits, and what is lost when two independent readings become one.

**Nothing here decides it.** What this document records is that the duplication is known,
that the remaining arguments are about provenance and not convenience, and that whoever
resolves it should write down which argument won. It should not be quietly tidied away by
someone who noticed the overlap and assumed it was an accident.

## The licence question, which is also open

The four intend to ship MIT/Apache. Much of what they know about the platform's formats was
read from projects that are copyleft - LibOrbisPkg is LGPL-3, ps5upload states GPL-3, and the
others carry licences of their own. Every one of them is credited, per file and per structure,
in the consuming project's `ACKNOWLEDGEMENTS.md`.

**Most of this is not the problem it first looks like**, and the reasons are worth writing down
once so nobody re-derives them in a hurry:

- **No code was copied**, and the arrangement in [conventions §1](CONVENTIONS.md#1-provenance-is-a-hard-boundary)
  is what makes that checkable rather than asserted: a fact goes into `data/` with a header
  naming its source, and the implementation is written from the table.
- **Facts are not the licensed thing.** An offset, a field name, the order blocks are signed
  in - these describe a file that exists. They are the same facts whoever writes them down, and
  a licence on a program does not reach them.
- **LGPL-3 in particular** is the licence written to permit exactly this kind of use, and it is
  the one covering the densest single dependency.

**What is not settled** is that "the whole filesystem-writing layout" - `selfish`'s own words
for what it took from four `PFS/` files and `Util/Crypto.cs` - is the largest amount any one
source contributed, and layout at that density is where a table of facts starts shading into
someone's design. `selfish#D049`-`D053` record the derivation and note that three things in it
were not conclusions this project would have reached alone. That candour is the right instinct
and it is also precisely what would need answering.

**Nothing here decides it.** What this records is that the question is known, that it is about
one dependency rather than the practice in general, and that the time to answer it is *before*
the first push rather than after - [PUBLISHING.md](PUBLISHING.md) is the point of no return,
because a licence asserted over published code is much harder to revise than one asserted over
a directory. Whoever resolves it should write down which argument won, and in which project's
log.

## Four repositories, one working copy

The split is about **distribution and identity, not about source-level independence**.

Development happens in this repository, where all four are present and build against each
other. The separate repositories exist because each project has its own audience, its own
releases and its own issue tracker: obSCEne is a conformance suite somebody might run
against a different emulator entirely, Prosperous is the hardware instrument whoever wrote the
payload, SELFish is a format library worth depending on from outside. Those are four
different conversations, and one repository would make them one.

**So a cross-repository dependency is not a cost to be minimised.** The development layout
always has all four checked out side by side; obSCEne reaching into SELFish costs nothing
structural, and neither would Orbistoun. What each repository owes its own audience is a
**release** - a binary, or a versioned library dependency - not a checkout that builds in
isolation.

That inverts what would otherwise be the obvious worry. The question is not "can this be
cloned alone" but "does this ship something on its own", and all four do.

## Citing a decision in another project

Each project numbers its decisions `D001` upward, independently. With four of them that is
already ambiguous, and it has already gone wrong: one repository cites "decision D049"
meaning another project's, and "(D049-D053)" meaning its own, **ten lines apart in the same
file**. A reader has no way to tell.

Where a document cites a decision that is not its own repository's, qualify it:

```
orbistoun#D242        not     orbistoun's D242
selfish#D049          not     D049
```

The same applies to project names that are nearly each other. `prosperity` is a third-party
project and `prosperous` is one of these four; they differ by one letter and have already
appeared in the same table with nothing marking which is which.

## Conventions

There is no shared convention document, and this file is not one. Each project carries its
own principles, decision log and workflow, and they differ deliberately - Orbistoun's
provenance rules exist because it reimplements a platform, and would be ceremony in a
hardware instrument.

What they do have in common is the shape: a `README`, a principles file, a numbered
decision log with reasoning, and a worklog. Where a project has drifted from its own stated
conventions, that is a fault in that project rather than something for this repository to
enforce.
