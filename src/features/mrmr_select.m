function [selected, scores] = mrmr_select(X, y, top_k, feature_names)
% MRMR_SELECT — minimum-Redundancy-Maximum-Relevance feature selection
%   Uses MATLAB built-in fsrmrmr if available (Stats & ML Toolbox).
%   X: n x p numeric features (no NaN)
%   y: n x 1 numeric target
%   top_k: number of top features to return
%   Author: RCW (2026-06)

if any(isnan(X(:))) || any(isnan(y))
    error('mrmr_select: input contains NaN');
end

p = size(X, 2);
top_k = min(top_k, p);

try
    [idx, scores_all] = fsrmrmr(X, y);
    selected = idx(1:top_k);
    scores   = scores_all(idx(1:top_k));
catch
    % Fallback: rank by absolute correlation with y
    warning('fsrmrmr unavailable; using correlation-rank fallback');
    rho = zeros(p, 1);
    for k = 1:p
        rho(k) = abs(corr(X(:,k), y, 'rows', 'complete'));
    end
    [scores, idx] = sort(rho, 'descend');
    selected = idx(1:top_k);
    scores   = scores(1:top_k);
end

if nargin >= 4 && ~isempty(feature_names)
    selected_names = feature_names(selected);
    fprintf('  [mRMR] top-%d: %s\n', top_k, strjoin(selected_names, ', '));
end
end
