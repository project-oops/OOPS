# Building

`bin/oops` drives the whole collection.

```bash
./bin/oops build            # every project
./bin/oops build orbistoun  # one project
./bin/oops test prosperous
./bin/oops all              # the collection gates, then every project's check
```

On Windows outside Git Bash, `bin\oops.cmd` finds Git Bash and runs the same script.

## One set of verbs

Every repository carries `bin/<project>` with the same verbs, and `bin/oops` relays to it, so
these are one command:

```bash
./bin/oops test selfish
cd selfish && ./bin/selfish test
```

How a project builds is known only to its own entry point. oops-sdk, oops-apps and oops-mesa
wrap `make`; the rest wrap cargo.

| Verb | What it does |
|---|---|
| `build [project...]` | build artefacts |
| `test [project...]` | run tests |
| `lint [project...]` | lints at `-D warnings` |
| `fmt [project...]` | format in place |
| `check [project...]` | the project's full gate, as its CI runs it |
| `clean [project...]` | remove build output |
| `doc [project...]` | build the API docs |

The rest are `bin/oops` only, because they concern the collection:

| Verb | What it does |
|---|---|
| `pkg` | obSCEne's installable package |
| `gates` | the collection gates ([tools/README.md](../tools/README.md)) |
| `all` | `gates`, then `check` in every project |
| `bootstrap [project...]` | fetch the members, or the named ones and their dependencies |
| `git <args...>` | run any git command in the root and every member |
| `status` | branch and working-tree state of each repository |
| `doctor` | whether this machine can build the collection |
| `setup` | install WSL, the `oops-builder` distribution and the toolchain |
| `exec "<cmd>" [project...]` | run a command in each project |
| `list` | the members and whether each is present |
| `tracer <titleid>` | capture a title's shaders on hardware and rank the shader translator's gaps |

No project means every project, and a name may be shortened while it stays unambiguous
(`oops test pros`). A failing project does not stop the others; failures are listed at the end
and the exit code is non-zero. Each `bin/<project> --help` lists the verbs that project adds.

## Dependencies

The sibling paths in each project's manifests, which `bootstrap` follows:

```
oops-libs    <- nothing
oops-sdk     <- nothing (freestanding C)
selfish      <- oops-libs
orbistoun    <- oops-libs, selfish (dev-dependency, orbistoun#D653)
prosperous   <- oops-libs, selfish (selfish-title)
obscene      <- selfish, prosperous, oops-libs, oops-sdk (a make edge)
oops-mesa    <- oops-sdk (a make edge)
oops-apps    <- oops-sdk, oops-mesa, selfish (make edges; selfish packages titles)
```

No project builds from a clone of its own repository alone. Each project's own build notes:
[orbistoun](https://github.com/project-oops/Orbistoun/blob/main/docs/BUILDING.md),
[obSCEne](https://github.com/project-oops/obSCEne/blob/main/docs/BUILDING.md),
[Prosperous](https://github.com/project-oops/Prosperous/blob/main/docs/BUILDING.md),
[SELFish](https://github.com/project-oops/SELFish/blob/main/docs/BUILDING.md),
[oops-libs](https://github.com/project-oops/oops-libs/blob/main/README.md#building),
[oops-sdk](https://github.com/project-oops/oops-sdk/blob/main/docs/BUILDING.md),
[oops-apps](https://github.com/project-oops/oops-apps#building-an-app).

## Windows, WSL, and why obSCEne is different

The Rust projects build anywhere. obSCEne, oops-sdk, oops-apps and oops-mesa compile
freestanding C for the target with `clang` and `lld` (CONVENTIONS section 8). Under Git Bash
without clang, `bin/oops` runs those four through WSL; `OOPS_NO_WSL=1` refuses instead.
`oops doctor` reports whether WSL has a distribution with clang in it.

`./bin/oops setup` (`tools/setup-wsl.sh`) registers a WSL distribution named `oops-builder`
from the Ubuntu image, runs it as root, and installs the toolchain in it. It installs only what
is missing, so it can be rerun, and `--dry-run` prints what it would do. On Linux it installs
the same packages directly. `wsl --unregister oops-builder` removes the distribution.
`WSL_DISTRO` names another distribution to build in, whose configuration is left alone.

Both scripts choose a distribution by one rule: `WSL_DISTRO`, else `oops-builder`, else WSL's
default when it is a usable one, else the first usable one. Container runtimes' own
distributions (Docker Desktop, Rancher, podman) are never used, and Docker Desktop can be
WSL's default.

## In CI

Every job in every repository begins with the same steps, because each project resolves its
siblings by relative path and a flat checkout does not build:

```yaml
- uses: actions/checkout@v4
  with: { repository: ${{ github.repository_owner }}/OOPS, path: OOPS }
- uses: actions/checkout@v4
  with: { path: OOPS/obscene }

- name: Siblings this build needs
  run: OOPS/bin/oops bootstrap obscene
```

A shared verb then goes through the collection entry point, and a project's own verb runs
from the project directory:

```yaml
- name: Check
  run: OOPS/bin/oops check obscene

- name: Build the tooling
  run: ./bin/obscene tool-build
  working-directory: OOPS/obscene
```

No job sets `defaults.run.working-directory`: the bootstrap step runs from the workspace root,
and each project step names its own directory. `tools/check-workflows.sh` checks every
workflow for this shape.

On Windows runners, a step that runs `OOPS/bin/oops` sets `shell: bash`; PowerShell cannot run
a script with no extension.

`oops <verb> <project>...` reads every argument after the verb as a project name. A verb that
takes further arguments is run through the project's own entry point with a
`working-directory`.

### A private sibling

`bootstrap` clones siblings anonymously. With `OOPS_CI_TOKEN` set it clones with that token,
then resets the remote to the plain URL so the token is not left in `.git/config`:

```yaml
      - name: Siblings this build needs
        run: OOPS/bin/oops bootstrap obscene
        env:
          OOPS_CI_TOKEN: ${{ secrets.OOPS_CI_TOKEN }}
```

The secret is an organisation secret holding a fine-grained token, or a GitHub App
installation token, with read access to the organisation's repositories.
