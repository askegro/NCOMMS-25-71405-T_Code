# RGM — Reconfigurable Battery Pack Simulation and Analysis

This repository contains the complete simulation and postprocessing
code used in:

> A. Škegro, T. Wik, B. Bijlenga, A. Bessman, C. Zou,
> *System-Level Assessment of Dynamic Reconfiguration
> for Lifetime and Cost
Outcomes in Electric Vehicle Battery Packs*,
> Nature Communications (2026).

---

## Repository structure

```text
RGM/
├── simulation/          # Core Monte Carlo simulation framework
│   ├── files/           # MATLAB routines, cell models, drive cycle data
│   └── run_RGM.sh       # SLURM job array script (HPC cluster)
└── postprocessing/      # Figure generation and economic analysis
    ├── code/            # MATLAB scripts for all figures
    ├── data/            # Raw simulation outputs and processed data
    └── results/         # Generated figures (written on execution)
```

---

## Two-component workflow

The repository is split into two independent components that correspond
to the two stages of the analysis:

**1. Simulation** (`simulation/`)

Runs the cell-level Monte Carlo simulations that evaluate lifetime
extension across 240 parameter combinations. Each scenario runs 1,000
Monte Carlo iterations with stochastic cell-to-cell manufacturing
variability. The full sweep was executed on the National Academic
Infrastructure for Supercomputing in Sweden (NAISS), accessed through
Chalmers University of Technology. Individual scenarios can be run on
a standard MATLAB workstation. See `simulation/README.md` for details.

**2. Postprocessing** (`postprocessing/`)

Generates all figures and the economic analysis reported in the paper,
reading directly from the raw simulation output files included in
`postprocessing/data/raw/`. All figures can therefore be reproduced
without rerunning the simulations. See `postprocessing/README.md`
for details.

---

## Quick start

To reproduce all figures directly:

```matlab
cd postprocessing/code
run_all_figures
```

To run a single simulation scenario on a local workstation:

```matlab
cd simulation/files
% Replace getenv('TMPDIR') with tempdir() in RGM_MATLAB_Main_f.m first
RGM_MATLAB_Main_f(1, 1, 4, 25, 0.00, 0.20)
```

---

## Requirements

| Component | Requirement |
|---|---|
| Simulation | MATLAB R2024b or later, Parallel Computing Toolbox |
| Postprocessing | MATLAB R2023b or later, Statistics and Machine Learning Toolbox |

---

## Citation

If you use this code, please cite:

```
A. Škegro, T. Wik, B. Bijlenga, A. Bessman, C. Zou,
System-Level Assessment of Dynamic Reconfiguration for Lifetime and Cost
Outcomes in Electric Vehicle Battery Packs,
Nature Communications, 2026.
```

---

## Licence

Source code in this repository is licensed under the MIT License; see `LICENSE`.

Data files in `postprocessing/data/` are dedicated to the public domain
under CC0 1.0; see `postprocessing/data/LICENSE`.

If you use this repository, please cite the associated publication.
