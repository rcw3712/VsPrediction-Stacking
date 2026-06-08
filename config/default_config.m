function cfg = default_config()
% DEFAULT_CONFIG — single source of truth for the Vs prediction pipeline
%   Single source of truth for the Vs prediction pipeline.
%   Flat, consistent schema — no field aliases.
%   Author: RCW (2026-06)

% =========================================================================
% PROJECT METADATA
% =========================================================================
cfg.project_name      = 'NEJ_v3_EXCEL_LOCKED';
cfg.matlab_root       = pwd;

% Run folder created at runtime by main_pipeline; placeholders below are
% overridden after the timestamp is generated.
cfg.results_root      = fullfile(cfg.matlab_root, 'results');
cfg.results_dir       = fullfile(cfg.results_root, 'NEJ_excel_locked_pending');
cfg.intermediate_dir  = fullfile(cfg.results_dir, 'intermediate');
cfg.audit_dir         = fullfile(cfg.results_dir, 'audit');
cfg.tables_dir        = fullfile(cfg.results_dir, 'tables');
cfg.figures_dir       = fullfile(cfg.results_dir, 'figures');
cfg.figures_pub_dir   = fullfile(cfg.results_dir, 'figures_publication');

% =========================================================================
% DATA (Excel ONLY)
% =========================================================================
cfg.data.train_file   = fullfile('data', 'NEJ-1.xlsx');
cfg.data.blind_file   = fullfile('data', 'NEJ-2.xlsx');
cfg.data.train_well   = 'NEJ-1';
cfg.data.blind_well   = 'NEJ-2';
cfg.data.canonical_cols = {'DEPTH','GR','RHOB','NPHI','PHIE','VP','VS'};

cfg.data.sanity.GR    = [0, 250];
cfg.data.sanity.RHOB  = [1.5, 3.2];
cfg.data.sanity.NPHI  = [-0.05, 1.0];
cfg.data.sanity.PHIE  = [0, 0.6];
cfg.data.sanity.VP    = [1.0, 7.0];
cfg.data.sanity.VS    = [0.3, 4.5];

cfg.data.null_sentinels = [-999, -999.25, -9999, -99999];

% =========================================================================
% PREPROCESSING
% =========================================================================
cfg.preprocess.iqr_k             = 1.5;
cfg.preprocess.zscore_thresh     = 3;
cfg.preprocess.gap_short_max     = 5;
cfg.preprocess.knn_k             = 5;
cfg.preprocess.savgol_order      = 2;
cfg.preprocess.savgol_window     = 11;
cfg.preprocess.depth_step_m      = 0.1524;
cfg.preprocess.normalize_method  = 'zscore';

% =========================================================================
% SEED + SPLIT
% =========================================================================
cfg.seed                = 42;
cfg.split.test_fraction = 0.20;
cfg.split.k_fold        = 5;

% =========================================================================
% FEATURE SELECTION (all 4 scenarios run; tighten to force meaningful diff)
% =========================================================================
cfg.features.scenarios       = {'S1_intersection','S2_all', ...
                                'S3_mrmr_only','S4_lasso_only'};
cfg.features.mrmr_top_k      = 3;            % force S3 ≠ S2 (3 of 5)
cfg.features.lasso_alpha     = 1.0;          % full L1 (more aggressive)
cfg.features.lasso_lambda    = [];           % CV-selected
cfg.features.candidate_logs  = {'GR','RHOB','NPHI','PHIE','VP'};
cfg.features.target          = 'VS';

% =========================================================================
% MODELS
% =========================================================================
cfg.optimization.enabled  = true;
cfg.optimization.method   = 'grid';
cfg.optimization.max_evals = 12;

% PNN
cfg.model.pnn.default.spread    = 0.5;
cfg.model.pnn.grid.spread       = [0.25, 0.5, 0.85, 1.5];

% MLFFNN
cfg.model.mlffnn.default.hidden     = [32 16];
cfg.model.mlffnn.default.lr         = 0.01;
cfg.model.mlffnn.default.epochs     = 100;
cfg.model.mlffnn.default.dropout    = 0.1;
cfg.model.mlffnn.default.L2         = 1e-4;
cfg.model.mlffnn.grid.hidden        = {[16], [32 16], [64 32]};
cfg.model.mlffnn.grid.lr            = [0.001, 0.01];

% DFFNN
cfg.model.dffnn.default.hidden      = [64 32 16];
cfg.model.dffnn.default.lr          = 0.001;
cfg.model.dffnn.default.epochs      = 100;
cfg.model.dffnn.default.dropout     = 0.2;
cfg.model.dffnn.default.L2          = 1e-3;
cfg.model.dffnn.grid.hidden         = {[32 16 8], [64 32 16], [128 64 32]};
cfg.model.dffnn.grid.lr             = [0.0005, 0.001];

% CNN1D (sped up)
cfg.model.cnn1d.default.kernel      = 3;
cfg.model.cnn1d.default.filters     = 16;
cfg.model.cnn1d.default.epochs      = 25;
cfg.model.cnn1d.default.lr          = 0.001;
cfg.model.cnn1d.default.dropout     = 0.2;
cfg.model.cnn1d.default.window      = 16;
cfg.model.cnn1d.grid.kernel         = [3];
cfg.model.cnn1d.grid.filters        = [16, 32];

% =========================================================================
% STACKING
% =========================================================================
cfg.stacking.use_oof              = true;
cfg.stacking.candidates           = {'ridge','icnn','hybrid_icnn'};

cfg.model.ridge.lambda_grid       = logspace(-2, 2, 21);
cfg.model.ridge.cv_folds          = 10;

cfg.model.icnn.kernels            = [3 5 7];
cfg.model.icnn.filters            = 32;
cfg.model.icnn.epochs             = 100;
cfg.model.icnn.lr                 = 0.001;
cfg.model.icnn.dropout            = 0.2;

cfg.model.hybrid_icnn.window      = 16;
cfg.model.hybrid_icnn.kernels     = [3 5 7];
cfg.model.hybrid_icnn.filters     = 32;
cfg.model.hybrid_icnn.epochs      = 100;
cfg.model.hybrid_icnn.lr          = 0.001;

% =========================================================================
% MODEL-SELECTION POLICY
% =========================================================================
cfg.selection.tie_threshold      = 0.005;   % ΔR² < this → practically tied
cfg.selection.r2_tie_threshold   = 0.005;   % legacy alias used by old code
cfg.selection.prefer_simpler     = true;
cfg.selection.simplicity_order   = {'ridge','pnn','mlffnn','dffnn','icnn','cnn1d','hybrid_icnn'};

% =========================================================================
% UNCERTAINTY
% =========================================================================
cfg.uncertainty.enabled           = true;
cfg.uncertainty.mc_dropout_T      = 200;
cfg.uncertainty.pi_level          = 0.95;

% =========================================================================
% DEPLOYMENT / OOD / CLIPPING
% =========================================================================
cfg.deployment.vs_clip_kms        = [0.20, 4.50];
cfg.deployment.ood_zthresh        = 3;
cfg.geomech.nu_range              = [0.0, 0.5];
cfg.geomech.g_min                 = 0;
cfg.geomech.k_min                 = 0;

% =========================================================================
% EMPIRICAL BASELINES
% =========================================================================
cfg.empirical.castagna.a          = 0.8042;
cfg.empirical.castagna.b          = -0.8559;
cfg.empirical.gc_shale.a          = 0.7700;
cfg.empirical.gc_shale.b          = -0.8674;
cfg.empirical.gc_sand.a           = 0.7936;
cfg.empirical.gc_sand.b           = -0.7868;
cfg.empirical.gc_limestone.a      = -0.05509;
cfg.empirical.gc_limestone.b      = 1.0168;
cfg.empirical.gc_limestone.c      = -1.0305;

% =========================================================================
% FIGURE STYLING (publication ready)
% =========================================================================
cfg.fig.dpi              = 300;
cfg.fig.font_size        = 11;
cfg.fig.font_name        = 'Arial';            % publication standard
cfg.fig.line_width       = 1.4;
cfg.fig.marker_size      = 5;
cfg.fig.color_measured   = [0.05 0.05 0.05];
cfg.fig.color_predicted  = [0.80 0.20 0.20];
cfg.fig.color_castagna   = [0.20 0.40 0.78];
cfg.fig.color_gc_lime    = [0.45 0.25 0.70];
cfg.fig.color_ood        = [0.82 0.82 0.82];
cfg.fig.color_pi_band    = [0.98 0.78 0.55];
cfg.fig.format           = 'png';

% NEJ-1 focused depth for Fig 5 (study interval)
cfg.fig.nej1_focus       = [1415, 1993];

% Track-axis limits
cfg.fig.xlim.NEJ1.GR     = [0 200];
cfg.fig.xlim.NEJ1.RHOB   = [1.5 3.0];
cfg.fig.xlim.NEJ1.VP     = [1.5 7.0];
cfg.fig.xlim.NEJ1.VS     = [0.5 4.5];
cfg.fig.xlim.NEJ1.NU     = [-0.2 0.6];
cfg.fig.xlim.NEJ2.GR     = [0 200];
cfg.fig.xlim.NEJ2.RHOB   = [1.5 3.0];
cfg.fig.xlim.NEJ2.VP     = [1.5 7.0];
cfg.fig.xlim.NEJ2.VS     = [0.5 4.5];
cfg.fig.xlim.NEJ2.NU     = [-0.2 0.6];

end
