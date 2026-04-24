% ============================================================================
% FUNCTION: Init_z_iRC
% ----------------------------------------------------------------------------
% PURPOSE:
%   Initialises the electrical state variables of all cells in the
%   Randomised Group Model (RGM) at the beginning of a simulation:
%     - State of charge (SOC) for each cell, set to 50% at BOL.
%     - RC branch current(s), initialised to zero (no dynamic history).
%
% ----------------------------------------------------------------------------
% NOTE: Partial implementation:
%   The multi-RC branch (NrRC > 1) is not yet active. The corresponding
%   initialisation is retained as commented-out code for future extension.
%
% NOTE: SOC variability:
%   Cell-to-cell SOC spread at BOL is currently disabled. 
%
% ----------------------------------------------------------------------------
% INPUTS:
%   AllOnes       - Column vector of ones,  size [N_ser × 1]              [-]
%   AllZeros      - Column vector of zeros, size [N_ser × 1]              [-]
%   N_ser         - Number of series-connected parallel units (PUs)       [-]
%   CellModel_Elec - Struct/object with electrical model parameters:
%                     .NrRC — number of RC elements in the ECM            [-]
%
% OUTPUTS:
%   z_cell_i_init    - Initial SOC for each cell                          [-]
%   iRC_cell_i_init  - Initial RC branch current(s) for each cell         [A]
% ============================================================================

function [z_cell_i_init, iRC_cell_i_init] = Init_z_iRC(AllOnes, AllZeros, N_ser, CellModel_Elec)

    % All cells start at 50% SOC (no BOL spread).
    z_cell_i_init = 0.5 * AllOnes;

    % Initialise RC branch current(s) to zero (system at rest at t = 0).
    if (CellModel_Elec.NrRC == 1)
        iRC_cell_i_init = AllZeros;

        % Multi-RC extension (inactive: NrRC > 1 not yet supported):
        % iRC_cell_i_init = single(ones(N_ser, 2));
    end

    % BOL SOC variability (inactive: uniform spread across cells disabled):
    % z_cell_i_init = z_cell_i_init + 0.05 * rand([N_ser, 1]);

end % function Init_z_iRC