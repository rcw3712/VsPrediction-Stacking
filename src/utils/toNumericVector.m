function v = toNumericVector(x)
% TONUMERICVECTOR — coerce table column / cellstr / string to numeric vector.
%   - Already numeric: returns double(x(:))
%   - Cell of strings:  str2double each
%   - String array:     str2double each
%   - Mixed:            best-effort double() cast then str2double fallback
%   Author: RCW (2026-06)

if isempty(x)
    v = double.empty(0, 1);
    return;
end

if isnumeric(x)
    v = double(x(:));
elseif islogical(x)
    v = double(x(:));
elseif iscell(x)
    v = nan(numel(x), 1);
    for i = 1:numel(x)
        if isnumeric(x{i}) && ~isempty(x{i})
            v(i) = double(x{i});
        elseif ischar(x{i}) || isstring(x{i})
            v(i) = str2double(string(x{i}));
        end
    end
elseif isstring(x) || ischar(x)
    v = str2double(string(x(:)));
else
    try
        v = double(x(:));
    catch
        v = nan(numel(x), 1);
    end
end
end
