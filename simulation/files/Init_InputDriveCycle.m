% ============================================================================
% FUNCTION: Init_InputDriveCycle
% ----------------------------------------------------------------------------
% PURPOSE:
%   Initialises all drive cycle and protocol parameters used to control
%   the CC-CV charge / CC discharge / Rest operating sequence.
%
%   Parameters are grouped into five categories:
%     1. CC discharge  — C-rate, current, minimum voltage cutoff
%     2. CC charge     — C-rate, current, maximum voltage cutoff
%     3. CV charge     — hold voltage, current cutoff, time limit
%     4. SOC limits    — minimum and maximum allowed SOC
%     5. Rest timing   — maximum rest duration per day
%
% ----------------------------------------------------------------------------
% NOTE: Hardcoded values:
%   Several parameters are currently set as fixed constants rather than being
%   read from CellModel_Elec. The original model references are shown in the
%   comments next to each affected line for future re-enabling.
%
% ----------------------------------------------------------------------------
% INPUTS:
%   Q_cell_nom          - Nominal cell capacity                           [Ah]
%   CellModel_Elec      - Struct/object with electrical model parameters:
%                           .CCCV.CC_dis_V_min    — CC discharge cutoff   [V]
%                           .CCCV.CC_chg_Crate    — CC charge C-rate      [-]
%                           .CCCV.CC_chg_V_max    — CC charge cutoff      [V]
%                           .CCCV.CV_chg_I_cutoff — CV current cutoff     [p.u.]
%   TIME_REST_PERC_DAY  - Fraction of the day spent resting               [-]
%
% OUTPUTS:
%   CC_dis_Crate        - CC discharge C-rate                             [-]
%   CC_dis_I            - CC discharge current                            [A]
%   CC_dis_V_min        - CC discharge minimum voltage cutoff             [V]
%   CC_chg_Crate        - CC charge C-rate                                [-]
%   CC_chg_I            - CC charge current                               [A]
%   CC_chg_V_max        - CC charge maximum voltage cutoff                [V]
%   CV_chg_V            - CV charge hold voltage                          [V]
%   CV_chg_I_cutoff     - CV charge current cutoff                        [A]
%   CV_chg_t_max        - CV charge maximum duration                      [s]
%   SOC_min             - Minimum allowed state-of-charge                 [-]
%   SOC_max             - Maximum allowed state-of-charge                 [-]
%   TIME_REST_MAX       - Maximum rest duration per cycle                 [s]
% ============================================================================

function [CC_dis_Crate, CC_dis_I, CC_dis_V_min, CC_chg_Crate, CC_chg_I, ...
        CC_chg_V_max, CV_chg_V, CV_chg_I_cutoff, CV_chg_t_max, ...
            SOC_min, SOC_max, TIME_REST_MAX] = Init_InputDriveCycle(Q_cell_nom, CellModel_Elec, TIME_REST_PERC_DAY)

    % 1C current: the reference current for all C-rate calculations.
    OneC_curr       = Q_cell_nom;                                               % [A]

    % ------------------------------------------------------------------------
    % CC discharge parameters.
    % ------------------------------------------------------------------------
    CC_dis_Crate    = 1;                                                        % [-]  Hardcoded; see CellModel_Elec.CCCV.CC_dis_Crate
    CC_dis_I        = CC_dis_Crate * OneC_curr;                                 % [A]
    CC_dis_V_min    = CellModel_Elec.CCCV.CC_dis_V_min;                        % [V]

    % ------------------------------------------------------------------------
    % CC charge parameters.
    % ------------------------------------------------------------------------
    CC_chg_Crate    = CellModel_Elec.CCCV.CC_chg_Crate;                        % [-]
    CC_chg_I        = CC_chg_Crate * OneC_curr;                                % [A]  
    CC_chg_V_max    = CellModel_Elec.CCCV.CC_chg_V_max;                        % [V]

    % ------------------------------------------------------------------------
    % CV charge parameters.
    % ------------------------------------------------------------------------
    CV_chg_V        = CC_chg_V_max;                                             % [V]  Hold at the CC charge upper cutoff voltage
    CV_chg_I_cutoff = CellModel_Elec.CCCV.CV_chg_I_cutoff * OneC_curr;         % [A]
    CV_chg_t_max    = 1800;                                                     % [s]  Hardcoded; see CellModel_Elec.CCCV.CV_chg_t_max

    % ------------------------------------------------------------------------
    % SOC operating window.
    % ------------------------------------------------------------------------
    SOC_min         = 0.2;                                                      % [-]  Hardcoded; see CellModel_Elec.SOC_min
    SOC_max         = 0.8;                                                      % [-]  Hardcoded; see CellModel_Elec.SOC_max

    % ------------------------------------------------------------------------
    % Rest time: scale the daily rest fraction to an absolute duration.
    % ------------------------------------------------------------------------
    TIME_REST_MAX   = TIME_REST_PERC_DAY * 86400;                               % [s]  (86400 s/day)

end % function Init_InputDriveCycle