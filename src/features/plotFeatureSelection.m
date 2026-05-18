function plotFeatureSelection(res, X, y, names, cfg)
%PLOTFEATURESELECTION  Heatmap, mRMR bar, LASSO path.

% --- Heatmap -----------------------------------------------------------
allMat = [X y];
allNms = [names(:); {'VS'}];
R = corr(allMat, 'rows','pairwise');
fig = figure('Color','w','Position',[100 100 700 600],'Visible','off');
imagesc(R); axis square;
colormap(redblue); caxis([-1 1]); cb = colorbar; cb.Label.String = 'Pearson r';
xticks(1:numel(allNms)); yticks(1:numel(allNms));
xticklabels(allNms); yticklabels(allNms);
xtickangle(45); title('Feature correlation matrix');
% annotate values
for i = 1:size(R,1)
    for j = 1:size(R,2)
        text(j, i, sprintf('%.2f', R(i,j)), ...
            'HorizontalAlignment','center','FontSize',8, ...
            'Color', ifelse(abs(R(i,j))>0.5,'w','k'));
    end
end
savePublicationFigure(fig, 'FS_heatmap_correlation', cfg);
close(fig);

% --- mRMR scores -------------------------------------------------------
fig = figure('Color','w','Position',[100 100 600 350],'Visible','off');
[ms, ord] = sort(res.mrmr.scores, 'descend');
bar(ms, 'FaceColor',[0.85 0.45 0.20]); grid on;
xticks(1:numel(ms)); xticklabels(names(ord));
ylabel('mRMR score'); title('Minimum Redundancy Maximum Relevance');
savePublicationFigure(fig, 'FS_mRMR_scores', cfg);
close(fig);

% --- LASSO coefficient path -------------------------------------------
fig = figure('Color','w','Position',[100 100 700 450],'Visible','off');
lam = res.lasso.fitInfo.Lambda;
plot(log(lam), res.lasso.B', 'LineWidth', 1.4); hold on;
yl = ylim; xl = xline(log(res.lasso.fitInfo.Lambda1SE), '--k', '\lambda_{1SE}');
xl.LabelHorizontalAlignment='left';
xline(log(res.lasso.fitInfo.LambdaMinMSE), ':k', '\lambda_{minMSE}');
xlabel('log(\lambda)'); ylabel('Coefficient');
legend(names, 'Location','bestoutside'); grid on;
title('LASSO coefficient path');
savePublicationFigure(fig, 'FS_LASSO_path', cfg);
close(fig);
end

function out = ifelse(c,a,b); if c, out=a; else, out=b; end; end

function cmap = redblue(n)
% Symmetric red-white-blue colormap
if nargin<1, n=256; end
mid = round(n/2);
r = [linspace(0.10,1,mid) ones(1,n-mid)]';
g = [linspace(0.30,1,mid) linspace(1,0.30,n-mid)]';
b = [ones(1,mid) linspace(1,0.10,n-mid)]';
cmap = [r g b];
end
