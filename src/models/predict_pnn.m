function y_hat = predict_pnn(model, X)
% PREDICT_PNN — GRNN-style prediction using Gaussian kernel
%   Author: RCW (2026-06)

[n_q, ~] = size(X);
y_hat    = zeros(n_q, 1);
sigma2   = 2 * model.spread^2;

% Chunked to avoid huge matrices
chunk = 200;
n_t   = size(model.X_train, 1);

for i = 1:chunk:n_q
    j = min(i + chunk - 1, n_q);
    Xq = X(i:j, :);
    % Squared distances: ||xq - xt||^2
    d2 = pdist2(Xq, model.X_train).^2;
    w  = exp(-d2 / sigma2);
    w_sum = sum(w, 2) + 1e-12;
    y_hat(i:j) = (w * model.y_train) ./ w_sum;
end
end
