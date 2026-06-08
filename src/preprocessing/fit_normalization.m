function ns = fit_normalization(X, method)
% FIT_NORMALIZATION — compute normalization stats from training data only.
%   X      : n x p numeric matrix
%   method : 'zscore' | 'minmax'
%   ns     : struct with fields method, mu, sigma (zscore) OR min, max (minmax)
%   Author: RCW (2026-06)

if nargin < 2, method = 'zscore'; end
ns.method = method;
switch lower(method)
    case 'zscore'
        ns.mu    = mean(X, 1, 'omitnan');
        ns.sigma = std(X, 0, 1, 'omitnan');
        ns.sigma(ns.sigma == 0) = 1;   % guard against constant columns
    case 'minmax'
        ns.min   = min(X, [], 1, 'omitnan');
        ns.max   = max(X, [], 1, 'omitnan');
        rng = ns.max - ns.min;
        rng(rng == 0) = 1;
        ns.range = rng;
    otherwise
        error('Unknown normalization method: %s', method);
end
end
