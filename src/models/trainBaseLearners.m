function res = trainBaseLearners(Xtr, ytr, Xte, yte, cfg, logFile)
%TRAINBASELEARNERS  Train PNN, MLFFNN, DFFNN, CNN-1D and evaluate.
%
%   K-fold cross-validation is performed on the training set; the final
%   models are also retrained on the full training fold and evaluated
%   on the held-out test set.

models = {'PNN','MLFFNN','DFFNN','CNN1D'};
res    = struct();

for m = 1:numel(models)
    name = models{m};
    logMsg(logFile, sprintf('  Training %s ...', name));

    % --- K-fold CV ----------------------------------------------------
    cv = cvpartition(numel(ytr), 'KFold', cfg.split.kFold);
    cvMetrics = zeros(cv.NumTestSets, 4);  % R2 RMSE MAE MAPE
    for f = 1:cv.NumTestSets
        idTr = training(cv, f); idVa = test(cv, f);
        mdlF = trainOne(name, Xtr(idTr,:), ytr(idTr), cfg);
        yhat = predictOne(name, mdlF, Xtr(idVa,:), cfg);
        cvMetrics(f,:) = computeMetrics(ytr(idVa), yhat);
    end
    res.(name).cv = cvMetrics;
    res.(name).cvMean = mean(cvMetrics, 1);
    res.(name).cvStd  = std(cvMetrics, 0, 1);

    % --- Final model on full train + test eval ------------------------
    mdl = trainOne(name, Xtr, ytr, cfg);
    yhTr = predictOne(name, mdl, Xtr, cfg);
    yhTe = predictOne(name, mdl, Xte, cfg);
    res.(name).model     = mdl;
    res.(name).yhatTrain = yhTr;
    res.(name).yhatTest  = yhTe;
    res.(name).metricsTrain = computeMetrics(ytr, yhTr);
    res.(name).metricsTest  = computeMetrics(yte, yhTe);

    logMsg(logFile, sprintf('     test  R2=%.3f RMSE=%.3f MAE=%.3f MAPE=%.2f%%', ...
        res.(name).metricsTest));
end

% --- Comparative plots --------------------------------------------------
plotBaseLearnerEvaluation(res, ytr, yte, cfg);

% --- Tables ------------------------------------------------------------
T = table('Size',[numel(models) 8], ...
    'VariableTypes',{'string','double','double','double','double','double','double','double'}, ...
    'VariableNames',{'Model','R2_cv','R2_test','RMSE_cv','RMSE_test','MAE_test','MAPE_test','R2_std_cv'});
for m = 1:numel(models)
    nm = models{m};
    T(m,:) = {nm, res.(nm).cvMean(1), res.(nm).metricsTest(1), ...
                  res.(nm).cvMean(2), res.(nm).metricsTest(2), ...
                  res.(nm).metricsTest(3), res.(nm).metricsTest(4), ...
                  res.(nm).cvStd(1)};
end
exportTable(T, 'base_learners_metrics', cfg);
res.summaryTable = T;
end

% =======================================================================
function mdl = trainOne(name, X, y, cfg)
switch upper(name)
    case 'PNN'    , mdl = trainPNN(X, y, cfg.base.PNN);
    case 'MLFFNN' , mdl = trainMLFFNN(X, y, cfg.base.MLFFNN);
    case 'DFFNN'  , mdl = trainDFFNN(X, y, cfg.base.DFFNN);
    case 'CNN1D'  , mdl = trainCNN1D(X, y, cfg.base.CNN1D);
end
end

function yhat = predictOne(name, mdl, X, cfg)
switch upper(name)
    case 'PNN'    , yhat = predictPNN(mdl, X);
    case 'MLFFNN' , yhat = predictNN(mdl, X);
    case 'DFFNN'  , yhat = predictNN(mdl, X);
    case 'CNN1D'  , yhat = predictCNN1D(mdl, X, cfg.base.CNN1D);
end
end
