# Publishing the four, and wiring up the submodules

None of the five repositories has a commit or a remote yet. Everything below is therefore
the order it has to happen in, not a description of something already done.

## Where things are right now

The four have been moved under this directory as **plain directories**, each still carrying
its own `.git`. They are not submodules yet and this repository is not a git repository yet;
`.gitignore` lists all four so that whenever it does become one, they are left alone rather
than swallowed as ordinary files.

That interim state is the working development layout and it is the right one - it is exactly
the arrangement submodules will produce, so anything that builds now will build then.

**One thing to check when moving a project in.** obSCEne finds SELFish by relative path, so
`OOPS/obscene/tool/Cargo.toml` resolves `../../selfish/crates/selfish-abi` to
`OOPS/selfish/crates/selfish-abi`. Until SELFish is moved in beside it, that path does not
exist and **obSCEne does not build** - not a broken dependency, just a sibling that has not
arrived. Moving the last project in fixes it, and nothing needs editing.

## Why the submodules are not wired up

A submodule records **a remote URL and a revision**. With no commits and no remotes there
is nothing to record, and a `.gitmodules` written now would name five repositories that do
not exist and pin four revisions that were never made. It would look finished and resolve
to nothing.

So this repository holds documentation and no submodules until the four are pushed.

## The order

**1. Push each project.** Each has its own history to make first - all four currently have
zero commits, so this is an initial commit rather than a push of existing work.

```
https://github.com/project-oops/Orbistoun
https://github.com/project-oops/obSCEne
https://github.com/project-oops/Prosperous
https://github.com/project-oops/SELFish
```

**2. Add them here, side by side.** The layout is not cosmetic - obSCEne finds SELFish by
relative path, as a sibling, so a nested or renamed arrangement breaks its build:

```bash
git submodule add https://github.com/project-oops/Orbistoun  orbistoun
git submodule add https://github.com/project-oops/obSCEne    obscene
git submodule add https://github.com/project-oops/Prosperous prosperous
git submodule add https://github.com/project-oops/SELFish    selfish
git submodule add https://github.com/project-oops/oops-libs  oops-libs
```

**Check the directory names against the path dependency before committing this.** obSCEne
refers to `../../selfish/crates/...`, lower-case, so the SELFish submodule directory has to
match whatever that path expects on a case-sensitive filesystem. It is worth building
obSCEne from inside a fresh clone of this repository once, because that is the only way to
find out that the layout is wrong.

**3. Replace the URLs in the docs.** [README.md](../README.md) and
[ARCHITECTURE.md](ARCHITECTURE.md) already use the published URLs, so they become correct
rather than needing an edit. The four projects themselves currently reference each other by
**local Windows path** - `<OOPS>/obscene`, `../selfish`, `<OOPS>/prosperous` - and none
of those survives publication. Converting them is a per-project job, and the largest single
documentation task the collection has.

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
