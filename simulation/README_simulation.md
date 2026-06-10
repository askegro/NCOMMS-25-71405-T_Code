# Simulation

Monte Carlo simulation of lifetime extension from dynamic battery pack reconfiguration.
Each run evaluates one of 240 parameter combinations across 1,000 iterations.

## Folder structure

```
simulation/
├── files/       # MATLAB source files, cell electrical/aging models (.mat), drive cycle data
├── Results/     # Output .mat files written by run_RGM.sh (must exist before submitting)
└── run_RGM.sh   # SLURM job array script (240 tasks)
```

## Running on the HPC cluster (NAISS/C3SE)

Create the output directory, then submit:

```bash
mkdir -p Results
sbatch run_RGM.sh
```

Each SLURM task copies its output file (`out_*.mat`) into `Results/` upon completion.

## Running a single scenario locally

Open MATLAB, then:

```matlab
cd simulation/files
% Replace getenv('TMPDIR') with tempdir() in RGM_MATLAB_Main_f.m first
RGM_MATLAB_Main_f(1, 1, 4, 25, 0.00, 0.20)
```

Arguments: `(FLAG_CHEMISTRY, FLAG_AGINGMODEL_TC, N_ser, CELL_T, CELL_T_SIGMA, TIME_REST_PERC_DAY)`

**Requirement:** MATLAB R2024b or later, Parallel Computing Toolbox.
