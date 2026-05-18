function plotDeployment(depth, Vp, Vs, Vsc, Vgc, GR, RHOB, nu, G, K, cfg, ood)
%PLOTDEPLOYMENT  Multi-panel publication figure for BT-1 deployment.
%
%   Robust against extreme/unphysical values: any plot section is wrapped
%   in try/catch so that one failure does not block the rest. Inputs Vs,
%   nu, G, K are clipped to physical ranges for display; raw values are
%   kept in the table export.
%
%   Inputs (all column vectors, identical length):
%     depth        - depth in m
%     Vp, Vs, Vsc  - velocities in km/s (model, Castagna)
%     Vgc          - Greenberg-Castagna Vs
%     GR, RHOB     - feature curves
%     nu, G, K     - Poisson, shear (GPa), bulk (GPa)
%     cfg          - pipeline config
%     ood          - (optional) logical [N x 1], true where the row is
%                    out-of-distribution from the training set

if nargin < 12 || isempty(ood); ood = false(size(depth)); end

% --- Physical clipping ranges (for display only) ----------------------
VsClip   = [0.2 , 4.5];     % km/s — physically reasonable crustal Vs
VpClip   = [1.5 , 6.5];     % km/s
nuClip   = [0   , 0.5];
GClip    = [0   ,  60];     % GPa
KClip    = [0   , 100];     % GPa

VsDisp  = clipVec(Vs , VsClip);
VscDisp = clipVec(Vsc, VsClip);
VgcDisp = clipVec(Vgc, VsClip);
VpDisp  = clipVec(Vp , VpClip);
nuDisp  = clipVec(nu , nuClip);
GDisp   = clipVec(G  , GClip);
KDisp   = clipVec(K  , KClip);

% =====================================================================
% FIGURE 1 - 5-track multi-track display
% =====================================================================
try
    fig = figure('Color','w','Position',[100 100 1300 750],'Visible','off');
    tl = tiledlayout(fig, 1, 5, 'Padding','compact','TileSpacing','compact');

    % Track 1: GR
    ax = nexttile(tl); plot(GR, depth, 'g-', 'LineWidth',1.0);
    addOodBand(ax, depth, ood, [0 200]);
    set(ax,'YDir','reverse');
    xlabel('GR (API)'); ylabel('Depth (m)'); title('GR'); grid on; box on;

    % Track 2: RHOB
    ax = nexttile(tl); plot(RHOB, depth, 'r-', 'LineWidth',1.0);
    addOodBand(ax, depth, ood, [1 3]);
    set(ax,'YDir','reverse');
    xlabel('RHOB (g/cc)'); title('RHOB'); grid on; box on;

    % Track 3: Vp
    ax = nexttile(tl); plot(VpDisp, depth, 'b-', 'LineWidth',1.0);
    addOodBand(ax, depth, ood, VpClip);
    set(ax,'YDir','reverse');
    xlabel('Vp (km/s)'); title('Vp'); grid on; box on; xlim(VpClip);

    % Track 4: Vs comparison
    ax = nexttile(tl); hold on;
    h1 = plot(VsDisp , depth, '-' , 'Color',[0.85 0.10 0.10], 'LineWidth',1.4);
    h2 = plot(VscDisp, depth, '--', 'Color',[0.20 0.45 0.85], 'LineWidth',1.0);
    h3 = plot(VgcDisp, depth, '-.', 'Color',[0.30 0.60 0.30], 'LineWidth',1.0);
    addOodBand(ax, depth, ood, VsClip);
    set(ax,'YDir','reverse');
    xlabel('Vs (km/s)'); xlim(VsClip);
    legend([h1 h2 h3], {'I-CNN','Castagna','Greenberg-C'}, 'Location','best');
    title('Vs comparison'); grid on; box on;

    % Track 5: Poisson
    ax = nexttile(tl); plot(nuDisp, depth, 'k-', 'LineWidth',1.0);
    addOodBand(ax, depth, ood, nuClip);
    set(ax,'YDir','reverse');
    xlabel('Poisson \nu'); title('Poisson'); grid on; box on; xlim(nuClip);

    title(tl, 'BT-1 deployment + indirect validation (gray bands = out-of-distribution)');
    savePublicationFigure(fig, 'DEP_multitrack_BT1', cfg);
    close(fig);
catch ME
    warning('plotDeployment:multitrack', 'Multi-track plot failed: %s', ME.message);
end

% =====================================================================
% FIGURE 2 - Vp-Vs crossplot with empirical lines
% =====================================================================
try
    % Mask: only IN-DISTRIBUTION samples for the crossplot scientific value
    inMask = ~ood & isfinite(Vp) & isfinite(Vs) & ...
              Vs >= VsClip(1) & Vs <= VsClip(2) & ...
              Vp >= VpClip(1) & Vp <= VpClip(2);

    fig = figure('Color','w','Position',[100 100 720 580],'Visible','off');
    ax = gca; hold(ax,'on');

    if any(inMask)
        hICNN = scatter(ax, Vp(inMask), Vs(inMask), 16, depth(inMask), ...
                        'filled', 'MarkerFaceAlpha', 0.6);
    else
        hICNN = scatter(ax, NaN, NaN, 16, 'filled');
    end
    colormap(ax, parula);
    cb = colorbar(ax); cb.Label.String = 'Depth (m)';

    % --- Empirical lines (Castagna, Greenberg-C sand & shale) ----------
    vpGrid = linspace(VpClip(1), VpClip(2), 200);

    % Castagna mudrock (1985)
    A = cfg.emp.castagna.A;   B = cfg.emp.castagna.B;
    vsCast = A*vpGrid - B;
    hCast = plot(ax, vpGrid, vsCast, '--', ...
                 'Color',[0.20 0.45 0.85], 'LineWidth',2);

    % Greenberg-Castagna sand (Han) and shale lines
    vsSand  = (0.7936*vpGrid - 0.7868);   % Han sand
    vsShale = (0.7700*vpGrid - 0.8674);   % Castagna shale
    hSand  = plot(ax, vpGrid, vsSand , ':', ...
                  'Color',[0.20 0.65 0.20], 'LineWidth',1.5);
    hShale = plot(ax, vpGrid, vsShale, ':', ...
                  'Color',[0.65 0.40 0.10], 'LineWidth',1.5);

    xlabel(ax,'Vp (km/s)'); ylabel(ax,'Vs (km/s)');
    title(ax, sprintf('Vp-Vs crossplot, BT-1 (n=%d, OOD excluded)', sum(inMask)));
    xlim(ax, VpClip); ylim(ax, VsClip);
    legend(ax, [hICNN hCast hSand hShale], ...
        {'I-CNN prediction','Castagna mudrock','Greenberg-C sand','Greenberg-C shale'}, ...
        'Location','northwest');
    grid(ax,'on'); box(ax,'on');

    savePublicationFigure(fig, 'DEP_VpVs_crossplot', cfg);
    close(fig);
catch ME
    warning('plotDeployment:crossplot', 'Crossplot failed: %s', ME.message);
end

% =====================================================================
% FIGURE 3 - Geomechanical panel
% =====================================================================
try
    fig = figure('Color','w','Position',[100 100 1050 450],'Visible','off');
    tl = tiledlayout(fig,1,3,'Padding','compact','TileSpacing','compact');

    ax = nexttile(tl); plot(nuDisp, depth, 'k-', 'LineWidth',1.0);
    addOodBand(ax, depth, ood, nuClip);
    set(ax,'YDir','reverse'); xlim(ax, nuClip);
    xlabel('Poisson \nu'); ylabel('Depth (m)'); title('Poisson ratio');
    grid on; box on;

    ax = nexttile(tl); plot(GDisp, depth, 'b-', 'LineWidth',1.0);
    addOodBand(ax, depth, ood, GClip);
    set(ax,'YDir','reverse'); xlim(ax, GClip);
    xlabel('Shear (GPa)'); title('Shear modulus G'); grid on; box on;

    ax = nexttile(tl); plot(KDisp, depth, 'r-', 'LineWidth',1.0);
    addOodBand(ax, depth, ood, KClip);
    set(ax,'YDir','reverse'); xlim(ax, KClip);
    xlabel('Bulk (GPa)'); title('Bulk modulus K'); grid on; box on;

    title(tl, 'Geomechanical properties, BT-1 (clipped to physical range)');
    savePublicationFigure(fig, 'DEP_geomechanics', cfg);
    close(fig);
catch ME
    warning('plotDeployment:geomech', 'Geomechanics plot failed: %s', ME.message);
end
end

% =======================================================================
function v = clipVec(v, range)
%CLIPVEC  Clamp values to [range(1), range(2)]; preserve NaN.
v = min(max(v, range(1)), range(2));
end

function addOodBand(ax, depth, ood, xlim_)
%ADDOODBAND  Shade depth intervals where samples are out-of-distribution.
if ~any(ood); return; end
hold(ax,'on');
% Identify contiguous OOD runs
d = depth(:); m = ood(:);
i = 1; N = numel(m);
while i <= N
    if m(i)
        j = i;
        while j <= N && m(j); j = j + 1; end
        z0 = d(i); z1 = d(min(j, N));
        patch(ax, ...
            [xlim_(1) xlim_(2) xlim_(2) xlim_(1)], ...
            [z0       z0       z1       z1      ], ...
            [0.85 0.85 0.85], 'EdgeColor','none', 'FaceAlpha',0.35);
        i = j;
    else
        i = i + 1;
    end
end
end
