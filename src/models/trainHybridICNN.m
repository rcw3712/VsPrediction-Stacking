function res = trainHybridICNN(Xtrain, metaTr, ytrain, Xtest, metaTe, ytest, cfg, logFile)
%TRAINHYBRIDICNN  Hybrid Feature-Fusion Multi-Scale I-CNN.
%
%   NOVELTY of this study. Unlike the simple "I-CNN as stacker" baseline
%   (which convolves over only 4 base-learner predictions and has no
%   meaningful spatial structure), this architecture integrates:
%
%      [ Original log sequence (P_orig channels) ]
%      [ Base-learner predictions (K channels)   ]
%             ↓  concat along channel dim
%      [ Windowed tensor: W x (P_orig+K) x 1 x N ]
%             ↓
%      Multi-scale parallel CNN branches  (kernels 3, 5, 7)
%             ↓
%      Concatenation fusion -> FC head -> Vs
%
%   This justifies "multi-scale" claim geologically:
%     - small kernel (3): thin-bed transitions in original logs
%     - medium kernel (5): facies signature + base learner consensus
%     - large kernel (7): compaction trend + long-range geological context
%
%   Inputs
%     Xtrain  [Ntr x P_orig]  - original feature matrix (z-scored)
%     metaTr  [Ntr x K]       - base-learner predictions on Xtrain (OOF)
%     ytrain  [Ntr x 1]       - target (z-scored)
%     Xtest, metaTe, ytest    - same for held-out test set
%     cfg, logFile
%
%   Output (struct compatible with deployToBT1.m)
%     res.kind        = 'hybrid'
%     res.net         - trained dlnetwork
%     res.trainInfo   - training history
%     res.yhatTrain   - in-sample predictions
%     res.yhatTest    - held-out predictions
%     res.metricsTrain / .metricsTest = [R2 RMSE MAE MAPE]
%     res.params      - architecture params (windowSize, etc.)
%--------------------------------------------------------------------------

W = cfg.icnn.windowSize;
P_orig = size(Xtrain, 2);
K      = size(metaTr, 2);
P      = P_orig + K;                  % concatenated channel count

% --- Build the fused tensor [W x P x 1 x N] -------------------------
[Xtra, ytw] = buildFusionTensor(Xtrain, metaTr, ytrain, W);
[Xtea, ytew] = buildFusionTensor(Xtest, metaTe, ytest, W);
Ntr = size(Xtra, 4);

logMsg(logFile, sprintf( ...
    '  Hybrid I-CNN input: W=%d, channels=%d (%d original + %d base preds), N_train=%d', ...
    W, P, P_orig, K, Ntr));

% --- Build the multi-scale I-CNN network ----------------------------
lgraph = buildICNNNetwork(W, P, cfg.icnn);

% --- Training options ----------------------------------------------
opts = trainingOptions('adam', ...
    'MaxEpochs',          cfg.icnn.maxEpochs, ...
    'InitialLearnRate',   cfg.icnn.lr, ...
    'L2Regularization',   cfg.icnn.l2, ...
    'MiniBatchSize',      min(cfg.icnn.miniBatch, Ntr), ...
    'Shuffle',           'every-epoch', ...
    'Verbose',            false, ...
    'OutputNetwork',      'best-validation-loss', ...
    'ValidationFrequency',10, ...
    'ValidationPatience', cfg.icnn.patience, ...
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropFactor',0.5, ...
    'LearnRateDropPeriod',60);

% Validation split (15% of train)
rng('default');
nv = max(1, round(0.15*Ntr));
idx = randperm(Ntr); val = idx(1:nv); tra = idx(nv+1:end);
opts.ValidationData = {Xtra(:,:,:,val), single(ytw(val))};

logMsg(logFile, '  Training Hybrid Multi-scale I-CNN ...');
net0 = dlnetwork(lgraph);              % R2024b: trainnet needs dlnetwork
[net, info] = trainnet(Xtra(:,:,:,tra), single(ytw(tra)), net0, 'mse', opts);

% --- Predict --------------------------------------------------------
yhTr = double(predict(net, Xtra)); yhTr = yhTr(:);
yhTe = double(predict(net, Xtea)); yhTe = yhTe(:);

% --- Pack results ---------------------------------------------------
res.kind          = 'hybrid';
res.net           = net;
res.trainInfo     = info;
res.params        = cfg.icnn;
res.params.P_orig = P_orig;
res.params.K_base = K;
res.yhatTrain     = yhTr;
res.yhatTest      = yhTe;
res.metricsTrain  = computeMetrics(ytw , yhTr);
res.metricsTest   = computeMetrics(ytew, yhTe);

logMsg(logFile, sprintf( ...
    '  Hybrid I-CNN  : test  R2=%.3f RMSE=%.3f MAE=%.3f', ...
    res.metricsTest(1), res.metricsTest(2), res.metricsTest(3)));

% --- Diagnostic plot: predicted vs actual ---------------------------
try
    fig = figure('Color','w','Position',[100 100 600 500],'Visible','off');
    ax = gca; hold(ax,'on');
    scatter(ax, ytew, yhTe, 18, 'filled', 'MarkerFaceAlpha', 0.55);
    lim = [min([ytew; yhTe]) max([ytew; yhTe])];
    plot(ax, lim, lim, 'k--', 'LineWidth',1.2);
    xlabel(ax,'Actual Vs (z-score)'); ylabel(ax,'Predicted Vs (z-score)');
    title(ax, sprintf('Hybrid I-CNN: R^2=%.3f  RMSE=%.3f', ...
        res.metricsTest(1), res.metricsTest(2)));
    grid(ax,'on'); box(ax,'on');
    savePublicationFigure(fig, 'META_hybrid_pred_vs_actual', cfg);
    close(fig);
catch ME
    warning('trainHybridICNN:plot', 'Scatter plot failed: %s', ME.message);
end
end

% =======================================================================
function [Xa, yw] = buildFusionTensor(X, metaFeat, y, W)
%BUILDFUSIONTENSOR  Concatenate (X | metaFeat) along channel dim and
% window along depth, returning a 4-D tensor ready for conv2d.
%
%   X        [N x P_orig]
%   metaFeat [N x K]
%   y        [N x 1]
%   W        scalar window size
%
%   Returns
%     Xa   [W x P x 1 x N_win]  single tensor
%     yw   [N_win x 1]          windowed target (centred on the window)
%
%   Sample i in Xa corresponds to depth-rows (i:i+W-1) of the input;
%   yw(i) = y(i + floor(W/2))  (centred prediction target).

P_orig = size(X, 2);
K      = size(metaFeat, 2);
P      = P_orig + K;
Fused  = [X, metaFeat];                  % N x P

N = size(Fused, 1);
nWin = N - W + 1;
if nWin < 1
    error('buildFusionTensor:WindowTooLarge', ...
        'Window size %d > number of samples %d', W, N);
end

Xa = zeros(W, P, 1, nWin, 'single');
yw = zeros(nWin, 1);
ctr = floor(W/2) + 1;                    % center offset in window
for i = 1:nWin
    Xa(:, :, 1, i) = single(Fused(i:i+W-1, :));
    yw(i) = y(i + ctr - 1);
end
end
