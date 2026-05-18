function [depthOut, curvesOut] = resampleDepth(depthIn, curvesIn, dz)
%RESAMPLEDEPTH  Resample all curves to a uniform depth grid.
%
%   dz : target depth step (m)
%
%   Linear interpolation is used. Edge values are extrapolated using
%   nearest neighbour to avoid artefacts.

depthIn = depthIn(:);
[depthIn, ix] = sort(depthIn, 'ascend');
fn = fieldnames(curvesIn);
for k = 1:numel(fn)
    curvesIn.(fn{k}) = curvesIn.(fn{k})(ix);
end

dMin = depthIn(1);
dMax = depthIn(end);
depthOut = (dMin : dz : dMax).';

curvesOut = struct();
for k = 1:numel(fn)
    x = curvesIn.(fn{k});
    % only interpolate where we have data
    valid = ~isnan(x);
    if nnz(valid) >= 2
        curvesOut.(fn{k}) = interp1(depthIn(valid), x(valid), depthOut, ...
            'linear', NaN);
        % Edge fill with nearest
        nz = isnan(curvesOut.(fn{k}));
        if any(nz)
            curvesOut.(fn{k})(nz) = interp1(depthIn(valid), x(valid), ...
                depthOut(nz), 'nearest', 'extrap');
        end
    else
        curvesOut.(fn{k}) = nan(size(depthOut));
    end
end
end
