% ============================================================================
% FUNCTION: Init_R0_R_Tau
% ----------------------------------------------------------------------------
% PURPOSE:
%   Initialises the electrical parameters of all cells in the RGM at the
%   beginning of a simulation:
%     - Series resistance R0
%     - RC element resistance R1
%     - RC discrete-time coefficient (exp(-dt/tau))
%     - RC time constant tau1
%
%   Two modes depending on the thermal model resolution:
%     - ISOTHERMAL  (scalar T_vec): all cells share a single parameter set,
%       taken directly from the LUT without interpolation.
%     - DISTRIBUTED (vector T_vec): each cell gets its own parameter set,
%       interpolated from the LUT at its individual temperature.
%
% ----------------------------------------------------------------------------
% NOTE: Multi-RC extension (inactive):
%   The NrRC > 1 branch is not yet active. Relevant lines are retained as
%   commented-out code for future extension to higher-order ECMs.
%
% ----------------------------------------------------------------------------
% INPUTS:
%   CellModel_Elec  - Struct/object with electrical model parameters:
%                       .T_vec    — temperature breakpoints for LUTs   [°C]
%                       .R0_LUT   — series resistance look-up table     [Ω]
%                       .R1_LUT   — RC resistance look-up table         [Ω]
%                       .tau1_LUT — RC time constant look-up table      [s]
%                       .NrRC     — number of RC elements in the ECM    [-]
%   T_i_degC        - Cell temperatures, size [N_ser × 1]              [°C]
%   AllOnes         - Column vector of ones,  size [N_ser × 1]          [-]
%   t_stepsize      - Simulation step size                              [s]
%
% OUTPUTS:
%   R0_cell_i_init    - Initial series resistance for each cell          [Ω]
%   R_cell_i_init     - Initial RC resistance for each cell              [Ω]
%   RC_cell_i_init    - Initial RC discrete-time coefficient exp(-dt/τ)  [-]
%   tau1_cell_active  - RC time constant for each cell                   [s]
% ============================================================================

function [R0_cell_i_init, R_cell_i_init, RC_cell_i_init, tau1_cell_active] = ...
    Init_R0_R_Tau(CellModel_Elec, T_i_degC, AllOnes, t_stepsize)


    % ========================================================================
    % ISOTHERMAL MODE: Single temperature entry in the LUT.
    %   Parameters are uniform across all cells; no interpolation needed.
    % ========================================================================
    if (isscalar(CellModel_Elec.T_vec))

        % Broadcast scalar LUT values to all N_ser cells.
        R0_cell_i_init   = CellModel_Elec.R0_LUT  * AllOnes;
        R_cell_i_init    = CellModel_Elec.R1_LUT  * AllOnes;
        tau1_cell_active = CellModel_Elec.tau1_LUT * AllOnes;

        % Pre-compute discrete-time RC coefficient for the initial step size.
        RC_cell_i_init   = exp(-t_stepsize ./ abs(tau1_cell_active));


    % ========================================================================
    % DISTRIBUTED MODE: Temperature vector available.
    %   Each cell gets its own parameters, interpolated at its temperature.
    %   Extrapolation is enabled to handle minor out-of-range temperatures.
    % ========================================================================
    else

        % Interpolate series resistance at each cell's temperature.
        R0_cell_i_init   = interp1(CellModel_Elec.T_vec, CellModel_Elec.R0_LUT,   T_i_degC, 'linear', 'extrap');

        % Interpolate RC resistance at each cell's temperature.
        R_cell_i_init    = interp1(CellModel_Elec.T_vec, CellModel_Elec.R1_LUT,   T_i_degC, 'linear', 'extrap');
        % Multi-RC extension (inactive):
        % R_cell_i_init  = R1_cell_active;   % select based on NrRC

        % Interpolate RC time constant at each cell's temperature.
        tau1_cell_active = interp1(CellModel_Elec.T_vec, CellModel_Elec.tau1_LUT, T_i_degC, 'linear', 'extrap');

        % Pre-compute discrete-time RC coefficient for the initial step size.
        RC_cell_i_init   = exp(-t_stepsize ./ abs(tau1_cell_active));
        % Multi-RC extension (inactive):
        % RC_cell_i_init = RC_cell_i_init * AllOnes;

    end

end % function Init_R0_R_Tau