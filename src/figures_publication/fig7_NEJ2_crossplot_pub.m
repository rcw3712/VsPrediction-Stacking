function fig7_NEJ2_crossplot_pub(pred, outdir, cfg)
% FIG7_NEJ2_CROSSPLOT_PUB — Vp-Vs scatter with empirical overlays + annotations.
%
%   pred fields used: Vp, Vs_pred, ood
%   Author: RCW (2026-06)

addpath(fullfile(cfg.matlab_root, 'src', 'figures_publication'));

ood = logical(pred.ood);
Vp  = pred.Vp;
Vs  = pred.Vs_pred;
n_total   = numel(Vp);
n_non_ood = sum(~ood);

% Compute empirical baselines at the actual Vp samples
Vp_grid = linspace(max(0.5, min(Vp)*0.95), max(Vp)*1.05, 200)';
c = cfg.empirical;
cas = c.castagna.a   * Vp_grid + c.castagna.b;
gcs = c.gc_shale.a   * Vp_grid + c.gc_shale.b;
gcd = c.gc_sand.a    * Vp_grid + c.gc_sand.b;
gcl = c.gc_limestone.a * Vp_grid.^2 + c.gc_limestone.b * Vp_grid + c.gc_limestone.c;

% Mean bias vs Castagna (on non-OOD samples)
cas_at_samples = c.castagna.a * Vp(~ood) + c.castagna.b;
bias_vs_cas = mean(Vs(~ood) - cas_at_samples, 'omitnan');

fig = figure('Position', [80 80 900 800], 'Color', 'w');
ax = axes('Parent', fig);
hold(ax, 'on');

% Scatter — non-OOD red, OOD gray
scatter(ax, Vp(~ood), Vs(~ood), 14, [0.80 0.20 0.20], 'filled', ...
        'MarkerFaceAlpha', 0.45, 'DisplayName', sprintf('Non-OOD (n=%d)', n_non_ood));
scatter(ax, Vp(ood), Vs(ood), 14, [0.55 0.55 0.55], 'filled', ...
        'MarkerFaceAlpha', 0.30, 'DisplayName', sprintf('OOD (n=%d)', sum(ood)));

% Empirical lines
plot(ax, Vp_grid, cas, '--', 'Color', [0.20 0.40 0.78], ...
     'LineWidth', 1.5, 'DisplayName', 'Castagna mudrock');
plot(ax, Vp_grid, gcs, ':',  'Color', [0.10 0.55 0.35], ...
     'LineWidth', 1.5, 'DisplayName', 'GC shale');
plot(ax, Vp_grid, gcd, '-.', 'Color', [0.85 0.55 0.10], ...
     'LineWidth', 1.5, 'DisplayName', 'GC sandstone');
plot(ax, Vp_grid, gcl, '-',  'Color', [0.45 0.25 0.70], ...
     'LineWidth', 1.5, 'DisplayName', 'GC limestone');

xlim(ax, [1.5, max(Vp)*1.05]);
ylim(ax, [0, 4.5]);
xlabel(ax, 'V_p (km/s)', 'FontName', 'Arial', 'FontSize', 11);
ylabel(ax, 'V_s (km/s)', 'FontName', 'Arial', 'FontSize', 11);
title(ax, sprintf('%s deployment — V_p vs V_s with empirical references', ...
                  cfg.data.blind_well), ...
      'FontName', 'Arial', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'northwest', 'FontName', 'Arial', 'FontSize', 9, ...
       'Box', 'off', 'AutoUpdate', 'off');

% Annotation box (text)
ann_str = {
    sprintf('Total samples: %d', n_total)
    sprintf('Non-OOD: %d (%.1f%%)', n_non_ood, 100*n_non_ood/n_total)
    sprintf('Mean Vs offset vs Castagna: %+.3f km/s (%s)', bias_vs_cas, ...
             ternary7(bias_vs_cas >= 0, 'above', 'below'))
};
text(ax, 0.97, 0.03, ann_str, 'Units', 'normalized', ...
     'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
     'FontName', 'Arial', 'FontSize', 9, ...
     'BackgroundColor', [1 1 1 0.85], 'EdgeColor', [0.7 0.7 0.7], ...
     'Margin', 4);

set(ax, 'FontName', 'Arial', 'FontSize', 10, 'LineWidth', 0.8, ...
        'Box', 'on', 'TickDir', 'in', 'XGrid', 'on', 'YGrid', 'on', ...
        'GridAlpha', 0.15);

pub_save_figure(fig, outdir, 'Fig7_NEJ-2_Vp-Vs_crossplot_pub');
close(fig);
end

function out = ternary7(c,a,b)
if c, out = a; else, out = b; end
end
