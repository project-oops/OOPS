# Building

`bin/oops` drives the whole collection, relaying to each repository's own entry point.

```bash
./bin/oops doctor           # verify required tools are present
./bin/oops build            # build every project
./bin/oops build orbistoun  # build one project
./bin/oops test prosperous  # test one project
./bin/oops all              # collection gates, then every project's check
```

On Windows, `. X:\toolchains\paths.ps1` (or `call X:\toolchains\paths.cmd`) activates the
toolchain in the current session, and `bin\oops.cmd` runs the collection verbs.

## Prerequisites and dependencies

The collection consists of host tools in Rust and target software in freestanding C and C++.
Every dependency runs natively on the host machine.

| Dependency | Purpose | Requirement |
|---|---|---|
| **Git** | Repository and submodule management | 2.30+ |
| **Rust / Cargo** | Host tools (`orbistoun`, `prosperous`, `selfish`, `oops-libs`) | Current stable |
| **Clang / LLVM** | Target C and C++ cross-compilation (`clang`, `clang++`, `lld`, `llvm-ar`, `llvm-nm`, `llvm-readelf`) | Pinned to major version 21 |
| **GNU Make** | Target build orchestration (`oops-sdk`, `oops-apps`, `oops-mesa`, `obscene`) | 4.0+ (Windows-native binary on Windows) |
| **Python 3** | ROM conversion and XML asset pack scripts | 3.10+ (with standard `zipfile` module) |
| **POSIX utilities** | Shell recipes (`sh`, `find`, `grep`, `sed`, `awk`, `tr`, `sort`, `cut`, `cat`) | Standard coreutils on Linux; Git Bash on Windows |

## Installation instructions

### Linux (Ubuntu / Debian)

1. **System packages and POSIX utilities:**
   ```bash
   sudo apt update
   sudo apt install -y git build-essential python3 curl wget
   ```

2. **Rust:**
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source "$HOME/.cargo/env"
   ```

3. **Clang 21 and LLVM tools:**
   Install Clang 21 using the official LLVM APT repository:
   ```bash
   wget https://apt.llvm.org/llvm.sh
   chmod +x llvm.sh
   sudo ./llvm.sh 21 all
   ```
   Ensure the binaries are discovered as `clang`, `clang++`, `lld`, `llvm-ar` on `PATH`:
   ```bash
   sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-21 100 \
       --slave /usr/bin/clang++ clang++ /usr/bin/clang++-21 \
       --slave /usr/bin/lld lld /usr/bin/lld-21 \
       --slave /usr/bin/llvm-ar llvm-ar /usr/bin/llvm-ar-21 \
       --slave /usr/bin/llvm-nm llvm-nm /usr/bin/llvm-nm-21 \
       --slave /usr/bin/llvm-readelf llvm-readelf /usr/bin/llvm-readelf-21
   ```

4. **Verify the environment:**
   ```bash
   ./bin/oops doctor
   ```

### Linux (Arch Linux)

```bash
sudo pacman -S git base-devel clang lld llvm python rustup curl
rustup default stable
./bin/oops doctor
```

### Linux (Fedora)

```bash
sudo dnf install -y git make gcc clang lld llvm python3 rust cargo curl
./bin/oops doctor
```

### Windows (Native)

Building on Windows runs natively with standard command-line tools.

1. **Git and POSIX utilities:**
   Install Git for Windows from [git-scm.com](https://git-scm.com/) or via `winget`:
   ```powershell
   winget install Git.Git
   ```
   Git Bash provides standard POSIX utilities (`sh`, `find`, `grep`, `sed`, `awk`, `tr`) under
   `C:\Program Files\Git\usr\bin`.

2. **Rust:**
   Install Rust via `winget` or download `rustup-init.exe` from [rustup.rs](https://rustup.rs/):
   ```powershell
   winget install Rustlang.Rustup
   rustup default stable
   ```

3. **GNU Make (Windows-native binary):**
   Install a native Windows GNU Make 4.4+ (e.g. via Chocolatey or unpacked to `X:\toolchains\make`):
   ```powershell
   choco install make -y
   ```
   *Do not use an MSYS or Cygwin make.* The makefiles derive source paths using `$(CURDIR)`,
   which must produce Windows drive paths (`C:/...`) that `clang.exe` can open rather than
   Unix-style mounts (`/c/...`).

4. **Clang 21 and LLVM tools:**
   Unpack portable LLVM 21 release binaries to a local directory (e.g. `X:\toolchains\llvm21`).
   Ensure `clang.exe`, `clang++.exe`, `lld.exe`, `llvm-ar.exe`, `llvm-nm.exe`, and
   `llvm-readelf.exe` are present in its `bin` directory.

5. **Python 3:**
   ```powershell
   winget install Python.Python.3.14
   ```

6. **Environment activation:**
   Activate the toolchain for your shell session:
   - PowerShell:
     ```powershell
     . X:\toolchains\paths.ps1
     ```
   - Command Prompt (CMD):
     ```cmd
     call X:\toolchains\paths.cmd
     ```

7. **Verify the environment:**
   ```powershell
   bash bin/oops doctor
   ```

## Parallel builds

Makefiles in the collection automatically detect available logical processors on both Linux
and Windows. When no `-j` flag is specified on the command line, GNU Make defaults to
two-thirds of the host's logical cores (`MAKEFLAGS += -j<N>`, e.g. 21 workers on a 32-thread
machine) to maximize compilation throughput while keeping the system responsive. Passing
`-j<N>` explicitly overrides this default.

## Building applications and titles

The exact same command builds an application on both Linux and Windows:

```bash
cd oops-apps/src/oops-titles/ship-of-harkinian
make SOH_ARMED=1
```

For native Windows builds, `common/deps.mk` automatically writes long object lists to
response files (`@file`) to prevent exceeding the Windows command line character limit
(32,767 characters). The same response file mechanism runs on Linux.

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
