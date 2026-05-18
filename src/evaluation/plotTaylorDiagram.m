function plotTaylorDiagram(yRef, predList, names, cfg, baseName)
%PLOTTAYLORDIAGRAM  Custom Taylor diagram (R, sigma, RMSD).
%
%   yRef     : reference vector
%   predList : cell array of predicted vectors
%   names    : cellstr labels

if nargin < 5, baseName = 'taylor_diagram'; end

sRef = std(yRef, 0, 'omitnan');
% Normalised stds and correlations
sigmas = zeros(numel(predList),1);
corrs  = zeros(numel(predList),1);
for k = 1:numel(predList)
    p = predList{k};
    sigmas(k) = std(p,0,'omitnan') / sRef;
    R = corr(yRef, p, 'rows','complete');
    corrs(k) = R;
end

fig = figure('Color','w','Position',[100 100 600 600], 'Visible','off');
ax = gca; hold(ax,'on');

% --- Polar grid -------------------------------------------------------
maxR = max([sigmas; 1.5]);
theta = linspace(0, pi/2, 100);
% sigma circles (dashed)
for r = 0.25:0.25:ceil(maxR*4)/4
    plot(ax, r*cos(theta), r*sin(theta), ':', 'Color',[0.6 0.6 0.6]);
end
% correlation rays
rays = [0 0.2 0.4 0.6 0.8 0.9 0.95 0.99 1];
for k = 1:numel(rays)
    a = acos(rays(k));
    plot(ax, [0 maxR*cos(a)], [0 maxR*sin(a)], ':', 'Color',[0.6 0.6 0.6]);
    text(ax, (maxR+0.05)*cos(a), (maxR+0.05)*sin(a), ...
        sprintf('%.2f', rays(k)), 'HorizontalAlignment','center', ...
        'FontSize',9,'Color',[0.3 0.3 0.3]);
end
% Reference point on x-axis at sigma=1
plot(ax, 1, 0, 'k^', 'MarkerFaceColor','k', 'MarkerSize',9);
text(ax, 1, -0.05, 'Ref', 'HorizontalAlignment','center');

% RMSD circles around (1,0)
for rmsd = 0.25:0.25:1.5
    th = linspace(0, 2*pi, 100);
    xc = 1 + rmsd*cos(th); yc = rmsd*sin(th);
    keep = yc >= 0 & sqrt(xc.^2 + yc.^2) <= maxR + 0.05;
    plot(ax, xc(keep), yc(keep), '-.', 'Color',[0.85 0.55 0.40]);
end

% --- Plot models ------------------------------------------------------
clr = lines(numel(predList));
for k = 1:numel(predList)
    a = acos(max(min(corrs(k),1),-1));
    x = sigmas(k)*cos(a); y = sigmas(k)*sin(a);
    plot(ax, x, y, 'o','MarkerSize',10,'MarkerFaceColor',clr(k,:), ...
         'MarkerEdgeColor','k');
    text(ax, x+0.02, y+0.02, names{k}, 'FontSize',10);
end

axis(ax,'equal'); xlim(ax,[0 maxR+0.2]); ylim(ax,[0 maxR+0.2]);
xlabel(ax,'Standard deviation (normalised)');
ylabel(ax,'Standard deviation (normalised)');
title(ax,'Taylor diagram');
set(ax,'Box','on');

savePublicationFigure(fig, baseName, cfg);
close(fig);
end
