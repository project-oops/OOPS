# Style

How code, comments, documents and commit messages are written in every OOPS repository.
[CONVENTIONS](CONVENTIONS.md) holds the project rules: provenance, naming, honest failure,
logging, tooling and gates. A repository's own `AGENTS.md` or `CLAUDE.md` adds to both and
does not restate them.

## 1. Write what is

Code, comments and documents describe the system as it is, in the present tense.

- **No history.** Not "used to", "previously", "no longer", "an earlier version", "until
  2026-09-21", "this was found when". Git holds history, and the commit message is where it
  is written.
- **No storytelling.** State the fact, then the reason if it is not obvious. No account of
  how something was discovered, no lessons, no rhetorical headings ("Why this is a...").
- **No status.** "Works", "not yet", "currently N of M", limitation lists and progress
  tables stay out of hand-written text. Open work is a line in the repository's `ISSUES.md`.
  Generated status is allowed (section 5).
- **No numbers that change with the code.** Counts of crates, tests, commands, symbols or
  files are generated, pointed at ("the members are in `Cargo.toml`"), or left out.
- **Matter-of-fact tone.** Short declarative sentences. Bold marks a defined term or a rule
  name, never emphasis. Headings are noun phrases.
- **Dashes are hyphens.** A sentence break is ` - `; ranges are `D001-D023`. Captured
  output, quoted material, string literals and generated blocks keep their dashes.
  `tools/check-dashes.sh` enforces this.

## 2. Code

### Formatting

A formatter decides layout, and review never discusses it.

| Language | Formatter and lints |
|---|---|
| Rust | `cargo fmt` with default settings; clippy with the workspace `[lints]` table, `pedantic` on, `unsafe_code` forbidden or every `unsafe` documented |
| C, C++ | `clang-format` with the collection file: LLVM base, 4-space indent, 88 columns, braces on the same line. Each C repository carries a copy of `obscene/.clang-format` |
| Shell | `set -euo pipefail`, 4-space indent, `shellcheck` clean |
| All | LF line endings, final newline, no trailing whitespace |

Every repository's check verb (`./bin/<project> check`) runs its formatter in check mode and
fails on a diff. Upstream and vendored code is excluded from formatting and from every rule
in this file.

### Size

- A function does one thing. Aim for under 60 lines; over 150 is split.
- Nesting stays within 4 levels. Return early instead of nesting.
- A file holds one topic. Over about 1,500 lines, it is split by topic into a module
  directory. New code does not go into a file that is already over the limit.
- Repetitive cases are a table and one function, not one pasted function per case.

### Simplicity

- Write the simplest code that meets the requirement in front of you. No abstraction for a
  caller that does not exist, no option nobody sets, no extension point without a user.
- No dead code: no `#if 0`, no commented-out code, no function parked behind
  `__attribute__((unused))` or `#[allow(dead_code)]`. Delete it; git keeps it.
- Debug switches and instrumentation added for an investigation are removed when it ends,
  or promoted to the shared logging facility.
- Investigation scratch (one-off probes, dumps, diffs) is not committed. A script that is
  reused lives in `tools/` with a one-line purpose.

### One owner per thing

Before adding a helper, entry point, constant, error type or log facility, look for the
existing one:

- C: [`oops-sdk/docs/API_INDEX.md`](../oops-sdk/docs/API_INDEX.md), then grep.
- Rust: oops-libs (`oops-build`, `oops-log`, `oops-paths`), the selfish crates for formats
  (`selfish-elf`, `selfish-nid`), then grep across the collection.

Shared Rust code goes in oops-libs or the selfish crate that owns the format. Shared C code
goes in oops-sdk, or oops-apps `common/` when only apps use it. A second copy is a defect
even when the first lives in another repository; request the change through the bus
(CONVENTIONS section 9) rather than copying.

### Consistency

- Match the surrounding code: naming, error handling, logging. Where the surrounding code
  contradicts this file, follow this file.
- Rust libraries expose one error enum per crate. No `Result<_, String>` in a library API.
  A binary uses one result alias.
- Rust logs through `oops-log` (`tracing`); C logs through `oops_log_*`. No per-module
  logging wrappers.
- C public symbols carry their library prefix (`oops_`, `agc_`). File names are
  `snake_case`.

## 3. Comments

A comment says why the code is the way it is, when the code cannot say it.

- One to three lines is normal. A file or module header states purpose and main contract
  in at most ten lines.
- Every public item has a doc comment: Rust through `missing_docs`, C in the header. A
  non-trivial file with no comments is a defect, as is one full of essays.
- Required: `// SAFETY:` on every `unsafe` block; `# Safety` and `# Errors` sections on
  public Rust APIs where they apply; one line on each test naming the property it protects.
- A hardware or format fact names its source as a stable pointer: a file and line in a
  reference, a `data/` record, a test, or a decision.
- A comment changes in the same commit as the code it describes.

Not in comments:

- history or dates (section 1)
- request, bus, session or worklog identifiers (`REQ-...`, `worklog 851`)
- a list of decision numbers. Cite one decision, `(D123)`, only where it constrains the code
  in front of the reader; across repositories, `orbistoun#D242`
- markdown: headings, bold, tables
- a restatement of what the code does

## 4. Documents

### What a repository holds

| File | Holds |
|---|---|
| `README.md` | what the project is, how to build it, how to use it |
| `AGENTS.md` or `CLAUDE.md` | agent rules this repository adds to the shared ones |
| `docs/<SUBJECT>.md` | reference, user guide or architecture: one file per subject a reader looks up |
| `docs/decisions/`, `docs/DECISIONS.md` | the decisions in force, and their generated index |
| `docs/WORKLOG.md` | one entry per milestone |
| `CHANGELOG.md` | one line per user-visible change, under the release that shipped it; only in a repository that tags releases |
| `ACKNOWLEDGEMENTS.md` | sources consulted |
| `ISSUES.md` | open defects, gaps and unmeasured facts, one line each; a line is deleted when it is fixed |
| `data/` | measured and cited facts, as text with a provenance header |

Generated documents are allowed anywhere. Each states the command that generates it, and a
gate fails when it is out of date.

Nothing else is hand-written. Before creating a document, extend an existing one. A new file
needs a subject a reader will come looking for; a fix, an investigation, a request, a finding
or a session is not a subject.

### Decisions

A decision records a choice between real alternatives that constrains later work. A
measurement, a finding or an implementation detail is not a decision: a measurement goes in
`data/` or a test, a detail in a code comment or the commit message.

Each decision is one file, `docs/decisions/Dnnn-short-title.md`, under 40 lines:

```markdown
# D123 - Noun-phrase title

**Status:** decided
**Date:** 2026-09-26

The decision, in one or two present-tense sentences.

**Why:** the reason, in one to five sentences.

**Rejected:** each alternative, one line each, with the reason.
```

- Status is `decided`, or `assumed` for a choice made without the evidence to settle it.
  Assume freely and keep working; the status marks it for review.
- A decision that changes is edited to state what holds now, with the new date. A decision
  that no longer constrains anything is deleted. Numbers are never reused.
- `docs/DECISIONS.md` is generated by `tools/split-decisions.sh --index <project>` and
  checked by `tools/check-decisions.sh`. Never edit it by hand.

### Worklog

`docs/WORKLOG.md` has one entry per milestone: a capability that now works end to end (a
title reaches a new stage, a tool gains a command, a subsystem is verified on hardware), or
a release. Between milestones, commit messages are the record; there are no per-task or
per-session entries.

```markdown
## 2026-09-26 - Milestone name

- What now exists, one fact per bullet.
- Facts learned that are not recorded in code, data or a decision.
```

An entry is at most about ten bullets, with no narrative.

### Status and open work

Open work, known gaps and defects are one line each in the repository's `ISSUES.md`, grouped
by kind and deleted when done. No other hand-written roadmap status, backlog,
milestone-state or "where it stands" document. A `ROADMAP.md` may give the intended order of
work, one line per item.

## 5. Commit messages

- Subject: imperative, what changed, at most 72 characters. Not "wip", not "updates".
- Body: why the change was made and what was learned. This is where history belongs.
- One logical change per commit; a formatting pass is its own commit.
