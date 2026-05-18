function plotBaseLearnerEvaluation(res, ytr, yte, cfg) %#ok<INUSL>
%PLOTBASELEARNEREVALUATION  Generate publication-grade comparative plots.

models = {'PNN','MLFFNN','DFFNN','CNN1D'};
colors = lines(numel(models));

% --- Predicted vs Actual (test) ----------------------------------------
fig = figure('Color','w','Position',[100 100 1100 280],'Visible','off');
tl  = tiledlayout(fig, 1, numel(models), 'Padding','compact','TileSpacing','compact');
for m = 1:numel(models)
    ax = nexttile(tl);
    yh = res.(models{m}).yhatTest;
    scatter(ax, yte, yh, 12, 'filled', 'MarkerFaceColor', colors(m,:)); hold(ax,'on');
    mn = min([yte;yh]); mx = max([yte;yh]);
    plot(ax,[mn mx],[mn mx],'k--','LineWidth',1.0);
    xlabel(ax,'Vs actual'); if m==1, ylabel(ax,'Vs predicted'); end
    metr = res.(models{m}).metricsTest;
    title(ax, sprintf('%s  R^2=%.2f', models{m}, metr(1)));
    grid(ax,'on'); axis(ax,'square');
end
title(tl,'Predicted vs Actual (test set)');
savePublicationFigure(fig, 'BL_predicted_vs_actual', cfg);
close(fig);

% --- Residual plots ---------------------------------------------------
fig = figure('Color','w','Position',[100 100 1100 280],'Visible','off');
tl  = tiledlayout(fig, 1, numel(models), 'Padding','compact','TileSpacing','compact');
for m = 1:numel(models)
    ax = nexttile(tl);
    rr = yte - res.(models{m}).yhatTest;
    scatter(ax, res.(models{m}).yhatTest, rr, 10, 'filled', ...
        'MarkerFaceColor', colors(m,:));
    yline(ax, 0, 'k--');
    xlabel(ax,'Vs predicted'); if m==1, ylabel(ax,'Residual'); end
    title(ax, models{m}); grid(ax,'on');
end
title(tl,'Residual plots');
savePublicationFigure(fig, 'BL_residuals', cfg);
close(fig);

% --- Error histograms -------------------------------------------------
fig = figure('Color','w','Position',[100 100 1100 280],'Visible','off');
tl  = tiledlayout(fig, 1, numel(models), 'Padding','compact','TileSpacing','compact');
for m = 1:numel(models)
    ax = nexttile(tl);
    rr = yte - res.(models{m}).yhatTest;
    histogram(ax, rr, 25, 'FaceColor', colors(m,:), 'EdgeColor','k');
    xlabel(ax,'Residual'); if m==1, ylabel(ax,'Frequency'); end
    title(ax, models{m}); grid(ax,'on');
end
title(tl,'Error histograms');
savePublicationFigure(fig, 'BL_error_histograms', cfg);
close(fig);

% --- Bar chart of metrics --------------------------------------------
fig = figure('Color','w','Position',[100 100 800 350],'Visible','off');
metMat = zeros(numel(models), 4);
for m = 1:numel(models)
    metMat(m,:) = res.(models{m}).metricsTest;
end
b = bar(metMat); ylabel('Metric value');
xticklabels(models); legend({'R^2','RMSE','MAE','MAPE'},'Location','best');
title('Base learners — test metrics'); grid on;
for k = 1:numel(b); b(k).EdgeColor='k'; end
savePublicationFigure(fig, 'BL_metrics_bar', cfg);
close(fig);

% --- Taylor diagram (custom) -----------------------------------------
plotTaylorDiagram(yte, ...
    cellfun(@(m) res.(m).yhatTest, models, 'UniformOutput', false), ...
    models, cfg, 'BL_taylor_diagram');
end
