function metrics = evaluate_model(y_true_kms, y_pred_kms)
% EVALUATE_MODEL — compute R², RMSE, MAE, MAPE, Bias in physical units (km/s).
%
%   Inputs MUST be in km/s.
%   ALWAYS returns the canonical 7-field metric struct (see force_metric_fields).
%
%   MAPE is computed only on |y_true| > 0.1 km/s and finite values to avoid
%   division blow-up and to prevent the z-score domain meaningless values.
%
%   Author: RCW (2026-06)

% Always start with the canonical schema
metrics = force_metric_fields();

% Robust input handling
y_true_kms = double(y_true_kms(:));
y_pred_kms = double(y_pred_kms(:));
valid = ~isnan(y_true_kms) & ~isnan(y_pred_kms) & ...
        isfinite(y_true_kms) & isfinite(y_pred_kms);
y_t = y_true_kms(valid);
y_p = y_pred_kms(valid);

if isempty(y_t)
    return;
end

% R²
ss_res = sum((y_t - y_p).^2);
ss_tot = sum((y_t - mean(y_t)).^2);
if ss_tot < 1e-12
    metrics.R2 = NaN;
else
    metrics.R2 = double(1 - ss_res / ss_tot);
end

metrics.RMSE_kms = double(sqrt(mean((y_t - y_p).^2)));
metrics.MAE_kms  = double(mean(abs(y_t - y_p)));
metrics.Bias_kms = double(mean(y_p - y_t));
metrics.N        = double(numel(y_t));

% MAPE: only on physical positive Vs > 0.1 km/s
mape_mask = (y_t > 0.1) & isfinite(y_t) & isfinite(y_p);
if any(mape_mask)
    metrics.MAPE_percent = double(100 * mean(abs((y_t(mape_mask) - y_p(mape_mask)) ./ y_t(mape_mask))));
else
    metrics.MAPE_percent = NaN;
end

metrics.Domain = 'physical_kms';
end
