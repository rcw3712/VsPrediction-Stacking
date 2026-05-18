function m = computeMetrics(y, yhat)
%COMPUTEMETRICS  Standard regression metrics: [R2 RMSE MAE MAPE].
%
%   y, yhat : column vectors
%   MAPE is in percent; values where |y|<eps are excluded to avoid
%   division by zero.

y = y(:); yhat = yhat(:);
ok = isfinite(y) & isfinite(yhat);
y = y(ok); yhat = yhat(ok);
if isempty(y)
    m = [NaN NaN NaN NaN]; return;
end
ss_res = sum((y - yhat).^2);
ss_tot = sum((y - mean(y)).^2);
R2     = 1 - ss_res / max(ss_tot, eps);
RMSE   = sqrt(mean((y - yhat).^2));
MAE    = mean(abs(y - yhat));
denom  = max(abs(y), 1e-3);   % protect against near-zero
MAPE   = mean(abs((y - yhat) ./ denom)) * 100;
m = [R2 RMSE MAE MAPE];
end
