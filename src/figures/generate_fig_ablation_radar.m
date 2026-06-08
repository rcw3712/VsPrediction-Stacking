function generate_fig_ablation_radar(scenarios, base_results, cfg)
% GENERATE_FIG_ABLATION_RADAR — radar + bar comparison of 4 FS scenarios.
%   For each scenario, compute mean R², RMSE, MAE across base learners
%   plus CV-RMSE std (stability).
%   Author: RCW (2026-06)

addpath(fullfile(cfg.matlab_root, 'src', 'utils'));

base_kinds = {'pnn','mlffnn','dffnn','cnn1d'};
n_scen = numel(scenarios);

% Collect mean metrics per scenario across the 4 base learners
mean_r2   = zeros(n_scen, 1);
mean_rmse = zeros(n_scen, 1);
mean_mae  = zeros(n_scen, 1);
mean_std  = zeros(n_scen, 1);
labels    = cell(n_scen, 1);

for s = 1:n_scen
    sid = scenarios(s).id;
    labels{s} = strrep(sid, '_', '\_');
    r2s = zeros(numel(base_kinds), 1);
    rmses = zeros(numel(base_kinds), 1);
    maes = zeros(numel(base_kinds), 1);
    stds = zeros(numel(base_kinds), 1);
    for m = 1:numel(base_kinds)
        rk = base_results.(sid).(base_kinds{m});
        r2s(m)   = rk.test_metrics.R2;
        rmses(m) = rk.test_metrics.RMSE_kms;
        maes(m)  = rk.test_metrics.MAE;
        stds(m)  = rk.cv_rmse_std;
    end
    mean_r2(s)   = mean(r2s);
    mean_rmse(s) = mean(rmses);
    mean_mae(s)  = mean(maes);
    mean_std(s)  = mean(stds);
end

fig = figure('Position', [80 80 1400 600], 'Color', 'w');

% Bar chart
subplot(1, 2, 1);
bar([mean_r2, 1 - mean_rmse/max(mean_rmse), 1 - mean_mae/max(mean_mae), 1 - mean_std/max(mean_std)]);
set(gca, 'XTickLabel', labels, 'XTickLabelRotation', 30);
ylabel('Score (R² | 1 − normalized error)');
legend({'R²','1 − norm RMSE','1 − norm MAE','1 − norm CV-std (stability)'}, ...
       'Location', 'best', 'FontSize', cfg.fig.font_size - 2);
title('Ablation: scenario comparison (higher = better)');
ylim([0 1]);
grid on;

% Radar (polar) plot
subplot(1, 2, 2);
metrics = [mean_r2(:), 1 - mean_rmse(:)/max(mean_rmse), ...
           1 - mean_mae(:)/max(mean_mae), 1 - mean_std(:)/max(mean_std)];
M = size(metrics, 2);
metric_names = {'R²','RMSE^{-1}','MAE^{-1}','Stability'};

theta = linspace(0, 2*pi, M+1);
colors = lines(n_scen);
hold on;
for s = 1:n_scen
    r = [metrics(s, :), metrics(s, 1)];
    pl = polarplot(theta, r, '-o', 'LineWidth', cfg.fig.line_width, ...
                   'Color', colors(s, :), 'DisplayName', labels{s});
end
ax = gca;
ax.ThetaTick = rad2deg(theta(1:end-1));
ax.ThetaTickLabel = metric_names;
ax.RLim = [0 1];
legend('Location', 'eastoutside', 'FontSize', cfg.fig.font_size - 2);
title('Ablation radar (normalized scores)');

sgtitle('Feature-selection ablation study', ...
        'FontSize', cfg.fig.font_size + 1, 'FontWeight', 'bold');

out_path = fullfile(cfg.figures_dir, 'Fig_ablation_radar_bar.png');
save_figure_safe(fig, out_path, cfg.fig.dpi);
close(fig);

% Also save ablation summary table
T = table(labels, mean_r2, mean_rmse, mean_mae, mean_std, ...
    'VariableNames', {'Scenario','mean_R2','mean_RMSE_kms','mean_MAE_kms','mean_CV_std_kms'});
write_table_safe(T, fullfile(cfg.tables_dir, 'ablation_summary.csv'));
end
