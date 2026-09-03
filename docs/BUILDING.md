# Building

There is one command, and it is `bin/oops`.

```bash
./bin/oops build            # everything
./bin/oops build orbistoun  # one of them
./bin/oops test prosperous
./bin/oops all              # the meta gates, then every project's own gate
```

On Windows outside Git Bash, `bin\oops.cmd` is the same script - it finds a bash and hands
over, so there is no second implementation to drift.

## One vocabulary, in every project

**Every repository carries `bin/<name>`, and every one of them takes the same verbs.** So
these are the same command reached two ways:

```bash
./bin/oops test selfish        # from the meta repo
cd selfish && ./bin/selfish test
```

`oops` **relays**; it does not know how anything builds. It used to hold a table mapping four
verbs onto four projects' internals, and a table that has to know what `make check` means
inside obSCEne is a second copy of obSCEne's build, kept somewhere obSCEne's authors will
never look. The knowledge lives with the project that owns it.

That is also why CI uses these: the moment the command CI runs and the command a person runs
are different commands, one of them is untested, and it is always the one nobody watches.

There is a fallback for a project that has not grown an entry point yet - it is treated as a
plain cargo workspace - but all six have one, both libraries included. oops-sdk is the one
that is not cargo at all: its entry point wraps `make`, which is exactly why the fallback
cannot be the interface.

### There is no `<project>.sh` any more

`orbistoun.sh`, `prosperous.sh` and `selfish/scripts/gate.sh` **are** these files; they moved
rather than being wrapped, so there is still exactly one implementation of each. Older
references in the decision logs and worklogs name the old paths, because those record what was
true when they were written.

## The verbs

The seven below are carried by `oops` **and** by every `bin/<project>`. The rest are the
meta-repo's own, because they are about the collection rather than about one project.

| verb | what it does |
|---|---|
| `build [project...]` | build artefacts |
| `test [project...]` | run tests |
| `lint [project...]` | lints at `-D warnings` |
| `fmt [project...]` | format in place |
| `check [project...]` | that project's own full gate - what its CI runs |
| `clean [project...]` | remove build output |
| `doc [project...]` | build the API docs |
| `pkg` | obSCEne's installable package |
| `gates` | the two meta-level checks: decision logs, markdown links |
| `all` | `gates`, then `check` across the four |
| `bootstrap [project...]` | fetch the four, or the ones named plus what they need |
| `git <args...>` | run any git verb across the meta and the four |
| `status` | branch and working-tree state |
| `doctor` | can this machine build all four |
| `exec "<cmd>" [project...]` | run an arbitrary command in each project |
| `list` | the four, where they are, whether present |

Omit the project to mean all four. Names may be shortened while they stay unambiguous, so
`oops test pros` is `oops test prosperous`.

`oops git` proxies **any** verb rather than a hardcoded list, so `oops git status -s`,
`oops git log --oneline -1` and `oops git remote -v` all work without this script knowing what
they mean. It walks the checkouts rather than using `git submodule foreach`, because that
skips the meta repo and finds nothing at all before the four are published.

### What a project adds beyond the seven

The shared verbs mean the same thing everywhere. What differs is only what a project has that
the others do not, reached through the same entry point:

| project | its own verbs |
|---|---|
| **orbistoun** | `run <title>`, `doctor`, `fix`, `cli`, `site`, `sweep`, `names`, `suggest`, `provenance`, `symbols-audit`, `constants`, `tables`, `decide`, `hooks`, `docs` |
| **obscene** | `pkg`, and any make target by name - `./bin/obscene eboot`, `./bin/obscene module-min` |
| **prosperous** | `provenance`, `target` |
| **selfish** | `provenance`, `links` |
| **oops-libs** | none |

Two of those are deliberately *not* folded into a shared verb. orbistoun's `fix` applies clippy
suggestions as well as formatting, which is a mutating operation that should be asked for by
name rather than hidden inside `fmt`; and its `docs` opens a browser, where `doc` does not,
because a build step that launches a browser cannot go in a pipeline.

`./bin/obscene test` is the tooling's own tests. It used to be `make check` - the same command
as `check` - which made the two words indistinguishable and said nothing true about either.

## A failing project does not stop the others

Failures are collected and reported at the end, and the exit code is non-zero if anything
failed. One run tells you everything that is broken rather than only the first thing, which
matters most when a change touches all four at once.

## What depends on what

Not a diagram of intent - these are the `path = "../..."` entries in the `Cargo.toml` files,
and a build without them fails as a missing directory rather than as a missing dependency.

```
oops-libs    ← nothing
selfish      ← oops-libs
orbistoun    ← oops-libs
prosperous   ← oops-libs
obscene      ← selfish, prosperous, oops-libs
```

**Every project takes oops-libs**, so nothing here builds from a clone of only its own
repository. That is recent and it is a real cost: the collection layout is now a build
requirement everywhere rather than in two places, and "SELFish is the bottom of the spine and
depends on nothing" - which its own entry point and CI still say - has stopped being true.
The claim is worth keeping as a goal; it is not a description.

`oops bootstrap` follows those edges: `bootstrap obscene` fetches selfish, prosperous and
oops-libs as well, because obSCEne does not build without them.

Each project's own `docs/BUILDING.md` covers what that one needs, what its `check` runs, and
what its CI runs:
[orbistoun](https://github.com/project-oops/Orbistoun/blob/main/docs/BUILDING.md) ·
[obSCEne](https://github.com/project-oops/obSCEne/blob/main/docs/BUILDING.md) ·
[Prosperous](https://github.com/project-oops/Prosperous/blob/main/docs/BUILDING.md) ·
[SELFish](https://github.com/project-oops/SELFish/blob/main/docs/BUILDING.md) ·
[oops-libs](https://github.com/project-oops/oops-libs/blob/main/docs/BUILDING.md)

## Windows, WSL, and why obSCEne is different

The three Rust projects build anywhere. obSCEne compiles freestanding C with `clang` and
`lld`, which under Git Bash usually means neither is present.

`oops` detects that and re-enters through WSL rather than failing with a compiler error that
reads as a code fault. `OOPS_NO_WSL=1` refuses instead of delegating.

Two things had to be handled for that to work at all, and both fail in ways that point at the
wrong thing:

- **Path translation goes through `cygpath -m`, not `-w`.** The backslashes in a `C:\...` path
  are eaten before `wslpath` sees them, and it answers `C:gitOOPSobscene` rather than failing.
- **`MSYS_NO_PATHCONV=1` on the `wsl.exe` call.** Otherwise Git Bash rewrites the `/mnt/c/...`
  argument on its way to a Windows executable, so `wsl.exe` is handed
  `C:/Program Files/Git/mnt/c/...` and reports `ERROR_PATH_NOT_FOUND` for a directory that
  exists, having never been asked about the real one.

It also sources `~/.cargo/env` inside WSL. A login shell there does not necessarily have
rustup's bin directory on `PATH`, and a distro-packaged `/usr/bin/cargo` shadows it - old
enough to refuse a version-4 lock file, which it reports as a lock-file parse error rather
than as a version problem.

`oops doctor` reports all of this before you hit it.

## In CI

**Every job in every repository begins with the same three steps**, and the uniformity is
not tidiness - it is what stops the one failure this collection keeps producing.

```yaml
- uses: actions/checkout@v4
  with: { repository: ${{ github.repository_owner }}/OOPS, path: OOPS }
- uses: actions/checkout@v4
  with: { path: OOPS/obscene }

- name: Siblings this build needs
  run: OOPS/bin/oops bootstrap obscene
```

After that, a shared verb goes through the collection entry point, and a project's own
verb runs from the project:

```yaml
- name: Check
  run: OOPS/bin/oops check obscene

- name: Build the tooling
  run: ./bin/obscene tool-build
  working-directory: OOPS/obscene
```

The project is checked out **into** the OOPS layout because the layout is load-bearing:
every project resolves `oops-libs` by relative path, and obSCEne resolves SELFish and
Prosperous too, so a flat checkout does not build. Cloning the meta shallow and letting
`bootstrap` pull only the needed siblings is why a one-project job does not pay for five
checkouts.


### A private sibling needs a token

All six repositories are public, so `bootstrap` clones a sibling with no credential and this
section is here for the day one of them is not.

They were private for about twenty minutes, and it broke immediately: a workflow's own
`GITHUB_TOKEN` is scoped to the single repository it runs in, so obSCEne named SELFish and
Prosperous correctly and then failed with `could not read Username for 'https://github.com'`,
while `oops-libs` arrived because it was still public. Two other things went with it, and both
are worth knowing before anybody tries again: **GitHub Pages does not serve a private repository
on a free plan**, so all four sites went dark, and the four `pages.yml` workflows are gated on
`github.event.repository.visibility == 'public'` so they skip rather than fail red.

`bootstrap` reads **`OOPS_CI_TOKEN`** from the environment and uses it for the clone when it is
set, then rewrites the remote to the plain URL so the credential is not left in `.git/config`.
Every step that calls `bootstrap` passes it:

```yaml
      - name: Siblings this build needs
        run: OOPS/bin/oops bootstrap obscene
        env:
          OOPS_CI_TOKEN: ${{ secrets.OOPS_CI_TOKEN }}
```

Unset - which is the case today - nothing changes. The secret has to be created by hand: a
fine-grained token or a GitHub App installation token with read access to the org, added as an
organisation secret of that name.

### Three traps, all of which were live

None of these workflows has ever executed - there are no remotes yet - so every one of
these was found by reading rather than by a red pipeline.

- **A flat checkout.** `actions/checkout@v4` with no `path:` and no collection around it.
  It fails as a missing *directory* rather than as a missing dependency, which reads like
  a broken repository rather than a broken workflow. Five jobs were in this state,
  including the one that produces the release archives the landing pages link to.
- **A job-level working directory.** `defaults.run.working-directory: OOPS/obscene` and
  then `run: OOPS/bin/oops bootstrap obscene` resolves to `OOPS/obscene/OOPS/bin/oops`.
  So no job sets one; the bootstrap step runs from the workspace root and each project
  step names its own directory.
- **No bootstrap at all**, on the strength of a comment saying the project depended on
  nothing outside itself. True when written, false for months afterwards.

`tools/check-workflows.sh` now refuses all three, and `./bin/oops gates` runs it. It is a
meta-repository gate for the same reason the other two are: a workflow checks *itself* out,
and whether the collection is around it when it does cannot be seen from inside that
repository.

### On Windows runners, say `shell: bash`

`OOPS/bin/oops` has no extension, so under the Windows runner's default PowerShell it is
not an executable at all - the step fails as an unrecognised command, naming nothing to do
with this project. Git Bash is on the image, and it is the same shell `bin/oops.cmd` finds
for a person. orbistoun's test matrix and release build set it at job level.

### Passing arguments to a verb

`oops <verb> <project>...` reads **everything** after the verb as a project name, so
`oops build orbistoun --target x86_64-pc-windows-msvc` dies on `unknown project
'--target'`. Where a verb takes arguments, call the project's entry point directly with a
`working-directory` - which is what the release build does.

This repository's own workflow runs `./bin/oops gates`, for the same reason all of the
above go through an entry point: the moment the command CI runs and the command a person
runs are different commands, one of them is untested.
