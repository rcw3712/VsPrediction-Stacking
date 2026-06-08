function fig5_NEJ1_multitrack_pub(D_train, test_idx, Vs_pred_test_kms, ...
                                   emp_test_kms_struct, outdir, cfg)
% FIG5_NEJ1_MULTITRACK_PUB — 5-track depth display, focused interval.
%   D_train       : preprocessed NEJ-1 table (DEPTH, GR, RHOB, NPHI, PHIE, VP, VS)
%   test_idx      : indices into D_train selected as test set
%   Vs_pred_test_kms : predictions on the test rows (km/s, from deployment model)
%   emp_test_kms_struct : struct with .castagna, .gc_limestone on test rows (km/s)
%   outdir        : output directory
%   cfg           : config
%   Author: RCW (2026-06)

addpath(fullfile(cfg.matlab_root, 'src', 'figures_publication'));

% Focused depth window — default to 1415-1993 m, override via cfg.fig.nej1_focus
if isfield(cfg, 'fig') && isfield(cfg.fig, 'nej1_focus')
    focus = cfg.fig.nej1_focus;
else
    focus = [1415, 1993];
end

depth_all = D_train.DEPTH;
mask_focus = depth_all >= focus(1) & depth_all <= focus(2);

depth_test = D_train.DEPTH(test_idx);
Vs_meas    = D_train.VS(test_idx);
Vp_test    = D_train.VP(test_idx);

residual = Vs_pred_test_kms - Vs_meas;

fig = figure('Position', [40 40 1500 800], 'Color', 'w');

n_tracks = 5;
ax_list = gobjects(n_tracks, 1);

% --- Track 1: GR
ax_list(1) = subplot(1, n_tracks, 1);
plot(D_train.GR(mask_focus), depth_all(mask_focus), '-', ...
     'Color', [0.30 0.30 0.30], 'LineWidth', 1.3);
set(ax_list(1), 'YDir', 'reverse');
xlabel('GR (API)', 'FontName', 'Arial', 'FontSize', 10);
ylabel('Depth (m)', 'FontName', 'Arial', 'FontSize', 11);
title('GR', 'FontName', 'Arial', 'FontSize', 12, 'FontWeight', 'bold');
xlim([0, 200]); ylim(focus);
apply_pub_style(ax_list(1));

% --- Track 2: RHOB
ax_list(2) = subplot(1, n_tracks, 2);
plot(D_train.RHOB(mask_focus), depth_all(mask_focus), '-', ...
     'Color', [0.60 0.30 0.10], 'LineWidth', 1.3);
set(ax_list(2), 'YDir', 'reverse');
xlabel('RHOB (g/cm³)', 'FontName', 'Arial', 'FontSize', 10);
title('RHOB', 'FontName', 'Arial', 'FontSize', 12, 'FontWeight', 'bold');
xlim([1.5, 3.0]); ylim(focus); set(ax_list(2), 'YTickLabel', []);
apply_pub_style(ax_list(2));

% --- Track 3: VP
ax_list(3) = subplot(1, n_tracks, 3);
plot(D_train.VP(mask_focus), depth_all(mask_focus), '-', ...
     'Color', [0.10 0.20 0.55], 'LineWidth', 1.3);
set(ax_list(3), 'YDir', 'reverse');
xlabel('V_p (km/s)', 'FontName', 'Arial', 'FontSize', 10);
title('V_p', 'FontName', 'Arial', 'FontSize', 12, 'FontWeight', 'bold');
xlim([1.5, 7.0]); ylim(focus); set(ax_list(3), 'YTickLabel', []);
apply_pub_style(ax_list(3));

% --- Track 4: VS comparison
ax_list(4) = subplot(1, n_tracks, 4);
hold on;
% Measured (black line across full focus)
plot(D_train.VS(mask_focus), depth_all(mask_focus), '-', ...
     'Color', [0.05 0.05 0.05], 'LineWidth', 1.3, ...
     'DisplayName', 'V_s measured');
% Predicted on test
test_in_focus = test_idx(depth_test >= focus(1) & depth_test <= focus(2));
[d_test_f, ord] = sort(D_train.DEPTH(test_in_focus));
pred_f = Vs_pred_test_kms(ismember(test_idx, test_in_focus));
pred_f = pred_f(ord);
scatter(pred_f, d_test_f, 14, [0.80 0.20 0.20], 'filled', ...
        'MarkerFaceAlpha', 0.65, 'DisplayName', 'V_s predicted (test)');
% Empirical
if isfield(emp_test_kms_struct, 'castagna')
    cas_f = emp_test_kms_struct.castagna(ismember(test_idx, test_in_focus));
    cas_f = cas_f(ord);
    plot(cas_f, d_test_f, '--', 'Color', [0.20 0.40 0.78], 'LineWidth', 1.2, ...
         'DisplayName', 'Castagna mudrock');
end
if isfield(emp_test_kms_struct, 'gc_limestone')
    gcl_f = emp_test_kms_struct.gc_limestone(ismember(test_idx, test_in_focus));
    gcl_f = gcl_f(ord);
    plot(gcl_f, d_test_f, '-.', 'Color', [0.45 0.25 0.70], 'LineWidth', 1.2, ...
         'DisplayName', 'GC limestone');
end
set(ax_list(4), 'YDir', 'reverse');
xlabel('V_s (km/s)', 'FontName', 'Arial', 'FontSize', 10);
title('V_s comparison', 'FontName', 'Arial', 'FontSize', 12, 'FontWeight', 'bold');
xlim([0.5, 4.5]); ylim(focus); set(ax_list(4), 'YTickLabel', []);
legend('Location', 'southwest', 'FontName', 'Arial', 'FontSize', 8, ...
       'Box', 'off', 'AutoUpdate', 'off');
apply_pub_style(ax_list(4));

% --- Track 5: Residual
ax_list(5) = subplot(1, n_tracks, 5);
hold on;
res_f = residual(ismember(test_idx, test_in_focus));
res_f = res_f(ord);
scatter(res_f, d_test_f, 14, [0.80 0.20 0.20], 'filled', ...
        'MarkerFaceAlpha', 0.65, 'HandleVisibility', 'off');
plot([0 0], focus, 'k--', 'LineWidth', 0.8, 'HandleVisibility', 'off');
set(ax_list(5), 'YDir', 'reverse');
xlabel('Pred − Meas (km/s)', 'FontName', 'Arial', 'FontSize', 10);
title('Residual', 'FontName', 'Arial', 'FontSize', 12, 'FontWeight', 'bold');
xlim([-1, 1]); ylim(focus); set(ax_list(5), 'YTickLabel', []);
apply_pub_style(ax_list(5));

sgtitle(sprintf('%s training well — V_s prediction quality (depth %d–%d m)', ...
                cfg.data.train_well, focus(1), focus(2)), ...
        'FontName', 'Arial', 'FontSize', 13, 'FontWeight', 'bold');

pub_save_figure(fig, outdir, 'Fig5_NEJ-1_multitrack_pub');
close(fig);
end


function apply_pub_style(ax)
set(ax, 'FontName', 'Arial', 'FontSize', 10, 'LineWidth', 0.8, ...
        'Box', 'on', 'TickDir', 'in', 'XGrid', 'on', 'YGrid', 'on', ...
        'GridAlpha', 0.15);
end
