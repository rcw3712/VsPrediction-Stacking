function write_table_safe(T, path, varargin)
% WRITE_TABLE_SAFE — write table with mkdir + extension handling
parent = fileparts(path);
if ~isempty(parent) && ~exist(parent, 'dir'), mkdir(parent); end
writetable(T, path, varargin{:});
fprintf('  [IO] Wrote: %s\n', path);
end
