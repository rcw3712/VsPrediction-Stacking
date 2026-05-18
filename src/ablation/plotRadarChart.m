function plotRadarChart(R, cfg)
%PLOTRADARCHART  Radar/spider plot for ablation scenarios.
%
%   Higher value = better. Metrics are inverted as needed and rescaled
%   to [0,1] across scenarios so all axes share a common scale.

cats = {'R^2','-RMSE','-MAE','-MAPE','-std(R^2)'};
M = [
    [R.R2]
    -[R.RMSE]
    -[R.MAE]
    -[R.MAPE]
    -[R.std_R2]
    ];

% Min-max rescale per axis
M = (M - min(M,[],2)) ./ max(range(M, 2), eps);

th = linspace(0, 2*pi, numel(cats)+1);
clr = lines(size(M,2));

fig = figure('Color','w','Position',[100 100 600 600],'Visible','off');
ax  = polaraxes(fig); hold(ax,'on');
for s = 1:size(M,2)
    rr = [M(:,s); M(1,s)];
    polarplot(ax, th, rr, '-o', 'LineWidth', 1.6, ...
        'Color', clr(s,:), 'MarkerFaceColor', clr(s,:));
end
ax.ThetaTick = rad2deg(th(1:end-1));
ax.ThetaTickLabel = cats;
ax.RLim = [0 1.05];
title(ax, 'Ablation radar chart (rescaled, larger = better)');
legend(ax, {R.tag}, 'Location','southoutside','NumColumns',2);

savePublicationFigure(fig, 'ABL_radar', cfg);
close(fig);
end
