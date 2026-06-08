function [selected, beta] = lasso_select(X, y, alpha_val, feature_names)
% LASSO_SELECT — features with non-zero LASSO coefficient at CV-optimal λ.
%   Uses lasso() with K-fold CV. Returns the support set at lambda_1se.
%   Author: RCW (2026-06)

if any(isnan(X(:))) || any(isnan(y))
    error('lasso_select: input contains NaN');
end

if nargin < 3 || isempty(alpha_val), alpha_val = 1; end

try
    [B, info] = lasso(X, y, 'CV', 5, 'Alpha', alpha_val);
    idx_lambda = info.Index1SE;
    if isempty(idx_lambda) || idx_lambda < 1, idx_lambda = info.IndexMinMSE; end
    beta = B(:, idx_lambda);
    selected = find(abs(beta) > 1e-8);
    if isempty(selected)
        % Fallback to MinMSE if 1SE wipes everything
        idx_lambda = info.IndexMinMSE;
        beta = B(:, idx_lambda);
        selected = find(abs(beta) > 1e-8);
    end
catch ME
    warning('LASSO failed (%s); using correlation > 0.1 fallback', ME.message);
    p = size(X, 2);
    rho = zeros(p, 1);
    for k = 1:p
        rho(k) = abs(corr(X(:,k), y, 'rows', 'complete'));
    end
    selected = find(rho > 0.1);
    beta = rho;
end

if nargin >= 4 && ~isempty(feature_names)
    if isempty(selected)
        fprintf('  [LASSO] selected: NONE\n');
    else
        fprintf('  [LASSO] selected: %s\n', ...
                strjoin(feature_names(selected), ', '));
    end
end
end
