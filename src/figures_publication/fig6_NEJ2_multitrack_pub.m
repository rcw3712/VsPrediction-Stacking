function fig6_NEJ2_multitrack_pub(D_blind, pred, outdir, cfg)
% FIG6_NEJ2_MULTITRACK_PUB — NEJ-2 deployment, length-safe and clean OOD legend.
%
%   Fix vs previous: explicitly synchronize length of ALL vectors before
%   any logical indexing. Coerce to column vectors. Filter for finite
%   together to keep masks aligned.
%
%   Author: RCW (2026-06)

addpath(fullfile(cfg.matlab_root, 'src', 'figures_publication'));

% =========================================================================
% LENGTH-SAFE EXTRACTION (per spec)
% =========================================================================
depth = pred.depth(:);
GR    = D_blind.GR(:);
RHOB  = D_blind.RHOB(:);
VP    = D_blind.VP(:);
Vs    = pred.Vs_pred(:);
nu    = pred.nu(:);
ood   = logical(pred.ood(:));
Vs_cas = [];
if isfield(pred, 'Vs_castagna'), Vs_cas = pred.Vs_castagna(:); end

% Truncate to common length
n = min([numel(depth), numel(GR), numel(RHOB), numel(VP), ...
         numel(Vs), numel(nu), numel(ood)]);
if numel(Vs_cas) >= n, Vs_cas = Vs_cas(1:n); end

depth = depth(1:n); GR = GR(1:n); RHOB = RHOB(1:n); VP = VP(1:n);
Vs    = Vs(1:n);    nu = nu(1:n); ood = ood(1:n);

% Joint finite filter (predictors only; let plot lines handle NaN gracefully)
valid = isfinite(depth);
depth = depth(valid); GR = GR(valid); RHOB = RHOB(valid); VP = VP(valid);
Vs    = Vs(valid);    nu = nu(valid); ood = ood(valid);
if ~isempty(Vs_cas), Vs_cas = Vs_cas(valid); end

if isempty(depth)
    warning('Fig6: empty data after length sync'); return;
end

ylim_range = [min(depth), max(depth)];

fig = figure('Position', [40 40 1500 850], 'Color', 'w');
ax_list = gobjects(5, 1);

% --- Track 1: GR ---
ax_list(1) = subplot(1, 5, 1);
plot(GR, depth, '-', 'Color', [0.30 0.30 0.30], 'LineWidth', 1.3, ...
     'HandleVisibility', 'off');
set(ax_list(1), 'YDir', 'reverse');
xlim([0, 200]); ylim(ylim_range);
xlabel('GR (API)', 'FontName', 'Arial', 'FontSize', 10);
ylabel('Depth (m)', 'FontName', 'Arial', 'FontSize', 11);
title('GR', 'FontName', 'Arial', 'FontSize', 12, 'FontWeight', 'bold');
apply_pub_style(ax_list(1)); shade_ood_bands(ax_list(1), ood, depth);

% --- Track 2: RHOB ---
ax_list(2) = subplot(1, 5, 2);
plot(RHOB, depth, '-', 'Color', [0.60 0.30 0.10], 'LineWidth', 1.3, ...
     'HandleVisibility', 'off');
set(ax_list(2), 'YDir', 'reverse');
xlim([1.5, 3.0]); ylim(ylim_range); set(ax_list(2), 'YTickLabel', []);
xlabel('RHOB (g/cm³)', 'FontName', 'Arial', 'FontSize', 10);
title('RHOB', 'FontName', 'Arial', 'FontSize', 12, 'FontWeight', 'bold');
apply_pub_style(ax_list(2)); shade_ood_bands(ax_list(2), ood, depth);

% --- Track 3: VP ---
ax_list(3) = subplot(1, 5, 3);
plot(VP, depth, '-', 'Color', [0.10 0.20 0.55], 'LineWidth', 1.3, ...
     'HandleVisibility', 'off');
set(ax_list(3), 'YDir', 'reverse');
xlim([1.5, 7.0]); ylim(ylim_range); set(ax_list(3), 'YTickLabel', []);
xlabel('V_p (km/s)', 'FontName', 'Arial', 'FontSize', 10);
title('V_p', 'FontName', 'Arial', 'FontSize', 12, 'FontWeight', 'bold');
apply_pub_style(ax_list(3)); shade_ood_bands(ax_list(3), ood, depth);

% --- Track 4: VS prediction ---
ax_list(4) = subplot(1, 5, 4); hold on;
plot(Vs, depth, '-', 'Color', [0.80 0.20 0.20], 'LineWidth', 1.3, ...
     'DisplayName', 'V_s predicted');
if ~isempty(Vs_cas)
    plot(Vs_cas, depth, '--', 'Color', [0.20 0.40 0.78], ...
         'LineWidth', 1.2, 'DisplayName', 'Castagna mudrock');
end
set(ax_list(4), 'YDir', 'reverse');
xlim([0.5, 4.5]); ylim(ylim_range); set(ax_list(4), 'YTickLabel', []);
xlabel('V_s (km/s)', 'FontName', 'Arial', 'FontSize', 10);
title('V_s prediction', 'FontName', 'Arial', 'FontSize', 12, 'FontWeight', 'bold');
apply_pub_style(ax_list(4)); shade_ood_bands(ax_list(4), ood, depth);

% Dummy patch for OOD legend (single entry)
hOOD = patch(ax_list(4), NaN, NaN, [0.82 0.82 0.82], ...
             'FaceAlpha', 0.55, 'EdgeColor', 'none', ...
             'DisplayName', 'OOD-flagged interval'); %#ok<NASGU>
legend(ax_list(4), 'Location', 'southwest', 'FontName', 'Arial', ...
       'FontSize', 8, 'Box', 'off', 'AutoUpdate', 'off');

% --- Track 5: Poisson ratio ---
ax_list(5) = subplot(1, 5, 5); hold on;
plot(nu, depth, '-', 'Color', [0.40 0.20 0.60], 'LineWidth', 1.3, ...
     'HandleVisibility', 'off');
plot([0 0],     ylim_range, 'r--', 'LineWidth', 0.9, 'HandleVisibility', 'off');
plot([0.5 0.5], ylim_range, 'r--', 'LineWidth', 0.9, 'HandleVisibility', 'off');
set(ax_list(5), 'YDir', 'reverse');
xlim([-0.2, 0.6]); ylim(ylim_range); set(ax_list(5), 'YTickLabel', []);
xlabel('\nu (Poisson)', 'FontName', 'Arial', 'FontSize', 10);
title('\nu', 'FontName', 'Arial', 'FontSize', 12, 'FontWeight', 'bold');
apply_pub_style(ax_list(5)); shade_ood_bands(ax_list(5), ood, depth);

sgtitle(sprintf('%s blind deployment — gray bands = OOD-flagged intervals', ...
                cfg.data.blind_well), ...
        'FontName', 'Arial', 'FontSize', 13, 'FontWeight', 'bold');

pub_save_figure(fig, outdir, 'Fig6_NEJ-2_multitrack_pub');
close(fig);
end


function shade_ood_bands(ax, ood, depth)
% Shade contiguous OOD intervals. All ood values added with HandleVisibility=off
% so they DON'T pollute the legend. ood and depth MUST be same length, verified.
if numel(ood) ~= numel(depth)
    return;   % defensive — caller already synced
end
xl = xlim(ax);

% Find contiguous runs of ood==true
n = numel(ood);
i = 1;
while i <= n
    if ood(i)
        j = i;
        while j <= n && ood(j), j = j + 1; end
        d_lo = depth(i);
        d_hi = depth(min(j-1, n));
        patch(ax, [xl(1) xl(2) xl(2) xl(1)], [d_lo d_lo d_hi d_hi], ...
              [0.82 0.82 0.82], 'FaceAlpha', 0.55, 'EdgeColor', 'none', ...
              'HandleVisibility', 'off');
        i = j;
    else
        i = i + 1;
    end
end

% Push patches behind other graphics using uistack
% (robust to HandleVisibility='off'; findall ignores it, get() doesn't)
try
    patches = findall(ax, 'Type', 'patch');
    if ~isempty(patches)
        uistack(patches, 'bottom');
    end
catch
    % Cosmetic only — never let z-order break the figure
end
end


function apply_pub_style(ax)
set(ax, 'FontName', 'Arial', 'FontSize', 10, 'LineWidth', 0.8, ...
        'Box', 'on', 'TickDir', 'in', 'XGrid', 'on', 'YGrid', 'on', ...
        'GridAlpha', 0.15);
end
