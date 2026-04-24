#!/bin/bash
#SBATCH -A C3SE2024-11-05
#SBATCH -n 40
#SBATCH --array=1-240

module load MATLAB/2024b

# ============================================================================
# Build the full parameter list inline.
# Each combination is assigned an index; the job picks its own by
# matching against $SLURM_ARRAY_TASK_ID.
# ============================================================================

# ----------------------------------------------------------------------------
# LFP sweep (FLAG_CHEMISTRY = 1)
#   Full sweep over pack size, temperature and sigma variability.
# ----------------------------------------------------------------------------
CHEMISTRY=1
TEST_CASES=(1 2)
N_SER_VALUES=(4 16 20 50 100 200)
TEMPERATURES=(25 35 45)
T_SIGMAS=(0.00 0.42 0.83)
REST_FRACS=(0.20 0.95)

idx=0
for TC in "${TEST_CASES[@]}"; do
for NS in "${N_SER_VALUES[@]}"; do
for T in "${TEMPERATURES[@]}"; do
for TSIG in "${T_SIGMAS[@]}"; do
for TREST in "${REST_FRACS[@]}"; do
    idx=$((idx + 1))
    if [ "$idx" -eq "$SLURM_ARRAY_TASK_ID" ]; then
        FLAG_CHEMISTRY=$CHEMISTRY
        FLAG_AGINGMODEL_TC=$TC
        N_ser=$NS
        CELL_T=$T
        CELL_T_SIGMA=$TSIG
        TIME_REST_PERC_DAY=$TREST
    fi
done; done; done; done; done

# ----------------------------------------------------------------------------
# NMC sweep (FLAG_CHEMISTRY = 2)
#   Restricted to T=25 and Tsig=0 (no multi-temperature data available).
# ----------------------------------------------------------------------------
CHEMISTRY=2
TEST_CASES=(1 2)
N_SER_VALUES=(4 14 20 50 100 200)
TEMPERATURES=(25)
T_SIGMAS=(0.00)
REST_FRACS=(0.20 0.95)

for TC in "${TEST_CASES[@]}"; do
for NS in "${N_SER_VALUES[@]}"; do
for T in "${TEMPERATURES[@]}"; do
for TSIG in "${T_SIGMAS[@]}"; do
for TREST in "${REST_FRACS[@]}"; do
    idx=$((idx + 1))
    if [ "$idx" -eq "$SLURM_ARRAY_TASK_ID" ]; then
        FLAG_CHEMISTRY=$CHEMISTRY
        FLAG_AGINGMODEL_TC=$TC
        N_ser=$NS
        CELL_T=$T
        CELL_T_SIGMA=$TSIG
        TIME_REST_PERC_DAY=$TREST
    fi
done; done; done; done; done

# ============================================================================
# Copy files to scratch, run, copy result back.
# RunMatlab.sh is used instead of calling matlab directly, as it restarts
# MATLAB automatically if it crashes at startup — necessary when many jobs
# are submitted simultaneously on the C3SE cluster.
# ============================================================================
cp files/* $TMPDIR/
cd $TMPDIR

RunMatlab.sh -o "-nodisplay -nosplash -r \"RGM_MATLAB_Main_f( \
    ${FLAG_CHEMISTRY}, \
    ${FLAG_AGINGMODEL_TC}, \
    ${N_ser}, \
    ${CELL_T}, \
    ${CELL_T_SIGMA}, \
    ${TIME_REST_PERC_DAY}); exit;\"" < /dev/null

cp out_*.mat $SLURM_SUBMIT_DIR/Results/