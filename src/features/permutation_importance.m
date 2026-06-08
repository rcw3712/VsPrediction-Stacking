function imp = permutation_importance(X, y, predict_fn, feature_names, n_repeats, seed)
% PERMUTATION_IMPORTANCE — model-agnostic feature importance.
%   For each feature, randomly permute its column and measure the
%   degradation in prediction R². Higher degradation = more important.
%   Drop-in alternative to SHAP when toolbox unavailable.
%   Author: RCW (2026-06)

if nargin < 5, n_repeats = 5; end
if nargin < 6, seed = 42; end

p = size(X, 2);
imp = zeros(p, 1);

% Baseline R²
y_hat = predict_fn(X);
ss_res = sum((y - y_hat).^2);
ss_tot = sum((y - mean(y)).^2) + 1e-12;
r2_base = 1 - ss_res / ss_tot;

rng(seed, 'twister');
for k = 1:p
    deltas = zeros(n_repeats, 1);
    for r = 1:n_repeats
        X_perm = X;
        X_perm(:, k) = X(randperm(size(X,1)), k);
        y_perm = predict_fn(X_perm);
        ss_p = sum((y - y_perm).^2);
        r2_perm = 1 - ss_p / ss_tot;
        deltas(r) = r2_base - r2_perm;   % positive = feature is important
    end
    imp(k) = mean(deltas);
end

if nargin >= 4 && ~isempty(feature_names)
    [~, ord] = sort(imp, 'descend');
    fprintf('  [PERM-IMP] ranking (Δ R² baseline=%.3f):\n', r2_base);
    for i = 1:numel(ord)
        fprintf('    %-8s : %+.4f\n', feature_names{ord(i)}, imp(ord(i)));
    end
end
end
