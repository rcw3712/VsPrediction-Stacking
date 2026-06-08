function y_hat_z = predict_ridge_stacker(model, Z)
% PREDICT_RIDGE_STACKER
%   Author: RCW (2026-06)
y_hat_z = Z * model.beta;
end
