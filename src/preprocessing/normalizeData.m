function [curvesNorm, statsOut] = normalizeData(curves, method, statsRef)
%NORMALIZEDATA  Per-curve normalisation with reusable parameters.
%
%   [Cn, S] = normalizeData(C, method)         % fit + transform
%   [Cn, S] = normalizeData(C, method, S0)     % transform with given stats
%
%   method  : 'zscore' or 'minmax'
%   curves  : struct of Nx1 vectors keyed by curve mnemonic
%   statsRef: optional struct with fields .(curve).mu/.sd or .min/.max
%
%   This guarantees BT-1 is normalised with BT-4 statistics, preventing
%   train/test leakage and keeping feature magnitudes comparable.

if nargin < 3, statsRef = []; end
fn = fieldnames(curves);
curvesNorm = struct();
statsOut   = struct();

for k = 1:numel(fn)
    nm = fn{k};
    x  = curves.(nm)(:);
    switch lower(method)
        case 'zscore'
            if ~isempty(statsRef) && isfield(statsRef, nm)
                mu = statsRef.(nm).mu; sd = statsRef.(nm).sd;
            else
                mu = mean(x, 'omitnan');
                sd = std(x, 0, 'omitnan');
                if sd == 0 || isnan(sd); sd = 1; end
            end
            xn = (x - mu) / sd;
            statsOut.(nm).mu = mu;
            statsOut.(nm).sd = sd;
        case 'minmax'
            if ~isempty(statsRef) && isfield(statsRef, nm)
                mn = statsRef.(nm).min; mx = statsRef.(nm).max;
            else
                mn = min(x, [], 'omitnan');
                mx = max(x, [], 'omitnan');
                if mx == mn; mx = mn + 1; end
            end
            xn = (x - mn) ./ (mx - mn);
            statsOut.(nm).min = mn;
            statsOut.(nm).max = mx;
        otherwise
            error('normalizeData:Method','Unknown method: %s', method);
    end
    curvesNorm.(nm) = xn;
end
end
