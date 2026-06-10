%% PREPARE
clearvars -except CODE_DIR
close all; clc;

% NatComm figure formatting: sans-serif font, 5-7pt text
set(groot, 'DefaultAxesTickLabelInterpreter', 'tex');
set(groot, 'DefaultTextInterpreter', 'tex');
set(groot, 'DefaultLegendInterpreter', 'tex');
set(groot, 'DefaultAxesFontName', 'Helvetica');
set(groot, 'DefaultTextFontName', 'Helvetica');
set(groot, 'DefaultLegendFontName', 'Helvetica');

set(groot, 'DefaultAxesFontSize', 7);
set(groot, 'DefaultTextFontSize', 7);
set(groot, 'DefaultLegendFontSize', 7);




%% ===== Code Ocean / portable paths setup =====
ROOT_DIR = fileparts(CODE_DIR); %fileparts(fileparts(CODE_DIR));
DATA_DIR = fullfile(ROOT_DIR, 'data');
RESULTS_DIR = fullfile(ROOT_DIR, 'results', 'fig3'); 
if (~isfolder(RESULTS_DIR))
    mkdir(RESULTS_DIR); 
end
plot_dir = RESULTS_DIR;



% === Data inputs ===
INPUT_RESULTS_MAT = 'results_EFC_2025_06.mat';
INPUT_EV_XLSX     = 'EVs_Voltages_Nominal.xlsx';

matPath  = find_in_data_dirs(INPUT_RESULTS_MAT, DATA_DIR);
xlsxPath = find_in_data_dirs(INPUT_EV_XLSX,     DATA_DIR);

if matPath == ""
    error('Could not find "%s" in processed/raw/CODE/ROOT folders. Place it under <root>/data/processed or <root>/data/raw.', INPUT_RESULTS_MAT);
end
if xlsxPath == ""
    error('Could not find "%s" in processed/raw/CODE/ROOT folders. Place it under <root>/data/raw.', INPUT_EV_XLSX);
end

% Load the results table (expects variable resultsEFC_2025_06)
load(matPath, 'resultsEFC_2025_06');

% Where to write/read the derived EV data
EV_DATA_PATH = fullfile(ROOT_DIR, 'data', 'processed', 'EV_Data.mat');
if ~exist(fileparts(EV_DATA_PATH), 'dir')
    mkdir(fileparts(EV_DATA_PATH));
end

summary_m = matPath;
ev_xlsx   = xlsxPath;


% === Output targets ===
OUT_PDF  = fullfile(RESULTS_DIR, 'J1_NatComm_Figure_3.pdf');
OUT_FIG  = fullfile(RESULTS_DIR, 'J1_NatComm_Figure_3.fig');
OUT_TEX  = fullfile(RESULTS_DIR, 'J1_NatComm_SuppTable_4_Data.tex');



%% MAIN FILE
% =========================================================================
% PART 1 — Build EV_Data.mat from Excel
% =========================================================================
fprintf('Step 1/2: Building EV_Data.mat from "%s"...\n', ev_xlsx);

if ~isfile(ev_xlsx)
    error('File "%s" not found. Please check the filename or path.', ev_xlsx);
end

% Read table and keep first 6 columns
Table = readtable(xlsxPath);
T     = Table(:, 1:6);

% Assign column names
T.Properties.VariableNames = {'Brand','Model','Type','Year','VNom','ChemistryRaw'};

% Full name
FullName = strcat(string(T.Brand), " ", string(T.Model));

% Standardize chemistry: default NMC, switch to LFP if "LFP" appears
col6      = string(T.ChemistryRaw);
Chemistry = repmat("NMC", height(T), 1);
Chemistry(contains(col6, "LFP", 'IgnoreCase', true)) = "LFP";

% Nominal voltage (numeric column already in T)
VNom = T.VNom;

% Output table
EV_Data = table(FullName, Chemistry, VNom);
EV_Data.Properties.VariableNames = {'FullName','Chemistry','VNom'};

% Save
save(EV_DATA_PATH, 'EV_Data');
fprintf('EV_Data.mat exported.\n');



% =========================================================================
% PART 2 — Main analysis 
% =========================================================================
fprintf('Step 2/2: Loading results and plotting sensitivity...\n');

% Load summary .mat
if ~isfile(summary_m)
    error('File "%s" not found. Please check the filename or path.', summary_m);
end
S = load(summary_m);

% The loaded variable must be named resultsEFC_2025_06 per your script
if ~isfield(S, 'resultsEFC_2025_06')
    error('Expected variable "resultsEFC_2025_06" not found in "%s".', summary_m);
end
data = S.resultsEFC_2025_06;

% Prepare data
data_LFP = preprocessChemistry(data, "CHEM_1");
data_NMC = preprocessChemistry(data, "CHEM_2");

% Get desired TC subset
data_LFP_TC2 = extractTC(data_LFP, 2, 25, 0.42, 0.95);
data_NMC_TC2 = extractTC(data_NMC, 2, 25, 0.00, 0.95); % NMC TC3 -> TC2

% Labels
data_LFP_TC2.Chemistry = repmat("LFP", height(data_LFP_TC2), 1);
data_NMC_TC2.Chemistry = repmat("NMC", height(data_NMC_TC2), 1);

% Nominal voltage calculation
data_LFP_TC2.NominalVoltage = convertVoltageVector(data_LFP_TC2.Chemistry, data_LFP_TC2.Ns);
data_NMC_TC2.NominalVoltage = convertVoltageVector(data_NMC_TC2.Chemistry, data_NMC_TC2.Ns);

% Combine datasets
data_all = [data_LFP_TC2; data_NMC_TC2];

% Parameters/outputs
Parameters        = {'NominalVoltage'};
Param_Symbols   = {'V_{pack}^{nom} [V]'};
Outputs           = {'meanEFC'};
Outputs_Symbols = {'\chi [%]'};

% Plot
[best_fits, medians, lower_bounds, upper_bounds] = ...
    plotSensitivity(data_all, Parameters, Outputs, Param_Symbols, Outputs_Symbols, OUT_PDF, OUT_FIG, OUT_TEX, EV_DATA_PATH);
fprintf('Plot exported.\n');

fprintf('All done. Results saved under "%s/".\n\n', RESULTS_DIR);



%% AUXILIARY FUNCTIONS
% -------------------------------------------------------------------------
% PLOTSENSITIVITY
% -------------------------------------------------------------------------
function [best_fits, medians, lower_bounds, upper_bounds] = plotSensitivity(data_all, NomVoltages, Outputs, NomVoltages_Symbols, Outputs_Symbols, OUT_PDF, OUT_FIG, OUT_TEX, EV_DATA_PATH)
%PLOTSENSITIVITY
%   High-level plotting: loops nominal voltages/outputs, computes fits,
%   overlays EV markers, draws legends, exports figure, and writes a LaTeX table.
%
%   Inputs
%     data_all            : table with data from both chemistries
%     NomVoltages         : cellstr of nominal voltage column names ({'NominalVoltage'})
%     Outputs             : cellstr of output column names ({'meanEFC'})
%     NomVoltages_Symbols : cellstr of LaTeX x-labels (same size as NomVoltages)
%     Outputs_Symbols     : cellstr of LaTeX y-labels (same size as Outputs)
%
%   Outputs
%     best_fits           : struct with per-chem best-fit function handles, names, params, and fit summary tables
%     medians             : struct with median series per chemistry at each nominal voltage value
%     lower_bounds        : struct with (median - median(std)) per chemistry
%     upper_bounds        : struct with (median + median(std)) per chemistry
%
%   Notes
%   - Expects data_all to have columns: Chemistry (string), NomVoltages,
%     output mean columns 'meanEFC', and matching std columns
%     named as 'stdEFC'. The std column name is derived by
%     replacing 'mean' with 'std'.
%   - Axis ranges are currently hard-coded in setupAxes for consistent
%     comparison across runs.


    % Styles & ensure Chemistry is string
    [chems, chem_styles]            = getChemistryStyles();							   
    if ~isstring(data_all.Chemistry)
        data_all.Chemistry          = string(data_all.Chemistry);
    end


    for i = 1:length(NomVoltages)
        NomVoltage_name             = NomVoltages{i};
        NomVoltage_symbol           = NomVoltages_Symbols{i};


        % Collect unique X values and build a readable xtick set
        pred_vals                   = unique(data_all{:, NomVoltage_name});
        xtick_vals                  = unique(setdiff([pred_vals; (100:100:800)'], [12, 15, 80]));


        % Figure & tiles
        paperWidth  = 18.0;      % 180 mm, Nature 2-column original research
        paperHeight = 12.5;      % adjust if needed
        fig = figure('Color','w', ...
            'Units','centimeters', ...
            'Position',[2 2 paperWidth paperHeight]);   % 180 mm wide, final 2-column size        
        t                       = tiledlayout(length(Outputs), 1, 'TileSpacing', 'compact', 'Padding', 'compact');

        for j = 1:length(Outputs)
            output_name         = Outputs{j};
            output_symbol       = Outputs_Symbols{j};

            ax                  = nexttile; 
            hold on;
				

            % Core computation: medians, bounds, and trend fits
            [best_fits, medians, pred_vals, ...
                lower_bounds, upper_bounds] = ...
                                                plotChemBoxplots(ax, data_all, ...
                                                    NomVoltage_name, output_name, pred_vals, chems, chem_styles);


            % EV overlay (plots markers and returns a table for legends)
            [~, ~, vehicle_eval_table] = ...
                                            overlayEVs(ax, NomVoltage_name, output_name, ...
                                                pred_vals, best_fits, data_all, chem_styles,EV_DATA_PATH);

            % Axes styling & labels
            setupAxes(ax, xtick_vals, output_symbol);

        end
        xlabel(t, NomVoltage_symbol, 'Interpreter','tex', 'FontSize', 7, 'FontName', 'Helvetica');


        % Compact, split legend inside plot
        drawSplitLegendBoxedHorizontal(ax, vehicle_eval_table, chem_styles);

        set(fig, ...
            'Units', 'centimeters', ...
            'Position', [2 2 paperWidth paperHeight], ...
            'PaperUnits', 'centimeters', ...
            'PaperSize', [paperWidth paperHeight], ...
            'PaperPosition', [0 0 paperWidth paperHeight], ...
            'PaperPositionMode', 'manual', ...
            'Color', 'w');
        
        drawnow;        
        exportgraphics(fig, OUT_PDF, 'ContentType','vector', 'BackgroundColor','white');
        savefig(fig, OUT_FIG);

        % --------- Build merged LaTeX summary per nominal voltage ----------
        chemList                            = ["LFP", "NMC"];

        all_summary                         = table();

        for chem = chemList

            T                               = best_fits.summary.(chem);
            ChemCol                         = repmat({char(chem)}, height(T), 1);
            T                               = addvars(T, ChemCol, 'Before', 'Model', 'NewVariableNames', 'Chemistry');
            all_summary                     = [all_summary; T];             %#ok<AGROW>

        end

        % Write a single concise LaTeX table with both chemistries
        fid                                 = fopen(OUT_TEX, 'w');

        fprintf(fid, '\\begin{table}[h]\n');
        fprintf(fid, '\\centering\n');
        fprintf(fid, '\\caption{Comparison of candidate models for lifetime extension fitting across both LFP and NMC systems. For models that do not require all parameters, unused entries are denoted by ``--''.}\n');
        fprintf(fid, '\\label{tab:fitting_comparison}\n');
        fprintf(fid, '\\begin{tabular}{l l c c c c c c}\n');
        fprintf(fid, '\\toprule\n');
        fprintf(fid, 'Chemistry & Model & Param1 & Param2 & Param3 & RMSE & MAE & $R^2$ \\\\\n');
        fprintf(fid, '\\midrule\n');

        for iter = 1:height(all_summary)

            chem                            = all_summary.Chemistry{iter};
            model                           = all_summary.Model{iter};
            							   
            param1                          = formatParam(all_summary.Param1(iter), model, 1);
            param2                          = formatParam(all_summary.Param2(iter), model, 2);
            param3                          = formatParam(all_summary.Param3(iter), model, 3);

            fprintf(fid, '%s & %s & %s & %s & %s & %.4f & %.4f & %.4f \\\\\n', ...
                chem, model, param1, param2, param3, ...
                all_summary.RMSE(iter), all_summary.MAE(iter), all_summary.R2(iter));

        end

        fprintf(fid, '\\bottomrule\n');
        fprintf(fid, '\\end{tabular}\n');
        fprintf(fid, '\\end{table}\n');

        fclose(fid);

    end

end



% -------------------------------------------------------------------------
% PREPROCESSCHEMISTRY
% -------------------------------------------------------------------------
function data_chem = preprocessChemistry(data, chem_name)
%PREPROCESSCHEMISTRY Filter a full dataset to one chemistry and normalize %
%   Inputs
%     data      : full table containing at least columns Chemistry, Tsig, Trest
%     chem_name : string key to match in data.Chemistry (e.g., "CHEM_1")
%   Output
%     data_chem : subset table for that chemistry with Tsig/Trest in [0,1]
%
%   Notes
%   - The source has Tsig/Trest given in percent (0–100). Downstream code
%     expects fractions (0–1), so we convert here to avoid repeated divides.

    idx                 = matches(data.Chemistry, chem_name);

    data_chem           = data(idx, :);
    data_chem.Tsig      = data_chem.Tsig  / 100;
    data_chem.Trest     = data_chem.Trest / 100;

end



% -------------------------------------------------------------------------
% EXTRACTTC
% -------------------------------------------------------------------------
function data_TC = extractTC(data, tc_val, Tset, Tsig_set, Trest_set)
%EXTRACTTC Select a consistent test-condition slice from a table
%   Inputs
%     data       : table with columns TC, Temp, Tsig, Trest
%     tc_val     : integer of the target test condition
%     Tset       : temperature setpoint to match exactly (e.g., 25)
%     Tsig_set   : target Tsig fraction (exact within tolerance)
%     Trest_set  : target Trest fraction (exact within tolerance)
%   Output
%     data_TC    : filtered table
%
%   Notes
%   - Floating comparisons (Tsig/Trest) use a small absolute tolerance.

    tol             = 1e-6;

    mask_TCval      = (data.TC == tc_val);
    mask_Tmean      = (data.Temp == Tset);
    mask_Tsig       = (abs(data.Tsig - Tsig_set) < tol);
    mask_Trest      = (abs(data.Trest - Trest_set) < tol);

    mask            = mask_TCval & mask_Tmean & mask_Tsig & mask_Trest;

    data_TC         = data(mask, :);

end



% -------------------------------------------------------------------------
% CONVERTVOLTAGEVECTOR
% -------------------------------------------------------------------------
function Vnom = convertVoltageVector(chem, ns)
%CONVERTVOLTAGEVECTOR Compute nominal pack voltage from chemistry & Ns
%   Inputs
%     chem : string array, "LFP" or "NMC"
%     ns   : numeric array of series cell count
%   Output
%     Vnom : numeric array of nominal pack voltages [V]
%
%   Rules
%     - Special-cases common automotive pack configs:
%         LFP, Ns=4  -> 12 V   (approx 4 * 3.2V)
%         NMC, Ns=4  -> 15 V   (approx 4 * 3.7V)
%         LFP, Ns=16 -> 50 V   (approx 16 * 3.2V)
%         NMC, Ns=14 -> 50 V   (approx 14 * 3.6V)
%     - Fallback: 4 V per series cell (coarse nominal), if no rule matched.
%   Notes
%     - Keep arrays shape-consistent; output is same size as ns.

    Vnom                            = zeros(size(ns));
    Vnom(chem == "LFP" & ns == 4)   = 12;
    Vnom(chem == "NMC" & ns == 4)   = 15;
    Vnom(chem == "LFP" & ns == 16)  = 50;
    Vnom(chem == "NMC" & ns == 14)  = 50;

    % Generic linear fallback if no explicit rule matches
    fallback                        = (Vnom == 0);
    Vnom(fallback)                  = ns(fallback) * 4;    

end



% -------------------------------------------------------------------------
% PLOTCHEMBOXPLOTS
% -------------------------------------------------------------------------
function [best_fits, medians, pred_vals, lower_bounds, upper_bounds] = plotChemBoxplots(ax, data, xname, yname, pred_vals, chems, styles)
%PLOTCHEMBOXPLOTS Compute per-chemistry medians, fit trends, and draw bands
%   Inputs
%     ax        : target axes
%     data      : table containing columns Chemistry, xname, yname, and std*
%     xname     : nominal voltage (string/char)
%     yname     : response mean column name (e.g., 'meanEFC')
%     pred_vals : unique x-grid values to evaluate
%     chems     : ["LFP","NMC"]
%     styles    : struct of per-chem plot colors/offsets
%   Outputs
%     best_fits     : struct with per-chem fit function handles & metadata
%     medians       : struct with per-chem median(y) at each x in pred_vals
%     pred_vals     : (echoed) x-grid used
%     lower_bounds  : median(y) - median(std_y) envelope per chem
%     upper_bounds  : median(y) + median(std_y) envelope per chem
%
%   Behavior
%     - For each chem and x grid point, compute median of y.
%     - Fit a simple model among {log, sqrt, power, poly2}; keep best RSS.
%     - Draw fit lines and semi-transparent confidence “bands”
%       using median ± median(std).
%
%   Assumptions
%     - A std column exists and is named by swapping 'mean'->'std'.
%       Example: yname='meanEFC' => std column 'stdEFC'.


    % Initialize median containers
    best_fits                               = struct();
    medians                                 = struct();
    for chem = chems
        medians.(chem)                      = NaN(size(pred_vals));
    end


    % Aggregate medians per chemistry at every x value
    for k = 1:length(pred_vals)

        val                                 = pred_vals(k);

        for chem = chems

            idx_1                           = (data{:, xname} == val);
            idx_2                           = (data.Chemistry == chem);
            idx                             = idx_1 & idx_2;

            y                               = data{idx, yname};
            if isempty(y)
                continue; 
            end
            medians.(chem)(k)               = median(y, 'omitnan');

        end

    end


    % Fit and plot the median trends
    for chem = chems
        s                                   = styles.(chem);

        % Offset left for styling if needed
        notNaN                              = (~isnan(medians.(chem)));
        x                                   = pred_vals(notNaN) + s.offset; 
        y                                   = medians.(chem)(notNaN);


        % We need at least 4 points to fit well
        if numel(x) < 4
            continue; 
        end  


        % Model selection among a small set
        [fit_fun, fit_name, p, fit_summary] = bestFitAll(x, y);


        % Return a summary table
        best_fits.summary.(chem)            = fit_summary;


        % Return other interesting parameters
        best_fits.(chem)                    = fit_fun;
        best_fits.name.(chem)               = fit_name;
        best_fits.par.(chem)                = p;


        % Draw smooth curve for the best fit
        xq                                  = linspace(min(x), max(x), 200);
        yq                                  = fit_fun(xq);
        plot(xq, yq, '--', 'Color', s.color, 'LineWidth', 0.5);

        switch fit_name
            case 'log'
                label_str = sprintf('%.2f \\cdot log(V^{nom}_{pack}) %+.2f', p(1), p(2));
            case 'sqrt'
                label_str = sprintf('%.2f \\cdot sqrt(V^{nom}_{pack}) %+.2f', p(1), p(2));
            case 'power'
                label_str = sprintf('%.2f \\cdot {(V^{nom}_{pack})}^{%.2f}', p(1), p(2));
            case 'poly2'
                label_str = sprintf('%.2f V^2 %+.2f V %+.2f', p(1), p(2), p(3));
            otherwise
                label_str = fit_name;
        end        


        % Place the label near 20% of the curve to avoid edge clutter
        idx_label                           = round(0.2 * numel(xq));
        x_label                             = xq(idx_label);
        y_label                             = yq(idx_label);
        angle_deg                           = strcmp(chem,'LFP')*8 + strcmp(chem,'NMC')*20;

        text(ax, x_label, y_label + 0.2, label_str, ...
            'Interpreter', 'tex', ...
            'FontSize', 7, ...
            'Color', s.color, ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', ...
            'Rotation', angle_deg, 'FontName', 'Helvetica');
    end


    % Build simple uncertainty bounds: median ± median(std)
    lower_bounds                            = struct(); 
    upper_bounds                            = struct();
    for chem = chems

        idxc                                = (data.Chemistry == chem);

        x_vals                              = data{idxc, xname};
        y_vals                              = data{idxc, yname};

        % Derive std column name by replacing prefix 'mean' with 'std'
        std_col                             = ['std', extractAfter(yname, 'mean')];
        std_vals                            = data{idxc, std_col};

        for k = 1:length(pred_vals)

            val                             = pred_vals(k);
            chem_idx                        = (x_vals == val);

            if any(chem_idx)

                m                           = median(y_vals(chem_idx), 'omitnan');
                s                           = median(std_vals(chem_idx), 'omitnan');  
                lower_bounds.(chem)(k)      = m - s;
                upper_bounds.(chem)(k)      = m + s;

            else

                lower_bounds.(chem)(k)      = NaN;
                upper_bounds.(chem)(k)      = NaN;

            end

        end

    end


    % Draw translucent bands for each chemistry
    for chem = chems

        notNaN_Again                        = (~isnan(medians.(chem)));
        st                                  = styles.(chem);

        x                                   = pred_vals(notNaN_Again);
        lo                                  = lower_bounds.(chem)(notNaN_Again);
        hi                                  = upper_bounds.(chem)(notNaN_Again);


        % We need at least two points to make a polygon
        if length(x) < 2
            continue; 
        end  

        x_fill                              = [transpose(x), fliplr(transpose(x))];
        y_fill                              = [lo, fliplr(hi)];

        fill(ax, x_fill, y_fill, st.face, 'EdgeColor', 'none', 'FaceAlpha', 0.3);

    end

end



% -------------------------------------------------------------------------
% GETCHEMISTRYSTYLES
% -------------------------------------------------------------------------
function [chems, styles] = getChemistryStyles()
%GETCHEMISTRYSTYLES Centralized visual identity per chemistry
%   Outputs
%     chems  : ["LFP","NMC"] convenience array for looping
%     styles : struct with fields per chemistry:
%              .color  : RGB 1x3 line/marker color
%              .face   : RGB 1x3 fill color
%              .offset : optional x-offset for decluttering curves

    chems               = ["LFP", "NMC"];

    styles              = struct();
    styles.LFP.color    = [0 0 1];
    styles.LFP.face     = [0.8 0.8 1];
    styles.LFP.offset   = 0;

    styles.NMC.color    = [1 0.5 0];
    styles.NMC.face     = [1 0.85 0.5];
    styles.NMC.offset   = 0;

end



% -------------------------------------------------------------------------
% OVERLAYEVS
% -------------------------------------------------------------------------
function [legend_handles, legend_labels, eval_table] = overlayEVs(ax, nomVoltage_name, output_name, pred_vals, best_fits, all_data, styles,EV_DATA_PATH) %#ok<INUSD,INUSL>
%OVERLAYEVS Plot EV markers evaluated either from data or from the fit
%   Inputs
%     ax             : target axes
%     nomVoltage_name : column name for X ('NominalVoltage')
%     output_name    : column name for Y mean ('meanEFC')
%     pred_vals      : numeric vector of discrete x values in the dataset
%     best_fits      : struct with per-chem fit functions (fallback)
%     all_data       : table with Chemistry, NominalVoltage, output columns
%     styles         : color styling per chemistry
%   Outputs
%     legend_handles : plotted handles for potential legends
%     legend_labels  : names per handle
%     eval_table     : table with Name, Chemistry, VNom, Y_Value for entries plotted
%
%   Notes
%     - For each EV in EV_Data: try to use median of actual data at the
%       matching X; if unavailable, evaluate the best-fit curve.
%     - Skip EVs outside the plotting X-range or with missing Y-value.

    load(EV_DATA_PATH, 'EV_Data');

    legend_handles              = {}; 
    legend_labels               = {};
    eval_data                   = struct('Name',{}, 'Chemistry',{}, 'VNom',[], 'Y_Value',[]);

    % Independent marker cycles for each chemistry for visual variety
    marker_list                 = {'o','s','^','d','v','>','<','p','h','+','*','x','.','diamond','pentagram','hexagram','square'};
    lfp_idx                     = 0; 
    nmc_idx                     = 0;
															   

    for i = 1:numel(EV_Data.FullName)
        name                    = EV_Data.FullName{i};
        chem                    = EV_Data.Chemistry{i};
        xval                    = EV_Data.VNom(i);


        % Prefer real data (median at the nearest integer x), else use fit
        yval                    = NaN;

        match_idx_1             = strcmp(all_data.Chemistry, chem);
        match_idx_2             = (all_data{:, nomVoltage_name} == round(xval));
        match_idx               = match_idx_1 & match_idx_2;
        
        if any(match_idx)

            yval                = median(all_data{match_idx, output_name}, 'omitnan');

        elseif isfield(best_fits, chem)

            yval                = best_fits.(chem)(xval);

        end


        % Skip outside domain or missing values to avoid clutter
        if ((xval < 10) || (xval > 820) || (isnan(yval)))
            continue;
        end


        % Cycle markers separately per chemistry
        switch upper(chem)
            case 'LFP'
                lfp_idx         = lfp_idx + 1;
                mark_idx        = mod(lfp_idx - 1, numel(marker_list)) + 1;
                marker          = marker_list{mark_idx};
            case 'NMC'
                nmc_idx         = nmc_idx + 1;
                mark_idx        = mod(nmc_idx - 1, numel(marker_list)) + 1;
                marker          = marker_list{mark_idx};
            otherwise
                marker          = 'o';
        end


        % Draw EV point in chemistry color
        h = plot(ax, xval, yval, marker, ...
            'MarkerSize', 7, ...
            'MarkerEdgeColor', styles.(chem).color, ...
            'MarkerFaceColor', styles.(chem).color, ...
            'LineWidth', 1.5);

        legend_handles{end+1}   = h;                            %#ok<AGROW>
        legend_labels{end+1}    = name;                         %#ok<AGROW>

        eval_data(end+1)        = struct('Name', name, ...
                                    'Chemistry', chem, ...
                                    'VNom', xval, ...
                                    'Y_Value', yval);           %#ok<AGROW>
    end

    % Output as table for legend building elsewhere
    eval_table = struct2table(eval_data);
    assignin('base', 'vehicle_eval_table', eval_table); % convenient for ad-hoc inspection
end



% -------------------------------------------------------------------------
% SETUPAXES
% -------------------------------------------------------------------------
function setupAxes(ax, xtick_vals, y_label)
%SETUPAXES Apply consistent axis scaling, grids, and labels
%   Inputs
%     ax         : target axes
%     xtick_vals : vector of x-ticks to display
%     y_label    : LaTeX string for y-axis label
%
%   Notes
%     - X/Y limits are intentionally fixed for apples-to-apples comparison
%       across figures. 

    % Hard-coded X domain (NominalVoltage)
    xlim(ax, [12, 820]);   


    % Hard-coded Y range for meanEFC
    ylim(ax, [0, 34.5]);     


    % Remaining axes settings
    ax.GridAlpha  = 0.4;
    ax.GridColor  = [0.85 0.85 0.85];
    ax.LineWidth  = 1;
    grid(ax, 'on');

    set(ax, ...
        'XTick', xtick_vals, ...
        'XTickLabel', string(xtick_vals), ...
        'TickLabelInterpreter', 'tex', ...
        'Box', 'on', ...
        'FontSize', 7, ...
        'FontName', 'Helvetica');                

    ylabel(ax, y_label, 'Interpreter','tex', 'FontSize', 7, 'FontName', 'Helvetica');


end



% -------------------------------------------------------------------------
% DRAWSPLITLEGENDBOXEDHORIZONTAL
% -------------------------------------------------------------------------
function drawSplitLegendBoxedHorizontal(ax, vehicle_eval_table, styles)
%DRAWSPLITLEGENDBOXEDHORIZONTAL Inline, readable legend grouped by chemistry
%   Inputs
%     ax                 : target axes
%     vehicle_eval_table : table returned from overlayEVs (Name, Chemistry, Y_Value)
%     styles             : colors per chemistry
%
%   Notes
%     - Two compact groups: LFP near bottom, NMC near top.
%     - Each group is boxed with a subtle border.
%     - Items are sorted by Y_Value (ascending) to provide a quick ranking.

    % List of markers
    marker_list         = {'o','s','^','d','v','>','<','p','h','+','*','x','.','diamond','pentagram','hexagram','square'};


    % Sort each chemistry group by performance
    isLFP               = strcmpi(vehicle_eval_table.Chemistry, 'LFP');
    isNMC               = strcmpi(vehicle_eval_table.Chemistry, 'NMC');
    LFP                 = sortrows(vehicle_eval_table(isLFP, :), 'Y_Value');
    NMC                 = sortrows(vehicle_eval_table(isNMC, :), 'Y_Value');


    % Position basis and layout parameters
    xlims               = xlim(ax); 
    ylims               = ylim(ax);
			

    % Left margin inside the axes
    x0                  = xlims(1) + 30;   


    % Horizontal distance between legend columns
    h_spacing           = 200;   


    % Vertical distance between rows
    v_spacing           = 1;      
				  

    % Wrap after N items per row
    itemsPerRow         = 4;      


    % Draw LFP group from bottom upward
    y0_LFP = ylims(1) + 1;
    drawLegendGroupRowWise(ax, LFP, styles, 'LFP Vehicles', ...
        x0, y0_LFP, itemsPerRow, h_spacing, v_spacing, ...
        marker_list, ...
        false, 0);


    % Draw NMC group from top downward
    y0_NMC = ylims(2) - 5;
    drawLegendGroupRowWise(ax, NMC, styles, 'NMC Vehicles', ...
        x0, y0_NMC, itemsPerRow, h_spacing, v_spacing, ...
        marker_list, ...
        true, 0);

end



% -------------------------------------------------------------------------
% DRAWLEGENDGROUPROWWISE
% -------------------------------------------------------------------------
function drawLegendGroupRowWise(ax, group_table, styles, title_str, ...
    x0, y0, itemsPerRow, h_spacing, v_spacing, marker_list, invert_rows, marker_offset)
%DRAWLEGENDGROUPROWWISE Low-level routine to render a labeled legend grid
%   Inputs
%     ax, group_table, styles, title_str : as named
%     x0, y0       : anchor coordinate inside axes (left, baseline)
%     itemsPerRow  : number of legend items per row before wrapping
%     h_spacing    : x-distance between columns
%     v_spacing    : y-distance between rows
%     marker_list  : cell array of marker symbols to cycle through
%     invert_rows  : logical; true draws rows downward from y0 (for top block)
%     marker_offset: integer offset into marker_list (for staggered groups)
%
%   Output
%     (none)       : draws markers, labels, and a surrounding box on ax
%
%   Notes
%     - Uses data coordinates (not normalized), so it stays anchored to the
%       same visual scale when paned/zoomed within the axes.

    n               = height(group_table);
    rows            = ceil(n / itemsPerRow);
    dx              = h_spacing; 
    dy              = v_spacing;


    % For box extents
    all_x           = zeros(n, 1); 
    all_y           = zeros(n, 1); 



    for i = 1:n

        % Compute grid position
        col         = mod((i-1), itemsPerRow);
        row         = floor((i-1) / itemsPerRow);


        % Draw top group downward
        if invert_rows
            row     = rows - 1 - row; 
        end


        % Convert grid to data coordinates
        x           = x0 + col * dx;
        y           = y0 + row * dy;


        % Fetch display values
        name        = group_table.Name{i};
        chem        = string(group_table.Chemistry{i});


        % Cycle markers
        marker_idx  = marker_offset + i;
        marker      = marker_list{mod(marker_idx - 1, numel(marker_list)) + 1};


        % Marker + text label
        plot(ax, x, y, marker, ...
                'MarkerSize', 7, ...
                'MarkerFaceColor', styles.(chem).color, ...
                'MarkerEdgeColor', styles.(chem).color, ...
                'LineWidth', 1.2);
        text(ax, x + 10, y, name, ...
             'Color', styles.(chem).color, ...
             'Interpreter', 'tex', ...
             'FontSize', 7, 'FontName', 'Helvetica', ...
             'HorizontalAlignment', 'left', ...
             'VerticalAlignment', 'middle');
             % 'FontSize', 11, ...  % NatComm: original        


        % Track extents for box
        all_x(i)    = x; 
        all_y(i)    = y;

    end

    % Draw a subtle rounded rectangle around the group
    padding         = 4;
    x_min           = min(all_x) - 2 * padding;
    x_max           = max(all_x) + 160;   % space for text labels
    y_min           = min(all_y) - dy / 1.5;
    y_max           = max(all_y) + dy / 1.5;

    rectangle(ax, ...
        'Position', [x_min, y_min, x_max - x_min, y_max - y_min], ...
        'EdgeColor', [0.5 0.5 0.5], ...
        'LineWidth', 0.8, ...
        'LineStyle', '-', ...
        'Curvature', 0.1);


    % Title the group
    text(ax, x_min + 2, y_max + 0.5, title_str, ...
        'FontSize', 7, 'FontName', 'Helvetica', ...
        'FontWeight', 'bold', ...
        'Interpreter', 'tex', ...
        'Color', [0.3 0.3 0.3]);    

end



% -------------------------------------------------------------------------
% BESTFITALL
% -------------------------------------------------------------------------
function [best_fit, name, p_best, fit_summary] = bestFitAll(x, y)
%BESTFITALL Try several simple models and pick the lowest-RSS fit
%   Inputs
%     x, y        : numeric vectors (same length)
%   Outputs
%     best_fit    : function handle @(xq) predicting y on new xq
%     name        : name of winning model: 'log' | 'sqrt' | 'power' | 'poly2' 
%     p_best      : parameter vector of the winning model
%     fit_summary : table with rows per model: Model, Param1..3, RMSE, MAE, R2
%
%   Models tried (in order)
%     - log:   a*log(x) + b
%     - sqrt:  a*sqrt(x) + b
%     - power: a*x^b     (nonlinear in parameters)
%     - poly2: a*x^2 + b*x + c
%
%   Notes
%     - We use RMSE/MAE/R^2 for reporting; selection is based on RSS.
%     - Initial guesses are intentionally simple to keep this robust.

    models = ...
    {
        @(a,b,x) a*log(x)+b,               'log',   2;
        @(a,b,x) a*sqrt(x)+b,              'sqrt',  2;
        @(a,b,x) a*x.^b,                   'power', 2;
        @(a,b,c,x) a*x.^2 + b*x + c,      'poly2', 3;
    };

    fit_summary             = table();
    best_rss                = Inf; 
    best_fit                = []; 
    name                    = ''; 
    p_best                  = [];


    for i = 1:size(models,1)

        f                   = models{i,1}; 
        label               = models{i,2}; 
        n_params            = models{i,3};


        % Define RSS cost and naive initial guess
        if (n_params == 2)

            cost            = @(p) sum((f(p(1), p(2), x) - y).^2);
            p0              = [1, 1];
            p               = fminsearch(cost, p0, optimset('Display','off'));
            y_pred          = f(p(1), p(2), x);

        else

            cost            = @(p) sum((f(p(1), p(2), p(3), x) - y).^2);
            p0              = [0, 0, mean(y)];
            p               = fminsearch(cost, p0, optimset('Display','off'));
            y_pred          = f(p(1), p(2), p(3), x);

        end


        % Report metrics for transparency and later tabulation
        rmse                = sqrt(mean((y_pred - y).^2));
        mae                 = mean(abs(y_pred - y));
        ss_res              = sum((y - y_pred).^2);
        ss_tot              = sum((y - mean(y)).^2);
        r2                  = 1 - ss_res/ss_tot;


        % Append to summary (Param3=NaN for 2-param models)
        if (n_params == 2)
            new_row         = {label, p(1), p(2), NaN, rmse, mae, r2};
        else
            new_row         = {label, p(1), p(2), p(3), rmse, mae, r2};
        end
        fit_summary         = [fit_summary; new_row];                   %#ok<AGROW>

        % Keep the model with the smallest RSS
        if (ss_res < best_rss)

            best_rss        = ss_res;

            if (n_params == 2)
                best_fit    = @(xq) f(p(1), p(2), xq);
            else
                best_fit    = @(xq) f(p(1), p(2), p(3), xq);
            end

            name            = label; 
            p_best          = p;

        end

    end

    % Finalize summary headers
    fit_summary.Properties.VariableNames = {'Model', 'Param1', 'Param2', 'Param3', 'RMSE', 'MAE', 'R2'};
end



% -------------------------------------------------------------------------
% FORMATPARAM
% -------------------------------------------------------------------------
function s = formatParam(val, model, param_idx)
%FORMATPARAM Render numeric parameter for LaTeX table, or '--' if unused
%   Inputs
%     val       : numeric scalar (may be NaN)
%     model     : model name (string)
%     param_idx : which parameter index (1..3)
%   Output
%     s         : string ("--" for unused/NaN)
%
%   Notes
%     - For poly2, Param3 is a legitimate parameter; if it is NaN for some
%       reason, we choose '0.0000'.

    if isnan(val)
        isModelPoly2    = strcmp(model, 'poly2');
        isParamIdx3     = (param_idx == 3);

        if (isModelPoly2 && isParamIdx3)
            s           = '0.0000';
        else
            s           = '--';
        end

    else
        s               = sprintf('%.6f', val);
    end

end


% A helper: find file in DATA_DIRS
function p = find_in_data_dirs(fname, data_dirs)
    if isstring(fname),      fname = char(fname);      end
    if isstring(data_dirs),  data_dirs = cellstr(data_dirs); end
    if ischar(data_dirs),    data_dirs = {data_dirs};  end

    for k = 1:numel(data_dirs)
        d = data_dirs{k};
        cand = fullfile(d, fname);
        if exist(cand, 'file')
            p = cand;
            return
        end
    end
    error('find_in_data_dirs:NotFound', ...
          'Could not find "%s" in: %s', fname, strjoin(data_dirs, ', '));
end