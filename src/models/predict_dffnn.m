function y_hat = predict_dffnn(model, X)
% PREDICT_DFFNN
%   Author: RCW (2026-06)
if ~isempty(model.net)
    y_hat = (model.net(X'))';
else
    y_hat = [ones(size(X,1),1), X] * model.beta;
end
end
