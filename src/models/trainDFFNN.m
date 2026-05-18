function mdl = trainDFFNN(X, y, params)
%TRAINDFFNN  Deep Feed-Forward Neural Network with dropout + batchnorm.
%
%   params.hiddenSizes : vector, deeper than MLFFNN (e.g. [64 64 32 16])
%   params.dropout     : per-hidden dropout probability
%   params.l2, params.lr, params.maxEpochs

if nargin < 3, params = struct(); end
defaults = struct('hiddenSizes',[64 64 32 16],'maxEpochs',300,'lr',5e-4, ...
                  'l2',1e-4,'dropout',0.20,'activation','relu');
params = mergeStruct(defaults, params);

P = size(X,2);

layers = [featureInputLayer(P, 'Normalization', 'none', 'Name','input')];
for k = 1:numel(params.hiddenSizes)
    layers = [layers
        fullyConnectedLayer(params.hiddenSizes(k), 'Name', sprintf('fc%d',k))
        batchNormalizationLayer('Name', sprintf('bn%d',k))
        activationLayerByName(params.activation, sprintf('act%d',k))
        dropoutLayer(params.dropout, 'Name', sprintf('do%d',k))]; %#ok<AGROW>
end
layers = [layers
    fullyConnectedLayer(1, 'Name','out')];

patience = 25; if isfield(params,'patience'), patience = params.patience; end

opts = trainingOptions('adam', ...
    'MaxEpochs',         params.maxEpochs, ...
    'InitialLearnRate',  params.lr, ...
    'L2Regularization',  params.l2, ...
    'MiniBatchSize',     min(64, size(X,1)), ...
    'Shuffle',           'every-epoch', ...
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropFactor',0.5, ...
    'LearnRateDropPeriod',50, ...
    'Verbose',            false, ...
    'OutputNetwork',      'best-validation-loss', ...
    'ValidationFrequency',10, ...
    'ValidationPatience', patience);

N = size(X,1); rng('default');
nv = max(1, round(0.15*N));
idx = randperm(N); val = idx(1:nv); tra = idx(nv+1:end);
opts.ValidationData = {X(val,:), y(val)};

[net, info] = trainnet(X(tra,:), y(tra), layers, 'mse', opts);
mdl.net   = net;
mdl.kind  = 'dlnetwork';
mdl.params= params;
mdl.trainInfo = info;
end

function s = mergeStruct(a, b)
s = a;
fn = fieldnames(b);
for k = 1:numel(fn); s.(fn{k}) = b.(fn{k}); end
end

function L = activationLayerByName(name, lname)
% Map textual activation name to MATLAB layer.
switch lower(string(name))
    case "relu"   , L = reluLayer('Name', lname);
    case "tanh"   , L = tanhLayer('Name', lname);
    case "sigmoid", L = sigmoidLayer('Name', lname);
    case "elu"    , L = eluLayer('Name', lname);
    case "leakyrelu", L = leakyReluLayer(0.1, 'Name', lname);
    otherwise     , L = reluLayer('Name', lname);
end
end
