% ============================================================================
% FUNCTION: RGM_MATLAB_Main_f
% ----------------------------------------------------------------------------
% PURPOSE:
%   Top-level Monte Carlo simulation.
%
%   For each of numSims independent Monte Carlo iterations:
%     1. Cell parameters (capacity, resistance) are sampled from BOL
%        distributions to represent manufacturing spread.
%     2. The pack is cycled through a repeated Discharge -> CC Charge -> Rest
%        sequence until all cells reach end-of-life (SOH < SOH_DEAD).
%     3. At each Rest->Discharge transition, incremental aging (dQ, dR) is
%        evaluated and applied to update cell parameters.
%     4. Per-cycle and full-run quantities are logged and stored.
%
%   After all iterations, results are aggregated, sorted, and saved to a
%   uniquely named .mat file determined by the input parameter combination.
%
% ----------------------------------------------------------------------------
% OPERATING MODE STATE MACHINE:
%   OpMode encodes the current phase of the charge-discharge cycle:
%
%     0  — Initial CC charge   (startup: charge to SOC_max before first discharge)
%     2  — Initial Rest        (startup: rest after initial charge)
%    41  — Discharge           (CC or dynamic drive cycle)
%    42  — CC Charge
%    43  — CV Charge           (inactive: transitions directly to Rest)
%    44  — Rest
%
%   Active transitions:
%     0  -> 2   : SOC_max reached during initial charge
%     2  -> 41  : rest duration reached
%    41  -> 42  : SOC_min reached during discharge
%    42  -> 44  : SOC_max reached during CC charge
%    44  -> 41  : rest duration reached  (aging evaluated here)
%
%
% ----------------------------------------------------------------------------
% INPUTS:
%   FLAG_CHEMISTRY_input        - Chemistry selector: 1 = LFP, 2 = NMC     [-]
%   FLAG_AGINGMODEL_TC_input    - BOL variability test case: 1, 2, or 3     [-]
%   N_ser_input                 - Number of series-connected PUs             [-]
%   CELL_T_input                - Mean cell temperature                     [°C]
%   CELL_T_SIGMA_input          - Std. deviation of cell temperature        [°C]
%   TIME_REST_PERC_DAY_input    - Fraction of the day spent resting          [-]
%
% OUTPUTS:
%   Saves 'out_<runID>_<numSims>.mat' containing:
%     Outputs  — aggregated scalar and array results across all iterations
%     Experiment — fixed simulation configuration parameters
% ============================================================================

function RGM_MATLAB_Main_f(FLAG_CHEMISTRY_input, FLAG_AGINGMODEL_TC_input, N_ser_input, CELL_T_input, CELL_T_SIGMA_input, TIME_REST_PERC_DAY_input)

    % Manual input override (inactive: used for interactive debugging):
    % clearvars; clc;
    % FLAG_CHEMISTRY_input     = 1;
    % FLAG_AGINGMODEL_TC_input = 1;
    % N_ser_input              = 4;
    % CELL_T_input             = 25;
    % CELL_T_SIGMA_input       = 0;
    % TIME_REST_PERC_DAY_input = 0.2;
    % rng(41, "twister");

    
    % ========================================================================
    % Environment setup.
    % ========================================================================

    % Add the current folder and all subfolders to the MATLAB path.
    addpath(genpath(pwd));

    % Seed the global RNG for reproducibility across runs.
    rng(41, "twister");
    


    % ========================================================================
    % Run identifier: encode all input parameters into a unique filename tag.
    %   Fractional inputs are scaled to integers, e.g. 0.95 -> 95, 0.083 -> 83.
    % ========================================================================

    Trest_str = num2str(round(TIME_REST_PERC_DAY_input * 100));
    Tsig_str  = num2str(round(CELL_T_SIGMA_input * 100));
    T_str     = num2str(round(CELL_T_input));

    runID = sprintf('CHEM_%d_TC_%d_Ns_%d_T_%s_Tsig_%s_Trest_%s', ...
        FLAG_CHEMISTRY_input, ...
        FLAG_AGINGMODEL_TC_input, ...
        N_ser_input, ...
        T_str, ...
        Tsig_str, ...
        Trest_str);



    % ========================================================================
    % Parallel pool setup.
    %   Initialises the Parallel Computing Toolbox on the cluster node.
    %   Job storage is directed to $TMPDIR (the node's local scratch disk)
    %   for fast I/O. The number of workers is detected automatically from
    %   the SLURM allocation (#SBATCH -n).
    % ========================================================================

    delete(gcp('nocreate'));
    sched                    = parcluster('local');
    sched.JobStorageLocation = getenv('TMPDIR');
    parpool(sched, sched.NumWorkers);

    % Per-worker RNG stream: Threefry generator, seeded at 42.
    % Each iteration sets its own substream to ensure independent,
    % reproducible random draws regardless of worker assignment.
    sc = parallel.pool.Constant(@() RandStream('Threefry', 'Seed', 42));
    clear('sched');
    
        
    
    % ========================================================================
    % Simulation configuration.
    % ========================================================================

    % Number of Monte Carlo iterations.
    numSims = double(1000);

    % Output filename for this run.
    resultsFileName = sprintf('out_%s_%d.mat', runID, numSims);

    % ------------------------------------------------------------------------
    % Decision variables: passed in from the function arguments.
    % ------------------------------------------------------------------------

    % Cell chemistry: 1 = LFP, 2 = NMC.
    FLAG_CHEMISTRY   = FLAG_CHEMISTRY_input;

    % BOL aging model variability test case: 1, 2, or 3.
    FLAG_AGINGMODEL_TC = FLAG_AGINGMODEL_TC_input;

    % Drive cycle type: 1 = CC discharge, 2 = dynamic (WLTC).
    FLAG_CURRENTINPUT = 2;

    % Pack configuration: number of series-connected parallel units.
    N_ser = N_ser_input;                                                        % [-]

    % Cell temperatures: sampled from a Gaussian to represent thermal spread.
    CELL_T       = CELL_T_input;
    CELL_T_SIGMA = CELL_T_SIGMA_input;
    T_i_degC     = double(normrnd(CELL_T, CELL_T_SIGMA, [N_ser, 1]));          % [°C]

    % Fraction of each day that the pack spends at rest.
    TIME_REST_PERC_DAY = TIME_REST_PERC_DAY_input;                             % [-]

    % ------------------------------------------------------------------------
    % Simulation time and step sizes.
    % ------------------------------------------------------------------------
    SOH_DEAD         = double(0.97); %double(0.8);                                             % [-]   EOL threshold (80% capacity)

    t_sim_base       = double(500000); %double(50000000);                                        % [s]   Maximum simulation horizon
    t_sim            = t_sim_base;
    t_stepsize_base  = double(1);                                               % [s]   Base step size (discharge)
    N_timepoints     = floor(t_sim / t_stepsize_base);

    decim            = 1;                                                       % [-]   Logging decimation factor

    % Adaptive step sizes for each cycle phase.
    % Larger steps are used during charge and rest to reduce compute time.
    t_stepsize_disc      = t_stepsize_base;                                     % [s]   Discharge
    t_stepsize_chg_fast  = 100 * t_stepsize_disc;                               % [s]   Early CC charge
    t_stepsize_chg_slow  = 20  * t_stepsize_disc;                               % [s]   Late CC charge (near SOC_max)
    % t_stepsize_rest is computed dynamically per cycle from TIME_REST_MAX.

    % Auxiliary broadcast vectors (avoids repeated construction inside loop).
    AllOnes  = double(ones(N_ser, 1));
    AllZeros = double(zeros(N_ser, 1));
    


    % ========================================================================
    % Model initialisation: load cell electrical and aging models.
    % ========================================================================

    [CellModel_Elec, CellModel_Aging, Q_cell_nom, ~, ~, ...
        dQ_cell_i_BOL_mean, dQ_cell_i_BOL_std, ...
        dR_cell_i_BOL_mean, dR_cell_i_BOL_std] = ...
        Load_CellModel_Elec_Aging(FLAG_CHEMISTRY, FLAG_AGINGMODEL_TC, T_i_degC);



    % ========================================================================
    % Monte Carlo simulation loop.
    % ========================================================================

    % Preallocate the results structure array (scalar fields only; array fields
    % are added dynamically inside the loop).
    Results2(numSims) = struct( ...
        'index',         0,     ...
        'FLAG_SIM_STOP', false, ...
        'FLAG_SIM_SHORT',false, ...
        'chi_time_perc', 0,     ...
        'chi_EFC_perc',  0,     ...
        'simTime_iter',  0);

    tStart = tic;
    ticBytes(gcp);

    parfor iter = 1:numSims

        try            

        % Assign this iteration its own RNG substream for reproducibility.
        stream            = sc.Value;
        stream.Substream  = iter;

        tStart_iter = tic;

        % --------------------------------------------------------------------
        % Per-iteration state initialisation.
        % --------------------------------------------------------------------

        % Phase timers.
        t_Rest      = 0;
        t_DC        = 0;
        t_dyn_start = 0;

        % Cycle reference timestamps (initialised to 1 to trigger bootstrap
        % mode in Calculate_dQ_dR on the first aging evaluation).
        t_cycStart_days     = 1;
        Ah_cell_i_cycStart  = 1;
        EFC_cell_i_cycStart = 1;

        % Simulation clock.
        t_stepsize = t_stepsize_base;
        t_current  = t_stepsize;

        % Termination flags.
        FLAG_SIM_STOP  = false;
        FLAG_SIM_SHORT = false;

        % EOL tracking: time and EFC at which each cell crosses SOH_DEAD.
        t_EOL         = AllZeros;
        EFC_EOL       = AllZeros;
        first_crossing = zeros(N_ser, 1);

        % Temporary variable initialization
        dt_sec      = [];
        z_mean_i    = [];
        C_rate_i    = [];
        dDOD_i      = [];
        dEFC_cell_i = [];


        % --------------------------------------------------------------------
        % Per-cycle logging arrays (grown dynamically, one row per cycle).
        % --------------------------------------------------------------------
        cycle_idx      = uint32(0);     % Cycle counter; incremented at Rest->Discharge
        cycle_dyn_dur  = double([]);    % Dynamic phase duration (Discharge + Charge)  [s]
        cycle_rest_dur = double([]);    % Preceding rest duration                       [s]
        cycle_start_t  = double([]);    % Timestamp at start of Discharge               [s]
        cycle_end_t    = double([]);    % Timestamp at end of dynamic phase             [s]
        dis_start_t    = double([]);    % Timestamp when Discharge begins               [s]
        chg_start_t    = double([]);    % Timestamp when CC Charge begins               [s]
        cycle_dis_dur  = double([]);    % Discharge duration per cycle                  [s]
        cycle_chg_dur  = double([]);    % CC Charge duration per cycle                  [s]

        % Per-cycle aging input features (one row per cycle, one col per cell).
        zmean_log = double(zeros(0, N_ser));    % Mean SOC per cycle
        dt_log    = double(zeros(0, N_ser));    % Cycle duration [s]
        Crate_log = double(zeros(0, N_ser));    % Mean C-rate
        dDOD_log  = double(zeros(0, N_ser));    % DOD
        dEFC_log  = double(zeros(0, N_ser));    % Incremental EFC


        % --------------------------------------------------------------------
        % Full-run logging arrays (pre-allocated, decimated by 'decim').
        % --------------------------------------------------------------------
        N_log          = floor(N_timepoints / decim);
        z_log          = double(zeros(N_ser, N_log));   % SOC
        EFC_log        = double(zeros(N_ser, N_log));   % Cumulative EFC
        dQloss_cal_log = double(zeros(N_ser, N_log));   % Calendar capacity loss
        dQloss_cyc_log = double(zeros(N_ser, N_log));   % Cyclic capacity loss
        t_log          = zeros(1, N_log);               % Time [s]
        log_k          = uint32(0);

        % Cycle-window SOC buffer (reset at each Rest->Discharge transition).
        z_cell_i_store = [];
        t_store        = [];



        % --------------------------------------------------------------------
        % Electrical model initialisation.
        % --------------------------------------------------------------------
        [z_cell_i, iRC_cell_i] = Init_z_iRC(AllOnes, AllZeros, N_ser, CellModel_Elec);

        [R0_cell_i, R_cell_i, ~, tau1_cell_active] = Init_R0_R_Tau(CellModel_Elec, T_i_degC, AllOnes, t_stepsize);
        R0_cell_i_init = R0_cell_i;
        R_cell_i_init  = R_cell_i;   
    
        

        % --------------------------------------------------------------------
        % Aging model initialisation.
        % --------------------------------------------------------------------
        [EFC_cell_i, dQ_cell_i, dR_cell_i] = Init_EFC_dQ_dR(AllZeros, ...
            dQ_cell_i_BOL_mean, dQ_cell_i_BOL_std, N_ser, ...
            dR_cell_i_BOL_mean, dR_cell_i_BOL_std);
        dQ_cell_i_init = dQ_cell_i;
        dR_cell_i_init = dR_cell_i;
              


        % --------------------------------------------------------------------
        % Drive cycle initialisation.
        % --------------------------------------------------------------------
        [CC_dis_Crate, CC_dis_I, ~, ~, CC_chg_I, ...
            ~, ~, ~, ~, SOC_min, SOC_max, TIME_REST_MAX] = ...
            Init_InputDriveCycle(Q_cell_nom, CellModel_Elec, TIME_REST_PERC_DAY);

        [~, DC_Input_Current_final_i_PU, DC_Input_Current_final_t, t_DC_end] = ...
            Init_DynamicDC(FLAG_CURRENTINPUT, CC_dis_Crate, Q_cell_nom, CellModel_Elec);
    
        
        

        % --------------------------------------------------------------------
        % Simulation state variable initialisation.
        % --------------------------------------------------------------------

        % Electrical.
        Q_cell_i = Q_cell_nom * dQ_cell_i;                                     % [Ah]  Effective cell capacity

        % Aging accumulators (initialised to zero, matching cell vector size).
        dQ_loss_i     = 0 * dQ_cell_i;
        dR_inc_i      = 0 * dR_cell_i;
        dQ_loss_cal_i = 0 * dQ_cell_i;
        dQ_loss_cyc_i = 0 * dQ_cell_i;
        dR_inc_cal_i  = 0 * dR_cell_i;
        dR_inc_cyc_i  = 0 * dR_cell_i;

        % Operating mode: start in initial CC charge (mode 0).
        OpMode = 0;
        i_PU   = CC_chg_I;

        % Flag to detect whether the first DODStart snapshot has been taken.
        FLAG_DOD_INIT_SET = false;


        % ====================================================================
        % Main time-stepping loop.
        % ====================================================================
        for idx_time = 1:N_timepoints
        
            % Advance simulation clock (held at t_stepsize on the first step).
            if (idx_time > 1)
                t_current = t_current + t_stepsize;
            end

            % ----------------------------------------------------------------
            % Termination check: stop if all cells have reached EOL.
            % ----------------------------------------------------------------
            FLAG_SIM_STOP = all(dQ_cell_i(:) < SOH_DEAD);
            if FLAG_SIM_STOP
                break
            end     
        
        

            % ----------------------------------------------------------------
            % State update: ECM Euler step.
            % ----------------------------------------------------------------

            % Current step (k): resolve cell branch current from current i_PU.
            [~, ~, i_cell_i]  = CellModel_Elec_OutputEquation(CellModel_Elec, z_cell_i, R0_cell_i, R_cell_i, iRC_cell_i, i_PU);

            % Pre-compute RC discrete-time coefficients for this step size.
            RC_cell_i   = exp(-t_stepsize ./ abs(tau1_cell_active));
            A_RC_cell_i = RC_cell_i;
            B_RC_cell_i = 1 - A_RC_cell_i;

            % Next step (k+1): advance SOC, RC state, and EFC.
            z_cell_i   = z_cell_i   - (1/3600) * t_stepsize * i_cell_i ./ Q_cell_i;
            iRC_cell_i = A_RC_cell_i .* iRC_cell_i + B_RC_cell_i .* i_cell_i;
            EFC_cell_i = EFC_cell_i  + (1/3600) * t_stepsize * abs(i_cell_i) / (2 * Q_cell_nom);

            
            % ----------------------------------------------------------------
            % Diagnostics: evaluate state bounds.
            % ----------------------------------------------------------------
            z_min = min(z_cell_i(:));                                           % [-]   Minimum SOC across all cells
            z_max = max(z_cell_i(:));                                           % [-]   Maximum SOC across all cells

            % Voltage-based limits (inactive: SOC limits used instead):
            % v_PU_min = min(v_PU_i(:));
            % v_PU_max = max(v_PU_i(:));
            % FLAG_V_MIN_REACHED = (v_PU_min < CC_dis_V_min);
            % FLAG_V_MAX_REACHED = (v_PU_max > CC_chg_V_max);

            FLAG_SOC_MIN_REACHED = (z_min < SOC_min);
            FLAG_SOC_MAX_REACHED = (z_max > SOC_max);
            FLAG_REST_TIME_HIGH  = (t_Rest >= TIME_REST_MAX);

            % CV charge cutoff flags (inactive: CV phase bypassed):
            % FLAG_CV_CHG_I_CUTOFF_LOW = (abs(i_PU) < abs(CV_chg_I_cutoff));
            % FLAG_CV_T_HIGH           = (t_CV > CV_chg_t_max);
        

            % ----------------------------------------------------------------
            % Operating mode flags: decode current OpMode integer.
            % ----------------------------------------------------------------
            FLAG_OPMODE_INIT_CCCHG = (OpMode == 0);
            % FLAG_OPMODE_INIT_CVCHG = (OpMode == 1);   % inactive
            FLAG_OPMODE_INIT_REST  = (OpMode == 2);
            FLAG_OPMODE_CCDIS      = ((FLAG_CURRENTINPUT == 1) && (OpMode == 41));
            FLAG_OPMODE_DC         = ((FLAG_CURRENTINPUT == 2) && (OpMode == 41));
            FLAG_OPMODE_CCCHG      = (OpMode == 42);
            % FLAG_OPMODE_CVCHG    = (OpMode == 43);    % inactive
            FLAG_OPMODE_REST       = (OpMode == 44);  
        

            % ----------------------------------------------------------------
            % Transition flags: evaluate all state machine edges.
            % ----------------------------------------------------------------

            % Active transitions:
            FLAG_TRANS_0_2   = (FLAG_OPMODE_INIT_CCCHG && FLAG_SOC_MAX_REACHED);
            FLAG_TRANS_2_41  = (FLAG_OPMODE_INIT_REST  && FLAG_REST_TIME_HIGH);
            FLAG_TRANS_41_42 = ((FLAG_OPMODE_CCDIS || FLAG_OPMODE_DC) && FLAG_SOC_MIN_REACHED);
            FLAG_TRANS_42_44 = (FLAG_OPMODE_CCCHG && FLAG_SOC_MAX_REACHED);
            FLAG_TRANS_44_41 = (FLAG_OPMODE_REST   && FLAG_REST_TIME_HIGH);

            % Inactive transitions (CV phase):
            % FLAG_TRANS_0_1   = (FLAG_OPMODE_INIT_CCCHG && (FLAG_V_MAX_REACHED || FLAG_SOC_MAX_REACHED));
            % FLAG_TRANS_1_41  = (FLAG_OPMODE_INIT_CVCHG && (FLAG_CV_CHG_I_CUTOFF_LOW || FLAG_CV_T_HIGH));
            % FLAG_TRANS_42_43 = (FLAG_OPMODE_CCCHG && (FLAG_V_MAX_REACHED || FLAG_SOC_MAX_REACHED));
            % FLAG_TRANS_43_41 = (FLAG_OPMODE_CVCHG && (FLAG_CV_CHG_I_CUTOFF_LOW || FLAG_CV_T_HIGH));

            % Composite mode and transition flags.
            FLAG_OPMODE_CCCHG_ANY  = (FLAG_OPMODE_INIT_CCCHG || FLAG_OPMODE_CCCHG);
            FLAG_OPMODE_REST_ANY   = (FLAG_OPMODE_INIT_REST   || FLAG_OPMODE_REST);
            FLAG_OPMODE_DIS_ANY    = (FLAG_OPMODE_CCDIS       || FLAG_OPMODE_DC);
            FLAG_TRANS_CCCHG_REST  = (FLAG_OPMODE_CCCHG_ANY && (FLAG_TRANS_0_2  || FLAG_TRANS_42_44));
            FLAG_TRANS_REST_DIS    = (FLAG_OPMODE_REST_ANY  && (FLAG_TRANS_2_41 || FLAG_TRANS_44_41));
            FLAG_TRANS_CCDIS_CCCHG = (FLAG_OPMODE_DIS_ANY  && FLAG_TRANS_41_42);
            % FLAG_TRANS_CCCHG_CVCHG = (FLAG_OPMODE_CCCHG_ANY && (FLAG_TRANS_0_1 || FLAG_TRANS_42_43));
            % FLAG_TRANS_CVCHG_DIS   = (FLAG_OPMODE_CVCHG_ANY && (FLAG_TRANS_1_41 || FLAG_TRANS_43_41));
               
        

            % ================================================================
            % Operating mode actions: one branch fires per time step.
            % ================================================================

            % ----------------------------------------------------------------
            % MODE: Discharge (CC or dynamic): not transitioning yet.
            % ----------------------------------------------------------------
            if (FLAG_OPMODE_DIS_ANY && ~FLAG_TRANS_CCDIS_CCCHG)

                if (FLAG_OPMODE_DC)
                    % Dynamic drive cycle: look up i_PU from the profile.
                    if (t_DC < t_DC_end)
                        i_PU = interp1(DC_Input_Current_final_t, DC_Input_Current_final_i_PU, t_DC, 'previous');
                        t_DC = t_DC + t_stepsize;
                    else
                        % Profile exhausted: wrap back to the start.
                        t_DC = 0;
                    end
                else
                    % CC discharge: constant current.
                    i_PU = CC_dis_I;
                end
        
        
        
            % ----------------------------------------------------------------
            % TRANSITION: Discharge -> CC Charge (SOC_min reached).
            % ----------------------------------------------------------------
            elseif (FLAG_OPMODE_DIS_ANY && FLAG_TRANS_CCDIS_CCCHG)

                OpMode     = 42;
                i_PU       = CC_chg_I;
                t_stepsize = t_stepsize_chg_fast;

                % Log end of discharge phase and start of charge phase.
                if cycle_idx >= 1
                    cycle_dis_dur(cycle_idx, 1) = double(t_current - dis_start_t(cycle_idx));
                    chg_start_t(cycle_idx, 1)   = t_current;
                end
        

            % ----------------------------------------------------------------
            % MODE: CC Charge: not transitioning yet.
            % ----------------------------------------------------------------
            elseif (FLAG_OPMODE_CCCHG_ANY && ~FLAG_TRANS_CCCHG_REST)

                i_PU = CC_chg_I;

                % Slow down the step size as SOC approaches the upper limit.
                if (SOC_max - z_max < 0.2)
                    t_stepsize = t_stepsize_chg_slow;
                end
         
        
            % ----------------------------------------------------------------
            % TRANSITION: CC Charge -> Rest (SOC_max reached).
            %   (CV charge phase is inactive: transitions directly to Rest.)
            % ----------------------------------------------------------------

            % Inactive: CC Charge -> CV Charge transition.
            % elseif (FLAG_OPMODE_CCCHG_ANY && FLAG_TRANS_CCCHG_CVCHG)
            %     OpMode = (FLAG_TRANS_0_1) * 1 + (~FLAG_TRANS_0_1) * 43;
            %     i_PU   = CVChg_Calculate_i_PU(CellModel_Elec, z_cell_i, ...
            %                 iRC_cell_i, R0_cell_i, R_cell_i, N_ser, CC_chg_I, CV_chg_V);
            %     t_CV   = 0;

            %%%% If CC charge -> Rest... %%%%
            elseif (FLAG_OPMODE_CCCHG_ANY && FLAG_TRANS_CCCHG_REST)

                % Set mode: 2 = initial rest (before first discharge), 44 = regular rest.
                if (FLAG_TRANS_0_2)
                    OpMode = 2;
                else
                    OpMode = 44;
                end

                i_PU      = 0;
                t_dyn_end = t_current;
                t_dyn     = t_dyn_end - t_dyn_start;

                % Log end of charge phase.
                if cycle_idx >= 1 && numel(chg_start_t) >= cycle_idx && chg_start_t(cycle_idx) > 0
                    cycle_chg_dur(cycle_idx, 1) = double(t_current - chg_start_t(cycle_idx));
                end

                % Compute rest duration proportional to the dynamic phase length.
                % TIME_REST_MAX = t_dyn * (TIME_REST_PERC_DAY / (1 - TIME_REST_PERC_DAY))
                TIME_REST_MAX    = ceil((1 / (1 - TIME_REST_PERC_DAY_input) - 1) * t_dyn);
                t_stepsize_rest  = ceil(TIME_REST_MAX / 4);

                % Log dynamic phase duration for this cycle.
                if cycle_idx > 0 && numel(cycle_dyn_dur) < cycle_idx
                    cycle_dyn_dur(cycle_idx, 1) = double(t_dyn);
                    cycle_end_t(cycle_idx, 1)   = t_current;
                end

                % Start the rest timer and switch to the rest step size.
                t_Rest     = 0;
                t_stepsize = t_stepsize_rest;
        

            % ----------------------------------------------------------------
            % MODE: Rest: not transitioning yet.
            % ----------------------------------------------------------------

            % Inactive: CV Charge mode.
            % elseif (FLAG_OPMODE_CVCHG_ANY && ~FLAG_TRANS_CVCHG_DIS)
            %     i_PU = CVChg_Calculate_i_PU(CellModel_Elec, z_cell_i, ...
            %                iRC_cell_i, R0_cell_i, R_cell_i, N_ser, CC_chg_I, CV_chg_V);
            %     t_CV = t_CV + t_stepsize;

            elseif (FLAG_OPMODE_REST_ANY && ~FLAG_TRANS_REST_DIS)

                i_PU   = 0;
                t_Rest = t_Rest + t_stepsize;
    
    
            % ----------------------------------------------------------------
            % TRANSITION: Rest -> Discharge.
            %   This is the main aging evaluation point. Incremental dQ and dR
            %   are computed from the SOC history of the completed cycle, then
            %   applied to update all cell parameters before the next discharge.
            % ----------------------------------------------------------------

            % Inactive: CV Charge -> Discharge transition.
            % elseif (FLAG_OPMODE_CVCHG_ANY && FLAG_TRANS_CVCHG_DIS)

            elseif (FLAG_OPMODE_REST_ANY && FLAG_TRANS_REST_DIS)

                prevRest = t_Rest;                  % Save rest duration for cycle log.

                % Set mode and initial current for the new discharge phase.
                OpMode = 41;
                if (FLAG_CURRENTINPUT == 1)
                    i_PU = CC_dis_I;
                else
                    i_PU = DC_Input_Current_final_i_PU(1);
                    t_DC = DC_Input_Current_final_t(1);
                end

                t_stepsize = t_stepsize_disc;


                % ------------------------------------------------------------
                % Aging evaluation.
                % ------------------------------------------------------------
                if (~FLAG_DOD_INIT_SET)

                    % First transition: record cycle start reference only;
                    % no aging to compute yet (no completed cycle available).
                    [t_cycStart_days, ~, Ah_cell_i_cycStart, EFC_cell_i_cycStart, ~] = ...
                        DODStart(idx_time, t_stepsize, z_cell_i, EFC_cell_i, Q_cell_nom, decim, t_current);

                    FLAG_DOD_INIT_SET = true;
                    z_cell_i_store    = [];
                    t_store           = [];

                else

                    % Subsequent transitions: compute aging from completed cycle data.
                    z_data      = z_cell_i_store;
                    z_data_time = t_store;

                    % Derive all aging model inputs from the cycle window.
                    [t_cycStart_sec, dt_sec, dt_days, ...
                        z_mean_i, T_i, C_rate_i, dDOD_i, ...
                        ~, dEFC_cell_i, ~, dAh_cell_i, v_RMS_i, v_mean_i] = ...
                        PrepareInputs(t_cycStart_days, ...
                            z_data, EFC_cell_i, Ah_cell_i_cycStart, EFC_cell_i_cycStart, ...
                            T_i_degC, Q_cell_nom, CellModel_Elec, decim, t_current, z_data_time);

                    % Compute incremental and cumulative capacity loss and resistance increase.
                    [dQ_loss_cal_i, dQ_loss_cyc_i, dR_inc_cal_i, dR_inc_cyc_i] = ...
                        Calculate_dQ_dR(CellModel_Aging, FLAG_CHEMISTRY, ...
                            z_mean_i, T_i, t_cycStart_sec, dt_sec, t_cycStart_days, dt_days, ...
                            C_rate_i, dDOD_i, EFC_cell_i_cycStart, Ah_cell_i_cycStart, ...
                            dEFC_cell_i, dAh_cell_i, ...
                            dQ_loss_cal_i, dQ_loss_cyc_i, dR_inc_cal_i, dR_inc_cyc_i, ...
                            v_RMS_i, v_mean_i);

                    % Total aging increments.
                    dQ_loss_i = dQ_loss_cal_i + dQ_loss_cyc_i;
                    dR_inc_i  = dR_inc_cal_i  + dR_inc_cyc_i;

                    % Reset cycle start reference for the next aging evaluation.
                    [t_cycStart_days, ~, Ah_cell_i_cycStart, EFC_cell_i_cycStart, ~] = ...
                        DODStart(idx_time, t_stepsize, z_cell_i, EFC_cell_i, Q_cell_nom, decim, t_current);
                    z_cell_i_store = [];
                    t_store        = [];

                end

                % Update cell capacity and resistance factors from aging totals.
                dQ_cell_i = dQ_cell_i_init - dQ_loss_i;
                dR_cell_i = dR_cell_i_init + dR_inc_i;

                % Record the first time each cell crosses the EOL threshold.
                crossing_indices               = (dQ_cell_i < SOH_DEAD) & (first_crossing == 0);
                first_crossing(crossing_indices) = idx_time;
                t_EOL(crossing_indices)        = t_current;
                EFC_EOL(crossing_indices)      = EFC_cell_i(1);

                % Propagate aging to effective electrical parameters.
                Q_cell_i  = Q_cell_nom    .* dQ_cell_i;
                R0_cell_i = R0_cell_i_init .* dR_cell_i;
                R_cell_i  = R_cell_i_init  .* dR_cell_i;

                % ------------------------------------------------------------
                % Log per-cycle aging features (written at end of rest,
                % i.e. just before the new discharge starts).
                % ------------------------------------------------------------
                if cycle_idx >= 1
                    toRow = @(x) double(reshape(x(:), 1, []));
                    zmean_log(cycle_idx, 1:N_ser) = toRow(z_mean_i);
                    dt_log(   cycle_idx, 1:N_ser) = toRow(dt_sec);
                    Crate_log(cycle_idx, 1:N_ser) = toRow(C_rate_i);
                    dDOD_log( cycle_idx, 1:N_ser) = toRow(dDOD_i);
                    dEFC_log( cycle_idx, 1:N_ser) = toRow(dEFC_cell_i);
                    cycle_rest_dur(cycle_idx, 1)  = double(prevRest);
                    cycle_end_t(   cycle_idx, 1)  = t_current;
                end

                % Increment cycle counter and record start of new cycle.
                cycle_idx = cycle_idx + 1;
                cycle_start_t(cycle_idx, 1) = t_current;
                dis_start_t(  cycle_idx, 1) = t_current;
                t_Rest      = 0;
                t_stepsize  = t_stepsize_disc;
                t_dyn_start = t_current;


            else
                fprintf("Error: no operating mode matched at index %d\n", idx_time);
            end
    

            % ----------------------------------------------------------------
            % Data logging.
            % ----------------------------------------------------------------

            % Append SOC and time to the cycle-window buffer (used for aging).
            z_cell_i_store = [z_cell_i_store, z_cell_i];                       %#ok<AGROW>
            t_store        = [t_store, t_current];                             %#ok<AGROW>

            % Full-run logging at the decimated rate.
            if mod(idx_time, decim) == 0
                log_k                  = log_k + 1;
                z_log(:, log_k)        = z_cell_i;          % [-]     SOC
                EFC_log(:, log_k)      = EFC_cell_i;        % [-]     Cumulative EFC
                dQloss_cal_log(:,log_k)= dQ_loss_cal_i;     % [p.u.]  Calendar capacity loss
                dQloss_cyc_log(:,log_k)= dQ_loss_cyc_i;     % [p.u.]  Cyclic capacity loss
                t_log(1, log_k)        = t_current;         % [s]     Simulation time
            end

        end % time-stepping loop
    
        % --------------------------------------------------------------------
        % Trim full-run logs to the number of steps actually completed.
        % --------------------------------------------------------------------
        if log_k > 0
            z_log          = z_log(:, 1:log_k);
            EFC_log        = EFC_log(:, 1:log_k);
            dQloss_cal_log = dQloss_cal_log(:, 1:log_k);
            dQloss_cyc_log = dQloss_cyc_log(:, 1:log_k);
            t_log          = t_log(1, 1:log_k);
        else
            z_log = []; 
            EFC_log = []; 
            dQloss_cal_log = []; 
            dQloss_cyc_log = []; 
            t_log = [];
        end
    

        % --------------------------------------------------------------------
        % Store per-iteration results.
        % --------------------------------------------------------------------

        % Full-run time series logs.
        Results2(iter).z_log          = z_log;
        Results2(iter).EFC_log        = EFC_log;
        Results2(iter).dQloss_cal_log = dQloss_cal_log;
        Results2(iter).dQloss_cyc_log = dQloss_cyc_log;
        Results2(iter).t_log          = t_log;

        % Per-cycle timing and duration logs.
        Results2(iter).cycle_dyn_dur  = cycle_dyn_dur;
        Results2(iter).cycle_rest_dur = cycle_rest_dur;
        Results2(iter).cycle_start_t  = cycle_start_t;
        Results2(iter).cycle_end_t    = cycle_end_t;
        Results2(iter).dis_start_t    = dis_start_t;
        Results2(iter).chg_start_t    = chg_start_t;
        Results2(iter).cycle_dis_dur  = cycle_dis_dur;
        Results2(iter).cycle_chg_dur  = cycle_chg_dur;

        % Per-cycle aging feature logs.
        Results2(iter).zmean_log      = zmean_log;
        Results2(iter).dt_log         = dt_log;
        Results2(iter).Crate_log      = Crate_log;
        Results2(iter).dDOD_log       = dDOD_log;
        Results2(iter).dEFC_log       = dEFC_log;
    
        % --------------------------------------------------------------------
        % Performance metrics: chi (lifetime gain of RBP over CBP).
        %   CBP: EOL set by the weakest cell (min).
        %   RBP: EOL averaged/summed across all cells.
        %   FLAG_SIM_SHORT is set if any cell never reached SOH_DEAD
        %   within the simulation horizon.
        % --------------------------------------------------------------------
        if ~all(first_crossing > 0)

            FLAG_SIM_SHORT = true;
            chi_time_perc  = 0;
            chi_EFC_perc   = 0;

        else

            t_EOL_CBP     = min(t_EOL);
            t_EOL_RBP     = mean(t_EOL);
            chi_time_perc = (t_EOL_RBP / t_EOL_CBP - 1) * 100;                % [%]

            EFC_EOL_CBP  = N_ser * min(EFC_EOL);
            EFC_EOL_RBP  = sum(EFC_EOL);
            chi_EFC_perc = (EFC_EOL_RBP / EFC_EOL_CBP - 1) * 100;             % [%]

        end
        
        simTime_iter = toc(tStart_iter);                                        % [s]

        % Scalar result fields.
        Results2(iter).index          = iter;
        Results2(iter).FLAG_SIM_STOP  = FLAG_SIM_STOP;
        Results2(iter).FLAG_SIM_SHORT = FLAG_SIM_SHORT;
        Results2(iter).chi_time_perc  = chi_time_perc;
        Results2(iter).chi_EFC_perc   = chi_EFC_perc;
        Results2(iter).simTime_iter   = simTime_iter;

        % Final aging state.
        Results2(iter).dQ_cell_i_init = dQ_cell_i_init;
        Results2(iter).dQ_cell_i      = dQ_cell_i;
        Results2(iter).dQ_loss_cal_i  = dQ_loss_cal_i;
        Results2(iter).dQ_loss_cyc_i  = dQ_loss_cyc_i;
        Results2(iter).dR_cell_i_init = dR_cell_i_init;
        Results2(iter).dR_cell_i      = dR_cell_i;
        Results2(iter).dR_inc_cal_i   = dR_inc_cal_i;
        Results2(iter).dR_inc_cyc_i   = dR_inc_cyc_i;
        Results2(iter).t_EOL          = t_EOL;
        Results2(iter).EFC_EOL        = EFC_EOL;

        % Worker ID: use iteration index when running as a regular for-loop.
        t = getCurrentTask();
        if isempty(t)
            Results2(iter).iterationID = iter;      % for-loop on client
        else
            Results2(iter).iterationID = t.ID;      % parfor worker
        end

        catch ME
            fprintf('Error in iteration %d: %s\n', iter, ME.message);
        end

    end % Monte Carlo loop

    Outputs.bytes = tocBytes(gcp);


    % ========================================================================
    % Post-processing: sort, aggregate, and save results.
    % ========================================================================

    % Shut down the parallel pool.
    delete(gcp('nocreate'));

    % Sort by iterationID to restore correct order (parfor does not guarantee it).
    [~, sortIdx]  = sort([Results2.iterationID]);
    sortedResults = Results2(sortIdx);

    % Total wall-clock time for all iterations.
    Outputs.simTime = toc(tStart);                                              % [s]

    
    % ------------------------------------------------------------------------
    % Aggregate scalar flag and metric arrays.
    % ------------------------------------------------------------------------
    Outputs.FLAG_SIM_STOP_All  = [sortedResults(:).FLAG_SIM_STOP]';
    Outputs.FLAG_SIM_SHORT_All = [sortedResults(:).FLAG_SIM_SHORT]';
    Outputs.chi_time_perc_All  = [sortedResults(:).chi_time_perc]';
    Outputs.chi_EFC_perc_All   = [sortedResults(:).chi_EFC_perc]';
    Outputs.simTime_iter_All   = [sortedResults(:).simTime_iter]'; 


    % ------------------------------------------------------------------------
    % Aggregate per-cell array outputs across all iterations.
    % ------------------------------------------------------------------------
    Outputs.t_EOL         = cell2mat(arrayfun(@(i) sortedResults(i).t_EOL,         1:numSims, 'UniformOutput', false));
    Outputs.EFC_EOL       = cell2mat(arrayfun(@(i) sortedResults(i).EFC_EOL,       1:numSims, 'UniformOutput', false));
    Outputs.dQ_cell_i     = cell2mat(arrayfun(@(i) sortedResults(i).dQ_cell_i,     1:numSims, 'UniformOutput', false));
    Outputs.dQ_loss_cal_i = cell2mat(arrayfun(@(i) sortedResults(i).dQ_loss_cal_i, 1:numSims, 'UniformOutput', false));
    Outputs.dQ_loss_cyc_i = cell2mat(arrayfun(@(i) sortedResults(i).dQ_loss_cyc_i, 1:numSims, 'UniformOutput', false));
    Outputs.dQ_cell_i_init= cell2mat(arrayfun(@(i) sortedResults(i).dQ_cell_i_init,1:numSims, 'UniformOutput', false));
    Outputs.dR_cell_i     = cell2mat(arrayfun(@(i) sortedResults(i).dR_cell_i,     1:numSims, 'UniformOutput', false));
    Outputs.dR_inc_cal_i  = cell2mat(arrayfun(@(i) sortedResults(i).dR_inc_cal_i,  1:numSims, 'UniformOutput', false));
    Outputs.dR_inc_cyc_i  = cell2mat(arrayfun(@(i) sortedResults(i).dR_inc_cyc_i,  1:numSims, 'UniformOutput', false));
    Outputs.dR_cell_i_init= cell2mat(arrayfun(@(i) sortedResults(i).dR_cell_i_init,1:numSims, 'UniformOutput', false));

    % Per-simulation time-series and cycle logs (inactive: large memory footprint):
    % Outputs.z_log         = cell2mat(arrayfun(@(r) r.z_log,          sortedResults, 'UniformOutput', false));
    % Outputs.EFC_log       = cell2mat(arrayfun(@(r) r.EFC_log,        sortedResults, 'UniformOutput', false));
    % Outputs.dQloss_cal_log= cell2mat(arrayfun(@(r) r.dQloss_cal_log, sortedResults, 'UniformOutput', false));
    % Outputs.dQloss_cyc_log= cell2mat(arrayfun(@(r) r.dQloss_cyc_log, sortedResults, 'UniformOutput', false));
    % Outputs.t_log         = cell2mat(arrayfun(@(r) r.t_log,          sortedResults, 'UniformOutput', false));
    % Outputs.cycle_dyn_dur = {sortedResults.cycle_dyn_dur};
    % Outputs.cycle_rest_dur= {sortedResults.cycle_rest_dur};
    % ... (see Results2 struct for full field list)


    % ------------------------------------------------------------------------
    % Record experiment configuration alongside results.
    % ------------------------------------------------------------------------
    Experiment.FLAG_CHEMISTRY    = FLAG_CHEMISTRY;
    Experiment.FLAG_AGINGMODEL_TC= FLAG_AGINGMODEL_TC;
    Experiment.FLAG_CURRENTINPUT = FLAG_CURRENTINPUT;
    Experiment.N_ser             = N_ser;
    Experiment.CELL_T            = CELL_T;
    Experiment.CELL_T_SIGMA      = CELL_T_SIGMA;


    % ------------------------------------------------------------------------
    % Save to a uniquely named file for this parameter combination.
    % ------------------------------------------------------------------------
    save(resultsFileName, "Outputs", "Experiment");


end % function RGM_MATLAB_Main_f