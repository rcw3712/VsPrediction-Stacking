function res = trainICNNMeta(Xmeta_tr, ytr, Xmeta_te, yte, cfg, logFile)
%TRAINICNNMETA  Train the I-CNN multi-stack meta-learner.
%
%   Input meta-features are stacked depth-windows (W x P_meta x 1)
%   produced from base-learner predictions. The I-CNN exploits vertical
%   context to refine the stacked predictions.

W = cfg.icnn.windowSize;
P = size(Xmeta_tr, 2);
[Xtw, ytw] = makeWindows(Xmeta_tr, ytr, W);
[Xtew, ytew] = makeWindows(Xmeta_te, yte, W);

Ntr = numel(Xtw); Nte = numel(Xtew);
Xtra = zeros(W, P, 1, Ntr, 'single');
for i = 1:Ntr; Xtra(:,:,1,i) = single(Xtw{i}); end
Xtea = zeros(W, P, 1, Nte, 'single');
for i = 1:Nte; Xtea(:,:,1,i) = single(Xtew{i}); end

lgraph = buildICNNNetwork(W, P, cfg.icnn);

opts = trainingOptions('adam', ...
    'MaxEpochs',         cfg.icnn.maxEpochs, ...
    'InitialLearnRate',  cfg.icnn.lr, ...
    'L2Regularization',  cfg.icnn.l2, ...
    'MiniBatchSize',     min(cfg.icnn.miniBatch, Ntr), ...
    'Shuffle',           'every-epoch', ...
    'Verbose',            false, ...
    'OutputNetwork',      'best-validation-loss', ...
    'ValidationFrequency',10, ...
    'ValidationPatience', cfg.icnn.patience, ...
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropFactor',0.5, ...
    'LearnRateDropPeriod',60);

rng('default');
nv = max(1, round(0.15*Ntr));
idx = randperm(Ntr); val = idx(1:nv); tra = idx(nv+1:end);
opts.ValidationData = {Xtra(:,:,:,val), single(ytw(val))};

logMsg(logFile, '  Training I-CNN multi-stack ...');
% trainnet (R2024b) requires a dlnetwork or layer array, not a layerGraph
net0 = dlnetwork(lgraph);
[net, info] = trainnet(Xtra(:,:,:,tra), single(ytw(tra)), net0, 'mse', opts);

yhTr = double(predict(net, Xtra)); yhTr = yhTr(:);
yhTe = double(predict(net, Xtea)); yhTe = yhTe(:);

res.net          = net;
res.trainInfo    = info;
res.params       = cfg.icnn;
res.yhatTrain    = yhTr;
res.yhatTest     = yhTe;
res.metricsTrain = computeMetrics(ytw, yhTr);
res.metricsTest  = computeMetrics(ytew, yhTe);

logMsg(logFile, sprintf('  I-CNN test  R2=%.3f RMSE=%.3f MAE=%.3f MAPE=%.2f%%', ...
    res.metricsTest));

% --- Plots -------------------------------------------------------------
plotICNNEvaluation(ytew, yhTe, cfg);

% --- Save metrics ------------------------------------------------------
T = table({'I-CNN'}, res.metricsTest(1), res.metricsTest(2), res.metricsTest(3), res.metricsTest(4), ...
    'VariableNames',{'Model','R2','RMSE','MAE','MAPE'});
exportTable(T, 'icnn_metrics', cfg);
res.summaryTable = T;
end

% =======================================================================
function plotICNNEvaluation(y, yh, cfg)
fig = figure('Color','w','Position',[100 100 900 400],'Visible','off');
tl = tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');

ax1 = nexttile(tl);
scatter(ax1, y, yh, 12, 'filled', 'MarkerFaceColor',[0.20 0.55 0.85]); hold(ax1,'on');
mn = min([y;yh]); mx = max([y;yh]);
plot(ax1,[mn mx],[mn mx],'k--','LineWidth',1.2);
xlabel(ax1,'Vs actual (norm.)'); ylabel(ax1,'Vs I-CNN (norm.)');
m = computeMetrics(y, yh);
text(ax1, mn+0.05*(mx-mn), mx-0.1*(mx-mn), ...
    sprintf('R^2=%.3f\nRMSE=%.3f', m(1), m(2)), 'BackgroundColor','w');
title(ax1,'Predicted vs Actual'); grid(ax1,'on');

ax2 = nexttile(tl);
res = y - yh;
histogram(ax2, res, 30, 'FaceColor',[0.85 0.45 0.20], 'EdgeColor','k');
xlabel(ax2,'Residual'); ylabel(ax2,'Frequency');
title(ax2,'Residual histogram'); grid(ax2,'on');

savePublicationFigure(fig, 'ICNN_eval', cfg);
close(fig);
end
