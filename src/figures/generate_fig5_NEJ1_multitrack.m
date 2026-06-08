function generate_fig5_NEJ1_multitrack(D_train, results, cfg)
% GENERATE_FIG5_NEJ1_MULTITRACK
%   5 tracks (GR, RHOB, VP, VS comparison, residual) showing measured Vs
%   alongside the deployed-model prediction (test points only).
%   Author: RCW (2026-06)

addpath(fullfile(cfg.matlab_root, 'src', 'utils'));

fig = figure('Position', [100 100 1400 700], 'Color', 'w');
sgtitle(sprintf('%s training well: V_s prediction quality', cfg.data.train_well), ...
        'FontSize', cfg.fig.font_size + 1, 'FontWeight', 'bold');

% Test indices and predictions
test_idx = results.test.indices;
Vs_meas  = D_train.VS(test_idx);
Vs_pred  = results.test.Vs_pred_kms;
Vp_test  = D_train.VP(test_idx);

% Empirical baselines on test
emp = empirical_baselines(Vp_test, cfg);

depth_test = D_train.DEPTH(test_idx);
depth_full = D_train.DEPTH;

ntracks = 5;

% --- Track 1: GR
subplot(1, ntracks, 1);
plot(D_train.GR, depth_full, 'Color', [0.3 0.3 0.3], 'LineWidth', cfg.fig.line_width);
set(gca, 'YDir', 'reverse');
xlabel('GR (API)'); ylabel('Depth (m)');
xlim(cfg.fig.xlim.NEJ1.GR);
title('GR');
grid on;

% --- Track 2: RHOB
subplot(1, ntracks, 2);
plot(D_train.RHOB, depth_full, 'Color', [0.6 0.3 0.1], 'LineWidth', cfg.fig.line_width);
set(gca, 'YDir', 'reverse');
xlabel('RHOB (g/cm³)');
xlim(cfg.fig.xlim.NEJ1.RHOB);
title('RHOB');
grid on;

% --- Track 3: VP
subplot(1, ntracks, 3);
plot(D_train.VP, depth_full, 'Color', [0.10 0.20 0.55], 'LineWidth', cfg.fig.line_width);
set(gca, 'YDir', 'reverse');
xlabel('V_p (km/s)');
xlim(cfg.fig.xlim.NEJ1.VP);
title('V_p');
grid on;

% --- Track 4: VS comparison
subplot(1, ntracks, 4);
plot(D_train.VS, depth_full, 'Color', cfg.fig.color_measured, ...
     'LineWidth', cfg.fig.line_width); hold on;
scatter(Vs_pred, depth_test, cfg.fig.marker_size^2, ...
        cfg.fig.color_predicted, 'filled', 'MarkerFaceAlpha', 0.6);
plot(emp.gc_limestone, depth_test, ':', 'Color', cfg.fig.color_gc_lime, ...
     'LineWidth', cfg.fig.line_width);
plot(emp.castagna,     depth_test, '--', 'Color', cfg.fig.color_castagna, ...
     'LineWidth', cfg.fig.line_width);
set(gca, 'YDir', 'reverse');
xlabel('V_s (km/s)');
xlim(cfg.fig.xlim.NEJ1.VS);
title('V_s comparison');
legend({'Measured V_s','Predicted (test)','GC limestone','Castagna mudrock'}, ...
       'Location', 'best', 'FontSize', cfg.fig.font_size - 2);
grid on;

% --- Track 5: Residual
subplot(1, ntracks, 5);
residual = Vs_pred - Vs_meas;
scatter(residual, depth_test, cfg.fig.marker_size^2, ...
        cfg.fig.color_predicted, 'filled'); hold on;
plot([0 0], [min(depth_full) max(depth_full)], 'k--');
set(gca, 'YDir', 'reverse');
xlabel('Pred − Meas (km/s)');
title('Residual');
xlim([-1 1]);
grid on;

out_path = fullfile(cfg.figures_dir, 'Fig5_NEJ-1_multitrack.png');
save_figure_safe(fig, out_path, cfg.fig.dpi);
close(fig);
end
