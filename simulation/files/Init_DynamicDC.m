% ============================================================================
% FUNCTION: Init_DynamicDC
% ----------------------------------------------------------------------------
% PURPOSE:
%   Initialises the drive cycle current profile used during the discharge
%   phase of the simulation. Supports two input modes:
%
%     FLAG_CURRENTINPUT = 1 — CC discharge: constant current at the
%                             specified C-rate; no profile loading needed.
%     FLAG_CURRENTINPUT = 2 — Dynamic drive cycle: loads a WLTC profile
%                             from file, scales it to respect the cell's
%                             maximum allowed C-rate, and returns the
%                             time-current vectors for use in the main loop.
%
%
% ----------------------------------------------------------------------------
% INPUTS:
%   FLAG_CURRENTINPUT   - Drive cycle selector: 1 = CC, 2 = WLTC          [-]
%   CC_dis_Crate        - CC discharge C-rate (used as C-rate ceiling)     [-]
%   Q_cell_nom          - Nominal cell capacity                            [Ah]
%   CellModel_Elec      - Struct/object with electrical model parameters:
%                           .CCCV.CC_dis_Crate — maximum allowed C-rate    [-]
%
% OUTPUTS:
%   C_rate                       - Representative C-rate for the profile   [-]
%   DC_Input_Current_final_i_PU  - PU-level current profile                [A]
%   DC_Input_Current_final_t     - Corresponding time vector               [s]
%   t_DC_end                     - Total duration of one drive cycle       [s]
% ============================================================================

function [C_rate, DC_Input_Current_final_i_PU, ...
    DC_Input_Current_final_t, t_DC_end] = ...
        Init_DynamicDC(FLAG_CURRENTINPUT, CC_dis_Crate, Q_cell_nom, CellModel_Elec)

    % Initialise all outputs to safe defaults.
    % (Outputs are only meaningfully set for the active FLAG_CURRENTINPUT branch.)
    C_rate                         = 1;
    DC_Input_Current_final_i_PU    = 0;
    DC_Input_Current_final_t       = 0;
    t_DC_end                       = 1;


    if (FLAG_CURRENTINPUT == 1)

        % ====================================================================
        % CC DISCHARGE: constant current profile.
        %   No drive cycle loading needed; C-rate is set directly.
        % ====================================================================
        C_rate = CC_dis_Crate;


    elseif (FLAG_CURRENTINPUT == 2)

        % ====================================================================
        % DYNAMIC DRIVE CYCLE: WLTC profile.
        % ====================================================================

        % Load the WLTC current profile from file.
        x = load("WLTC.mat");

        % --------------------------------------------------------------------
        % C-rate ceiling check.
        %   If the WLTC peak C-rate exceeds the cell's rated maximum,
        %   scale the entire profile down proportionally so the peak
        %   exactly meets the cell limit.
        % --------------------------------------------------------------------
        DC_Input_I_cell_max       = max(x.DC_Input_Current.i_cell);
        DC_Input_C_rate_cell_max  = DC_Input_I_cell_max / Q_cell_nom;

        if (DC_Input_C_rate_cell_max > CellModel_Elec.CCCV.CC_dis_Crate)
            % Profile exceeds cell limit: scale down to rated maximum.
            DC_Input_Current_final_I_cell = (x.DC_Input_Current.i_cell ...
                                             / DC_Input_C_rate_cell_max) ...
                                             * CellModel_Elec.CCCV.CC_dis_Crate;
        else
            % Profile is within cell limit: use as-is.
            DC_Input_Current_final_I_cell = x.DC_Input_Current.i_cell;
        end

        % --------------------------------------------------------------------
        % Upscale from cell level to PU level.
        %   Multiplier is 1 (single-cell PU).
        % --------------------------------------------------------------------
        DC_Input_Current_final_i_PU  = DC_Input_Current_final_I_cell * 1;
        DC_Input_Current_final_t     = x.DC_Input_Current.t;

        % Total duration of one drive cycle repetition.
        t_DC_end = DC_Input_Current_final_t(end);                              % [s]

        % Representative C-rate: mean absolute current over the cycle.
        C_rate   = mean(abs(DC_Input_Current_final_I_cell)) / Q_cell_nom;      % [-]

    end

end % function Init_DynamicDC