function figS_nonphysical_pub(pred, np, outdir, cfg)
% FIGS_NONPHYSICAL_PUB — supplementary 1×3 layout, no overlapping labels.
%
%   Panel 1: Poisson ratio vs depth (lines at ν=0, ν=0.5)
%   Panel 2: Vs/Vp ratio vs depth (line at 1/sqrt(3) ≈ 0.577 for ν=0)
%   Panel 3: Bar summary OOD vs non-OOD nonphysical counts
%   Plus text box with all summary numbers.
%   Author: RCW (2026-06)

addpath(fullfile(cfg.matlab_root, 'src', 'figures_publication'));

depth = pred.depth;
nu    = pred.nu;
Vs    = pred.Vs_pred;
Vp    = pred.Vp;
ood   = logical(pred.ood);
vs_vp = Vs ./ Vp;

ylim_range = [min(depth), max(depth)];

fig = figure('Position', [40 40 1500 800], 'Color', 'w');

% Panel 1: Poisson
ax1 = subplot(1, 3, 1);
hold(ax1, 'on');
plot(ax1, nu(~ood), depth(~ood), '.', 'Color', [0.30 0.30 0.78], ...
     'MarkerSize', 5, 'DisplayName', 'Non-OOD');
plot(ax1, nu(ood), depth(ood), '.', 'Color', [0.55 0.55 0.55], ...
     'MarkerSize', 5, 'DisplayName', 'OOD');
plot(ax1, [0 0], ylim_range, 'r--', 'LineWidth', 0.9, ...
     'HandleVisibility', 'off');
plot(ax1, [0.5 0.5], ylim_range, 'r--', 'LineWidth', 0.9, ...
     'HandleVisibility', 'off');
set(ax1, 'YDir', 'reverse'); xlim(ax1, [-0.3, 0.7]); ylim(ax1, ylim_range);
xlabel(ax1, '\nu (Poisson)', 'FontName', 'Arial', 'FontSize', 10);
ylabel(ax1, 'Depth (m)', 'FontName', 'Arial', 'FontSize', 11);
title(ax1, 'Poisson ratio', 'FontName', 'Arial', 'FontSize', 12, ...
      'FontWeight', 'bold');
legend(ax1, 'Location', 'best', 'FontName', 'Arial', 'FontSize', 8, ...
       'Box', 'off', 'AutoUpdate', 'off');
apply_pub_style(ax1);

% Panel 2: Vs/Vp ratio
ax2 = subplot(1, 3, 2);
hold(ax2, 'on');
plot(ax2, vs_vp(~ood), depth(~ood), '.', 'Color', [0.30 0.30 0.78], ...
     'MarkerSize', 5, 'HandleVisibility', 'off');
plot(ax2, vs_vp(ood), depth(ood), '.', 'Color', [0.55 0.55 0.55], ...
     'MarkerSize', 5, 'HandleVisibility', 'off');
% Reference at 1/sqrt(3) ≈ 0.577 (Vs/Vp at ν=0)
plot(ax2, [1/sqrt(3) 1/sqrt(3)], ylim_range, 'r--', 'LineWidth', 0.9, ...
     'HandleVisibility', 'off');
text(ax2, 1/sqrt(3) + 0.01, ylim_range(1) + 0.95*diff(ylim_range), ...
     ' V_s/V_p at \nu=0', 'FontName', 'Arial', 'FontSize', 8, ...
     'Color', 'r', 'HandleVisibility', 'off');
set(ax2, 'YDir', 'reverse'); xlim(ax2, [0, 1]); ylim(ax2, ylim_range);
set(ax2, 'YTickLabel', []);
xlabel(ax2, 'V_s / V_p', 'FontName', 'Arial', 'FontSize', 10);
title(ax2, 'V_s / V_p ratio', 'FontName', 'Arial', 'FontSize', 12, ...
      'FontWeight', 'bold');
apply_pub_style(ax2);

% Panel 3: Bar summary
ax3 = subplot(1, 3, 3);
totals = np.totals;
n_ok      = totals.n_total - totals.n_np_total;
n_np_ood  = totals.n_np_ood;
n_np_nood = totals.n_np_non_ood;

bar_data = [n_ok, n_np_ood, n_np_nood];
bar_labels = {'Physical', 'Non-physical (OOD)', 'Non-physical (non-OOD)'};
bar_colors = [0.30 0.55 0.30; 0.55 0.55 0.55; 0.80 0.20 0.20];

for k = 1:3
    bar(ax3, k, bar_data(k), 'FaceColor', bar_colors(k,:), 'EdgeColor', 'none', ...
        'HandleVisibility', 'off');
    hold(ax3, 'on');
    text(ax3, k, bar_data(k) + 0.02*max(bar_data), num2str(bar_data(k)), ...
         'HorizontalAlignment', 'center', 'FontName', 'Arial', 'FontSize', 9);
end
set(ax3, 'XTick', 1:3, 'XTickLabel', bar_labels, 'XTickLabelRotation', 20);
ylabel(ax3, 'Count', 'FontName', 'Arial', 'FontSize', 11);
title(ax3, 'Non-physical breakdown', 'FontName', 'Arial', 'FontSize', 12, ...
      'FontWeight', 'bold');
apply_pub_style(ax3);

% Summary text box (top-right of figure)
silent_pct = 100 * n_np_nood / max(totals.n_np_total, 1);
summary_str = sprintf( ...
   ['Total deployment samples: %d\n', ...
    'Non-physical total: %d (%.2f%%)\n', ...
    'Within OOD: %d\n', ...
    'Within non-OOD: %d\n', ...
    'Silent failures: %.1f%% of NP'], ...
    totals.n_total, totals.n_np_total, 100*totals.n_np_total/totals.n_total, ...
    n_np_ood, n_np_nood, silent_pct);
annotation('textbox', [0.81, 0.85, 0.17, 0.13], 'String', summary_str, ...
    'FontName', 'Arial', 'FontSize', 9, ...
    'BackgroundColor', [1 1 1 0.92], 'EdgeColor', [0.7 0.7 0.7], ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');

if totals.n_np_total == 0
    title_str = 'Geomechanical plausibility diagnostic (no non-physical excursions)';
else
    title_str = 'Non-physical diagnostic (supplementary)';
end
sgtitle(title_str, 'FontName', 'Arial', 'FontSize', 13, 'FontWeight', 'bold');

pub_save_figure(fig, outdir, 'FigS_NEJ-2_nonphysical_diagnostic_pub');
close(fig);
end


function apply_pub_style(ax)
set(ax, 'FontName', 'Arial', 'FontSize', 10, 'LineWidth', 0.8, ...
        'Box', 'on', 'TickDir', 'in', 'XGrid', 'on', 'YGrid', 'on', ...
        'GridAlpha', 0.15);
end
