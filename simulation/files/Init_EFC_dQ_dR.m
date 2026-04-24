% ============================================================================
% FUNCTION: Init_EFC_dQ_dR
% ----------------------------------------------------------------------------
% PURPOSE:
%   Initialises the aging-related state variables for all cells in the RGM
%   at the beginning of a simulation:
%     - Equivalent full cycles (EFC), set to zero at BOL.
%     - Cell capacity factor dQ, sampled from a Gaussian distribution
%       to represent cell-to-cell manufacturing spread at BOL.
%     - Cell resistance factor dR, sampled from a Gaussian distribution
%       to represent cell-to-cell manufacturing spread at BOL.
%
%   Both dQ and dR are normalised (p.u.) scaling factors relative to the
%   nominal cell values. A value of 1.0 means no deviation from nominal.
%
% ----------------------------------------------------------------------------
% INPUTS:
%   AllZeros            - Column vector of zeros, size [N_ser × 1]        [-]
%   dQ_cell_i_BOL_mean  - Mean capacity factor at BOL                     [p.u.]
%   dQ_cell_i_BOL_std   - Standard deviation of capacity factor at BOL    [p.u.]
%   N_ser               - Number of series-connected parallel units        [-]
%   dR_cell_i_BOL_mean  - Mean resistance factor at BOL                   [p.u.]
%   dR_cell_i_BOL_std   - Standard deviation of resistance factor at BOL  [p.u.]
%
% OUTPUTS:
%   EFC_cell_i_init     - Initial equivalent full cycles for each cell     [-]
%   dQ_cell_i_init      - Initial capacity factor for each cell (BOL)      [p.u.]
%   dR_cell_i_init      - Initial resistance factor for each cell (BOL)    [p.u.]
% ============================================================================

function [EFC_cell_i_init, dQ_cell_i_init, dR_cell_i_init] = ...
        Init_EFC_dQ_dR(AllZeros, dQ_cell_i_BOL_mean, ...
            dQ_cell_i_BOL_std, N_ser, ...
                dR_cell_i_BOL_mean, dR_cell_i_BOL_std)

    % All cells start with zero accumulated cycling at BOL.
    EFC_cell_i_init  = AllZeros;                                                % [-]

    % ------------------------------------------------------------------------
    % BOL capacity spread — sample each cell's dQ from a Gaussian.
    % ------------------------------------------------------------------------
    dQ_cell_i_init   = normrnd(dQ_cell_i_BOL_mean, dQ_cell_i_BOL_std, [N_ser, 1]);   % [p.u.]

    % ------------------------------------------------------------------------
    % BOL resistance spread — sample each cell's dR from a Gaussian.
    % ------------------------------------------------------------------------
    dR_cell_i_init   = normrnd(dR_cell_i_BOL_mean, dR_cell_i_BOL_std, [N_ser, 1]);   % [p.u.]

end % function Init_EFC_dQ_dR