% ============================================================================
% FUNCTION: Calculate_dQ_dR
% ----------------------------------------------------------------------------
% PURPOSE:
%   Computes incremental capacity loss (dQ) and resistance increase (dR)
%   for a battery cell due to calendar and cyclic aging mechanisms.
%
%   Two operating modes:
%     - BOOTSTRAP  (dQ_loss_cal_i_old == 0): Evaluates cumulative aging
%       functions directly at the current time/EFC state.
%     - INCREMENTAL (dQ_loss_cal_i_old ~= 0): Estimates aging increments
%       using derivatives (dX/dt or dX/dEFC), then accumulates into totals.
%
%   Supports two cell chemistry types (FLAG_CHEMISTRY):
%     1 -> LFP  — state-of-charge (SOC) and time [sec] based
%     2 -> NMC  — voltage and time [days] based
%
% ----------------------------------------------------------------------------
% INPUTS:
%   CellModel_Aging       - Object containing aging model function handles
%   FLAG_CHEMISTRY        - Chemistry selector: 1 = LFP, 2 = NMC
%
%   z_mean_i              - Mean state-of-charge (SOC) in current interval  [-]
%   T_i                   - Cell temperature in current interval             [K or °C]
%   t_cycStart_sec        - Cycle start time                                 [s]
%   dt_sec                - Elapsed time in current interval                 [s]
%   t_cycStart_days       - Cycle start time                                 [days]
%   dt_days               - Elapsed time in current interval                 [days]
%
%   C_rate_i              - C-rate during current interval                   [-]
%   dDOD_i                - Depth of discharge in current interval           [-]
%   EFC_cell_i_cycStart   - Equivalent full cycles at cycle start            [-]
%   Ah_cell_i_cycStart    - Cumulative Ah throughput at cycle start          [Ah]
%   dEFC_cell_i           - Incremental EFC in current interval              [-]
%   dAh_cell_i            - Incremental Ah throughput in current interval    [Ah]
%
%   dQ_loss_cal_i_old     - Accumulated calendar capacity loss (previous)    [p.u.]
%   dQ_loss_cyc_i_old     - Accumulated cyclic capacity loss (previous)      [p.u.]
%   dR_inc_cal_i_old      - Accumulated calendar resistance increase (prev.) [p.u.]
%   dR_inc_cyc_i_old      - Accumulated cyclic resistance increase (prev.)   [p.u.]
%
%   v_RMS_i               - RMS voltage in current interval (NMC only)       [V]
%   v_mean_i              - Mean voltage in current interval (NMC only)      [V]
%
% OUTPUTS:
%   dQ_loss_cal_i         - Updated calendar capacity loss                   [p.u.]
%   dQ_loss_cyc_i         - Updated cyclic capacity loss                     [p.u.]
%   dR_inc_cal_i          - Updated calendar resistance increase              [p.u.]
%   dR_inc_cyc_i          - Updated cyclic resistance increase                [p.u.]
% ============================================================================

function [dQ_loss_cal_i, dQ_loss_cyc_i, dR_inc_cal_i, dR_inc_cyc_i] ...
            = ...
            Calculate_dQ_dR(CellModel_Aging, FLAG_CHEMISTRY, ...
                z_mean_i, T_i, t_cycStart_sec, dt_sec, t_cycStart_days, dt_days, ...
                C_rate_i, dDOD_i, EFC_cell_i_cycStart, Ah_cell_i_cycStart, dEFC_cell_i, dAh_cell_i, ...
                dQ_loss_cal_i_old, dQ_loss_cyc_i_old, dR_inc_cal_i_old, dR_inc_cyc_i_old, v_RMS_i, v_mean_i)


    % ========================================================================
    % BOOTSTRAP MODE: First call: evaluate cumulative aging models directly.
    %   No derivative is available yet, so absolute aging functions are used
    %   at the current elapsed time and cycle count.
    % ========================================================================
    if (dQ_loss_cal_i_old == 0)

        % --------------------------------------------------------------------
        % Calendar aging: Absolute evaluation at (t_start + dt)
        % --------------------------------------------------------------------
        if (FLAG_CHEMISTRY == 1)
            % LFP: aging parameterised by SOC and time [sec]
            dQ_loss_cal_i  = CellModel_Aging.Q_loss_cal(z_mean_i, T_i, t_cycStart_sec + dt_sec) * 0.01;
            dR_inc_cal_i   = CellModel_Aging.R_inc_cal(z_mean_i, T_i, t_cycStart_sec + dt_sec) * 0.01;

        elseif (FLAG_CHEMISTRY == 2)
            % NMC: aging parameterised by voltage and time [days]
            dQ_loss_cal_i  = CellModel_Aging.Q_loss_cal(T_i, v_mean_i, t_cycStart_days + dt_days);
            dR_inc_cal_i   = CellModel_Aging.R_inc_cal(T_i, v_mean_i, t_cycStart_days + dt_days);

        else
            fprintf("ERROR: Wrong chemistry code.\n");
        end

        % --------------------------------------------------------------------
        % Cyclic aging: Absolute evaluation at current EFC / Ah state
        % --------------------------------------------------------------------
        if (FLAG_CHEMISTRY == 1)
            % LFP: evaluate cyclic loss at total EFC accumulated so far
            dQ_loss_cyc_i  = CellModel_Aging.Q_loss_cyc(C_rate_i, dDOD_i, (EFC_cell_i_cycStart + dEFC_cell_i)) * 0.01;
            dR_inc_cyc_i   = CellModel_Aging.R_inc_cyc(C_rate_i, dDOD_i, (EFC_cell_i_cycStart + dEFC_cell_i)) * 0.01;

        elseif (FLAG_CHEMISTRY == 2)
            % NMC: evaluate cyclic loss at total Ah throughput accumulated so far
            dQ_loss_cyc_i  = CellModel_Aging.Q_loss_cyc(Ah_cell_i_cycStart + dAh_cell_i, dDOD_i, v_RMS_i);
            dR_inc_cyc_i   = CellModel_Aging.R_inc_cyc(Ah_cell_i_cycStart + dAh_cell_i, dDOD_i, v_RMS_i);

        else
            fprintf("ERROR: Wrong chemistry code.\n");
        end


    % ========================================================================
    % INCREMENTAL MODE: Subsequent calls: estimate aging via derivatives,
    %   then accumulate into running totals.
    % ========================================================================
    else

        % --------------------------------------------------------------------
        % Calendar capacity loss: dQ_cal = (dQ/dt) * dt
        % --------------------------------------------------------------------
        if (FLAG_CHEMISTRY == 1)
            % LFP: aging parameterised by SOC and time [sec]
            dQ_loss_cal_dt_eval  = CellModel_Aging.dQ_loss_cal_dt(z_mean_i, T_i, t_cycStart_sec);
            dQ_loss_cal_i        = dQ_loss_cal_dt_eval .* dt_sec * 0.01;

        elseif (FLAG_CHEMISTRY == 2)
            % NMC: aging parameterised by voltage and time [days]
            dQ_loss_cal_dt_eval  = CellModel_Aging.dQ_loss_cal_dt(T_i, v_mean_i, t_cycStart_days);
            dQ_loss_cal_i        = dQ_loss_cal_dt_eval .* dt_days;

        else
            fprintf("ERROR: Wrong chemistry code.\n");
        end

        % --------------------------------------------------------------------
        % Calendar resistance increase: dR_cal = (dR/dt) * dt
        % --------------------------------------------------------------------
        if (FLAG_CHEMISTRY == 1)
            % LFP: aging parameterised by SOC and time [sec]
            dR_inc_cal_dt_eval   = CellModel_Aging.dR_inc_cal_dt(z_mean_i, T_i);
            dR_inc_cal_i         = dR_inc_cal_dt_eval .* dt_sec * 0.01;

        elseif (FLAG_CHEMISTRY == 2)
            % NMC: aging parameterised by voltage and time [days]
            dR_inc_cal_dt_eval   = CellModel_Aging.dR_inc_cal_dt(T_i, v_mean_i, t_cycStart_days);
            dR_inc_cal_i         = dR_inc_cal_dt_eval .* dt_days;

        else
            fprintf("ERROR: Wrong chemistry code.\n");
        end

        % --------------------------------------------------------------------
        % Cyclic capacity loss: dQ_cyc = (dQ/dEFC) * dEFC  or  (dQ/dAh) * dAh
        % --------------------------------------------------------------------
        if (FLAG_CHEMISTRY == 1)
            % LFP: cyclic loss integrated over equivalent full cycles
            dQ_loss_cyc_dEFC_eval  = CellModel_Aging.dQ_loss_cyc_dEFC(C_rate_i, dDOD_i, EFC_cell_i_cycStart);
            dQ_loss_cyc_i          = dQ_loss_cyc_dEFC_eval .* dEFC_cell_i * 0.01;

        elseif (FLAG_CHEMISTRY == 2)
            % NMC: cyclic loss integrated over Ah throughput
            dQ_loss_cyc_dAh_eval   = CellModel_Aging.dQ_loss_cyc_dAh(Ah_cell_i_cycStart, dDOD_i, v_RMS_i);
            dQ_loss_cyc_i          = dQ_loss_cyc_dAh_eval .* dAh_cell_i;

        else
            fprintf("ERROR: Wrong chemistry code.\n");
        end

        % --------------------------------------------------------------------
        % Cyclic resistance increase: dR_cyc = (dR/dEFC) * dEFC  or  (dR/dAh) * dAh
        % --------------------------------------------------------------------
        if (FLAG_CHEMISTRY == 1)
            % LFP: resistance increase integrated over equivalent full cycles
            dR_inc_cyc_dEFC_eval   = CellModel_Aging.dR_inc_cyc_dEFC(C_rate_i, dDOD_i);
            dR_inc_cyc_i           = dR_inc_cyc_dEFC_eval .* dEFC_cell_i * 0.01;

        elseif (FLAG_CHEMISTRY == 2)
            % NMC: resistance increase integrated over Ah throughput
            dR_inc_cyc_dAh_eval    = CellModel_Aging.dR_inc_cyc_dAh(dDOD_i, v_RMS_i);
            dR_inc_cyc_i           = dR_inc_cyc_dAh_eval .* dAh_cell_i;

        else
            fprintf("ERROR: Wrong chemistry code.\n");
        end

        % --------------------------------------------------------------------
        % Accumulate increments into running totals
        % --------------------------------------------------------------------
        dQ_loss_cal_i  = dQ_loss_cal_i_old + dQ_loss_cal_i;
        dQ_loss_cyc_i  = dQ_loss_cyc_i_old + dQ_loss_cyc_i;

        dR_inc_cal_i   = dR_inc_cal_i_old  + dR_inc_cal_i;
        dR_inc_cyc_i   = dR_inc_cyc_i_old  + dR_inc_cyc_i;

    end % if bootstrap/incremental

end % function Calculate_dQ_dR