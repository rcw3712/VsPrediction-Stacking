function x_out = denoise_savgol(x, cfg)
% DENOISE_SAVGOL — Savitzky-Golay filter with edge protection
%   Author: RCW (2026-06)

x_out = x;
if any(isnan(x_out))
    warning('denoise_savgol: input has NaN, attempting filtering on valid block only');
end
win = cfg.preprocess.savgol_window;
ord = cfg.preprocess.savgol_order;
if numel(x_out) <= win || any(isnan(x_out))
    return;   % too short or has NaN — skip
end
try
    x_out = sgolayfilt(x_out, ord, win);
catch
    x_out = movmean(x_out, win, 'omitnan');
end
end
