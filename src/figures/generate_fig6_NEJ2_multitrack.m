function generate_fig6_NEJ2_multitrack(D_blind, pred, cfg)
% GENERATE_FIG6_NEJ2_MULTITRACK
%   5 tracks for NEJ-2 deployment: GR, RHOB, VP, VS prediction overlay, ν
%   Author: RCW (2026-06)

addpath(fullfile(cfg.matlab_root, 'src', 'utils'));

fig = figure('Position', [100 100 1400 700], 'Color', 'w');
sgtitle(sprintf('%s blind deployment: V_s prediction with OOD safety', ...
                cfg.data.blind_well), ...
        'FontSize', cfg.fig.font_size + 1, 'FontWeight', 'bold');

depth = D_blind.DEPTH;
ood   = logical(pred.ood);

ntracks = 5;

% Helper to shade OOD bands
function shade_ood(ax, depth_in, ood_in, ylim_curr)
    ax.YDir = 'reverse';
    yl = ax.YLim;
    xl = ax.XLim;
    hold(ax, 'on');
    % Identify contiguous OOD ranges
    d = diff([0; ood_in(:); 0]);
    starts = find(d == 1);
    ends   = find(d == -1) - 1;
    for ii = 1:numel(starts)
        d_lo = depth_in(starts(ii));
        d_hi = depth_in(ends(ii));
        patch(ax, [xl(1) xl(2) xl(2) xl(1)], [d_lo d_lo d_hi d_hi], ...
              cfg.fig.color_ood, 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    end
    uistack(findobj(ax, 'Type', 'patch'), 'bottom');
end

% Track 1: GR
subplot(1, ntracks, 1);
plot(D_blind.GR, depth, 'Color', [0.3 0.3 0.3], 'LineWidth', cfg.fig.line_width);
set(gca, 'YDir', 'reverse');
xlim(cfg.fig.xlim.NEJ2.GR);
xlabel('GR (API)'); ylabel('Depth (m)');
title('GR'); grid on;
shade_ood(gca, depth, ood, ylim);

% Track 2: RHOB
subplot(1, ntracks, 2);
plot(D_blind.RHOB, depth, 'Color', [0.6 0.3 0.1], 'LineWidth', cfg.fig.line_width);
set(gca, 'YDir', 'reverse');
xlim(cfg.fig.xlim.NEJ2.RHOB);
xlabel('RHOB (g/cm³)');
title('RHOB'); grid on;
shade_ood(gca, depth, ood, ylim);

% Track 3: VP
subplot(1, ntracks, 3);
plot(D_blind.VP, depth, 'Color', [0.10 0.20 0.55], 'LineWidth', cfg.fig.line_width);
set(gca, 'YDir', 'reverse');
xlim(cfg.fig.xlim.NEJ2.VP);
xlabel('V_p (km/s)');
title('V_p'); grid on;
shade_ood(gca, depth, ood, ylim);

% Track 4: VS prediction + Castagna
subplot(1, ntracks, 4);
plot(pred.Vs_pred,     depth, 'Color', cfg.fig.color_predicted, ...
     'LineWidth', cfg.fig.line_width); hold on;
plot(pred.Vs_castagna, depth, '--', 'Color', cfg.fig.color_castagna, ...
     'LineWidth', cfg.fig.line_width);
set(gca, 'YDir', 'reverse');
xlim(cfg.fig.xlim.NEJ2.VS);
xlabel('V_s (km/s)');
title('V_s prediction');
legend({'Predicted','Castagna'}, 'Location', 'best', ...
       'FontSize', cfg.fig.font_size - 2);
grid on;
shade_ood(gca, depth, ood, ylim);

% Track 5: Poisson's ratio
subplot(1, ntracks, 5);
plot(pred.nu, depth, 'Color', [0.4 0.2 0.6], 'LineWidth', cfg.fig.line_width);
hold on; plot([0 0], [min(depth) max(depth)], 'r--');
plot([0.5 0.5], [min(depth) max(depth)], 'r--');
set(gca, 'YDir', 'reverse');
xlim(cfg.fig.xlim.NEJ2.NU);
xlabel('\nu (Poisson)'); title('\nu');
grid on;

out_path = fullfile(cfg.figures_dir, 'Fig6_NEJ-2_multitrack.png');
save_figure_safe(fig, out_path, cfg.fig.dpi);
close(fig);
end
