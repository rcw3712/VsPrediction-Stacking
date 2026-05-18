function res = ablationStudy(BT4, fsRes, cfg, logFile)
%ABLATIONSTUDY  Run 4 scenarios and compare metrics + stability.
%
%   S1 : full pipeline   (mRMR ∪ LASSO + I-CNN)
%   S2 : no FS           (all features)
%   S3 : mRMR only
%   S4 : LASSO only

scenarios = {
    'S1_full',  fsRes.finalFeatures
    'S2_noFS',  cfg.featureCurves
    'S3_mRMR',  fsRes.featureNames(fsRes.mrmr.selected)
    'S4_LASSO', fsRes.featureNames(fsRes.lasso.selected)};

R = repmat(struct('R2',NaN,'RMSE',NaN,'MAE',NaN,'MAPE',NaN, ...
    'std_R2',NaN,'features',{{}}), 4, 1);

for s = 1:size(scenarios, 1)
    tag = scenarios{s,1};
    feats = scenarios{s,2};
    if isempty(feats); feats = cfg.featureCurves; end
    logMsg(logFile, sprintf('  Ablation %s with %d features', tag, numel(feats)));

    [Xtr, ytr, Xte, yte] = splitTrainTest(BT4, feats, cfg);

    % Use a small CV to assess stability
    k = max(2, min(3, cfg.split.kFold));
    cv = cvpartition(numel(ytr),'KFold',k);
    metr = zeros(k,4);
    for f = 1:cv.NumTestSets
        idTr = training(cv,f); idVa = test(cv,f);
        % Fast shallow stack: DFFNN + I-CNN with default params
        mdlFFN = trainDFFNN(Xtr(idTr,:), ytr(idTr), cfg.base.DFFNN);
        yhVal = predictNN(mdlFFN, Xtr(idVa,:));
        metr(f,:) = computeMetrics(ytr(idVa), yhVal);
    end
    % Final model on train -> test
    mdlF = trainDFFNN(Xtr, ytr, cfg.base.DFFNN);
    yhTe = predictNN(mdlF, Xte);
    finalM = computeMetrics(yte, yhTe);

    R(s).tag      = tag;
    R(s).features = feats;
    R(s).R2       = finalM(1);
    R(s).RMSE     = finalM(2);
    R(s).MAE      = finalM(3);
    R(s).MAPE     = finalM(4);
    R(s).std_R2   = std(metr(:,1));
    R(s).std_RMSE = std(metr(:,2));
end

% --- Table -------------------------------------------------------------
T = table({R.tag}', cellfun(@(c) strjoin(c,','), {R.features}', 'UniformOutput',false), ...
          [R.R2]', [R.RMSE]', [R.MAE]', [R.MAPE]', [R.std_R2]', ...
    'VariableNames', {'Scenario','Features','R2','RMSE','MAE','MAPE','R2_std'});
[~, ord] = sort(T.R2, 'descend'); T.Rank = (1:height(T))';
T = T(ord, :);
exportTable(T, 'ablation_summary', cfg);

% --- Radar plot -------------------------------------------------------
plotRadarChart(R, cfg);

res.scenarios = R;
res.table     = T;
end
