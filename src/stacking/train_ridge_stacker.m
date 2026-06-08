function model = train_ridge_stacker(Z_oof, y_train_z, cfg)
% TRAIN_RIDGE_STACKER — closed-form ridge regression on OOF meta-features.
%   Z_oof: n × M matrix of OOF predictions from M base learners
%   y_train_z: n × 1 training target (z-score domain)
%   Selects optimal lambda via internal CV from cfg.model.ridge.lambda_grid.
%   Author: RCW (2026-06)

[n, M] = size(Z_oof);
lambdas = cfg.model.ridge.lambda_grid;
K = cfg.model.ridge.cv_folds;

rng(cfg.seed, 'twister');
cv = cvpartition(n, 'KFold', K);

best_lambda = lambdas(1);
best_rmse = inf;
for li = 1:numel(lambdas)
    lam = lambdas(li);
    rmse_f = zeros(K, 1);
    for f = 1:K
        tr = training(cv, f);
        va = test(cv, f);
        % Closed-form: beta = (X'X + lam*I) \ X'y
        Zt = Z_oof(tr, :);
        yt = y_train_z(tr);
        A  = Zt' * Zt + lam * eye(M);
        b  = Zt' * yt;
        beta = A \ b;
        yhat_va = Z_oof(va, :) * beta;
        rmse_f(f) = sqrt(mean((yhat_va - y_train_z(va)).^2));
    end
    if mean(rmse_f) < best_rmse
        best_rmse = mean(rmse_f);
        best_lambda = lam;
    end
end

% Final beta on full Z_oof
A = Z_oof' * Z_oof + best_lambda * eye(M);
b = Z_oof' * y_train_z;
beta = A \ b;

model.kind        = 'ridge';
model.beta        = beta;
model.lambda_star = best_lambda;
model.cv_rmse     = best_rmse;
end
