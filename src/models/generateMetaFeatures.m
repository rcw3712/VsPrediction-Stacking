function Xmeta = generateMetaFeatures(optRes, X, y, splitTag, cfg)
%GENERATEMETAFEATURES  Stack base-learner predictions into meta-features.
%
%   Returns an N x 4 matrix [yPNN yMLF yDFF yCNN] used as input to the
%   I-CNN meta-learner. To avoid leakage, predictions on the training
%   split are produced by out-of-fold predictions when called with
%   splitTag='train'.

models = {'PNN','MLFFNN','DFFNN','CNN1D'};

if strcmpi(splitTag, 'train')
    % --- Out-of-fold predictions to prevent leakage --------------------
    cv = cvpartition(numel(y), 'KFold', cfg.split.kFold);
    Xmeta = zeros(numel(y), numel(models));
    for f = 1:cv.NumTestSets
        idTr = training(cv,f); idVa = test(cv,f);
        for m = 1:numel(models)
            mdl = trainFromOpt(models{m}, optRes.(models{m}).bestParams, ...
                X(idTr,:), y(idTr), cfg);
            yh = predictFromOpt(models{m}, mdl, X(idVa,:), optRes.(models{m}).bestParams);
            Xmeta(idVa, m) = yh;
        end
    end
else
    % --- Use the final retrained model on the held-out test set --------
    Xmeta = zeros(size(X,1), numel(models));
    for m = 1:numel(models)
        Xmeta(:,m) = predictFromOpt(models{m}, optRes.(models{m}).bestModel, X, ...
            optRes.(models{m}).bestParams);
    end
end
end

% =======================================================================
function mdl = trainFromOpt(name, p, X, y, cfg) %#ok<INUSD>
switch upper(name)
    case 'PNN'    , mdl = trainPNN   (X, y, p);
    case 'MLFFNN' , mdl = trainMLFFNN(X, y, p);
    case 'DFFNN'  , mdl = trainDFFNN (X, y, p);
    case 'CNN1D'  , mdl = trainCNN1D (X, y, p);
end
end

function yhat = predictFromOpt(name, mdl, X, p)
switch upper(name)
    case 'PNN'    , yhat = predictPNN(mdl, X);
    case 'MLFFNN' , yhat = predictNN (mdl, X);
    case 'DFFNN'  , yhat = predictNN (mdl, X);
    case 'CNN1D'  , yhat = predictCNN1D(mdl, X, p);
end
end
