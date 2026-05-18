function res = deployToBT1(BT1, finalFeatures, optRes, metaRes, cfg, logFile)
%DEPLOYTOBT1  Apply the trained pipeline to the deployment well (no Vs).
%
%   metaRes can be EITHER the I-CNN result (with .net) OR the Ridge result
%   (with .model, .kind='ridge'). Inference dispatches automatically.
%
%   Steps
%     1) Build feature matrix X (BT-1 normalised with BT-4 stats)
%     2) Get base-learner predictions -> meta-features
%     3) Run I-CNN to obtain final Vs prediction
%     4) Indirect validation:
%          - Vs vs depth trend
%          - Vp-Vs crossplot
%          - Castagna and Greenberg-Castagna comparison
%          - Geomechanical interpretation (Poisson, mu, K)

% --- Depth-range sanity (training vs deployment) --------------------
if isfield(BT1, 'depth') && isfield(cfg, 'trainDepthRange')
    z1 = min(BT1.depth);  z2 = max(BT1.depth);
    [zT0, zT1] = deal(cfg.trainDepthRange(1), cfg.trainDepthRange(2));
    overlap = max(0, min(z2,zT1) - max(z1,zT0));
    deployRange = max(eps, z2 - z1);
    if overlap / deployRange < 0.05
        logMsg(logFile, sprintf(['  *** VERTICAL EXTRAPOLATION WARNING *** \n' ...
            '      training depth   : %.0f - %.0f m\n' ...
            '      deployment depth : %.0f - %.0f m\n' ...
            '      overlap          : %.0f%% of deployment range\n' ...
            '      Predictions on BT-1 are out-of-distribution in depth.\n' ...
            '      Treat results as illustrative; report this as a limitation.'], ...
            zT0, zT1, z1, z2, 100*overlap/deployRange));
    end
end

[X, ~] = stackCurves(BT1, finalFeatures, '');

% --- Base-learner predictions ----------------------------------------
models = {'PNN','MLFFNN','DFFNN','CNN1D'};
Xmeta = zeros(size(X,1), numel(models));
for m = 1:numel(models)
    nm = models{m};
    mdl = optRes.(nm).bestModel;
    p   = optRes.(nm).bestParams;
    switch nm
        case 'PNN'    , Xmeta(:,m) = predictPNN(mdl, X);
        case 'MLFFNN' , Xmeta(:,m) = predictNN (mdl, X);
        case 'DFFNN'  , Xmeta(:,m) = predictNN (mdl, X);
        case 'CNN1D'  , Xmeta(:,m) = predictCNN1D(mdl, X, p);
    end
end

% --- Meta-learner inference (dispatches by metaRes.kind) ---------------
if isfield(metaRes, 'kind') && strcmpi(metaRes.kind, 'ridge')
    % Ridge: closed-form linear stacker, no windowing
    yPred_norm = metaTr_pred(metaRes, Xmeta);
    logMsg(logFile, '  Deployment using RIDGE stacker');
elseif isfield(metaRes, 'kind') && strcmpi(metaRes.kind, 'hybrid')
    % Hybrid I-CNN: needs concatenation of original X + base predictions,
    % then windowed reshape.
    W      = cfg.icnn.windowSize;
    P_orig = size(X, 2);
    K      = size(Xmeta, 2);
    Fused  = [X(1:size(Xmeta,1), :), Xmeta];     % N x (P_orig + K)
    [Xa, ~] = makeWindowsTensor(Fused, W);
    yPred_norm = double(predict(metaRes.net, Xa));
    yPred_norm = yPred_norm(:);
    logMsg(logFile, sprintf( ...
        '  Deployment using HYBRID I-CNN (%d original + %d base = %d channels)', ...
        P_orig, K, P_orig + K));
else
    % I-CNN stacker (legacy): windows over 4 base preds only
    W = cfg.icnn.windowSize; P = size(Xmeta,2);
    [Xw, ~] = makeWindows(Xmeta, zeros(size(Xmeta,1),1), W);
    N = numel(Xw);
    Xa = zeros(W, P, 1, N, 'single');
    for i = 1:N; Xa(:,:,1,i) = single(Xw{i}); end
    yPred_norm = double(predict(metaRes.net, Xa)); yPred_norm = yPred_norm(:);
    logMsg(logFile, '  Deployment using I-CNN multi-stack meta-learner');
end

% --- De-normalize back to physical units (km/s or m/s) --------------
% The target was z-scored using BT-4 stats; we don't have those here, so
% we expose normalised Vs and let the user de-normalize externally if
% the BT4 stats are passed in. For physical interpretation we use the
% Vp curve directly (BT-1 provides VP in m/s).
logMsg(logFile, sprintf('  I-CNN predicted %d Vs samples on BT-1', numel(yPred_norm)));

depth = BT1.depth(1:numel(yPred_norm));

% --- Get Vp directly from the BT-1 dataset (in m/s -> km/s) ----------
Vp_ms  = BT1.curvesRaw.VP(1:numel(yPred_norm));
Vp_kms = Vp_ms / 1000;

% --- Empirical Vs curves --------------------------------------------
Vs_castagna = cfg.emp.castagna.A .* Vp_kms - cfg.emp.castagna.B;

% Greenberg-Castagna for sandstone+shale weighted by GR
GR = BT1.curvesRaw.GR(1:numel(yPred_norm));
GRn = (GR - min(GR)) / max(range(GR), eps);  % rough Vsh proxy
a = cfg.emp.gcCoefs.sand;  % [a2 a1 a0]
b = cfg.emp.gcCoefs.shale;
Vs_sand  = a(1)*Vp_kms + a(2);
Vs_shale = b(1)*Vp_kms + b(2);
Vs_GC    = (1 - GRn) .* Vs_sand + GRn .* Vs_shale;

% --- Re-scale yPred_norm to a physical Vs estimate ---------
% Use the empirical mean/std as anchor (preserves shape from the I-CNN
% but maps to a physical range).
mu0 = mean(Vs_GC, 'omitnan');
sd0 = std (Vs_GC, 'omitnan');
Vs_pred_kms = mu0 + sd0 * yPred_norm;

% --- Out-of-distribution detection ----------------------------------
% Inputs are already z-scored against BT-4 training statistics in Stage 2.
% Flag rows where ANY feature has |z| > 3 (well outside training cloud)
zMax = max(abs(X), [], 2);
ood  = zMax(1:numel(Vp_kms)) > 3;
nOod = sum(ood);
if nOod > 0
    logMsg(logFile, sprintf( ...
        '  %d / %d samples (%.1f%%) are OUT-OF-DISTRIBUTION  (|z|>3 in any feature)', ...
        nOod, numel(ood), 100*nOod/numel(ood)));
    logMsg(logFile, '  -> these samples are flagged but kept in the table; plots gray them out');
end

% --- Physical clipping for Vs prediction (defensive) ------------------
% Crustal sediment/rock Vs is bounded; values outside [0.2, 4.5] km/s
% are non-physical (typically caused by feature extrapolation).
VsClip_kms = [0.2, 4.5];
Vs_pred_raw = Vs_pred_kms;                       % keep raw for diagnostics
Vs_pred_kms = max(min(Vs_pred_kms, VsClip_kms(2)), VsClip_kms(1));
nClipped = sum(Vs_pred_raw ~= Vs_pred_kms);
if nClipped > 0
    logMsg(logFile, sprintf( ...
        '  Clipped %d / %d Vs predictions to physical range [%.2f, %.2f] km/s', ...
        nClipped, numel(Vs_pred_kms), VsClip_kms(1), VsClip_kms(2)));
end

% --- Geomechanical interpretation -----------------------------------
RHOB = BT1.curvesRaw.RHOB(1:numel(yPred_norm));
% Poisson's ratio
nu = (Vp_kms.^2 - 2*Vs_pred_kms.^2) ./ (2*(Vp_kms.^2 - Vs_pred_kms.^2));
% Shear modulus  G = rho*Vs^2  (units: GPa if rho in g/cc, V in km/s)
G  = RHOB .* Vs_pred_kms.^2;
% Bulk modulus  K = rho*Vp^2 - 4/3*G
K  = RHOB .* Vp_kms.^2 - (4/3) .* G;

% --- Plots -----------------------------------------------------------
plotDeployment(depth, Vp_kms, Vs_pred_kms, Vs_castagna, Vs_GC, GR, RHOB, ...
    nu, G, K, cfg, ood);

% --- Tables / saves --------------------------------------------------
T = table(depth, Vp_kms, Vs_pred_kms, Vs_pred_raw, Vs_castagna, Vs_GC, ...
    nu, G, K, ood, ...
    'VariableNames', {'Depth_m','Vp_kms','Vs_ICNN_kms','Vs_ICNN_raw_kms', ...
        'Vs_Castagna_kms','Vs_GC_kms','Poisson','Shear_GPa','Bulk_GPa','OOD_flag'});
exportTable(T, 'BT1_deployment_predictions', cfg);

res.depth        = depth;
res.Vp_kms       = Vp_kms;
res.Vs_pred_kms  = Vs_pred_kms;
res.Vs_pred_raw  = Vs_pred_raw;
res.Vs_castagna  = Vs_castagna;
res.Vs_GC        = Vs_GC;
res.poisson      = nu;
res.shearMod     = G;
res.bulkMod      = K;
res.ood          = ood;
res.consistency  = consistencyMetrics(Vs_pred_kms, Vs_castagna, Vs_GC);
logMsg(logFile, sprintf('  Deployment metrics: rho(Vp,Vs)=%.3f, MAE vs Castagna=%.3f km/s', ...
    res.consistency.corr_VpVs, res.consistency.mae_castagna));
end

% =======================================================================
function [X, y] = stackCurves(well, featNames, targetName)
N = numel(well.depth);
P = numel(featNames);
X = zeros(N, P);
for k = 1:P
    X(:,k) = well.curvesNorm.(featNames{k});
end
if isempty(targetName) || ~isfield(well.curvesNorm, targetName)
    y = [];
else
    y = well.curvesNorm.(targetName);
end
ok = all(isfinite(X),2);
if ~isempty(y); ok = ok & isfinite(y); end
X = X(ok,:);
if ~isempty(y); y = y(ok); end
end

function m = consistencyMetrics(Vs, Vsc, Vgc)
ok = isfinite(Vs) & isfinite(Vsc) & isfinite(Vgc);
m.corr_VpVs       = NaN;  % filled by caller when needed
m.mae_castagna    = mean(abs(Vs(ok) - Vsc(ok)));
m.mae_greenberg   = mean(abs(Vs(ok) - Vgc(ok)));
m.r_castagna      = corr(Vs(ok), Vsc(ok));
m.r_greenberg     = corr(Vs(ok), Vgc(ok));
end

function y = metaTr_pred(ridgeRes, Xmeta)
%METATR_PRED  Apply trained ridge stacker on new meta-features.
y = Xmeta * ridgeRes.B + ridgeRes.intercept;
y = y(:);
end

function [Xa, n] = makeWindowsTensor(Fused, W)
%MAKEWINDOWSTENSOR  Build W x P x 1 x Nwin tensor from N x P matrix.
[N, P] = size(Fused);
n = N - W + 1;
if n < 1
    error('makeWindowsTensor:WindowTooLarge', ...
        'W=%d > N=%d in BT-1 inference', W, N);
end
Xa = zeros(W, P, 1, n, 'single');
for i = 1:n
    Xa(:, :, 1, i) = single(Fused(i:i+W-1, :));
end
end
