function mask_bad = detect_outliers(x, cfg)
% DETECT_OUTLIERS — IQR + z-score double-criterion
%   Returns logical mask of outliers (true = remove/mark NaN).
%   Author: RCW (2026-06)

valid = ~isnan(x);
if sum(valid) < 4
    mask_bad = false(size(x));
    return;
end

vv = x(valid);
Q  = quantile(vv, [0.25 0.75]);
iqr_v = Q(2) - Q(1);
lo_iqr = Q(1) - cfg.preprocess.iqr_k * iqr_v;
hi_iqr = Q(2) + cfg.preprocess.iqr_k * iqr_v;

mu = mean(vv);
sd = std(vv);

mask_bad = false(size(x));
mask_bad(valid) = (vv < lo_iqr) | (vv > hi_iqr) | ...
                  (abs(vv - mu) > cfg.preprocess.zscore_thresh * sd);
end
