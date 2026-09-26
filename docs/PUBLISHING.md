# Repositories and submodules

Every project is published under the `project-oops` organisation and is a submodule of this
repository.

| Repository | Submodule directory |
|---|---|
| https://github.com/project-oops/OOPS | the collection |
| https://github.com/project-oops/Orbistoun | `orbistoun` |
| https://github.com/project-oops/obSCEne | `obscene` |
| https://github.com/project-oops/Prosperous | `prosperous` |
| https://github.com/project-oops/SELFish | `selfish` |
| https://github.com/project-oops/oops-libs | `oops-libs` |
| https://github.com/project-oops/oops-sdk | `oops-sdk` |
| https://github.com/project-oops/oops-apps | `oops-apps` |
| https://github.com/project-oops/oops-mesa | `oops-mesa` |

The directory names are lower-case because the projects find each other by relative path on
case-sensitive filesystems: `OOPS/obscene/tool/Cargo.toml` resolves
`../../selfish/crates/selfish-abi` to `OOPS/selfish/crates/selfish-abi`. A nested or renamed
layout does not build.

## Cloning

Cloning this repository gets every project, arranged so they build:

```bash
git clone --recurse-submodules https://github.com/project-oops/OOPS
```

A clone of one project is for using its releases, not for changing its code; obSCEne, for one,
does not build without its siblings. `./bin/oops bootstrap <project>` fetches the siblings a
project needs into an existing checkout of this repository.

## Updating the pins

A submodule pins a revision, so this repository records a set of revisions known to work
together. Updating is a deliberate commit:

```bash
git submodule update --remote
```

## Private repositories

A workflow's `GITHUB_TOKEN` reads only its own repository, so `bootstrap` cannot clone a
private sibling with it; it takes `OOPS_CI_TOKEN` instead ([BUILDING.md](BUILDING.md#a-private-sibling)).
GitHub Pages does not serve a private repository on the free plan, and each project's
`pages.yml` runs only when `github.event.repository.visibility == 'public'`.
