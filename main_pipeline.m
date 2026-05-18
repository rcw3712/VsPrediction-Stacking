%==========================================================================
% MAIN_PIPELINE.M
%--------------------------------------------------------------------------
% Vs Prediction from Conventional Well Logs using Stacking Deep Learning
%--------------------------------------------------------------------------
% Project : Shear-wave velocity (Vs) prediction
% Wells   : BT-4 (calibrated, has Vs)  -> Training/Testing/Tuning
%           BT-1 (deployment, no Vs)  -> Inference + indirect validation
% Logs    : GR, RHOB, NPHI, PHIE, DT, CHKS
% Author  : Geophysics-ML Research Group
% MATLAB  : R2024b
%--------------------------------------------------------------------------
% This script orchestrates the end-to-end workflow:
%   1) Data loading (LAS) + curve extraction + depth alignment
%   2) Preprocessing (outliers, imputation, denoising, normalization)
%   3) Feature selection (mRMR, LASSO, SHAP)
%   4) Base learners (PNN, MLFFNN, DFFNN, CNN-1D)
%   5) Hyperparameter optimization (Bayesian + limited grid search)
%   6) Stacking with I-CNN multi-stack as meta-learner
%   7) Uncertainty analysis (MC-Dropout, ensemble)
%   8) Ablation study (4 scenarios)
%   9) Deployment to BT-1 with empirical validation
%==========================================================================

clear; clc; close all;

%% --- 0. Setup paths and configuration ----------------------------------
projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(projectRoot, 'src')));
addpath(fullfile(projectRoot, 'config'));

cfg = pipelineConfig(projectRoot);     % single source of truth
createFolders(cfg);                    % auto-create all output folders
logFile = setupLogger(cfg);            % file + console logging
logMsg(logFile, '=== Vs Prediction Pipeline Started ===');
logMsg(logFile, sprintf('Run timestamp : %s', cfg.runStamp));
logMsg(logFile, sprintf('Project root  : %s', projectRoot));

% Global reproducibility
rng(cfg.randomSeed, 'twister');

%% --- 1. Data loading ----------------------------------------------------
logMsg(logFile, '[1/10] Loading well data (auto-detect format) ...');
wellBT4 = loadWellData(cfg.dataFiles.calibrated, cfg.requiredCurves      , true , logFile, cfg.lasAliases);
wellBT1 = loadWellData(cfg.dataFiles.deployment, cfg.requiredCurvesDeploy, false, logFile, cfg.lasAliases);

% Subset BT-4 to depth interval with valid VS (and complete features) so
% the model is only trained where ground truth exists.
if cfg.subsetToValidTarget
    wellBT4 = subsetToValidRows(wellBT4, cfg, logFile);
end
cfg.trainDepthRange = [min(wellBT4.depth), max(wellBT4.depth)];

% Persist raw extraction
save(fullfile(cfg.dirs.raw_data, 'wells_raw.mat'), 'wellBT4', 'wellBT1');

%% --- 2. Preprocessing ---------------------------------------------------
logMsg(logFile, '[2/10] Preprocessing both wells (consistent pipeline) ...');
[BT4, ppStatsBT4] = preprocessWell(wellBT4, cfg, logFile, 'BT-4');
[BT1, ppStatsBT1] = preprocessWell(wellBT1, cfg, logFile, 'BT-1', ppStatsBT4);

save(fullfile(cfg.dirs.preprocessing, 'preprocessed.mat'), ...
    'BT4', 'BT1', 'ppStatsBT4', 'ppStatsBT1');

%% --- 3. Feature selection (BT-4 only) ----------------------------------
logMsg(logFile, '[3/10] Feature selection on BT-4 (mRMR + LASSO + SHAP) ...');
fsRes = featureSelectionPipeline(BT4, cfg, logFile);
save(fullfile(cfg.dirs.feature_selection, 'feature_selection.mat'), 'fsRes');

% Final feature set (intersection / union per config)
finalFeatures = fsRes.finalFeatures;
logMsg(logFile, sprintf('Final features: %s', strjoin(finalFeatures, ', ')));

%% --- 4. Base learners ---------------------------------------------------
logMsg(logFile, '[4/10] Training base learners with k-fold CV ...');
[Xtrain, Ytrain, Xtest, Ytest, splitInfo] = ...
    splitTrainTest(BT4, finalFeatures, cfg);

baseRes = trainBaseLearners(Xtrain, Ytrain, Xtest, Ytest, cfg, logFile);
save(fullfile(cfg.dirs.base_models, 'base_learners.mat'), ...
    'baseRes', 'Xtrain', 'Ytrain', 'Xtest', 'Ytest', 'splitInfo');

%% --- 5. Hyperparameter optimization -------------------------------------
logMsg(logFile, '[5/10] Hyperparameter optimization (Bayesian + limited grid seed) ...');
optRes = hyperparameterOptimization(Xtrain, Ytrain, Xtest, Ytest, cfg, logFile);
save(fullfile(cfg.dirs.optimization, 'optimization.mat'), 'optRes');

% Learning curves (per flowchart stage 7 -- "Learning Curve")
plotLearningCurves(baseRes, optRes, cfg);

%% --- 6. Meta-feature generation ----------------------------------------
logMsg(logFile, '[6/10] Generating meta-features from optimal base learners ...');
metaFeatTrain = generateMetaFeatures(optRes, Xtrain, Ytrain, 'train', cfg);
metaFeatTest  = generateMetaFeatures(optRes, Xtest , Ytest , 'test' , cfg);

%% --- 7. Meta-learners (3 variants: I-CNN stacker, Ridge, Hybrid I-CNN) -
logMsg(logFile, '[7/10] Training 3 meta-learners (stacker, ridge, hybrid) ...');

% (a) I-CNN as simple stacker over 4 base predictions (baseline)
icnnRes   = trainICNNMeta(metaFeatTrain, Ytrain, metaFeatTest, Ytest, cfg, logFile);

% (b) Ridge regression closed-form stacker (lightweight baseline)
ridgeRes  = trainRidgeStacker(metaFeatTrain, Ytrain, metaFeatTest, Ytest, cfg, logFile);

% (c) Hybrid Multi-scale Feature-Fusion I-CNN  (PRIMARY NOVELTY)
%     Fuses original log sequences with base-learner predictions.
hybridRes = trainHybridICNN(Xtrain, metaFeatTrain, Ytrain, ...
                            Xtest , metaFeatTest , Ytest , cfg, logFile);

% Train all 3 variants for full ablation reporting
metaCandidates = struct('icnn', icnnRes, 'ridge', ridgeRes, 'hybrid', hybridRes);
metaR2 = struct('icnn', icnnRes.metricsTest(1), ...
                'ridge', ridgeRes.metricsTest(1), ...
                'hybrid', hybridRes.metricsTest(1));
logMsg(logFile, sprintf( ...
    '  Test R2 summary -- I-CNN stacker: %.3f | Ridge: %.3f | Hybrid I-CNN: %.3f', ...
    metaR2.icnn, metaR2.ridge, metaR2.hybrid));

% Select meta-learner for deployment per cfg.meta.deploymentChoice
choice = lower(cfg.meta.deploymentChoice);
if strcmp(choice, 'auto')
    [~, iBest] = max([metaR2.icnn, metaR2.ridge, metaR2.hybrid]);
    choices = {'icnn','ridge','hybrid'};
    choice = choices{iBest};
end
switch choice
    case 'ridge'  , metaRes = ridgeRes;
    case 'hybrid' , metaRes = hybridRes;
    case 'icnn'   , metaRes = icnnRes;
    otherwise
        error('main_pipeline:BadMetaChoice', ...
            'Unknown cfg.meta.deploymentChoice "%s"', cfg.meta.deploymentChoice);
end
logMsg(logFile, sprintf('  >>> Deployment meta-learner: %s (kind=%s, test R2=%.3f)', ...
    upper(choice), metaRes.kind, metaRes.metricsTest(1)));

save(fullfile(cfg.dirs.icnn_meta, 'icnn_meta.mat'), ...
    'icnnRes', 'ridgeRes', 'hybridRes', 'metaRes', ...
    'metaFeatTrain', 'metaFeatTest');

%% --- 8. Uncertainty analysis -------------------------------------------
logMsg(logFile, '[8/10] Uncertainty analysis (MC-Dropout + Ensemble) ...');
uqRes = uncertaintyAnalysis(icnnRes, metaFeatTest, Ytest, cfg, logFile);
save(fullfile(cfg.dirs.uncertainty, 'uncertainty.mat'), 'uqRes');

%% --- 9. Ablation study --------------------------------------------------
logMsg(logFile, '[9/10] Ablation study (4 scenarios) ...');
ablRes = ablationStudy(BT4, fsRes, cfg, logFile);
save(fullfile(cfg.dirs.ablation, 'ablation.mat'), 'ablRes');

%% --- 10. Deployment to BT-1 -------------------------------------------
logMsg(logFile, '[10/10] Deployment to BT-1 + empirical validation ...');
depRes = deployToBT1(BT1, finalFeatures, optRes, metaRes, cfg, logFile);
save(fullfile(cfg.dirs.deployment, 'deployment.mat'), 'depRes');

%% --- Final reporting ----------------------------------------------------
generateFinalReport(baseRes, optRes, icnnRes, uqRes, ablRes, depRes, cfg, logFile, ridgeRes, hybridRes);

logMsg(logFile, '=== Pipeline finished successfully ===');
fclose(logFile.fid);

fprintf('\nAll outputs in : %s\n', cfg.dirs.runRoot);
