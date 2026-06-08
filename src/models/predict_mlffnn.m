function y_hat = predict_mlffnn(model, X)
% PREDICT_MLFFNN
%   Author: RCW (2026-06)

if ~isempty(model.net)
    y_hat = (model.net(X'))';
else
    y_hat = [ones(size(X,1),1), X] * model.beta;
end
end
