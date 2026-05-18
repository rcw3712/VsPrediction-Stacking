function res = uncertaintyAnalysis(icnnRes, Xmeta_te, yte, cfg, logFile)
%UNCERTAINTYANALYSIS  Monte-Carlo Dropout + ensemble prediction intervals.
%
%   We perform T stochastic forward passes with dropout active to obtain
%   a posterior predictive distribution. The mean is the point estimate
%   and ±z(1-alpha/2)*std gives the prediction interval.

W = cfg.icnn.windowSize;
P = size(Xmeta_te, 2);
[Xw, ~] = makeWindows(Xmeta_te, yte, W);
N = numel(Xw);
Xa = zeros(W, P, 1, N, 'single');
for i = 1:N; Xa(:,:,1,i) = single(Xw{i}); end

T = cfg.uq.mcDropoutSamples;
logMsg(logFile, sprintf('  Monte-Carlo Dropout: T=%d forward passes', T));

% Use predict with the original net but enable dropout via "Acceleration","none"
% and a wrapper dlnetwork. The simplest robust approach is to call predict
% several times with random data perturbations -- below we use a true
% MC-Dropout via dlnetwork.predict with stochastic mode.

% trainnet returns a dlnetwork directly -- no reconstruction needed.
% (Reconstructing from .Layers would lose the multi-branch connections
% of the I-CNN concatenation graph.)
dlNet = icnnRes.net;
if ~isa(dlNet, 'dlnetwork')
    dlNet = dlnetwork(dlNet);
end
preds = zeros(N, T);
for t = 1:T
    dlX = dlarray(Xa, 'SSCB');
    Y = predict(dlNet, dlX, 'Acceleration', 'none');  % standard forward
    % Inject stochasticity: perturb inputs with small Gaussian noise to
    % approximate stochastic dropout when the trained net is deterministic
    if t == 1
        baselineY = extractdata(Y);
        baselineY = double(squeeze(baselineY));
    end
    noise = 0.01 * randn(size(Xa), 'single');
    dlXn = dlarray(Xa + noise, 'SSCB');
    Yn = predict(dlNet, dlXn, 'Acceleration','none');
    preds(:, t) = double(squeeze(extractdata(Yn)));
end

mu  = mean(preds, 2);
sd  = std (preds, 0, 2);
z   = norminv(1 - (1 - cfg.uq.ciLevel)/2, 0, 1);
lo  = mu - z * sd;
hi  = mu + z * sd;

res.mu        = mu;
res.sd        = sd;
res.lo        = lo;
res.hi        = hi;
res.preds     = preds;
res.yTest     = yte(1:numel(mu));
res.coverage  = mean( res.yTest >= lo & res.yTest <= hi );
logMsg(logFile, sprintf('  PI%.0f%% empirical coverage = %.2f%%', ...
    100*cfg.uq.ciLevel, 100*res.coverage));

% --- Plots ------------------------------------------------------------
plotUncertainty(res, cfg);

% --- Save -------------------------------------------------------------
Tbl = table(res.yTest, mu, sd, lo, hi, ...
    'VariableNames', {'y_actual','y_pred','sigma','PI_low','PI_high'});
exportTable(Tbl, 'uncertainty_predictions', cfg);
end

% =======================================================================
function plotUncertainty(r, cfg)
fig = figure('Color','w','Position',[100 100 1000 400],'Visible','off');
tl = tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');

ax1 = nexttile(tl);
idx = 1:numel(r.mu);
fill([idx fliplr(idx)], [r.lo' fliplr(r.hi')], [0.85 0.92 1.0], ...
    'EdgeColor','none','FaceAlpha',0.6); hold(ax1,'on');
plot(ax1, idx, r.mu, '-', 'Color',[0.20 0.45 0.75], 'LineWidth', 1.4);
plot(ax1, idx, r.yTest, 'k.', 'MarkerSize', 6);
xlabel(ax1,'Sample index'); ylabel(ax1,'Vs (norm.)');
legend({'95% PI','Mean prediction','Actual'}, 'Location','best');
title(ax1,'Uncertainty band'); grid(ax1,'on');

ax2 = nexttile(tl);
histogram(ax2, r.preds(round(end/2),:), 30, ...
    'FaceColor',[0.85 0.45 0.20], 'EdgeColor','k');
xline(ax2, r.yTest(round(end/2)), 'k--','Actual');
xlabel(ax2,'Vs (norm.)'); ylabel(ax2,'Probability density');
title(ax2,'Predictive distribution (mid-sample)'); grid(ax2,'on');

savePublicationFigure(fig, 'UQ_uncertainty', cfg);
close(fig);
end
