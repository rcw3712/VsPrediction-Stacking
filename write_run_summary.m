function write_run_summary(run_dir, info)
% WRITE_RUN_SUMMARY — comprehensive audit log for the current run.
%
%   info struct fields (all optional, missing → "n/a"):
%     timestamp, train_file, blind_file, sheet_name
%     n_raw_train, n_raw_blind, n_valid_train, n_valid_blind
%     depth_range_train, depth_range_blind
%     seed, n_train, n_test
%     scenarios   (struct array with .id and .features)
%     ranking     (struct array with .rank, .kind, .R2, .RMSE_kms, .note)
%     winner_kind, selection_reason
%     n_ood, n_total_blind, n_clipped
%     np_total, np_ood, np_non_ood
%     metric_domain ('physical_kms')
%
%   Author: RCW (2026-06)

if ~exist(run_dir, 'dir'), mkdir(run_dir); end
audit_dir = fullfile(run_dir, 'audit');
if ~exist(audit_dir, 'dir'), mkdir(audit_dir); end

path = fullfile(audit_dir, 'run_summary.txt');
fid = fopen(path, 'w');
if fid < 0, warning('Could not open %s', path); return; end

g = @(k, d) get_field(info, k, d);

fprintf(fid, '========================================================================\n');
fprintf(fid, '  RUN SUMMARY — Vs Prediction Pipeline (NEJ_v3 EXCEL LOCKED)\n');
fprintf(fid, '========================================================================\n\n');

fprintf(fid, 'TIMESTAMP\n');
fprintf(fid, '  Run started: %s\n\n', g('timestamp', datestr(now)));

fprintf(fid, 'INPUTS\n');
fprintf(fid, '  Train file:    %s\n', g('train_file', 'n/a'));
fprintf(fid, '  Blind file:    %s\n', g('blind_file', 'n/a'));
fprintf(fid, '  Sheet name:    %s\n\n', g('sheet_name', 'Sheet1'));

fprintf(fid, 'SAMPLE COUNTS\n');
fprintf(fid, '  NEJ-1 raw rows:           %s\n', num_str(g('n_raw_train', NaN)));
fprintf(fid, '  NEJ-1 after cleaning:     %s\n', num_str(g('n_valid_train', NaN)));
fprintf(fid, '  NEJ-2 raw rows:           %s\n', num_str(g('n_raw_blind', NaN)));
fprintf(fid, '  NEJ-2 after cleaning:     %s\n\n', num_str(g('n_valid_blind', NaN)));

fprintf(fid, 'TARGET VS (NEJ-1) — METHODOLOGY GUARD\n');
fprintf(fid, '  VS measured:                       %s\n', num_str(g('n_vs_measured', NaN)));
fprintf(fid, '  VS missing:                        %s\n', num_str(g('n_vs_missing',  NaN)));
fprintf(fid, '  VS imputed for supervised learning: %s   ← MUST be 0\n', num_str(g('n_vs_imputed_sup', NaN)));
fprintf(fid, '  Supervised samples (measured VS): %s\n\n', num_str(g('n_supervised', NaN)));

dt = g('depth_range_train', [NaN NaN]);
db = g('depth_range_blind', [NaN NaN]);
fprintf(fid, 'DEPTH RANGES (m, after preprocessing)\n');
fprintf(fid, '  NEJ-1: [%s, %s]\n',  num_str(dt(1), '%.2f'), num_str(dt(2), '%.2f'));
fprintf(fid, '  NEJ-2: [%s, %s]\n\n', num_str(db(1), '%.2f'), num_str(db(2), '%.2f'));

fprintf(fid, 'TRAIN/TEST SPLIT (NEJ-1)\n');
fprintf(fid, '  Master seed:  %s\n', num_str(g('seed', NaN)));
fprintf(fid, '  N train:      %s\n', num_str(g('n_train', NaN)));
fprintf(fid, '  N test:       %s\n\n', num_str(g('n_test', NaN)));

fprintf(fid, 'FEATURE-SELECTION SCENARIOS\n');
scn = g('scenarios', []);
if ~isempty(scn)
    for i = 1:numel(scn)
        feats = scn(i).features;
        if iscell(feats), feats_str = strjoin(feats, ', '); else, feats_str = char(feats); end
        fprintf(fid, '  %-16s [%d]: %s\n', scn(i).id, numel(scn(i).features), feats_str);
    end
else
    fprintf(fid, '  (not provided)\n');
end
fprintf(fid, '\n');

fprintf(fid, 'MODEL RANKING (test set, sorted by R²)\n');
rk = g('ranking', []);
if ~isempty(rk)
    fprintf(fid, '  %-4s %-30s %-10s %-12s %s\n', ...
            'Rank', 'Model', 'R²', 'RMSE (km/s)', 'Note');
    fprintf(fid, '  %s\n', repmat('-', 1, 80));
    for i = 1:numel(rk)
        fprintf(fid, '  %-4d %-30s %-10.4f %-12.4f %s\n', ...
                rk(i).rank, rk(i).kind, rk(i).R2, rk(i).RMSE_kms, rk(i).note);
    end
else
    fprintf(fid, '  (not provided)\n');
end
fprintf(fid, '\n');

fprintf(fid, 'DEPLOYMENT MODEL\n');
fprintf(fid, '  Selected: %s\n\n', g('winner_kind', 'n/a'));
fprintf(fid, 'SELECTION REASONING\n');
reason = g('selection_reason', '(not provided)');
% Indent each line of reason
reason_lines = strsplit(reason, newline);
for i = 1:numel(reason_lines)
    fprintf(fid, '  %s\n', reason_lines{i});
end
fprintf(fid, '\n');

fprintf(fid, 'NEJ-2 DEPLOYMENT STATISTICS\n');
n_total = g('n_total_blind', NaN);
n_ood   = g('n_ood', NaN);
n_clip  = g('n_clipped', NaN);
fprintf(fid, '  Total samples:       %s\n', num_str(n_total));
fprintf(fid, '  OOD (|z|>3):         %s (%s%%)\n', num_str(n_ood), pct_str(n_ood, n_total));
fprintf(fid, '  Clipped to [0.2, 4.5]: %s (%s%%)\n\n', num_str(n_clip), pct_str(n_clip, n_total));

fprintf(fid, 'NON-PHYSICAL ANALYSIS\n');
np_total   = g('np_total', NaN);
np_ood     = g('np_ood', NaN);
np_non_ood = g('np_non_ood', NaN);
fprintf(fid, '  Total non-physical:        %s (%s%%)\n', num_str(np_total), pct_str(np_total, n_total));
fprintf(fid, '  Within OOD:                %s\n', num_str(np_ood));
fprintf(fid, '  Within non-OOD:            %s\n', num_str(np_non_ood));
silent_pct = 100 * np_non_ood / max(np_total, 1);
fprintf(fid, '  Silent failures (non-OOD): %.1f%% of total NP\n\n', silent_pct);

fprintf(fid, 'METRIC DOMAIN\n');
fprintf(fid, '  All RMSE/MAE/Bias/MAPE: %s\n', g('metric_domain', 'physical_kms'));
fprintf(fid, '  (z-score metrics, if any, are in debug_metrics_zscore.csv)\n\n');

fprintf(fid, 'OUTPUT FOLDER\n');
fprintf(fid, '  %s\n\n', run_dir);

fprintf(fid, '========================================================================\n');
fprintf(fid, '  END OF RUN SUMMARY\n');
fprintf(fid, '========================================================================\n');

fclose(fid);
fprintf('  [AUDIT] Run summary saved: %s\n', path);
end


function v = get_field(s, k, d)
if isfield(s, k), v = s.(k); else, v = d; end
end


function s = num_str(v, fmt)
if nargin < 2, fmt = '%g'; end
if isnan(v) || (isnumeric(v) && isempty(v)), s = 'n/a';
else, s = sprintf(fmt, v); end
end


function s = pct_str(num, den)
if isnan(num) || isnan(den) || den == 0, s = 'n/a';
else, s = sprintf('%.1f', 100*num/den); end
end
