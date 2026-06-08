function generate_fig7_NEJ2_crossplot(pred, cfg)
% GENERATE_FIG7_NEJ2_CROSSPLOT
%   Vp-Vs crossplot for NEJ-2, color-coded by OOD flag, with Castagna ref.
%   Author: RCW (2026-06)

addpath(fullfile(cfg.matlab_root, 'src', 'utils'));

fig = figure('Position', [100 100 800 700], 'Color', 'w');

ood = logical(pred.ood);
Vp = pred.Vp;
Vs = pred.Vs_pred;

scatter(Vp(~ood), Vs(~ood), 12, cfg.fig.color_predicted, 'filled', ...
        'MarkerFaceAlpha', 0.5, 'DisplayName', 'Non-OOD predictions');
hold on;
scatter(Vp(ood), Vs(ood), 12, cfg.fig.color_ood, 'filled', ...
        'MarkerFaceAlpha', 0.3, 'DisplayName', 'OOD-flagged');

% Castagna reference line
Vp_ref = linspace(min(Vp), max(Vp), 100);
Vs_cas = cfg.empirical.castagna.a * Vp_ref + cfg.empirical.castagna.b;
plot(Vp_ref, Vs_cas, '--', 'Color', cfg.fig.color_castagna, ...
     'LineWidth', cfg.fig.line_width + 0.5, 'DisplayName', 'Castagna mudrock');

xlabel('V_p (km/s)', 'FontSize', cfg.fig.font_size);
ylabel('V_s (km/s)', 'FontSize', cfg.fig.font_size);
title(sprintf('%s deployment: V_p–V_s crossplot (deployment model)', ...
              cfg.data.blind_well), ...
      'FontSize', cfg.fig.font_size + 1);
legend('Location', 'northwest');
grid on;
axis([1.5 6.5 0 4.5]);

out_path = fullfile(cfg.figures_dir, 'Fig7_NEJ-2_Vp-Vs_crossplot.png');
save_figure_safe(fig, out_path, cfg.fig.dpi);
close(fig);
end
