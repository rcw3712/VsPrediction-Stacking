function res = featureSelectionPipeline(BT4, cfg, logFile)
%FEATURESELECTIONPIPELINE  Run mRMR + LASSO + SHAP on the calibrated well.
%
%   Returns a struct RES with:
%     .X, .y                  : design matrix and target (normalised)
%     .featureNames           : cellstr of feature mnemonics
%     .mrmr.scores, .mrmr.idx : mRMR ranking
%     .lasso.B, .lasso.fitInfo: full LASSO path + best lambda
%     .lasso.selected         : feature mask for the 1-SE rule
%     .shap.values, .shap.summary
%     .finalFeatures          : intersection / union per cfg.fs.combineRule
%
%   Only BT-4 is used; the resulting feature set is applied to BT-1 too.

featNames = cfg.featureCurves;
[X, y, names] = buildDesignMatrix(BT4, featNames, cfg.targetCurve);
logMsg(logFile, sprintf('  Design matrix: %d x %d, target = %s', ...
    size(X,1), size(X,2), cfg.targetCurve));

%% --- mRMR ---------------------------------------------------------------
% fscmrmr is designed for classification (categorical Y). When called with
% a continuous regression target it treats each unique value as its own
% class, returning meaningless near-zero scores. We bin y into deciles to
% convert the problem to discrete-label MI estimation (a standard
% workaround in regression feature selection literature).
if exist('fscmrmr', 'file') == 2
    nBins = min(10, max(3, floor(numel(y)/50)));     % at least 3, at most 10
    yBinned = discretize(y, quantile(y, linspace(0, 1, nBins + 1)));
    yBinned(isnan(yBinned)) = 1;                     % handle edge values
    [idxR, scoresR] = fscmrmr(X, yBinned);
    if all(scoresR < 1e-9)
        % Defensive: fallback to correlation if mRMR still degenerate
        logMsg(logFile, '  WARN: fscmrmr returned near-zero scores; falling back to correlation-based mRMR');
        [scoresR, idxR] = corrBasedRanking(X, y);
    end
else
    % Fallback when toolbox missing
    [scoresR, idxR] = corrBasedRanking(X, y);
end
res.mrmr.idx     = idxR;
res.mrmr.scores  = scoresR;
res.mrmr.names   = names(idxR);
topK = min(cfg.fs.mrmrTopK, numel(idxR));
res.mrmr.selected = false(1,numel(idxR));
res.mrmr.selected(idxR(1:topK)) = true;
logMsg(logFile, sprintf('  mRMR top-%d : %s', topK, ...
    strjoin(names(idxR(1:topK)), ', ')));

%% --- LASSO -------------------------------------------------------------
[B, fitInfo] = lasso(X, y, 'CV', cfg.fs.lassoCV, ...
    'Alpha', cfg.fs.lassoAlpha, 'Standardize', true);
% 1-SE rule -> sparser model
idx1SE = fitInfo.Index1SE;
selL   = abs(B(:, idx1SE)) > 0;
res.lasso.B        = B;
res.lasso.fitInfo  = fitInfo;
res.lasso.selected = selL;
res.lasso.selectedNames = names(selL);
logMsg(logFile, sprintf('  LASSO selected : %s', ...
    strjoin(names(selL), ', ')));

%% --- Combine -----------------------------------------------------------
switch lower(cfg.fs.combineRule)
    case 'union'
        finalMask = res.mrmr.selected(:) | selL(:);
        ruleLabel = 'UNION (mRMR + LASSO)';
    case 'intersect'
        finalMask = res.mrmr.selected(:) & selL(:);
        ruleLabel = 'INTERSECTION (mRMR \cap LASSO)';
    case {'mrmr_only','mrmr','mrmronly'}
        finalMask = res.mrmr.selected(:);
        ruleLabel = 'mRMR-only (recommended for small tabular data)';
    case {'lasso_only','lasso','lassoonly'}
        finalMask = selL(:);
        ruleLabel = 'LASSO-only';
    otherwise
        finalMask = res.mrmr.selected(:);
        ruleLabel = 'mRMR-only (default fallback)';
end
logMsg(logFile, sprintf('  Combine rule  : %s', ruleLabel));

if ~any(finalMask)
    logMsg(logFile, '  WARN: combine rule produced empty mask -> falling back to mRMR-only');
    finalMask = res.mrmr.selected(:);
end
res.finalMask     = finalMask;
res.finalFeatures = names(finalMask);
res.combineRule   = cfg.fs.combineRule;
logMsg(logFile, sprintf('  Final features: %s', strjoin(res.finalFeatures, ', ')));

%% --- SHAP (model-agnostic, permutation-based on a fast surrogate) -----
shapMdl = fitrensemble(X(:,finalMask), y, 'Method','LSBoost','NumLearningCycles',150);
res.shap = computeShapValues(shapMdl, X(:,finalMask), names(finalMask), cfg);
logMsg(logFile, '  SHAP analysis complete');

%% --- Visualisations ----------------------------------------------------
plotFeatureSelection(res, X, y, names, cfg);

%% --- Persist ----------------------------------------------------------
res.X = X; res.y = y; res.featureNames = names;
T = table(names(:), res.mrmr.selected(:), selL(:), finalMask, ...
    'VariableNames', {'Feature','mRMR','LASSO','Final'});
exportTable(T, 'feature_selection_summary', cfg);
end

% =======================================================================
function [X, y, names] = buildDesignMatrix(well, featNames, targetName)
%BUILDDESIGNMATRIX  Stack normalised curves into [X, y].
fn = fieldnames(well.curvesNorm);
keep = intersect(featNames, fn, 'stable');
X = zeros(numel(well.depth), numel(keep));
for k = 1:numel(keep)
    X(:,k) = well.curvesNorm.(keep{k});
end
y = well.curvesNorm.(targetName);
names = keep;

% Drop rows with any NaN
ok = all(isfinite(X),2) & isfinite(y);
X = X(ok,:); y = y(ok);
end

function [scores, idx] = corrBasedRanking(X, y)
%CORRBASEDRANKING  mRMR-style ranking when fscmrmr is unavailable or
% degenerate. Uses absolute Pearson correlation with target (relevance)
% penalized by mean absolute correlation with already-selected features
% (redundancy). Greedy selection produces order; scores are normalized.
P = size(X, 2);
rho = abs(corr(X, y, 'rows','pairwise'));
rho(~isfinite(rho)) = 0;
R = abs(corr(X, 'rows','pairwise'));
R(~isfinite(R)) = 0;
R(1:P+1:end) = 0;                                    % zero diagonal

scores = zeros(P, 1);
idx    = zeros(P, 1);
selected = false(P, 1);
for k = 1:P
    if k == 1
        rel = rho;  red = zeros(P,1);
    else
        rel = rho;
        red = mean(R(:, selected), 2);
    end
    score = rel - red;
    score(selected) = -Inf;
    [bestVal, bestIdx] = max(score);
    idx(k) = bestIdx;
    scores(k) = bestVal;
    selected(bestIdx) = true;
end
end
