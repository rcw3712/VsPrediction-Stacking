function save_figure_safe(fig, path, dpi)
% SAVE_FIGURE_SAFE — exportgraphics with mkdir + fallback to print
if nargin < 3, dpi = 300; end
parent = fileparts(path);
if ~isempty(parent) && ~exist(parent, 'dir'), mkdir(parent); end
try
    warning('off', 'all');
    exportgraphics(fig, path, 'Resolution', dpi);
    warning('on', 'all');
catch
    try
        print(fig, path, sprintf('-r%d', dpi), '-dpng');
    catch ME2
        warning('Could not save figure %s: %s', path, ME2.message);
    end
end
fprintf('  [FIG] Saved: %s\n', path);
end
