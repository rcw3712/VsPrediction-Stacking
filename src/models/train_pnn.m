function model = train_pnn(X_train, y_train, hyperparams)
% TRAIN_PNN — Probabilistic Neural Network for regression (GRNN variant)
%   Lightweight implementation using radial basis interpolation.
%   For deployment, predict_pnn uses Gaussian kernel weighted averaging.
%   Author: RCW (2026-06)

if nargin < 3 || isempty(hyperparams), hyperparams.spread = 0.5; end

model.kind         = 'pnn';
model.X_train      = X_train;
model.y_train      = y_train;
model.spread       = hyperparams.spread;
model.hyperparams  = hyperparams;
end
