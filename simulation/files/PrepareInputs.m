% ============================================================================
% FUNCTION: PrepareInputs
% ----------------------------------------------------------------------------
% PURPOSE:
%   Computes all derived quantities needed as inputs to Calculate_dQ_dR at
%   the end of a discharge-charge cycle. Takes raw logged state data from
%   the cycle window and returns scalar aging-model inputs per cell.
%
%   Computed quantities:
%     - Time       : cycle start [sec], elapsed time [sec] and [days]
%     - SOC        : time-averaged mean and RMS, mapped to OCV via LUT
%     - Temperature: converted from [°C] to [K]
%     - DOD        : swing (max - min SOC) over the cycle window
%     - EFC        : cumulative and incremental equivalent full cycles
%     - C-rate     : mean effective C-rate derived from dEFC and dt
%     - Ah         : cumulative and incremental Ah throughput
%
% ----------------------------------------------------------------------------
% NOTE: Time-averaged vs. simple mean SOC:
%   z_mean_i and z_RMS_i are computed via trapezoidal integration over the
%   logged time vector, rather than a simple arithmetic mean. This
%   accounts for variable step sizes (the simulation uses different step
%   sizes for discharge, charge, and rest). Simple-mean alternatives are
%   retained as commented-out lines for reference.
%
% ----------------------------------------------------------------------------
% INPUTS:
%   t_cycStart_days       - Cycle start time                               [days]
%   z_data                - Logged SOC matrix, size [N_ser × N_samples]   [-]
%   EFC_cell_i            - Cumulative EFC at cycle end                    [-]
%   Ah_cell_i_cycStart    - Cumulative Ah throughput at cycle start        [Ah]
%   EFC_cell_i_cycStart   - Cumulative EFC at cycle start                  [-]
%   T_i_degC              - Cell temperatures, size [N_ser × 1]           [°C]
%   Q_cell_nom            - Nominal cell capacity                          [Ah]
%   CellModel_Elec        - Struct/object with electrical model parameters:
%                             .SOC_vec  — SOC breakpoints for OCV LUT      [-]
%                             .OCV_LUT  — OCV values at SOC breakpoints    [V]
%   decim                 - Data storage decimation factor                 [-]
%   t_current             - Current simulation time (cycle end)            [s]
%   z_data_time           - Time vector corresponding to z_data columns    [s]
%
% OUTPUTS:
%   t_cycStart_sec        - Cycle start time                               [s]
%   dt_sec                - Elapsed cycle duration                         [s]
%   dt_days               - Elapsed cycle duration                         [days]
%   z_mean_i              - Time-averaged mean SOC over the cycle          [-]
%   T_i                   - Cell temperature                               [K]
%   C_rate_i              - Mean effective C-rate over the cycle           [-]
%   dDOD_i                - Depth of discharge over the cycle              [-]
%   EFC_cell_i_cycEnd     - Cumulative EFC at cycle end                    [-]
%   dEFC_cell_i           - Incremental EFC over the cycle                 [-]
%   Ah_cell_i_cycEnd      - Cumulative Ah throughput at cycle end          [Ah]
%   dAh_cell_i            - Incremental Ah throughput over the cycle       [Ah]
%   v_RMS_i               - RMS OCV over the cycle (NMC aging input)       [V]
%   v_mean_i              - Mean OCV over the cycle (NMC aging input)      [V]
% ============================================================================

function [t_cycStart_sec, dt_sec, dt_days, ...
            z_mean_i, T_i, C_rate_i, dDOD_i, ...
            EFC_cell_i_cycEnd, dEFC_cell_i, Ah_cell_i_cycEnd, dAh_cell_i, v_RMS_i, v_mean_i] ...
            = ...
            PrepareInputs(t_cycStart_days, ...
                        z_data, EFC_cell_i, Ah_cell_i_cycStart, ...
                            EFC_cell_i_cycStart, ...
                                T_i_degC, Q_cell_nom, CellModel_Elec, decim, t_current, z_data_time)


    % ========================================================================
    % Time: convert cycle start to [sec] and compute elapsed duration.
    % ========================================================================
    t_cycStart_sec  = t_cycStart_days * 24 * 60 * 60;                          % [s]

    t_cycEnd_sec    = t_current;                                                % [s]
    t_cycEnd_days   = t_cycEnd_sec / (24 * 60 * 60);                           % [days]

    dt_days         = t_cycEnd_days - t_cycStart_days;                         % [days]
    dt_sec          = dt_days * 24 * 60 * 60;                                  % [s]

    % Index-based alternative for t_cycEnd (inactive: replaced by t_current):
    % idx_time_End  = idx_store_End * decim;
    % t_cycEnd_sec  = idx_time_End * t_stepsize;


    % ========================================================================
    % SOC: time-averaged statistics over the cycle window.
    %   Trapezoidal integration is used to handle variable step sizes.
    % ========================================================================
    dt_window = z_data_time(end) - z_data_time(1);                             % [s] total window duration

    % Time-averaged mean SOC.
    z_mean_i  = trapz(z_data_time, z_data, 2) / dt_window;                    % [-]
    % Simple-mean alternative (inactive):
    % z_mean_i = mean(z_data, 2);

    % Time-averaged RMS SOC.
    z_RMS_i   = sqrt(trapz(z_data_time, z_data.^2, 2) / dt_window);           % [-]
    % Simple-RMS alternative (inactive):
    % z_RMS_i = sqrt(sum(z_data.^2, 2) / length(z_data));

    % Map mean and RMS SOC to OCV via the look-up table (used by NMC aging model).
    v_mean_i  = interp1(CellModel_Elec.SOC_vec, CellModel_Elec.OCV_LUT, z_mean_i);  % [V]
    v_RMS_i   = interp1(CellModel_Elec.SOC_vec, CellModel_Elec.OCV_LUT, z_RMS_i);   % [V]


    % ========================================================================
    % Temperature: convert from [°C] to [K] (required by aging model).
    % ========================================================================
    T_i = T_i_degC + 273.15;                                                   % [K]


    % ========================================================================
    % DOD: peak-to-peak SOC swing over the cycle window.
    % ========================================================================
    dDOD_i = max(z_data, [], 2) - min(z_data, [], 2);                         % [-]


    % ========================================================================
    % EFC: cumulative and incremental equivalent full cycles.
    % ========================================================================
    EFC_cell_i_cycEnd = EFC_cell_i;                                            % [-]
    dEFC_cell_i       = EFC_cell_i_cycEnd - EFC_cell_i_cycStart;               % [-]


    % ========================================================================
    % C-rate: mean effective C-rate derived from incremental EFC and duration.
    %   C-rate = dEFC * 2 / dt_hours
    %   (factor 2: one EFC = one full discharge + one full charge)
    % ========================================================================
    C_rate_i = dEFC_cell_i * 2 / (dt_sec / 3600);                             % [-]


    % ========================================================================
    % Ah: cumulative and incremental throughput.
    %   Ah_end is derived from EFC: Ah = EFC * Q_nom (1 EFC = Q_nom Ah discharged)
    % ========================================================================
    Ah_cell_i_cycEnd = EFC_cell_i * Q_cell_nom;                                % [Ah]
    dAh_cell_i       = Ah_cell_i_cycEnd - Ah_cell_i_cycStart;                  % [Ah]

end % function PrepareInputs