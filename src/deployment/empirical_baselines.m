function baselines = empirical_baselines(Vp_kms, cfg)
% EMPIRICAL_BASELINES — compute Castagna and Greenberg-Castagna Vs estimates.
%   Returns struct with fields .castagna, .gc_shale, .gc_sand, .gc_limestone
%   Author: RCW (2026-06)

c = cfg.empirical;
baselines.castagna     = c.castagna.a     * Vp_kms + c.castagna.b;
baselines.gc_shale     = c.gc_shale.a     * Vp_kms + c.gc_shale.b;
baselines.gc_sand      = c.gc_sand.a      * Vp_kms + c.gc_sand.b;
baselines.gc_limestone = c.gc_limestone.a * Vp_kms.^2 + ...
                         c.gc_limestone.b * Vp_kms + c.gc_limestone.c;
end
