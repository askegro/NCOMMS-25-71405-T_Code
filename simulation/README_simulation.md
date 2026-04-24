# RGM — Reconfigurable Battery Pack Lifetime Simulation

This repository contains the core simulation framework used in:

> A. Škegro, T. Wik, B. Bijlenga, A. Bessman, C. Zou,
> *System-level benefits of dynamic reconfiguration in electric vehicle
> battery packs: Lifetime extension and economic viability*,
> Nature Communications (2026).

The framework evaluates the lifetime extension achievable by reconfigurable battery packs (RBPs) relative to conventional fixed-configuration battery packs (CBPs) using large-scale Monte Carlo simulations with cell-level electrical and ageing models.

Post-processing, statistical analysis, figure generation, and economic evaluation scripts are available separately via Code Ocean.

---

## Repository structure

```
RGM-main/
├── run_RGM.sh                                                          # SLURM job array submission script (HPC)
└── files/
    ├── RGM_MATLAB_Main_f.m                                             # Top-level Monte Carlo simulation function
    ├── Load_CellModel_Elec_Aging.m                                     # Loads electrical and ageing model parameters
    ├── Init_InputDriveCycle.m                                          # Initialises drive cycle and operating limits
    ├── Init_DynamicDC.m                                                # Prepares dynamic (WLTC) current profile
    ├── Init_z_iRC.m                                                    # Initialises SOC and RC state variables
    ├── Init_R0_R_Tau.m                                                 # Initialises ECM resistance and time constants
    ├── Init_EFC_dQ_dR.m                                                # Initialises EFC and BOL capacity/resistance
    ├── CellModel_Elec_OutputEquation.m                                 # ECM output equation (terminal voltage, current)
    ├── Calculate_dQ_dR.m                                               # Computes incremental capacity loss and resistance increase
    ├── PrepareInputs.m                                                 # Derives ageing model inputs from cycle SOC history
    ├── DODStart.m                                                      # Records cycle start reference for ageing evaluation
    ├── AgingModel_BOL_Variation_2024_04_18.mat                         # BOL capacity/resistance distributions
    ├── LFP_Sony_Murata_US_26650_FTC1_Model_Electrical_2024_02_13_AS.mat   # LFP ECM parameters
    ├── LFP_Sony_Murata_US_26650_FTC1_Model_Aging_2025_02_14.mat           # LFP ageing model
    ├── NMC_Sanyo_UR_18650_E_Model_Electrical_2024_02_15_AS.mat            # NMC ECM parameters
    ├── NMC_Sanyo_UR_18650_E_Model_Aging_2025_02_25.mat                    # NMC ageing model
    └── WLTC.mat                                                        # WLTC drive cycle current profile
```

---

## Requirements

- MATLAB R2024b or later (earlier versions may work but have not been tested)
- Parallel Computing Toolbox (required for `parpool`)

No additional toolboxes are required.

---

## Quick start: local workstation

### 1. One required code change

The main simulation file contains one line specific to the High-Performance Computing (HPC) cluster environment that must be adapted for local use. Open `files/RGM_MATLAB_Main_f.m` and find:

```matlab
sched.JobStorageLocation = getenv('TMPDIR');
```

Replace it with:

```matlab
sched.JobStorageLocation = tempdir();
```

This redirects parallel pool job storage to your system's temporary directory instead of the HPC scratch disk.

### 2. Run a single scenario

Add the `files/` folder to your MATLAB path and call the main function directly:

```matlab
addpath('files');
RGM_MATLAB_Main_f( ...
    FLAG_CHEMISTRY,       ...  % Chemistry: 1 = LFP, 2 = NMC
    FLAG_AGINGMODEL_TC,   ...  % BOL variability test case: 1 (tight) or 2 (loose)
    N_ser,                ...  % Number of series-connected cells
    CELL_T,               ...  % Mean cell temperature [°C]
    CELL_T_SIGMA,         ...  % Std. deviation of cell temperature [°C]
    TIME_REST_PERC_DAY);       % Fraction of day spent at rest [-]
```

**Example** — LFP, tight manufacturing tolerances, 4 series cells, 25 °C, no thermal gradient, 20% rest fraction:

```matlab
RGM_MATLAB_Main_f(1, 1, 4, 25, 0.00, 0.20);
```

Alternatively, uncomment the manual input block near the top of `RGM_MATLAB_Main_f.m` for interactive debugging without function arguments.

### 3. Reducing computational load

The default number of Monte Carlo iterations is `numSims = 1000`. For quick verification runs, reduce this by editing the line:

```matlab
numSims = double(1000);
```

to a smaller value, e.g. `numSims = double(10)`.

---

## Input parameters

| Parameter | Description | Units | Values used in paper |
|---|---|---|---|
| `FLAG_CHEMISTRY` | Cell chemistry | — | 1 (LFP), 2 (NMC) |
| `FLAG_AGINGMODEL_TC` | BOL variability test case | — | 1 (tight), 2 (loose) |
| `N_ser` | Number of series-connected cells | — | 4, 16/14, 20, 50, 100, 200 |
| `CELL_T` | Mean cell temperature | °C | 25, 35, 45 |
| `CELL_T_SIGMA` | Std. deviation of cell temperature | °C | 0.00, 0.42, 0.83 |
| `TIME_REST_PERC_DAY` | Fraction of day spent at rest | — | 0.20, 0.95 |

Note: `N_ser = 16` is used for NMC and `N_ser = 14` for LFP at the approximately 50 V voltage class. All other `N_ser` values are identical across chemistries.

---

## Output

Each simulation run produces a `.mat` file named:

```
out_CHEM_<c>_TC_<tc>_Ns_<n>_T_<t>_Tsig_<ts>_Trest_<tr>_1000.mat
```

where the tags encode the input parameter combination. The file contains two structures:

### `Outputs`

| Field | Description | Units |
|---|---|---|
| `chi_EFC_perc_All` | Lifetime extension per Monte Carlo run (EFC-based) | % |
| `chi_time_perc_All` | Lifetime extension per Monte Carlo run (time-based) | % |
| `FLAG_SIM_STOP_All` | True if all cells reached EOL before the time limit | — |
| `FLAG_SIM_SHORT_All` | True if any cell did not reach EOL within the time limit | — |
| `t_EOL` | Time at which each cell crossed 80% SOH, per run | s |
| `EFC_EOL` | EFC at which each cell crossed 80% SOH, per run | — |
| `dQ_cell_i` | Remaining cell capacity fraction (SOH) at EOL, per run | p.u. |
| `dR_cell_i` | Cell resistance scaling factor at EOL, per run | p.u. |
| `simTime_iter_All` | Wall-clock time per Monte Carlo iteration | s |

The primary output used in the paper is `chi_EFC_perc_All`, from which the mean lifetime extension $\bar{\chi}$ and its standard deviation $s_\chi$ are computed across the 1,000 Monte Carlo runs.

### `Experiment`

Records the fixed simulation configuration: `FLAG_CHEMISTRY`, `FLAG_AGINGMODEL_TC`, `FLAG_CURRENTINPUT`, `N_ser`, `CELL_T`, `CELL_T_SIGMA`.

---

## Full parameter sweep: HPC cluster

The complete sweep reported in the paper comprises 240 scenarios (216 LFP + 24 NMC), each with 1,000 Monte Carlo iterations, submitted as a SLURM job array on the National Academic Infrastructure for Supercomputing in Sweden (NAISS), accessed through Chalmers University of Technology. The submission script `run_RGM.sh` is configured for the C3SE Vera cluster and uses 40 parallel cores per job.

To rerun the full sweep on a compatible cluster:

```bash
mkdir Results
sbatch run_RGM.sh
```

Output `.mat` files are written to the `Results/` subdirectory.

Note that `run_RGM.sh` uses `RunMatlab.sh`, a C3SE-specific wrapper that restarts MATLAB automatically if it crashes at startup under high concurrent load. On other clusters, replace this with a direct `matlab` call:

```bash
matlab -nodisplay -nosplash -r "RGM_MATLAB_Main_f(...); exit;"
```

---

## Reproducibility

The global RNG is seeded at `41` (Mersenne Twister) and per-worker streams use a Threefry generator seeded at `42` with per-iteration substreams, ensuring reproducible results regardless of worker assignment order.

Post-processing scripts used to generate all figures and the economic analysis in the paper are available via Code Ocean.

---

## Citation

If you use this code, please cite:

```
A. Škegro, T. Wik, B. Bijlenga, A. Bessman, C. Zou,
System-level benefits of dynamic reconfiguration in electric vehicle
battery packs: Lifetime extension and economic viability,
Nature Communications, 2026.
```

---

## Licence

Please refer to the repository licence file for terms of use.
