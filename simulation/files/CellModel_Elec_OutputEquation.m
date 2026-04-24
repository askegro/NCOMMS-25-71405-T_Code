% ============================================================================
% FUNCTION: CellModel_Elec_OutputEquation
% ----------------------------------------------------------------------------
% PURPOSE:
%   Computes the electrical output quantities of a battery cell for a given
%   operating point. Implements the output equation of an equivalent circuit
%   model (ECM), consisting of:
%
%       OCV source -> RC dynamics -> R0 (series resistance) -> terminal
%
%   The cell terminal voltage is obtained by subtracting the ohmic drop
%   across R0 from the dynamic (RC-filtered) open-circuit voltage.
%
% ----------------------------------------------------------------------------
% NOTE: Simplified implementation:
%   The general multi-RC / parallel-branch formulation (supporting NrRC > 1
%   and cell current redistribution within a parallel unit) is retained below
%   as commented-out code for reference. The active implementation assumes a
%   single RC element.
%
% ----------------------------------------------------------------------------
% INPUTS:
%   CellModel     - Struct/object with cell model parameters:
%                     .SOC_vec   — SOC breakpoints for OCV look-up table  [-]
%                     .OCV_LUT   — OCV values at each SOC breakpoint       [V]
%   z_cell_i      - Cell state of charge                                   [-]
%   R0_cell_i     - Cell series (ohmic) resistance                         [Ω]
%   R_cell_i      - RC element resistance(s)                               [Ω]
%   iRC_cell_i    - RC element current(s) (dynamic state variable)         [A]
%   i_PU          - Parallel unit current (applied terminal current)       [A]
%
% OUTPUTS:
%   v_cell_OC_i   - Cell open-circuit voltage (from OCV LUT)               [V]
%   v_PU_i        - Parallel unit terminal voltage                         [V]
%   i_cell_i      - Cell branch current                                    [A]
% ============================================================================

function [v_cell_OC_i, v_PU_i, i_cell_i] ...
    = CellModel_Elec_OutputEquation(CellModel, z_cell_i, R0_cell_i, R_cell_i, iRC_cell_i, i_PU)

    % Look up open-circuit voltage from SOC via linear interpolation.
    % Extrapolation is enabled to handle minor SOC boundary violations.
    v_cell_OC_i  = interp1(CellModel.SOC_vec, CellModel.OCV_LUT, z_cell_i(:), 'linear', 'extrap');

    % Subtract RC voltage drop to get the dynamic (static) cell voltage.
    % v_cell_stat = OCV - R_RC * i_RC
    v_cell_stat_i = v_cell_OC_i - R_cell_i .* iRC_cell_i;

    % Subtract ohmic drop across R0 to get the parallel unit terminal voltage.
    % v_PU = v_cell_stat - R0 * i_PU
    v_PU_i        = v_cell_stat_i - R0_cell_i * i_PU;

    % Series-connected unit.
    i_cell_i      = i_PU;


    % ------------------------------------------------------------------------
    % REFERENCE — General multi-RC / parallel-branch formulation (inactive).
    % Retained for future extension to NrRC > 1.
    % ------------------------------------------------------------------------
    %
    % if (CellModel.NrRC == 1)
    %     v_cell_stat_i  = reshape(v_cell_OC_i, size(z_cell_i)) ...
    %                      - R_cell_i .* iRC_cell_i;
    % else
    %     % Sum contributions from all RC elements along dimension 2
    %     v_cell_stat_i  = reshape(v_cell_OC_i, size(z_cell_i)) ...
    %                      - sum(R_cell_i .* iRC_cell_i, 2);
    % end
    %
    % % Parallel unit voltage via conductance-weighted average
    % v_PU_i     = (sum(v_cell_stat_i ./ R0_cell_i, 2) - i_PU) ...
    %              ./ sum(1 ./ R0_cell_i, 2);
    %
    % % Individual cell branch currents from voltage difference and R0
    % i_cell_i   = (v_cell_stat_i - repmat(v_PU_i, 1, 1)) ./ R0_cell_i;

end % function CellModel_Elec_OutputEquation