function shap = computeShapValues(model, X, names, cfg)
%COMPUTESHAPVALUES  Vectorised Monte-Carlo Shapley value estimator.
%
%   Strumbelj & Kononenko (2014) — same algorithm as before, but with
%   batched predict() calls.  Earlier the inner loop fired one predict()
%   per (sample, feature, permutation) combination -> O(N x P x M) single
%   row predictions, which is killed by MATLAB's per-call overhead.  Here
%   we collect Nexplain rows into a single tall matrix and predict in one
%   shot, then accumulate the contributions in fully vectorised form.
%
%   Complexity   : O(M x P) batched predicts of Nexplain rows each (a few
%                  hundred batched predicts), instead of O(N x M x P)
%                  single-row predicts (millions of calls). Speed-up ~1000x.
%
%   Inputs
%     model     : trained regression model with a predict() method
%     X         : [Ntrain x P] feature matrix used to train `model`
%     names     : cellstr of feature names
%     cfg.fs.   : .shapNumExplain (sample subset, default 300)
%                 .shapNumSamples (background pool size, default 200)
%                 .shapNumPerm    (permutations, default 50)
%
%   Outputs
%     shap.values  : [Nexplain x P] per-sample Shapley contributions
%     shap.global  : 1 x P mean|phi_j| (global importance)
%     shap.names   : feature names
%--------------------------------------------------------------------------

[Ntrain, P] = size(X);

% Defaults if user did not set the newer parameters
if isfield(cfg.fs,'shapNumExplain'), nExplain = cfg.fs.shapNumExplain;
else,                                nExplain = 300; end
if isfield(cfg.fs,'shapNumSamples'), nBg = cfg.fs.shapNumSamples;
else,                                nBg = 200; end
if isfield(cfg.fs,'shapNumPerm'),    M = cfg.fs.shapNumPerm;
else,                                M = 50; end
nExplain = min(nExplain, Ntrain);
nBg      = min(nBg     , Ntrain);

rng(0, 'twister');                          % deterministic SHAP subset
explainIdx = randperm(Ntrain, nExplain);
bgIdx      = randperm(Ntrain, nBg);
Xe = X(explainIdx, :);
bg = X(bgIdx, :);

phi = zeros(nExplain, P);                    % Shapley accumulator

% For each permutation m we build two Nexplain x P matrices per
% insertion (xWith, xWithout). We do P insertions per permutation,
% so 2*P batched predicts per permutation. Total batched predicts: 2*M*P.
t0 = tic;
for m = 1:M
    perm  = randperm(P);                            % random feature ordering
    bRow  = bg(randi(nBg, nExplain, 1), :);         % independent baseline per sample

    xCur = bRow;                                    % start = pure baseline

    for jj = 1:P
        j = perm(jj);
        xWO       = xCur;
        xW        = xCur;
        xW(:, j)  = Xe(:, j);

        yWO = predict(model, xWO);                  % batched
        yW  = predict(model, xW );                  % batched
        phi(:, j) = phi(:, j) + (yW - yWO);

        xCur(:, j) = Xe(:, j);                      % j now in coalition
    end

    if mod(m, max(1, round(M/10))) == 0
        fprintf('    SHAP progress: %3d / %d permutations  (elapsed %.1fs)\n', ...
            m, M, toc(t0));
    end
end
phi = phi / M;

shap.values = phi;
shap.global = mean(abs(phi), 1);
shap.names  = names;

plotShap(shap, Xe, cfg);
end

% =======================================================================
function plotShap(shap, X, cfg)
fig = figure('Color','w','Position',[100 100 900 500],'Visible','off');
tl = tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');

% Global importance bar
ax1 = nexttile(tl);
[gs, ord] = sort(shap.global, 'descend');
bar(ax1, gs, 'FaceColor', [0.20 0.45 0.75], 'EdgeColor','k');
xticks(ax1, 1:numel(gs)); xticklabels(ax1, shap.names(ord));
ylabel(ax1, 'mean(|SHAP|)'); title(ax1, 'Global feature importance');
grid(ax1,'on');

% Beeswarm-style summary
ax2 = nexttile(tl);
hold(ax2,'on');
P = size(shap.values, 2);
for j = 1:P
    jj = ord(j);
    yj = repmat(P-j+1, size(shap.values,1), 1) + ...
         0.25*(rand(size(shap.values,1),1)-0.5);
    scatter(ax2, shap.values(:,jj), yj, 8, X(:,jj), 'filled', ...
            'MarkerFaceAlpha', 0.5);
end
yticks(ax2, 1:P); yticklabels(ax2, flip(shap.names(ord)));
xlabel(ax2, 'SHAP value (impact on Vs)');
title(ax2, 'Feature contribution');
colormap(ax2, parula); cb = colorbar(ax2);
cb.Label.String = 'Feature value (norm.)';
grid(ax2,'on');

savePublicationFigure(fig, 'SHAP_summary', cfg);
close(fig);
end
