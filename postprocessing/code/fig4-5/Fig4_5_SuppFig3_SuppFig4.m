%% PREPARE
clearvars -except CODE_DIR
close all; clc;



%% ===== Code Ocean / portable paths setup =====
ROOT_DIR = fileparts(CODE_DIR); %fileparts(fileparts(CODE_DIR));
DATA_DIR = fullfile(ROOT_DIR, 'data');
RESULTS_DIR = fullfile(ROOT_DIR, 'results', 'fig4-5'); 
if (~isfolder(RESULTS_DIR))
    mkdir(RESULTS_DIR); 
end  

% Global defaults
set(groot, 'DefaultAxesTickLabelInterpreter', 'tex');
set(groot, 'DefaultTextInterpreter', 'tex');
set(groot, 'DefaultLegendInterpreter', 'tex');
set(groot, 'DefaultAxesFontName', 'Helvetica');
set(groot, 'DefaultTextFontName', 'Helvetica');
set(groot, 'DefaultLegendFontName', 'Helvetica');

set(groot, 'DefaultAxesFontSize', 7);
set(groot, 'DefaultTextFontSize', 7);
set(groot, 'DefaultLegendFontSize', 7);

% === Output targets ===
% Figure 5 is split into two files:
%   Figure5a: panels (a)-(d) — cost composition and NPC trajectories
%   Figure5b: panels (a)-(f) — sensitivity analysis (formerly panels e-j)
OUT_FIG4_PDF  = fullfile(RESULTS_DIR, 'J1_NatComm_Figure_4.pdf');
OUT_FIG4_EPS  = fullfile(RESULTS_DIR, 'J1_NatComm_Figure_4.eps');
OUT_FIG4_FIG  = fullfile(RESULTS_DIR, 'J1_NatComm_Figure_4.fig');
OUT_FIG5_PDF  = fullfile(RESULTS_DIR, 'J1_NatComm_Figure_5.pdf');
OUT_FIG5_EPS  = fullfile(RESULTS_DIR, 'J1_NatComm_Figure_5.eps');
OUT_FIG5_FIG  = fullfile(RESULTS_DIR, 'J1_NatComm_Figure_5.fig');
OUT_SUPP3_PDF  = fullfile(RESULTS_DIR, 'J1_NatComm_SuppFigure_3.pdf');
OUT_SUPP3_EPS  = fullfile(RESULTS_DIR, 'J1_NatComm_SuppFigure_3.eps');
OUT_SUPP3_FIG  = fullfile(RESULTS_DIR, 'J1_NatComm_SuppFigure_3.fig');
OUT_SUPP4_PDF  = fullfile(RESULTS_DIR, 'J1_NatComm_SuppFigure_4.pdf');
OUT_SUPP4_EPS  = fullfile(RESULTS_DIR, 'J1_NatComm_SuppFigure_4.eps');
OUT_SUPP4_FIG  = fullfile(RESULTS_DIR, 'J1_NatComm_SuppFigure_4.fig');



%%%%%%%%%%%%%%%%%%%%%%% USER CONFIGURATION %%%%%%%%%%%%%%%%%%%%%%%
params                      = getParams();
paramsBaseline              = params;

% ========== PARAMETER RANGES ==========
paramRanges                 = getParamRanges();



%%%%%%%%%%%%%%%%%%%%%%% TEST IF THE FUNCTIONS WORK %%%%%%%%%%%%%%%%%%%%%%%
%resultBaseline             = computeNPC_DiscAndNonDisc(paramsBaseline);



%% %%%%%%%%%%%%%%%%%%%%%%% SAMPLE & PLOT MULTIVARIATE SENSITIVITY %%%%%%%%%%%%%%%%%%%%%%%
n_samples = 100000;
% Figure-export note:
% The plotting functions below deterministically decimate only
% the displayed scatter clouds; all fitted lines, medians, rectangles,
% boxcharts, and selected scenarios are still computed from the full
% sample set.

% ---------- Run the experiment ----------
[samples, delta_NPC, results_all, p_out_all] = sampleDeltaNPC_LHS(paramRanges, n_samples, paramsBaseline);

% Convert to kEUR
delta_NPC_kEuros = delta_NPC / 1000;

% ---------- Identify best, baseline, worst ----------
[maxNPC, idx_max]       = max(delta_NPC_kEuros);
resultBest              = results_all(idx_max);
pBest                   = p_out_all(idx_max);
idx.best                = idx_max;

idx_baseline            = n_samples;
resultBaseline          = results_all(idx_baseline);
baselineNPC             = resultBaseline.delta_NPC;
pBaseline               = p_out_all(idx_baseline);
idx.baseline            = idx_baseline;

[minNPC, idx_min]       = min(delta_NPC_kEuros);
resultWorst             = results_all(idx_min);
pWorst                  = p_out_all(idx_min);
idx.worst               = idx_min;



%% ======================================================================
%  FIGURE 5a: Cost composition and cumulative NPC trajectories
%  Panels (a)-(d)
% ======================================================================
% 
ylims_Main   = [-3 6];
yticks_Main  = [-3 0 3 6];
dotSize      = 1;
dotSize2     = 10;

% --- Figure 4 size: Nature 2-column, preserve original Fig. 4 ratio ---
paperWidth  = 18.0;      % 180 mm, Nature 2-column original research
paperHeight = 14.0;      %

figCosts = figure( ...
    'Units', 'centimeters', ...
    'Position', [2 2 paperWidth paperHeight], ...
    'Color', 'w');
tl_costs = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Panel (a): Annual cost breakdown, spans full first row ---
axAnnualCost = nexttile(tl_costs, 1, [1 3]);
yLim_axAnnual   = [-3 9];
yTicks_axAnnual = [-3 0 3 6 9];
plotAnnualCostBreakdown_DiscNonDisc_Subplot(axAnnualCost, resultBaseline, yLim_axAnnual, yTicks_axAnnual, 'nondiscounted');
addPanelLabel(axAnnualCost, '(\bfa\rm)', -0.05, 1, 7);

% --- Panel (b): Best-case cumulative NPC ---
axBestCase = nexttile(tl_costs);
yLim_axBest   = [10 30];
yTicks_axBest = [10 15 20 25 30];
plotCumulativeNPC_DiscNonDisc_Subplot(axBestCase, resultBest, true, true, "northwest", "Best", resultBest.delta_NPC, yLim_axBest, yTicks_axBest, 'discounted');
addPanelLabel(axBestCase, '(\bfb\rm)', -0.2, 1, 7);

% --- Panel (c): Baseline cumulative NPC ---
axBaselineCase = nexttile(tl_costs);
yLim_axBaseline   = [5 25];
yTicks_axBaseline = [5 10 15 20 25];
plotCumulativeNPC_DiscNonDisc_Subplot(axBaselineCase, resultBaseline, true, true, "northwest", "Baseline", resultBaseline.delta_NPC, yLim_axBaseline, yTicks_axBaseline, 'discounted');
addPanelLabel(axBaselineCase, '(\bfc\rm)', -0.2, 1, 7);

% --- Panel (d): Worst-case cumulative NPC ---
axWorstCase = nexttile(tl_costs);
yLim_axWorst   = [0 60];
yTicks_axWorst = [0 20 40 60];
plotCumulativeNPC_DiscNonDisc_Subplot(axWorstCase, resultWorst, true, true, "northwest", "Worst", resultWorst.delta_NPC, yLim_axWorst, yTicks_axWorst, 'discounted');
addPanelLabel(axWorstCase, '(\bfd\rm)', -0.2, 1, 7);


set(figCosts, ...
    'Units', 'centimeters', ...
    'Position', [2 2 paperWidth paperHeight], ...
    'PaperUnits', 'centimeters', ...
    'PaperSize', [paperWidth paperHeight], ...
    'PaperPosition', [0 0 paperWidth paperHeight], ...
    'PaperPositionMode', 'manual', ...
    'Color', 'w');

drawnow;

exportgraphics(figCosts, OUT_FIG4_PDF, 'ContentType', 'vector', 'BackgroundColor','white');
exportgraphics(figCosts, OUT_FIG4_EPS, 'ContentType', 'vector', 'BackgroundColor','white');
saveas(figCosts, OUT_FIG4_FIG);
fprintf('Figure 4 exported.\n');



%% ======================================================================
%  FIGURE 5b: Sensitivity analysis
%  Panels (a)-(f)  [formerly panels (e)-(j) of the original Fig. 5]
% ======================================================================

% --- Figure 5 size: Nature 2-column, preserve original Fig. 5 ratio ---
paperWidth  = 18.0;      % 180 mm, Nature 2-column original research
paperHeight = 14.0;      % 

figSens = figure( ...
    'Units', 'centimeters', ...
    'Position', [2 2 paperWidth paperHeight], ...
    'Color', 'w');
tl_sens = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Panel (a): Global sensitivity ranking (Spearman) ---
axSpearman = nexttile(tl_sens);
tornadoPlotDeltaNPC_Subplot(axSpearman, samples, delta_NPC_kEuros);
addPanelLabel(axSpearman, '(\bfa\rm)', -0.15, 1, 7);

% --- Panel (b): 1D sensitivity to E_pack_nom ---
axEpacknom = nexttile(tl_sens);
x_axEpack     = samples.E_pack_nom;
y_axEpack     = delta_NPC_kEuros;
xLabel_axEpack = 'E_{pack}^{nom} [kWh]';
xLim_axEpack  = [10 130];
xTicks_axEpack = 20:20:120;
[x_zero_E, R_squared_E, RMSE_E] = plotSensitivity1D_NoPerc_Subplot( ...
    axEpacknom, x_axEpack, y_axEpack, xLabel_axEpack, xLim_axEpack, xTicks_axEpack, ...
    ylims_Main, yticks_Main, idx_max, idx_baseline, idx_min, dotSize2);
addPanelLabel(axEpacknom, '(\bfb\rm)', -0.15, 1, 7);

% --- Panel (c): 1D sensitivity to L ---
axL = nexttile(tl_sens);
xlims_L  = [5000 70000];
xticks_L = 5000:20000:70000;
[x_zero_L, R_squared_L, RMSE_L] = plotSensitivity1D_NoPerc_Subplot( ...
    axL, samples.L, delta_NPC_kEuros, 'L [km]', xlims_L, xticks_L, ...
    ylims_Main, yticks_Main, idx_max, idx_baseline, idx_min, dotSize, "northwest");
addPanelLabel(axL, '(\bfc\rm)', -0.15, 1, 7);

% --- Panel (d): 1D sensitivity to nu ---
axnu = nexttile(tl_sens);
x_axnu      = samples.nu;
y_axnu      = delta_NPC_kEuros;
xLabel_axnu = '\nu [%]';
xlims_axnu  = [0 16];
xticks_axnu = [0 5 10 15];
[x_zero_nu, R_squared_nu, RMSE_nu] = plot1DWithRegression_Subplot( ...
    axnu, x_axnu, y_axnu, xLabel_axnu, xlims_axnu, xticks_axnu, ...
    ylims_Main, yticks_Main, idx_max, idx_baseline, idx_min, dotSize);
addPanelLabel(axnu, '(\bfd\rm)', -0.15, 1, 7);

% --- Panels (e) and (f): Design-space rectangle and chemistry boxplot ---
axRectPlot = nexttile(tl_sens);
xLim_axRectPlot   = [0 15.1];
xTicks_axRectPlot = [0 5 10 15];
yLim_axRectPlot   = [4500 89000];
yTicks_axRectPlot = [10000 30000 50000 70000];

axChemPlot = nexttile(tl_sens);
rect_bounds      = [paramRanges.nu.LIMITS; paramRanges.L.LIMITS];
successThreshold = 0.997;
dotSize          = 1;
[nu_best, L_best] = plotChemistryBoxScatterWithRectangle_Modified_Subplot_v2( ...
    axChemPlot, axRectPlot, samples, delta_NPC, ...
    rect_bounds, ylims_Main, yticks_Main, true, successThreshold, dotSize, ...
    xLim_axRectPlot, xTicks_axRectPlot, yLim_axRectPlot, yTicks_axRectPlot);
addPanelLabel(axRectPlot, '(\bfe\rm)', -0.15, 1, 7);
addPanelLabel(axChemPlot, '(\bff\rm)', -0.15, 1, 7);
fprintf('nu < %.4g and delta < %.4g\n', nu_best, L_best);

set(figSens, ...
    'Units', 'centimeters', ...
    'Position', [2 2 paperWidth paperHeight], ...
    'PaperUnits', 'centimeters', ...
    'PaperSize', [paperWidth paperHeight], ...
    'PaperPosition', [0 0 paperWidth paperHeight], ...
    'PaperPositionMode', 'manual', ...
    'Color', 'w');

drawnow;

exportgraphics(figSens, OUT_FIG5_PDF, 'ContentType', 'vector','BackgroundColor','white');
exportgraphics(figSens, OUT_FIG5_EPS, 'ContentType', 'vector');
saveas(figSens, OUT_FIG5_FIG);
fprintf('Figure 5 exported.\n');



%% ============================ SUPPLEMENTARY FIGURE S3 EXPORT ============================
paperWidth  = 18.0;      % 180 mm, Nature 2-column original research
paperHeight = 12.73;      % 

figSuppFigure3 = figure( ...
    'Units', 'centimeters', ...
    'Position', [2 2 paperWidth paperHeight], ...
    'Color', 'w');

tlSupp = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');

axdeltaLoss = nexttile(tlSupp);
xlims_deltaLoss = [1 5];
xticks_deltaLoss = 1:1:5;
[x_zero_delta, R_squared_delta, RMSE_delta] = plot1DWithRegression_Subplot(axdeltaLoss, samples.delta_loss, delta_NPC_kEuros, ...
    '\delta_{loss} [%]', xlims_deltaLoss, xticks_deltaLoss, ...
    ylims_Main, yticks_Main, idx_max, idx_baseline, idx_min, dotSize); 
addPanelLabel(axdeltaLoss, '(\bfa\rm)', -0.15, 1, 7);

axdeltaalpha = nexttile(tlSupp);
samples.delta_alpha     = samples.alpha_CBP - samples.alpha_RBP;
x_axSupp1               = samples.delta_alpha; 
y_axSupp1               = delta_NPC_kEuros; 
xLabel_axSupp1          = '\Delta\alpha [%]';
xLim_axSupp1            = [0.5 1.5];
xTicks_axSupp1          = [0.5 1 1.5];
plot1DWithRegression_Subplot(axdeltaalpha, x_axSupp1, y_axSupp1, xLabel_axSupp1, xLim_axSupp1, xTicks_axSupp1, ylims_Main, yticks_Main, idx_max, idx_baseline, idx_min, dotSize);
addPanelLabel(axdeltaalpha, '(\bfb\rm)', -0.15, 1, 7);   

axr = nexttile(tlSupp);
x_axr               = samples.r_CBP; 
y_axr               = delta_NPC_kEuros; 
xLabel_axr          = 'r [%]';    
xlims_axr           = [2 4];
xticks_axr          = [1 2 3 4 5];
plotSensitivity1D_Subplot(axr, x_axr, y_axr, ...
xLabel_axr, xlims_axr, xticks_axr, ylims_Main, yticks_Main, idx_max, idx_baseline, idx_min, dotSize);    
addPanelLabel(axr, '(\bfc\rm)', -0.15, 1, 7);    

axYEV = nexttile(tlSupp);
x_axYEV               = samples.Y_EV; 
y_axYEV               = delta_NPC_kEuros; 
xLabel_axYEV          = 'Y_{{EV}} [years]';    
xlims_axYEV           = [15 20];
xticks_axYEV          = 15:1:20;
plotSensitivity1D_Subplot(axYEV, x_axYEV/100, y_axYEV, xLabel_axYEV, xlims_axYEV, xticks_axYEV, ylims_Main, yticks_Main, idx_max, idx_baseline, idx_min, dotSize);  
addPanelLabel(axYEV, '(\bfd\rm)', -0.15, 1, 7); 

axSOHCBP = nexttile(tlSupp);
x_axSOHCBP               = samples.SOH_EOL_SecondLife_CBP; 
y_axSOHCBP               = delta_NPC_kEuros; 
xLabel_axSOHCBP          = 'SOH_{EOL2}^{CBP} [%]';
xLim_axSOHCBP            = [50, 60];
xTicks_axSOHCBP          = [50 55 60];
plotSensitivity1D_Subplot(axSOHCBP, x_axSOHCBP, y_axSOHCBP, xLabel_axSOHCBP, xLim_axSOHCBP, xTicks_axSOHCBP, ylims_Main, yticks_Main, idx_max, idx_baseline, idx_min, dotSize);
addPanelLabel(axSOHCBP, '(\bfe\rm)', -0.15, 1, 7);   

axSOHRBP = nexttile(tlSupp);
x_axSOHRBP               = samples.SOH_EOL_SecondLife_RBP; 
y_axSOHRBP               = delta_NPC_kEuros; 
xLabel_axSOHRBP          = 'SOH_{EOL2}^{RBP} [%]';    
xlims_axSOHRBP           = [40, 50];
xticks_axSOHRBP          = [40 45 50];
plotSensitivity1D_Subplot(axSOHRBP, x_axSOHRBP, y_axSOHRBP, ...
xLabel_axSOHRBP, xlims_axSOHRBP, xticks_axSOHRBP, ylims_Main, yticks_Main, idx_max, idx_baseline, idx_min, dotSize);    
addPanelLabel(axSOHRBP, '(\bff\rm)', -0.15, 1, 7);   

% Set PaperSize for export
set(figSuppFigure3, ...
    'Units', 'centimeters', ...
    'Position', [2 2 paperWidth paperHeight], ...
    'PaperUnits', 'centimeters', ...
    'PaperSize', [paperWidth paperHeight], ...
    'PaperPosition', [0 0 paperWidth paperHeight], ...
    'PaperPositionMode', 'manual', ...
    'Color', 'w');

drawnow;

% Scatter-heavy artists are visually decimated inside the
% plotting helpers, so the PDF remains vector without storing all 100000
% samples as individual markers.
exportgraphics(figSuppFigure3, OUT_SUPP3_PDF, 'ContentType','vector','BackgroundColor','white');
exportgraphics(figSuppFigure3, OUT_SUPP3_EPS, 'ContentType','vector','BackgroundColor','white');
saveas(figSuppFigure3, OUT_SUPP3_FIG);
fprintf('Supplementary Figure 3 exported.\n');



%% ============================ SUPPLEMENTARY FIGURE S4 EXPORT ============================
figSuppFigure4 = figure( ...
    'Units', 'centimeters', ...
    'Position', [2 2 paperWidth paperHeight], ...
    'Color', 'w');
tlSupp_2D = tiledlayout(figSuppFigure4, 1, 3, 'TileSpacing','compact','Padding','compact');

xlims = {[0 15.1], [0 15.1], [1 5]};
ylims = {[4500 82000], [1 5.85714], [4500 82000]};
xticks = {[0 5 10 15], [0 5 10 15], [1 3 5]};
yticks = {[10000 30000 50000 70000], [1 3 5], [10000 30000 50000 70000]};
xVars = {"nu", "nu", "delta_loss"};
yVars = {"L", "delta_loss", "L"};
xLabels = {'\nu [%]', '\nu [%]', '\delta_{{loss}} [%]'};
yLabels = {'L [km]', '\delta_{{loss}} [%]', 'L [km]'};
xInPerc = [true, true, true];
yInPerc = [false, true, false];
boundsList = {
    [paramRanges.nu.LIMITS;          paramRanges.L.LIMITS], ...
    [paramRanges.nu.LIMITS;          paramRanges.delta_loss.LIMITS], ...
    [paramRanges.delta_loss.LIMITS;  paramRanges.L.LIMITS]
};

dotSize = 1;  
successThreshold = 0.997;


panelLetters = {'(\bfa\rm)','(\bfb\rm)','(\bfc\rm)'};
rectResults  = struct('panel',{},'xVar',{},'yVar',{},'edges',{},'altEdges',{},'success_rate',{},'x_max',{},'y_max',{});

for i = 1:3
    axRect = nexttile(tlSupp_2D);

    [x_best_i, y_best_i, srate_i, edges_i, alt_i, ...
    x_best_alt_i, y_best_alt_i, srate_alt_i] = plotDominantRectangle2DOnly( ...
    axRect, samples, delta_NPC, ...
    boundsList{i}, true(size(samples.(xVars{i}))), successThreshold, dotSize, ...
    xlims{i}, xticks{i}, ylims{i}, yticks{i}, ...
    xVars{i}, yVars{i}, xInPerc(i), yInPerc(i), ...
    xLabels{i}, yLabels{i}, ...
    0.95, true);   

    set(axRect, 'TickLabelInterpreter','tex', 'FontName','Helvetica', 'FontSize',7);
    addPanelLabel(axRect, panelLetters{i}, -0.15, 1, 7);

    % Store for later use
    rectResults(i).panel        = char(panelLetters{i});
    rectResults(i).xVar         = xVars{i};        
    rectResults(i).yVar         = yVars{i};        

    rectResults(i).main.x_max   = x_best_i;
    rectResults(i).main.y_max   = y_best_i;
    rectResults(i).main.rate    = srate_i;
    rectResults(i).main.edges   = edges_i;         % struct with x_min/x_max/y_min/y_max

    rectResults(i).alt.x_max    = x_best_alt_i;
    rectResults(i).alt.y_max    = y_best_alt_i;
    rectResults(i).alt.rate     = srate_alt_i;
    rectResults(i).alt.edges    = alt_i;           % struct with x_min/x_max/y_min/y_max
    fprintf("Supplementary Figure 3: %d / 3 completed.\n", i);
end

% Optional: print or save edges for reproducibility
for i = 1:numel(rectResults)
    e_main = rectResults(i).main.edges;
    e_alt  = rectResults(i).alt.edges;

    % Main rectangle
    e = rectResults(i).main.edges;
    if isstruct(e)
        fprintf('Panel %s, main: for %s < %.4g and %s < %.4g, success rate = %.2f%%\n', ...
            rectResults(i).panel, rectResults(i).xVar, e.x_max, rectResults(i).yVar, e.y_max, 100*rectResults(i).main.rate);
    end

    % Alternative rectangle
    ea = rectResults(i).alt.edges;
    if isstruct(ea) && ~any(isnan([ea.x_max ea.y_max]))
        fprintf('Panel %s, alt:  for %s < %.4g and %s < %.4g, success rate = %.2f%%\n', ...
            rectResults(i).panel, rectResults(i).xVar, ea.x_max, rectResults(i).yVar, ea.y_max, 100*rectResults(i).alt.rate);
    end
end

paperWidth  = 18.0;      % 180 mm, Nature 2-column original research
paperHeight = 10.18;      % 

set(figSuppFigure4, ...
    'Units', 'centimeters', ...
    'Position', [2 2 paperWidth paperHeight], ...
    'PaperUnits', 'centimeters', ...
    'PaperSize', [paperWidth paperHeight], ...
    'PaperPosition', [0 0 paperWidth paperHeight], ...
    'PaperPositionMode', 'manual', ...
    'Color', 'w');

drawnow;


% Export as vector. The 2D rectangle plots below draw only a deterministic
% visual subset of the sample cloud; rectangle selection still uses the full
% 100000-sample dataset.
exportgraphics(figSuppFigure4, OUT_SUPP4_PDF, 'ContentType','vector','BackgroundColor','white');
exportgraphics(figSuppFigure4, OUT_SUPP4_EPS, 'ContentType','vector','BackgroundColor','white');
saveas(figSuppFigure4, OUT_SUPP4_FIG);
fprintf('Supplementary Figure 4 exported.\n');

figs = findall(0, 'Type', 'figure');
close(setdiff(figs, [figCosts, figSens, figSuppFigure3, figSuppFigure4]));
fprintf('All done. Results saved under "%s/".\n\n', RESULTS_DIR);



%% AUXILIARY FUNCTIONS
% -------------------------------------------------------------------------
% GETPARAMS
% -------------------------------------------------------------------------
function paramsOut = getParams(varargin)
    % ====== DEFAULT PARAMETERS ======
    defaultParams = struct( ...
        'E_pack_nom',               80, ...            % [kWh]
        'V_pack_nom',               800, ...           % [V] 
        'V_nom_module',             50, ...            % [V]
        'Chemistry',                "LFP", ...         % "LFP" or "NMC"
        'UserSelection',            1, ...
        'Y_EV',                     18.8, ...          % [years]
        'Y_CBP',                    10, ...            % [years]
        'r_CBP',                    0.03, ...          % [fraction]
        'r_RBP',                    0.03, ...          % [fraction]
        'alpha_CBP',                0.02, ...          % [fraction/year]
        'alpha_RBP',                0.02 * 0.5, ...    % [fraction/year]
        'delta_loss',               0.03, ...          % [fraction]
        'SOH_EOL_FirstLife_CBP',    0.8, ...
        'SOH_EOL_FirstLife_RBP',    0.8, ...
        'SOH_EOL_SecondLife_CBP',   0.55, ...
        'SOH_EOL_SecondLife_RBP',   0.45, ...
        'c_pack_USDperkWh',         115, ...           % [USD/kWh]
        'currExch_USDtoEUR',        0.8554, ...
        'c_en_EURperkWh',           0.24, ...
        'eta_en_kWhkm',             0.2, ...
        'L',                        12000, ...         % [km/year]
        'nu',                       0.075, ...
        'c_res_CBP_USDperkWh',      22.99, ...         % [USD/kWh]
        'c_res_RBP_USDperkWh',      22.99, ...         % [USD/kWh]
        'c_res_depreccoeff',        0.5, ...
        'DefaultIndicator',         true...        
    );

    % Derived
    defaultParams.c_res_CBP_EURperkWh = defaultParams.c_res_CBP_USDperkWh * defaultParams.currExch_USDtoEUR;
    defaultParams.c_res_RBP_EURperkWh = defaultParams.c_res_RBP_USDperkWh * defaultParams.currExch_USDtoEUR;

    if nargin == 0 
        overrideParams = struct(); 
    else 
        overrideParams = struct(varargin{:}); 
    end

    paramsOut = mergeStructs(defaultParams, overrideParams);

    % ====== CHEMISTRY-SPECIFIC ADJUSTMENTS ======
    chem        = string(paramsOut.Chemistry);
    V           = paramsOut.V_pack_nom;

    switch chem
        case "LFP"
            chi_mu_perc = 1.54 * log(V) + 1.06;
            if V==800
                bounds = [9.4439, 12.8275];
            else 
                error("Unsupported V_pack_nom for LFP");
            end
        case "NMC"
            chi_mu_perc = 4.06 * log(V) - 1.91;
            if V==800
                bounds = [20.7396, 28.9010];
            else 
                error("Unsupported V_pack_nom for NMC");
            end
        otherwise
            error("Unknown Chemistry: %s", chem);
    end

    if paramsOut.DefaultIndicator
        chi_percent = chi_mu_perc;                       
    else
        chi_value_perc = bounds(1) + (bounds(2)-bounds(1)) * rand; 
        chi_percent    = chi_value_perc;
    end

    paramsOut.Y_RBP = paramsOut.Y_CBP * (1 + chi_percent/100);
end



% -------------------------------------------------------------------------
% MERGESTRUCTS
% -------------------------------------------------------------------------
function paramsOut = mergeStructs(defaultParams, overrideParams)
    paramsOut = defaultParams;                           
    f = fieldnames(overrideParams);
    for i = 1:numel(f)
        paramsOut.(f{i}) = overrideParams.(f{i});        
    end
end



% -------------------------------------------------------------------------
% GETPARAMRANGES
% -------------------------------------------------------------------------
function ranges = getParamRanges()
    ranges.Y_EV.LIMITS                  = [15, 20];
    ranges.r_CBP.LIMITS                 = [0.02, 0.04];
    ranges.alpha_CBP.LIMITS             = [0.01, 0.03];
    ranges.delta_loss.LIMITS            = [0.01, 0.05];
    ranges.L.LIMITS                     = [5000, 70000];
    ranges.nu.LIMITS                    = [0.01, 0.15];
    ranges.E_pack_nom.LIMITS            = [20, 120];
    ranges.E_pack_nom_detailed          = 20:20:120;        
    ranges.n_E                          = numel(ranges.E_pack_nom_detailed);
    ranges.SOH_EOL_SecondLife_CBP.LIMITS  = [0.50, 0.60];
    ranges.SOH_EOL_SecondLife_RBP.LIMITS  = [0.40, 0.50];

    ranges.Chemistry.LIST               = ["LFP", "NMC"];
    ranges.n_chem                       = numel(ranges.Chemistry.LIST);

    assertLimits(ranges.Y_EV.LIMITS, 'Y_EV');
    assertLimits(ranges.r_CBP.LIMITS, 'r_CBP');
    assertLimits(ranges.alpha_CBP.LIMITS, 'alpha_CBP');
    assertLimits(ranges.delta_loss.LIMITS, 'delta_loss');
    assertLimits(ranges.L.LIMITS, 'L');
    assertLimits(ranges.nu.LIMITS, 'nu');
    assertLimits(ranges.E_pack_nom.LIMITS, 'E_pack_nom');
    assertLimits(ranges.SOH_EOL_SecondLife_CBP.LIMITS, 'SOH_EOL_SecondLife_CBP');
    assertLimits(ranges.SOH_EOL_SecondLife_RBP.LIMITS, 'SOH_EOL_SecondLife_RBP');
end



% -------------------------------------------------------------------------
% ASSERTLIMITS
% -------------------------------------------------------------------------
function assertLimits(lim, name)
    if ~(isnumeric(lim) && isvector(lim) && numel(lim)==2 && all(isfinite(lim)))
        error('getParamRanges:InvalidLimits', ...
              'Field "%s.LIMITS" must be a 1x2 finite numeric vector.', name);
    end
    if lim(1) > lim(2)
        error('getParamRanges:LimitsOrder', ...
              'Field "%s.LIMITS" must satisfy min <= max.', name);
    end
end



% -------------------------------------------------------------------------
% COMPUTENPC_DISCANDNONDSC
% -------------------------------------------------------------------------
function results = computeNPC_DiscAndNonDisc(params)
    mustHave(params, {'Y_EV','Y_CBP','Y_RBP','E_pack_nom','c_pack_USDperkWh','currExch_USDtoEUR', ...
                      'c_en_EURperkWh','eta_en_kWhkm','L','r_CBP','r_RBP','alpha_CBP','alpha_RBP', ...
                      'delta_loss','nu','SOH_EOL_FirstLife_CBP','SOH_EOL_FirstLife_RBP', ...
                      'SOH_EOL_SecondLife_CBP','SOH_EOL_SecondLife_RBP','c_res_depreccoeff'});

    Y_EV        = params.Y_EV;
    Y_EV_floor  = floor(Y_EV);
    Y_EV_ceil   = ceil(Y_EV);
    d_Y_EV      = Y_EV - Y_EV_floor;
    Y_EV_array  = 1:1:Y_EV_ceil;

    Cost_Init_CBP = params.E_pack_nom * params.c_pack_USDperkWh * params.currExch_USDtoEUR; 
    Cost_Init_RBP = (1 + params.nu) * Cost_Init_CBP;

    Cost_energy_CBP = params.c_en_EURperkWh * params.eta_en_kWhkm * params.L;             
    Cost_energy_RBP = (1 + params.delta_loss) * Cost_energy_CBP;

    Cost_ResidualValue_CBP = computeResidual_DiscAndNonDisc( ...
        params, ...
        params.Y_CBP, ...
        params.r_CBP, ...
        Cost_Init_CBP, ...
        params.SOH_EOL_FirstLife_CBP, ...
        params.SOH_EOL_SecondLife_CBP);

    Cost_ResidualValue_RBP = computeResidual_DiscAndNonDisc( ...
        params, ...
        params.Y_RBP, ...
        params.r_RBP, ...
        Cost_Init_RBP, ...
        params.SOH_EOL_FirstLife_RBP, ...
        params.SOH_EOL_SecondLife_RBP);

    cbpInputs = struct( ...
        'Y_EV', Y_EV, ...
        'Y_EV_floor', Y_EV_floor, ...
        'd_Y_EV', d_Y_EV, ...
        'Y_battPack', params.Y_CBP, ...
        'initCost', Cost_Init_CBP, ...
        'alphaOM', params.alpha_CBP, ...
        'energyCost', Cost_energy_CBP, ...
        'discountRate', params.r_CBP, ...
        'E_pack_nom', params.E_pack_nom, ...
        'RV_discounted', Cost_ResidualValue_CBP.RV_discounted, ...
        'RV_nondiscounted', Cost_ResidualValue_CBP.RV_nondiscounted, ...
        't_residuals', Cost_ResidualValue_CBP.t_residuals, ...
        'nu', 0); 
    [Cost_Yearly_PerYear_CBP, Cost_Yearly_Total_CBP_d, Cost_Yearly_Total_CBP_nd] = computeAnnualCosts_DiscAndNonDisc(cbpInputs);

    rbpInputs = struct( ...
        'Y_EV', Y_EV, ...
        'Y_EV_floor', Y_EV_floor, ...
        'd_Y_EV', d_Y_EV, ...
        'Y_battPack', params.Y_RBP, ...
        'initCost', Cost_Init_RBP, ...
        'alphaOM', params.alpha_RBP, ...
        'energyCost', Cost_energy_RBP, ...
        'discountRate', params.r_RBP, ...
        'E_pack_nom', params.E_pack_nom, ...
        'RV_discounted', Cost_ResidualValue_RBP.RV_discounted, ...
        'RV_nondiscounted', Cost_ResidualValue_RBP.RV_nondiscounted, ...
        't_residuals', Cost_ResidualValue_RBP.t_residuals, ...
        'nu', params.nu);
    [Cost_Yearly_PerYear_RBP, Cost_Yearly_Total_RBP_d, Cost_Yearly_Total_RBP_nd] = computeAnnualCosts_DiscAndNonDisc(rbpInputs);

    NPC_CBP   = Cost_Init_CBP + Cost_Yearly_Total_CBP_d - Cost_ResidualValue_CBP.RV_total_discounted;
    NPC_RBP   = Cost_Init_RBP + Cost_Yearly_Total_RBP_d - Cost_ResidualValue_RBP.RV_total_discounted;
    delta_NPC = NPC_CBP - NPC_RBP;

    results.years = Y_EV_array;

    results.CBP.costs.InitCost                         = Cost_Init_CBP;
    results.CBP.costs.AnnualCosts.discounted           = Cost_Yearly_PerYear_CBP.discounted;
    results.CBP.costs.AnnualCosts.nondiscounted        = Cost_Yearly_PerYear_CBP.nondiscounted;
    results.CBP.costs.TotalAnnualCosts.discounted      = Cost_Yearly_Total_CBP_d;
    results.CBP.costs.TotalAnnualCosts.nondiscounted   = Cost_Yearly_Total_CBP_nd;
    results.CBP.costs.RV_discounted                    = Cost_ResidualValue_CBP.RV_total_discounted;
    results.CBP.costs.RV_nondiscounted                 = Cost_ResidualValue_CBP.RV_total_nondiscounted;
    results.CBP.costs.NPC                              = NPC_CBP;
    results.CBP.SOH_EOL_Pack                           = Cost_ResidualValue_CBP.SOH_EOL_Pack;
    results.CBP.SOH_residual                           = Cost_ResidualValue_CBP.SOH_residual;
    results.CBP.residualStruct                         = Cost_ResidualValue_CBP;

    results.RBP.costs.InitCost                         = Cost_Init_RBP;
    results.RBP.costs.AnnualCosts.discounted           = Cost_Yearly_PerYear_RBP.discounted;
    results.RBP.costs.AnnualCosts.nondiscounted        = Cost_Yearly_PerYear_RBP.nondiscounted;
    results.RBP.costs.TotalAnnualCosts.discounted      = Cost_Yearly_Total_RBP_d;
    results.RBP.costs.TotalAnnualCosts.nondiscounted   = Cost_Yearly_Total_RBP_nd;
    results.RBP.costs.RV_discounted                    = Cost_ResidualValue_RBP.RV_total_discounted;
    results.RBP.costs.RV_nondiscounted                 = Cost_ResidualValue_RBP.RV_total_nondiscounted;
    results.RBP.costs.NPC                              = NPC_RBP;
    results.RBP.SOH_EOL_Pack                           = Cost_ResidualValue_RBP.SOH_EOL_Pack;
    results.RBP.SOH_residual                           = Cost_ResidualValue_RBP.SOH_residual;
    results.RBP.residualStruct                         = Cost_ResidualValue_RBP;

    results.delta_NPC                                  = delta_NPC;
end



% -------------------------------------------------------------------------
% COMPUTERESIDUAL_DISCANDNONDSC
% -------------------------------------------------------------------------
function output = computeResidual_DiscAndNonDisc(params, Y_battPack, r_battPack, Cost_Init_battPack, SOH_EOL_FirstLife, SOH_EOL_SecondLife)
    mustHave(params, {'Y_EV','E_pack_nom','c_res_depreccoeff'});
    Y_EV  = params.Y_EV;
    E_nom = params.E_pack_nom;

    max_n     = floor(Y_EV / Y_battPack);
    t_replace = Y_battPack * (1:max_n);
    if mod(Y_EV, Y_battPack) > 0 || isempty(t_replace)
        t_replace = [t_replace, Y_EV];
    end

    n_packs      = numel(t_replace);
    t_residuals  = t_replace;

    SOH_EOL_Pack     = zeros(1, n_packs);
    SOH_residual     = zeros(1, n_packs);
    RV_nondiscounted = zeros(1, n_packs);
    RV_discounted    = zeros(1, n_packs);

    for i = 1:n_packs
        if i == 1
            y_elapsed = t_replace(i);
        else
            y_elapsed = t_replace(i) - t_replace(i-1);
        end

        SOH_EOL_Pack(i) = 1 - (y_elapsed / Y_battPack) * (1 - SOH_EOL_FirstLife);

        SOH_residual(i) = (SOH_EOL_Pack(i) - SOH_EOL_SecondLife) / (1 - SOH_EOL_SecondLife);

        if (i == 1)
            RV_nondiscounted(i) = SOH_residual(i) * Cost_Init_battPack * params.c_res_depreccoeff;
            Cost_Init_battPack_new  = getReplCost(t_replace(i), E_nom);
        else
            RV_nondiscounted(i)  = SOH_residual(i) * Cost_Init_battPack_new * params.c_res_depreccoeff;            
        end
        RV_discounted(i)    = RV_nondiscounted(i) / ((1 + r_battPack)^t_replace(i));
    end

    output.RV_total_discounted     = sum(RV_discounted);
    output.RV_total_nondiscounted  = sum(RV_nondiscounted);
    output.RV_discounted           = RV_discounted;
    output.RV_nondiscounted        = RV_nondiscounted;
    output.t_residuals             = t_residuals;
    output.SOH_EOL_Pack            = SOH_EOL_Pack;
    output.SOH_residual            = SOH_residual;
end



% -------------------------------------------------------------------------
% GETREPLCOST
% -------------------------------------------------------------------------
function replCost_EUR = getReplCost(t, E_pack_nom)
    validateattributes(t, {'numeric'}, {'nonempty','real','finite','>=',0}, mfilename, 't', 1);
    validateattributes(E_pack_nom, {'double','single'}, {'scalar','real','finite','>',0}, mfilename, 'E_pack_nom', 2);

    p1   = 172.0648;
    p2   = 0.1420;
    p3   = 63.0950;
    t0   = 2017;
    yr0  = 2025;         
    FX   = 0.8554;       

    year                    = yr0 + t;
    replCost_USDperkWh      = p1 .* exp(-p2 .* (year - t0)) + p3;

    replCost_USD            = replCost_USDperkWh .* E_pack_nom;
    replCost_EUR            = FX .* replCost_USD;
end



% -------------------------------------------------------------------------
% COMPUTEANNUALCOSTS_DISCANDNONDSC
% -------------------------------------------------------------------------
function [costs, totalCost, totalCost_nondiscounted, replacementSchedule] = computeAnnualCosts_DiscAndNonDisc(inputs)
    mustHave(inputs, {'Y_EV','Y_EV_floor','d_Y_EV','Y_battPack','energyCost','alphaOM', ...
                      'discountRate','initCost','E_pack_nom','nu'});

    Y_EV         = inputs.Y_EV;
    Y_EV_floor   = inputs.Y_EV_floor;
    d_Y_EV       = inputs.d_Y_EV;
    Y_battPack   = inputs.Y_battPack;
    energyCost   = inputs.energyCost;
    alphaOM      = inputs.alphaOM;
    discountRate = inputs.discountRate;
    nu           = inputs.nu;
    initCost     = inputs.initCost;
    E_pack_nom   = inputs.E_pack_nom;

    if ((isfield(inputs, 'RV_discounted')) && (isfield(inputs,'RV_nondiscounted')) && (isfield(inputs,'t_residuals')))
        RV_discounted    = inputs.RV_discounted;
        RV_nondiscounted = inputs.RV_nondiscounted;
        t_residuals      = inputs.t_residuals;
        RV_years         = ceil(t_residuals);  
    else
        RV_discounted    = [];
        RV_nondiscounted = [];
        RV_years         = [];
    end

    max_n         = floor(Y_EV / Y_battPack);
    t_replace     = Y_battPack * (1:max_n);
    replacementYears = ceil(t_replace);
    frac_old      = mod(t_replace, 1);
    frac_new      = 1 - frac_old;

    replacementSchedule.t_replace        = t_replace;
    replacementSchedule.replacementYears  = replacementYears;
    replacementSchedule.frac_old          = frac_old;
    replacementSchedule.frac_new          = frac_new;

    Y_max = Y_EV_floor + (d_Y_EV > 0);

    D.energy = zeros(1, Y_max);
    D.oandm = zeros(1, Y_max);
    D.replacement = zeros(1, Y_max);
    D.residual = zeros(1, Y_max);
    ND = D;

    currentCapitalCost = initCost;

    for year = 1:Y_max
        discountFactor = (1 + discountRate)^year;

        if year <= Y_EV_floor
            yearWeight = 1.0;
        else
            yearWeight = d_Y_EV; 
        end
        D.energy(year)  = yearWeight * energyCost / discountFactor;
        ND.energy(year) = yearWeight * energyCost;

        idx_repl = find(replacementYears == year, 1, 'first');
        if (~isempty(idx_repl))
            actualTime = t_replace(idx_repl);                   
            discountFactor_actual = (1 + discountRate)^actualTime;

            newCapitalCost = getReplCost(actualTime, E_pack_nom) * (1 + nu); 

            omCost = yearWeight * ( ...
                frac_old(idx_repl) * alphaOM * currentCapitalCost + ...
                frac_new(idx_repl) * alphaOM * newCapitalCost ...
            );

            D.oandm(year)        = omCost / discountFactor;
            ND.oandm(year)       = omCost;
            D.replacement(year)  = newCapitalCost / discountFactor_actual;
            ND.replacement(year) = newCapitalCost;

            currentCapitalCost = newCapitalCost;
        else
            omCost = yearWeight * alphaOM * currentCapitalCost;
            D.oandm(year)  = omCost / discountFactor;
            ND.oandm(year) = omCost;
        end

        if ~isempty(RV_years)
            idx_rv = find(RV_years == year);
            if (~isempty(idx_rv))
                D.residual(year)  = -sum(RV_discounted(idx_rv));
                ND.residual(year) = -sum(RV_nondiscounted(idx_rv));
            end
        end
    end

    D.totalPerYear  = D.energy + D.oandm + D.replacement + D.residual;
    ND.totalPerYear = ND.energy + ND.oandm + ND.replacement + ND.residual;

    costs.discounted    = D;
    costs.nondiscounted = ND;

    totalCost                = sum(D.totalPerYear);
    totalCost_nondiscounted  = sum(ND.totalPerYear);
end



% -------------------------------------------------------------------------
% SAMPLEDELTANPC_LHS
% -------------------------------------------------------------------------
function [samples_out, delta_NPC_out, results_out, p_out] = sampleDeltaNPC_LHS(ranges, n_samples, params_baseline)
    validateattributes(n_samples, {'numeric'}, {'scalar','integer','>=',1}, mfilename, 'n_samples', 2);
    mustHave(ranges, {'Y_EV','delta_loss','L','nu','r_CBP','alpha_CBP', ...
                      'E_pack_nom','E_pack_nom_detailed','n_E', ...
                      'Chemistry','n_chem', ...
                      'SOH_EOL_SecondLife_CBP','SOH_EOL_SecondLife_RBP'});

    rng(42);
    n_batch = n_samples - 1;
    X = lhsdesign(n_batch, 10); 

    samples_all = struct();

    samples_all.Y_EV       = interp1([0 1], ranges.Y_EV.LIMITS,       X(:,1));
    samples_all.delta_loss = interp1([0 1], ranges.delta_loss.LIMITS, X(:,2));
    samples_all.L          = interp1([0 1], ranges.L.LIMITS,          X(:,3));
    samples_all.nu         = interp1([0 1], ranges.nu.LIMITS,         X(:,4));

    samples_all.r_CBP      = interp1([0 1], ranges.r_CBP.LIMITS,      X(:,5));
    samples_all.r_RBP      = samples_all.r_CBP;

    samples_all.alpha_CBP  = interp1([0 1], ranges.alpha_CBP.LIMITS,  X(:,6));
    samples_all.alpha_RBP  = samples_all.alpha_CBP * 0.5;

    n_E        = ranges.n_E;
    E_indices  = min(ceil(X(:,7) * n_E), n_E);
    samples_all.E_pack_nom = transpose(ranges.E_pack_nom_detailed(E_indices));

    n_chem       = ranges.n_chem;
    chem_indices = min(ceil(X(:,8) * n_chem), n_chem);
    samples_all.Chemistry = transpose(ranges.Chemistry.LIST(chem_indices));

    samples_all.SOH_EOL_SecondLife_CBP = interp1([0 1], ranges.SOH_EOL_SecondLife_CBP.LIMITS, X(:,9));
    samples_all.SOH_EOL_SecondLife_RBP = interp1([0 1], ranges.SOH_EOL_SecondLife_RBP.LIMITS, X(:,10));

    samples_out = samples_all;
    samples_out.DefaultIndicator = false(n_batch, 1);

    fieldnames_list = fieldnames(samples_all);
    for k = 1:numel(fieldnames_list)
        field = fieldnames_list{k};
        samples_out.(field)(n_samples, 1) = params_baseline.(field);
    end
    samples_out.DefaultIndicator(n_samples, 1) = true;

    n_total        = n_samples;
    delta_NPC_out  = zeros(n_total, 1);

    p_first     = getParams(getSampleStruct(samples_out, 1));
    result_first = computeNPC_DiscAndNonDisc(p_first);
    delta_NPC_out(1) = result_first.delta_NPC;

    results_out = repmat(result_first, n_total, 1);
    p_out       = repmat(p_first, n_total, 1);

    for i = 2:n_total
        p_i        = getParams(getSampleStruct(samples_out, i));
        result_i   = computeNPC_DiscAndNonDisc(p_i);
        p_out(i)         = p_i;
        results_out(i)   = result_i;
        delta_NPC_out(i) = result_i.delta_NPC;
    end
end



% -------------------------------------------------------------------------
% GETSAMPLESTRUCT
% -------------------------------------------------------------------------
function s = getSampleStruct(samples_out, i)
    validateattributes(i, {'numeric'}, ...
        {'scalar','integer','>=',1,'<=',numel(samples_out.Y_EV)}, ...
        mfilename, 'i', 2);

    s.Y_EV       = samples_out.Y_EV(i);
    s.alpha_CBP  = samples_out.alpha_CBP(i);
    s.alpha_RBP  = samples_out.alpha_RBP(i);
    s.delta_loss = samples_out.delta_loss(i);
    s.r_CBP      = samples_out.r_CBP(i);
    s.r_RBP      = samples_out.r_RBP(i);
    s.L          = samples_out.L(i);
    s.nu         = samples_out.nu(i);
    s.E_pack_nom = samples_out.E_pack_nom(i);
    s.Chemistry  = samples_out.Chemistry(i);
end



% -------------------------------------------------------------------------
% PLOTANNUALCOSTBREAKDOWN_DISCNONDISC_SUBPLOT
% -------------------------------------------------------------------------
function plotAnnualCostBreakdown_DiscNonDisc_Subplot(ax, results, yLim, yTicks, costType)
    if nargin < 5 || isempty(costType), costType = 'discounted'; end
    costType = validatestring(string(costType), ["discounted","nondiscounted"], mfilename, 'costType', 5);

    if ~isfield(results,'CBP') || ~isfield(results,'RBP') || ~isfield(results,'years')
        error('plotAnnualCost:BadResults','RESULTS must contain .CBP, .RBP, and .years.');
    end

    years     = results.years;
    Y         = numel(years);      
    Y_full    = Y + 1;             
    tickStep  = 1.5;               
    x_base    = tickStep * (0:Y);  
    x_cbp     = x_base - 0.3;
    x_rbp     = x_base + 0.3;

    cbpCosts = results.CBP.costs.AnnualCosts.(costType);
    rbpCosts = results.RBP.costs.AnnualCosts.(costType);

    CBP_e       = [0, cbpCosts.energy]        / 1000;
    CBP_m       = [0, cbpCosts.oandm]         / 1000;
    CBP_upfront = zeros(1, Y_full);  CBP_upfront(1) = results.CBP.costs.InitCost / 1000;
    CBP_r       = [0, cbpCosts.replacement]   / 1000;
    CBP_res     = [0, cbpCosts.residual]      / 1000;

    RBP_e       = [0, rbpCosts.energy]        / 1000;
    RBP_m       = [0, rbpCosts.oandm]         / 1000;
    RBP_upfront = zeros(1, Y_full);  RBP_upfront(1) = results.RBP.costs.InitCost / 1000;
    RBP_r       = [0, rbpCosts.replacement]   / 1000;
    RBP_res     = [0, rbpCosts.residual]      / 1000;

    data_cbp = [CBP_e', CBP_m', CBP_upfront', CBP_r', CBP_res'];
    data_rbp = [RBP_e', RBP_m', RBP_upfront', RBP_r', RBP_res'];

    axes(ax); 
    hold(ax,'on');

    b_cbp = bar(ax, x_cbp, data_cbp, 0.4, 'stacked');
    b_rbp = bar(ax, x_rbp, data_rbp, 0.4, 'stacked');

    % Colour-blind-safe palette following Wong (2011, Nature Methods).
    % CBP components: blue family. RBP components: orange/vermillion family.
    % No red-green combinations are used.
    cbp_colors = [ ...
         86  180  233;   ...  % CBP Energy      — sky blue
          0  114  178;   ...  % CBP O&M         — blue
          0   60  120;   ...  % CBP Upfront     — dark blue
        204  121  167;   ...  % CBP Replacement — reddish purple
        230  210  225] / 255; % CBP Residual    — light reddish purple

    rbp_colors = [ ...
        240  200  100;   ...  % RBP Energy      — light orange
        230  159    0;   ...  % RBP O&M         — orange
        160  100    0;   ...  % RBP Upfront     — dark orange
          0  158  115;   ...  % RBP Replacement — bluish green
        160  220  200] / 255; % RBP Residual    — light bluish green

    for j = 1:5
        b_cbp(j).FaceColor = cbp_colors(j,:);  b_cbp(j).EdgeColor = 'none';
        b_rbp(j).FaceColor = rbp_colors(j,:);  b_rbp(j).EdgeColor = 'none';
        b_rbp(j).FaceAlpha = 0.7;
    end

    if exist('yLim','var') && ~isempty(yLim), ylim(ax, yLim); end
    if exist('yTicks','var') && ~isempty(yTicks), yticks(ax, yTicks); end

    ylabel(ax, 'Cost [kEUR]', 'Interpreter','tex', 'FontName','Helvetica','FontSize',7);
    xticks(ax, tickStep * (0:5:20));
    xticklabels(ax, string(0:5:20));
    xlabel(ax, 'Year', 'Interpreter','tex', 'FontName','Helvetica','FontSize',7);
    grid(ax,'on'); box(ax,'on');
    set(ax, 'FontSize',7, 'TickLabelInterpreter','tex', 'FontName','Helvetica');

    handles = [ ...
        b_cbp(3), b_cbp(1), b_cbp(2), b_cbp(4), b_cbp(5), ...
        b_rbp(3), b_rbp(1), b_rbp(2), b_rbp(4), b_rbp(5) ];

    labels = { ...
        'CBP Upfront','CBP Energy','CBP O&M','CBP Replacement','CBP Residual', ...
        'RBP Upfront','RBP Energy','RBP O&M','RBP Replacement','RBP Residual' };

    lgd = safeLegend(ax, handles, labels, ...
        'Orientation','horizontal', 'Location','northeast', ...
        'FontSize',7, 'Interpreter','tex');
    lgd.NumColumns    = 5;
    lgd.ItemTokenSize = [10 6];

    hold(ax,'off');
end



% -------------------------------------------------------------------------
% ADDPANELLABEL
% -------------------------------------------------------------------------
function addPanelLabel(ax, label, offsetX, offsetY, fontSize)
    if nargin < 3 || isempty(offsetX), offsetX = -0.12; end
    if nargin < 4 || isempty(offsetY), offsetY = 1.02;  end
    if nargin < 5 || isempty(fontSize), fontSize = 7;  end

    text(ax, offsetX, offsetY, label, ...
        'Units', 'normalized', ...
        'FontSize', fontSize, ...
        'FontWeight', 'bold', ...
        'Interpreter', 'tex', ...
        'FontName', 'Helvetica', ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top');
end



% -------------------------------------------------------------------------
% PLOTCUMULATIVENPC_DISCNONDISC_SUBPLOT
% -------------------------------------------------------------------------
function plotCumulativeNPC_DiscNonDisc_Subplot(ax, results, yLabelOn, legendOn, legendLocation, label1, deltaNPC, yLim, yTicks, costType)
    if nargin < 10 || isempty(costType), costType = 'discounted'; end
    costType = validatestring(string(costType), ["discounted","nondiscounted"], mfilename, 'costType', 10);

    years      = results.years;
    Y          = numel(years);
    Y_full     = Y + 1;
    years_full = [0, years];
    tick_spacing = 1.5;
    x_base     = tick_spacing * (0:Y);  

    cbp = results.CBP.costs.AnnualCosts.(costType);
    rbp = results.RBP.costs.AnnualCosts.(costType);

    CBP_e   = [0, cbp.energy];
    CBP_m   = [0, cbp.oandm];
    CBP_r   = [results.CBP.costs.InitCost, cbp.replacement];
    CBP_res = [0, cbp.residual];

    RBP_e   = [0, rbp.energy];
    RBP_m   = [0, rbp.oandm];
    RBP_r   = [results.RBP.costs.InitCost, rbp.replacement];
    RBP_res = [0, rbp.residual];

    CBP_total = CBP_e + CBP_m + CBP_r + CBP_res;
    RBP_total = RBP_e + RBP_m + RBP_r + RBP_res;

    cum_CBP = cumsum(CBP_total) / 1000;
    cum_RBP = cumsum(RBP_total) / 1000;

    delta_curve = cum_CBP - cum_RBP;

    sgn = sign(delta_curve);
    idx_cross = find(diff(sgn) ~= 0, 1, 'last');

    axes(ax); 
    hold(ax,'on');

    % Colour-blind-safe palette following Wong (2011, Nature Methods).
    % CBP: blue family; RBP: orange/vermillion family.
    col_CBP_light = [86,  180, 233] / 255;   % sky blue
    col_CBP       = [0,   114, 178] / 255;   % blue
    col_RBP_light = [230, 159,   0] / 255;   % orange
    col_RBP       = [213,  94,   0] / 255;   % vermillion
    col_breakeven = [204, 121, 167] / 255;   % reddish purple

    hCBP = plot(ax, x_base, cum_CBP, '-', 'LineWidth', 2, 'Color', col_CBP_light);
    hRBP = plot(ax, x_base, cum_RBP, '-', 'LineWidth', 2, 'Color', col_RBP_light);

    hFinalCBP = plot(ax, x_base(end), cum_CBP(end), '*', 'MarkerSize', 10, 'LineWidth', 1, 'Color', col_CBP);
    hFinalRBP = plot(ax, x_base(end), cum_RBP(end), '*', 'MarkerSize', 10, 'LineWidth', 1, 'Color', col_RBP);

    haveBreakEven = ~isempty(idx_cross) && idx_cross < Y_full;
    if haveBreakEven
        x1 = years_full(idx_cross);   x2 = years_full(idx_cross+1);
        y1 = delta_curve(idx_cross);  y2 = delta_curve(idx_cross+1);
        if y2 ~= y1
            year_be = x1 - y1*(x2 - x1)/(y2 - y1); 
            t_query = year_be * tick_spacing;
            CBP_be  = interp1(years_full*tick_spacing, cum_CBP, t_query, 'linear', 'extrap');
            hBE1 = plot(ax, t_query, CBP_be, 'x', 'MarkerSize', 10, 'LineWidth', 2, 'Color', col_breakeven, 'DisplayName', 'Break-even');
        else
            haveBreakEven = false;
        end
    end

    if yLabelOn
        ylabel(ax, 'NPC [kEUR]', 'Interpreter','tex', 'FontName','Helvetica','FontSize',7);
    end
    xlabel(ax, 'Year', 'Interpreter','tex', 'FontName','Helvetica','FontSize',7);
    xlim(ax, tick_spacing*[0 20]);
    xticks(ax, tick_spacing*(0:5:20));
    xticklabels(ax, string(0:5:20));
    if exist('yLim','var') && ~isempty(yLim),   ylim(ax, yLim);   end
    if exist('yTicks','var') && ~isempty(yTicks), yticks(ax, yTicks); end
    grid(ax,'on'); box(ax,'on');
    set(ax, 'FontSize',7, 'TickLabelInterpreter','tex', 'FontName','Helvetica');

    if legendOn
        legHandles = [hCBP, hRBP, hFinalCBP, hFinalRBP];
        legLabels  = {'CBP','RBP','Final CBP','Final RBP'};
        if haveBreakEven
            legHandles(end+1) = hBE1;
            legLabels{end+1}  = 'Break-even';
        end        
        lgd = safeLegend(ax, legHandles, legLabels, ...
            'Location', legendLocation, ...
            'Interpreter','tex', 'FontSize',7);
        lgd.ItemTokenSize = [10, 4];
    end

    if nargin >= 6 && ~isempty(label1) && ~isempty(deltaNPC)
        if exist('year_be','var') == 1 && haveBreakEven
            breakEvenStr = sprintf('%.1f', year_be);
        else
            breakEvenStr = '--';
        end
    
        deltaNPCStr = sprintf('%.0f', deltaNPC);
    
        label_text = sprintf('\\bf%s\\rm scenario\nΔNPC: %s EUR\nBreak-even: %s years', ...
                             label1, deltaNPCStr, breakEvenStr);
    
        text(ax, 0.98, 0.02, label_text, ...
             'Units','normalized', ...
             'Interpreter','tex', ...
             'FontSize',7, ...
             'HorizontalAlignment','right', ...
             'VerticalAlignment','bottom', ...
             'FontName','Helvetica');
    end

    hold(ax,'off');
end



% -------------------------------------------------------------------------
% TORNADOPLOTDELTANPC_SUBPLOT
% -------------------------------------------------------------------------
function sorted_corrs = tornadoPlotDeltaNPC_Subplot(ax, samples, delta_NPC_kEuros)
    req = {'Y_EV','alpha_CBP','alpha_RBP','delta_loss','nu','L','r_CBP','E_pack_nom'};
    for k = 1:numel(req)
        if ~isfield(samples, req{k})
            error('tornadoPlot:MissingField','SAMPLES missing field "%s".', req{k});
        end
    end
    y = delta_NPC_kEuros(:);
    n = numel(y);

    for k = 1:numel(req)
        v = samples.(req{k});
        if ~isvector(v) || numel(v) ~= n
            error('tornadoPlot:SizeMismatch','Field "%s" must be a vector of length %d.', req{k}, n);
        end
    end

    factors = {'Y_{{EV}}', ...
               '\Delta\alpha', ...
               '\delta_{{loss}}', ...
               '\nu', ...
               'L', ...
               'r', ...
               'E_{pack}^{nom}'};  

    alpha_diff = samples.alpha_CBP(:) - samples.alpha_RBP(:);

    X = [ samples.Y_EV(:), ...
          alpha_diff, ...
          samples.delta_loss(:), ...
          samples.nu(:), ...
          samples.L(:), ...
          samples.r_CBP(:), ...
          samples.E_pack_nom(:) ];

    corrs = corr(X, y, 'Type','Spearman', 'Rows','pairwise');

    [sorted_corrs, idx] = sort(abs(corrs), 'descend'); 
    corrs_sorted = corrs(idx);
    factors_sorted = factors(idx);

    axes(ax); 
    cla(ax); hold(ax, 'on');

    x_pos = 1:numel(factors_sorted);
    % Colour-blind-safe palette following Wong (2011, Nature Methods).
    col_bar = [0, 114, 178] / 255;   % WongBlue
    bar(ax, x_pos, corrs_sorted, 0.6, 'FaceColor', col_bar, 'EdgeColor','none');

    plot(ax, [0.5, numel(factors_sorted)+0.5], [0 0], '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.75);

    ylabel(ax, '\rho [-]', 'Interpreter','tex', 'FontName','Helvetica','FontSize',7);
    xticks(ax, x_pos);
    xticklabels(ax, factors_sorted);
    yticks(ax, -1.0:0.5:1.0);
    ylim(ax, [-1.0 1.0]);
    xlim(ax, [0.5, numel(factors_sorted)+0.5]);

    grid(ax, 'on'); box(ax, 'on');
    set(ax, 'FontSize', 7, ...
            'FontName', 'Helvetica', ...
            'TickLabelInterpreter', 'tex', ...
            'LabelFontSizeMultiplier', 1);

    for i = 1:numel(corrs_sorted)
        val = corrs_sorted(i);
        if val >= 0
            y_offset = 0.02;  va = 'bottom';
        else
            y_offset = -0.02; va = 'top';
        end
        text(ax, x_pos(i), val + y_offset, sprintf('%.2f', val), ...
            'HorizontalAlignment','center', 'VerticalAlignment',va, ...
            'FontSize', 7, 'Interpreter','tex');
    end

    hold(ax, 'off');
end



% -------------------------------------------------------------------------
% PLOTSENSITIVITY1D_NOPERC_SUBPLOT
% -------------------------------------------------------------------------
function [x_zero, R_squared, RMSE] = plotSensitivity1D_NoPerc_Subplot(ax, x, y, xLabel, xlims, xticks, ylims, yticks, idxBest, idxBaseline, idxWorst, dotSize, legendLocation)
    x = x(:); y = y(:);
    mask = isfinite(x) & isfinite(y);
    x = x(mask); y = y(mask);
    if numel(x) < 3
        error('plot1D:TooFewPoints','Need at least 3 finite points for regression.');
    end

    % Colour-blind-safe palette following Wong (2011, Nature Methods).
    col_samples   = [86,  180, 233] / 255;   % sky blue   — scatter points
    col_fit       = [0,     0,   0] / 255;   % black      — regression line
    col_breakeven = [204, 121, 167] / 255;   % reddish purple — break-even marker
    col_best      = [0,   158, 115] / 255;   % bluish green   — best scenario
    col_baseline  = [0,   114, 178] / 255;   % blue           — baseline scenario
    col_worst     = [213,  94,   0] / 255;   % vermillion     — worst scenario

    axes(ax); 
    hold(ax, 'on');
    % Plot only a deterministic subset of the sample cloud.
    % The regression below still uses the full x,y vectors.
    plotIdx = deterministicPlotSubset(numel(x), 12000, 42);
    scatter(ax, x(plotIdx), y(plotIdx), dotSize, col_samples, 'filled');

    if range(x) < max(1e-9, 1e-6*max(abs(x)))
        x_fit = [min(x) max(x)];
        y_fit = [mean(y) mean(y)];
        x_zero = NaN;
        R_squared = NaN;
        RMSE = NaN;
        plot(ax, x_fit, y_fit, '-', 'LineWidth', 2, 'Color', col_fit);
    else
        p = polyfit(x, y, 1);                 
        x_fit = linspace(min(x), max(x), 200);
        y_fit = polyval(p, x_fit);
        plot(ax, x_fit, y_fit, '-', 'LineWidth', 2, 'Color', col_fit);

        y_pred = polyval(p, x);
        SS_res = sum((y - y_pred).^2);
        SS_tot = sum((y - mean(y)).^2);
        if SS_tot > 0
            R_squared = 1 - SS_res/SS_tot;
        else
            R_squared = NaN;
        end
        RMSE = sqrt(mean((y - y_pred).^2));

        if abs(p(1)) > eps
            x_zero = -p(2)/p(1);
        else
            x_zero = NaN;
        end

        if isfinite(x_zero) && (isempty(xlims) || (x_zero >= min(xlims) && x_zero <= max(xlims)))
            plot(ax, x_zero, 0, 'x', 'MarkerSize', 10, 'LineWidth', 2, 'Color', col_breakeven);
        end
    end

    idxAll = find(mask);
    ib = idxAll(idxBest);    
    ibl = idxAll(idxBaseline);
    iw = idxAll(idxWorst);

    hBest = []; hBase = []; hWorst = [];
    if ib >= 1 && ib <= numel(x)
        hBest  = plot(ax, x(ib),  y(ib),  '*', 'MarkerSize', 10, 'LineWidth', 1, 'Color', col_best);
    end
    if ibl >= 1 && ibl <= numel(x)
        hBase  = plot(ax, x(ibl), y(ibl), '*', 'MarkerSize', 10, 'LineWidth', 1, 'Color', col_baseline);
    end
    if iw >= 1 && iw <= numel(x)
        hWorst = plot(ax, x(iw),  y(iw),  '*', 'MarkerSize', 10, 'LineWidth', 1, 'Color', col_worst);
    end

    xlabel(ax, xLabel, 'Interpreter','tex', 'FontName','Helvetica','FontSize',7);
    ylabel(ax, '\DeltaNPC [kEUR]', 'Interpreter','tex', 'FontName','Helvetica','FontSize',7);

    if isempty(xlims), xlims = [min(x) max(x)]; end
    xlim(ax, xlims);
    if ~isempty(xticks), set(ax, 'XTick', xticks); end

    if isempty(ylims), ylims = [min(y) max(y)]; end
    ylim(ax, ylims);
    if ~isempty(yticks), set(ax, 'YTick', yticks); end

    grid(ax, 'on'); box(ax, 'on');
    set(ax, 'FontSize', 7, 'FontName', 'Helvetica', ...
        'TickLabelInterpreter', 'tex', 'LabelFontSizeMultiplier', 1);

    if ~exist('legendLocation','var') || isempty(legendLocation)
        legendLocation = "best";
    end

    hSamples   = findobj(ax, 'Type', 'scatter', '-depth', 1);
    hFit       = findobj(ax, 'Type', 'line', '-and', 'Color', col_fit, '-depth', 1);
    hBreakEven = findobj(ax, 'Type', 'line', '-and', 'Color', col_breakeven, '-and', 'Marker', 'x', '-depth', 1);

    handles = [hSamples(1), hFit(1)];
    labels  = {'Samples', 'Best-fit line'};
    if ~isempty(hBreakEven), handles(end+1) = hBreakEven(1); labels{end+1} = 'Break-even'; end
    if ~isempty(hBest),      handles(end+1) = hBest(1);      labels{end+1} = 'Best';       end
    if ~isempty(hBase),      handles(end+1) = hBase(1);      labels{end+1} = 'Baseline';   end
    if ~isempty(hWorst),     handles(end+1) = hWorst(1);     labels{end+1} = 'Worst';      end

    lgd = safeLegend(ax, handles, labels, 'Location', legendLocation, ...
        'FontSize', 7, 'Interpreter','tex', 'NumColumns', 2);
    lgd.ItemTokenSize = [10, 4];

    hold(ax, 'off');
end



% -------------------------------------------------------------------------
% PLOT1DWITHREGRESSION_SUBPLOT
% -------------------------------------------------------------------------
function [x_zero, R_squared, RMSE] = plot1DWithRegression_Subplot(ax, x, y, xLabel, xlims, xticks, ylims, yticks, idxBest, idxBaseline, idxWorst, dotSize)
    x = x(:); y = y(:);
    mask = isfinite(x) & isfinite(y);
    x = x(mask); y = y(mask);
    if numel(x) < 3
        error('plot1DReg:TooFewPoints','Need at least 3 finite points for regression.');
    end

    % Colour-blind-safe palette following Wong (2011, Nature Methods).
    col_samples   = [86,  180, 233] / 255;   % sky blue       — scatter points
    col_fit       = [0,     0,   0] / 255;   % black          — regression line
    col_breakeven = [204, 121, 167] / 255;   % reddish purple — break-even marker
    col_best      = [0,   158, 115] / 255;   % bluish green   — best scenario
    col_baseline  = [0,   114, 178] / 255;   % blue           — baseline scenario
    col_worst     = [213,  94,   0] / 255;   % vermillion     — worst scenario

    nearConstX = range(x) < max(1e-9, 1e-6*max(abs(x)));
    axes(ax); 
    cla(ax); hold(ax,'on');

    % Plot only a deterministic subset of the sample cloud.
    % The regression below still uses the full x,y vectors.
    plotIdx = deterministicPlotSubset(numel(x), 12000, 43);
    scatter(ax, 100*x(plotIdx), y(plotIdx), dotSize, col_samples, 'filled'); 

    if nearConstX
        x_fit = linspace(min(x), max(x), 2);
        y_fit = [mean(y) mean(y)];
        plot(ax, 100*x_fit, y_fit, '-', 'LineWidth', 2, 'Color', col_fit);
        x_zero   = NaN;
        R_squared = NaN;
        RMSE      = sqrt(mean((y - mean(y)).^2));
    else
        p    = polyfit(x, y, 1);               
        x_fit = linspace(min(x), max(x), 200);
        y_fit = polyval(p, x_fit);
        plot(ax, 100*x_fit, y_fit, '-', 'LineWidth', 2, 'Color', col_fit);

        y_pred  = polyval(p, x);
        SS_res  = sum((y - y_pred).^2);
        SS_tot  = sum((y - mean(y)).^2);
        R_squared = 1 - SS_res / SS_tot;
        RMSE      = sqrt(mean((y - y_pred).^2));

        if abs(p(1)) > eps
            x_zero = -p(2)/p(1);   
            if isempty(xlims) || (100*x_zero >= min(xlims) && 100*x_zero <= max(xlims))
                plot(ax, 100*x_zero, 0, 'x', 'MarkerSize', 10, 'LineWidth', 2, 'Color', col_breakeven);
            end
        else
            x_zero = NaN;
        end
    end

    idxAll = find(mask);
    iBase = idxAll(idxBaseline);
    iWorst = idxAll(idxWorst);

    if idxBest <= numel(x), plot(ax, 100*x(idxBest), y(idxBest), '*', 'MarkerSize', 10, 'LineWidth', 1, 'Color', col_best);     end
    if iBase  <= numel(x),  plot(ax, 100*x(iBase),   y(iBase),   '*', 'MarkerSize', 10, 'LineWidth', 1, 'Color', col_baseline); end
    if iWorst <= numel(x),  plot(ax, 100*x(iWorst),  y(iWorst),  '*', 'MarkerSize', 10, 'LineWidth', 1, 'Color', col_worst);    end

    xlabel(ax, xLabel, 'Interpreter','tex', 'FontName','Helvetica','FontSize',7);
    ylabel(ax, '\DeltaNPC [kEUR]', 'Interpreter','tex', 'FontName','Helvetica','FontSize',7);

    if isempty(xlims), xlims = [100*min(x) 100*max(x)]; end
    xlim(ax, xlims);
    if ~isempty(xticks), set(ax, 'XTick', xticks); end

    if isempty(ylims), ylims = [min(y) max(y)]; end
    ylim(ax, ylims);
    if ~isempty(yticks), set(ax, 'YTick', yticks); end

    grid(ax,'on'); box(ax,'on');
    set(ax, 'FontSize', 7, 'FontName', 'Helvetica', ...
        'TickLabelInterpreter','tex', 'LabelFontSizeMultiplier',1);

    lgd = safeLegend(ax, {'Samples','Best-fit line','Break-even','Best','Baseline','Worst'}, ...
        'Location','best', 'FontSize',7, 'Interpreter','tex', 'NumColumns',2);
    lgd.ItemTokenSize = [10, 4];

    hold(ax,'off');
end



% -------------------------------------------------------------------------
% PLOTCHEMISTRYBOXSCATTERWITHRECTANGLE_MODIFIED_SUBPLOT_V2
% -------------------------------------------------------------------------
function [nu_best, L_best] = ...
    plotChemistryBoxScatterWithRectangle_Modified_Subplot_v2 ...
        (axChemPlot, axRectPlot, samples, delta_NPC, ...
         rect_bounds, ylims_Main, yticks_Main, feasible, successThreshold, dotSize, ...
         xLim_axRectPlot, xTicks_axRectPlot, yLim_axRectPlot, yTicks_axRectPlot)

    delta_NPC_k = delta_NPC(:) / 1000;      
    nu = samples.nu(:);
    L  = samples.L(:);
    feasible = logical(feasible(:));

    is_LFP = (samples.Chemistry(:) == "LFP");
    is_NMC = (samples.Chemistry(:) == "NMC");

    nu_bounds = rect_bounds(1,:);
    L_bounds  = rect_bounds(2,:);
    nu_min = nu_bounds(1); nu_max = nu_bounds(2);
    L_min  = L_bounds(1);  L_max  = L_bounds(2);

    idx_safe = feasible & ...
               (nu >= nu_min) & (nu <= nu_max) & ...
               (L  >= L_min ) & (L  <= L_max );

    nu_safe   = nu(idx_safe);
    L_safe    = L(idx_safe);
    dNPC_safe = delta_NPC(idx_safe);     
    success   = dNPC_safe > 0;           

    % Normalize to [0,1] within bounds, like S3
    x_min = nu_bounds(1); x_max = nu_bounds(2); x_rng = max(eps, x_max - x_min);
    y_min = L_bounds(1);  y_max = L_bounds(2);  y_rng = max(eps, y_max - y_min);

    xn = (nu_safe - x_min)/x_rng;  xn = min(max(xn,0),1);
    yn = (L_safe  - y_min)/y_rng;  yn = min(max(yn,0),1);

    % Same binning as S3
    B = 100;
    edges = linspace(0,1,B+1);
    ix = discretize(xn, edges); ix(isnan(ix)) = B;
    iy = discretize(yn, edges); iy(isnan(iy)) = B;

    % Integral images (counts and successes)
    H  = accumarray([ix,iy], 1,                  [B B], @sum, 0, true);
    Hs = accumarray([ix,iy], double(success),    [B B], @sum, 0, true);
    Cum  = cumsum(cumsum(H ,1),2);
    CumS = cumsum(cumsum(Hs,1),2);

    valid = Cum > 0;
    SuccRate = zeros(B,B); 
    SuccRate(valid) = CumS(valid) ./ Cum(valid);

    % Normalized area at each upper-right grid corner
    gx = edges(2:end); gy = gx;
    Area = (gx(:) * gy(:).');   % BxB

    % Pick the largest-area rectangle among those meeting the threshold;
    % if none meet it, fall back to the best success rate (break ties by area)
    mask = SuccRate >= successThreshold & valid;
    if any(mask(:))
        [~, rel] = max(Area(mask)); 
        idxs = find(mask); bestLin = idxs(rel);
    else
        [~, bestLin] = max(SuccRate(:) + 1e-12*Area(:));
    end
    [i_best, j_best] = ind2sub([B B], bestLin);

    % Convert back to original units (exactly as S3 does)
    nu_best = x_min + gx(i_best) * x_rng;
    L_best  = y_min + gy(j_best) * y_rng;

    % Colour-blind-safe palette following Wong (2011, Nature Methods).
    % Success/fail scatter: sky blue / vermillion (no red-green).
    % Chemistry boxplots:
    %   LFP all samples : blue;     LFP domain (D): sky blue
    %   NMC all samples : vermillion; NMC domain (D): orange
    col_success  = [86,  180, 233] / 255;   % sky blue
    col_fail     = [213,  94,   0] / 255;   % vermillion
    col_LFP      = [0,   114, 178] / 255;   % blue
    col_LFP_dom  = [86,  180, 233] / 255;   % sky blue
    col_NMC      = [213,  94,   0] / 255;   % vermillion
    col_NMC_dom  = [230, 159,   0] / 255;   % orange

    axes(axRectPlot); cla(axRectPlot); hold(axRectPlot,'on');

    % Plot only a deterministic subset of the design-space cloud.
    % The success-threshold rectangle above is still computed from all safe samples.
    plotIdx = deterministicPlotSubset(numel(nu_safe), 12000, 44);
    nu_plot      = nu_safe(plotIdx);
    L_plot       = L_safe(plotIdx);
    success_plot = success(plotIdx);

    hSucc = scatter(axRectPlot, 100*nu_plot(success_plot),  L_plot(success_plot),  dotSize, col_success, 'filled');
    hFail = scatter(axRectPlot, 100*nu_plot(~success_plot), L_plot(~success_plot), dotSize, col_fail,    'filled');
    hRect = gobjects(1);
    
    if isfinite(nu_best) && isfinite(L_best)
        x_rect = [nu_min, nu_best, nu_best, nu_min, nu_min]*100;
        y_rect = [L_min,  L_min,  L_best,  L_best,  L_min];
    
        hRect = patch(axRectPlot, ...
            'XData', x_rect, ...
            'YData', y_rect, ...
            'FaceColor','none', ...
            'EdgeColor','k', ...
            'LineWidth',2, ...
            'LineStyle','-', ...
            'DisplayName','D');
    end    

    xlabel(axRectPlot, '\nu [%]', 'Interpreter','tex','FontSize',7);
    ylabel(axRectPlot, 'L [km]', 'Interpreter','tex','FontSize',7);
    xlim(axRectPlot, xLim_axRectPlot);
    xticks(axRectPlot, xTicks_axRectPlot);
    ylim(axRectPlot, yLim_axRectPlot);
    yticks(axRectPlot, yTicks_axRectPlot);
    grid(axRectPlot,'on'); box(axRectPlot,'on');
    set(axRectPlot, 'FontSize',7, 'FontName','Helvetica', 'TickLabelInterpreter','tex');

    legHandles = [hSucc, hFail];
    legLabels  = {'\DeltaNPC > 0', '\DeltaNPC < 0'};
    
    if isgraphics(hRect)
        legHandles = [legHandles, hRect];
        legLabels  = [legLabels, {'\bfD\rm'}];
    end
    
    lgd2 = safeLegend(axRectPlot, legHandles, legLabels, ...
        'Interpreter','tex', ...
        'Location','north', ...
        'FontSize',7, ...
        'NumColumns',2);
    
    lgd2.FontName = 'Helvetica';
    lgd2.ItemTokenSize = [10, 4];    

    hold(axRectPlot,'off');

    axes(axChemPlot); cla(axChemPlot); hold(axChemPlot,'on'); rng(42); jitter = 0.05;

    dNPC_LFP_feas = delta_NPC_k(is_LFP & feasible);
    dNPC_NMC_feas = delta_NPC_k(is_NMC & feasible);

    if isfinite(nu_best) && isfinite(L_best)
        in_dom_rect = feasible & (nu <= nu_best) & (L <= L_best);
        dNPC_LFP_dom = delta_NPC_k(is_LFP & in_dom_rect);
        dNPC_NMC_dom = delta_NPC_k(is_NMC & in_dom_rect);
    else
        dNPC_LFP_dom = []; dNPC_NMC_dom = [];
    end

    scatterPoints_subplot(axChemPlot, 0.6, dNPC_LFP_feas, col_LFP,     jitter);
    scatterPoints_subplot(axChemPlot, 1.4, dNPC_LFP_dom,  col_LFP_dom, jitter);
    h1 = boxchart(axChemPlot, 0.6*ones(size(dNPC_LFP_feas)), dNPC_LFP_feas, ...
                  'BoxFaceAlpha', 0.5, 'BoxFaceColor', col_LFP,     'HandleVisibility', 'off');
    h2 = boxchart(axChemPlot, 1.4*ones(size(dNPC_LFP_dom)),  dNPC_LFP_dom, ...
                  'BoxFaceAlpha', 0.5, 'BoxFaceColor', col_LFP_dom, 'HandleVisibility', 'off'); 
    h1.JitterOutliers='on'; h1.MarkerStyle='none';
    h2.JitterOutliers='on'; h2.MarkerStyle='none';

    scatterPoints_subplot(axChemPlot, 2.1, dNPC_NMC_feas, col_NMC,     jitter);
    scatterPoints_subplot(axChemPlot, 2.9, dNPC_NMC_dom,  col_NMC_dom, jitter);
    h3 = boxchart(axChemPlot, 2.1*ones(size(dNPC_NMC_feas)), dNPC_NMC_feas, ...
                  'BoxFaceAlpha', 0.5, 'BoxFaceColor', col_NMC,     'HandleVisibility', 'off');
    h4 = boxchart(axChemPlot, 2.9*ones(size(dNPC_NMC_dom)),  dNPC_NMC_dom, ...
                  'BoxFaceAlpha', 0.5, 'BoxFaceColor', col_NMC_dom, 'HandleVisibility', 'off'); 
    h3.JitterOutliers='on'; h3.MarkerStyle='none';
    h4.JitterOutliers='on'; h4.MarkerStyle='none';

    xlabel(axChemPlot, 'Chemistry', 'Interpreter','tex','FontSize',7);
    ylabel(axChemPlot, '\DeltaNPC [kEUR]', 'Interpreter','tex','FontSize',7);
    xlim(axChemPlot, [0 3.5]); ylim(axChemPlot, ylims_Main);
    set(axChemPlot, 'YTick', yticks_Main);
    grid(axChemPlot,'on'); box(axChemPlot,'on');
    lg = safeLegend(axChemPlot, {'LFP','LFP (\bfD\rm)','NMC','NMC (\bfD\rm)'}, ...
           'FontSize',7,'Interpreter','tex','Location','north','NumColumns',2);
    lg.ItemTokenSize = [10,4];
    set(axChemPlot, 'FontSize',7, 'FontName','Helvetica', 'TickLabelInterpreter','tex');
    set(axChemPlot, 'XTick', []);

    if ~isempty(dNPC_LFP_dom)
        med_LFP_dom = median(dNPC_LFP_dom);
        edgeColor   = col_LFP_dom;
        bgColor     = edgeColor + (1 - edgeColor)*0.5;
        text(axChemPlot, 1.4-0.02, ylims_Main(1) + 0.18*range(ylims_Main), ...
            sprintf('Median:\n%.0f EUR', med_LFP_dom*1000), ...
            'HorizontalAlignment','center','VerticalAlignment','top', ...
            'FontSize',7,'Color','black','Interpreter','tex', ...
            'EdgeColor',edgeColor,'BackgroundColor',bgColor,'Margin',1);
    end
    if ~isempty(dNPC_NMC_dom)
        med_NMC_dom = median(dNPC_NMC_dom);
        edgeColor   = col_NMC_dom;
        bgColor     = edgeColor + (1 - edgeColor)*0.5;
        text(axChemPlot, 2.9-0.02, ylims_Main(1) + 0.18*range(ylims_Main), ...
            sprintf('Median:\n%.0f EUR', med_NMC_dom*1000), ...
            'HorizontalAlignment','center','VerticalAlignment','top', ...
            'FontSize',7,'Color','black','Interpreter','tex', ...
            'EdgeColor',edgeColor,'BackgroundColor',bgColor,'Margin',1);
    end

    hold(axChemPlot,'off');
end



% -------------------------------------------------------------------------
% SCATTERPOINTS_SUBPLOT
% -------------------------------------------------------------------------
function scatterPoints_subplot(ax, xpos, ydata, color, jitter)
    axes(ax);

    % The chemistry panel can contain tens of thousands of points per group.
    % Draw a deterministic subset only; the boxchart and medians are still
    % computed from the full ydata vectors by the caller.
    ydata = ydata(:);
    plotIdx = deterministicPlotSubset(numel(ydata), 2500, 45 + round(100*xpos));
    yplot = ydata(plotIdx);

    % Make the jitter reproducible without disturbing the caller's RNG state.
    rngState = rng;
    cleanupObj = onCleanup(@() rng(rngState)); 
    rng(1000 + round(100*xpos));

    xj = xpos + (rand(size(yplot)) - 0.5) * jitter;
    scatter(ax, xj, yplot, 8, color, 'filled');
end



% -------------------------------------------------------------------------
% POSITIONFIGUREONMONITOR
% -------------------------------------------------------------------------
% function positionFigureOnMonitor(fig, monitorIdx, paperW_cm, paperH_cm)
%     screens = get(0,'MonitorPositions');
%     dpi     = get(0,'ScreenPixelsPerInch');
%     cm2in   = 1/2.54;
% 
%     width_px  = round(paperW_cm * cm2in * dpi);
%     height_px = round(paperH_cm * cm2in * dpi);
% 
%     if size(screens,1) >= monitorIdx
%         mon = screens(monitorIdx,:);
%     else
%         mon = screens(1,:);
%     end
% 
%     fig_left   = mon(1);
%     fig_bottom = mon(2) + mon(4) - height_px - 50; 
%     set(fig, 'Units','pixels', 'Position',[fig_left, fig_bottom, width_px, height_px]);
% 
%     set(fig, 'PaperUnits','centimeters', ...
%         'PaperSize',[paperW_cm paperH_cm], ...
%         'PaperPositionMode','manual', ...
%         'PaperPosition',[0 0 paperW_cm paperH_cm]);
% end



% -------------------------------------------------------------------------
% MUSTHAVE
% -------------------------------------------------------------------------
function mustHave(s, names)
    for k = 1:numel(names)
        if ~isfield(s, names{k})
            error('computeNPC:MissingField','Required field "%s" is missing.', names{k});
        end
    end
end



% -------------------------------------------------------------------------
% PLOTSENSITIVITY1D_SUBPLOT
% -------------------------------------------------------------------------
function plotSensitivity1D_Subplot(ax, x, y, xLabel, xlims, xticks, ylims, yticks, idxBest, idxBaseline, idxWorst, dotSize)
    % Colour-blind-safe palette following Wong (2011, Nature Methods).
    col_samples  = [86,  180, 233] / 255;   % sky blue       — scatter points
    col_best     = [0,   158, 115] / 255;   % bluish green   — best scenario
    col_baseline = [0,   114, 178] / 255;   % blue           — baseline scenario
    col_worst    = [213,  94,   0] / 255;   % vermillion     — worst scenario

    axes(ax);
    hold(ax, 'on');

    % Plot only a deterministic subset of the sample cloud.
    plotIdx = deterministicPlotSubset(numel(x), 12000, 46);
    scatter(ax, 100*x(plotIdx), y(plotIdx), dotSize, col_samples, 'filled');

    plot(ax, 100*x(idxBest),     y(idxBest),     '*', 'MarkerSize', 10, 'LineWidth', 1, 'Color', col_best);
    plot(ax, 100*x(idxBaseline), y(idxBaseline), '*', 'MarkerSize', 10, 'LineWidth', 1, 'Color', col_baseline);
    plot(ax, 100*x(idxWorst),    y(idxWorst),    '*', 'MarkerSize', 10, 'LineWidth', 1, 'Color', col_worst);

    xlabel(ax, xLabel, 'Interpreter','tex', 'FontName', 'Helvetica','FontSize',7);
    ylabel(ax, '\DeltaNPC [kEUR]', 'Interpreter','tex', 'FontName', 'Helvetica','FontSize',7);

    if isempty(xlims)
        xlims = [min(x), max(x)];
    end
    xlim(ax, xlims);
    set(ax, 'XTick', xticks);  

    if isempty(ylims)
        ylims = [min(y), max(y)];
    end    
    ylim(ax, ylims);
    set(ax, 'YTick', yticks);       

    grid(ax, 'on');
    box(ax, 'on');

    set(ax, 'FontSize', 7, 'FontName', 'Helvetica', ...
        'TickLabelInterpreter', 'tex', ...
        'LabelFontSizeMultiplier', 1);
    lgd1 = safeLegend(ax, {'Samples', 'Best', 'Baseline', 'Worst'}, ...
        'Location', 'best', 'FontSize', 7, 'Interpreter', 'tex', 'NumColumns', 2);
    lgd1.ItemTokenSize = [10, 4];        

    hold(ax, 'off');
end



% -------------------------------------------------------------------------
% DETERMINISTICPLOTSUBSET
% -------------------------------------------------------------------------
function idx = deterministicPlotSubset(n, maxN, seed)
    % Return indices for a deterministic visual-only subset.
    % This helper is used only to reduce vector-PDF object count; it must not
    % be used for statistics, regressions, medians, or rectangle selection.
    if nargin < 3 || isempty(seed)
        seed = 42;
    end

    if n <= 0
        idx = zeros(0,1);
        return
    end

    if n <= maxN
        idx = (1:n).';
        return
    end

    rngState = rng;
    cleanupObj = onCleanup(@() rng(rngState));

    rng(seed);
    idx = sort(randperm(n, maxN)).';
end



% -------------------------------------------------------------------------
% safeLegend
% -------------------------------------------------------------------------
function lgd = safeLegend(axOrHandles, varargin)
% Usage patterns mirrored:
%   lgd = safeLegend(ax, handles, labels, 'Name',Value,...)
%   lgd = safeLegend(ax, 'Label1','Label2',..., 'Name',Value,...)
%   lgd = safeLegend({'Label1','Label2',...}, 'Name',Value,...)  % current axes
%
% Internally routes to feval(@legend, ...)

    % If first arg is an axes or graphics object, keep it; else pass through
    try
        lgd = legend(axOrHandles, varargin{:});
    catch
        % Fallback: no explicit axes passed; prepend current axes
        lgd = legend(varargin{:});
    end
end



% -------------------------------------------------------------------------
% PLOT DOMINANT RECTANGLE
% -------------------------------------------------------------------------
function [x_best, y_best, success_rate_best, rectEdges, altRectEdges, ...
          x_best_alt, y_best_alt, success_rate_alt] = plotDominantRectangle2DOnly( ...
    axRect, samples, delta_NPC, ...
    rect_bounds, feasible, successThreshold, dotSize, ...
    xlims, xticks, ylims, yticks, ...
    xVarName, yVarName, xAxisInPerc, yAxisInPerc, ...
    xLabel, yLabel, altSuccessThreshold, plotAltCriterion)

    % Validate axes
    if ~ishandle(axRect) || ~strcmp(get(axRect,'Type'),'axes')
        error('plotDominantRectangle2DOnly:InvalidAxes','axRect must be a valid axes handle.');
    end
    
    % Defaults
    if nargin < 5 || isempty(feasible), feasible = true(numel(samples.(xVarName)),1); end
    if nargin < 15 || isempty(altSuccessThreshold), altSuccessThreshold = 0.95; end
    if nargin < 16 || isempty(plotAltCriterion),     plotAltCriterion     = false;  end
    
    % Extract variables
    xVar = samples.(xVarName)(:);
    yVar = samples.(yVarName)(:);
    succAll = delta_NPC(:) > 0;
    if ~isvector(feasible), feasible = feasible(:); end
    
    % Bounds & feasible subset
    x_bounds = rect_bounds(1,:);  y_bounds = rect_bounds(2,:);
    x_min = x_bounds(1); x_max = x_bounds(2); x_rng = max(eps, x_max - x_min);
    y_min = y_bounds(1); y_max = y_bounds(2); y_rng = max(eps, y_max - y_min);
    
    in = feasible & xVar>=x_min & xVar<=x_max & yVar>=y_min & yVar<=y_max;
    x = xVar(in); y = yVar(in); succ = succAll(in);
    
    % Defaults for empty case
    x_best = NaN; y_best = NaN; success_rate_best = NaN;
    rectEdges = struct('x_min',NaN,'x_max',NaN,'y_min',NaN,'y_max',NaN, ...
                       'success_rate',NaN,'area_norm',NaN,'grid_x_norm',NaN,'grid_y_norm',NaN);
    altRectEdges = rectEdges;
    x_best_alt = NaN; y_best_alt = NaN; success_rate_alt = NaN;
    
    % Early out if nothing usable
    if isempty(x)
        axes(axRect); cla(axRect); box(axRect,'on'); grid(axRect,'on');
        xlabel(axRect, xLabel, 'Interpreter','tex','FontSize',7,'FontName','Helvetica'); 
        ylabel(axRect, yLabel, 'Interpreter','tex','FontSize',7,'FontName','Helvetica');
        xlim(axRect, xlims); if ~isempty(xticks), set(axRect,'XTick',xticks); end
        ylim(axRect, ylims); if ~isempty(yticks), set(axRect,'YTick',yticks); end
        set(axRect,'FontSize',7,'TickLabelInterpreter','tex','FontName','Helvetica');
        return
    end
    
    % Normalize to [0,1]
    xn = (x - x_min)/x_rng; xn = min(max(xn,0),1);
    yn = (y - y_min)/y_rng; yn = min(max(yn,0),1);
    
    % Bin into BxB grid
    B = 100;                             % tune for speed/precision
    edges = linspace(0,1,B+1);
    ix = discretize(xn, edges); ix(isnan(ix)) = B;
    iy = discretize(yn, edges); iy(isnan(iy)) = B;
    
    H  = accumarray([ix,iy], 1,     [B B], @sum, 0, true);  % counts
    Hs = accumarray([ix,iy], double(succ),  [B B], @sum, 0, true);  % successes
    
    % 2D cumulative sums (integral images)
    Cum  = cumsum(cumsum(H ,1),2);
    CumS = cumsum(cumsum(Hs,1),2);
    
    valid = Cum > 0;
    SuccRate = zeros(B,B);
    SuccRate(valid) = CumS(valid) ./ Cum(valid);
    
    % Rectangle area in normalized units using right/top grid edges
    gx = edges(2:end); gy = gx;
    Area = (gx(:) * gy(:).');   % BxB
    
    % ---------- Main criterion ----------
    mask = SuccRate >= successThreshold & valid;
    if any(mask(:))
        [~, rel] = max(Area(mask)); idxs = find(mask); bestLin = idxs(rel);
    else
        [~, bestLin] = max(SuccRate(:) + 1e-12*Area(:));  % fallback: best rate then area
    end
    [i_best, j_best] = ind2sub([B B], bestLin);
    
    x_best = x_min + gx(i_best) * x_rng;
    y_best = y_min + gy(j_best) * y_rng;
    success_rate_best = SuccRate(i_best, j_best);
    
    rectEdges = struct( ...
        'x_min', x_min, 'x_max', x_best, ...
        'y_min', y_min, 'y_max', y_best, ...
        'success_rate', success_rate_best, ...
        'area_norm', Area(i_best,j_best), ...
        'grid_x_norm', gx(i_best), 'grid_y_norm', gy(j_best));
    
    % ---------- Alternative criterion ----------
    if plotAltCriterion
        maskAlt = SuccRate >= altSuccessThreshold & valid;
        if any(maskAlt(:))
            [~, relA] = max(Area(maskAlt)); idxsA = find(maskAlt); linAlt = idxsA(relA);
            [ia, ja] = ind2sub([B B], linAlt);
    
            x_best_alt = x_min + gx(ia) * x_rng;
            y_best_alt = y_min + gy(ja) * y_rng;
            success_rate_alt = SuccRate(ia, ja);
    
            altRectEdges = struct( ...
                'x_min', x_min, 'x_max', x_best_alt, ...
                'y_min', y_min, 'y_max', y_best_alt, ...
                'success_rate', success_rate_alt, ...
                'area_norm', Area(ia,ja), ...
                'grid_x_norm', gx(ia), 'grid_y_norm', gy(ja));
        end
    end
    
    % ---------- Plot ----------
    axes(axRect); cla(axRect); hold(axRect,'on');
    xplot = @(v) v; yplot = @(v) v;
    if xAxisInPerc, xplot = @(v) 100*v; end
    if yAxisInPerc, yplot = @(v) 100*v; end
    
    % Colour-blind-safe palette following Wong (2011, Nature Methods).
    % Success: sky blue; failure: vermillion. No red used.
    col_succ = [86,  180, 233] / 255;   % WongSkyBlue
    col_fail = [213,  94,   0] / 255;   % WongVermillion
    
    % Plot only a deterministic subset of the rectangle-design cloud.
    % Rectangle estimation above still uses all x,y,succ values.
    plotIdx = deterministicPlotSubset(numel(x), 12000, 47);
    x_plot = x(plotIdx);
    y_plot = y(plotIdx);
    succ_plot = succ(plotIdx);
    
    hSucc = scatter(axRect, xplot(x_plot(succ_plot)),   yplot(y_plot(succ_plot)),   dotSize, col_succ, 'filled', 'DisplayName', 'ΔNPC > 0');
    hFail = scatter(axRect, xplot(x_plot(~succ_plot)),  yplot(y_plot(~succ_plot)),  dotSize, col_fail, 'filled', 'DisplayName', 'ΔNPC < 0');
    
    % Main rectangle
    x_rect = [x_min, rectEdges.x_max, rectEdges.x_max, x_min, x_min];
    y_rect = [y_min, y_min,          rectEdges.y_max, rectEdges.y_max, y_min];
    if xAxisInPerc, x_rect = 100*x_rect; end
    if yAxisInPerc, y_rect = 100*y_rect; end
    
    hD1 = patch(axRect, ...
        'XData', x_rect, ...
        'YData', y_rect, ...
        'FaceColor','none', ...
        'EdgeColor','k', ...
        'LineWidth',2.0, ...
        'LineStyle','-', ...
        'DisplayName','D1');
    
    % Alternative rectangle: D2
    hD2 = gobjects(1);
    
    if plotAltCriterion && isfinite(x_best_alt)
        xr2 = [x_min, altRectEdges.x_max, altRectEdges.x_max, x_min, x_min];
        yr2 = [y_min, y_min,             altRectEdges.y_max,  altRectEdges.y_max, y_min];
    
        if xAxisInPerc, xr2 = 100*xr2; end
        if yAxisInPerc, yr2 = 100*yr2; end
    
        hD2 = patch(axRect, ...
            'XData', xr2, ...
            'YData', yr2, ...
            'FaceColor','none', ...
            'EdgeColor',[0.35 0.35 0.35], ...
            'LineStyle','--', ...
            'LineWidth',1.5, ...
            'DisplayName','D2');
    end
    
    xlabel(axRect, xLabel, 'Interpreter','tex','FontSize',7, 'FontName','Helvetica');
    ylabel(axRect, yLabel, 'Interpreter','tex','FontSize',7, 'FontName','Helvetica');
    xlim(axRect, xlims); if ~isempty(xticks), set(axRect,'XTick',xticks); end
    ylim(axRect, ylims); if ~isempty(yticks), set(axRect,'YTick',yticks); end
    grid(axRect,'on'); box(axRect,'on');
    set(axRect,'FontSize',7,'TickLabelInterpreter','tex','FontName','Helvetica');
    
    legHandles = [hSucc, hFail, hD1];
    legLabels  = {'ΔNPC > 0', 'ΔNPC < 0', 'D1'};
    
    if isgraphics(hD2)
        legHandles = [legHandles, hD2];
        legLabels  = [legLabels, {'D2'}];
    end
    lgd = safeLegend(axRect, legHandles, legLabels, ...
        'Interpreter','tex', ...
        'Location','north', ...
        'FontSize',7, ...
        'NumColumns',2);
    
    lgd.FontName = 'Helvetica';
    lgd.ItemTokenSize = [12, 6];
    
    hold(axRect,'off');
end