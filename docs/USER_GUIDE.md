# User guide

Building an application, running it on hardware, and running it in the emulator, with the
collection's own tools. [THE_LOOP.md](THE_LOOP.md) explains how these steps feed each other;
[BUILDING.md](BUILDING.md) covers the toolchain and `bin/oops`.

## The tools

The host tools are Rust and run natively on Windows and Linux. Target code is freestanding C,
cross-compiled with clang 21 in the `silkeh/clang:21` container or the WSL `oops-builder`
distribution (`./bin/oops setup`).

```bash
./bin/oops build selfish prosperous orbistoun
```

| Tool | Binary | Purpose |
|---|---|---|
| SELFish | `selfish/target/release/selfish` | containers, title directories, packages |
| Prosperous | `prosperous/target/release/pros` | registering a target, deploying, launching, logs |
| Orbistoun | `orbistoun/target/release/orbistoun-cli`, or `./bin/orbistoun` | running a title in the emulator |

Every host tool keeps its data under one root, `%APPDATA%\OOPS` on Windows, or beside the
binary in portable mode. The [oops-libs guide](../oops-libs/docs/USER_GUIDE.md) gives the
layout and its overrides.

## From source to title

```
[C source]
    | make, in the container or WSL
    v
[app.elf] -- selfish --format title --> [title directory, e.g. GLCB00001/]
                                            |-- pros restore, pros launch --> hardware
                                            '-- orbistoun run ----------------> emulator
```

### Build and package an app

```bash
cd oops-apps/src/oops-gl/gl1-cube
make title
```

`make title` compiles the app, and calls `selfish --format title` to lay out
`build/title/GLCB00001/` with `eboot.bin`, `sce_module/` and `sce_sys/` (`param.json`,
`icon0.png` and the other metadata a title carries).

### Run it on hardware

```bash
pros register <address> --name <name>
pros check
pros restore build/title/GLCB00001 /data/homebrew/GLCB00001
pros logs            # in a second terminal, before launching
pros launch GLCB00001
```

`pros check` expects the target's services on ports 9021 (payload loader), 2121 (FTP), 3232
(kernel log), 2323 (shell) and 8084 (payload manager).

### Run it in the emulator

```bash
cd orbistoun
./bin/orbistoun run GLCB00001
```

`run` finds the title in the title library, runs it until it exits, faults or stops, and
reports the verdict against the previous run. `orbistoun-cli questions` ranks what guests asked
for that is still unknown, and `orbistoun-cli worklist` ranks what to implement next.

## Per-project guides

- Prosperous: [getting started](../prosperous/docs/guide/getting-started.md),
  [targets](../prosperous/docs/guide/targets.md), [logs](../prosperous/docs/guide/logs.md),
  [files](../prosperous/docs/guide/files.md), [titles](../prosperous/docs/guide/titles.md),
  [library](../prosperous/docs/guide/library.md), [shell](../prosperous/docs/guide/shell.md),
  [payloads](../prosperous/docs/guide/payloads.md)
- Orbistoun: [features](../orbistoun/docs/features/README.md)
- SELFish: [user guide](../selfish/docs/USER_GUIDE.md)
- obSCEne: [user guide](../obscene/docs/USER_GUIDE.md)
- oops-sdk: [user guide](../oops-sdk/docs/USER_GUIDE.md)
- oops-apps: [user guide](../oops-apps/docs/USER_GUIDE.md)
- oops-libs: [user guide](../oops-libs/docs/USER_GUIDE.md)

## Troubleshooting

`pros check` times out:

- The address registered with `pros register` is the target's current address.
- The payload loader and the services run in memory, so a restarted target needs them started
  again.
- No firewall on the host blocks ports 9021, 2121, 3232, 2323 or 8084.
