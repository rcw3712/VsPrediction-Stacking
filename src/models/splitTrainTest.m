function [Xtrain, Ytrain, Xtest, Ytest, info] = splitTrainTest(BT4, finalFeatures, cfg)
%SPLITTRAINTEST  Build [X y] for the calibrated well and split it.
%
%   The split optionally stratifies along depth so that train and test
%   span the same lithological intervals.

[X, y] = stackCurves(BT4, finalFeatures, cfg.targetCurve);
N = size(X, 1);
rng(cfg.randomSeed);

switch lower(cfg.split.stratifyBy)
    case 'depth'
        nBin = 10;
        d = (1:N)';
        edges = linspace(min(d), max(d)+1, nBin+1);
        bin = discretize(d, edges);
        testMask = false(N,1);
        for b = 1:nBin
            idx = find(bin == b);
            n   = numel(idx);
            nt  = round(cfg.split.testFraction * n);
            sel = randperm(n, nt);
            testMask(idx(sel)) = true;
        end
    otherwise   % random
        sel = randperm(N, round(cfg.split.testFraction * N));
        testMask = false(N,1); testMask(sel) = true;
end

Xtrain = X(~testMask, :); Ytrain = y(~testMask);
Xtest  = X( testMask, :); Ytest  = y( testMask);

info.testMask = testMask;
info.nTrain   = size(Xtrain,1);
info.nTest    = size(Xtest ,1);
info.features = finalFeatures;
end

% =======================================================================
function [X, y] = stackCurves(well, featNames, targetName)
N = numel(well.depth);
P = numel(featNames);
X = zeros(N, P);
for k = 1:P
    X(:,k) = well.curvesNorm.(featNames{k});
end
y = well.curvesNorm.(targetName);
ok = all(isfinite(X),2) & isfinite(y);
X = X(ok,:); y = y(ok);
end
