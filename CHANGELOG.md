# Changelog

OOPS publishes **no artifact**. It is the collection: the entry point every project is driven
through, the gates they share, and the conventions they are all held to. There is no version -
the commit is the version.

Entries are grouped **Added / Changed / Fixed**, newest first.

Nothing has shipped yet - this is the initial commit.

## [unreleased] - as of 2026-09-01

### Added

- **`bin/oops`**, one entry point for five repositories. `bootstrap` fetches the siblings a
  project needs, whether they are already present, submodules, or absent and needing a clone,
  so a CI job and a fresh checkout take the same path.
- **The shared gates**, all of them shell: provenance, links, decision logs, workflow shape,
  and the hyphen rule. Every one was made to fail on purpose before being trusted, because a
  guard nobody has seen fail is a guard nobody knows works.
- **`docs/CONVENTIONS.md`**, stated once for all five repositories rather than five times
  slightly differently. Provenance, naming, honest failure over plausible output, decision
  logs, not writing what goes stale, and the gates.
- **`docs/BUILDING.md`** plus one per project, and the three ways a CI job gets the sibling
  checkout wrong.
- **The document splitters.** `split-decisions.sh` and `split-doc.sh` turn a log that GitHub
  will not render into one file per entry and a generated index with a status column. Two
  sessions appending to two files never collide, which retires the duplicate-number and
  out-of-order failures rather than managing them.

### Fixed

- **The splitters were discarding document preambles.** `split-decisions.sh` sent them to
  `/dev/null` directly beneath a comment saying they were kept. Thirteen documents across five
  repositories had lost theirs, including the note explaining why obSCEne decisions before D026
  still name deleted tools, and two explaining why undated entries are undated and must not be
  given invented dates. All thirteen were recovered and are now stored beside their entries.
- **`grep -m1 -o` caps matching lines, not matches.** A line naming two statuses or two dates
  returned two of them, put a newline into a tab-separated field and split one row in two. That
  broke thirty-five index rows, dropped two decisions out of their own index, and stopped the
  date search four rows from its anchor.
- **`check-decisions.sh --prune-baseline`.** The file said a baseline can only shrink while the
  only command on offer rewrote it from whatever fires today, which would have absorbed eighty
  unfixed failures into "known" in one run.
