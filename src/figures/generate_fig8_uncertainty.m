function generate_fig8_uncertainty(pred, cfg)
% GENERATE_FIG8_UNCERTAINTY — depth profile with 95% PI band
%   Author: RCW (2026-06)

addpath(fullfile(cfg.matlab_root, 'src', 'utils'));

fig = figure('Position', [100 100 700 800], 'Color', 'w');

depth = pred.depth;
y_mean = pred.Vs_pred;
y_lo   = pred.PI_low;
y_hi   = pred.PI_high;

% Sort by depth for contiguous fill
[depth_s, sord] = sort(depth);
y_mean_s = y_mean(sord);
y_lo_s   = y_lo(sord);
y_hi_s   = y_hi(sord);

% PI band as patch
patch([y_lo_s; flipud(y_hi_s)], [depth_s; flipud(depth_s)], ...
      cfg.fig.color_pi_band, 'FaceAlpha', 0.4, 'EdgeColor', 'none', ...
      'DisplayName', '95% PI');
hold on;
plot(y_mean_s, depth_s, 'Color', cfg.fig.color_predicted, ...
     'LineWidth', cfg.fig.line_width, 'DisplayName', 'Mean prediction');

set(gca, 'YDir', 'reverse');
xlabel('V_s (km/s)', 'FontSize', cfg.fig.font_size);
ylabel('Depth (m)', 'FontSize', cfg.fig.font_size);
title(sprintf('%s deployment: uncertainty band', cfg.data.blind_well), ...
      'FontSize', cfg.fig.font_size + 1);
legend('Location', 'best');
xlim(cfg.fig.xlim.NEJ2.VS);
grid on;

out_path = fullfile(cfg.figures_dir, 'Fig8_uncertainty.png');
save_figure_safe(fig, out_path, cfg.fig.dpi);
close(fig);
end
