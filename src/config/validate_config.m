function validate_config(cfg)
% VALIDATE_CONFIG — assert all required fields exist and are sensible.
%   Fails loudly with a descriptive message if anything is missing or wrong.
%   Called as the FIRST step in main_pipeline.
%
%   Author: RCW (2026-06)

% -------------------------------------------------------------------------
% Required top-level fields
% -------------------------------------------------------------------------
required_top = {'project_name','matlab_root','results_dir','intermediate_dir', ...
                'audit_dir','tables_dir','figures_dir','data','preprocess', ...
                'seed','split','features','optimization','model', ...
                'stacking','selection','uncertainty','deployment','geomech', ...
                'empirical','fig'};
must_have(cfg, required_top, 'cfg (top-level)');

% -------------------------------------------------------------------------
% Data
% -------------------------------------------------------------------------
must_have(cfg.data, {'train_file','blind_file','train_well','blind_well', ...
                     'canonical_cols','sanity','null_sentinels'}, 'cfg.data');

% Sanity ranges
must_have(cfg.data.sanity, {'GR','RHOB','NPHI','PHIE','VP','VS'}, ...
          'cfg.data.sanity');

assert(strcmp(cfg.data.train_well, 'NEJ-1'), ...
       'Train well must be ''NEJ-1'' (not ''%s'')', cfg.data.train_well);
assert(strcmp(cfg.data.blind_well, 'NEJ-2'), ...
       'Blind well must be ''NEJ-2'' (not ''%s'')', cfg.data.blind_well);

% -------------------------------------------------------------------------
% Preprocessing
% -------------------------------------------------------------------------
must_have(cfg.preprocess, {'iqr_k','zscore_thresh','knn_k', ...
                           'savgol_order','savgol_window', ...
                           'depth_step_m','normalize_method'}, ...
          'cfg.preprocess');

assert(cfg.preprocess.depth_step_m > 0 && cfg.preprocess.depth_step_m < 1, ...
       'depth_step_m must be in (0, 1) meters, got %.4f', ...
       cfg.preprocess.depth_step_m);

% -------------------------------------------------------------------------
% Seed and split
% -------------------------------------------------------------------------
assert(isnumeric(cfg.seed) && isscalar(cfg.seed) && cfg.seed >= 0, ...
       'cfg.seed must be a non-negative integer');

must_have(cfg.split, {'test_fraction','k_fold'}, 'cfg.split');
assert(cfg.split.test_fraction > 0 && cfg.split.test_fraction < 0.5, ...
       'test_fraction must be in (0, 0.5)');

% -------------------------------------------------------------------------
% Features
% -------------------------------------------------------------------------
must_have(cfg.features, {'scenarios','mrmr_top_k','lasso_alpha', ...
                         'candidate_logs','target'}, 'cfg.features');

expected_scenarios = {'S1_intersection','S2_all','S3_mrmr_only','S4_lasso_only'};
for k = 1:numel(expected_scenarios)
    assert(any(strcmp(cfg.features.scenarios, expected_scenarios{k})), ...
           'Missing feature scenario: %s', expected_scenarios{k});
end

% -------------------------------------------------------------------------
% Models
% -------------------------------------------------------------------------
must_have(cfg.model, {'pnn','mlffnn','dffnn','cnn1d','ridge','icnn', ...
                      'hybrid_icnn'}, 'cfg.model');

% -------------------------------------------------------------------------
% Stacking & selection
% -------------------------------------------------------------------------
must_have(cfg.stacking, {'use_oof','candidates'}, 'cfg.stacking');
must_have(cfg.selection, {'r2_tie_threshold','prefer_simpler', ...
                          'simplicity_order'}, 'cfg.selection');

% -------------------------------------------------------------------------
% Figures — strict naming convention
% -------------------------------------------------------------------------
must_have(cfg.fig, {'dpi','font_size','font_name','line_width', ...
                    'marker_size','color_measured','color_predicted', ...
                    'color_castagna','color_gc_lime','color_ood', ...
                    'color_pi_band','format','xlim'}, 'cfg.fig');

% Reject alias 'linewidth' (we use 'line_width' consistently)
assert(~isfield(cfg.fig, 'linewidth'), ...
       'cfg.fig.linewidth is FORBIDDEN — use cfg.fig.line_width');

must_have(cfg.fig.xlim, {'NEJ1','NEJ2'}, 'cfg.fig.xlim');

% -------------------------------------------------------------------------
% Empirical baselines
% -------------------------------------------------------------------------
must_have(cfg.empirical, {'castagna','gc_shale','gc_sand','gc_limestone'}, ...
          'cfg.empirical');
must_have(cfg.empirical.gc_limestone, {'a','b','c'}, ...
          'cfg.empirical.gc_limestone');

% -------------------------------------------------------------------------
% Deployment
% -------------------------------------------------------------------------
must_have(cfg.deployment, {'vs_clip_kms','ood_zthresh'}, 'cfg.deployment');
assert(numel(cfg.deployment.vs_clip_kms) == 2 && ...
       cfg.deployment.vs_clip_kms(1) < cfg.deployment.vs_clip_kms(2), ...
       'vs_clip_kms must be [lo, hi]');

fprintf('  [VALIDATE] Config validated successfully.\n');
end


function must_have(s, fields, name)
for k = 1:numel(fields)
    if ~isfield(s, fields{k})
        error('Config missing required field: %s.%s', name, fields{k});
    end
end
end
