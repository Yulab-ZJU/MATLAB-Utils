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
%       to [width_mm, height_mm].
%
%       After Position scaling is completed, the Position box is shifted by
%       the reserved left and bottom margins. The reserved margins are then
%       ADDED to the final figure/PDF size:
%
%           finalWidth  = width  + left + right
%           finalHeight = height + bottom + top
%
%       Thus, width_mm and height_mm always describe the target Position-box
%       size rather than the complete PDF page size. Tick labels, axis
%       labels, titles, legends, colorbars, and other surrounding contents
%       can occupy the additionally reserved margins without reducing or
%       clipping the target Position box.
%
%       Because exportgraphics may crop unused outer whitespace, slightly
%       overestimating the reserved margins is generally harmless.
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
% INPUTS:
%   figHandle : figure handle
%   filename  : output PDF filename
%   width_mm  : target Position-box width in millimeters
%   height_mm : target Position-box height in millimeters
%
% NAME-VALUE:
%   expandMode:
%       "fixed"             - use width_mm and height_mm directly
%       "keepratio-width"   - keep width_mm and calculate height
%       "keepratio-height"  - keep height_mm and calculate width
%       "keepratio-min"     - preserve ratio using the smaller constraint
%       "keepratio-max"     - preserve ratio using the larger constraint
%
%   adjustOpt:
%       "on"  - adjust layout boundary (default)
%       "off" - width_mm and height_mm are the complete figure size
%
%   adjustPositionType:
%       "TightInset" - fit complete visible content
%       "Position"   - preserve the requested Position-box size and add
%                      reserved margins around it
%
%   tol:
%       relative fitting tolerance in TightInset mode (default 1e-3)
%
%   maxIter:
%       maximum TightInset fitting iterations (default 100)
%
% EXAMPLES:
%   % Relative margins:
%   mu.exportFigure2PDF(gcf, "test.pdf", 100, 50, ...
%       "adjustPositionType", "Position");

% ---- Parameters ----
arguments
    figHandle       (1,1) matlab.ui.Figure
    filename        {mustBeTextScalar}
    width_mm        (1,1) double {mustBePositive}
    height_mm       (1,1) double {mustBePositive}

    opts.expandMode {mustBeTextScalar} = "fixed"
    opts.adjustOpt = "on"
    opts.adjustPositionType {mustBeTextScalar} = "TightInset"

    opts.tol     (1,1) double {mustBeNonnegative} = 1e-3
    opts.maxIter (1,1) double {mustBePositive, mustBeInteger} = 100

    opts.debug (1,1) logical = false
end

expandMode = validatestring(opts.expandMode, { ...
    'fixed', ...
    'keepratio-width', ...
    'keepratio-height', ...
    'keepratio-min', ...
    'keepratio-max'});

adjustOpt = mu.OptionState.create(opts.adjustOpt).toLogical;

adjustPositionType = validatestring(opts.adjustPositionType, { ...
    'TightInset', ...
    'Position', ...
    'tightinset', ...
    'position'});
adjustPositionType = lower(string(adjustPositionType));

% ---- Resolve incompatible options ----
if startsWith(expandMode, "keepratio") && adjustPositionType == "tightinset"
    warning("exportFigure2PDF:AdjustPositionTypeChanged", ...
        ['expandMode="%s" requires preserving Position geometry. ' ...
         'adjustPositionType has been changed from "TightInset" to "Position".'], ...
        expandMode);

    adjustPositionType = "position";
end

tol = opts.tol;
maxIter = opts.maxIter;

% Ensure source figure layout is fully updated
drawnow;

% Copy a new figure
tempFig = copyobj(figHandle, 0);
cleanupObj = onCleanup(@() local_closeIfValid(tempFig));

% Use a normal, explicitly sized window. A maximized figure can ignore
% Position updates and make pixel/physical-unit conversions inconsistent.
try
    tempFig.WindowState = "normal";
catch
end
if ~opts.debug
    tempFig.Visible = "off";
end

drawnow;

% ---- Treat [w h] as the whole figure size ----
if ~adjustOpt
    finalPaperW_cm = width_mm / 10;
    finalPaperH_cm = height_mm / 10;

    local_setFigureSize(tempFig, finalPaperW_cm, finalPaperH_cm);
    local_disableToolbars(tempFig);

    drawnow;

    exportgraphics(tempFig, filename, ...
        'ContentType', 'vector', ...
        'BackgroundColor', 'none', ...
        'Colorspace', 'rgb', ...
        'Resolution', 600);

    fprintf('============== PDF Exporting ==============\n');
    fprintf('Adjustment: off\n');
    fprintf('Final paper size: %.3g x %.3g cm\n', ...
        finalPaperW_cm, finalPaperH_cm);
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

% Store root Position boxes in absolute figure coordinates.
rootPos_cm = local_getRootPositions( ...
    layoutRoots, tempFig, "centimeters");

% ---- Determine initial reference box ----
switch adjustPositionType
    case "tightinset"
        % Measure complete visible content recursively.
        [bBox, WBox, HBox] = local_getContentBorderBox( ...
            tempFig, layoutRoots, "centimeters");

    case "position"
        % Position mode is based only on the top-level Position geometry.
        [bBox, WBox, HBox] = local_getBoxUnion(rootPos_cm);

    otherwise
        error("exportFigure2PDF:InvalidPositionType", ...
            "Invalid adjustPositionType: %s.", adjustPositionType);
end

if WBox <= 0 || HBox <= 0 || ...
        ~all(isfinite([bBox, WBox, HBox]))
    error('exportFigure2PDF:InvalidLayoutBox', ...
        'The measured layout boundary has invalid width or height.');
end

whRatioBox = WBox / HBox;
whRatioPDF = width_mm / height_mm;


% ---- Decide target Position-box size ----
% expandMode controls only Position mode. TightInset mode fits the complete
% visible boundary and therefore should not alter the requested aspect ratio.
if adjustPositionType == "tightinset"
    expandModeEffective = "fixed";
else
    expandModeEffective = expandMode;
end

switch expandModeEffective
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
        if whRatioPDF > whRatioBox
            W_mm = height_mm * whRatioBox;
            H_mm = height_mm;
        else
            W_mm = width_mm;
            H_mm = width_mm / whRatioBox;
        end

    case 'keepratio-max'
        if whRatioPDF < whRatioBox
            W_mm = height_mm * whRatioBox;
            H_mm = height_mm;
        else
            W_mm = width_mm;
            H_mm = width_mm / whRatioBox;
        end
end

% Target Position-box size in centimeters.
W_cm = W_mm / 10;
H_cm = H_mm / 10;

% Initially create a canvas equal to the requested Position-box size.
% Position mode enlarges it after the Position box has been established.
local_setFigureSize(tempFig, W_cm, H_cm);

% Place top-level roots relative to the original reference-box origin.
% Keep-ratio modes use one scalar transformation; only "fixed" may use
% different horizontal and vertical scale factors.
switch expandMode
    case 'fixed'
        scaleX = W_cm / WBox;
        scaleY = H_cm / HBox;

    otherwise
        scaleX = W_cm / WBox;
        scaleY = H_cm / HBox;

        % The two values should be identical in keep-ratio modes. Use a
        % single scalar explicitly to prevent numerical/layout drift.
        scaleUniform = min(scaleX, scaleY);
        scaleX = scaleUniform;
        scaleY = scaleUniform;
end

targetRootPos_cm = rootPos_cm;
targetRootPos_cm(:, 1) = ...
    (rootPos_cm(:, 1) - bBox(1)) * scaleX;
targetRootPos_cm(:, 2) = ...
    (rootPos_cm(:, 2) - bBox(2)) * scaleY;
targetRootPos_cm(:, 3) = rootPos_cm(:, 3) * scaleX;
targetRootPos_cm(:, 4) = rootPos_cm(:, 4) * scaleY;

local_assignAbsoluteRootPositions( ...
    layoutRoots, targetRootPos_cm, ...
    tempFig, "centimeters");

drawnow;

% ---- Adjustment according to selected position type ----
switch adjustPositionType
    case "tightinset"
        % -------------------------------------------------------------
        % TightInset mode:
        %
        % Keep an immutable reference geometry. Every iteration rebuilds
        % the root positions from that reference instead of repeatedly
        % transforming the previous iteration. The complete visible
        % boundary is then anchored at [0, 0]. This prevents cumulative
        % drift and keeps axes, legends, and colorbars together.
        % -------------------------------------------------------------

        drawnow;

        % Anchor the initial complete-content boundary at the page origin.
        [bBoxNow, ~, ~] = local_getContentBorderBox( ...
            tempFig, layoutRoots, "centimeters");

        local_shiftRoots( ...
            layoutRoots, tempFig, ...
            -bBoxNow(1), -bBoxNow(2), "centimeters");

        drawnow;

        % Immutable root geometry after initial anchoring.
        baseRootPos_cm = local_getRootPositions( ...
            layoutRoots, tempFig, "centimeters");

        cumulativeScale = 1;
        n = 0;

        for iter = 1:maxIter
            n = iter;

            % Reconstruct from the immutable geometry. Scaling both the
            % origin and size preserves every root-to-root relationship.
            rootPosNow = baseRootPos_cm * cumulativeScale;

            local_assignAbsoluteRootPositions( ...
                layoutRoots, rootPosNow, ...
                tempFig, "centimeters");

            drawnow;

            % TightInset and managed objects can change after drawnow.
            % Re-anchor the complete visible boundary at [0, 0].
            [bBoxNow, ~, ~] = local_getContentBorderBox( ...
                tempFig, layoutRoots, "centimeters");

            local_shiftRoots( ...
                layoutRoots, tempFig, ...
                -bBoxNow(1), -bBoxNow(2), "centimeters");

            drawnow;

            [~, WBoxNow, HBoxNow] = ...
                local_getContentBorderBox( ...
                    tempFig, layoutRoots, "centimeters");

            widthExcess = (WBoxNow - W_cm) / W_cm;
            heightExcess = (HBoxNow - H_cm) / H_cm;

            if widthExcess <= tol && heightExcess <= tol
                break;
            end

            % Uniformly shrink the entire layout. Text extents and
            % TightInset are not perfectly linear, so remeasure next round.
            fitScale = min([ ...
                1, ...
                W_cm / WBoxNow, ...
                H_cm / HBoxNow]);

            if ~isfinite(fitScale) || fitScale <= 0
                error('exportFigure2PDF:InvalidFitScale', ...
                    'Invalid TightInset fitting scale: %.6g.', ...
                    fitScale);
            end

            % Stop if graphics quantization leaves no meaningful progress.
            if 1 - fitScale <= 10 * eps
                break;
            end

            cumulativeScale = cumulativeScale * fitScale;
        end

        % A final draw can slightly change text extents. Anchor once more.
        [bBoxFinal, ~, ~] = local_getContentBorderBox( ...
            tempFig, layoutRoots, "centimeters");

        local_shiftRoots( ...
            layoutRoots, tempFig, ...
            -bBoxFinal(1), -bBoxFinal(2), "centimeters");

        drawnow;

        [bBoxFinal, WBoxFinal, HBoxFinal] = ...
            local_getContentBorderBox( ...
                tempFig, layoutRoots, "centimeters");

        finalPaperW_cm = W_cm;
        finalPaperH_cm = H_cm;
        reservedMargins_cm = [0, 0, 0, 0];

        if WBoxFinal > W_cm * (1 + tol) || ...
                HBoxFinal > H_cm * (1 + tol)
            warning('exportFigure2PDF:TightInsetNotConverged', ...
                ['TightInset fitting did not fully converge after %d ' ...
                 'iterations. Final content size is %.4g x %.4g cm; ' ...
                 'target is %.4g x %.4g cm.'], ...
                n, WBoxFinal, HBoxFinal, W_cm, H_cm);
        end

    case "position"
        % -------------------------------------------------------------
        % expandMode is applied only in Position mode. The Position box is
        % treated as the geometry-preserving object; margins are enlarged
        % adaptively to contain labels, legends, and colorbars.
        % Position mode:
        %
        % 1. The top-level Position union has already been scaled to
        %    [W_cm, H_cm].
        %
        % 2. Convert requested reserved margins to centimeters.
        %
        % 3. Enlarge the final figure/PaperSize by the reserved margins.
        %
        % 4. Restore the Position geometry at its original physical size,
        %    shifted right/up by [left, bottom].
        %
        % No text-based shrinking or centering is performed in this mode.
        % -------------------------------------------------------------

        n = 1;

        % Automatically estimate margins required by visible contents.
        % The Position box keeps its geometry; labels, titles, legends and
        % colorbars expand the page. exportgraphics will remove unused outer
        % whitespace during export, so a small safety factor is harmless.
        reservedMargins_cm = local_estimatePositionMargins( ...
            tempFig, layoutRoots, targetRootPos_cm);

        marginLeft   = reservedMargins_cm(1);
        marginBottom = reservedMargins_cm(2);
        marginRight  = reservedMargins_cm(3);
        marginTop    = reservedMargins_cm(4);

        finalPaperW_cm = ...
            W_cm + marginLeft + marginRight;

        finalPaperH_cm = ...
            H_cm + marginBottom + marginTop;

        % Record the already-correct target Position geometry before the
        % figure canvas is enlarged.
        targetRootPos_cm = local_getRootPositions( ...
            layoutRoots, tempFig, "centimeters");

        % Add reserved margins to the complete figure/PDF dimensions.
        local_setFigureSize( ...
            tempFig, finalPaperW_cm, finalPaperH_cm);

        % Shift the Position box by left/bottom reserves while preserving
        % its target physical width and height.
        targetRootPos_cm(:, 1) = ...
            targetRootPos_cm(:, 1) + marginLeft;

        targetRootPos_cm(:, 2) = ...
            targetRootPos_cm(:, 2) + marginBottom;

        local_assignAbsoluteRootPositions( ...
            layoutRoots, targetRootPos_cm, ...
            tempFig, "centimeters");

        drawnow;

        % Managed graphics objects, especially colorbars, may alter the
        % associated axes during drawnow. Restore the requested root
        % geometry once after the layout manager has updated.
        local_assignAbsoluteRootPositions( ...
            layoutRoots, targetRootPos_cm, ...
            tempFig, "centimeters");

        drawnow;

        % Re-anchor the final Position union at [marginLeft, marginBottom]
        % without changing its physical width, height, or aspect ratio.
        rootPosCheck_cm = local_getRootPositions( ...
            layoutRoots, tempFig, "centimeters");
        [positionBoxNow, ~, ~] = local_getBoxUnion(rootPosCheck_cm);

        local_shiftRoots( ...
            layoutRoots, tempFig, ...
            marginLeft - positionBoxNow(1), ...
            marginBottom - positionBoxNow(2), ...
            "centimeters");

        drawnow;

        [bBoxFinal, WBoxFinal, HBoxFinal] = ...
            local_getContentBorderBox( ...
                tempFig, layoutRoots, "centimeters");
end

% ---- Disable axes toolbars to avoid exporting them ----
local_disableToolbars(tempFig);

drawnow;

% ---- Final clipping safety check ----
[bBoxCheck, ~, ~] = local_getContentBorderBox( ...
    tempFig, layoutRoots, "centimeters");

if any(bBoxCheck < -opts.tol)
    warning("exportFigure2PDF:UnexpectedOverflow", ...
        "Visible content extends outside the estimated page region: [%g %g %g %g] cm.", ...
        bBoxCheck);
end

% Ensure the paper settings retain the final expanded dimensions.
tempFig.PaperUnits = "centimeters";
tempFig.PaperPositionMode = "manual";
tempFig.PaperPosition = [ ...
    0, 0, finalPaperW_cm, finalPaperH_cm];
tempFig.PaperSize = [ ...
    finalPaperW_cm, finalPaperH_cm];

% ---- Export with exportgraphics ----
exportgraphics(tempFig, filename, ...
    'ContentType', 'vector', ...
    'BackgroundColor', 'none', ...
    'Colorspace', 'rgb', ...
    'Resolution', 600);

% ---- Report ----
fprintf('============== PDF Exporting ==============\n');
fprintf('adjustPositionType: %s\n', adjustPositionType);

if adjustPositionType == "tightinset"
    fprintf(['PDF exporting: Iter=%d, tol=%.3g, ' ...
             'w_diff=%.3g, h_diff=%.3g\n'], ...
        n, ...
        tol, ...
        (WBoxFinal - finalPaperW_cm) / finalPaperW_cm, ...
        (HBoxFinal - finalPaperH_cm) / finalPaperH_cm);
else
    fprintf('Target Position-box size: %.3g x %.3g cm\n', ...
        W_cm, H_cm);

    fprintf(['Reserved margins [L B R T]: ' ...
             '[%.3g %.3g %.3g %.3g] cm\n'], ...
        reservedMargins_cm(1), ...
        reservedMargins_cm(2), ...
        reservedMargins_cm(3), ...
        reservedMargins_cm(4));
end

fprintf(['Final content boundary [L B R T]: ' ...
         '[%.3g %.3g %.3g %.3g] cm\n'], ...
    bBoxFinal(1), ...
    bBoxFinal(2), ...
    bBoxFinal(3), ...
    bBoxFinal(4));

fprintf('Final paper size: %.3g x %.3g cm\n', ...
    finalPaperW_cm, finalPaperH_cm);

fprintf('PDF file exported to: %s\n', ...
    mu.getabspath(filename));

fprintf('================== Done ===================\n');

return;
end

%% Helper functions


function margins_cm = local_estimatePositionMargins( ...
    figHandle, layoutRoots, positionBox)
% Estimate [left bottom right top] margins required by visible contents.
%
% The position box is treated as the protected plotting region. All visible
% objects outside this region are converted into additional paper margins.

    [posBox, ~, ~] = local_getBoxUnion(positionBox);

    [contentBox, ~, ~] = local_getContentBorderBox( ...
        figHandle, layoutRoots, "centimeters");

    margins_cm = [ ...
        max(0, posBox(1) - contentBox(1)), ...
        max(0, posBox(2) - contentBox(2)), ...
        max(0, contentBox(3) - posBox(3)), ...
        max(0, contentBox(4) - posBox(4))];

    % Account for renderer/font extent differences.
    margins_cm = margins_cm * 1.2;
end

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
% Determine whether a property can be assigned.
try
    oldValue = obj.(propName);
    obj.(propName) = oldValue;
    tf = true;
catch
    tf = false;
end
end

function local_setFigureSize(figHandle, width_cm, height_cm)
% Set rendered figure size and PDF paper size.

try
    figHandle.WindowState = "normal";
catch
end

oldUnits = figHandle.Units;
figHandle.Units = "centimeters";

% Use a deterministic on-screen origin. A maximized or partly off-screen
% figure can make getpixelposition and physical-unit conversion unstable.
figHandle.Position = [1, 1, width_cm, height_cm];

figHandle.Units = oldUnits;

figHandle.PaperUnits = "centimeters";
figHandle.PaperPositionMode = "manual";
figHandle.PaperPosition = [0, 0, width_cm, height_cm];
figHandle.PaperSize = [width_cm, height_cm];

drawnow;
end

function posAll = local_getRootPositions( ...
    layoutRoots, figHandle, units)
% Return root Position boxes in absolute figure coordinates.

nRoot = numel(layoutRoots);
posAll = zeros(nRoot, 4);

for k = 1:nRoot
    posAll(k, :) = local_getAbsolutePosition( ...
        layoutRoots(k), figHandle, units);
end
end

function local_assignAbsoluteRootPositions( ...
    layoutRoots, posAll, figHandle, units)
% Assign root boxes specified in absolute figure coordinates.

for k = 1:numel(layoutRoots)
    local_setAbsolutePosition( ...
        layoutRoots(k), ...
        posAll(k, :), ...
        figHandle, ...
        units);
end
end

function local_shiftRoots( ...
    layoutRoots, figHandle, dx, dy, units)
% Shift all top-level layout roots together.

posAll = local_getRootPositions( ...
    layoutRoots, figHandle, units);

posAll(:, 1) = posAll(:, 1) + dx;
posAll(:, 2) = posAll(:, 2) + dy;

local_assignAbsoluteRootPositions( ...
    layoutRoots, posAll, figHandle, units);
end

function [bBox, WBox, HBox] = local_getContentBorderBox( ...
    figHandle, layoutRoots, units)
% Recursively measure complete visible content in absolute figure
% coordinates.
%
% The measured content includes:
%   - axes Position expanded by TightInset
%   - axes title/labels/tick labels through TightInset
%   - standalone text objects through their Extent
%   - legend Position
%   - colorbar Position and label overflow
%   - top-level layout roots as fallback

objects = local_collectMeasurementObjects(layoutRoots);
boxAll = zeros(0, 4);

for k = 1:numel(objects)
    h = objects(k);
    typeName = lower(string(local_getType(h)));

    try
        if typeName == "text"
            textBox = local_getTextExtentAbsolute( ...
                h, figHandle, units);

            if all(isfinite(textBox)) && ...
                    textBox(3) >= 0 && ...
                    textBox(4) >= 0
                boxAll(end + 1, :) = [ ...
                    textBox(1), ...
                    textBox(2), ...
                    textBox(1) + textBox(3), ...
                    textBox(2) + textBox(4)]; %#ok<AGROW>
            end
            continue;
        end

        pos = local_getAbsolutePosition( ...
            h, figHandle, units);

        if ~all(isfinite(pos)) || ...
                pos(3) < 0 || pos(4) < 0
            continue;
        end

        inset = zeros(1, 4);

        if local_isAxesLike(h)
            inset = local_getAbsoluteTightInset(h, units);

        elseif typeName == "colorbar"
            inset = local_getColorbarLabelInsetAbsolute( ...
                h, figHandle, units);
        end

        boxAll(end + 1, :) = [ ...
            pos(1) - inset(1), ...
            pos(2) - inset(2), ...
            pos(1) + pos(3) + inset(3), ...
            pos(2) + pos(4) + inset(4)]; %#ok<AGROW>
    catch
        % Ignore unsupported or transient graphics objects.
    end
end

if isempty(boxAll)
    rootPos = local_getRootPositions( ...
        layoutRoots, figHandle, units);

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
% Recursively collect visible graphics objects used for boundary
% measurement.

objects = gobjects(0);

for rIndex = 1:numel(layoutRoots)
    root = layoutRoots(rIndex);
    descendants = findall(root);
    rootObjects = gobjects(0);

    for k = 1:numel(descendants)
        h = descendants(k);

        if ~isgraphics(h) || ~local_isVisible(h)
            continue;
        end

        typeName = lower(string(local_getType(h)));

        isRelevant = ...
            local_isAxesLike(h) || ...
            typeName == "legend" || ...
            typeName == "colorbar" || ...
            typeName == "text";

        if ~isRelevant
            continue;
        end

        % Ignore empty text objects.
        if typeName == "text"
            try
                str = string(h.String);

                if isempty(str) || ...
                        all(strlength(str) == 0)
                    continue;
                end
            catch
            end
        end

        rootObjects(end + 1, 1) = h; %#ok<AGROW>
    end

    if isempty(rootObjects)
        rootObjects = root;
    end

    objects = [objects; rootObjects(:)]; %#ok<AGROW>
end

if ~isempty(objects)
    objects = unique(objects, "stable");
end
end

function tf = local_isAxesLike(h)
tf = ...
    isa(h, "matlab.graphics.axis.Axes") || ...
    isa(h, "matlab.graphics.axis.PolarAxes") || ...
    isa(h, "matlab.graphics.axis.GeographicAxes");
end

function tf = local_isVisible(h)
tf = true;

try
    tf = strcmpi(string(h.Visible), "on");
catch
end
end

function typeName = local_getType(h)
try
    typeName = string(h.Type);
catch
    typeName = string(class(h));
end
end

function pos = local_getAbsolutePosition( ...
    h, figHandle, units)
% Convert an object's Position into absolute figure coordinates.
%
% getpixelposition(...,true) recursively resolves positions through parent
% containers, including tiledlayout and nested panels.

try
    pixelPos = double(getpixelposition(h, true));
catch
    pixelPos = local_getAbsolutePixelPositionFallback( ...
        h, figHandle);
end

switch lower(string(units))
    case "pixels"
        pos = pixelPos;

    case "centimeters"
        pos = pixelPos * ...
            local_pixelToCentimeterScale(figHandle);

    case "inches"
        pos = pixelPos / ...
            local_getPixelsPerInch(figHandle);

    otherwise
        error("exportFigure2PDF:UnsupportedUnits", ...
            "Unsupported absolute unit: %s.", units);
end
end

function pixelPos = local_getAbsolutePixelPositionFallback( ...
    h, figHandle)
% Fallback absolute-position calculation.

oldUnits = h.Units;
cleanupObj = onCleanup(@() set(h, "Units", oldUnits));

h.Units = "normalized";
localPos = double(h.Position);

parent = h.Parent;

if parent == figHandle
    figPixelPos = double(getpixelposition(figHandle));

    pixelPos = [ ...
        localPos(1) * figPixelPos(3), ...
        localPos(2) * figPixelPos(4), ...
        localPos(3) * figPixelPos(3), ...
        localPos(4) * figPixelPos(4)];

    return;
end

parentPixelPos = double( ...
    getpixelposition(parent, true));

pixelPos = [ ...
    parentPixelPos(1) + ...
        localPos(1) * parentPixelPos(3), ...
    parentPixelPos(2) + ...
        localPos(2) * parentPixelPos(4), ...
    localPos(3) * parentPixelPos(3), ...
    localPos(4) * parentPixelPos(4)];
end

function local_setAbsolutePosition( ...
    h, pos, figHandle, units)
% Set a top-level layout root from absolute figure coordinates.
%
% This function is intentionally used only for top-level roots. Axes inside
% tiledlayout are never directly assigned here.

switch lower(string(units))
    case "pixels"
        pixelPos = pos;

    case "centimeters"
        pixelPos = pos / ...
            local_pixelToCentimeterScale(figHandle);

    case "inches"
        pixelPos = pos * ...
            local_getPixelsPerInch(figHandle);

    otherwise
        error("exportFigure2PDF:UnsupportedUnits", ...
            "Unsupported absolute unit: %s.", units);
end

parent = h.Parent;

if parent == figHandle
    parentPixelPos = double( ...
        getpixelposition(figHandle));

    parentWidth = parentPixelPos(3);
    parentHeight = parentPixelPos(4);

    localPos = [ ...
        pixelPos(1) / parentWidth, ...
        pixelPos(2) / parentHeight, ...
        pixelPos(3) / parentWidth, ...
        pixelPos(4) / parentHeight];
else
    parentPixelPos = double( ...
        getpixelposition(parent, true));

    localPos = [ ...
        (pixelPos(1) - parentPixelPos(1)) / ...
            parentPixelPos(3), ...
        (pixelPos(2) - parentPixelPos(2)) / ...
            parentPixelPos(4), ...
        pixelPos(3) / parentPixelPos(3), ...
        pixelPos(4) / parentPixelPos(4)];
end

oldUnits = h.Units;
cleanupObj = onCleanup(@() set(h, "Units", oldUnits));

h.Units = "normalized";
h.Position = localPos;
end

function inset = local_getAbsoluteTightInset(ax, units)
% Return TightInset in absolute physical units.

oldUnits = ax.Units;
cleanupObj = onCleanup(@() set(ax, "Units", oldUnits));

ax.Units = "pixels";
insetPixels = double(ax.TightInset);

figHandle = ancestor(ax, "figure");

switch lower(string(units))
    case "pixels"
        inset = insetPixels;

    case "centimeters"
        inset = insetPixels * ...
            local_pixelToCentimeterScale(figHandle);

    case "inches"
        inset = insetPixels / ...
            local_getPixelsPerInch(figHandle);

    otherwise
        error("exportFigure2PDF:UnsupportedUnits", ...
            "Unsupported absolute unit: %s.", units);
end
end

function inset = local_getColorbarLabelInsetAbsolute( ...
    cb, figHandle, units)
% Estimate colorbar-label overflow beyond the colorbar Position box.

inset = zeros(1, 4);

try
    cbPos = local_getAbsolutePosition( ...
        cb, figHandle, units);

    labelObj = cb.Label;

    oldUnits = labelObj.Units;
    cleanupObj = onCleanup(@() set(labelObj, "Units", oldUnits));

    labelObj.Units = "pixels";
    labelExtentPixels = double(labelObj.Extent);

    switch lower(string(units))
        case "pixels"
            labelExtent = labelExtentPixels;

        case "centimeters"
            labelExtent = ...
                labelExtentPixels * ...
                local_pixelToCentimeterScale(figHandle);

        case "inches"
            labelExtent = ...
                labelExtentPixels / ...
                local_getPixelsPerInch(figHandle);

        otherwise
            return;
    end

    location = lower(string(cb.Location));

    if cbPos(4) >= cbPos(3)
        % Vertical colorbar.
        extraWidth = max(0, labelExtent(3));

        if contains(location, "west")
            inset(1) = extraWidth;
        else
            inset(3) = extraWidth;
        end
    else
        % Horizontal colorbar.
        extraHeight = max(0, labelExtent(4));

        if contains(location, "south")
            inset(2) = extraHeight;
        else
            inset(4) = extraHeight;
        end
    end
catch
    inset = zeros(1, 4);
end
end

function box = local_getTextExtentAbsolute( ...
    textObj, figHandle, units)
% Return complete text Extent as [x y w h] in absolute figure coordinates.

oldUnits = textObj.Units;
cleanupObj = onCleanup(@() set(textObj, "Units", oldUnits));

textObj.Units = "pixels";
extentPx = double(textObj.Extent);

parent = textObj.Parent;

if isa(parent, "matlab.ui.Figure")
    parentOriginPx = [0, 0];
else
    try
        parentPosPx = double( ...
            getpixelposition(parent, true));

        parentOriginPx = parentPosPx(1:2);
    catch
        parentOriginPx = [0, 0];
    end
end

boxPx = [ ...
    parentOriginPx(1) + extentPx(1), ...
    parentOriginPx(2) + extentPx(2), ...
    extentPx(3), ...
    extentPx(4)];

switch lower(string(units))
    case "pixels"
        box = boxPx;

    case "centimeters"
        box = boxPx * ...
            local_pixelToCentimeterScale(figHandle);

    case "inches"
        box = boxPx / ...
            local_getPixelsPerInch(figHandle);

    otherwise
        error("exportFigure2PDF:UnsupportedUnits", ...
            "Unsupported absolute unit: %s.", units);
end
end

function [bBox, WBox, HBox] = local_getBoxUnion(posAll)
% Get union boundary from [x y w h] boxes.

if isempty(posAll)
    error('exportFigure2PDF:EmptyPositionList', ...
        'Cannot calculate a boundary from an empty position list.');
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

if isempty(ppi) || ...
        ~isfinite(ppi) || ...
        ppi <= 0
    ppi = 96;
end
end

function local_disableToolbars(figHandle)
axesAll = findall( ...
    figHandle, "-property", "Toolbar");

for k = 1:numel(axesAll)
    try
        toolbarObj = axesAll(k).Toolbar;

        if ~isempty(toolbarObj)
            toolbarObj.Visible = "off";
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