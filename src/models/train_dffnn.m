function model = train_dffnn(X_train, y_train, hyperparams)
% TRAIN_DFFNN — deep feed-forward NN (deeper than MLFFNN)
%   Same backend as MLFFNN but with more layers.
%   Author: RCW (2026-06)

if nargin < 3 || isempty(hyperparams)
    hyperparams.hidden   = [64 32 16];
    hyperparams.lr       = 0.001;
    hyperparams.epochs   = 100;
end

try
    net = feedforwardnet(hyperparams.hidden, 'trainscg');
    net.trainParam.epochs     = hyperparams.epochs;
    net.trainParam.showWindow = false;
    net.divideFcn  = 'dividetrain';
    % Use tansig hidden + linear output (default)
    net = train(net, X_train', y_train');
    model.net = net;
catch ME
    warning('DFFNN training failed: %s. Falling back to ridge regression.', ME.message);
    model.net  = [];
    model.beta = [ones(size(X_train,1),1), X_train] \ y_train;
end

model.kind        = 'dffnn';
model.hyperparams = hyperparams;
end
