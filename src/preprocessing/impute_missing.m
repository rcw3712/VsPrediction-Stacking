function x_out = impute_missing(x, cfg)
% IMPUTE_MISSING — interp1 for short gaps, KNN-style mean for long gaps
%   x: column vector with NaN
%   Author: RCW (2026-06)

x_out = x;
nan_mask = isnan(x_out);
if ~any(nan_mask) || all(nan_mask)
    return;
end

idx = (1:numel(x_out))';
good = ~nan_mask;

% Step 1: linear interp for short gaps
try
    x_interp = interp1(idx(good), x_out(good), idx, 'linear', NaN);
    % Identify gap lengths; replace only short gaps with interp
    gap_lengths = compute_gap_lengths(nan_mask);
    short_gap = nan_mask & (gap_lengths <= cfg.preprocess.gap_short_max);
    x_out(short_gap) = x_interp(short_gap);
catch
end

% Step 2: KNN-style mean for remaining long gaps
remaining_nan = isnan(x_out);
if any(remaining_nan)
    good_idx  = find(~remaining_nan);
    bad_idx   = find(remaining_nan);
    K = cfg.preprocess.knn_k;
    for i = bad_idx(:)'
        % Find K nearest non-NaN neighbors by index distance
        d = abs(good_idx - i);
        [~, sord] = sort(d);
        nn = good_idx(sord(1:min(K, numel(good_idx))));
        x_out(i) = mean(x_out(nn));
    end
end

% Final: edge extrapolation if still NaN
still = isnan(x_out);
if any(still)
    x_out(still) = interp1(idx(~still), x_out(~still), idx(still), ...
                           'nearest', 'extrap');
end
end


function lens = compute_gap_lengths(mask)
% Return same-size vector where each NaN position holds the length of its gap
lens = zeros(size(mask));
n = numel(mask);
i = 1;
while i <= n
    if mask(i)
        j = i;
        while j <= n && mask(j), j = j + 1; end
        lens(i:j-1) = j - i;
        i = j;
    else
        i = i + 1;
    end
end
end
