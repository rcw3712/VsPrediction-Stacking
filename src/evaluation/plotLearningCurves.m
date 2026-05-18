function plotLearningCurves(baseRes, optRes, cfg)
%PLOTLEARNINGCURVES  Publication-grade learning curve per neural model.
%
%   R2024b compatibility: `trainnet` returns info.TrainingHistory as a
%   timetable/table; older versions return info.TrainingLoss as a vector.
%   This helper handles both formats.

if nargin < 2, optRes = []; end

models = {'MLFFNN','DFFNN','CNN1D'};
have   = intersect(models, fieldnames(baseRes));
if isempty(have); return; end

f = figure('Color','w','Position',[100 100 1200 360],'Visible','off');
tl = tiledlayout(f, 1, numel(have), 'Padding','compact', 'TileSpacing','compact');
title(tl, 'Learning Curves (train vs validation loss)', ...
      'FontWeight','bold','FontName',cfg.fig.fontName);

for i = 1:numel(have)
    nm = have{i};
    nexttile;

    % --- Pull trainInfo from optRes if available, else baseRes
    info = [];
    if ~isempty(optRes) && isfield(optRes, nm) && ...
       isstruct(optRes.(nm).bestModel) && ...
       isfield(optRes.(nm).bestModel, 'trainInfo')
        info = optRes.(nm).bestModel.trainInfo;
    elseif isfield(baseRes.(nm), 'trainInfo')
        info = baseRes.(nm).trainInfo;
    end

    % --- Parse train/val loss arrays from either API ---------------
    [trainLoss, valLoss] = parseTrainInfo(info);

    if ~isempty(trainLoss)
        epochs = 1:numel(trainLoss);
        plot(epochs, trainLoss, 'b-', 'LineWidth',1.6); hold on;
        if ~isempty(valLoss) && any(isfinite(valLoss))
            % Validation loss is typically sampled at intervals; pad to
            % match train length when needed
            if numel(valLoss) == numel(trainLoss)
                plot(epochs, valLoss, 'r--', 'LineWidth',1.6);
            else
                idxV = round(linspace(1, numel(trainLoss), numel(valLoss)));
                plot(idxV, valLoss, 'r--', 'LineWidth',1.6);
            end
            legend({'Train','Validation'}, 'Location','best','Box','off');
        else
            legend({'Train'}, 'Location','best','Box','off');
        end
        xlabel('Iteration / Epoch'); ylabel('MSE Loss');
    else
        text(0.5, 0.5, sprintf('No training history\nstored for %s', nm), ...
             'Units','normalized','HorizontalAlignment','center');
        set(gca,'XTick',[],'YTick',[]);
    end
    title(nm, 'FontWeight','bold');
    grid on; box on;
    set(gca,'FontName',cfg.fig.fontName,'FontSize',cfg.fig.fontSize);
end

savePublicationFigure(f, 'EVAL_learning_curves', cfg);
close(f);
end

% =======================================================================
function [trainLoss, valLoss] = parseTrainInfo(info)
%PARSETRAININFO  Extract loss arrays regardless of trainnet API version.
% R2024b: `info` is a TrainingInfo OBJECT (not a struct) -> isfield()
% returns false. Use try-catch on direct field access instead.
trainLoss = [];  valLoss = [];
if isempty(info), return; end

% --- Try to grab TrainingHistory (R2024b object property) -------------
th = [];
try
    th = info.TrainingHistory;
catch
    th = [];
end

if ~isempty(th)
    if istimetable(th); th = timetable2table(th); end
    if istable(th)
        vn = th.Properties.VariableNames;
        % Find training-loss column (multiple possible names)
        for cand = {'TrainingLoss','Loss','TrainLoss'}
            ix = find(strcmpi(vn, cand{1}), 1);
            if ~isempty(ix), trainLoss = th{:, ix}; break; end
        end
        % Find validation-loss column
        for cand = {'ValidationLoss','ValLoss'}
            ix = find(strcmpi(vn, cand{1}), 1);
            if ~isempty(ix), valLoss = th{:, ix}; break; end
        end
    elseif isstruct(th)
        if isfield(th,'TrainingLoss'),   trainLoss = th.TrainingLoss(:); end
        if isfield(th,'Loss') && isempty(trainLoss), trainLoss = th.Loss(:); end
        if isfield(th,'ValidationLoss'), valLoss   = th.ValidationLoss(:); end
    end
end

% --- Pre-R2024b fallback: info.TrainingLoss / info.ValidationLoss -----
if isempty(trainLoss)
    try, trainLoss = info.TrainingLoss(:);   catch, end
end
if isempty(valLoss)
    try, valLoss   = info.ValidationLoss(:); catch, end
end

% Strip NaNs
if ~isempty(trainLoss); trainLoss = trainLoss(isfinite(trainLoss)); end
if ~isempty(valLoss);   valLoss   = valLoss(isfinite(valLoss));     end
end
