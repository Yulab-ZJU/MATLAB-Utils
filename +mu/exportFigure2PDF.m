function exportFigure2PDF(figHandle, outFile, widthMm, heightMm, opts)
%EXPORTFIGURE2PDF Export a figure by adjusting tiledlayout or axes roots.
%
%   mu.exportFigure2PDF(figHandle, outFile, widthMm, heightMm)
%   mu.exportFigure2PDF(..., Name, Value)
%
% The source figure is copied and never modified.
%
% Adjustment roots follow mu.getContentBox:
%
%   - if tiledlayout exists, only outermost tiledlayout roots are adjusted;
%   - axes and nested tiledlayout objects inside them are never assigned;
%   - if tiledlayout does not exist, visible axes roots are adjusted.
%
% Public tiledlayout Title, Subtitle, XLabel, and YLabel objects are preserved.
% TightInset mode measures those public text objects but still changes only
% each root Position. MATLAB is allowed to reflow everything inside a
% tiledlayout after its Position changes.
%
% INPUTS
%   figHandle
%       Scalar MATLAB figure handle.
%
%   outFile
%       Output PDF path. The ".pdf" extension is appended when omitted.
%
%   widthMm, heightMm
%       Requested Position or TightInset content-box size.
%
% NAME-VALUE OPTIONS
%   expandMode
%       'fixed', default
%       'keepratio-width'
%       'keepratio-height'
%       'keepratio-min'
%       'keepratio-max'
%
%   adjustOpt
%       'on', default
%           Iteratively adjust root Position values.
%
%       'off'
%           Export the copied figure at widthMm-by-heightMm.
%
%   adjustPositionType
%       'Position', default
%       'TightInset'
%
%   canvasScale
%       Working-canvas size relative to the target content size.
%       Default: 2.
%
%   maxIter
%       Maximum adjustment iterations. Default: 12.
%
%   toleranceMm
%       Maximum allowed origin or size error in millimeters.
%       Default: 0.01.
%
%   debug
%       true keeps the copied figure open and draws the final selected boxes.
%       Default: false.

arguments
    figHandle (1,1) matlab.ui.Figure
    outFile   {mustBeTextScalar}
    widthMm   (1,1) double {mustBeFinite, mustBePositive}
    heightMm  (1,1) double {mustBeFinite, mustBePositive}

    opts.expandMode {mustBeMember(opts.expandMode, {'fixed', 'keepratio-width', 'keepratio-height', 'keepratio-min', 'keepratio-max'})} = 'fixed'
    opts.adjustOpt  {mustBeMember(opts.adjustOpt, {'on', 'off'})} = 'on'
    opts.adjustPositionType {mustBeMember(opts.adjustPositionType, {'Position', 'TightInset'})} = 'Position'
    opts.canvasScale (1,1) double {mustBeFinite, mustBeGreaterThanOrEqual(opts.canvasScale, 1.2)} = 2
    opts.maxIter (1,1) double {mustBeInteger, mustBePositive} = 12
    opts.toleranceMm (1,1) double {mustBeFinite, mustBePositive} = 0.01
    opts.debug (1,1) logical = false
end

expandMode = lower(validatestring( ...
    opts.expandMode, ...
    {'fixed', ...
    'keepratio-width', ...
    'keepratio-height', ...
    'keepratio-min', ...
    'keepratio-max'}, ...
    mfilename, ...
    'expandMode'));

adjustOpt = mu.OptionState.create(opts.adjustOpt).toLogical;

adjustPositionType = lower(validatestring( ...
    opts.adjustPositionType, ...
    {'Position', 'TightInset'}, ...
    mfilename, ...
    'adjustPositionType'));

outFile = char(string(outFile));
[folderPath, fileName, extension] = fileparts(outFile);

if isempty(fileName)
    error('exportFigure2PDF:InvalidOutputFile', ...
        'outFile must contain a valid file name.');
end

if isempty(extension)
    extension = '.pdf';
elseif ~strcmpi(extension, '.pdf')
    error('exportFigure2PDF:InvalidOutputExtension', ...
        'outFile must use the ".pdf" extension.');
end

if ~isempty(folderPath) && ~isfolder(folderPath)
    [success, message] = mkdir(folderPath);

    if ~success
        error('exportFigure2PDF:CreateFolderFailed', ...
            'Could not create output folder "%s": %s', ...
            folderPath, ...
            message);
    end
end

if isempty(folderPath)
    outFile = [fileName, extension];
else
    outFile = fullfile(folderPath, [fileName, extension]);
end

% Update figure before copy
drawnow;
tempFig = copyobj(figHandle, groot);
cleanupObj = onCleanup(@() delete(tempFig));

try
    tempFig.WindowState = 'normal';
catch
end

if opts.debug
    tempFig.Visible = 'on';
else
    tempFig.Visible = 'off';
end

axesHandles = findall(tempFig, '-property', 'Toolbar');

for axesIndex = 1:numel(axesHandles)
    try
        axesHandles(axesIndex).Toolbar.Visible = 'off';
    catch
    end
end

drawnow;

screenPpi = double(get(groot, 'ScreenPixelsPerInch'));

if ~isfinite(screenPpi) || screenPpi <= 0
    screenPpi = 96;
end

pxPerMm = screenPpi / 25.4;
mmPerPx = 1 / pxPerMm;
tolerancePx = opts.toleranceMm * pxPerMm;

if ~adjustOpt
    local_setFigureSizePx_( ...
        tempFig, ...
        [widthMm, heightMm] * pxPerMm);

    drawnow;

    try
        exportgraphics( ...
            tempFig, ...
            outFile, ...
            'ContentType', 'vector', ...
            'BackgroundColor', 'none', ...
            'Colorspace', 'rgb', ...
            'Units', 'millimeters', ...
            'Width', widthMm, ...
            'Height', heightMm, ...
            'Padding', 'figure', ...
            'PreserveAspectRatio', 'off');
    catch
        exportgraphics( ...
            tempFig, ...
            outFile, ...
            'ContentType', 'vector', ...
            'BackgroundColor', 'none', ...
            'Colorspace', 'rgb');
    end

    fprintf('\n============== PDF Exporting ==============\n');
    fprintf('Adjustment: off\n');
    fprintf('Requested figure size: %.6g x %.6g mm\n', ...
        widthMm, heightMm);
    fprintf('PDF file exported to: %s\n', outFile);
    fprintf('================== Done ===================\n');

    if opts.debug
        clear cleanupObj;
    end

    return;
end

[initialBoundaryPx, initialElements] = mu.getContentBox( ...
    tempFig, ...
    'PositionType', adjustPositionType, ...
    'Annotation', false);

rootItems = initialElements.items;
rootHandles = gobjects(numel(rootItems), 1);
initialPositionBoxesPx = nan(numel(rootItems), 4);

for rootIndex = 1:numel(rootItems)
    rootHandles(rootIndex) = rootItems(rootIndex).handle;
    initialPositionBoxesPx(rootIndex, :) = rootItems(rootIndex).position;
end

if ~local_isValidBox_(initialBoundaryPx)
    error('exportFigure2PDF:InvalidInitialBoundary', ...
        'The initial %s content boundary is invalid.', ...
        adjustPositionType);
end

initialSizeMm = initialBoundaryPx(3:4) * mmPerPx;
initialRatio = initialSizeMm(1) / initialSizeMm(2);

switch expandMode
    case 'fixed'
        targetSizeMm = [widthMm, heightMm];

    case 'keepratio-width'
        targetSizeMm = [widthMm, widthMm / initialRatio];

    case 'keepratio-height'
        targetSizeMm = [heightMm * initialRatio, heightMm];

    case 'keepratio-min'
        scaleValue = min([ ...
            widthMm / initialSizeMm(1), ...
            heightMm / initialSizeMm(2)]);

        targetSizeMm = initialSizeMm * scaleValue;

    case 'keepratio-max'
        scaleValue = max([ ...
            widthMm / initialSizeMm(1), ...
            heightMm / initialSizeMm(2)]);

        targetSizeMm = initialSizeMm * scaleValue;

    otherwise
        error('exportFigure2PDF:InvalidExpandMode', ...
            'Unknown expandMode "%s".', expandMode);
end

targetSizePx = targetSizeMm * pxPerMm;
workingMarginPx = max(20 * pxPerMm, 0.2 * max(targetSizePx));
targetBoundaryPx = [ ...
    workingMarginPx, ...
    workingMarginPx, ...
    targetSizePx];

sourceFigureSizePx = local_getFigureSizePx_(tempFig);
workingFigureSizePx = max( ...
    sourceFigureSizePx, ...
    opts.canvasScale * targetSizePx + 2 * workingMarginPx);

local_setFigureSizePx_(tempFig, workingFigureSizePx);

for rootIndex = 1:numel(rootHandles)
    local_setAbsolutePositionBox_( ...
        rootHandles(rootIndex), ...
        initialPositionBoxesPx(rootIndex, :), ...
        tempFig);
end

drawnow;

converged = false;
finalBoundaryPx = initialBoundaryPx;
finalElements = initialElements;

for iteration = 1:opts.maxIter
    [currentBoundaryPx, currentElements] = mu.getContentBox( ...
        tempFig, ...
        'PositionType', adjustPositionType, ...
        'Annotation', false);

    currentPositionBoxesPx = ...
        local_getPositionBoxesForHandles_( ...
        rootHandles, currentElements);

    scaleFactor = ...
        targetBoundaryPx(3:4) ./ ...
        currentBoundaryPx(3:4);

    targetPositionBoxesPx = currentPositionBoxesPx;
    targetPositionBoxesPx(:, 1) = ...
        targetBoundaryPx(1) + ...
        (currentPositionBoxesPx(:, 1) - ...
        currentBoundaryPx(1)) * scaleFactor(1);

    targetPositionBoxesPx(:, 2) = ...
        targetBoundaryPx(2) + ...
        (currentPositionBoxesPx(:, 2) - ...
        currentBoundaryPx(2)) * scaleFactor(2);

    targetPositionBoxesPx(:, 3) = ...
        currentPositionBoxesPx(:, 3) * scaleFactor(1);

    targetPositionBoxesPx(:, 4) = ...
        currentPositionBoxesPx(:, 4) * scaleFactor(2);

    for rootIndex = 1:numel(rootHandles)
        local_setAbsolutePositionBox_( ...
            rootHandles(rootIndex), ...
            targetPositionBoxesPx(rootIndex, :), ...
            tempFig);
    end

    drawnow;

    [measuredBoundaryPx, measuredElements] = mu.getContentBox( ...
        tempFig, ...
        'PositionType', adjustPositionType, ...
        'Annotation', false);

    originCorrectionPx = ...
        targetBoundaryPx(1:2) - ...
        measuredBoundaryPx(1:2);

    if any(abs(originCorrectionPx) > tolerancePx)
        measuredPositionBoxesPx = ...
            local_getPositionBoxesForHandles_( ...
            rootHandles, measuredElements);

        measuredPositionBoxesPx(:, 1) = ...
            measuredPositionBoxesPx(:, 1) + ...
            originCorrectionPx(1);

        measuredPositionBoxesPx(:, 2) = ...
            measuredPositionBoxesPx(:, 2) + ...
            originCorrectionPx(2);

        for rootIndex = 1:numel(rootHandles)
            local_setAbsolutePositionBox_( ...
                rootHandles(rootIndex), ...
                measuredPositionBoxesPx(rootIndex, :), ...
                tempFig);
        end

        drawnow;
    end

    [finalBoundaryPx, finalElements] = mu.getContentBox( ...
        tempFig, ...
        'PositionType', adjustPositionType, ...
        'Annotation', false);

    boundaryDifferencePx = [ ...
        finalBoundaryPx(1:2) - targetBoundaryPx(1:2), ...
        finalBoundaryPx(3:4) - targetBoundaryPx(3:4)];

    if max(abs(boundaryDifferencePx)) <= tolerancePx
        converged = true;
        break;
    end
end

% Position mode does not necessarily include public layout text. Measure the
% final TightInset content as well so that the working canvas cannot clip it.
[actualContentBoundaryPx, ~] = mu.getContentBox( ...
    tempFig, ...
    'PositionType', 'tightinset', ...
    'Annotation', false);

contentShiftPx = [ ...
    max(0, workingMarginPx - actualContentBoundaryPx(1)), ...
    max(0, workingMarginPx - actualContentBoundaryPx(2))];

if any(contentShiftPx > tolerancePx)
    finalPositionBoxesPx = ...
        local_getPositionBoxesForHandles_( ...
        rootHandles, finalElements);

    finalPositionBoxesPx(:, 1) = ...
        finalPositionBoxesPx(:, 1) + contentShiftPx(1);

    finalPositionBoxesPx(:, 2) = ...
        finalPositionBoxesPx(:, 2) + contentShiftPx(2);

    for rootIndex = 1:numel(rootHandles)
        local_setAbsolutePositionBox_( ...
            rootHandles(rootIndex), ...
            finalPositionBoxesPx(rootIndex, :), ...
            tempFig);
    end

    drawnow;

    [finalBoundaryPx, finalElements] = mu.getContentBox( ...
        tempFig, ...
        'PositionType', adjustPositionType, ...
        'Annotation', false);

    [actualContentBoundaryPx, ~] = mu.getContentBox( ...
        tempFig, ...
        'PositionType', 'tightinset', ...
        'Annotation', false);
end

requiredFigureSizePx = [ ...
    actualContentBoundaryPx(1) + ...
    actualContentBoundaryPx(3) + workingMarginPx, ...
    actualContentBoundaryPx(2) + ...
    actualContentBoundaryPx(4) + workingMarginPx];

currentFigureSizePx = local_getFigureSizePx_(tempFig);

if any(requiredFigureSizePx > currentFigureSizePx)
    finalPositionBoxesPx = ...
        local_getPositionBoxesForHandles_( ...
        rootHandles, finalElements);

    local_setFigureSizePx_( ...
        tempFig, ...
        max(currentFigureSizePx, requiredFigureSizePx));

    for rootIndex = 1:numel(rootHandles)
        local_setAbsolutePositionBox_( ...
            rootHandles(rootIndex), ...
            finalPositionBoxesPx(rootIndex, :), ...
            tempFig);
    end

    drawnow;

    [finalBoundaryPx, finalElements] = mu.getContentBox( ...
        tempFig, ...
        'PositionType', adjustPositionType, ...
        'Annotation', false);

    [actualContentBoundaryPx, ~] = mu.getContentBox( ...
        tempFig, ...
        'PositionType', 'tightinset', ...
        'Annotation', false);
end

% Delete diagnostics only. Public tiledlayout text is never removed or
% modified.
mu.getContentBox( ...
    tempFig, ...
    'PositionType', adjustPositionType, ...
    'Annotation', false);

try
    exportgraphics( ...
        tempFig, ...
        outFile, ...
        'ContentType', 'vector', ...
        'BackgroundColor', 'none', ...
        'Colorspace', 'rgb', ...
        'Padding', 'tight');
catch
    exportgraphics( ...
        tempFig, ...
        outFile, ...
        'ContentType', 'vector', ...
        'BackgroundColor', 'none', ...
        'Colorspace', 'rgb');
end

finalSizeMm = finalBoundaryPx(3:4) * mmPerPx;
actualContentSizeMm = actualContentBoundaryPx(3:4) * mmPerPx;
relativeDifference = ...
    (finalSizeMm - targetSizeMm) ./ targetSizeMm;

fprintf('\n============== PDF Exporting ==============\n');
fprintf('adjustPositionType: %s\n', adjustPositionType);
fprintf('expandMode: %s\n', expandMode);
fprintf('Root mode: %s\n', finalElements.rootMode);
fprintf('Adjusted roots: %d\n', numel(rootHandles));
fprintf('Iterations: %d\n', iteration);
fprintf('Converged: %d\n', converged);
fprintf('Target %s-box size: %.6g x %.6g mm\n', ...
    adjustPositionType, targetSizeMm(1), targetSizeMm(2));
fprintf('Final %s-box size: %.6g x %.6g mm\n', ...
    adjustPositionType, finalSizeMm(1), finalSizeMm(2));
fprintf('Final TightInset content size: %.6g x %.6g mm\n', ...
    actualContentSizeMm(1), actualContentSizeMm(2));
fprintf('Relative size difference: [%+.6g %+.6g]\n', ...
    relativeDifference(1), relativeDifference(2));
fprintf('PDF file exported to: %s\n', outFile);
fprintf('================== Done ===================\n');

if opts.debug
    mu.getContentBox( ...
        tempFig, ...
        'PositionType', adjustPositionType, ...
        'Annotation', true);

    clear cleanupObj;
end

end

function positionBoxesPx = local_getPositionBoxesForHandles_( ...
    rootHandles, elementBoxes)
%LOCAL_GETPOSITIONBOXESFORHANDLES_ Match root handles to Position boxes.

positionBoxesPx = nan(numel(rootHandles), 4);

for rootIndex = 1:numel(rootHandles)
    matched = false;

    for itemIndex = 1:numel(elementBoxes.items)
        if isequal( ...
                rootHandles(rootIndex), ...
                elementBoxes.items(itemIndex).handle)
            positionBoxesPx(rootIndex, :) = ...
                elementBoxes.items(itemIndex).position;
            matched = true;
            break;
        end
    end

    if ~matched
        error('exportFigure2PDF:RootMatchingFailed', ...
            'A transform root could not be matched after layout reflow.');
    end
end

end

function local_setAbsolutePositionBox_( ...
    objectHandle, targetBoxPx, figHandle)
%LOCAL_SETABSOLUTEPOSITIONBOX_ Assign one root Position in absolute pixels.

if ~local_isValidBox_(targetBoxPx)
    error('exportFigure2PDF:InvalidTargetBox', ...
        'Invalid target Position box for %s.', class(objectHandle));
end

if ~isprop(objectHandle, 'Position') || ...
        ~isprop(objectHandle, 'Units')
    error('exportFigure2PDF:PositionNotWritable', ...
        '%s does not expose writable Units and Position.', ...
        class(objectHandle));
end

originalUnits = objectHandle.Units;
cleanupObj = onCleanup(@() ...
    local_restoreUnits_(objectHandle, originalUnits));

objectHandle.Units = 'pixels';
parentHandle = local_parent_(objectHandle);

if isempty(parentHandle) || isequal(parentHandle, figHandle)
    localPositionPx = targetBoxPx;
else
    [parentBox, parentSuccess] = ...
        local_getGenericAbsolutePositionBox_( ...
        parentHandle, figHandle);

    if ~parentSuccess
        error('exportFigure2PDF:ParentMeasurementFailed', ...
            'Could not resolve the parent Position for %s.', ...
            class(objectHandle));
    end

    localPositionPx = [ ...
        targetBoxPx(1:2) - parentBox(1:2) + [1, 1], ...
        targetBoxPx(3:4)];
end

try
    objectHandle.Position = localPositionPx;
catch exception
    error('exportFigure2PDF:SetPositionFailed', ...
        'Failed to set Position for %s: %s', ...
        class(objectHandle), ...
        exception.message);
end

end

function [positionBox, success] = ...
    local_getGenericAbsolutePositionBox_(objectHandle, figHandle)
%LOCAL_GETGENERICABSOLUTEPOSITIONBOX_ Read a positioned object recursively.

positionBox = nan(1, 4);
success = false;

try
    positionBox = reshape( ...
        double(getpixelposition(objectHandle, true)), ...
        1, 4);

    success = local_isValidBox_(positionBox);

    if success
        return;
    end
catch
end

if ~isprop(objectHandle, 'Position') || ...
        ~isprop(objectHandle, 'Units')
    return;
end

try
    nativePosition = reshape(double(objectHandle.Position), 1, 4);
    nativeUnits = char(string(objectHandle.Units));
    parentHandle = local_parent_(objectHandle);

    localPositionPx = hgconvertunits( ...
        figHandle, ...
        nativePosition, ...
        nativeUnits, ...
        'pixels', ...
        parentHandle);

    localPositionPx = reshape(double(localPositionPx), 1, 4);

    if ~local_isValidBox_(localPositionPx)
        return;
    end

    if isempty(parentHandle) || isequal(parentHandle, figHandle)
        positionBox = localPositionPx;
    else
        [parentBox, parentSuccess] = ...
            local_getGenericAbsolutePositionBox_( ...
            parentHandle, figHandle);

        if ~parentSuccess
            return;
        end

        positionBox = [ ...
            parentBox(1:2) + localPositionPx(1:2) - [1, 1], ...
            localPositionPx(3:4)];
    end

    success = local_isValidBox_(positionBox);
catch
end

end

function figureSizePx = local_getFigureSizePx_(figHandle)
%LOCAL_GETFIGURESIZEPX_ Read figure client size in pixels.

try
    figurePosition = reshape( ...
        double(getpixelposition(figHandle)), 1, 4);
    figureSizePx = figurePosition(3:4);
catch
    originalUnits = figHandle.Units;
    cleanupObj = onCleanup(@() ...
        local_restoreUnits_(figHandle, originalUnits));

    figHandle.Units = 'pixels';
    figurePosition = reshape(double(figHandle.Position), 1, 4);
    figureSizePx = figurePosition(3:4);
end

end

function local_setFigureSizePx_(figHandle, figureSizePx)
%LOCAL_SETFIGURESIZEPX_ Set figure client width and height.

if numel(figureSizePx) ~= 2 || ...
        any(~isfinite(figureSizePx)) || ...
        any(figureSizePx <= 0)
    error('exportFigure2PDF:InvalidFigureSize', ...
        'Invalid figure size: [%s] pixels.', ...
        strtrim(sprintf('%.12g ', figureSizePx)));
end

try
    figHandle.WindowState = 'normal';
catch
end

originalUnits = figHandle.Units;
cleanupObj = onCleanup(@() ...
    local_restoreUnits_(figHandle, originalUnits));

figHandle.Units = 'pixels';
figurePosition = reshape(double(figHandle.Position), 1, 4);
figurePosition(3:4) = figureSizePx;
figHandle.Position = figurePosition;

end

function parentHandle = local_parent_(objectHandle)
%LOCAL_PARENT_ Return Parent when available.

parentHandle = [];

try
    parentHandle = objectHandle.Parent;
catch
end

end

function local_restoreUnits_(objectHandle, originalUnits)
%LOCAL_RESTOREUNITS_ Restore Units without masking an earlier exception.

if isgraphics(objectHandle)
    try
        objectHandle.Units = originalUnits;
    catch
    end
end

end

function tf = local_isValidBox_(box)
%LOCAL_ISVALIDBOX_ Validate a finite positive rectangle.

tf = ...
    isnumeric(box) && ...
    numel(box) == 4 && ...
    all(isfinite(box)) && ...
    box(3) > 0 && ...
    box(4) > 0;

end
