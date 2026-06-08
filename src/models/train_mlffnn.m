function model = train_mlffnn(X_train, y_train, hyperparams)
% TRAIN_MLFFNN — multi-layer feed-forward NN (shallow)
%   Uses fitnet/feedforwardnet if Neural Network Toolbox is available.
%   Author: RCW (2026-06)

if nargin < 3 || isempty(hyperparams)
    hyperparams.hidden   = [32 16];
    hyperparams.lr       = 0.01;
    hyperparams.epochs   = 100;
end

try
    net = feedforwardnet(hyperparams.hidden, 'trainscg');
    net.trainParam.epochs    = hyperparams.epochs;
    net.trainParam.showWindow = false;
    net.divideFcn  = 'dividetrain';   % use ALL training rows (no internal validation split)
    net = train(net, X_train', y_train');
    model.net = net;
catch ME
    warning('MLFFNN training failed: %s. Falling back to linear regression.', ME.message);
    model.net = [];
    model.beta = [ones(size(X_train,1),1), X_train] \ y_train;
end

model.kind        = 'mlffnn';
model.hyperparams = hyperparams;
end
