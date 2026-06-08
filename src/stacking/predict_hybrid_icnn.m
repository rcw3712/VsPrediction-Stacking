function y_hat_z = predict_hybrid_icnn(model, X_z, Z)
% PREDICT_HYBRID_ICNN — returns DOUBLE precision.
%   Author: RCW (2026-06)

if strcmp(model.kind, 'hybrid_fallback_ridge')
    y_hat_z = predict_ridge_stacker(model, Z);
    y_hat_z = double(y_hat_z);
    return;
end
n = size(X_z, 1);
n_ch = model.n_ch;
Xseq = cell(n, 1);
for i = 1:n
    v = [X_z(i,:), Z(i,:)];
    Xseq{i} = reshape(v, 1, n_ch);
end
y_hat_z = predict(model.net, Xseq);
y_hat_z = double(y_hat_z);
end
