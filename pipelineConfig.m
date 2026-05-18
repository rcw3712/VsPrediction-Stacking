function cfg = pipelineConfig(projectRoot)
%PIPELINECONFIG  Single source of truth for the Vs prediction pipeline.
%   Modify paths and hyperparameters here without touching the main script.
%
%   Returns a struct CFG containing every parameter required by the
%   downstream modules (paths, preprocessing, models, optimization, etc.).
%--------------------------------------------------------------------------

if nargin < 1 || isempty(projectRoot)
    projectRoot = pwd;
end

%% --- Run identification -------------------------------------------------
cfg.runStamp   = datestr(now, 'yyyymmdd_HHMMSS');
cfg.randomSeed = 42;
cfg.projectRoot = projectRoot;

%% --- Input data ---------------------------------------------------------
% Data format auto-detected from extension (.xlsx, .xls, .csv, or .las)
% Calibrated well = BT-4   (must contain VS as target)
% Deployment well = BT-1   (no VS column; predicted via stacking model)
cfg.dataFiles.calibrated = fullfile(projectRoot, 'data', 'BT-4.xlsx');
cfg.dataFiles.deployment = fullfile(projectRoot, 'data', 'BT-1.xlsx');

% Logs to be used.  Header units expected: GR(API), RHOB(g/cc),
% NPHI(v/v), PHIE(v/v), VP(m/s), VS(m/s).  DEPTH may be in ft or m
% (auto-converted to m).
cfg.requiredCurves       = {'GR','RHOB','NPHI','PHIE','VP','VS'};
cfg.requiredCurvesDeploy = {'GR','RHOB','NPHI','PHIE','VP'};
cfg.targetCurve          = 'VS';
cfg.featureCurves        = {'GR','RHOB','NPHI','PHIE','VP'};

% --- Mnemonic alias overrides (use if your headers are non-standard) ---
% Built-in aliases already cover: PHIT/PHI/POROEFF -> PHIE,
%   RHOZ/DEN -> RHOB, TNPH -> NPHI, GAMMA/CGR -> GR,
%   VEL_P/PVEL -> VP, VS_FAST/SVEL -> VS, DTC/DTCO -> DT, DTSM -> DTS, etc.
% Add your specific mappings below (header text, case-insensitive). Examples:
%   cfg.lasAliases.PHIE_BCS = 'PHIE';      % company-specific effective porosity
%   cfg.lasAliases.VSM      = 'VS';        % Vs measured
%   cfg.lasAliases.GRD      = 'GR';        % gamma-ray downhole
cfg.lasAliases = struct();                  % leave empty if not needed

% --- Row subsetting (training subset auto-selected to rows with valid VS) --
cfg.subsetToValidTarget = true;             % keep only rows where VS is valid in BT-4
cfg.subsetRequireAllFeatures = true;        % AND where all feature columns are valid

%% --- Output directory tree ---------------------------------------------
cfg.dirs.runRoot         = fullfile(projectRoot, 'results', cfg.runStamp);
cfg.dirs.raw_data        = fullfile(cfg.dirs.runRoot, 'raw_data');
cfg.dirs.preprocessing   = fullfile(cfg.dirs.runRoot, 'preprocessing');
cfg.dirs.feature_selection = fullfile(cfg.dirs.runRoot, 'feature_selection');
cfg.dirs.base_models     = fullfile(cfg.dirs.runRoot, 'base_models');
cfg.dirs.icnn_meta       = fullfile(cfg.dirs.runRoot, 'icnn_meta');
cfg.dirs.optimization    = fullfile(cfg.dirs.runRoot, 'optimization');
cfg.dirs.evaluation      = fullfile(cfg.dirs.runRoot, 'evaluation');
cfg.dirs.uncertainty     = fullfile(cfg.dirs.runRoot, 'uncertainty');
cfg.dirs.ablation        = fullfile(cfg.dirs.runRoot, 'ablation');
cfg.dirs.deployment      = fullfile(cfg.dirs.runRoot, 'deployment');
cfg.dirs.figures         = fullfile(cfg.dirs.runRoot, 'figures');
cfg.dirs.tables          = fullfile(cfg.dirs.runRoot, 'tables');
cfg.dirs.logs            = fullfile(cfg.dirs.runRoot, 'logs');

%% --- Preprocessing -----------------------------------------------------
cfg.pp.outlierMethod   = 'IQR';      % 'IQR' or 'zscore' or 'both'
cfg.pp.iqrFactor       = 3.0;
cfg.pp.zScoreThr       = 3.0;
cfg.pp.imputationMethod = 'KNN';     % 'linear' / 'spline' / 'KNN'
cfg.pp.knnNeighbors    = 5;
cfg.pp.savgolOrder     = 3;
cfg.pp.savgolFrameLen  = 11;          % must be odd
cfg.pp.normalization   = 'zscore';   % 'zscore' or 'minmax' (used for ML)
cfg.pp.resampleStep    = 0.1524;     % m  (=0.5 ft, typical wireline step)
cfg.pp.depthMin        = [];         % auto if empty
cfg.pp.depthMax        = [];

%% --- Feature selection -------------------------------------------------
cfg.fs.mrmrTopK        = 6;
cfg.fs.lassoCV         = 10;
cfg.fs.lassoAlpha      = 1.0;        % pure LASSO
cfg.fs.combineRule     = 'mrmr_only'; % 'mrmr_only' (recommended), 'intersect', 'union', or 'lasso_only'
% Ablation revealed mRMR-only is optimal for this 5-feature dataset --
% intersection (mRMR ∩ LASSO) drops GR, which is crucial for sand/shale
% discrimination. See ablation_summary.xlsx for justification.
cfg.fs.shapNumSamples  = 200;        % background pool size
cfg.fs.shapNumExplain  = 300;        % samples to compute SHAP for (subset)
cfg.fs.shapNumPerm     = 50;         % permutations per sample (Strumbelj-Kononenko)

%% --- Train/test split --------------------------------------------------
cfg.split.testFraction = 0.2;
cfg.split.kFold        = 5;
cfg.split.stratifyBy   = 'depth';    % preserves vertical heterogeneity

%% --- Base learners (default hyperparameters) --------------------------
cfg.base.PNN.spread    = 0.1;

cfg.base.MLFFNN.hiddenSizes = [32 16];
cfg.base.MLFFNN.maxEpochs   = 200;
cfg.base.MLFFNN.lr          = 1e-3;
cfg.base.MLFFNN.l2          = 1e-4;

% DFFNN: trimmed to suit small tabular data (~3500 samples, 5 features).
% Old [64 64 32 16] was over-parameterised -> overfit. New [32 16 8]
% keeps params/sample ratio reasonable; dropout 0.30 + L2 1e-3 add
% strong regularisation.
cfg.base.DFFNN.hiddenSizes  = [32 16 8];
cfg.base.DFFNN.maxEpochs    = 250;
cfg.base.DFFNN.lr           = 5e-4;
cfg.base.DFFNN.l2           = 1e-3;
cfg.base.DFFNN.dropout      = 0.30;

% CNN1D: small kernels, fewer filters, fewer blocks. With only 5 input
% channels and a short depth window, deep stacks add noise more than
% signal.  Window 16 provides ~2.4 m of depth context (better than 8).
cfg.base.CNN1D.numFilters   = 16;
cfg.base.CNN1D.kernelSize   = 3;
cfg.base.CNN1D.numBlocks    = 2;
cfg.base.CNN1D.maxEpochs    = 200;
cfg.base.CNN1D.lr           = 5e-4;
cfg.base.CNN1D.dropout      = 0.25;
cfg.base.CNN1D.windowSize   = 16;      % depth-window samples (was 8)
cfg.base.CNN1D.fixedSeed    = 7;       % reproducibility

%% --- Hyperparameter optimization ---------------------------------------
cfg.opt.method           = 'bayesopt';   % 'bayesopt' or 'grid'
cfg.opt.maxObjEvals      = 30;
cfg.opt.useParallel      = false;
cfg.opt.acquisition      = 'expected-improvement-plus';
cfg.opt.useGridSearch    = true;          % seed Bayesopt with limited grid (per flowchart)
% Inner-CV speed knobs (objective-function quick training)
cfg.opt.innerMaxEpochs   = 60;            % cap epochs DURING bayesopt evaluations
cfg.opt.innerPatience    = 10;            % early-stop patience during inner CV
cfg.opt.maxTimeSec       = 3600;          % wall-clock budget per model (sec); Inf = off

%% --- I-CNN meta-learner -----------------------------------------------
cfg.icnn.kernelsMulti    = [3 5 7];      % small / medium / large
cfg.icnn.filtersPerStack = 32;
cfg.icnn.numStacks       = 3;
cfg.icnn.fusion          = 'concat';     % 'concat' / 'sum' / 'attention'
cfg.icnn.fcSizes         = [64 32];
cfg.icnn.dropout         = 0.30;
cfg.icnn.maxEpochs       = 250;
cfg.icnn.miniBatch       = 32;
cfg.icnn.lr              = 5e-4;
cfg.icnn.l2              = 1e-4;
cfg.icnn.patience        = 25;
cfg.icnn.windowSize      = 16;

%% --- Meta-learner choice (Option C from research design) --------------
% Always trains 3 variants (I-CNN stacker, Ridge, Hybrid I-CNN) for
% reporting in ablation; this flag controls WHICH variant is deployed
% to BT-1. 'ridge' is recommended for small tabular datasets (most
% stable). 'auto' picks the highest test R^2 automatically.
cfg.meta.deploymentChoice = 'ridge';     % 'ridge' | 'icnn' | 'hybrid' | 'auto'

%% --- Uncertainty -------------------------------------------------------
cfg.uq.mcDropoutSamples  = 200;
cfg.uq.ensembleSize      = 10;
cfg.uq.ciLevel           = 0.95;

%% --- Empirical equations (deployment) ---------------------------------
cfg.emp.castagna.A      = 0.8042;     % Vs = A*Vp - B  (sandstone)
cfg.emp.castagna.B      = 0.8559;
cfg.emp.gcCoefs.sand    = [0.80416 -0.85588 0];
cfg.emp.gcCoefs.shale   = [0.76969 -0.86735 0];
cfg.emp.gcCoefs.lime    = [0.000 1.01677 -1.030500];   % (km/s) Vp^2 + Vp - Vs
cfg.emp.gcCoefs.dolo    = [-0.05508 1.01677 -1.030500];

%% --- Figures -----------------------------------------------------------
cfg.fig.dpi             = 300;
cfg.fig.format          = {'png', 'pdf'};
cfg.fig.fontName        = 'Arial';
cfg.fig.fontSize        = 11;
cfg.fig.lineWidth       = 1.4;

end
