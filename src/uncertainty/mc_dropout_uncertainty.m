function uq = mc_dropout_uncertainty(predict_fn, X, T, pi_level)
% MC_DROPOUT_UNCERTAINTY — Monte Carlo dropout ensemble UQ.
%   predict_fn: function handle f(X) -> y_hat
%   T:          number of forward passes
%   For models without dropout at inference, this acts as ensemble of T
%   identical predictions; the resulting interval will be near-zero (a
%   true MC-Dropout requires the model to enable dropout at inference).
%
%   Returns:
%     uq.mean, uq.std, uq.lower, uq.upper
%   Author: RCW (2026-06)

if nargin < 4, pi_level = 0.95; end
alpha = (1 - pi_level) / 2;

n = size(X, 1);
all_preds = zeros(n, T);
for t = 1:T
    all_preds(:, t) = predict_fn(X);
end

uq.mean  = mean(all_preds, 2);
uq.std   = std(all_preds, 0, 2);
uq.lower = quantile(all_preds, alpha,     2);
uq.upper = quantile(all_preds, 1 - alpha, 2);
end
