function mdl = trainMLFFNN(X, y, params)
%TRAINMLFFNN  Multi-Layer Feed-Forward Neural Network (shallow).
%
%   params.hiddenSizes : vector e.g. [32 16]
%   params.maxEpochs, params.lr, params.l2

if nargin < 3, params = struct(); end
defaults = struct('hiddenSizes',[32 16],'maxEpochs',200, ...
                  'lr',1e-3,'l2',1e-4,'activation','relu');
params = mergeStruct(defaults, params);

P = size(X,2);

layers = [
    featureInputLayer(P, 'Normalization', 'none', 'Name','input')];
for k = 1:numel(params.hiddenSizes)
    layers = [layers
        fullyConnectedLayer(params.hiddenSizes(k), 'Name', sprintf('fc%d',k))
        activationLayerByName(params.activation, sprintf('act%d', k))]; %#ok<AGROW>
end
layers = [layers
    fullyConnectedLayer(1, 'Name','out')];

% Honor patience/verbose if provided by caller (used in Bayesopt inner CV)
patience = 25; if isfield(params,'patience'), patience = params.patience; end

opts = trainingOptions('adam', ...
    'MaxEpochs',          params.maxEpochs, ...
    'InitialLearnRate',   params.lr, ...
    'L2Regularization',   params.l2, ...
    'MiniBatchSize',      min(64, size(X,1)), ...
    'Shuffle',            'every-epoch', ...
    'Verbose',            false, ...
    'ValidationFrequency',10, ...
    'ValidationPatience', patience, ...
    'OutputNetwork',      'best-validation-loss', ...
    'ExecutionEnvironment','auto');

% Internal validation split
N = size(X,1); rng('default');
nv = max(1, round(0.15*N));
idx = randperm(N); val = idx(1:nv); tra = idx(nv+1:end);
opts.ValidationData = {X(val,:), y(val)};

[net, info] = trainnet(X(tra,:), y(tra), layers, 'mse', opts);
mdl.net   = net;
mdl.kind  = 'dlnetwork';
mdl.params = params;
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
