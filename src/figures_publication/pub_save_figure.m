function pub_save_figure(fig, outdir, name, dpi)
% PUB_SAVE_FIGURE — save publication figure as PNG (300 DPI) + PDF (vector)
%   Author: RCW (2026-06)
if nargin < 4, dpi = 300; end
if ~exist(outdir, 'dir'), mkdir(outdir); end
set(fig, 'Color', 'w', 'InvertHardcopy', 'off');
try
    exportgraphics(fig, fullfile(outdir, [name '.png']), 'Resolution', dpi);
catch
    print(fig, fullfile(outdir, [name '.png']), sprintf('-r%d', dpi), '-dpng');
end
try
    exportgraphics(fig, fullfile(outdir, [name '.pdf']), 'ContentType', 'vector');
catch
    print(fig, fullfile(outdir, [name '.pdf']), '-dpdf', '-bestfit');
end
fprintf('  [FIG-PUB] %s.png/.pdf saved\n', name);
end
