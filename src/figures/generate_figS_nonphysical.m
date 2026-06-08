function generate_figS_nonphysical(pred, np, cfg)
% GENERATE_FIGS_NONPHYSICAL — depth distribution of non-physical samples
%   colored by OOD flag status.
%   Author: RCW (2026-06)

addpath(fullfile(cfg.matlab_root, 'src', 'utils'));

fig = figure('Position', [100 100 800 800], 'Color', 'w');

depth = pred.depth;
ood = logical(pred.ood);
np_any = np.flag_any;

depth_np_ood = depth(np_any & ood);
depth_np_nonood = depth(np_any & ~ood);
depth_ok = depth(~np_any);

% Plot 1: depth histogram of non-physical samples
subplot(1, 2, 1);
scatter(zeros(size(depth_ok)), depth_ok, 6, [0.85 0.85 0.85], ...
        'filled', 'MarkerFaceAlpha', 0.3, 'DisplayName', 'Physical');
hold on;
scatter(ones(size(depth_np_ood)),  depth_np_ood, 30, [0.8 0.2 0.2], ...
        'filled', 'DisplayName', sprintf('Non-physical AND OOD (n=%d)', ...
        numel(depth_np_ood)));
scatter(2*ones(size(depth_np_nonood)), depth_np_nonood, 30, [0.2 0.4 0.85], ...
        'filled', 'DisplayName', sprintf('Non-physical AND non-OOD (n=%d)', ...
        numel(depth_np_nonood)));
set(gca, 'YDir', 'reverse');
xlim([-0.5 2.5]);
set(gca, 'XTick', [0 1 2], 'XTickLabel', {'Physical','NP+OOD','NP+non-OOD'});
ylabel('Depth (m)');
title('Non-physical excursions by depth');
legend('Location', 'eastoutside', 'FontSize', cfg.fig.font_size - 2);
grid on;

% Plot 2: summary text
subplot(1, 2, 2);
axis off;
total = np.totals.n_total;
text(0.05, 0.95, sprintf('Total deployment samples: %d', total), 'FontSize', 11);
text(0.05, 0.85, sprintf('Non-physical total: %d (%.2f%%)', ...
     np.totals.n_np_total, 100*np.totals.n_np_total/total), 'FontSize', 11);
text(0.05, 0.75, sprintf('Within OOD subset: %d (%.1f%%)', ...
     np.totals.n_np_ood, 100*np.totals.n_np_ood/max(sum(ood),1)), 'FontSize', 11);
text(0.05, 0.65, sprintf('Within non-OOD: %d (%.2f%%)', ...
     np.totals.n_np_non_ood, ...
     100*np.totals.n_np_non_ood/max(sum(~ood),1)), 'FontSize', 11);
text(0.05, 0.55, sprintf('Silent failures: %.1f%% of total NP', ...
     np.totals.silent_pct), 'FontSize', 11, 'FontWeight', 'bold');

sgtitle('Non-physical diagnostic — supplementary', ...
        'FontSize', cfg.fig.font_size + 1, 'FontWeight', 'bold');

out_path = fullfile(cfg.figures_dir, 'FigS_NEJ-2_nonphysical_diagnostic.png');
save_figure_safe(fig, out_path, cfg.fig.dpi);
close(fig);
end
