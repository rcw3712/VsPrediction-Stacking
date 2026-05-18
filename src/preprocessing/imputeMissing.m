function y = imputeMissing(x, depth, method, kNeighbors)
%IMPUTEMISSING  Fill NaN values in a 1-D log.
%
%   method : 'linear' | 'spline' | 'pchip' | 'nearest' | 'KNN'
%   For 'KNN' the nearest depth samples are used as neighbours
%   (inverse-distance weighting on the depth axis).

if nargin < 3, method = 'linear'; end
if nargin < 4, kNeighbors = 5; end

x = x(:); depth = depth(:);
y = x;
nanIdx = isnan(y);
if ~any(nanIdx) || all(nanIdx); return; end

switch lower(method)
    case {'linear','spline','pchip','nearest'}
        y(nanIdx) = interp1(depth(~nanIdx), x(~nanIdx), depth(nanIdx), ...
            method, 'extrap');

    case 'knn'
        goodD = depth(~nanIdx); goodX = x(~nanIdx);
        if isempty(goodD); return; end
        idxNan = find(nanIdx);
        for j = 1:numel(idxNan)
            di       = abs(goodD - depth(idxNan(j)));
            [ds, od] = sort(di, 'ascend');
            kk       = min(kNeighbors, numel(od));
            od = od(1:kk); ds = ds(1:kk);
            w  = 1 ./ (ds + eps);
            y(idxNan(j)) = sum(w .* goodX(od)) / sum(w);
        end
    otherwise
        error('imputeMissing:Method','Unknown method: %s', method);
end

% Fallback for any remaining NaN at edges
if any(isnan(y))
    y = fillmissing(y, 'nearest');
end
end
