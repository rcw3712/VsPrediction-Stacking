function T_out = resample_uniform(T_in, step, cols_to_resample)
% RESAMPLE_UNIFORM — uniform-step depth interpolation
%   T_in: table with at least DEPTH and other numeric columns
%   step: depth step in same units as T_in.DEPTH
%   cols_to_resample: optional, default = all numeric except DEPTH
%   Author: RCW (2026-06)

if nargin < 3 || isempty(cols_to_resample)
    cols_to_resample = setdiff(T_in.Properties.VariableNames, {'DEPTH'}, 'stable');
end

if step <= 0
    T_out = T_in;
    return;
end

d_min = ceil(min(T_in.DEPTH) / step) * step;
d_max = floor(max(T_in.DEPTH) / step) * step;
new_d = (d_min:step:d_max)';

T_out = table(new_d, 'VariableNames', {'DEPTH'});

for k = 1:numel(cols_to_resample)
    c = cols_to_resample{k};
    if ismember(c, T_in.Properties.VariableNames) && isnumeric(T_in.(c))
        T_out.(c) = interp1(T_in.DEPTH, T_in.(c), new_d, 'linear', 'extrap');
    end
end
end
