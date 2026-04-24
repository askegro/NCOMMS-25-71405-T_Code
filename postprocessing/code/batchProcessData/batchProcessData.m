% =========================================================================
% Batch processor for battery lifetime extension simulation results.
% Scans data/raw/ for matching .mat files, extracts metadata from
% filenames, computes summary statistics, and saves results.
%
% Expected filename format:
%   out_<Chem>_TC_<N>_Ns_<N>_T_<N>_Tsig_<N>_Trest_<N>_1000[_new].mat
%
% Output: results_summary_2026_06.mat  (written to data/)
%   - resultsEFC_2026_06 : lifetime extension statistics (EFC-based)
% =========================================================================
clear;

% --- Resolve paths relative to this script's location -------------------
scriptDir = fileparts(mfilename('fullpath'));
dataDir   = fullfile(scriptDir, '..', '..', 'data', 'raw');
outputDir = fullfile(scriptDir, '..', '..', 'data');

% --- Configuration -------------------------------------------------------
FILENAME_PATTERN = ...
    'out_(\w+)_TC_(\d+)_Ns_(\d+)_T_(\d+)_Tsig_(\d+)_Trest_(\d+)_1000(_new)?\.mat';
OUTPUT_FILE   = 'results_summary_2026_06.mat';
COL_NAMES_EFC = {'FileName','Chemistry','TC','Ns','Temp','Tsig','Trest', ...
                  'minEFC','meanEFC','stdEFC','maxEFC','CVEFC'};

% --- Collect files -------------------------------------------------------
% Gather versioned (*_1000_new.mat) and unversioned (*_1000.mat) files.
% The two globs are mutually exclusive: *_1000.mat does NOT match *_1000_new.mat.
fileList = [ dir(fullfile(dataDir, '*_1000_new.mat')); ...
             dir(fullfile(dataDir, '*_1000.mat')) ];
nFiles   = numel(fileList);
fprintf('Found %d candidate file(s).\n\n', nFiles);

% Pre-allocate row storage
rowsEFC = cell(nFiles, numel(COL_NAMES_EFC));
nValid  = 0;

% --- Main loop -----------------------------------------------------------
for i = 1:nFiles
    fileName = fileList(i).name;
    filePath = fullfile(fileList(i).folder, fileName);   % FIX: full path for load
    fprintf('[%d/%d] %s\n', i, nFiles, fileName);

    % -- Parse metadata from filename -------------------------------------
    tokens = regexp(fileName, FILENAME_PATTERN, 'tokens');
    if isempty(tokens)
        warning('  Filename does not match expected pattern.');
        fprintf('  -----------------------------------------\n');
        continue
    end

    tok   = tokens{1};
    chem  = tok{1};
    tc    = str2double(tok{2});
    ns    = str2double(tok{3});
    temp  = str2double(tok{4});
    tsig  = str2double(tok{5});
    trest = str2double(tok{6});
    fprintf('  Chem: %s | TC: %d | Ns: %d | T: %d°C | Tsig: %d | Trest: %d\n', ...
            chem, tc, ns, temp, tsig, trest);

    % -- Load data and compute statistics ---------------------------------
    data    = load(filePath);                            % FIX: use full path
    chi_EFC = data.Outputs.chi_EFC_perc_All(:);

    [minEFC, meanEFC, stdEFC, maxEFC, CVEFC] = summaryStats(chi_EFC);
    fprintf('  EFC  — min: %.4f | mean: %.4f | std: %.4f | max: %.4f | CV: %.4f\n', ...
            minEFC, meanEFC, stdEFC, maxEFC, CVEFC);

    % -- Store row --------------------------------------------------------
    nValid = nValid + 1;
    meta   = {fileName, chem, tc, ns, temp, tsig, trest};
    rowsEFC(nValid, :) = [meta, {minEFC, meanEFC, stdEFC, maxEFC, CVEFC}];
    fprintf('  -----------------------------------------\n');
end

% --- Build table and save ------------------------------------------------
resultsEFC_2026_06 = cell2table(rowsEFC(1:nValid, :), 'VariableNames', COL_NAMES_EFC);

outputPath = fullfile(outputDir, OUTPUT_FILE);
save(outputPath, 'resultsEFC_2026_06');              % FIX: named var + correct path

fprintf('\nDone. Processed %d/%d file(s). Results saved to:\n  %s\n', ...
        nValid, nFiles, outputPath);

% =========================================================================
% Local helper: compute min, mean, std, max, and coefficient of variation
% =========================================================================
function [mn, mu, sg, mx, cv] = summaryStats(x)
    mn = min(x);
    mu = mean(x);
    sg = std(x);
    mx = max(x);
    cv = sg / mu;
end