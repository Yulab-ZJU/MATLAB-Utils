function exportFigure2PDF(figHandle, filename, width_mm, height_mm, opts)
%EXPORTFIGURE2PDF
% Export PDF using exportgraphics.
%
% Two adjustment modes are supported:
%
%   adjustPositionType = "TightInset"  (default, legacy behavior)
%       AFTER removing surrounding blank margins, the union boundary of all
%       layout contents expanded by TightInset has final size
%       [width_mm, height_mm] in mm. This keeps the exported PDF content box
%       fixed, but axes plot-box lengths can vary when tick labels/xlabel/
%       ylabel/title are different.
%
%   adjustPositionType = "Position"
%       The union boundary of all top-level layout Position boxes is scaled
%       to [width_mm, height_mm] in mm. Then the figure canvas is expanded
%       adaptively and top-level layout objects are shifted so that tick
%       labels/xlabel/ylabel/title remain visible. This keeps axes plot-box
%       lengths consistent across figures with different label extents.
%
% TILEDLAYOUT SUPPORT:
%   Top-level layout containers, including tiledlayout, are resized as a
%   whole. Axes inside tiledlayout are not individually repositioned.
%   Their positions are measured recursively in figure coordinates only for
%   boundary calculation. Thus, tile arrangement, spacing, padding, and
%   spanning tiles are preserved.
%
% NOTICE:
%   Images created with `imagesc` are compressed when exported to PDF in
%   R2025a and later versions. Please use `mu.image` for better performance.
%
% Boundary per axes in TightInset mode:
%   p  = absolute axes Position in figure coordinates;
%   ti = axes TightInset converted to the same absolute units;
%
%   L = p(1) - ti(1);
%   B = p(2) - ti(2);
%   R = p(1) + p(3) + ti(3);
%   T = p(2) + p(4) + ti(4);
%
% In Position mode, the target size refers to the union of the Position
% boxes of top-level layout objects. For a tiledlayout figure, this normally
% means the tiledlayout Position box rather than each individual tile.

% ---- Parameters ----
arguments
    figHandle       (1,1) matlab.ui.Figure
    filename        {mustBeTextScalar}
    width_mm        (1,1) double {mustBePositive}
    height_mm       (1,1) double {mustBePositive}
    opts.expandMode {mustBeTextScalar} = "fixed"
    opts.adjustOpt  = "on"
    opts.adjustPositionType {mustBeTextScalar} = "TightInset"
    opts.tol        (1,1) double {mustBeNonnegative} = 1e-3
    opts.maxIter    (1,1) double {mustBePositive, mustBeInteger} = 100
end

expandMode = validatestring(opts.expandMode, ...
    {'fixed', ...
     'keepratio-width', ...
     'keepratio-height', ...
     'keepratio-min', ...
     'keepratio-max'});

adjustOpt = mu.OptionState.create(opts.adjustOpt).toLogical;

adjustPositionType = validatestring(opts.adjustPositionType, ...
    {'TightInset','Position','tightinset','position'});
adjustPositionType = lower(string(adjustPositionType));

tol = opts.tol;
maxIter = opts.maxIter;

% ---- Copy a new figure ----
tempFig = copyobj(figHandle, 0);
cleanupObj = onCleanup(@() local_closeIfValid(tempFig)); %#ok<NASGU>

% Avoid transient layout calculations while the figure is being adjusted.
tempFig.Visible = "off";

drawnow;
drawnow limitrate;

% ---- Treat [w h] as the whole figure size ----
if ~adjustOpt
    W_cm = width_mm / 10;
    H_cm = height_mm / 10;

    local_setFigureSize(tempFig, W_cm, H_cm);
    local_disableToolbars(tempFig);

    drawnow;

    exportgraphics(tempFig, filename, ...
        'ContentType', 'vector', ...
        'BackgroundColor', 'none', ...
        'Colorspace', 'rgb', ...
        'Resolution', 600);

    fprintf('============== PDF Exporting ==============\n');
    fprintf('Adjustment: off\n');
    fprintf('Final paper size: %.3g x %.3g cm\n', W_cm, H_cm);
    fprintf('PDF file exported to: %s\n', mu.getabspath(filename));
    fprintf('================== Done ===================\n');
    return;
end

% ---- Find top-level layout objects ----
%
% Only these objects are moved or scaled. If a top-level object is a
% tiledlayout, its internal axes remain controlled by the layout manager.
layoutRoots = local_getLayoutRoots(tempFig);

if isempty(layoutRoots)
    error('exportFigure2PDF:NoLayoutChildren', ...
        ['No top-level layout objects with writable Units and Position ' ...
         'properties were found in the figure.']);
end

% Store all root Position boxes in absolute figure coordinates.
rootPos_cm = local_getRootPositions(layoutRoots, tempFig, "centimeters");

% ---- Determine initial reference box ----
switch adjustPositionType
    case "tightinset"
        % Measure axes, colorbars, legends, and other visible position
        % objects recursively in figure coordinates.
        [bBox, WBox, HBox] = local_getContentBorderBox( ...
            tempFig, layoutRoots, "centimeters");

    case "position"
        % Position mode uses only the top-level layout boxes. A tiledlayout
        % is consequently treated as one intact layout unit.
        [bBox, WBox, HBox] = local_getBoxUnion(rootPos_cm);

    otherwise
        error("Invalid adjustPositionType: %s.", adjustPositionType);
end

if WBox <= 0 || HBox <= 0 || ~all(isfinite([WBox, HBox]))
    error('exportFigure2PDF:InvalidLayoutBox', ...
        'The measured layout boundary has invalid width or height.');
end

whRatioBox = WBox / HBox;
whRatioPDF = width_mm / height_mm;

% Normalize root Position boxes to the selected reference boundary.
rootPosNorm = rootPos_cm;
rootPosNorm(:, 1) = (rootPosNorm(:, 1) - bBox(1)) / WBox;
rootPosNorm(:, 2) = (rootPosNorm(:, 2) - bBox(2)) / HBox;
rootPosNorm(:, 3) = rootPosNorm(:, 3) / WBox;
rootPosNorm(:, 4) = rootPosNorm(:, 4) / HBox;

% ---- Decide target box size ----
switch expandMode
    case 'fixed'
        W_mm = width_mm;
        H_mm = height_mm;

    case 'keepratio-width'
        W_mm = width_mm;
        H_mm = width_mm / whRatioBox;

    case 'keepratio-height'
        W_mm = height_mm * whRatioBox;
        H_mm = height_mm;

    case 'keepratio-min'
        if whRatioPDF > 1
            W_mm = height_mm * whRatioBox;
            H_mm = height_mm;
        else
            W_mm = width_mm;
            H_mm = width_mm / whRatioBox;
        end

    case 'keepratio-max'
        if whRatioPDF < 1
            W_mm = height_mm * whRatioBox;
            H_mm = height_mm;
        else
            W_mm = width_mm;
            H_mm = width_mm / whRatioBox;
        end
end

% Convert to centimeters.
W_cm = W_mm / 10;
H_cm = H_mm / 10;

% Set both screen and paper sizes. exportgraphics depends on the rendered
% figure canvas rather than PaperSize alone.
local_setFigureSize(tempFig, W_cm, H_cm);

% Place top-level roots according to normalized layout geometry.
local_setRootPositions(layoutRoots, rootPosNorm, W_cm, H_cm);

drawnow;
drawnow limitrate;

% ---- Adjustment according to selected position type ----
switch adjustPositionType
    case "tightinset"
        % Shrink/move top-level layout roots until the recursively measured
        % TightInset-expanded content box fits within [W_cm, H_cm].
        %
        % For tiledlayout, only the tiledlayout Position is changed. Axes
        % inside it retain their relative tile positions.

        n = 0;

        for iter = 1:maxIter
            n = iter;

            [bBoxNow, WBoxNow, HBoxNow] = ...
                local_getContentBorderBox(tempFig, layoutRoots, "centimeters");

            excessX = (WBoxNow - W_cm) / W_cm;
            excessY = (HBoxNow - H_cm) / H_cm;

            leftOverflow   = max(0, -bBoxNow(1));
            bottomOverflow = max(0, -bBoxNow(2));
            rightOverflow  = max(0, bBoxNow(3) - W_cm);
            topOverflow    = max(0, bBoxNow(4) - H_cm);

            if excessX <= tol && excessY <= tol && ...
               leftOverflow / W_cm <= tol && ...
               bottomOverflow / H_cm <= tol && ...
               rightOverflow / W_cm <= tol && ...
               topOverflow / H_cm <= tol
                break;
            end

            scaleFactorX = 1;
            scaleFactorY = 1;

            if excessX > tol
                scaleFactorX = W_cm / WBoxNow;
            end

            if excessY > tol
                scaleFactorY = H_cm / HBoxNow;
            end

            % Avoid overshooting because TightInset may not scale linearly
            % with the layout size, particularly for text and tiledlayout.
            scaleFactorX = min(1, max(0.05, scaleFactorX));
            scaleFactorY = min(1, max(0.05, scaleFactorY));

            rootPosNow = local_getRootPositions( ...
                layoutRoots, tempFig, "centimeters");

            % Scale roots about the lower-left corner of the measured box.
            rootPosNow(:, 1) = ...
                bBoxNow(1) + (rootPosNow(:, 1) - bBoxNow(1)) * scaleFactorX;
            rootPosNow(:, 2) = ...
                bBoxNow(2) + (rootPosNow(:, 2) - bBoxNow(2)) * scaleFactorY;
            rootPosNow(:, 3) = rootPosNow(:, 3) * scaleFactorX;
            rootPosNow(:, 4) = rootPosNow(:, 4) * scaleFactorY;

            local_assignAbsoluteRootPositions( ...
                layoutRoots, rootPosNow, tempFig, "centimeters");

            drawnow;
            drawnow limitrate;

            % Shift all root objects together so that left and bottom
            % labels remain inside the figure.
            [bBoxNow, ~, ~] = local_getContentBorderBox( ...
                tempFig, layoutRoots, "centimeters");

            shiftX = max(0, -bBoxNow(1));
            shiftY = max(0, -bBoxNow(2));

            if shiftX > 0 || shiftY > 0
                local_shiftRoots(layoutRoots, tempFig, ...
                    shiftX, shiftY, "centimeters");

                drawnow;
                drawnow limitrate;
            end
        end

        [bBoxFinal, WBoxFinal, HBoxFinal] = ...
            local_getContentBorderBox(tempFig, layoutRoots, "centimeters");

        finalPaperW_cm = W_cm;
        finalPaperH_cm = H_cm;
        reservedMargins_cm = [0, 0, 0, 0];

    case "position"
        % Keep the top-level Position union at [W_cm, H_cm], then expand
        % the figure canvas to reserve space for labels and tick labels.
        %
        % A tiledlayout remains one intact root object. Its tile geometry is
        % not individually rescaled.

        n = 1;

        [tightBox0, ~, ~] = local_getContentBorderBox( ...
            tempFig, layoutRoots, "centimeters");

        reservedMargins_cm = [ ...
            max(0, -tightBox0(1)), ...
            max(0, -tightBox0(2)), ...
            max(0,  tightBox0(3) - W_cm), ...
            max(0,  tightBox0(4) - H_cm)];

        finalPaperW_cm = ...
            W_cm + reservedMargins_cm(1) + reservedMargins_cm(3);
        finalPaperH_cm = ...
            H_cm + reservedMargins_cm(2) + reservedMargins_cm(4);

        % Expand both rendered figure canvas and paper.
        local_setFigureSize(tempFig, finalPaperW_cm, finalPaperH_cm);

        % Keep root object sizes unchanged. Only shift them right/up by the
        % left and bottom reserved margins.
        local_shiftRoots(layoutRoots, tempFig, ...
            reservedMargins_cm(1), ...
            reservedMargins_cm(2), ...
            "centimeters");

        drawnow;
        drawnow limitrate;

        [bBoxFinal, WBoxFinal, HBoxFinal] = ...
            local_getContentBorderBox(tempFig, layoutRoots, "centimeters");
end

% ---- Disable axes toolbars to avoid exporting them ----
local_disableToolbars(tempFig);

drawnow;
drawnow limitrate;

% ---- Export with exportgraphics ----
exportgraphics(tempFig, filename, ...
    'ContentType', 'vector', ...
    'BackgroundColor', 'none', ...
    'Colorspace', 'rgb', ...
    'Resolution', 600);

fprintf('============== PDF Exporting ==============\n');
fprintf('adjustPositionType: %s\n', adjustPositionType);
fprintf('PDF exporting: Iter=%d, tol=%.3g, w_diff=%.3g, h_diff=%.3g\n', ...
    n, tol, ...
    (WBoxFinal - finalPaperW_cm) / finalPaperW_cm, ...
    (HBoxFinal - finalPaperH_cm) / finalPaperH_cm);

if adjustPositionType == "position"
    fprintf('Position target size: %.3g x %.3g cm\n', W_cm, H_cm);
    fprintf(['Adaptive reserved margins [L B R T]: ' ...
             '[%.3g %.3g %.3g %.3g] cm\n'], ...
        reservedMargins_cm(1), ...
        reservedMargins_cm(2), ...
        reservedMargins_cm(3), ...
        reservedMargins_cm(4));
end

fprintf('Final content boundary [L B R T]: [%.3g %.3g %.3g %.3g] cm\n', ...
    bBoxFinal(1), bBoxFinal(2), bBoxFinal(3), bBoxFinal(4));
fprintf('Final paper size: %.3g x %.3g cm\n', ...
    finalPaperW_cm, finalPaperH_cm);
fprintf('PDF file exported to: %s\n', mu.getabspath(filename));
fprintf('================== Done ===================\n');

return;
end

%% Helper functions

function layoutRoots = local_getLayoutRoots(figHandle)
% Return top-level objects that define the figure layout.
%
% A tiledlayout is returned as one root. Axes inside it are deliberately
% excluded because their Position is managed by the layout container.

children = figHandle.Children;
keep = false(size(children));

for k = 1:numel(children)
    h = children(k);

    keep(k) = ...
        isgraphics(h) && ...
        isprop(h, "Units") && ...
        isprop(h, "Position") && ...
        local_isWritableProperty(h, "Units") && ...
        local_isWritableProperty(h, "Position");
end

layoutRoots = children(keep);
end

function tf = local_isWritableProperty(obj, propName)
tf = false;

try
    mc = metaclass(obj);
    p = findobj(mc.PropertyList, "Name", propName);

    if isempty(p)
        return;
    end

    tf = ~p.SetAccess == "private";
catch
    % Some graphics objects do not expose useful metaclass information.
    try
        oldValue = obj.(propName);
        obj.(propName) = oldValue;
        tf = true;
    catch
        tf = false;
    end
end
end

function local_setFigureSize(figHandle, width_cm, height_cm)
figHandle.Units = "centimeters";

figPos = figHandle.Position;
figHandle.Position = [figPos(1), figPos(2), width_cm, height_cm];

figHandle.PaperUnits = "centimeters";
figHandle.PaperPositionMode = "manual";
figHandle.PaperPosition = [0, 0, width_cm, height_cm];
figHandle.PaperSize = [width_cm, height_cm];
end

function posAll = local_getRootPositions(layoutRoots, figHandle, units)
% Return root Position boxes in absolute figure coordinates.

nRoot = numel(layoutRoots);
posAll = zeros(nRoot, 4);

for k = 1:nRoot
    posAll(k, :) = local_getAbsolutePosition( ...
        layoutRoots(k), figHandle, units);
end
end

function local_setRootPositions(layoutRoots, posNorm, W, H)
% Set roots from normalized geometry relative to the figure.

for k = 1:numel(layoutRoots)
    root = layoutRoots(k);

    oldUnits = root.Units;
    root.Units = "normalized";

    root.Position = [ ...
        posNorm(k, 1), ...
        posNorm(k, 2), ...
        posNorm(k, 3), ...
        posNorm(k, 4)];

    root.Units = oldUnits;
end

% W and H are intentionally unused here. The normalized root positions are
% relative to the resized figure canvas.
if nargin < 4 %#ok<*ISMT>
    return;
end
end

function local_assignAbsoluteRootPositions(layoutRoots, posAll, figHandle, units)
% Assign root boxes specified in absolute figure coordinates.

for k = 1:numel(layoutRoots)
    local_setAbsolutePosition(layoutRoots(k), posAll(k, :), ...
        figHandle, units);
end
end

function local_shiftRoots(layoutRoots, figHandle, dx, dy, units)
% Shift all top-level layout roots together.

posAll = local_getRootPositions(layoutRoots, figHandle, units);
posAll(:, 1) = posAll(:, 1) + dx;
posAll(:, 2) = posAll(:, 2) + dy;

local_assignAbsoluteRootPositions(layoutRoots, posAll, figHandle, units);
end

function [bBox, WBox, HBox] = local_getContentBorderBox( ...
    figHandle, layoutRoots, units)
% Recursively measure visible layout content in absolute figure coordinates.
%
% Axes use TightInset. Colorbar, legend, and other Position-based objects use
% their absolute Position boxes. Top-level layout roots are used as fallback
% when no measurable descendants are found.

objects = local_collectMeasurementObjects(layoutRoots);

boxAll = zeros(0, 4);

for k = 1:numel(objects)
    h = objects(k);

    try
        pos = local_getAbsolutePosition(h, figHandle, units);
    catch
        continue;
    end

    if ~all(isfinite(pos)) || pos(3) < 0 || pos(4) < 0
        continue;
    end

    inset = zeros(1, 4);

    if local_isAxesLike(h)
        inset = local_getAbsoluteTightInset(h, units);
    elseif strcmpi(local_getType(h), "colorbar")
        inset = local_getColorbarLabelInsetAbsolute( ...
            h, figHandle, units);
    end

    boxAll(end + 1, :) = [ ... %#ok<AGROW>
        pos(1) - inset(1), ...
        pos(2) - inset(2), ...
        pos(1) + pos(3) + inset(3), ...
        pos(2) + pos(4) + inset(4)];
end

if isempty(boxAll)
    rootPos = local_getRootPositions(layoutRoots, figHandle, units);
    [bBox, WBox, HBox] = local_getBoxUnion(rootPos);
    return;
end

bBox = [ ...
    min(boxAll(:, 1)), ...
    min(boxAll(:, 2)), ...
    max(boxAll(:, 3)), ...
    max(boxAll(:, 4))];

WBox = bBox(3) - bBox(1);
HBox = bBox(4) - bBox(2);
end

function objects = local_collectMeasurementObjects(layoutRoots)
% Recursively collect axes, legend, colorbar, and other positioned objects.
%
% Nested tiledlayout containers themselves are not used as final measurement
% boxes when measurable descendants exist.

objects = gobjects(0);

for rIndex = 1:numel(layoutRoots)
    root = layoutRoots(rIndex);
    descendants = findall(root);

    for k = 1:numel(descendants)
        h = descendants(k);

        if h == root && local_isLayoutContainer(h)
            continue;
        end

        if ~isprop(h, "Position") || ~isprop(h, "Units")
            continue;
        end

        if ~local_isVisible(h)
            continue;
        end

        typeName = local_getType(h);

        isRelevant = ...
            local_isAxesLike(h) || ...
            strcmpi(typeName, "legend") || ...
            strcmpi(typeName, "colorbar") || ...
            strcmpi(typeName, "uipanel") || ...
            strcmpi(typeName, "uitab");

        if isRelevant
            objects(end + 1, 1) = h; %#ok<AGROW>
        end
    end
end

if isempty(objects)
    objects = layoutRoots(:);
else
    objects = unique(objects, "stable");
end
end

function tf = local_isAxesLike(h)
tf = isa(h, "matlab.graphics.axis.Axes") || ...
     isa(h, "matlab.graphics.axis.PolarAxes") || ...
     isa(h, "matlab.graphics.axis.GeographicAxes");
end

function tf = local_isLayoutContainer(h)
className = class(h);

tf = contains(className, "TiledChartLayout") || ...
     contains(className, "GridLayout") || ...
     strcmpi(local_getType(h), "tiledlayout");
end

function tf = local_isVisible(h)
tf = true;

try
    tf = strcmpi(string(h.Visible), "on");
catch
end
end

function typeName = local_getType(h)
typeName = "";

try
    typeName = string(h.Type);
catch
    typeName = string(class(h));
end
end

function pos = local_getAbsolutePosition(h, figHandle, units)
% Convert an object's Position into absolute figure coordinates.
%
% getpixelposition(..., true) recursively resolves the position through
% parent containers, including tiledlayout and nested panels.

pixelPos = getpixelposition(h, true);

switch lower(string(units))
    case "pixels"
        pos = pixelPos;

    case "centimeters"
        scale = local_pixelToCentimeterScale(figHandle);
        pos = pixelPos * scale;

    case "inches"
        scale = 1 / local_getPixelsPerInch(figHandle);
        pos = pixelPos * scale;

    otherwise
        error("Unsupported absolute unit: %s.", units);
end
end

function local_setAbsolutePosition(h, pos, figHandle, units)
% Set a top-level layout root from absolute figure coordinates.
%
% This helper is intentionally used only for top-level roots. Axes inside a
% tiledlayout are never passed here.

switch lower(string(units))
    case "pixels"
        pixelPos = pos;

    case "centimeters"
        pixelPos = pos / local_pixelToCentimeterScale(figHandle);

    case "inches"
        pixelPos = pos * local_getPixelsPerInch(figHandle);

    otherwise
        error("Unsupported absolute unit: %s.", units);
end

parent = h.Parent;

if isa(parent, "matlab.ui.Figure")
    figPixelPos = getpixelposition(figHandle);
    parentWidth = figPixelPos(3);
    parentHeight = figPixelPos(4);

    oldUnits = h.Units;
    h.Units = "normalized";

    h.Position = [ ...
        pixelPos(1) / parentWidth, ...
        pixelPos(2) / parentHeight, ...
        pixelPos(3) / parentWidth, ...
        pixelPos(4) / parentHeight];

    h.Units = oldUnits;
    return;
end

% Fallback for roots whose parent is not directly the figure.
parentPixelPos = getpixelposition(parent, true);

oldUnits = h.Units;
h.Units = "normalized";

h.Position = [ ...
    (pixelPos(1) - parentPixelPos(1)) / parentPixelPos(3), ...
    (pixelPos(2) - parentPixelPos(2)) / parentPixelPos(4), ...
    pixelPos(3) / parentPixelPos(3), ...
    pixelPos(4) / parentPixelPos(4)];

h.Units = oldUnits;
end

function inset = local_getAbsoluteTightInset(ax, units)
% Return TightInset in absolute physical units.

oldUnits = ax.Units;
cleanupObj = onCleanup(@() set(ax, "Units", oldUnits)); %#ok<NASGU>

ax.Units = "pixels";
insetPixels = ax.TightInset;

figHandle = ancestor(ax, "figure");

switch lower(string(units))
    case "pixels"
        inset = insetPixels;

    case "centimeters"
        inset = insetPixels * local_pixelToCentimeterScale(figHandle);

    case "inches"
        inset = insetPixels / local_getPixelsPerInch(figHandle);

    otherwise
        error("Unsupported absolute unit: %s.", units);
end
end

function inset = local_getColorbarLabelInsetAbsolute(cb, figHandle, units)
% Estimate colorbar label overflow in absolute figure coordinates.
%
% The colorbar itself is already included through its Position box. This
% function adds only the part of its label extending beyond that box.

inset = zeros(1, 4);

try
    cbPos = local_getAbsolutePosition(cb, figHandle, units);

    label = cb.Label;
    oldLabelUnits = label.Units;
    cleanupObj = onCleanup(@() set(label, "Units", oldLabelUnits)); %#ok<NASGU>

    label.Units = "pixels";
    labelExtentPixels = label.Extent;

    switch lower(string(units))
        case "pixels"
            extentScale = 1;

        case "centimeters"
            extentScale = local_pixelToCentimeterScale(figHandle);

        case "inches"
            extentScale = 1 / local_getPixelsPerInch(figHandle);

        otherwise
            extentScale = 1;
    end

    labelExtent = labelExtentPixels * extentScale;

    % The exact label origin depends on colorbar orientation and MATLAB
    % version. Width/height overflow is estimated conservatively.
    if cbPos(4) >= cbPos(3)
        % Vertical colorbar: label normally extends left or right.
        extraWidth = max(0, labelExtent(3));

        if contains(lower(string(cb.Location)), "west")
            inset(1) = extraWidth;
        else
            inset(3) = extraWidth;
        end
    else
        % Horizontal colorbar: label normally extends above or below.
        extraHeight = max(0, labelExtent(4));

        if contains(lower(string(cb.Location)), "south")
            inset(2) = extraHeight;
        else
            inset(4) = extraHeight;
        end
    end
catch
    inset = zeros(1, 4);
end
end

function [bBox, WBox, HBox] = local_getBoxUnion(posAll)
% Get union boundary from [x y w h] boxes.

if isempty(posAll)
    error('exportFigure2PDF:EmptyPositionList', ...
        'Cannot calculate a union boundary from an empty position list.');
end

boxAll = [ ...
    posAll(:, 1), ...
    posAll(:, 2), ...
    posAll(:, 1) + posAll(:, 3), ...
    posAll(:, 2) + posAll(:, 4)];

bBox = [ ...
    min(boxAll(:, 1)), ...
    min(boxAll(:, 2)), ...
    max(boxAll(:, 3)), ...
    max(boxAll(:, 4))];

WBox = bBox(3) - bBox(1);
HBox = bBox(4) - bBox(2);
end

function scale = local_pixelToCentimeterScale(figHandle)
scale = 2.54 / local_getPixelsPerInch(figHandle);
end

function ppi = local_getPixelsPerInch(~)
try
    ppi = double(groot.ScreenPixelsPerInch);
catch
    ppi = 96;
end

if isempty(ppi) || ~isfinite(ppi) || ppi <= 0
    ppi = 96;
end
end

function local_disableToolbars(figHandle)
axesAll = findall(figHandle, "-property", "Toolbar");

for k = 1:numel(axesAll)
    try
        if ~isempty(axesAll(k).Toolbar)
            axesAll(k).Toolbar.Visible = "off";
        end
    catch
    end
end
end

function local_closeIfValid(figHandle)
if ~isempty(figHandle) && isvalid(figHandle)
    close(figHandle);
end
end