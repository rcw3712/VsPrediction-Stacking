function make_all_publication_figures(M, ranking, D_train, test_idx, ...
                                       Vs_pred_test_kms, emp_test_kms_struct, ...
                                       D_blind, pred, np, outdir, cfg)
% MAKE_ALL_PUBLICATION_FIGURES — master orchestrator for the 6 pub figures.
%
%   Generates:
%     - Fig4_model_ranking_pub.png/pdf
%     - Fig5_NEJ-1_multitrack_pub.png/pdf
%     - Fig6_NEJ-2_multitrack_pub.png/pdf
%     - Fig7_NEJ-2_Vp-Vs_crossplot_pub.png/pdf
%     - Fig8_uncertainty_pub.png/pdf
%     - FigS_NEJ-2_nonphysical_diagnostic_pub.png/pdf
%
%   Each figure is generated in a try/catch so one failure does not block
%   the rest.
%
%   Author: RCW (2026-06)

if ~exist(outdir, 'dir'), mkdir(outdir); end

addpath(fullfile(cfg.matlab_root, 'src', 'figures_publication'));

fprintf('\n========================================================\n');
fprintf('  Generating publication-quality figures\n');
fprintf('  Output: %s\n', outdir);
fprintf('========================================================\n');

fig_failures = strings(0, 1);

% --- Fig 4 (CRITICAL — model ranking)
try
    fig4_model_ranking_pub(M, outdir, cfg, ranking);
catch ME
    fig_failures(end+1) = "Fig4";
    fprintf(2, '\n[FIG-FAIL] Fig4 failed: %s\n', ME.message);
    for s = 1:numel(ME.stack)
        fprintf(2, '    at %s (line %d)\n', ME.stack(s).name, ME.stack(s).line);
    end
end

% --- Fig 5
try
    fig5_NEJ1_multitrack_pub(D_train, test_idx, Vs_pred_test_kms, ...
                              emp_test_kms_struct, outdir, cfg);
catch ME
    fprintf(2, '\n[FIG-FAIL] Fig5 failed: %s\n', ME.message);
    for s = 1:numel(ME.stack)
        fprintf(2, '    at %s (line %d)\n', ME.stack(s).name, ME.stack(s).line);
    end
end

% --- Fig 6 (CRITICAL — NEJ-2 multitrack)
try
    fig6_NEJ2_multitrack_pub(D_blind, pred, outdir, cfg);
catch ME
    fig_failures(end+1) = "Fig6";
    fprintf(2, '\n[FIG-FAIL] Fig6 failed: %s\n', ME.message);
    for s = 1:numel(ME.stack)
        fprintf(2, '    at %s (line %d)\n', ME.stack(s).name, ME.stack(s).line);
    end
end

% --- Fig 7
try
    fig7_NEJ2_crossplot_pub(pred, outdir, cfg);
catch ME
    fprintf(2, '\n[FIG-FAIL] Fig7 failed: %s\n', ME.message);
end

% --- Fig 8
try
    fig8_uncertainty_pub(pred, outdir, cfg);
catch ME
    fprintf(2, '\n[FIG-FAIL] Fig8 failed: %s\n', ME.message);
end

% --- FigS
try
    figS_nonphysical_pub(pred, np, outdir, cfg);
catch ME
    fprintf(2, '\n[FIG-FAIL] FigS failed: %s\n', ME.message);
end

fprintf('========================================================\n');
if isempty(fig_failures)
    fprintf('  ✓ Publication figures complete (Fig4 + Fig6 ok).\n');
else
    fprintf(2, '  ⚠  PUBLICATION PACKAGE INCOMPLETE — critical fig failures: %s\n', ...
            strjoin(fig_failures, ', '));
end
fprintf('========================================================\n\n');
end
