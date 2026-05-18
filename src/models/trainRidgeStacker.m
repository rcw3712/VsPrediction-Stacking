function res = trainRidgeStacker(metaTr, ytr, metaTe, yte, cfg, logFile)
%TRAINRIDGESTACKER  Manual ridge regression meta-learner with K-fold CV.
%
%   Uses standard closed-form ridge solution (avoids fitrlinear API
%   quirks): beta = (X'X + lambda*I)^-1 X'y
%
%   Inputs  : metaTr [Ntr x K], ytr [Ntr x 1]
%             metaTe [Nte x K], yte [Nte x 1]
%             cfg, logFile
%   Outputs : res.B          - K weights
%             res.intercept  - bias term
%             res.yhatTrain  - in-sample prediction
%             res.yhatTest   - held-out prediction
%             res.metricsTrain / .metricsTest = [R2 RMSE MAE MAPE]
%             res.bestLambda - optimal lambda from CV
%             res.kind       = 'ridge'
%--------------------------------------------------------------------------

K = size(metaTr, 2);
if K == 0
    error('trainRidgeStacker:NoMetaFeatures', 'Empty meta-feature matrix.');
end

% Center training data for clean ridge regression ---------------------
xMu = mean(metaTr, 1, 'omitnan');
yMu = mean(ytr   , 'omitnan');
Xc  = metaTr - xMu;
yc  = ytr    - yMu;

% --- Manual K-fold CV ridge sweep ------------------------------------
lambdaGrid = logspace(-6, 2, 25);
nFolds     = 10;
rng(0, 'twister');
cv = cvpartition(numel(yc), 'KFold', nFolds);

cvMse = zeros(numel(lambdaGrid), 1);
for iL = 1:numel(lambdaGrid)
    lam = lambdaGrid(iL);
    foldMse = zeros(nFolds, 1);
    for f = 1:nFolds
        idTr = training(cv, f);  idVa = test(cv, f);
        Xtr = Xc(idTr,:);  ytr_f = yc(idTr);
        Xva = Xc(idVa,:);  yva   = yc(idVa);

        % Closed-form ridge: beta = (X'X + lam*I)^-1 X'y
        A    = Xtr' * Xtr + lam * eye(K);
        beta = A \ (Xtr' * ytr_f);
        yhVa = Xva * beta;
        foldMse(f) = mean((yva - yhVa).^2);
    end
    cvMse(iL) = mean(foldMse);
end

[~, iBest] = min(cvMse);
bestLambda = lambdaGrid(iBest);

% --- Refit on full training data with optimal lambda -----------------
A    = Xc' * Xc + bestLambda * eye(K);
beta = A \ (Xc' * yc);
b0   = yMu - xMu * beta;             % intercept

% --- Predict ---------------------------------------------------------
yhTr = metaTr * beta + b0;
yhTe = metaTe * beta + b0;

% --- Pack results ----------------------------------------------------
res.kind        = 'ridge';
res.B           = beta;
res.intercept   = b0;
res.xMu         = xMu;
res.yMu         = yMu;
res.bestLambda  = bestLambda;
res.lambdaGrid  = lambdaGrid;
res.cvMse       = cvMse;
res.yhatTrain   = yhTr;
res.yhatTest    = yhTe;
res.metricsTrain= computeMetrics(ytr, yhTr);
res.metricsTest = computeMetrics(yte, yhTe);

if ~isempty(logFile)
    logMsg(logFile, sprintf( ...
        '  Ridge stacker  : lambda*=%.2e   test  R2=%.3f RMSE=%.3f', ...
        bestLambda, res.metricsTest(1), res.metricsTest(2)));
    wStr = sprintf('%+.3f ', beta);
    logMsg(logFile, sprintf('  Ridge weights  : [%s]', strtrim(wStr)));
end

% --- Diagnostic plot: CV MSE vs lambda --------------------------------
try
    fig = figure('Color','w','Position',[100 100 720 380],'Visible','off');
    ax = gca; hold(ax,'on');
    semilogx(ax, lambdaGrid, cvMse, 'b-o', 'LineWidth',1.4, 'MarkerSize',5);
    plot(ax, bestLambda, cvMse(iBest), 'rs', 'MarkerSize',12, 'LineWidth',2);
    xlabel(ax,'\lambda (ridge regularisation)');
    ylabel(ax,'CV MSE');
    title(ax, sprintf('Ridge meta-learner CV (best \\lambda = %.2e)', bestLambda));
    legend(ax, {'CV MSE','optimum'}, 'Location','best');
    grid(ax,'on'); box(ax,'on');
    savePublicationFigure(fig, 'META_ridge_cv', cfg);
    close(fig);
catch ME
    warning('trainRidgeStacker:plot1', 'CV plot failed: %s', ME.message);
end

% --- Predicted-vs-actual scatter --------------------------------------
try
    fig = figure('Color','w','Position',[100 100 600 500],'Visible','off');
    ax = gca; hold(ax,'on');
    scatter(ax, yte, yhTe, 18, 'filled', 'MarkerFaceAlpha', 0.55);
    lim = [min([yte; yhTe]) max([yte; yhTe])];
    plot(ax, lim, lim, 'k--', 'LineWidth',1.2);
    xlabel(ax,'Actual Vs (z-score)'); ylabel(ax,'Predicted Vs (z-score)');
    title(ax, sprintf('Ridge stacker: R^2=%.3f  RMSE=%.3f', ...
        res.metricsTest(1), res.metricsTest(2)));
    grid(ax,'on'); box(ax,'on');
    savePublicationFigure(fig, 'META_ridge_pred_vs_actual', cfg);
    close(fig);
catch ME
    warning('trainRidgeStacker:plot2', 'Scatter plot failed: %s', ME.message);
end
end
