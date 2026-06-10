function run_all_figures

    thisFile = mfilename('fullpath');
    CODE_DIR = fileparts(thisFile);
    addpath(genpath(CODE_DIR));

    % --- Batch process simulation results ---
    % cd(fullfile(CODE_DIR, 'batchProcessData'));
    % batchProcessData;    
    % CODE_DIR = fileparts(mfilename('fullpath')); 

    % --- Fig 3 (sensitivity boxplots; paper Fig 2) ---
    cd(fullfile(CODE_DIR, 'fig2'));
    Fig2_SuppFig2;

    % --- Fig 4 (EV case study + fitting; paper Fig 3) ---
    cd(fullfile(CODE_DIR, 'fig3'));
    Fig3_SuppTableS4;

    % % --- Fig 5 (cost + sensitivity analysis; paper Figs 4 & 5) ---
    cd(fullfile(CODE_DIR, 'fig4-5'));
    Fig4_5_SuppFig3_SuppFig4;        
    SuppFig5;

    % --- Restore working directory ---
    cd(CODE_DIR);

    fprintf('\nAll figures successfully generated. Check /results/\n');

end
