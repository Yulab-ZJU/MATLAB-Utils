function exportFigure2PDF(figHandle, filename, width_mm, height_mm, opts)
%EXPORTFIGURE2PDF
% Export PDF using exportgraphics such that AFTER removing surrounding blank
% margins, the union boundary of all axes (Position expanded by TightInset)
% has final size [width_mm, height_mm] (or adjusted by expandMode) in mm.
%
% Boundary per-axes:
%   p  = ax.Position;      % [x y w h]
%   ti = ax.TightInset;    % [l b r t] relative to position
%   L = p(1) - ti(1);
%   B = p(2) - ti(2);
%   R = p(1) + p(3) + ti(3);
%   T = p(2) + p(4) + ti(4);

arguments
    figHandle       matlab.ui.Figure
    filename        {mustBeTextScalar}
    width_mm        (1,1) double {mustBePositive}
    height_mm       (1,1) double {mustBePositive}

    opts.expandMode (1,1) string = "fixed"
    opts.packBbox                = "auto"      % "auto"|true|false
    opts.Padding    (1,1) double {mustBeNonnegative} = 0
    opts.Background              = 'none'
    opts.MaxIter    (1,1) double {mustBeInteger, mustBePositive} = 4
    opts.Tol_mm     (1,1) double {mustBePositive} = 0.05
end

opts.expandMode = validatestring(opts.expandMode, ...
    {'fixed','keepratio-width','keepratio-height','keepratio-min','keepratio-max'});

% ---- clone figure ----
tempFig = copyobj(figHandle, 0);
set(tempFig, 'Visible', 'off');

% ---- find visible axes ----
axs = findall(tempFig, 'Type', 'axes');
axs = axs(strcmp({axs.Visible}, 'on'));
if isempty(axs)
    close(tempFig);
    error('exportFigure2PDF:NoAxes', 'No visible axes found in the figure.');
end

drawnow;  % ensure TightInset is up-to-date

% ============================================================
% 1) bboxRatio_phys: compute directly in CENTIMETERS
% ============================================================
[~, bboxW_cm, bboxH_cm] = local_bbox_position_tightinset_cm(axs);
bboxRatio_phys = bboxW_cm / bboxH_cm; % physical width/height in cm

% ---- apply expandMode to target size (mm) using physical bbox ratio ----
targetW_mm = width_mm;
targetH_mm = height_mm;

switch opts.expandMode
    case 'fixed'
        % keep user specified
    case 'keepratio-width'
        targetH_mm = targetW_mm / bboxRatio_phys;
    case 'keepratio-height'
        targetW_mm = targetH_mm * bboxRatio_phys;
    case 'keepratio-min'
        m = min(targetW_mm, targetH_mm);
        if bboxRatio_phys >= 1
            targetH_mm = m;
            targetW_mm = m * bboxRatio_phys;
        else
            targetW_mm = m;
            targetH_mm = m / bboxRatio_phys;
        end
    case 'keepratio-max'
        M = max(targetW_mm, targetH_mm);
        if bboxRatio_phys >= 1
            targetW_mm = M;
            targetH_mm = M / bboxRatio_phys;
        else
            targetH_mm = M;
            targetW_mm = M * bboxRatio_phys;
        end
end

targetW_cm = targetW_mm / 10;
targetH_cm = targetH_mm / 10;

% ============================================================
% 2) Decide packing (in normalized coordinates)
% ============================================================
isKeepRatioMode = startsWith(string(opts.expandMode), "keepratio");

if ischar(opts.packBbox) || isstring(opts.packBbox)
    packMode = string(opts.packBbox);
    if packMode == "auto"
        doPack = isKeepRatioMode;
    else
        error('exportFigure2PDF:BadPackMode', 'opts.packBbox must be "auto", true, or false.');
    end
elseif islogical(opts.packBbox) || isnumeric(opts.packBbox)
    doPack = logical(opts.packBbox);
else
    error('exportFigure2PDF:BadPackMode', 'opts.packBbox must be "auto", true, or false.');
end

% Compute bbox in normalized units for later solve/pack
[bbox_norm, wNorm, hNorm] = local_bbox_position_tightinset_norm(axs);

if doPack
    local_pack_axes_positions(axs, bbox_norm, wNorm, hNorm);
    drawnow;
    [bbox_norm, wNorm, hNorm] = local_bbox_position_tightinset_norm(axs); %#ok<ASGLU>
end

% ============================================================
% 3) Iteratively solve figure physical size (cm)
% ============================================================
figW_cm = targetW_cm / max(wNorm, eps);
figH_cm = targetH_cm / max(hNorm, eps);

for it = 1:opts.MaxIter
    local_set_fig_wh_cm(tempFig, figW_cm, figH_cm);
    drawnow;

    [~, w_it, h_it] = local_bbox_position_tightinset_norm(axs);

    achievedW_mm = (w_it * figW_cm) * 10;
    achievedH_mm = (h_it * figH_cm) * 10;

    if abs(achievedW_mm - targetW_mm) <= opts.Tol_mm && abs(achievedH_mm - targetH_mm) <= opts.Tol_mm
        break
    end

    figW_cm = targetW_cm / max(w_it, eps);
    figH_cm = targetH_cm / max(h_it, eps);
end

% ---- export with exportgraphics ----
args = {'ContentType', 'vector', 'BackgroundColor', opts.Background};

try
    exportgraphics(tempFig, filename, args{:}, 'Padding', opts.Padding);
catch
    exportgraphics(tempFig, filename, args{:});
end

close(tempFig);
end

% ====================== helpers ======================

function [bbox, wNorm, hNorm] = local_bbox_position_tightinset_norm(axs)
bbox = [inf inf -inf -inf]; % [L B R T] normalized
for k = 1:numel(axs)
    ax = axs(k);
    if ~isvalid(ax) || ~strcmp(ax.Visible,'on'), continue; end

    oldUnits = ax.Units;
    ax.Units = 'normalized';

    p  = get(ax, "Position");
    ti = get(ax, "TightInset"); % relative to Position

    ax.Units = oldUnits;

    if numel(p)~=4 || numel(ti)~=4 || any(~isfinite([p ti])), continue; end

    L = p(1) - ti(1);
    B = p(2) - ti(2);
    R = p(1) + p(3) + ti(3);
    T = p(2) + p(4) + ti(4);

    bbox(1) = min(bbox(1), L);
    bbox(2) = min(bbox(2), B);
    bbox(3) = max(bbox(3), R);
    bbox(4) = max(bbox(4), T);
end

wNorm = bbox(3) - bbox(1);
hNorm = bbox(4) - bbox(2);

if ~(isfinite(wNorm) && isfinite(hNorm) && wNorm > 0 && hNorm > 0)
    error('exportFigure2PDF:BadBBox', 'Failed to compute valid bbox (normalized).');
end
end

function [bbox_cm, bboxW_cm, bboxH_cm] = local_bbox_position_tightinset_cm(axs)
% Compute bbox in physical centimeters directly from axes Position/TightInset.
bbox_cm = [inf inf -inf -inf]; % [L B R T] in cm

for k = 1:numel(axs)
    ax = axs(k);
    if ~isvalid(ax) || ~strcmp(ax.Visible,'on'), continue; end

    oldUnits = ax.Units;
    ax.Units = 'centimeters';

    p  = get(ax, "Position");      % cm
    ti = get(ax, "TightInset");    % cm, relative to Position

    ax.Units = oldUnits;

    if numel(p)~=4 || numel(ti)~=4 || any(~isfinite([p ti])), continue; end

    L = p(1) - ti(1);
    B = p(2) - ti(2);
    R = p(1) + p(3) + ti(3);
    T = p(2) + p(4) + ti(4);

    bbox_cm(1) = min(bbox_cm(1), L);
    bbox_cm(2) = min(bbox_cm(2), B);
    bbox_cm(3) = max(bbox_cm(3), R);
    bbox_cm(4) = max(bbox_cm(4), T);
end

bboxW_cm = bbox_cm(3) - bbox_cm(1);
bboxH_cm = bbox_cm(4) - bbox_cm(2);

if ~(isfinite(bboxW_cm) && isfinite(bboxH_cm) && bboxW_cm > 0 && bboxH_cm > 0)
    error('exportFigure2PDF:BadBBox', 'Failed to compute valid bbox (centimeters).');
end
end

function local_pack_axes_positions(axs, bbox, wNorm, hNorm)
% Affine-map axes Position so that the union bbox becomes [0 0 1 1] in figure normalized.
L0 = bbox(1);
B0 = bbox(2);

for k = 1:numel(axs)
    ax = axs(k);
    if ~isvalid(ax) || ~strcmp(ax.Visible,'on'), continue; end

    oldUnits = ax.Units;
    ax.Units = 'normalized';

    p = ax.Position;
    pNew = [ (p(1) - L0) / wNorm, ...
             (p(2) - B0) / hNorm, ...
              p(3) / wNorm, ...
              p(4) / hNorm ];
    ax.Position = pNew;

    ax.Units = oldUnits;
end
end

function local_set_fig_wh_cm(fig, W_cm, H_cm)
old = fig.Units;
fig.Units = 'centimeters';
pos = fig.Position;
pos(3:4) = [W_cm H_cm];
fig.Position = pos;

% Keep paper consistent (helps some backends)
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0 0 W_cm H_cm];
fig.PaperSize = [W_cm H_cm];

fig.Units = old;
end
