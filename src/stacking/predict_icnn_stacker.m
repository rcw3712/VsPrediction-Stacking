function y_hat_z = predict_icnn_stacker(model, Z)
% PREDICT_ICNN_STACKER — returns DOUBLE precision.
%   Author: RCW (2026-06)

if strcmp(model.kind, 'icnn_fallback_ridge')
    y_hat_z = predict_ridge_stacker(model, Z);
    y_hat_z = double(y_hat_z);
    return;
end
n = size(Z, 1);
M = model.M;
Xseq = cell(n, 1);
for i = 1:n
    Xseq{i} = reshape(Z(i,:), 1, M);
end
y_hat_z = predict(model.net, Xseq);
y_hat_z = double(y_hat_z);
end
