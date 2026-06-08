function [nu, G, K] = compute_geomechanics(Vs_kms, Vp_kms, rho_gcc)
% COMPUTE_GEOMECHANICS — Poisson's ratio, shear modulus, bulk modulus.
%   Author: RCW (2026-06)

Vp2 = Vp_kms .^ 2;
Vs2 = Vs_kms .^ 2;
nu = (Vp2 - 2*Vs2) ./ (2 * (Vp2 - Vs2) + 1e-12);
G  = rho_gcc .* Vs2;
K  = rho_gcc .* Vp2 - (4/3) * G;
end
