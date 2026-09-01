# Publishing the four, and wiring up the submodules

**Done, on 2026-09-01.** All six repositories have an initial commit, a remote and a public
`main`, and the five projects are submodules of this one. What follows is what was done and why,
plus the one step still outstanding.

## Where things are

```
https://github.com/project-oops/OOPS         the collection, and this file
https://github.com/project-oops/Orbistoun    submodule: orbistoun
https://github.com/project-oops/obSCEne      submodule: obscene
https://github.com/project-oops/Prosperous   submodule: prosperous
https://github.com/project-oops/SELFish      submodule: selfish
https://github.com/project-oops/oops-libs    submodule: oops-libs
```

The layout is not cosmetic. obSCEne finds SELFish by relative path, so
`OOPS/obscene/tool/Cargo.toml` resolves `../../selfish/crates/selfish-abi` to
`OOPS/selfish/crates/selfish-abi`. A nested or renamed arrangement breaks its build, and the
submodule directory names are lower-case to match what that path expects on a case-sensitive
filesystem.

## They were public, then private, then public again

Worth writing down, because the private half broke three things at once and none of them
announced itself as a visibility problem:

- **CI could not fetch siblings.** A workflow's `GITHUB_TOKEN` is scoped to its own repository,
  so obSCEne named SELFish and Prosperous correctly and failed with `could not read Username
  for 'https://github.com'`. `bootstrap` now reads `OOPS_CI_TOKEN` for that case; see
  [BUILDING.md](BUILDING.md).
- **GitHub Pages went dark.** The free plan does not serve Pages from a private repository. The
  four `pages.yml` workflows are now gated on `github.event.repository.visibility == 'public'`
  so they skip instead of failing red.
- **A public parent with private submodules** is a clone that fails for everybody else, which is
  the one that would have been discovered by a stranger rather than by CI.

## Why they were not wired up sooner

A submodule records **a remote URL and a revision**. With no commits and no remotes there was
nothing to record, and a `.gitmodules` written then would have named five repositories that did
not exist and pinned four revisions that were never made. It would have looked finished and
resolved to nothing.

## What is still outstanding

**The four projects reference each other by local path.** `<OOPS>/obscene`, `../selfish`,
`<OOPS>/prosperous` - none of those means anything to a reader with a clone. Converting them to
the published URLs is a per-project job and the largest single documentation task the collection
has. [README.md](../README.md) and [ARCHITECTURE.md](ARCHITECTURE.md) already used the published
URLs, so they were correct the moment the remotes existed.

**Build obSCEne once from a fresh clone.** That is the only way to find out the submodule layout
is wrong, and it has not been done.

## What a reader gets either way

**Cloning this repository** gets all four, arranged so obSCEne builds.

```bash
git clone --recurse-submodules https://github.com/project-oops/OOPS
```

**Cloning one project** is not the development path and its README should say so - point
at this repository for anyone intending to change the code, and at releases for anyone
intending to use it. obSCEne in particular does not build without SELFish beside it, which
is worth stating rather than leaving somebody to discover from a build error.

## Keeping it current

A submodule pins a revision, so this repository does not follow the projects - it records a
set of four revisions that were known to work together. Updating is deliberate:

```bash
git submodule update --remote
```

That is a feature rather than a chore. obSCEne's dependency on SELFish means the two can
disagree, and a parent repository that pins both is the only place a combination is
recorded as having been tried.
