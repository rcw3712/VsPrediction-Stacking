function Xn = apply_normalization(X, ns)
% APPLY_NORMALIZATION — apply pre-fit normalization stats.
%   Author: RCW (2026-06)

switch lower(ns.method)
    case 'zscore'
        Xn = (X - ns.mu) ./ ns.sigma;
    case 'minmax'
        Xn = (X - ns.min) ./ ns.range;
    otherwise
        error('Unknown normalization method: %s', ns.method);
end
end
