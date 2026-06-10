%% PREPARE
clearvars -except CODE_DIR
close all; clc;



%% ===== Code Ocean / portable paths setup =====
ROOT_DIR    = fileparts(CODE_DIR);
DATA_DIR    = fullfile(ROOT_DIR, 'data');       
RESULTS_DIR = fullfile(ROOT_DIR, 'results', 'fig4-5');
if (~isfolder(RESULTS_DIR))
    mkdir(RESULTS_DIR);
end

OUT_PDF = fullfile(RESULTS_DIR, 'J1_NatComm_SuppFigure_5.pdf');
OUT_FIG = fullfile(RESULTS_DIR, 'J1_NatComm_SuppFigure_5.fig');

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



%% ===== CONFIGURATION =====
paramRanges = getParamRanges();
n_samples   = 100000;

% --- Panel (a): Electricity price scenarios ---
% Low:      Hungary/Bulgaria (~0.10 EUR/kWh)
% Baseline: Sweden, second half of 2024 (~0.24 EUR/kWh)
% High:     Germany (~0.40 EUR/kWh)
% Source: Eurostat electricity price statistics
c_en_scenarios = [0.10,  0.24,  0.40];
labels_en      = {'Low (0.10)', 'Baseline (0.24)', 'High (0.40)'};
n_en           = numel(c_en_scenarios);

% --- Panel (b): Vehicle energy consumption scenarios ---
% Low:      City driving, mild climate, e.g. southern Europe (~0.15 kWh/km)
% Baseline: Mixed conditions, mid-size BEV (~0.20 kWh/km)
% High:     Highway driving or cold-climate winter, e.g. Nordic winter (~0.30 kWh/km)
% Range grounded in Green NCAP real-world testing (0.158 to 0.312 kWh/km)
eta_scenarios = [0.15,  0.20,  0.30];
labels_eta    = {'Low (0.15)', 'Baseline (0.20)', 'High (0.30)'};
n_eta         = numel(eta_scenarios);



%% ===== RUN LHS: ELECTRICITY PRICE =====
fprintf('=== Panel (a): Electricity price sensitivity ===\n');
delta_NPC_en   = cell(n_en, 1);
samples_en     = cell(n_en, 1);

for s = 1:n_en
    fprintf('  Running scenario %d / %d  (c_en = %.2f EUR/kWh) ...\n', ...
        s, n_en, c_en_scenarios(s));
    params_s = getParams('c_en_EURperkWh', c_en_scenarios(s));
    [samp_s, dNPC_s, ~, ~] = sampleDeltaNPC_LHS(paramRanges, n_samples, params_s);
    delta_NPC_en{s} = dNPC_s / 1000;
    samples_en{s}   = samp_s;
    fprintf('    Median delta_NPC = %.2f kEUR\n', median(delta_NPC_en{s}));
end



%% ===== RUN LHS: ENERGY CONSUMPTION =====
fprintf('=== Panel (b): Energy consumption sensitivity ===\n');
delta_NPC_eta  = cell(n_eta, 1);
samples_eta    = cell(n_eta, 1);

for s = 1:n_eta
    fprintf('  Running scenario %d / %d  (eta = %.2f kWh/km) ...\n', ...
        s, n_eta, eta_scenarios(s));
    params_s = getParams('eta_en_kWhkm', eta_scenarios(s));
    [samp_s, dNPC_s, ~, ~] = sampleDeltaNPC_LHS(paramRanges, n_samples, params_s);
    delta_NPC_eta{s} = dNPC_s / 1000;
    samples_eta{s}   = samp_s;
    fprintf('    Median delta_NPC = %.2f kEUR\n', median(delta_NPC_eta{s}));
end



%% ===== PRINT SUMMARY TABLES =====
E_threshold = 50;   % kWh 

fprintf('\n--- Panel (a): Electricity price sensitivity ---\n');
fprintf('  %-22s  %8s  %8s  %8s  %8s  %10s  %10s\n', ...
    'Scenario', 'Median', 'P25', 'P75', 'Frac>0', ...
    sprintf('E>=%dkWh', E_threshold), ...
    sprintf('E<%dkWh',  E_threshold));
for s = 1:n_en
    d     = delta_NPC_en{s};
    E     = samples_en{s}.E_pack_nom;
    fprintf('  %-22s  %8.2f  %8.2f  %8.2f  %7.1f%%  %9.1f%%  %9.1f%%\n', ...
        labels_en{s}, 1000*median(d), prctile(d,25), prctile(d,75), ...
        100*mean(d > 0), ...
        100*mean(d(E >= E_threshold) > 0), ...
        100*mean(d(E <  E_threshold) > 0));
end

fprintf('\n--- Panel (b): Energy consumption sensitivity ---\n');
fprintf('  %-22s  %8s  %8s  %8s  %8s  %10s  %10s\n', ...
    'Scenario', 'Median', 'P25', 'P75', 'Frac>0', ...
    sprintf('E>=%dkWh', E_threshold), ...
    sprintf('E<%dkWh',  E_threshold));
for s = 1:n_eta
    d     = delta_NPC_eta{s};
    E     = samples_eta{s}.E_pack_nom;
    fprintf('  %-22s  %8.2f  %8.2f  %8.2f  %7.1f%%  %9.1f%%  %9.1f%%\n', ...
        labels_eta{s}, 1000*median(d), prctile(d,25), prctile(d,75), ...
        100*mean(d > 0), ...
        100*mean(d(E >= E_threshold) > 0), ...
        100*mean(d(E <  E_threshold) > 0));
end
fprintf('\n');


%% ===== PRINT SUMMARY TABLES AND SPEARMAN ANALYSIS =====
E_threshold = 50;   % kWh 

% Parameter names for Spearman analysis
param_fields = {'E_pack_nom', 'L', 'nu', 'delta_loss', 'r_CBP', ...
                'alpha_CBP', 'Y_EV', 'SOH_EOL_SecondLife_CBP', ...
                'SOH_EOL_SecondLife_RBP'};
param_labels = {'$E^{\mathrm{nom}}_{\mathrm{pack}}$', '$L$', '$\nu$', ...
                '$\delta_{\mathrm{loss}}$', '$r$', '$\alpha_{\mathrm{CBP}}$', ...
                '$Y_{\mathrm{EV}}$', '$\mathrm{SOH}_{\mathrm{EOL2,CBP}}$', ...
                '$\mathrm{SOH}_{\mathrm{EOL2,RBP}}$'};
n_params = numel(param_fields);

fprintf('\n=== Panel (a): Electricity price sensitivity ===\n');
fprintf('  %-22s  %8s  %8s  %8s  %8s  %10s  %10s\n', ...
    'Scenario', 'Median', 'P25', 'P75', 'Frac>0', ...
    sprintf('E>=%dkWh', E_threshold), ...
    sprintf('E<%dkWh',  E_threshold));

rho_en = zeros(n_en, n_params);
for s = 1:n_en
    d     = delta_NPC_en{s};
    E     = samples_en{s}.E_pack_nom;
    fprintf('  %-22s  %8.2f  %8.2f  %8.2f  %7.1f%%  %9.1f%%  %9.1f%%\n', ...
        labels_en{s}, 1000*median(d), prctile(d,25), prctile(d,75), ...
        100*mean(d > 0), ...
        100*mean(d(E >= E_threshold) > 0), ...
        100*mean(d(E <  E_threshold) > 0));

    % Spearman correlations for this scenario
    for p = 1:n_params
        field = param_fields{p};
        if isfield(samples_en{s}, field)
            x = double(samples_en{s}.(field));
            if isnumeric(x)
                rho_en(s, p) = corr(x, d, 'type', 'Spearman');
            end
        end
    end
end

fprintf('\n  Spearman correlations with delta_NPC — Electricity price scenarios:\n');
fprintf('  %-30s', 'Parameter');
for s = 1:n_en
    fprintf('  %18s', labels_en{s});
end
fprintf('\n');
for p = 1:n_params
    fprintf('  %-30s', param_labels{p});
    for s = 1:n_en
        fprintf('  %18.3f', rho_en(s, p));
    end
    fprintf('\n');
end

% Identify dominant parameter per scenario
fprintf('\n  Dominant parameter per electricity price scenario:\n');
for s = 1:n_en
    [~, idx] = max(abs(rho_en(s, :)));
    fprintf('  %s: %s (rho = %.3f)\n', labels_en{s}, param_labels{idx}, rho_en(s, idx));
end


fprintf('\n=== Panel (b): Energy consumption sensitivity ===\n');
fprintf('  %-22s  %8s  %8s  %8s  %8s  %10s  %10s\n', ...
    'Scenario', 'Median', 'P25', 'P75', 'Frac>0', ...
    sprintf('E>=%dkWh', E_threshold), ...
    sprintf('E<%dkWh',  E_threshold));

rho_eta = zeros(n_eta, n_params);
for s = 1:n_eta
    d     = delta_NPC_eta{s};
    E     = samples_eta{s}.E_pack_nom;
    fprintf('  %-22s  %8.2f  %8.2f  %8.2f  %7.1f%%  %9.1f%%  %9.1f%%\n', ...
        labels_eta{s}, 1000*median(d), prctile(d,25), prctile(d,75), ...
        100*mean(d > 0), ...
        100*mean(d(E >= E_threshold) > 0), ...
        100*mean(d(E <  E_threshold) > 0));

    % Spearman correlations for this scenario
    for p = 1:n_params
        field = param_fields{p};
        if isfield(samples_eta{s}, field)
            x = double(samples_eta{s}.(field));
            if isnumeric(x)
                rho_eta(s, p) = corr(x, d, 'type', 'Spearman');
            end
        end
    end
end

fprintf('\n  Spearman correlations with delta_NPC — Energy consumption scenarios:\n');
fprintf('  %-30s', 'Parameter');
for s = 1:n_eta
    fprintf('  %18s', labels_eta{s});
end
fprintf('\n');
for p = 1:n_params
    fprintf('  %-30s', param_labels{p});
    for s = 1:n_eta
        fprintf('  %18.3f', rho_eta(s, p));
    end
    fprintf('\n');
end

% Identify dominant parameter per scenario
fprintf('\n  Dominant parameter per energy consumption scenario:\n');
for s = 1:n_eta
    [~, idx] = max(abs(rho_eta(s, :)));
    fprintf('  %s: %s (rho = %.3f)\n', labels_eta{s}, param_labels{idx}, rho_eta(s, idx));
end

% Cross-scenario stability check: does ranking of top-3 parameters change?
fprintf('\n  Parameter ranking stability across electricity price scenarios:\n');
[~, rank_en] = sort(abs(rho_en), 2, 'descend');
for s = 1:n_en
    fprintf('  %s: ', labels_en{s});
    for k = 1:3
        fprintf('%s (%.3f)  ', param_labels{rank_en(s,k)}, rho_en(s, rank_en(s,k)));
    end
    fprintf('\n');
end

fprintf('\n  Parameter ranking stability across energy consumption scenarios:\n');
[~, rank_eta] = sort(abs(rho_eta), 2, 'descend');
for s = 1:n_eta
    fprintf('  %s: ', labels_eta{s});
    for k = 1:3
        fprintf('%s (%.3f)  ', param_labels{rank_eta(s,k)}, rho_eta(s, rank_eta(s,k)));
    end
    fprintf('\n');
end



%% ===== FIGURE: TWO-PANEL COMBINED PLOT =====
% Colour-blind-safe palette following Wong (2011, Nature Methods).
col_low      = [ 86, 180, 233] / 255;   % sky blue   — low scenario
col_baseline = [  0, 114, 178] / 255;   % blue       — baseline
col_high     = [213,  94,   0] / 255;   % vermillion — high scenario
col_prices   = [col_low; col_baseline; col_high];

paperWidth  = 18.0;      % 180 mm, Nature 2-column original research
paperHeight = 10.0; %16.0;      % 
figCombined = figure( ...
    'Units', 'centimeters', ...
    'Position', [2 2 paperWidth paperHeight], ...
    'Color', 'w');
tl = tiledlayout(figCombined, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ylims_shared  = [-3 3.5];
yticks_shared = [-3 0 3];


% ------------------------------------------------------------------
% Panel (a): Electricity price
% ------------------------------------------------------------------
axEn = nexttile(tl);
hold(axEn, 'on');

for s = 1:n_en
    data_s = delta_NPC_en{s};
    bc = boxchart(axEn, s * ones(size(data_s)), data_s, ...
        'BoxFaceColor', col_prices(s,:), ...
        'BoxFaceAlpha', 0.6, ...
        'MarkerStyle',  'none');
    bc.JitterOutliers = 'off';
end

%yline(axEn, 0, '--k', 'LineWidth', 1.2);

% Annotate median and fraction-positive above each box
for s = 1:n_en
    d = delta_NPC_en{s};
    edgeColor   = col_prices(s,:);
    bgColor   = 0.10*edgeColor + 0.90*[1 1 1];
    text(axEn, s, ylims_shared(2) * 0.85, ...
        sprintf('Median: %4.0f EUR\n%.1f%% >0', 1000*median(d), 100*mean(d>0)), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment',   'top', ...
        'FontSize', 7, ...
        'Color','black','Interpreter', 'tex', 'EdgeColor',edgeColor,'BackgroundColor',bgColor, ...
        'FontName', 'Helvetica','Margin',1);
end

set(axEn, ...
    'XTick',               1:n_en, ...
    'XTickLabel',          labels_en, ...
    'YTick',               yticks_shared, ...
    'TickLabelInterpreter','tex', ...
    'FontName',            'Helvetica', ...
    'FontSize',            7);
ylim(axEn, ylims_shared);
ylabel(axEn, '\DeltaNPC [kEUR]', ...
    'Interpreter', 'tex', 'FontName', 'Helvetica');
xlabel(axEn, 'Electricity price [EUR/kWh]', ...
    'Interpreter', 'tex', 'FontName', 'Helvetica');
grid(axEn, 'on'); box(axEn, 'on');
addPanelLabel(axEn, '(\bfa\rm)', 0.05, 0.98, 7);
hold(axEn, 'off');


% ------------------------------------------------------------------
% Panel (b): Energy consumption
% ------------------------------------------------------------------
axEta = nexttile(tl);
hold(axEta, 'on');

for s = 1:n_eta
    data_s = delta_NPC_eta{s};
    bc = boxchart(axEta, s * ones(size(data_s)), data_s, ...
        'BoxFaceColor', col_prices(s,:), ...
        'BoxFaceAlpha', 0.6, ...
        'MarkerStyle',  'none');
    bc.JitterOutliers = 'off';
end

%yline(axEta, 0, '--k', 'LineWidth', 1.2);

for s = 1:n_eta
    d = delta_NPC_eta{s};
    edgeColor   = col_prices(s,:);
    bgColor   = 0.10*edgeColor + 0.90*[1 1 1];  
    text(axEta, s, ylims_shared(2) * 0.85, ...
        sprintf('Median: %4.0f EUR\n%.1f%% >0', 1000*median(d), 100*mean(d>0)), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment',   'top', ...
        'FontSize', 7, ...
        'Color','black','Interpreter', 'tex','EdgeColor',edgeColor,'BackgroundColor',bgColor, ...
        'FontName', 'Helvetica','Margin',1);
end

set(axEta, ...
    'XTick',               1:n_eta, ...
    'XTickLabel',          labels_eta, ...
    'YTick',               yticks_shared, ...
    'TickLabelInterpreter','tex', ...
    'FontName',            'Helvetica', ...
    'FontSize',            7);
ylim(axEta, ylims_shared);
ylabel(axEta, '\DeltaNPC [kEUR]', ...
    'Interpreter', 'tex', 'FontName', 'Helvetica');
xlabel(axEta, 'Energy consumption [kWh/km]', ...
    'Interpreter', 'tex', 'FontName', 'Helvetica');
grid(axEta, 'on'); box(axEta, 'on');
addPanelLabel(axEta, '(\bfb\rm)', 0.05, 0.98, 7);
hold(axEta, 'off');



%% ===== EXPORT =====
set(figCombined, ...
    'Units', 'centimeters', ...
    'Position', [2 2 paperWidth paperHeight], ...
    'PaperUnits', 'centimeters', ...
    'PaperSize', [paperWidth paperHeight], ...
    'PaperPosition', [0 0 paperWidth paperHeight], ...
    'PaperPositionMode', 'manual', ...
    'Color', 'w');

drawnow;

exportgraphics(figCombined, OUT_PDF, 'ContentType', 'vector', 'BackgroundColor', 'white');
saveas(figCombined, OUT_FIG);
fprintf('Combined energy sensitivity figure exported to:\n  %s\n', OUT_PDF);




%% ========================================================================
%  LOCAL HELPER FUNCTIONS
%  (copied from Fig5_SuppFig2_SuppFig3_v5.m to keep this file self-contained)
%% ========================================================================



% -------------------------------------------------------------------------
% GETPARAMS
% -------------------------------------------------------------------------
function paramsOut = getParams(varargin)
    defaultParams = struct( ...
        'E_pack_nom',               80, ...
        'V_pack_nom',               800, ...
        'V_nom_module',             50, ...
        'Chemistry',                "LFP", ...
        'UserSelection',            1, ...
        'Y_EV',                     18.8, ...
        'Y_CBP',                    10, ...
        'r_CBP',                    0.03, ...
        'r_RBP',                    0.03, ...
        'alpha_CBP',                0.02, ...
        'alpha_RBP',                0.02 * 0.5, ...
        'delta_loss',               0.03, ...
        'SOH_EOL_FirstLife_CBP',    0.8, ...
        'SOH_EOL_FirstLife_RBP',    0.8, ...
        'SOH_EOL_SecondLife_CBP',   0.55, ...
        'SOH_EOL_SecondLife_RBP',   0.45, ...
        'c_pack_USDperkWh',         115, ...
        'currExch_USDtoEUR',        0.8554, ...
        'c_en_EURperkWh',           0.24, ...
        'eta_en_kWhkm',             0.2, ...
        'L',                        12000, ...
        'nu',                       0.075, ...
        'c_res_CBP_USDperkWh',      22.99, ...
        'c_res_RBP_USDperkWh',      22.99, ...
        'c_res_depreccoeff',        0.5, ...
        'DefaultIndicator',         true ...
    );

    defaultParams.c_res_CBP_EURperkWh = defaultParams.c_res_CBP_USDperkWh * defaultParams.currExch_USDtoEUR;
    defaultParams.c_res_RBP_EURperkWh = defaultParams.c_res_RBP_USDperkWh * defaultParams.currExch_USDtoEUR;

    if nargin == 0
        overrideParams = struct();
    else
        overrideParams = struct(varargin{:});
    end

    paramsOut = mergeStructs(defaultParams, overrideParams);

    chem = string(paramsOut.Chemistry);
    V    = paramsOut.V_pack_nom;

    switch chem
        case "LFP"
            chi_mu_perc = 1.54 * log(V) + 1.06;
            if V == 800
                bounds = [9.4439, 12.8275];
            else
                error("Unsupported V_pack_nom for LFP");
            end
        case "NMC"
            chi_mu_perc = 4.06 * log(V) - 1.91;
            if V == 800
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
        chi_percent = bounds(1) + (bounds(2) - bounds(1)) * rand;
    end

    paramsOut.Y_RBP = paramsOut.Y_CBP * (1 + chi_percent / 100);
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
    ranges.Y_EV.LIMITS                    = [15, 20];
    ranges.r_CBP.LIMITS                   = [0.02, 0.04];
    ranges.alpha_CBP.LIMITS               = [0.01, 0.03];
    ranges.delta_loss.LIMITS              = [0.01, 0.05];
    ranges.L.LIMITS                       = [5000, 70000];
    ranges.nu.LIMITS                      = [0.01, 0.15];
    ranges.E_pack_nom.LIMITS              = [20, 120];
    ranges.E_pack_nom_detailed            = 20:20:120;
    ranges.n_E                            = numel(ranges.E_pack_nom_detailed);
    ranges.SOH_EOL_SecondLife_CBP.LIMITS  = [0.50, 0.60];
    ranges.SOH_EOL_SecondLife_RBP.LIMITS  = [0.40, 0.50];
    ranges.Chemistry.LIST                 = ["LFP", "NMC"];
    ranges.n_chem                         = numel(ranges.Chemistry.LIST);

    assertLimits(ranges.Y_EV.LIMITS,                   'Y_EV');
    assertLimits(ranges.r_CBP.LIMITS,                  'r_CBP');
    assertLimits(ranges.alpha_CBP.LIMITS,              'alpha_CBP');
    assertLimits(ranges.delta_loss.LIMITS,             'delta_loss');
    assertLimits(ranges.L.LIMITS,                      'L');
    assertLimits(ranges.nu.LIMITS,                     'nu');
    assertLimits(ranges.E_pack_nom.LIMITS,             'E_pack_nom');
    assertLimits(ranges.SOH_EOL_SecondLife_CBP.LIMITS, 'SOH_EOL_SecondLife_CBP');
    assertLimits(ranges.SOH_EOL_SecondLife_RBP.LIMITS, 'SOH_EOL_SecondLife_RBP');
end



% -------------------------------------------------------------------------
% ASSERTLIMITS
% -------------------------------------------------------------------------
function assertLimits(lim, name)
    if ~(isnumeric(lim) && isvector(lim) && numel(lim) == 2 && all(isfinite(lim)))
        error('getParamRanges:InvalidLimits', ...
              'Field "%s.LIMITS" must be a 1x2 finite numeric vector.', name);
    end
    if lim(1) > lim(2)
        error('getParamRanges:LimitsOrder', ...
              'Field "%s.LIMITS" must satisfy min <= max.', name);
    end
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

    n_E       = ranges.n_E;
    E_indices = min(ceil(X(:,7) * n_E), n_E);
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

    n_total       = n_samples;
    delta_NPC_out = zeros(n_total, 1);

    p_first = getParams(getSampleStruct(samples_out, 1));
    p_first.c_en_EURperkWh = params_baseline.c_en_EURperkWh;
    p_first.eta_en_kWhkm   = params_baseline.eta_en_kWhkm;
    result_first = computeNPC_DiscAndNonDisc(p_first);
    delta_NPC_out(1) = result_first.delta_NPC;

    results_out = repmat(result_first, n_total, 1);
    p_out       = repmat(p_first,      n_total, 1);

    for i = 2:n_total
        p_i = getParams(getSampleStruct(samples_out, i));
        p_i.c_en_EURperkWh = params_baseline.c_en_EURperkWh;
        p_i.eta_en_kWhkm   = params_baseline.eta_en_kWhkm;
        result_i           = computeNPC_DiscAndNonDisc(p_i);
        p_out(i)           = p_i;
        results_out(i)     = result_i;
        delta_NPC_out(i)   = result_i.delta_NPC;
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
% COMPUTENPC_DISCANDNONDSC
% -------------------------------------------------------------------------
function results = computeNPC_DiscAndNonDisc(params)
    mustHave(params, {'Y_EV','Y_CBP','Y_RBP','E_pack_nom','c_pack_USDperkWh','currExch_USDtoEUR', ...
                      'c_en_EURperkWh','eta_en_kWhkm','L','r_CBP','r_RBP','alpha_CBP','alpha_RBP', ...
                      'delta_loss','nu','SOH_EOL_FirstLife_CBP','SOH_EOL_FirstLife_RBP', ...
                      'SOH_EOL_SecondLife_CBP','SOH_EOL_SecondLife_RBP','c_res_depreccoeff'});

    Y_EV       = params.Y_EV;
    Y_EV_floor = floor(Y_EV);
    d_Y_EV     = Y_EV - Y_EV_floor;
    Y_EV_array = 1:1:ceil(Y_EV);

    Cost_Init_CBP   = params.E_pack_nom * params.c_pack_USDperkWh * params.currExch_USDtoEUR;
    Cost_Init_RBP   = (1 + params.nu) * Cost_Init_CBP;

    Cost_energy_CBP = params.c_en_EURperkWh * params.eta_en_kWhkm * params.L;
    Cost_energy_RBP = (1 + params.delta_loss) * Cost_energy_CBP;

    Cost_ResidualValue_CBP = computeResidual_DiscAndNonDisc( ...
        params, params.Y_CBP, params.r_CBP, Cost_Init_CBP, ...
        params.SOH_EOL_FirstLife_CBP, params.SOH_EOL_SecondLife_CBP);

    Cost_ResidualValue_RBP = computeResidual_DiscAndNonDisc( ...
        params, params.Y_RBP, params.r_RBP, Cost_Init_RBP, ...
        params.SOH_EOL_FirstLife_RBP, params.SOH_EOL_SecondLife_RBP);

    cbpInputs = struct( ...
        'Y_EV',             Y_EV, ...
        'Y_EV_floor',       Y_EV_floor, ...
        'd_Y_EV',           d_Y_EV, ...
        'Y_battPack',       params.Y_CBP, ...
        'initCost',         Cost_Init_CBP, ...
        'alphaOM',          params.alpha_CBP, ...
        'energyCost',       Cost_energy_CBP, ...
        'discountRate',     params.r_CBP, ...
        'E_pack_nom',       params.E_pack_nom, ...
        'RV_discounted',    Cost_ResidualValue_CBP.RV_discounted, ...
        'RV_nondiscounted', Cost_ResidualValue_CBP.RV_nondiscounted, ...
        't_residuals',      Cost_ResidualValue_CBP.t_residuals, ...
        'nu',               0);
    [~, Cost_Yearly_Total_CBP_d, ~] = computeAnnualCosts_DiscAndNonDisc(cbpInputs);

    rbpInputs = struct( ...
        'Y_EV',             Y_EV, ...
        'Y_EV_floor',       Y_EV_floor, ...
        'd_Y_EV',           d_Y_EV, ...
        'Y_battPack',       params.Y_RBP, ...
        'initCost',         Cost_Init_RBP, ...
        'alphaOM',          params.alpha_RBP, ...
        'energyCost',       Cost_energy_RBP, ...
        'discountRate',     params.r_RBP, ...
        'E_pack_nom',       params.E_pack_nom, ...
        'RV_discounted',    Cost_ResidualValue_RBP.RV_discounted, ...
        'RV_nondiscounted', Cost_ResidualValue_RBP.RV_nondiscounted, ...
        't_residuals',      Cost_ResidualValue_RBP.t_residuals, ...
        'nu',               params.nu);
    [~, Cost_Yearly_Total_RBP_d, ~] = computeAnnualCosts_DiscAndNonDisc(rbpInputs);

    NPC_CBP   = Cost_Init_CBP + Cost_Yearly_Total_CBP_d - Cost_ResidualValue_CBP.RV_total_discounted;
    NPC_RBP   = Cost_Init_RBP + Cost_Yearly_Total_RBP_d - Cost_ResidualValue_RBP.RV_total_discounted;
    delta_NPC = NPC_CBP - NPC_RBP;

    results.years     = Y_EV_array;
    results.delta_NPC = delta_NPC;

    results.CBP.costs.InitCost                    = Cost_Init_CBP;
    results.CBP.costs.TotalAnnualCosts.discounted = Cost_Yearly_Total_CBP_d;
    results.CBP.costs.NPC                         = NPC_CBP;
    results.CBP.costs.RV_discounted               = Cost_ResidualValue_CBP.RV_total_discounted;
    results.CBP.SOH_EOL_Pack                      = Cost_ResidualValue_CBP.SOH_EOL_Pack;
    results.CBP.SOH_residual                      = Cost_ResidualValue_CBP.SOH_residual;
    results.CBP.residualStruct                    = Cost_ResidualValue_CBP;

    results.RBP.costs.InitCost                    = Cost_Init_RBP;
    results.RBP.costs.TotalAnnualCosts.discounted = Cost_Yearly_Total_RBP_d;
    results.RBP.costs.NPC                         = NPC_RBP;
    results.RBP.costs.RV_discounted               = Cost_ResidualValue_RBP.RV_total_discounted;
    results.RBP.SOH_EOL_Pack                      = Cost_ResidualValue_RBP.SOH_EOL_Pack;
    results.RBP.SOH_residual                      = Cost_ResidualValue_RBP.SOH_residual;
    results.RBP.residualStruct                    = Cost_ResidualValue_RBP;

    % Dummy fields for compatibility with calling code using full results struct
    dummy = zeros(1, numel(Y_EV_array));
    for xi = {'CBP','RBP'}
        for fi = {'energy','oandm','replacement','residual'}
            results.(xi{1}).costs.AnnualCosts.discounted.(fi{1}) = dummy;
        end
    end
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

    n_packs          = numel(t_replace);
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

        if i == 1
            RV_nondiscounted(i)    = SOH_residual(i) * Cost_Init_battPack * params.c_res_depreccoeff;
            Cost_Init_battPack_new = getReplCost(t_replace(i), E_nom);
        else
            RV_nondiscounted(i)    = SOH_residual(i) * Cost_Init_battPack_new * params.c_res_depreccoeff;
        end
        RV_discounted(i) = RV_nondiscounted(i) / ((1 + r_battPack)^t_replace(i));
    end

    output.RV_total_discounted    = sum(RV_discounted);
    output.RV_total_nondiscounted = sum(RV_nondiscounted);
    output.RV_discounted          = RV_discounted;
    output.RV_nondiscounted       = RV_nondiscounted;
    output.t_residuals            = t_replace;
    output.SOH_EOL_Pack           = SOH_EOL_Pack;
    output.SOH_residual           = SOH_residual;
end



% -------------------------------------------------------------------------
% GETREPLCOST
% -------------------------------------------------------------------------
function replCost_EUR = getReplCost(t, E_pack_nom)
    p1  = 172.0648;
    p2  = 0.1420;
    p3  = 63.0950;
    t0  = 2017;
    yr0 = 2025;
    FX  = 0.8554;

    year               = yr0 + t;
    replCost_USDperkWh = p1 .* exp(-p2 .* (year - t0)) + p3;
    replCost_EUR       = FX .* replCost_USDperkWh .* E_pack_nom;
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

    if isfield(inputs,'RV_discounted') && isfield(inputs,'RV_nondiscounted') && isfield(inputs,'t_residuals')
        RV_discounted    = inputs.RV_discounted;
        RV_nondiscounted = inputs.RV_nondiscounted;
        t_residuals      = inputs.t_residuals;
        RV_years         = ceil(t_residuals);
    else
        RV_discounted    = [];
        RV_nondiscounted = [];
        RV_years         = [];
    end

    max_n            = floor(Y_EV / Y_battPack);
    t_replace        = Y_battPack * (1:max_n);
    replacementYears = ceil(t_replace);
    frac_old         = mod(t_replace, 1);
    frac_new         = 1 - frac_old;

    replacementSchedule.t_replace        = t_replace;
    replacementSchedule.replacementYears = replacementYears;
    replacementSchedule.frac_old         = frac_old;
    replacementSchedule.frac_new         = frac_new;

    Y_max = Y_EV_floor + (d_Y_EV > 0);

    D.energy      = zeros(1, Y_max);
    D.oandm       = zeros(1, Y_max);
    D.replacement = zeros(1, Y_max);
    D.residual    = zeros(1, Y_max);
    ND = D;

    currentCapitalCost = initCost;

    for year = 1:Y_max
        discountFactor = (1 + discountRate)^year;
        yearWeight     = 1.0;
        if year > Y_EV_floor
            yearWeight = d_Y_EV;
        end

        D.energy(year)  = yearWeight * energyCost / discountFactor;
        ND.energy(year) = yearWeight * energyCost;

        idx_repl = find(replacementYears == year, 1, 'first');
        if ~isempty(idx_repl)
            actualTime            = t_replace(idx_repl);
            discountFactor_actual = (1 + discountRate)^actualTime;
            newCapitalCost        = getReplCost(actualTime, E_pack_nom) * (1 + nu);

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
            omCost         = yearWeight * alphaOM * currentCapitalCost;
            D.oandm(year)  = omCost / discountFactor;
            ND.oandm(year) = omCost;
        end

        if ~isempty(RV_years)
            idx_rv = find(RV_years == year);
            if ~isempty(idx_rv)
                D.residual(year)  = -sum(RV_discounted(idx_rv));
                ND.residual(year) = -sum(RV_nondiscounted(idx_rv));
            end
        end
    end

    D.totalPerYear  = D.energy + D.oandm + D.replacement + D.residual;
    ND.totalPerYear = ND.energy + ND.oandm + ND.replacement + ND.residual;

    costs                   = struct('discounted', D, 'nondiscounted', ND);
    totalCost               = sum(D.totalPerYear);
    totalCost_nondiscounted = sum(ND.totalPerYear);
end



% -------------------------------------------------------------------------
% MUSTHAVE
% -------------------------------------------------------------------------
function mustHave(s, names)
    for k = 1:numel(names)
        if ~isfield(s, names{k})
            error('computeNPC:MissingField', 'Required field "%s" is missing.', names{k});
        end
    end
end



% -------------------------------------------------------------------------
% ADDPANELLABEL
% -------------------------------------------------------------------------
function addPanelLabel(ax, label, offsetX, offsetY, fontSize)
    if nargin < 3 || isempty(offsetX), offsetX = -0.12; end
    if nargin < 4 || isempty(offsetY), offsetY = 1.02;  end
    if nargin < 5 || isempty(fontSize), fontSize = 7;  end

    text(ax, offsetX, offsetY, label, ...
        'Units',               'normalized', ...
        'FontSize',            fontSize, ...
        'FontWeight',          'bold', ...
        'Interpreter',         'tex', ...
        'FontName',            'Helvetica', ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment',   'top');
end