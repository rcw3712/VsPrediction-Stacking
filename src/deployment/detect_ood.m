function ood_flag = detect_ood(X_z, zthresh)
% DETECT_OOD — per-row |z| > zthresh on ANY feature → OOD
%   Author: RCW (2026-06)

z_max = max(abs(X_z), [], 2);
ood_flag = z_max > zthresh;
end
