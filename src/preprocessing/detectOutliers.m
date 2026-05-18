function [mask, info] = detectOutliers(x, method, iqrFactor, zThr)
%DETECTOUTLIERS  Boolean mask of outlier samples in a 1-D log.
%
%   method : 'IQR' | 'zscore' | 'both'
%   mask   : true where the value is considered an outlier
%   info   : struct with bounds and counts
%
%   NaNs are passed through (mask=false). Constant signals -> mask=false.

if nargin < 2, method = 'IQR'; end
if nargin < 3, iqrFactor = 3; end
if nargin < 4, zThr = 3; end

x = x(:);
mask = false(size(x));
info = struct('method', method, 'low', NaN, 'high', NaN, 'count', 0);
ok = ~isnan(x);
if ~any(ok) || range(x(ok))==0
    return;
end

switch lower(method)
    case 'iqr'
        q = quantile(x(ok), [0.25 0.75]);
        iqrV = q(2)-q(1);
        lo = q(1) - iqrFactor*iqrV;
        hi = q(2) + iqrFactor*iqrV;
        mask = ok & (x < lo | x > hi);
        info.low = lo; info.high = hi;
    case 'zscore'
        mu = mean(x(ok)); sd = std(x(ok));
        z  = (x - mu) / max(sd, eps);
        mask = ok & abs(z) > zThr;
        info.low = mu - zThr*sd; info.high = mu + zThr*sd;
    case 'both'
        [m1,~] = detectOutliers(x, 'IQR'   , iqrFactor, zThr);
        [m2,~] = detectOutliers(x, 'zscore', iqrFactor, zThr);
        mask = m1 | m2;
    otherwise
        error('detectOutliers:Method','Unknown method: %s', method);
end
info.count = nnz(mask);
end
