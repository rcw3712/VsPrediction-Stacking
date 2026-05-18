function mdl = trainPNN(X, y, params)
%TRAINPNN  Generalized Regression Neural Network (GRNN) used as a
%   probabilistic neural network for regression.
%
%   The classical PNN is a classifier; for continuous targets the natural
%   counterpart is the GRNN (Specht 1991), which is implemented in MATLAB
%   as NEWGRNN. We expose the same "spread" parameter expected of a PNN.
%
%   params.spread : kernel smoothing factor (>0). Smaller -> more local.

if nargin < 3 || ~isfield(params, 'spread'); params.spread = 0.1; end

% newgrnn expects features as rows
mdl.spread = params.spread;
try
    mdl.net = newgrnn(X.', y.', params.spread);
    mdl.kind = 'newgrnn';
catch
    % Fallback: store training data and emulate GRNN by hand
    mdl.X = X; mdl.y = y; mdl.kind = 'manual';
end
end
