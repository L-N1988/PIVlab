# Repository Guidelines

## Project Structure & Module Organization
`PIVlab_GUI.m` is the main entry point for the desktop MATLAB app. Core functionality is split into MATLAB package folders at the repository root, including `+piv` (correlation/analysis), `+preproc`, `+postproc`, `+import`, `+export`, `+gui`, and hardware-related modules such as `+acquisition` and `+opencv`. Keep new functions in the closest existing package rather than adding flat root files.

Tests live in [`unittests/`](./unittests), sample inputs in [`Example_data/`](./Example_data), and automation examples in [`Example_scripts/`](./Example_scripts). User docs and the project website are in [`docs/`](./docs); packaged resources and MATLAB project metadata are under [`resources/`](./resources) and should only be edited when packaging behavior changes.

## Build, Test, and Development Commands
Run locally with MATLAB R2019b+:

```bash
matlab -batch "PIVlab_GUI"
```

Open the MATLAB project when you need project-scoped settings:

```bash
matlab -batch "openProject('PIVlab_source.prj'); PIVlab_GUI"
```

Execute the current unit suite:

```bash
matlab -batch "results=runtests('unittests'); assert(all([results.Passed]))"
```

Exercise the non-GUI workflow with the shipped example:

```bash
matlab -batch "run('Example_scripts/PIVlab_commandline.m')"
```

## Coding Style & Naming Conventions
Follow the style of the file you are editing; this codebase is legacy MATLAB and mixes tabs and spaces. Avoid whitespace-only rewrites. Use lowercase snake_case for most function files (for example, `piv_FFTmulti.m`) and preserve the existing `_Callback` suffix for UI callbacks. Keep one primary function per file, prefer package-qualified calls such as `piv.piv_FFTmulti`, and use short comments only where the math or control flow is not obvious.

## Testing Guidelines
Tests use MATLAB `functiontests`. The current pattern is a wrapper in `unittests/` that exposes local tests embedded in the implementation file. When modifying analysis code, add or update focused numeric assertions near the affected algorithm and make sure `runtests('unittests')` passes before opening a PR.

## Commit & Pull Request Guidelines
Recent history uses short, imperative subjects such as `bug fixes`, `packaging fixes`, and `modified demo mode`. Prefer concise, subsystem-first messages like `gui: fix demo mode toggle` or `piv: tighten FFT correlation test`. PRs should state the user-visible change, list MATLAB/toolbox assumptions, link relevant issues, and include screenshots for GUI changes or sample-output notes for algorithm changes.
