% ============================================================================
% FUNCTION: DODStart
% ----------------------------------------------------------------------------
% PURPOSE:
%   Records a snapshot of key state variables at the start of a new
%   discharge cycle. These values serve as the reference baseline from
%   which incremental aging quantities (dQ, dR) are computed at the end
%   of the cycle in Calculate_dQ_dR.
%
%   Captured quantities:
%     - Cycle start time          (in days, for NMC aging model)
%     - Cell SOC at cycle start
%     - Cumulative Ah throughput  (derived from EFC)
%     - Cumulative EFC
%     - Data store index          (pointer into the SOC logging buffer)
%
% ----------------------------------------------------------------------------
% INPUTS:
%   idx_time      - Current simulation time index                          [-]
%   t_stepsize    - Current simulation step size                           [s]
%   z_cell_i      - Cell state-of-charge at cycle start                   [-]
%   EFC_cell_i    - Cumulative equivalent full cycles at cycle start       [-]
%   Q_cell_nom    - Nominal cell capacity                                  [Ah]
%   decim         - Data storage decimation factor                         [-]
%   t_current     - Current simulation time                                [s]
%
% OUTPUTS:
%   t_cycStart_days       - Cycle start time                               [days]
%   z_cell_i_cycStart     - Cell SOC at cycle start                        [-]
%   Ah_cell_i_cycStart    - Cumulative Ah throughput at cycle start        [Ah]
%   EFC_cell_i_cycStart   - Cumulative EFC at cycle start                  [-]
%   idx_store_Start       - Index into SOC store buffer at cycle start     [-]
% ============================================================================

function [t_cycStart_days, z_cell_i_cycStart, ...
            Ah_cell_i_cycStart, EFC_cell_i_cycStart, idx_store_Start] = ...
            DODStart(idx_time, t_stepsize, z_cell_i, EFC_cell_i, Q_cell_nom, decim, t_current)

    % Compute the buffer index corresponding to the current time step.
    idx_store_Start     = ceil(idx_time / decim);

    % Convert current simulation time to days (used by the NMC aging model).
    t_cycStart_days     = t_current / (24 * 60 * 60);                          % [days]

    % Snapshot of SOC at cycle start.
    z_cell_i_cycStart   = z_cell_i;                                             % [-]

    % Cumulative Ah throughput, derived from EFC and nominal capacity.
    % Ah = EFC * Q_nom  (since 1 EFC = 1 full charge-discharge = Q_nom Ah)
    Ah_cell_i_cycStart  = EFC_cell_i * Q_cell_nom;                             % [Ah]

    % Snapshot of cumulative EFC at cycle start.
    EFC_cell_i_cycStart = EFC_cell_i;                                           % [-]

    % Inactive alternative for t_cycStart (index-based, replaced by t_current):
    % t_cycStart = idx_time * t_stepsize;

end % function DODStart