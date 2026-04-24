function run_all_figures

    thisFile = mfilename('fullpath');
    CODE_DIR = fileparts(thisFile);
    addpath(genpath(CODE_DIR));

    % --- Batch process simulation results ---
    cd(fullfile(CODE_DIR, 'batchProcessData'));
    batchProcessData;    
    CODE_DIR = fileparts(mfilename('fullpath'));  % recompute after clear; in script    

    % --- Fig 3 ---
    cd(fullfile(CODE_DIR, 'fig3'));
    Fig3_SuppFig1;

    % --- Fig 4 ---
    cd(fullfile(CODE_DIR, 'fig4'));
    Fig4_SuppTableS2;

    % --- Fig 5 ---
    cd(fullfile(CODE_DIR, 'fig5'));
    Fig5_SuppFig2_SuppFig3;
    Fig5_SuppFig_EnergySensitivity;

    % --- Restore working directory ---
    cd(CODE_DIR);    

    fprintf('\nAll figures successfully generated. Check /results/\n');
    
end
