# OOPS Ecosystem User Guide

Welcome to the **OOPS** (**O**rbistoun, **o**bSCEne, **P**rosperous, **S**ELFish) user guide.

This guide is designed for **homebrew developers, operators, hardware testers, and curious users** who want to build, package, deploy, or emulate console applications using 100% clean-room, first-party tools.

If you are an AI coding agent or an emulator/compiler architect looking for formal specifications, ABI layouts, or decision records, consult the **[Technical Reference & THE LOOP](THE_LOOP.md)** instead.

---

## Table of Contents

1. [Prerequisites & Environment Setup](#1-prerequisites--environment-setup)
2. [Building & Installing the First-Party Tools](#2-building--installing-the-first-party-tools)
3. [End-to-End Workflows](#3-end-to-end-workflows)
   - [Workflow A: Build and Package Homebrew](#workflow-a-build-and-package-homebrew)
   - [Workflow B: Deploy & Manage on Real Hardware](#workflow-b-deploy--manage-on-real-hardware)
   - [Workflow C: Run & Test in the Orbistoun Emulator](#workflow-c-run--test-in-the-orbistoun-emulator)
4. [Component User Guides](#4-component-user-guides)
5. [Troubleshooting & FAQ](#5-troubleshooting--faq)

---

## 1. Prerequisites & Environment Setup

OOPS uses a dual-environment toolchain:
- **Host Tools** (`selfish`, `pros`, `orbistoun`): Written in Rust, running natively on Windows or Linux.
- **Target Payloads** (`obscene`, `oops-sdk`, `oops-apps`): Freestanding C/C++ cross-compiled for x86-64 FreeBSD/Prospero.

### Required Software:
1. **Rust Toolchain**: Rust 1.80+ (`rustup default stable`).
2. **Container or WSL for Target Cross-Compilation**:
   - **Windows**: Use WSL2 (with Ubuntu / Debian) or Docker Desktop (`silkeh/clang:18`).
   - **Linux**: Clang 18+ and `lld` installed natively.

---

## 2. Building & Installing the First-Party Tools

To build the primary host command-line tools into your environment:

```powershell
# In PowerShell (Windows) or bash (Linux)
git clone https://github.com/project-oops/OOPS.git
cd OOPS

# Build the packager (selfish)
cargo build --release -p selfish-cli
# Build the target bridge (pros)
cargo build --release -p pros-cli
# Build the emulator (orbistoun)
cargo build --release -p orbistoun-cli
```

Binaries will land in `target/release/` (`selfish.exe`, `pros.exe`, `orbistoun.exe`). Add this directory to your `PATH` or invoke them directly.

---

## 3. End-to-End Workflows

```
  [C Source Code]
        │ (make in WSL / Docker)
        ▼
   [app.elf]
        │
        ├── (selfish --format title) ──► [Title Directory: GLCB00001/]
        │                                      │
        │                                      ├── (pros restore / launch) ──► Physical PS5
        │                                      │
        │                                      └── (orbistoun run) ──────────► Orbistoun Emulator
        ▼
   [eboot.bin]
```

### Workflow A: Build and Package Homebrew

1. **Compile the App Payload**:
   In your WSL terminal or Linux shell, navigate to an app in `oops-apps`:
   ```bash
   cd oops-apps/src/oops-gl/gl1-cube
   make title
   ```
   This automatically:
   - Compiles freestanding C source into `gl1-cube.elf`.
   - Compiles the companion `libc.prx` module.
   - Calls `selfish --format title` to layout `build/title/GLCB00001/` with generated `param.json`, `icon0.png`, `keystone`, `nptitle.dat`, and `pfs-version.dat`.

2. **Verify Title Directory**:
   Inspect the contents:
   ```powershell
   ls build/title/GLCB00001
   # Output: eboot.bin, sce_module/, sce_sys/
   ```

### Workflow B: Deploy & Manage on Real Hardware

1. **Register Your Target Console**:
   ```powershell
   pros.exe register 192.168.1.211 --name ps5-testbed
   ```

2. **Verify Console Health**:
   ```powershell
   pros.exe check
   ```
   *Expectation*: All 5 active ports should respond (`elfldr:9021`, `ftpsrv:2121`, `klogsrv:3232`, `shsrv:2323`, `pldmgr:8084`).

3. **Stage the Title**:
   ```powershell
   pros.exe restore build/title/GLCB00001 /data/homebrew/GLCB00001
   ```

4. **Launch and Stream Telemetry**:
   ```powershell
   # In terminal 1: Stream live system logs
   pros.exe logs

   # In terminal 2: Launch the title
   pros.exe launch GLCB00001
   ```

### Workflow C: Run & Test in the Orbistoun Emulator

1. **Run Title Directory**:
   ```powershell
   orbistoun.exe run build/title/GLCB00001
   ```

2. **Inspect Call Report & Compare Traces**:
   ```powershell
   # View calls made by the guest during execution
   orbistoun.exe report

   # Compare against the previous execution trace
   orbistoun.exe verify
   ```

---

## 4. Paths and Portable Mode Across OOPS

All host tools in the collection (`pros`, `orbistoun`, `selfish`, `obscene-tool`) share a unified platform storage layout resolved at runtime by `oops-paths`:

### Default Storage Layout
- **Windows**: `%APPDATA%\OOPS\`
- **Linux**: `~/.local/share/OOPS/` (or `$XDG_DATA_HOME/OOPS/`)

All tools share this directory:
```text
%APPDATA%\OOPS\
├── targets.txt      <- Registered consoles (shared between pros, orbistoun, and obscene)
├── titles/          <- Staged titles and guest filesystems (shared between pros and orbistoun)
├── saves/           <- Mounted save files
└── reports/         <- Hardware conformance reports and telemetry
```

### Portable Mode

Drop a `.portable` directory (or sentinel file) next to your OOPS executables, or set `OOPS_PORTABLE=1`:

```text
<wherever you put your tools>/
    pros.exe
    orbistoun.exe
    selfish.exe
    .portable        <- Sentinel directory or file
    targets.txt      <- Written right beside the binaries
    titles/
    saves/
```

In portable mode:
- **Zero footprint**: Nothing is written to `%APPDATA%` or host user profiles.
- **Self-contained**: You can run the entire toolchain, emulator, and target bridge off a USB stick or portable directory.
- **Binary Naming**: Any binary whose filename contains `portable` (e.g. `orbistoun-portable.exe` or `pros-portable.exe`) automatically operates in portable mode.

---

## 5. Modular Component User Guides

Following the in-house documentation standard, each project maintains dedicated, per-screen modular feature documents with screenshot placeholders and CLI/GUI side-by-side parity:

- 🔌 **Prosperous Features & Screens**: [**`prosperous/docs/features/`**](../prosperous/docs/features/README.md)
  - [User Guide & Portable Mode](../prosperous/docs/features/user-guide.md)
  - [Target Browser & Health Matrix](../prosperous/docs/features/targets.md)
  - [Live Kernel Telemetry Streamer](../prosperous/docs/features/logs.md)
  - [Remote Storage Browser](../prosperous/docs/features/files.md)
  - [Title Supervisor & Launcher](../prosperous/docs/features/titles.md)
  - [Remote Command Shell](../prosperous/docs/features/shell.md)
  - [Payload Injector](../prosperous/docs/features/payloads.md)

- 🎮 **Orbistoun Features & Screens**: [**`orbistoun/docs/features/`**](../orbistoun/docs/features/README.md)
  - [User Guide & Requirements](../orbistoun/docs/features/user-guide.md)
  - [Game Library & Dashboard](../orbistoun/docs/features/library.md)
  - [Execution Runner & Verification](../orbistoun/docs/features/running.md)
  - [Call Trace & HLE Inspector](../orbistoun/docs/features/inspector.md)
  - [Virtual Memory & Register State](../orbistoun/docs/features/memory.md)
  - [Graphics & Vulkan 1.3 Settings](../orbistoun/docs/features/graphics.md)
  - [Controller & Keyboard Mapping](../orbistoun/docs/features/controllers.md)
  - [NID Imports & Symbol Resolution](../orbistoun/docs/features/naming.md)
  - [Paths & Portable Storage](../orbistoun/docs/features/paths.md)

- 📦 **SELFish Packaging Recipes**: [**`selfish/docs/features/`**](../selfish/docs/features/README.md)
  - [User Guide & Syntax](../selfish/docs/features/user-guide.md)
  - [Signed Executable Wrapping (eboot)](../selfish/docs/features/eboot.md)
  - [Retail Title Directory Layout](../selfish/docs/features/title.md)
  - [Encrypted PFS Packages (PKG)](../selfish/docs/features/pkg.md)

- 🔬 **obSCEne Probing Modes**: [**`obscene/docs/features/`**](../obscene/docs/features/README.md)
  - [User Guide & Telemetry Grammar](../obscene/docs/features/user-guide.md)
  - [Raw Socket Payload (:9021)](../obscene/docs/features/payload.md)
  - [Full-Screen BIG_APP HUD](../obscene/docs/features/eboot.md)
  - [Retail Sandbox Package](../obscene/docs/features/pkg.md)

- 🛠️ **Supporting Repositories**:
  - [oops-sdk Developer Handbook](../oops-sdk/docs/USER_GUIDE.md)
  - [oops-apps Catalog & Tracer Guide](../oops-apps/docs/USER_GUIDE.md)
  - [oops-libs Host Developer Guide](../oops-libs/docs/USER_GUIDE.md)

---

## 6. Troubleshooting & FAQ

### Q: Why does `pros check` report target timeout?
- **Check IP Address**: Ensure your console's local network IP matches your registration (`pros register <IP>`).
- **Jailbreak Status**: The payload loader (`elfldr`) and background daemons run volatile in RAM. If the console rebooted, re-run the jailbreak environment on the console.
- **Firewall**: Ensure your host PC firewall does not block outbound traffic to ports `9021`, `2121`, `3232`, `2323`, and `8084`.

### Q: Can I run commercial retail games in Orbistoun right now?
- No. No emulator anywhere runs commercial PS5 retail titles today. Orbistoun currently loads, links, and executes native code for homebrew and tests, advancing call by call through our closed-loop oracle (**THE LOOP**).

### Q: Why does `pros restore` fail with directory errors?
- Make sure you are using the latest `pros` build. Our updated FTP client properly handles `226 Directory created` responses from embedded console servers.
