function fig8_uncertainty_pub(pred, outdir, cfg)
% FIG8_UNCERTAINTY_PUB — Vs prediction with shaded 95% PI + OOD bands.
%
%   pred fields used: depth, Vs_pred, PI_low, PI_high, ood
%   Author: RCW (2026-06)

addpath(fullfile(cfg.matlab_root, 'src', 'figures_publication'));

depth = pred.depth;
y_mean = pred.Vs_pred;
y_lo   = pred.PI_low;
y_hi   = pred.PI_high;
ood = logical(pred.ood);

% Sort by depth
[depth_s, ord] = sort(depth);
y_mean_s = y_mean(ord);
y_lo_s   = y_lo(ord);
y_hi_s   = y_hi(ord);

% Visualization clipping — keep raw values in tables (caller handles that)
clip_lo = 0.2;  clip_hi = 4.5;
y_lo_plot = max(y_lo_s, clip_lo);
y_hi_plot = min(y_hi_s, clip_hi);
ood_s    = ood(ord);

fig = figure('Position', [80 80 700 900], 'Color', 'w');
ax = axes('Parent', fig);
hold(ax, 'on');

ylim_range = [min(depth_s), max(depth_s)];
xlim_range = [0.3, 4.5];

% OOD bands first (back)
d_run = diff([0; ood_s(:); 0]);
starts = find(d_run == 1);
ends   = find(d_run == -1) - 1;
for ii = 1:numel(starts)
    d_lo = depth_s(starts(ii));
    d_hi = depth_s(ends(ii));
    patch(ax, [xlim_range(1) xlim_range(2) xlim_range(2) xlim_range(1)], ...
              [d_lo d_lo d_hi d_hi], ...
              [0.82 0.82 0.82], 'FaceAlpha', 0.50, 'EdgeColor', 'none', ...
              'HandleVisibility', 'off');
end

% 95% PI band
patch(ax, [y_lo_plot; flipud(y_hi_plot)], [depth_s; flipud(depth_s)], ...
      [0.98 0.78 0.55], 'FaceAlpha', 0.55, 'EdgeColor', 'none', ...
      'DisplayName', sprintf('95%% PI (clipped [%.1f,%.1f] for display)', clip_lo, clip_hi));

% Mean prediction line
plot(ax, y_mean_s, depth_s, '-', 'Color', [0.80 0.20 0.20], ...
     'LineWidth', 1.4, 'DisplayName', 'V_s mean prediction');

% Single dummy OOD legend item
patch(ax, NaN, NaN, [0.82 0.82 0.82], 'FaceAlpha', 0.50, ...
      'EdgeColor', 'none', 'DisplayName', 'OOD-flagged interval');

set(ax, 'YDir', 'reverse');
xlim(ax, xlim_range); ylim(ax, ylim_range);
xlabel(ax, 'V_s (km/s)', 'FontName', 'Arial', 'FontSize', 11);
ylabel(ax, 'Depth (m)', 'FontName', 'Arial', 'FontSize', 11);
title(ax, sprintf('%s — deployment V_s with 95%% prediction interval', ...
                  cfg.data.blind_well), ...
      'FontName', 'Arial', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'southeast', 'FontName', 'Arial', 'FontSize', 9, ...
       'Box', 'off', 'AutoUpdate', 'off');

set(ax, 'FontName', 'Arial', 'FontSize', 10, 'LineWidth', 0.8, ...
        'Box', 'on', 'TickDir', 'in', 'XGrid', 'on', 'YGrid', 'on', ...
        'GridAlpha', 0.15);

pub_save_figure(fig, outdir, 'Fig8_uncertainty_pub');
close(fig);
end
