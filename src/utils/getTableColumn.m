function col = getTableColumn(T, candidates, default_val)
% GETTABLECOLUMN — robust column lookup by canonical-name matching.
%
%   T          : table
%   candidates : cell array of candidate names (any spelling/case)
%   default_val: returned if no column matches (default: [])
%
%   Returns the FIRST column whose normalized name matches any of the
%   candidates' normalized names. Errors clearly if none match and no
%   default is provided.
%
%   Author: RCW (2026-06)

if nargin < 3, default_val = []; end
if ~iscell(candidates), candidates = {candidates}; end

vnames = T.Properties.VariableNames;
vnorm  = cellfun(@normalizeVarName, vnames, 'UniformOutput', false);

for k = 1:numel(candidates)
    target = normalizeVarName(candidates{k});
    hit = find(strcmp(vnorm, target), 1);
    if ~isempty(hit)
        col = T.(vnames{hit});
        return;
    end
end

if nargin >= 3
    col = default_val;
else
    error('getTableColumn:not_found', ...
          'No column matching any of: %s\nAvailable: %s', ...
          strjoin(candidates, ', '), strjoin(vnames, ', '));
end
end
