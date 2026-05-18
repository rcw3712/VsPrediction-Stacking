function [well, ppStats] = preprocessWell(well, cfg, logFile, wellTag, ppStatsRef)
%PREPROCESSWELL  Apply the consistent preprocessing chain to a well.
%
%   [well, ppStats] = preprocessWell(well, cfg, logFile, wellTag)        % learn stats
%   [well, ppStats] = preprocessWell(well, cfg, logFile, wellTag, ppRef) % apply ref stats
%
%   Steps (in order):
%     1) Resampling to a uniform depth interval
%     2) Outlier detection (IQR + z-score) -> set to NaN
%     3) Imputation (linear interpolation OR KNN)
%     4) Savitzky-Golay denoising
%     5) Normalization (z-score / min-max)  -- training stats reused on
%        deployment well to avoid leakage
%
%   When PPSTATSREF is supplied, the function uses the reference well's
%   normalization parameters (mean/std or min/max) instead of recomputing,
%   guaranteeing consistency between BT-4 and BT-1.
%--------------------------------------------------------------------------

if nargin < 5, ppStatsRef = []; end

curveNames = fieldnames(well.curves);
logMsg(logFile, sprintf('  [%s] Curves before pp: %s', wellTag, strjoin(curveNames, ',')));

% --- 1) Resample uniformly ---------------------------------------------
[well.depth, well.curves] = resampleDepth(well.depth, well.curves, cfg.pp.resampleStep);
logMsg(logFile, sprintf('  [%s] Resampled to dz=%.4f m, N=%d', ...
    wellTag, cfg.pp.resampleStep, numel(well.depth)));

% --- 2) Outlier detection ----------------------------------------------
ppStats.outliers = struct();
for k = 1:numel(curveNames)
    nm = curveNames{k};
    x  = well.curves.(nm);
    [mask, info] = detectOutliers(x, cfg.pp.outlierMethod, ...
        cfg.pp.iqrFactor, cfg.pp.zScoreThr);
    well.curves.(nm)(mask) = NaN;
    ppStats.outliers.(nm)  = info;
end

% --- 3) Imputation -----------------------------------------------------
for k = 1:numel(curveNames)
    nm = curveNames{k};
    well.curves.(nm) = imputeMissing(well.curves.(nm), well.depth, ...
        cfg.pp.imputationMethod, cfg.pp.knnNeighbors);
end

% --- 4) Savitzky-Golay denoising ---------------------------------------
for k = 1:numel(curveNames)
    nm = curveNames{k};
    if numel(well.curves.(nm)) > cfg.pp.savgolFrameLen
        well.curves.(nm) = denoiseSavGol(well.curves.(nm), ...
            cfg.pp.savgolOrder, cfg.pp.savgolFrameLen);
    end
end

% --- 5) Normalization --------------------------------------------------
%   Save raw values too so we can plot original logs.
well.curvesRaw = well.curves;

if isempty(ppStatsRef)
    [well.curvesNorm, ppStats.norm] = normalizeData( ...
        well.curves, cfg.pp.normalization, []);
else
    [well.curvesNorm, ppStats.norm] = normalizeData( ...
        well.curves, cfg.pp.normalization, ppStatsRef.norm);
end

ppStats.method = cfg.pp.normalization;
ppStats.well   = wellTag;

logMsg(logFile, sprintf('  [%s] Normalization: %s (stats %s)', ...
    wellTag, cfg.pp.normalization, ...
    ternary(isempty(ppStatsRef),'fitted','reused')));

% --- 6) Plot quick QC --------------------------------------------------
plotQCLogs(well, wellTag, cfg);
end

% =======================================================================
function plotQCLogs(well, wellTag, cfg)
fn = fieldnames(well.curvesRaw);
n = numel(fn);
fig = figure('Color','w','Position',[100 100 220*n 600], 'Visible', 'off');
tl = tiledlayout(fig, 1, n, 'Padding', 'compact', 'TileSpacing','compact');
for k = 1:n
    ax = nexttile(tl);
    plot(ax, well.curvesRaw.(fn{k}), well.depth, 'k-'); hold(ax,'on');
    set(ax, 'YDir', 'reverse');
    xlabel(ax, fn{k}); if k==1, ylabel(ax,'Depth (m)'); end
    grid(ax,'on');
end
title(tl, sprintf('Preprocessed logs - %s', wellTag));
savePublicationFigure(fig, sprintf('QC_logs_%s', wellTag), cfg);
close(fig);
end

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
