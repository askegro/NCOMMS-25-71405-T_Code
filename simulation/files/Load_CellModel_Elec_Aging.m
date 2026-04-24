% ============================================================================
% FUNCTION: Load_CellModel_Elec_Aging
% ----------------------------------------------------------------------------
% PURPOSE:
%   Loads and returns all model data required to run a battery aging
%   simulation, for a given cell chemistry and aging test case:
%
%     1. Electrical model  — OCV LUT, ECM parameters (R0, R1, tau1),
%                            CC-CV protocol limits.
%     2. Aging model       — Calendar and cyclic degradation functions
%                            for capacity loss and resistance increase.
%     3. BOL variability   — Mean and standard deviation of the initial
%                            cell-to-cell spread in capacity and resistance,
%                            drawn from the specified experimental test case.
%
%   Supported chemistries (FLAG_CHEMISTRY):
%     1 → LFP  — Sony Murata US26650 FTC1
%     2 → NMC  — Sanyo UR18650E
%
%   Supported BOL variability test cases (FLAG_AGINGMODEL_TC):
%     1 -> TestCase1,  2 -> TestCase2
%
% ----------------------------------------------------------------------------
% INPUTS:
%   FLAG_CHEMISTRY      - Chemistry selector: 1 = LFP, 2 = NMC             [-]
%   FLAG_AGINGMODEL_TC  - BOL variability test case selector: 1, 2         [-]
%   T_i_degC            - Cell temperature(s), size [N_ser × 1]            [°C]
%
% OUTPUTS:
%   CellModel_Elec        - Loaded electrical model struct
%   CellModel_Aging       - Loaded aging model struct
%   Q_cell_nom            - Nominal cell capacity                           [Ah]
%   T_cell_idx            - Index of T_i_degC in CellModel_Elec.T_vec,
%                           or empty if temperature requires interpolation  [-]
%   FLAG_INTERP_TEMP      - True if T_i_degC is not an exact LUT entry      [-]
%   dQ_cell_i_BOL_mean    - Mean capacity factor at BOL                    [p.u.]
%   dQ_cell_i_BOL_std     - Std. deviation of capacity factor at BOL       [p.u.]
%   dR_cell_i_BOL_mean    - Mean resistance factor at BOL                  [p.u.]
%   dR_cell_i_BOL_std     - Std. deviation of resistance factor at BOL     [p.u.]
% ============================================================================

function [CellModel_Elec, CellModel_Aging, ...
            Q_cell_nom, T_cell_idx, FLAG_INTERP_TEMP, ...
                dQ_cell_i_BOL_mean, dQ_cell_i_BOL_std, ...
                    dR_cell_i_BOL_mean, dR_cell_i_BOL_std] = ...
                        Load_CellModel_Elec_Aging(FLAG_CHEMISTRY, FLAG_AGINGMODEL_TC, T_i_degC)


    % ========================================================================
    % Electrical model: select and load the appropriate .mat file.
    % ========================================================================
    if (FLAG_CHEMISTRY == 1)
        Cell_Model_Electrical = "LFP_Sony_Murata_US_26650_FTC1_Model_Electrical_2024_02_13_AS";
    elseif (FLAG_CHEMISTRY == 2)
        Cell_Model_Electrical = "NMC_Sanyo_UR_18650_E_Model_Electrical_2024_02_15_AS";
    else
        fprintf("ERROR: Wrong chemistry code.\n");
    end

    CellModel_Elec_Loaded = load(Cell_Model_Electrical);
    CellModel_Elec        = CellModel_Elec_Loaded.CellModel;

    % Extract nominal cell capacity from the loaded model.
    Q_cell_nom = CellModel_Elec.Q_cell_nom;                                    % [Ah]


    % ========================================================================
    % Temperature index: check whether T_i_degC is an exact LUT entry.
    %   If not found, FLAG_INTERP_TEMP signals that interpolation is needed.
    % ========================================================================
    T_cell_idx = find(CellModel_Elec.T_vec == T_i_degC, 1, 'first');

    if (isempty(T_cell_idx))
        FLAG_INTERP_TEMP = true;    % Temperature not in LUT — interpolate
    else
        FLAG_INTERP_TEMP = false;   % Exact match found
    end


    % ========================================================================
    % Aging model: select and load the appropriate .mat file.
    % ========================================================================
    if (FLAG_CHEMISTRY == 1)
        Cell_Model_Aging = "LFP_Sony_Murata_US_26650_FTC1_Model_Aging_2025_02_14";
    elseif (FLAG_CHEMISTRY == 2)
        Cell_Model_Aging = "NMC_Sanyo_UR_18650_E_Model_Aging_2025_02_25";
    else
        fprintf("ERROR: Wrong chemistry code.\n");
    end

    CellModel_Aging = load(Cell_Model_Aging);


    % ========================================================================
    % BOL variability: load spread parameters for the selected chemistry
    %   and test case.
    % ========================================================================
    AgingModel_BOL_Loaded = load("AgingModel_BOL_Variation_2024_04_18.mat");
    AgingModel_BOL        = AgingModel_BOL_Loaded.AgingModel_BOL;

    % Select chemistry-specific BOL variation data.
    if (FLAG_CHEMISTRY == 1)
        AgingModel_BOLVariation = AgingModel_BOL.LFP;
    elseif (FLAG_CHEMISTRY == 2)
        AgingModel_BOLVariation = AgingModel_BOL.NMC;
    else
        fprintf("ERROR: Wrong chemistry code.\n");
    end

    % Select the experimental test case within the chosen chemistry.
    if (FLAG_AGINGMODEL_TC == 1)
        BOL_TestCase = AgingModel_BOLVariation.TestCase1;
    elseif (FLAG_AGINGMODEL_TC == 2)
        BOL_TestCase = AgingModel_BOLVariation.TestCase2;
    else
        fprintf("ERROR: Wrong aging model test case code.\n");
    end

    % ------------------------------------------------------------------------
    % Extract BOL capacity and resistance spread parameters.
    %   Mean is 1.0 (no bias from nominal); std is test-case dependent.
    % ------------------------------------------------------------------------
    dQ_cell_i_BOL_mean = 1;                                                    % [p.u.]
    dQ_cell_i_BOL_std  = BOL_TestCase.k_C;                                     % [p.u.]

    dR_cell_i_BOL_mean = 1;                                                    % [p.u.]
    dR_cell_i_BOL_std  = BOL_TestCase.k_R;                                     % [p.u.]

end % function Load_CellModel_Elec_Aging