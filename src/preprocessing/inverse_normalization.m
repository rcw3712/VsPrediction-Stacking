function X = inverse_normalization(Xn, ns)
% INVERSE_NORMALIZATION — undo normalization for a 1-D target.
%   Author: RCW (2026-06)

switch lower(ns.method)
    case 'zscore'
        X = Xn .* ns.sigma + ns.mu;
    case 'minmax'
        X = Xn .* ns.range + ns.min;
    otherwise
        error('Unknown normalization method: %s', ns.method);
end
end
