function D_sup = build_supervised_dataset(D, well_name)
% BUILD_SUPERVISED_DATASET — keep only rows with VS_source == "measured".
%
%   Hard assert: after filtering, EVERY row must have VS_source == "measured"
%   AND a finite positive VS. This is the methodologically clean training set.
%
%   Errors with a clear message if the supervised set ends up empty or too
%   small — that almost always indicates a resample/tolerance issue.
%
%   Author: RCW (2026-06)

if ~ismember('VS_source', D.Properties.VariableNames)
    error('build_supervised_dataset:no_VS_source', ...
          'Input table lacks VS_source column — preprocess_well must run first');
end

mask = (D.VS_source == "measured");
D_sup = D(mask, :);

% Defensive: warn if supervised set is too small
n_meas = height(D_sup);
if n_meas == 0
    error('build_supervised_dataset:empty', ...
          ['Supervised dataset is EMPTY for %s.\n' ...
           'This usually means the post-resample nearest-measured tolerance\n' ...
           'is too small relative to the resample step. Check\n' ...
           'cfg.preprocess.depth_step_m and preprocess_well Stage 5.'], well_name);
elseif n_meas < 100
    warning('build_supervised_dataset:too_small', ...
            'Supervised dataset has only %d samples for %s — model training may be unreliable', ...
            n_meas, well_name);
end

% Hard assertions — never train on imputed VS
assert(all(D_sup.VS_source == "measured"), ...
       'Target VS used for supervised learning must be measured, not imputed.');
assert(all(isfinite(D_sup.VS) & D_sup.VS > 0), ...
       'Supervised dataset contains non-finite or non-positive VS values.');

fprintf('  [SUP-%s] supervised samples: %d (from %d total) — all VS measured ✓\n', ...
        well_name, height(D_sup), height(D));
end
