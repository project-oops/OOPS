# AGENTS.md

Top-level instructions and constraints for coding agents working across the OOPS collection.

**Read [the OOPS conventions](docs/CONVENTIONS.md) first.** Provenance, naming, decision logs, worklogs, and gates are shared across [Orbistoun](orbistoun/), [obSCEne](obscene/), [Prosperous](prosperous/), [SELFish](selfish/), [oops-sdk](oops-sdk/), and [oops-apps](oops-apps/), and are stated once there.

---

## 1. First-Party Tooling: Eat Our Own Dogfood, Never Bypass (CONVENTIONS §10)

The OOPS collection builds and maintains its own toolchain for every layer of the platform stack:
- **`SELFish`**: File formats, container wrapping (`--format eboot`), title directory layout (`--format title`), and package authoring (`--format pkg`).
- **`Prosperous` (`pros`)**: Target registration, reachability checking (`pros check`), execution (`pros launch`, `pros send`), log streaming (`pros logs`), and title lifecycle (`pros close`, `pros titles`).
- **`oops-sdk` / `oops-apps/common/app.mk`**: Freestanding libc stubs, RDNA2 AGC graphics, audio, input, and application build gates.
- **`obscene-tool`**: Symbol census, fixed module tagging (`mkmodule`), and conformance probing.

### Rules for All Agents:
1. **Never bypass first-party tools with scratch scripts.**
   Do not write one-off Python, PowerShell, or bash scripts to manually stitch ELF headers, fake metadata files (`param.json`, `keystone`, `nptitle.dat`), borrow binaries/PRXs from sibling project build trees, or push files over raw FTP sockets when a tool exists for that operation.
2. **If a tool lacks a flag or fails, fix the tool.**
   Bypassing tools starves them of the defect reports and edge cases needed to mature. If `selfish` needs a new argument, `app.mk` has an incomplete build rule, or `pros` needs an improved command, modify and test the tool directly rather than routing around it.
3. **Use the canonical project interfaces:**
   - Build applications: `make elf`, `make eboot`, or `make title` via `app.mk`.
   - Layout title directories: `selfish --format title` (which automatically synthesizes conforming `param.json`, fake-signed `keystone`, `nptitle.dat`, `pfs-version.dat`, and default icon).
   - Talk to hardware: `pros check`, `pros launch <ID>`, `pros send <ELF>`, `pros logs`.

---

## 2. Toolchains: Container First, Portable Second, Installed Last

Per machine global instructions:
1. **Already installed?** Use it (check `PATH` / WSL before assuming missing).
2. **Run it in a container.** WSL `oops-builder` and Docker (`silkeh/clang:18`) are the standard runners for cross-compilation and testing.
3. **Portable install to `X:\toolchains\<name>`** when a container genuinely will not do.
4. **Never perform quiet machine-wide system installs.**

---

## 3. Strict Clean-Room Provenance (CONVENTIONS §1)

- Zero leaked headers, zero vendor SDK files, zero disassembly reproduction.
- Freestanding C runtime only (`-nostdlib -ffreestanding`).
- Any external open-source references consulted must be credited in the relevant project's `ACKNOWLEDGEMENTS.md`.

---

## 4. Hardware Safety (Target Testing)

- **Fail-safe GPU rasterization:** All rendering code must handle submit errors or fence timeouts gracefully by failing safe to CPU rasterization, logging to `klog`, and never hanging the hardware ring.
- **Never make unapproved git commits:** Keep working trees clean, verify with automated test suites (`make test` in `oops-sdk`, `make check` in `oops-apps`), and report findings clearly.

---

## 5. Coding Agent Tiering & LLM Developer Toolchain

Development across OOPS relies on autonomous and pair-programming LLM agents acting as translation glue and systems engineers. We explicitly tier the models employed and document their operational profiles:

### Primary Model Tiering (In Order of Priority):

1. **Gemini 3.8 Flash (Primary Workhorse / Closed-Loop Driver)**:
   - **Role**: Primary driver for the autonomous oracle loop. Fast HLE translation, parsing real-time `klog` telemetry from `pros logs`, compiling test harnesses, navigating multi-file workspaces, and executing mechanical diffs.
   - **Strengths**: High-throughput context window, rapid response times, and resilient handling of low-level memory maps, physical addresses, and bare-metal registers without false-positive safety interruptions.
   - **Default**: Used for 90% of routine loop operations and systems implementation.

2. **Claude Opus 5 (Architectural Reasoning & Deep Compiler Design)**:
   - **Role**: High-complexity compiler transformations (RDNA2 Wave32 control-flow restructuring, SPIR-V SSA lowering), architectural boundaries, and deep diagnostic triage.
   - **Operational Consideration (Invalid Cyber Refusals)**:
     Anthropic models (Claude / Opus) are prone to false-positive halts triggered by low-level security terminology, raw memory addresses, ROP gadgets, or hardware jailbreak mechanics (misclassifying systems-level console research as offensive cyber exploitation).
     *Mitigation*: When driving or prompting Opus 5, frame all tasks strictly in clean-room systems engineering terminology (e.g. "hardware abstraction", "conformance probing", "memory mapping", "virtual memory layout", "dynamic linker relocation") rather than offensive or exploit-related jargon.

3. **Fable 5.1 (Exploratory Sweeps & Candidate Verification)**:
   - **Role**: Cross-checking symbol candidate grammars, vocabulary expansion, and secondary hypothesis generation when the primary loop hits an ambiguous diagnostic.


