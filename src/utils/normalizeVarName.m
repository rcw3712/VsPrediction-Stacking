function s = normalizeVarName(name)
% NORMALIZEVARNAME — collapse a column name to lowercase alphanumeric for
% case-insensitive, punctuation-insensitive matching.
%   Examples:
%     'RMSE (km/s)'   → 'rmsekms'
%     'R²'            → 'r2'        (sup-2 lost; that's fine — match against 'r2')
%     'R_2'           → 'r2'
%     'Depth_m'       → 'depthm'
%   Author: RCW (2026-06)

if isstring(name), name = char(name); end
s = lower(regexprep(name, '[^a-zA-Z0-9]', ''));
% Normalize Unicode squared (²,³,etc) by stripping them; '2'/'3' digits preserved
s = regexprep(s, '[\x{00B2}]', '2');
s = regexprep(s, '[\x{00B3}]', '3');
end
