# Issues

Open questions and defects for the collection itself, one line each. Each member repository
keeps its own `ISSUES.md`. Delete a line when it is resolved.

- Whether to merge the duplicate SELFish and orbistoun ELF, ABI and NID parsers beyond the differential test (orbistoun#D653).
- How much of SELFish's filesystem-writing layout comes from LGPL-3 sources, and what that requires.
- obSCEne has not been built once from a fresh clone.
- Projects reference siblings by local path (`<OOPS>/obscene`, `../selfish`); published URLs are needed for a lone clone.
- `oops tracer` writes to `orbistoun/titles/<id>/shaders` by default, a directory the titles library replaced.
- `tools/check-workflows.sh` does not check oops-mesa.
- `tools/check-dashes.sh` fails on em-dashes in member repositories.
- `tools/check-links.sh` takes about 40 minutes.
