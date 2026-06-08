function [y_clipped, clipped_mask] = clip_predictions(y_raw, lo, hi)
% CLIP_PREDICTIONS — physical clipping
%   Author: RCW (2026-06)

y_clipped    = min(max(y_raw, lo), hi);
clipped_mask = y_clipped ~= y_raw;
end
