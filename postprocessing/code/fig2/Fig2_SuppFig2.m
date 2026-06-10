%% Housekeeping & Globals
clearvars -except CODE_DIR
close all; clc;



%% ===== Code Ocean / portable paths setup =====
ROOT_DIR = fileparts(CODE_DIR); %fileparts(fileparts(CODE_DIR));
DATA_DIR = fullfile(ROOT_DIR, 'data');
RESULTS_DIR = fullfile(ROOT_DIR, 'results', 'fig2'); 
if (~isfolder(RESULTS_DIR))
    mkdir(RESULTS_DIR); 
end
outDir = RESULTS_DIR;      



% === Data inputs ===
INPUT_RESULTS_MAT = 'results_EFC_2025_06.mat';
matPath = find_in_data_dirs(INPUT_RESULTS_MAT, DATA_DIR);
if matPath == ""
    error('Could not find "%s" in processed/raw/CODE/ROOT folders. Please place it under <root>/data/processed or <root>/data/raw.', INPUT_RESULTS_MAT);
end
load(matPath, 'resultsEFC_2025_06');   % expects the table variable to exist



% === Output targets ===
OUT_PDF_MAIN   = fullfile(RESULTS_DIR, 'J1_NatComm_Figure_2.pdf');
OUT_FIG_MAIN   = fullfile(RESULTS_DIR, 'J1_NatComm_Figure_2.fig');
OUT_PDF_SUPP   = fullfile(RESULTS_DIR, 'J1_NatComm_SuppFigure_2.pdf');
OUT_FIG_SUPP   = fullfile(RESULTS_DIR, 'J1_NatComm_SuppFigure_2.fig');



%% ===== Global graphics defaults =====
set(0, 'DefaultAxesFontName', 'Helvetica');
set(0, 'DefaultTextFontName', 'Helvetica');
set(0, 'DefaultAxesFontSize', 7);
set(0, 'DefaultTextInterpreter', 'latex');
set(0, 'DefaultAxesTickLabelInterpreter', 'latex');

% Per-figure normalization (if exporting single figs)
STD_W = 1100; 
STD_H = 850;
DO_INDIVIDUAL_EXPORT = false;

% Uniform grid look
GRID_COLOR = [0.85 0.85 0.85];
GRID_ALPHA = 0.35;



%% Load data
data = resultsEFC_2025_06;   % must exist in workspace
assert(istable(data), 'resultsEFC_2025_06 must be a MATLAB table.');
reqVars = ["Chemistry","TC","Ns","Temp","Tsig","Trest","meanEFC","stdEFC"];
assert(all(ismember(reqVars, string(data.Properties.VariableNames))), ...
       'Data table missing one or more required columns.');

% Normalize
data.Tsig  = data.Tsig  / 100;
data.Trest = data.Trest / 100;



% Split by chemistry and TC, assuming data is already cleaned & TC is final
rows_LFP = matches(string(data.Chemistry), ["CHEM_1","LFP"]);
rows_NMC = matches(string(data.Chemistry), ["CHEM_2","NMC"]);

LFP = data(rows_LFP, :);
NMC = data(rows_NMC, :);

% No remapping needed, just split by TC = 1 and 2
LFP_TC1 = LFP(LFP.TC == 1, :);
LFP_TC2 = LFP(LFP.TC == 2, :);

NMC_TC1 = NMC(NMC.TC == 1, :);
NMC_TC2 = NMC(NMC.TC == 2, :);

% Rename chemistry to human-readable if not already
LFP_TC1.Chemistry(:) = "LFP";
LFP_TC2.Chemistry(:) = "LFP";
NMC_TC1.Chemistry(:) = "NMC";
NMC_TC2.Chemistry(:) = "NMC";

data_LFP_all = {LFP_TC1, LFP_TC2};
data_NMC_all = {NMC_TC1, NMC_TC2};

for i = 1:numel(data_LFP_all)
    data_LFP_all{i}.Chemistry = repmat("LFP", height(data_LFP_all{i}), 1);
end
for i = 1:numel(data_NMC_all)
    data_NMC_all{i}.Chemistry = repmat("NMC", height(data_NMC_all{i}), 1);
end



%% Labels
Parameters_LFP   = {'Temp','Tsig','Trest','Ns'};
Pars_LFP_Symbols = {'$\mu_T\,[^{\circ}\mathrm{C}]$', ...
                    '$\sigma_T\,[^{\circ}\mathrm{C}]$', ...
                    '$t_{rest}\,[-]$', ...
                    '$N\,[-]$'};

Parameters_NMC   = {'Trest','Ns'};
Pars_NMC_Symbols = {'$t_{rest}\,[-]$', '$N\,[-]$'};

Outputs         = {'meanEFC', 'stdEFC'};
Outputs_Symbols = {'$\bar{\chi}_{\epsilon}$ [\%]', '$s_{\chi_{\epsilon}}$ [\%]'};



%% --------- Generate component figures (invisible; no per-figure export) ----------
% (1) LFP TC
fig1 = plot_TCSensitivity_trueX(data_LFP_all, Outputs, Outputs_Symbols, "LFP", ...
    outDir, "01_LFP_TC", false, true, STD_W, STD_H, DO_INDIVIDUAL_EXPORT, GRID_COLOR, GRID_ALPHA);

% (2-5) LFP parameters
figs_LFP = plot_ParameterSensitivity_trueX(data_LFP_all, Parameters_LFP, Outputs, ...
    Pars_LFP_Symbols, Outputs_Symbols, "LFP", outDir, ...
    ["02_LFP_Temp","03_LFP_Tsig","04_LFP_Trest","05_LFP_Ns"], ...
    false, true, STD_W, STD_H, DO_INDIVIDUAL_EXPORT, GRID_COLOR, GRID_ALPHA);

% (6) Chemistry grouped
fig6 = plot_ChemistryVoltageGroups(data_LFP_all, data_NMC_all, Outputs, ...
    outDir, "06_Chemistry_Grouped", true, STD_W, STD_H, DO_INDIVIDUAL_EXPORT, GRID_COLOR, GRID_ALPHA);

% (7) NMC TC
fig7 = plot_TCSensitivity_trueX(data_NMC_all, Outputs, Outputs_Symbols, "NMC", ...
    outDir, "07_NMC_TC", true, false, STD_W, STD_H, DO_INDIVIDUAL_EXPORT, GRID_COLOR, GRID_ALPHA);

% (8) Chemistry two groups at nominal thermal (LFP/NMC only ticks)
fig8 = plot_ChemistryTwoGroups_NominalThermal(data_LFP_all, data_NMC_all, Outputs, ...
    outDir, "08_Chemistry_TwoGroups", true, STD_W, STD_H, 25, 0, DO_INDIVIDUAL_EXPORT, GRID_COLOR, GRID_ALPHA);

% (9-10) NMC parameters
figs_NMC = plot_ParameterSensitivity_trueX(data_NMC_all, Parameters_NMC, Outputs, ...
    Pars_NMC_Symbols, Outputs_Symbols, "NMC", outDir, ...
    ["09_NMC_Trest","10_NMC_Ns"], ...
    true, false, STD_W, STD_H, DO_INDIVIDUAL_EXPORT, GRID_COLOR, GRID_ALPHA);



%% Composite groups
figs_1_to_6 = [ ...
    fig1, ...
    figs_LFP('02_LFP_Temp'), ...
    figs_LFP('03_LFP_Tsig'), ...
    figs_LFP('04_LFP_Trest'), ...
    figs_LFP('05_LFP_Ns'), ...
    fig6];

figs_7_to_10 = [ ...
    fig7, ...
    fig8, ...
    figs_NMC('09_NMC_Trest'), ...
    figs_NMC('10_NMC_Ns')];



%% --------- Build exact A4 composites with precise manual layout ---------
% Exact A4 (cm)
A4w = 21.0; 
A4h = 29.7;
targetMonitor = 2;

fig2  = exportCombinedGridA4Exact(figs_1_to_6, [3,2], OUT_PDF_MAIN, OUT_FIG_MAIN, A4w, A4h, targetMonitor, GRID_COLOR, GRID_ALPHA);
fprintf('Figure 2 exported.\n');
suppfig2 = exportCombinedGridA4Exact(figs_7_to_10, [2,2], OUT_PDF_SUPP, OUT_FIG_SUPP, A4w, A4h, targetMonitor, GRID_COLOR, GRID_ALPHA);
fprintf('Supplementary Figure 2 exported.\n');

fprintf('All done. Results saved under "%s/".\n\n', RESULTS_DIR);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ---------------------------- SUBFUNCTIONS ------------------------------ %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function normalizeFigureForExport(fig, STD_W, STD_H)
    set(fig, 'Units', 'pixels');
    pos = get(fig, 'Position');
    set(fig, 'Position', [pos(1), pos(2), STD_W, STD_H]);
    drawnow;
end



function finalizeExport(fig, base, outDir, STD_W, STD_H, doExport)
    normalizeFigureForExport(fig, STD_W, STD_H);
    if ~doExport, return; end
    exportgraphics(fig, fullfile(outDir, base + ".pdf"), 'ContentType','vector');
end



function fig = plot_TCSensitivity_trueX(data_all, Outputs, OutputLabels, Chem, outDir, fnamePrefix, enforceNMCTicks, enforceLFPTicks_1to6, STD_W, STD_H, doExport, GRID_COLOR, GRID_ALPHA)
    
    all_data = vertcat(data_all{:});
    if ~isstring(all_data.Chemistry), all_data.Chemistry = string(all_data.Chemistry); end

    switch Chem
        case "LFP", edgeCol=[0 0 1]; faceCol=[0.8 0.8 1];
        case "NMC", edgeCol=[1 0.5 0]; faceCol=[1 0.85 0.5];
        otherwise,  edgeCol=[0 0 0]; faceCol=[0.8 0.8 0.8];
    end
    redCol=[0.85 0 0]; labelBG=[1.00 0.95 0.95]; labelEdge=redCol;

    
    mv_delta = 0.35;
    pred_vals = [1.5 - mv_delta, 1.5 + mv_delta];
    xLabels   = {'Lower BOL spread','Higher BOL spread'};
    parameter_symbol = "Manufacturing Variability";

    base_height = 380; fig_height = 120 + base_height * numel(Outputs);
    fig = figure('Color','w','Visible','off','Position',[200,120,900,fig_height]); 
    tiledlayout(numel(Outputs),1,"TileSpacing","compact","Padding","compact");

    x_min = min(pred_vals); x_max = max(pred_vals);
    x_rng = max(x_max - x_min, eps);
    box_width = 0.32 * x_rng;
    x_pad = 0.55 * box_width;

    for j = 1:numel(Outputs)
        ax = nexttile; hold(ax, 'on');
        yName  = Outputs{j};
        yLabel = OutputLabels{j};

        % (draw)
        labelTopAll = []; whiskerLowAll = [];

        % TC==1 -> first, TC==2 -> second
        for k = 1:numel(pred_vals)
            val   = pred_vals(k);
            idx   = (all_data.TC == k);
            ydata = all_data{idx, yName};
            ydata = ydata(~isnan(ydata));
            if isempty(ydata), continue; end

            boxchart(ones(size(ydata))*val, ydata, ...
                'BoxWidth',box_width,'BoxFaceColor',faceCol,'BoxFaceAlpha',0.35, ...
                'BoxEdgeColor',edgeCol,'LineWidth',1.4,'MarkerStyle','o', ...
                'MarkerColor',[0 0 0],'MarkerSize',4);

            q  = quantile(ydata,[0.25 0.50 0.75]); q1=q(1); q2=q(2); q3=q(3);
            IQR = max(q3-q1,eps);
            wHigh = min(max(ydata), q3 + 1.5*IQR);
            wLow  = max(min(ydata), q1 - 1.5*IQR);

            plot([val - box_width/2, val + box_width/2], [q2 q2], 'Color', redCol, 'LineWidth', 1.7);

            spread = range(ydata); if ~isfinite(spread) || spread<=0, spread=max(IQR,1); end
            yText = wHigh + 0.02*spread;
            % smaller median tile
            txt = text(val,yText,sprintf('%.2f',q2),'HorizontalAlignment','center', ...
                'VerticalAlignment','bottom','FontSize',6,'FontWeight','bold', ...
                'Interpreter','latex','Color',redCol,'Margin',0.5, ...
                'BackgroundColor',labelBG,'EdgeColor',labelEdge,'LineWidth',0.4,'Clipping','off');
            set(txt,'Units','data'); ext = get(txt,'Extent');
            labelTopAll(end+1) = ext(2)+ext(4); whiskerLowAll(end+1) = wLow; %#ok<AGROW>
        end

        grid on; box on;
        ax.GridAlpha = GRID_ALPHA; ax.GridColor = GRID_COLOR;
        set(ax,'XTick',pred_vals,'XTickLabel',xLabels,'TickLabelInterpreter','latex');
        xlim(ax,[x_min - x_pad, x_max + x_pad]);
        ylabel(yLabel,'FontSize',7,'Interpreter','latex');
        ax.Box = 'on'; ax.Layer='top';

        % --- FORCE Y-LIMITS per figure set ---
        if enforceLFPTicks_1to6     
            % Figure 1 (LFP TC): mean [0,17], std [0.8,3]
            if strcmp(yName,'meanEFC')
                ylim(ax, [0, 17]); set(ax,'YTick',[0 5 10 15]);
            else
                ylim(ax, [0.8, 3]); set(ax,'YTick',[1 2 3]);
            end
        elseif Chem=="NMC" && enforceNMCTicks   
            % Figure 7 (NMC TC): mean [0,30], std [0,6]
            if strcmp(yName,'meanEFC')
                ylim(ax, [0, 30]); set(ax,'YTick',[0 10 20 30]);
            else
                ylim(ax, [0, 6]);  set(ax,'YTick',[0 2 4 6]);
            end
        end
    end

    % Bottom-axis label only
    tagAxesInTiles(fig); setBottomXAxisLabel(fig, parameter_symbol);

    base = sprintf('%s_TC_BoxplotTrueX_%s', fnamePrefix, Chem);
    finalizeExport(fig, base, outDir, STD_W, STD_H, doExport);

end



function figs = plot_ParameterSensitivity_trueX(data_all, Parameters, Outputs, ...
    ParameterLabels, OutputLabels, Chem, outDir, filenameOrder, ...
    enforceNMCTicks, enforceLFPTicks_1to6, STD_W, STD_H, doExport, GRID_COLOR, GRID_ALPHA)

    all_data_master = vertcat(data_all{:});
    if ~isstring(all_data_master.Chemistry), all_data_master.Chemistry = string(all_data_master.Chemistry); end

    switch Chem
        case "LFP", edgeCol=[0 0 1]; faceCol=[0.8 0.8 1];
        case "NMC", edgeCol=[1 0.5 0]; faceCol=[1 0.85 0.5];
        otherwise,  edgeCol=[0 0 0]; faceCol=[0.7 0.7 0.7];
    end
    redCol=[0.85 0 0]; labelBGCol=[1.00 0.95 0.95]; labelEdgeCol=redCol;

    widthMap = containers.Map({'Ns','Temp','Tsig','Trest'}, {0.03,0.10,0.10,0.20});
    figs = containers.Map('KeyType','char','ValueType','any');

    for p = 1:numel(Parameters)
        xName  = Parameters{p};
        xLabel = ParameterLabels{p};
        tag = filenameOrder(min(p, numel(filenameOrder)));

        all_data = all_data_master;

        % For clarity
        if strcmp(xName,'Ns') && (contains(tag,'05_LFP_Ns') || contains(tag,'10_NMC_Ns'))
            all_data = all_data(all_data.Ns ~= 20, :);
        end

        xvals = sort(unique(all_data{:, xName}));
        if isempty(xvals), warning('No values for %s (%s).', xName, Chem); continue; end

        xMin = min(xvals); xMax = max(xvals); xRange = max(xMax - xMin, eps);
        if isKey(widthMap, xName), w = widthMap(xName)*xRange; else, w = 0.03*xRange; end

        fig = figure('Color','w','Visible','off','Position',[200 150 900 800]); 
        tiledlayout(numel(Outputs),1,'TileSpacing','compact','Padding','compact');

        for j = 1:numel(Outputs)
            ax = nexttile; hold(ax,'on');
            yName  = Outputs{j};
            yLabel = OutputLabels{j};

            labelTopAll = []; whiskerLowAll = []; labelBottomAll = [];

            for k = 1:numel(xvals)
                xi = xvals(k);
                idx = all_data.(xName) == xi;
                y   = all_data{idx, yName};
                y   = y(~isnan(y)); if isempty(y), continue; end

                boxchart(ones(size(y))*xi, y, ...
                    'BoxWidth',w,'BoxFaceColor',faceCol,'BoxFaceAlpha',0.35, ...
                    'BoxEdgeColor',edgeCol,'LineWidth',1.3,'MarkerStyle','o', ...
                    'MarkerColor',[0 0 0],'MarkerSize',4);

                q  = quantile(y,[0.25 0.50 0.75]); q1=q(1); q2=q(2); q3=q(3);
                IQR = max(q3 - q1, eps);
                wHigh = min(max(y), q3 + 1.5*IQR);
                wLow  = max(min(y), q1 - 1.5*IQR);

                plot([xi - w/2, xi + w/2], [q2 q2], 'Color', redCol, 'LineWidth', 1.6);

                spread = range(y); if ~isfinite(spread) || spread<=0, spread=max(IQR,1); end

                % First Ns label below
                placeBelow = strcmp(xName,'Ns') && k==1;
                if placeBelow
                    yText = wLow - 0.03*spread;  vAlign = 'top';
                else
                    yText = wHigh + 0.02*spread; vAlign = 'bottom';
                end

                % Smaller median tile
                txt = text(xi,yText,sprintf('%.2f',q2),'HorizontalAlignment','center', ...
                    'VerticalAlignment',vAlign,'FontSize',6,'FontWeight','bold', ...
                    'Interpreter','latex','Color',redCol,'Margin',0.5, ...
                    'BackgroundColor',labelBGCol,'EdgeColor',labelEdgeCol,'LineWidth',0.4,'Clipping','off');              
                set(txt,'Units','data'); ext=get(txt,'Extent');

                labelTopAll(end+1)    = ext(2)+ext(4);  %#ok<AGROW>
                labelBottomAll(end+1) = ext(2);         %#ok<AGROW>
                whiskerLowAll(end+1)  = wLow;           %#ok<AGROW>
            end

            grid on; box on;
            ax.GridAlpha=GRID_ALPHA; ax.GridColor=GRID_COLOR; ax.Box='on'; ax.Layer='top';

            % X ticks/labels
            if strcmp(xName,'Tsig') && Chem=="LFP"
                TsigTicksDeg = [0 2.5 5];
                TsigTicksRaw = TsigTicksDeg / 6;  % map from ±3σ span back to σ
                set(ax,'XTick',TsigTicksRaw,'XTickLabel',string(TsigTicksDeg),'TickLabelInterpreter','latex');
            elseif strcmp(xName,'Ns')
                set(ax,'XTick',[0 50 100 150 200],'XTickLabel',string([0 50 100 150 200]));
            else
                set(ax,'XTick',xvals,'XTickLabel',string(xvals),'TickLabelInterpreter','latex');
            end

            % X limits (more room for Ns)
            if strcmp(xName,'Ns')
                xlim(ax, [-12, 212]);   % extra space on both sides
            elseif strcmp(xName,'Trest')
                xlim(ax, [xMin - 1.5*w, xMax + 1.5*w]);
            else
                xlim(ax,[xMin - 3*w, xMax + 3*w]);
            end

            % ylabel(yLabel,'FontSize',11,'Interpreter','latex');  % NatComm: original
            ylabel(yLabel,'FontSize',7,'Interpreter','latex');

            % --- FORCE Y-LIMITS per figure sets ---
            if enforceLFPTicks_1to6   % LFP set (Figures 2–5)
                if strcmp(yName,'meanEFC')
                    ylim(ax, [0, 17]); set(ax,'YTick',[0 5 10 15]);
                else
                    ylim(ax, [0.8, 3]); set(ax,'YTick',[1 2 3]);
                end
            elseif Chem=="NMC" && enforceNMCTicks  % NMC set (Figures 9–10)
                if strcmp(yName,'meanEFC')
                    ylim(ax, [0, 30]); set(ax,'YTick',[0 10 20 30]);
                else
                    ylim(ax, [0, 6]);  set(ax,'YTick',[0 2 4 6]);
                end
            end
        end

        % Bottom-axis label only
        if strcmp(xName,'Tsig') && Chem=="LFP"
            sharedXL = '$\pm 3\,\sigma_T$ $[^{\circ}\mathrm{C}]$';
        else
            sharedXL = xLabel;
        end
        tagAxesInTiles(fig); setBottomXAxisLabel(fig, sharedXL);

        base = sprintf('%s_BoxplotTrueX_%s_%s', tag, xName, Chem);
        finalizeExport(fig, base, outDir, STD_W, STD_H, doExport);

        figs(char(tag)) = fig;
    end
end



function fig = plot_ChemistryVoltageGroups(data_LFP_all, data_NMC_all, ~, outDir, fnamePrefix, ~, STD_W, STD_H, doExport, GRID_COLOR, GRID_ALPHA)
% Clustered groups:
%   Low voltage: [LFP lowV, NMC lowV]
%   400 V     : [LFP 400V, NMC 400V]
%   800 V     : [NMC 800V]

    all_data = vertcat(data_LFP_all{:}, data_NMC_all{:});

    ChemGroup = strings(height(all_data),1);
    for i = 1:height(all_data)
        Ns = all_data.Ns(i); ch = string(all_data.Chemistry(i));
        if ch == "LFP"
            if Ns < 100, ChemGroup(i) = "LFP lowV";
            elseif Ns == 100, ChemGroup(i) = "LFP 400V"; end
        elseif ch == "NMC"
            if Ns < 100, ChemGroup(i) = "NMC lowV";
            elseif Ns == 100, ChemGroup(i) = "NMC 400V";
            elseif Ns == 200, ChemGroup(i) = "NMC 800V"; 
            end
        end
    end
    valid = ChemGroup ~= ""; all_data = all_data(valid,:); ChemGroup = ChemGroup(valid);

    desired = ["LFP lowV","NMC lowV","LFP 400V","NMC 400V","NMC 800V"];
    present = desired(ismember(desired, unique(ChemGroup,'stable')));

    % Cluster centers: c1=1 (lowV), c2=3 (400V), c3=5 (800V)
    % Pair offset slightly wider: d=0.22
    c1=1; c2=3; c3=5; d=0.22;
    posMap = containers.Map( ...
       {'LFP lowV','NMC lowV','LFP 400V','NMC 400V','NMC 800V'}, ...
       {c1-d,      c1+d,      c2-d,      c2+d,      c3} );

    inCats = present;
    xpos = zeros(1, numel(inCats));
    for i=1:numel(inCats), xpos(i) = posMap(char(inCats(i))); end

    all_data.ChemGroup = categorical(ChemGroup, inCats, 'Ordinal', true);
    group2x = containers.Map(cellstr(inCats), num2cell(xpos));

    color_map = containers.Map( ...
        {'LFP lowV','LFP 400V','NMC lowV','NMC 400V','NMC 800V'}, ...
        {[0.2 0.2 1],[0 0 0.6],[1 0.6 0.2],[1 0.3 0],[0.6 0 0]} );

    fig = figure('Color','w','Visible','off','Position',[200 100 900 800]); 
    tiledlayout(2,1,"TileSpacing","compact","Padding","compact");

    % meanEFC (upper)
    ax1 = nexttile; hold(ax1, 'on');
    [~,labelTops_mean,whiskerLows_mean] = drawGroupedBoxax_clustered( ...
        all_data, inCats, group2x, color_map, xpos, 'meanEFC', 'NMC 800V');

    ylabel(ax1,'$\bar{\chi}_{\epsilon}$ [\%]','Interpreter','latex','FontSize',7);
    grid(ax1,'on'); box(ax1,'on'); applyPaddedYLimits(ax1,labelTops_mean,whiskerLows_mean);
    set(ax1,'YTick',[0 10 20 30]);
    ylim(ax1, [0, 30]);   % FIXED limits for Figure 6
    set(ax1,'GridColor',GRID_COLOR,'GridAlpha',GRID_ALPHA,'Layer','top');

    % stdEFC (lower)
    ax2 = nexttile; hold(ax2, 'on');
    [~,labelTops_std,whiskerLows_std] = drawGroupedBoxax_clustered(all_data, inCats, group2x, color_map, xpos, 'stdEFC', true);
    ylabel(ax2,'$s_{\chi_{\epsilon}}$ [\%]','Interpreter','latex','FontSize',7);
    grid(ax2,'on'); box(ax2,'on'); applyPaddedYLimits(ax2,labelTops_std,whiskerLows_std);
    set(ax2,'YTick',[1 3 5]);
    ylim(ax2, [0.8, 6]);  % FIXED limits for Figure 6
    set(ax2,'GridColor',GRID_COLOR,'GridAlpha',GRID_ALPHA,'Layer','top');

    % Cluster tick labels
    clusterCenters = [c1, c2, c3];
    clusterLabels  = {'Low voltage','400 V','800 V'};
    for ax = [ax1 ax2]
        set(ax, 'XTick', clusterCenters, 'XTickLabel', clusterLabels);
        xMin = min(xpos) - 0.6; xMax = max(xpos) + 0.6;
        xlim(ax, [xMin, xMax]);
    end

    tagAxesInTiles(fig);
    base = fnamePrefix;
    finalizeExport(fig, base, outDir, STD_W, STD_H, doExport);
end



function fig = plot_ChemistryTwoGroups_NominalThermal(data_LFP_all, data_NMC_all, ~, outDir, fnamePrefix, enforceNMCTicks, STD_W, STD_H, tempTarget, tsigTarget, doExport, GRID_COLOR, GRID_ALPHA)
    % Two-group chemistry plot; TICKS = {'LFP','NMC'} ONLY (both panels).
    if nargin < 6, enforceNMCTicks = false; end
    if nargin < 8, STD_W = 1100; STD_H = 850; end
    if nargin < 10, tempTarget = 25; end
    if nargin < 11, tsigTarget = 0; end

    LFP_all = vertcat(data_LFP_all{:});
    NMC_all = vertcat(data_NMC_all{:});

    tolT = 1e-9; tolS = 1e-12;
    LFP_sel = LFP_all(abs(LFP_all.Temp - tempTarget) < tolT & abs(LFP_all.Tsig - tsigTarget) < tolS, :);
    NMC_sel = NMC_all(abs(NMC_all.Temp - tempTarget) < tolT & abs(NMC_all.Tsig - tsigTarget) < tolS, :);

    if isempty(LFP_sel), LFP_sel = LFP_all; end
    if isempty(NMC_sel), NMC_sel = NMC_all; end

    LFP_sel.Cat = repmat("LFP", height(LFP_sel), 1);
    NMC_sel.Cat = repmat("NMC", height(NMC_sel), 1);
    T = [LFP_sel; NMC_sel];

    groupCats = {'LFP','NMC'}; xpos=[1 2]; group2x = containers.Map(groupCats, num2cell(xpos));
    color_map = containers.Map({'LFP','NMC'}, {[0 0 1],[1 0.5 0]});

    fig = figure('Color','w','Visible','off','Position',[200 120 900 800]); 
    tiledlayout(2,1,"TileSpacing","compact","Padding","compact");

    % meanEFC (upper)
    ax1 = nexttile; hold(ax1,'on');
    [~,labelTops_mean,whiskerLows_mean] = drawGroupedBoxax_simple(T, groupCats, group2x, color_map, xpos, 'meanEFC', 'Cat');
    ylabel(ax1,'$\bar{\chi}_{\epsilon}$ [\%]','Interpreter','latex','FontSize',7);
    grid(ax1,'on'); box(ax1,'on'); applyPaddedYLimits(ax1,labelTops_mean,whiskerLows_mean);
    if enforceNMCTicks, set(ax1,'YTick',[0 10 20 30]); end
    ylim(ax1, [0, 30]);    % FIXED limits
    set(ax1,'GridColor',GRID_COLOR,'GridAlpha',GRID_ALPHA,'Box','on','Layer','top');    
    set(ax1,'XTick',xpos,'XTickLabel',groupCats);
    xlim(ax1, [min(xpos)-0.6, max(xpos)+0.6]);

    % stdEFC (lower)
    ax2 = nexttile; hold(ax2,'on');
    [~,labelTops_std,whiskerLows_std] = drawGroupedBoxax_simple(T, groupCats, group2x, color_map, xpos, 'stdEFC', 'Cat');
    ylabel(ax2,'$s_{\chi_{\epsilon}}$ [\%]','Interpreter','latex','FontSize',7);
    grid(ax2,'on'); box(ax2,'on'); applyPaddedYLimits(ax2,labelTops_std,whiskerLows_std);
    if enforceNMCTicks, set(ax2,'YTick',[0 2 4 6]); end
    ylim(ax2, [0, 6]);     % FIXED limits
    set(ax2,'GridColor',GRID_COLOR,'GridAlpha',GRID_ALPHA,'Box','on','Layer','top');
    set(ax2,'XTick',xpos,'XTickLabel',groupCats);
    xlim(ax2, [min(xpos)-0.6, max(xpos)+0.6]);

    % Bottom-axis label only
    tagAxesInTiles(fig); setBottomXAxisLabel(fig, 'Chemistry');

    finalizeExport(fig, fnamePrefix, outDir, STD_W, STD_H, doExport);

end



function [stats, labelTops, whiskerLows] = drawGroupedBoxax_simple(T, groupCats, group2x, color_map, xpos, yColName, groupVar)
    Nc = numel(groupCats);
    box_width=0.55; 
    stats = repmat(struct('x',[],'wlow',[],'q1',[],'median',[],'q3',[],'whigh',[]),1,Nc);
    labelTops=[]; whiskerLows=[]; hold on;

    for i=1:Nc
        g = string(groupCats{i}); xi = group2x(char(g));
        idx = string(T.(groupVar)) == g;
        y = T{idx, yColName}; y = y(~isnan(y)); if isempty(y), continue; end

        c = color_map(char(g));
        boxchart(ones(size(y))*xi, y, 'BoxWidth',box_width,'BoxFaceColor',c, ...
                 'BoxFaceAlpha',0.3,'BoxEdgeColor',c,'LineWidth',1.4, ...
                 'MarkerStyle','o','MarkerColor',[0 0 0],'MarkerSize',4);

        q = quantile(y,[0.25 0.50 0.75]); q1=q(1); q2=q(2); q3=q(3);
        IQR=max(q3-q1,eps); wlow=max(min(y), q1-1.5*IQR); whi=min(max(y), q3+1.5*IQR);

        plot([xi - box_width/2, xi + box_width/2], [q2 q2], 'Color', [0.85 0 0], 'LineWidth', 1.6);

        spread = range(y); if ~isfinite(spread)||spread<=0, spread=max(IQR,1); end
        yText = whi + 0.02*spread;
        txt = text(xi,yText,sprintf('%.2f',q2),'HorizontalAlignment','center','VerticalAlignment','bottom', ...
                   'FontSize',6,'FontWeight','bold','Interpreter','latex','Color',[0.85 0 0], ...
                   'Margin',0.5,'BackgroundColor',[1.0 0.95 0.95],'EdgeColor',[0.85 0 0],'LineWidth',0.4,'Clipping','off');
        set(txt,'Units','data'); ext=get(txt,'Extent');        
        labelTops(end+1)=ext(2)+ext(4); %#ok<AGROW>
        whiskerLows(end+1)=wlow; %#ok<AGROW>

        stats(i).x = xi; stats(i).wlow = wlow; stats(i).q1 = q1; stats(i).median = q2; stats(i).q3 = q3; stats(i).whigh = whi;
    end

    xlim([min(xpos)-0.6, max(xpos)+0.6]);
end



function [stats, labelTops, whiskerLows] = drawGroupedBoxax_clustered(all_data, orderedCats, group2x, color_map, xpos, yColName, labelBelowGroup)
% Uses explicit x-positions (clustered),
% smaller median tiles, and (optionally) places the median label BELOW the
% lower whisker for one specified group (e.g., 'NMC 800V') on mean panel.
%
% labelBelowGroup: '' (default) or group name like 'NMC 800V'

    if nargin < 7 || isempty(labelBelowGroup)
        labelBelowGroup = '';  % default: no special placement
    end

    Nc = numel(orderedCats);
    box_width = 0.40; redCol=[0.85 0 0]; labelBG=[1.00 0.95 0.95]; labelEdge=redCol;

    stats = repmat(struct('x',[],'wlow',[],'q1',[],'median',[],'q3',[],'whigh',[]),1,Nc);
    labelTops=[]; whiskerLows=[];
    hold on;

    for i = 1:Nc
        gname = string(orderedCats{i});
        xi    = group2x(char(gname));
        idx   = all_data.ChemGroup == gname;
        y     = all_data{idx, yColName}; y = y(~isnan(y));
        if isempty(y), continue; end

        if isKey(color_map, char(gname)), c = color_map(char(gname)); else, c=[0.5 0.5 0.5]; end

        boxchart(ones(size(y))*xi, y, 'BoxWidth',box_width, 'BoxFaceColor',c, ...
                 'BoxFaceAlpha',0.3,'BoxEdgeColor',c,'LineWidth',1.4, ...
                 'MarkerStyle','o','MarkerColor',[0 0 0],'MarkerSize',4);

        q = quantile(y,[0.25 0.50 0.75]); q1=q(1); q2=q(2); q3=q(3);
        IQR = max(q3-q1,eps); wlow = max(min(y), q1-1.5*IQR); whi = min(max(y), q3+1.5*IQR);

        plot([xi - box_width/2, xi + box_width/2], [q2 q2], 'Color', redCol, 'LineWidth', 1.6);

        spread = range(y); if ~isfinite(spread) || spread<=0, spread=max(IQR,1); end
        
        if strcmpi(yColName,'meanEFC') && ~isempty(labelBelowGroup) && strcmp(string(labelBelowGroup), gname)
            yText  = wlow - 0.03*spread;
            vAlign = 'top';
        else
            yText  = whi + 0.02*spread;
            vAlign = 'bottom';
        end

        txt = text(xi,yText,sprintf('%.2f',q2),'HorizontalAlignment','center','VerticalAlignment',vAlign, ...
                   'FontSize',6,'FontWeight','bold','Interpreter','latex','Color',redCol, ...
                   'Margin',0.5,'BackgroundColor',labelBG,'EdgeColor',labelEdge,'LineWidth',0.4,'Clipping','off');        

        set(txt,'Units','data'); ext=get(txt,'Extent');
        labelTops(end+1)=ext(2)+ext(4); %#ok<AGROW>
        whiskerLows(end+1)=wlow;        %#ok<AGROW>

        stats(i).x = xi; stats(i).wlow = wlow; stats(i).q1 = q1; stats(i).median = q2; stats(i).q3 = q3; stats(i).whigh = whi;
    end

    xlim([min(xpos)-0.6, max(xpos)+0.6]);
end



function applyPaddedYLimits(ax, labelTops, whiskerLows)
    if isempty(whiskerLows), whiskerLows = ax.YLim(1); end
    if isempty(labelTops),   labelTops   = ax.YLim(2); end
    yMinData = min(whiskerLows); yMaxData = max(labelTops);
    dataSpan = yMaxData - yMinData; if ~isfinite(dataSpan) || dataSpan <= 0, dataSpan = 1; end
    ylim(ax, [yMinData - 0.05*dataSpan, yMaxData + 0.10*dataSpan]);
end



function tagAxesInTiles(fig)
    ax = findobj(fig, 'Type','Axes', '-not', 'Tag','legend');
    if numel(ax) >= 2
        [~,idx] = sort(arrayfun(@(a)a.Position(2), ax), 'descend');
        ax = ax(idx);
        set(ax(1), 'Tag','upper');
        set(ax(2), 'Tag','lower');
    end
end



function setBottomXAxisLabel(fig, labelStr)
    axLower = findobj(fig, 'Type','Axes', 'Tag','lower');
    if ~isempty(axLower) && (isstring(labelStr) || ischar(labelStr))
        xlabel(axLower(1), labelStr, 'Interpreter','latex', 'FontSize', 7);
    end
end



function destFig = exportCombinedGridA4Exact(srcFigs, gridRC, OUT_PDF, OUT_FIG, A4w_cm, A4h_cm, targetMonitor, GRID_COLOR, GRID_ALPHA)
% Manual layout (no tiledlayout): precise control of gaps inside each panel.
% - Exact A4 page size (width x height)
% - Place window top-left on target monitor
% - Two axes per panel (upper/lower) with small internal gap; wider column gap.
% - If outBase contains "Figure_3", cap upper YLim of upper axes for panels 1..5 to 17.

    rows = gridRC(1); cols = gridRC(2);
    assert(numel(srcFigs) == rows*cols, 'Mismatch between source figs and grid layout.');

    % Pixel sizing for the window (top-left on monitor)
    dpi = get(0,'ScreenPixelsPerInch'); cm2in = 1/2.54;
    width_px  = round(A4w_cm * cm2in * dpi);
    height_px = round(A4h_cm * cm2in * dpi);

    destFig = figure('Color','w','Units','pixels');
    screens = get(0,'MonitorPositions');
    if targetMonitor < 1 || targetMonitor > size(screens,1), targetMonitor = 1; end
    mon = screens(targetMonitor,:);
    fig_left   = mon(1);
    fig_bottom = mon(2) + mon(4) - height_px - 100;  % 100 px down from top
    set(destFig, 'Position', [fig_left, fig_bottom, width_px, height_px]);

    % Paper export exact A4
    set(destFig,'PaperUnits','centimeters');
    set(destFig,'PaperSize',[A4w_cm A4h_cm]);
    set(destFig,'PaperPosition',[0 0 A4w_cm A4h_cm]);
    set(destFig,'PaperPositionMode','manual');

    % ---- Manual normalized layout ----
    L = 0.08; R = 0.04; T = 0.06; B = 0.08;  % outer margins
    hgap = 0.07;           % gap between columns
    vgap_group = 0.06;     % gap between panel rows
    vgap_internal = 0.03;  % gap between mean/std within a panel

    cellW = (1 - L - R - (cols-1)*hgap)/cols;
    cellH = (1 - T - B - (rows-1)*vgap_group)/rows;
    axH   = (cellH - vgap_internal)/2;

    doCapUpper17 = contains(OUT_PDF, "Figure_3");

    % Iterate over panels and place upper/lower axes
    for k = 1:numel(srcFigs)
        if ~ishandle(srcFigs(k)), continue; end

        % Source axes (prefer tags; fallback to vertical sort)
        axUpperSrc = findobj(srcFigs(k), 'Type','Axes', 'Tag','upper');
        axLowerSrc = findobj(srcFigs(k), 'Type','Axes', 'Tag','lower');
        if isempty(axUpperSrc) || isempty(axLowerSrc)
            axSrc = findobj(srcFigs(k), 'Type','Axes', '-not','Tag','legend');
            [~, idxTmp] = sort(arrayfun(@(a)a.Position(2), axSrc), 'descend');
            axSrc = axSrc(idxTmp);
            if numel(axSrc)>=1, axUpperSrc = axSrc(1); end
            if numel(axSrc)>=2, axLowerSrc = axSrc(2); end
        end

        row = ceil(k/cols); col = mod(k-1, cols)+1;

        x0 = L + (col-1)*(cellW + hgap);
        yTop = 1 - T - (row-1)*(cellH + vgap_group);
        y0   = yTop - cellH;

        upPos = [x0, y0 + vgap_internal + axH, cellW, axH];
        loPos = [x0, y0,                          cellW, axH];

        axUp = axes('Parent',destFig,'Units','normalized','Position',upPos); hold(axUp,'on');
        axLo = axes('Parent',destFig,'Units','normalized','Position',loPos); hold(axLo,'on');

        if ~isempty(axUpperSrc), copyAxisContents(axUpperSrc(1), axUp); end
        if ~isempty(axLowerSrc), copyAxisContents(axLowerSrc(1), axLo); end

        for ax = [axUp, axLo]
            set(ax, 'GridColor', GRID_COLOR, 'GridAlpha', GRID_ALPHA, 'Box','on','Layer','top');
            grid(ax,'on');
        end

        % Cap upper YLim to 17 for Figure 3, panels 1..5 (upper axis)
        if doCapUpper17 && k <= 5
            yl = axUp.YLim; yl(2) = 17; if yl(1) >= yl(2), yl(1) = 0; end; axUp.YLim = yl;
        end
    end

    % Export graphics
    %exportgraphics(destFig, outBase + "_epsformat.eps", 'ContentType','vector');        
    exportgraphics(destFig, OUT_PDF, 'ContentType','vector');
    savefig(destFig, OUT_FIG);

end


function copyAxisContents(axSrc, axDest)
    kids = allchild(axSrc);
    copyobj(kids, axDest);

    if ~isempty(axSrc.XLabel.String)
        axDest.XLabel.String = axSrc.XLabel.String;
        axDest.XLabel.Interpreter = axSrc.XLabel.Interpreter;
    end
    if ~ischar(axSrc.YLabel.String) || ~isempty(axSrc.YLabel.String)
        axDest.YLabel.String = axSrc.YLabel.String;
        axDest.YLabel.Interpreter = axSrc.YLabel.Interpreter;
    end
    if ~isempty(axSrc.Title.String)
        axDest.Title.String  = axSrc.Title.String;
        axDest.Title.Interpreter  = axSrc.Title.Interpreter;
    end

    axDest.XLim = axSrc.XLim;   axDest.YLim = axSrc.YLim;
    axDest.XTick = axSrc.XTick; axDest.YTick = axSrc.YTick;
    try axDest.XTickLabel = axSrc.XTickLabel; catch, end
    axDest.TickLabelInterpreter = getOrDefault(axSrc,'TickLabelInterpreter','latex');
    axDest.FontName = getOrDefault(axSrc,'FontName','Arial');
    axDest.FontSize = getOrDefault(axSrc,'FontSize',7);
    axDest.Box = 'on';
    axDest.Layer = 'top';
end



function v = getOrDefault(s, prop, def)
    try v = get(s, prop); catch, v = def; end
end



% Utility: find a file in preferred data locations
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