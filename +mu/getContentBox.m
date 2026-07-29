function [contentBox, elementBoxes] = getContentBox(figHandle, opts)
%GETCONTENTBOX Measure the visible content boundary of a MATLAB figure.
%
%   contentBox = mu.getContentBox(figHandle)
%   [contentBox, elementBoxes] = mu.getContentBox(figHandle)
%   [...] = mu.getContentBox(..., Name, Value)
%
% All measured rectangles use figure-relative pixel coordinates:
%
%   [left, bottom, width, height]
%
% TiledChartLayout Position and OuterPosition are never included directly
% in the measured content boundary. The absolute parent-layout rectangle is
% used to reconstruct the location of a managed axes.
%
% Temporarily reading an axes Position with Units='pixels' gives the correct
% rendered width and height, but the managed [left,bottom] values cannot both
% be interpreted as figure-relative coordinates.
%
% For a horizontal tiledlayout, the measured left coordinate and size are
% retained, while the absolute bottom coordinate is reconstructed by
% vertically centering the axes inside the absolute parent-layout box:
%
%   bottomAbsolute = parentBottom + ...
%       (parentHeight - axesHeight) / 2
%
%   axesAbsoluteBox = [ ...
%       rawLeft, bottomAbsolute, rawWidth, rawHeight]
%
% For a vertical tiledlayout, the symmetric rule is used: retain the measured
% bottom coordinate and size, and horizontally center the axes inside the
% parent-layout box.
%
% TiledChartLayout Units is never changed. Axes Units is restored immediately
% after reading Position, and DRAWNOW is not called while Units='pixels'.
% For constrained axes,
% the visible plot box is obtained with tightPosition rather than the tile
% allocation stored in axes.Position. Shared tiledlayout
% Title, Subtitle, XLabel, and YLabel objects
% are retained in elementBoxes, but their position is empty because
% matlab.graphics.layout.Text does not expose a usable rectangular geometry.
% These unmeasured layout-text objects are therefore excluded from the total
% contentBox. exportFigure2PDF removes or clears them in the copied figure
% before any geometry adjustment.
%
% NAME-VALUE OPTIONS
%   PositionType
%       'tightinset' (default)
%           Invisible aspect-constrained axes use a calculated plot box;
%           other axes use tightPosition(...,IncludeLabels=true) when available,
%           which correctly follows square/image plot boxes. Older releases
%           fall back to Position expanded by TightInset. Text uses Extent.
%           Colorbars can additionally use OuterPosition and Label extent.
%
%       'position'
%           Axes and other positioned objects use Position. Text still uses
%           Extent because Text.Position is an anchor rather than a box.
%
%   Annotation
%       false (default)
%           Do not draw diagnostic rectangles.
%
%       true
%           Draw every measurable element rectangle. Element categories use
%           colors from LINES. The final contentBox is a thick red solid box.
%           Unmeasured tiledlayout text is retained in elementBoxes but is
%           not annotated. Internal graphics interaction objects, including
%           matlab.graphics.shape.internal.Button, are excluded.
%
% OUTPUT
%   contentBox
%       Union of all measurable visible elements:
%
%           [left, bottom, width, height]
%
%   elementBoxes
%       Structure with fields:
%
%           units
%           positionType
%           contentBox
%           items
%           byType
%           typeUnion
%           typeNames
%           tiledLayoutTextHandles
%           hasUnmeasuredTiledLayoutText
%
%       Each elementBoxes.items entry contains:
%
%           handle
%           type
%           subtype
%           position
%           box
%           method
%           axesHandle
%           isMeasured
%           includedInContentBox
%
%       position and box are aliases. They are empty for shared tiledlayout
%       text objects.
%
% EXAMPLE
%   [contentBox, elementBoxes] = mu.getContentBox(gcf, ...
%       'PositionType', 'tightinset', ...
%       'Annotation', true);

arguments
    figHandle (1,1) matlab.ui.Figure
    opts.PositionType {mustBeTextScalar} = 'tightinset'
    opts.Annotation (1,1) logical = false
end

positionType = lower(validatestring( ...
    opts.PositionType, ...
    {'tightinset', 'position'}, ...
    mfilename, ...
    'PositionType'));

debugTag = 'mu.getContentBox.annotation';

% Remove diagnostic rectangles from an earlier call before discovering
% figure content.
debugHandles = findall(figHandle, 'Tag', debugTag);
if ~isempty(debugHandles)
    delete(debugHandles(isgraphics(debugHandles)));
end

% Finalize axes TightInset, text Extent, colorbar, legend, and layout state.
drawnow;
drawnow;

allObjects = findall(figHandle);

items = struct( ...
    'handle', {}, ...
    'type', {}, ...
    'subtype', {}, ...
    'position', {}, ...
    'box', {}, ...
    'method', {}, ...
    'axesHandle', {}, ...
    'isMeasured', {}, ...
    'includedInContentBox', {});

handledRootHandles = gobjects(0);
layoutHandles = gobjects(0);

%% Find tiled layouts without measuring their Position
%
% A TiledChartLayout is not consistently returned by a Type='tiledlayout'
% search in every MATLAB release. Discover it through direct searches,
% public Children, and Parent chains of all discoverable objects.

try
    directLayouts = findall(figHandle, ...
        '-isa', 'matlab.graphics.layout.TiledChartLayout');
    for layoutIndex = 1:numel(directLayouts)
        layoutHandles = local_appendUniqueHandle_( ...
            layoutHandles, directLayouts(layoutIndex));
    end
catch
end

try
    directLayouts = findall(figHandle, 'Type', 'tiledlayout');
    for layoutIndex = 1:numel(directLayouts)
        layoutHandles = local_appendUniqueHandle_( ...
            layoutHandles, directLayouts(layoutIndex));
    end
catch
end

queue = {figHandle};
queueIndex = 1;

while queueIndex <= numel(queue)
    currentHandle = queue{queueIndex};
    queueIndex = queueIndex + 1;

    if isprop(currentHandle, 'Children')
        try
            children = currentHandle.Children;
        catch
            children = gobjects(0);
        end

        for childIndex = 1:numel(children)
            childHandle = children(childIndex);

            if isa(childHandle, ...
                    'matlab.graphics.layout.TiledChartLayout')
                layoutHandles = local_appendUniqueHandle_( ...
                    layoutHandles, childHandle);
            end

            if isprop(childHandle, 'Children')
                queue{end + 1} = childHandle; %#ok<AGROW>
            end
        end
    end
end

for objectIndex = 1:numel(allObjects)
    currentHandle = allObjects(objectIndex);

    while ~isempty(currentHandle) && ...
            ~isequal(currentHandle, figHandle)

        if isa(currentHandle, ...
                'matlab.graphics.layout.TiledChartLayout')
            layoutHandles = local_appendUniqueHandle_( ...
                layoutHandles, currentHandle);
        end

        currentHandle = local_parent_(currentHandle);
    end
end

%% Collect decoration Text handles that must not be measured twice

decorationTextHandles = gobjects(0);
axesHandlesAll = gobjects(0);

for objectIndex = 1:numel(allObjects)
    objectHandle = allObjects(objectIndex);

    if local_isAxesLike_(objectHandle)
        axesHandlesAll = local_appendUniqueHandle_( ...
            axesHandlesAll, objectHandle);
    end
end

for axesIndex = 1:numel(axesHandlesAll)
    axesHandle = axesHandlesAll(axesIndex);
    propertyNames = {'Title', 'Subtitle', 'XLabel', 'YLabel', 'ZLabel'};

    for propertyIndex = 1:numel(propertyNames)
        propertyName = propertyNames{propertyIndex};

        if ~isprop(axesHandle, propertyName)
            continue;
        end

        try
            textHandle = axesHandle.(propertyName);
        catch
            continue;
        end

        if ~isempty(textHandle) && isgraphics(textHandle)
            decorationTextHandles = local_appendUniqueHandle_( ...
                decorationTextHandles, textHandle);
        end
    end
end

for layoutIndex = 1:numel(layoutHandles)
    layoutHandle = layoutHandles(layoutIndex);
    propertyNames = {'Title', 'Subtitle', 'XLabel', 'YLabel'};

    for propertyIndex = 1:numel(propertyNames)
        propertyName = propertyNames{propertyIndex};

        if ~isprop(layoutHandle, propertyName)
            continue;
        end

        try
            textHandle = layoutHandle.(propertyName);
        catch
            continue;
        end

        if ~isempty(textHandle) && isgraphics(textHandle)
            decorationTextHandles = local_appendUniqueHandle_( ...
                decorationTextHandles, textHandle);
        end
    end
end

legendHandles = findall(figHandle, 'Type', 'legend');
for legendIndex = 1:numel(legendHandles)
    try
        textHandle = legendHandles(legendIndex).Title;
        if ~isempty(textHandle) && isgraphics(textHandle)
            decorationTextHandles = local_appendUniqueHandle_( ...
                decorationTextHandles, textHandle);
        end
    catch
    end
end

colorbarHandles = findall(figHandle, 'Type', 'colorbar');
for colorbarIndex = 1:numel(colorbarHandles)
    try
        textHandle = colorbarHandles(colorbarIndex).Label;
        if ~isempty(textHandle) && isgraphics(textHandle)
            decorationTextHandles = local_appendUniqueHandle_( ...
                decorationTextHandles, textHandle);
        end
    catch
    end
end

%% Associate visible graphics elements with their nearest axes
%
% Visible lines, images, patches, surfaces, scatter objects, and other axes
% descendants are represented by the owning axes boundary. Axis-off axes are
% retained when they contain visible rendered data.

axesHandles = gobjects(0);

for objectIndex = 1:numel(allObjects)
    objectHandle = allObjects(objectIndex);

    if isequal(objectHandle, figHandle) || ...
            local_isInternalObject_(objectHandle) || ...
            local_hasTag_(objectHandle, debugTag)
        continue;
    end

    if local_isAxesLike_(objectHandle)
        axesHandle = objectHandle;
    else
        if ~local_isRenderableVisible_(objectHandle, figHandle)
            continue;
        end

        axesHandle = [];
        parentHandle = local_parent_(objectHandle);

        while ~isempty(parentHandle)
            if local_isAxesLike_(parentHandle)
                axesHandle = parentHandle;
                break;
            end
            parentHandle = local_parent_(parentHandle);
        end
    end

    if isempty(axesHandle)
        continue;
    end

    measureAxes = local_isRenderableVisible_(axesHandle, figHandle);

    if ~measureAxes
        descendants = findall(axesHandle);

        for descendantIndex = 1:numel(descendants)
            descendantHandle = descendants(descendantIndex);

            if isequal(descendantHandle, axesHandle) || ...
                    local_isInternalObject_(descendantHandle) || ...
                    ~local_isRenderableVisible_( ...
                        descendantHandle, figHandle)
                continue;
            end

            descendantType = local_type_(descendantHandle);
            descendantClass = lower(class(descendantHandle));

            if ismember(descendantType, { ...
                    'line', ...
                    'patch', ...
                    'surface', ...
                    'image', ...
                    'scatter', ...
                    'bar', ...
                    'area', ...
                    'histogram', ...
                    'contour', ...
                    'quiver', ...
                    'stem', ...
                    'stair', ...
                    'rectangle'}) || ...
                    contains(descendantClass, 'chart.primitive')
                measureAxes = true;
                break;
            end
        end
    end

    if measureAxes
        axesHandles = local_appendUniqueHandle_( ...
            axesHandles, axesHandle);
    end
end

%% Measure axes
%
% For constrained-aspect-ratio axes, Position describes the available axes
% allocation rather than the actual visible plot box. This is especially
% obvious for square/image axes hosted by a wide or tall tiledlayout tile.
% In tightinset mode, use TIGHTPOSITION with labels whenever available.
% The local difference between tightPosition and Position is then applied to
% the already resolved figure-relative Position box. This avoids depending
% on the coordinate semantics of nested TiledChartLayout objects.

for axesIndex = 1:numel(axesHandles)
    axesHandle = axesHandles(axesIndex);

    [positionBox, success] = ...
        local_getAbsolutePositionBox_(axesHandle, figHandle);

    if ~success
        continue;
    end

    method = 'axes Position';
    axesBox = positionBox;

    if strcmp(positionType, 'tightinset')
        usedTightPosition = false;

        %% Axis-off constrained plot box
        %
        % For axis image/axis equal plots hosted by tiledlayout, Position is
        % the allocated tile rectangle. The actual rendered plot box can be
        % a centered square or another constrained rectangle. In addition,
        % tightPosition can return the full tile allocation for these axes.
        %
        % When the axes itself is invisible, tick labels and rulers are not
        % rendered. Compute the constrained plot box directly, then union
        % visible Title/Subtitle/XLabel/YLabel/ZLabel Text extents.

        axesVisibleOff = false;
        try
            axesVisibleOff = strcmpi( ...
                char(string(axesHandle.Visible)), 'off');
        catch
        end

        dataAspectManual = false;
        plotBoxAspectManual = false;

        try
            dataAspectManual = strcmpi( ...
                char(string(axesHandle.DataAspectRatioMode)), ...
                'manual');
        catch
        end

        try
            plotBoxAspectManual = strcmpi( ...
                char(string(axesHandle.PlotBoxAspectRatioMode)), ...
                'manual');
        catch
        end

        if axesVisibleOff && ...
                (dataAspectManual || plotBoxAspectManual)
            desiredAspectRatio = NaN;

            if plotBoxAspectManual
                try
                    plotBoxAspectRatio = ...
                        double(axesHandle.PlotBoxAspectRatio);

                    desiredAspectRatio = ...
                        plotBoxAspectRatio(1) / ...
                        plotBoxAspectRatio(2);
                catch
                end
            end

            if (~isfinite(desiredAspectRatio) || ...
                    desiredAspectRatio <= 0) && ...
                    dataAspectManual
                try
                    xLimits = double(axesHandle.XLim);
                    yLimits = double(axesHandle.YLim);
                    dataAspectRatio = ...
                        double(axesHandle.DataAspectRatio);

                    xSpan = abs(diff(xLimits));
                    ySpan = abs(diff(yLimits));

                    desiredAspectRatio = ...
                        (xSpan / dataAspectRatio(1)) / ...
                        (ySpan / dataAspectRatio(2));
                catch
                end
            end

            if isfinite(desiredAspectRatio) && ...
                    desiredAspectRatio > 0
                availableAspectRatio = ...
                    positionBox(3) / positionBox(4);

                if availableAspectRatio > desiredAspectRatio
                    plotHeight = positionBox(4);
                    plotWidth = plotHeight * desiredAspectRatio;
                    plotLeft = positionBox(1) + ...
                        (positionBox(3) - plotWidth) / 2;
                    plotBottom = positionBox(2);
                else
                    plotWidth = positionBox(3);
                    plotHeight = plotWidth / desiredAspectRatio;
                    plotLeft = positionBox(1);
                    plotBottom = positionBox(2) + ...
                        (positionBox(4) - plotHeight) / 2;
                end

                plotBox = [ ...
                    plotLeft, ...
                    plotBottom, ...
                    plotWidth, ...
                    plotHeight];

                if local_isValidBox_(plotBox)
                    axesBox = plotBox;
                    labelProperties = { ...
                        'Title', ...
                        'Subtitle', ...
                        'XLabel', ...
                        'YLabel', ...
                        'ZLabel'};

                    for labelIndex = 1:numel(labelProperties)
                        propertyName = ...
                            labelProperties{labelIndex};

                        if ~isprop(axesHandle, propertyName)
                            continue;
                        end

                        try
                            labelHandle = ...
                                axesHandle.(propertyName);
                        catch
                            continue;
                        end

                        if isempty(labelHandle) || ...
                                ~isgraphics(labelHandle) || ...
                                ~isprop(labelHandle, 'String')
                            continue;
                        end

                        try
                            labelString = ...
                                string(labelHandle.String);
                        catch
                            labelString = "";
                        end

                        if isempty(labelString) || ...
                                ~any(strlength(labelString) > 0)
                            continue;
                        end

                        [labelBox, labelSuccess] = ...
                            local_getTextExtentBox_( ...
                                labelHandle, figHandle);

                        if labelSuccess
                            axesBox = local_unionBoxes_( ...
                                [axesBox; labelBox]);
                        end
                    end

                    usedTightPosition = ...
                        local_isValidBox_(axesBox);

                    if usedTightPosition
                        method = [ ...
                            'aspect-constrained plot box ' ...
                            'union visible axes labels'];
                    end
                end
            end
        end

        if ~usedTightPosition
            try
                localTightBoxPx = tightPosition( ...
                    axesHandle, ...
                    'IncludeLabels', true, ...
                    'Units', 'pixels');

                localTightBoxPx = reshape( ...
                    double(localTightBoxPx), 1, 4);

                parentHandle = local_parent_(axesHandle);

                if isa(parentHandle, ...
                        'matlab.graphics.layout.TiledChartLayout')
                    [localPositionPx, localSuccess] = ...
                        local_getManagedAxesLocalPixelBox_( ...
                            axesHandle, figHandle);
                else
                    [localPositionPx, localSuccess] = ...
                        local_getLocalPixelPositionBox_( ...
                            axesHandle, figHandle);
                end

                if localSuccess && ...
                        local_isValidBox_(localTightBoxPx)
                    % Both boxes use the immediate axes-parent coordinate
                    % system. Their origin difference is therefore a local
                    % offset that can be applied to the corrected absolute
                    % axes Position. Width and height come from
                    % tightPosition directly.
                    localOffset = ...
                        localTightBoxPx(1:2) - ...
                        localPositionPx(1:2);

                    axesBox = [ ...
                        positionBox(1:2) + localOffset, ...
                        localTightBoxPx(3:4)];

                    usedTightPosition = ...
                        local_isValidBox_(axesBox);

                    if usedTightPosition
                        method = [ ...
                            'tightPosition relative offset applied ' ...
                            'to corrected absolute axes Position'];
                    end
                end
            catch
                usedTightPosition = false;
            end
        end

        if ~usedTightPosition && ...
                isprop(axesHandle, 'TightInset') && ...
                isprop(axesHandle, 'Position')
            try
                tightInset = reshape( ...
                    double(axesHandle.TightInset), 1, 4);
                nativePosition = reshape( ...
                    double(axesHandle.Position), 1, 4);

                parentHandle = local_parent_(axesHandle);

                if isa(parentHandle, ...
                        'matlab.graphics.layout.TiledChartLayout')
                    [localPositionPx, localSuccess] = ...
                        local_getManagedAxesLocalPixelBox_( ...
                            axesHandle, figHandle);
                else
                    [localPositionPx, localSuccess] = ...
                        local_getLocalPixelPositionBox_( ...
                            axesHandle, figHandle);
                end

                if localSuccess && ...
                        all(isfinite(tightInset)) && ...
                        all(tightInset >= 0) && ...
                        nativePosition(3) > 0 && ...
                        nativePosition(4) > 0
                    scaleX = ...
                        localPositionPx(3) / nativePosition(3);
                    scaleY = ...
                        localPositionPx(4) / nativePosition(4);

                    tightInsetPx = [ ...
                        tightInset(1) * scaleX, ...
                        tightInset(2) * scaleY, ...
                        tightInset(3) * scaleX, ...
                        tightInset(4) * scaleY];

                    axesBox = [ ...
                        positionBox(1) - tightInsetPx(1), ...
                        positionBox(2) - tightInsetPx(2), ...
                        positionBox(3) + ...
                            tightInsetPx(1) + tightInsetPx(3), ...
                        positionBox(4) + ...
                            tightInsetPx(2) + tightInsetPx(4)];

                    method = [ ...
                        'axes Position + TightInset converted ' ...
                        'without changing Units'];
                end
            catch
            end
        end
    end

    items = local_appendItem_( ...
        items, ...
        axesHandle, ...
        'axes', ...
        class(axesHandle), ...
        axesBox, ...
        method, ...
        axesHandle, ...
        true);
end

%% Measure ordinary user-created Text objects

textHandles = findall(figHandle, 'Type', 'text');

for textIndex = 1:numel(textHandles)
    textHandle = textHandles(textIndex);

    if local_isHandleInList_(textHandle, decorationTextHandles) || ...
            ~local_isRenderableVisible_(textHandle, figHandle)
        continue;
    end

    % Exclude annotation-owned internal text because the annotation itself is
    % measured later.
    hasAnnotationAncestor = false;
    currentHandle = local_parent_(textHandle);

    while ~isempty(currentHandle)
        if contains(lower(class(currentHandle)), ...
                'matlab.graphics.shape.')
            hasAnnotationAncestor = true;
            break;
        end
        currentHandle = local_parent_(currentHandle);
    end

    if hasAnnotationAncestor || ~isprop(textHandle, 'String')
        continue;
    end

    try
        textValue = string(textHandle.String);
    catch
        textValue = "";
    end

    if isempty(textValue) || ~any(strlength(textValue) > 0)
        continue;
    end

    [textBox, success] = ...
        local_getTextExtentBox_(textHandle, figHandle);

    if ~success
        continue;
    end

    axesHandle = [];
    currentHandle = local_parent_(textHandle);

    while ~isempty(currentHandle)
        if local_isAxesLike_(currentHandle)
            axesHandle = currentHandle;
            break;
        end
        currentHandle = local_parent_(currentHandle);
    end

    items = local_appendItem_( ...
        items, ...
        textHandle, ...
        'text', ...
        class(textHandle), ...
        textBox, ...
        'Text.Extent', ...
        axesHandle, ...
        true);
end

%% Retain shared tiledlayout Text objects with an empty position
%
% matlab.graphics.layout.Text exposes neither a usable Position nor a usable
% Extent in the tested MATLAB release. The objects remain in elementBoxes so
% exportFigure2PDF can detect and remove them from the copied figure before
% export. They do not contribute to contentBox.

layoutTextSpecs = { ...
    'Title',    'tiledTitle'; ...
    'Subtitle', 'tiledSubtitle'; ...
    'XLabel',   'tiledXLabel'; ...
    'YLabel',   'tiledYLabel'};

for layoutIndex = 1:numel(layoutHandles)
    layoutHandle = layoutHandles(layoutIndex);

    for specIndex = 1:size(layoutTextSpecs, 1)
        propertyName = layoutTextSpecs{specIndex, 1};
        typeName = layoutTextSpecs{specIndex, 2};

        if ~isprop(layoutHandle, propertyName)
            continue;
        end

        try
            textHandle = layoutHandle.(propertyName);
        catch
            continue;
        end

        if isempty(textHandle) || ...
                ~isgraphics(textHandle) || ...
                ~isprop(textHandle, 'String')
            continue;
        end

        try
            textValue = string(textHandle.String);
        catch
            textValue = "";
        end

        if isempty(textValue) || ~any(strlength(textValue) > 0)
            continue;
        end

        items = local_appendItem_( ...
            items, ...
            textHandle, ...
            typeName, ...
            sprintf('%s.%s', class(layoutHandle), propertyName), ...
            [], ...
            ['Unmeasured matlab.graphics.layout.Text; ' ...
             'retained for export removal'], ...
            [], ...
            false);
    end
end

%% Measure legends

for legendIndex = 1:numel(legendHandles)
    legendHandle = legendHandles(legendIndex);

    if ~local_isRenderableVisible_(legendHandle, figHandle)
        continue;
    end

    [legendBox, success] = ...
        local_getAbsolutePositionBox_(legendHandle, figHandle);

    if ~success
        continue;
    end

    items = local_appendItem_( ...
        items, ...
        legendHandle, ...
        'legend', ...
        class(legendHandle), ...
        legendBox, ...
        'legend Position', ...
        [], ...
        true);

    handledRootHandles = local_appendUniqueHandle_( ...
        handledRootHandles, legendHandle);
end

%% Measure colorbars

for colorbarIndex = 1:numel(colorbarHandles)
    colorbarHandle = colorbarHandles(colorbarIndex);

    if ~local_isRenderableVisible_(colorbarHandle, figHandle)
        continue;
    end

    [colorbarBox, success] = ...
        local_getAbsolutePositionBox_(colorbarHandle, figHandle);

    if ~success
        continue;
    end

    method = 'colorbar Position';

    if strcmp(positionType, 'tightinset')
        % OuterPosition is accepted only when it is a finite positive box.
        if isprop(colorbarHandle, 'OuterPosition') && ...
                isprop(colorbarHandle, 'Units')
            try
                outerPosition = double(colorbarHandle.OuterPosition);
                colorbarUnits = char(string(colorbarHandle.Units));
                parentHandle = local_parent_(colorbarHandle);

                outerBox = hgconvertunits( ...
                    figHandle, ...
                    outerPosition, ...
                    colorbarUnits, ...
                    'pixels', ...
                    parentHandle);

                outerBox = reshape(double(outerBox), 1, 4);

                if local_isValidBox_(outerBox)
                    if ~isempty(parentHandle) && ...
                            ~isequal(parentHandle, figHandle)
                        [parentBox, parentSuccess] = ...
                            local_getAbsolutePositionBox_( ...
                                parentHandle, figHandle);

                        if parentSuccess
                            outerBox(1:2) = ...
                                outerBox(1:2) + parentBox(1:2);
                        end
                    end

                    colorbarBox = local_unionBoxes_( ...
                        [colorbarBox; outerBox]);
                    method = 'colorbar Position union OuterPosition';
                end
            catch
            end
        end

        if isprop(colorbarHandle, 'Label')
            try
                labelHandle = colorbarHandle.Label;
            catch
                labelHandle = [];
            end

            if ~isempty(labelHandle) && ...
                    isgraphics(labelHandle) && ...
                    isprop(labelHandle, 'String')
                try
                    labelValue = string(labelHandle.String);
                catch
                    labelValue = "";
                end

                if any(strlength(labelValue) > 0)
                    [labelBox, labelSuccess] = ...
                        local_getTextExtentBox_( ...
                            labelHandle, figHandle);

                    if labelSuccess
                        colorbarBox = local_unionBoxes_( ...
                            [colorbarBox; labelBox]);
                        method = ...
                            [method, ' union colorbar Label Extent'];
                    end
                end
            end
        end
    end

    items = local_appendItem_( ...
        items, ...
        colorbarHandle, ...
        'colorbar', ...
        class(colorbarHandle), ...
        colorbarBox, ...
        method, ...
        [], ...
        true);

    handledRootHandles = local_appendUniqueHandle_( ...
        handledRootHandles, colorbarHandle);
end

%% Measure user annotation objects
%
% Public annotations such as Rectangle, Ellipse, TextBox, Line, Arrow,
% DoubleEndArrow, and TextArrow belong to matlab.graphics.shape.*.
% MATLAB also creates interaction controls in
% matlab.graphics.shape.internal.*, including toolbar Button objects.
% Internal shape objects are excluded because they are not exported figure
% content and can report negative off-canvas Position values.

for objectIndex = 1:numel(allObjects)
    objectHandle = allObjects(objectIndex);

    if ~contains(lower(class(objectHandle)), ...
            'matlab.graphics.shape.') || ...
            local_isInternalObject_(objectHandle) || ...
            local_hasTag_(objectHandle, debugTag) || ...
            ~local_isRenderableVisible_(objectHandle, figHandle)
        continue;
    end

    annotationBox = [];
    method = '';

    try
        if isprop(objectHandle, 'Units')
            originalUnits = objectHandle.Units;
            cleanupObj = onCleanup(@() ...
                local_restoreUnits_( ...
                    objectHandle, originalUnits)); %#ok<NASGU>
            objectHandle.Units = 'pixels';
        end

        if isprop(objectHandle, 'Position')
            positionValue = double(objectHandle.Position);

            if local_isValidBox_(positionValue)
                annotationBox = reshape(positionValue, 1, 4);
                method = 'annotation Position';
            end
        end

        if isempty(annotationBox) && ...
                isprop(objectHandle, 'X') && ...
                isprop(objectHandle, 'Y')
            xValue = double(objectHandle.X);
            yValue = double(objectHandle.Y);

            if ~isempty(xValue) && ...
                    numel(xValue) == numel(yValue) && ...
                    all(isfinite(xValue)) && ...
                    all(isfinite(yValue))
                linePadding = 2;

                if isprop(objectHandle, 'LineWidth')
                    try
                        linePadding = max( ...
                            linePadding, ...
                            ceil(double(objectHandle.LineWidth)));
                    catch
                    end
                end

                leftValue = min(xValue) - linePadding;
                bottomValue = min(yValue) - linePadding;
                rightValue = max(xValue) + linePadding;
                topValue = max(yValue) + linePadding;

                annotationBox = [ ...
                    leftValue, ...
                    bottomValue, ...
                    max(1, rightValue - leftValue), ...
                    max(1, topValue - bottomValue)];

                method = 'annotation X/Y bounding box';
            end
        end
    catch
        annotationBox = [];
    end

    if isempty(annotationBox) || ...
            ~local_isValidBox_(annotationBox)
        continue;
    end

    items = local_appendItem_( ...
        items, ...
        objectHandle, ...
        'annotation', ...
        class(objectHandle), ...
        annotationBox, ...
        method, ...
        [], ...
        true);

    handledRootHandles = local_appendUniqueHandle_( ...
        handledRootHandles, objectHandle);
end

%% Measure standalone charts, panels, UI objects, and positioned fallbacks

for objectIndex = 1:numel(allObjects)
    objectHandle = allObjects(objectIndex);

    if isequal(objectHandle, figHandle) || ...
            local_isAxesLike_(objectHandle) || ...
            isa(objectHandle, ...
                'matlab.graphics.layout.TiledChartLayout') || ...
            local_isInternalObject_(objectHandle) || ...
            ~local_isRenderableVisible_(objectHandle, figHandle) || ...
            ~isprop(objectHandle, 'Position')
        continue;
    end

    % Skip descendants of axes. Their owning axes was already measured.
    hasAxesAncestor = false;
    currentHandle = local_parent_(objectHandle);

    while ~isempty(currentHandle)
        if local_isAxesLike_(currentHandle)
            hasAxesAncestor = true;
            break;
        end
        currentHandle = local_parent_(currentHandle);
    end

    if hasAxesAncestor
        continue;
    end

    % Skip internals of already measured legends, colorbars, annotations,
    % panels, charts, and UI controls.
    hasHandledAncestor = false;
    currentHandle = objectHandle;

    while ~isempty(currentHandle)
        if local_isHandleInList_( ...
                currentHandle, handledRootHandles)
            hasHandledAncestor = true;
            break;
        end
        currentHandle = local_parent_(currentHandle);
    end

    if hasHandledAncestor
        continue;
    end

    objectType = local_type_(objectHandle);
    objectClass = lower(class(objectHandle));

    if contains(objectClass, 'matlab.graphics.shape.')
        continue;
    end

    category = '';

    if ismember(objectType, { ...
            'heatmap', ...
            'parallelplot', ...
            'stackedplot', ...
            'geobubble', ...
            'wordcloud', ...
            'confusionmatrixchart'}) || ...
            contains(objectClass, '.chart.') || ...
            contains(objectClass, 'chartcontainer')
        category = 'chart';
    elseif ismember(objectType, {'uipanel', 'uibuttongroup'})
        hasVisibleDecoration = true;

        if isprop(objectHandle, 'BorderType')
            try
                hasVisibleDecoration = ...
                    ~strcmpi(char(string( ...
                        objectHandle.BorderType)), 'none');
            catch
            end
        end

        if isprop(objectHandle, 'Title')
            try
                hasVisibleDecoration = ...
                    hasVisibleDecoration || ...
                    any(strlength(string( ...
                        objectHandle.Title)) > 0);
            catch
            end
        end

        if ~hasVisibleDecoration
            continue;
        end

        category = 'panel';
    elseif startsWith(objectType, 'ui') || ...
            ismember(objectType, {'uicontrol', 'uitable'})
        category = 'ui';
    else
        try
            positionValue = objectHandle.Position;
        catch
            continue;
        end

        if ~isnumeric(positionValue) || ...
                numel(positionValue) ~= 4
            continue;
        end

        category = 'positioned';
    end

    [objectBox, success] = ...
        local_getAbsolutePositionBox_(objectHandle, figHandle);

    if ~success
        continue;
    end

    items = local_appendItem_( ...
        items, ...
        objectHandle, ...
        category, ...
        class(objectHandle), ...
        objectBox, ...
        'Position', ...
        [], ...
        true);

    handledRootHandles = local_appendUniqueHandle_( ...
        handledRootHandles, objectHandle);
end

%% Remove exact duplicate entries

if numel(items) > 1
    keepMask = true(1, numel(items));

    for itemIndex = 2:numel(items)
        for previousIndex = 1:itemIndex - 1
            if ~keepMask(previousIndex)
                continue;
            end

            sameHandle = isequal( ...
                items(itemIndex).handle, ...
                items(previousIndex).handle);

            sameType = strcmp( ...
                items(itemIndex).type, ...
                items(previousIndex).type);

            if items(itemIndex).isMeasured && ...
                    items(previousIndex).isMeasured
                samePosition = max(abs( ...
                    items(itemIndex).position - ...
                    items(previousIndex).position)) < 1e-9;
            else
                samePosition = ...
                    ~items(itemIndex).isMeasured && ...
                    ~items(previousIndex).isMeasured;
            end

            if sameHandle && sameType && samePosition
                keepMask(itemIndex) = false;
                break;
            end
        end
    end

    items = items(keepMask);
end

%% Build total and per-type output

measuredMask = [items.isMeasured] & ...
    [items.includedInContentBox];

if ~any(measuredMask)
    error('getContentBox:NoVisibleContent', ...
        'No measurable visible graphics content was found in figHandle.');
end

measuredPositions = vertcat(items(measuredMask).position);
contentBox = local_unionBoxes_(measuredPositions);

typeNames = unique({items.type}, 'stable');

elementBoxes = struct;
elementBoxes.units = 'pixels';
elementBoxes.positionType = positionType;
elementBoxes.contentBox = contentBox;
elementBoxes.items = items;
elementBoxes.byType = struct;
elementBoxes.typeUnion = struct;
elementBoxes.typeNames = typeNames;

for typeIndex = 1:numel(typeNames)
    typeName = typeNames{typeIndex};
    typeMask = strcmp({items.type}, typeName);
    typeMeasuredMask = typeMask & [items.isMeasured];
    fieldName = matlab.lang.makeValidName(typeName);

    if any(typeMeasuredMask)
        typePositions = vertcat(items(typeMeasuredMask).position);
        elementBoxes.byType.(fieldName) = typePositions;
        elementBoxes.typeUnion.(fieldName) = ...
            local_unionBoxes_(typePositions);
    else
        elementBoxes.byType.(fieldName) = zeros(0, 4);
        elementBoxes.typeUnion.(fieldName) = [];
    end
end

layoutTextMask = ismember({items.type}, { ...
    'tiledTitle', ...
    'tiledSubtitle', ...
    'tiledXLabel', ...
    'tiledYLabel'});

elementBoxes.tiledLayoutTextHandles = ...
    {items(layoutTextMask).handle};
elementBoxes.hasUnmeasuredTiledLayoutText = ...
    any(layoutTextMask);

%% Draw element and total boxes

if opts.Annotation
    typeColors = lines(numel(typeNames));

    for itemIndex = 1:numel(items)
        if ~items(itemIndex).isMeasured
            continue;
        end

        typeIndex = find(strcmp( ...
            typeNames, items(itemIndex).type), 1, 'first');

        local_drawPixelBox_( ...
            figHandle, ...
            items(itemIndex).position, ...
            typeColors(typeIndex, :), ...
            '--', ...
            1.2, ...
            debugTag, ...
            sprintf('%s: %s', ...
                items(itemIndex).type, ...
                items(itemIndex).subtype));
    end

    local_drawPixelBox_( ...
        figHandle, ...
        contentBox, ...
        [1, 0, 0], ...
        '-', ...
        2.5, ...
        debugTag, ...
        'total content box');

    drawnow;
end

end

function items = local_appendItem_( ...
        items, objectHandle, typeName, subtype, position, ...
        method, axesHandle, includedInContentBox)
%LOCAL_APPENDITEM_ Append a measured or intentionally unmeasured item.

isMeasured = ~isempty(position);

if isMeasured
    position = reshape(double(position), 1, 4);

    if ~local_isValidBox_(position)
        error('getContentBox:InvalidElementBox', ...
            '%s (%s) produced an invalid box.', ...
            typeName, subtype);
    end
else
    position = [];
end

item = struct( ...
    'handle', objectHandle, ...
    'type', typeName, ...
    'subtype', subtype, ...
    'position', position, ...
    'box', position, ...
    'method', method, ...
    'axesHandle', axesHandle, ...
    'isMeasured', isMeasured, ...
    'includedInContentBox', ...
        logical(includedInContentBox && isMeasured));

items(end + 1) = item;

end

function handles = local_appendUniqueHandle_(handles, newHandle)
%LOCAL_APPENDUNIQUEHANDLE_ Append a valid graphics handle by identity.

if isempty(newHandle) || ~isgraphics(newHandle)
    return;
end

if ~local_isHandleInList_(newHandle, handles)
    handles(end + 1, 1) = newHandle;
end

end

function tf = local_isHandleInList_(objectHandle, handleList)
%LOCAL_ISHANDLEINLIST_ Compare graphics handles without numeric conversion.

tf = false;

for handleIndex = 1:numel(handleList)
    if isequal(objectHandle, handleList(handleIndex))
        tf = true;
        return;
    end
end

end

function [box, success] = ...
        local_getAbsolutePositionBox_(objectHandle, figHandle)
%LOCAL_GETABSOLUTEPOSITIONBOX_ Return a figure-relative pixel Position box.
%
% For a horizontal tiledlayout, managed axes width and height are read from
% pixel Position, the measured left value is retained, and bottom is rebuilt
% by vertically centering the axes in the absolute parent-layout rectangle.
% A vertical tiledlayout uses the symmetric horizontal-centering rule.

box = nan(1, 4);
success = false;

%% Axes managed by tiledlayout

if local_isAxesLike_(objectHandle)
    parentHandle = local_parent_(objectHandle);

    if isa(parentHandle, ...
            'matlab.graphics.layout.TiledChartLayout')
        [rawPositionPx, rawSuccess] = ...
            local_getManagedAxesLocalPixelBox_( ...
                objectHandle, figHandle);

        [parentLayoutBoxPx, parentSuccess] = ...
            local_getTiledLayoutAbsoluteBox_( ...
                parentHandle, figHandle);

        if rawSuccess && parentSuccess
            tileArrangement = "";

            if isprop(parentHandle, 'TileArrangement')
                try
                    tileArrangement = lower(string( ...
                        parentHandle.TileArrangement));
                catch
                end
            end

            gridSize = [NaN, NaN];

            if isprop(parentHandle, 'GridSize')
                try
                    gridSize = reshape( ...
                        double(parentHandle.GridSize), 1, 2);
                catch
                end
            end

            isHorizontal = ...
                tileArrangement == "horizontal" || ...
                (all(isfinite(gridSize)) && ...
                 gridSize(1) == 1 && gridSize(2) > 1);

            isVertical = ...
                tileArrangement == "vertical" || ...
                (all(isfinite(gridSize)) && ...
                 gridSize(2) == 1 && gridSize(1) > 1);

            if isHorizontal
                % Exact rule verified by
                % demo_tiledAxesPositionAnnotation_v2:
                %
                %   - raw left is retained;
                %   - raw width and height are correct;
                %   - bottom is reconstructed by vertically centering the
                %     axes in the absolute parent-layout rectangle.
                correctedBottomPx = ...
                    parentLayoutBoxPx(2) + ...
                    (parentLayoutBoxPx(4) - ...
                     rawPositionPx(4)) / 2;

                box = [ ...
                    rawPositionPx(1), ...
                    correctedBottomPx, ...
                    rawPositionPx(3), ...
                    rawPositionPx(4)];

            elseif isVertical
                % Symmetric reconstruction for a vertical tiledlayout.
                correctedLeftPx = ...
                    parentLayoutBoxPx(1) + ...
                    (parentLayoutBoxPx(3) - ...
                     rawPositionPx(3)) / 2;

                box = [ ...
                    correctedLeftPx, ...
                    rawPositionPx(2), ...
                    rawPositionPx(3), ...
                    rawPositionPx(4)];

            else
                % Fixed two-dimensional grids and flow layouts do not obey
                % the one-dimensional centering rule. Preserve the previous
                % parent-origin translation as a conservative fallback.
                box = [ ...
                    parentLayoutBoxPx(1:2) + ...
                        rawPositionPx(1:2) - [1, 1], ...
                    rawPositionPx(3:4)];
            end

            success = local_isValidBox_(box);

            if success
                return;
            end
        end
    end
end

%% Generic positioned-object conversion

try
    box = double(getpixelposition(objectHandle, true));
    box = reshape(box, 1, 4);

    if local_isValidBox_(box)
        success = true;
        return;
    end
catch
end

[localBox, localSuccess] = ...
    local_getLocalPixelPositionBox_( ...
        objectHandle, figHandle);

if ~localSuccess
    return;
end

parentHandle = local_parent_(objectHandle);

if isempty(parentHandle) || isequal(parentHandle, figHandle)
    box = localBox;
    success = true;
    return;
end

if isa(parentHandle, ...
        'matlab.graphics.layout.TiledChartLayout')
    [parentBox, parentSuccess] = ...
        local_getTiledLayoutAbsoluteBox_( ...
            parentHandle, figHandle);
else
    [parentBox, parentSuccess] = ...
        local_getAbsolutePositionBox_( ...
            parentHandle, figHandle);
end

if ~parentSuccess
    return;
end

box = [ ...
    parentBox(1:2) + localBox(1:2) - [1, 1], ...
    localBox(3:4)];

success = local_isValidBox_(box);

end

function [box, success] = ...
        local_getTiledLayoutAbsoluteBox_(layoutHandle, figHandle)
%LOCAL_GETTILEDLAYOUTABSOLUTEBOX_ Resolve layout Position without unit edits.
%
% Empirical diagnostics establish the following behavior:
%
%   layout depth 0 or 1
%       GETPIXELPOSITION(layout,true) returns the correct figure-relative
%       rectangle. The managed Position is referenced to the first
%       non-layout root container.
%
%   layout depth 2 or greater
%       GETPIXELPOSITION(layout,true) can report an incorrect size. Use the
%       local pixel rectangle and recursively add the immediate parent
%       layout origin.
%
% The layout rectangle is used only as a coordinate transform. It is never
% appended to the measured content list.

box = nan(1, 4);
success = false;

if ~isa(layoutHandle, ...
        'matlab.graphics.layout.TiledChartLayout')
    return;
end

layoutDepth = 0;
parentHandle = local_parent_(layoutHandle);
currentHandle = parentHandle;

while isa(currentHandle, ...
        'matlab.graphics.layout.TiledChartLayout')
    layoutDepth = layoutDepth + 1;
    currentHandle = local_parent_(currentHandle);
end

if layoutDepth <= 1
    try
        box = reshape( ...
            double(getpixelposition(layoutHandle, true)), ...
            1, 4);

        success = local_isValidBox_(box);

        if success
            return;
        end
    catch
    end
end

[localBox, localSuccess] = ...
    local_getLocalPixelPositionBox_( ...
        layoutHandle, figHandle);

if ~localSuccess
    return;
end

if layoutDepth <= 1
    rootContainer = currentHandle;

    if isempty(rootContainer)
        return;
    end

    if isequal(rootContainer, figHandle)
        rootOrigin = [1, 1];
    else
        [rootBox, rootSuccess] = ...
            local_getAbsolutePositionBox_( ...
                rootContainer, figHandle);

        if ~rootSuccess
            return;
        end

        rootOrigin = rootBox(1:2);
    end

    box = [ ...
        rootOrigin + localBox(1:2) - [1, 1], ...
        localBox(3:4)];
else
    if ~isa(parentHandle, ...
            'matlab.graphics.layout.TiledChartLayout')
        return;
    end

    [parentLayoutBox, parentSuccess] = ...
        local_getTiledLayoutAbsoluteBox_( ...
            parentHandle, figHandle);

    if ~parentSuccess
        return;
    end

    box = [ ...
        parentLayoutBox(1:2) + ...
            localBox(1:2) - [1, 1], ...
        localBox(3:4)];
end

success = local_isValidBox_(box);

end

function [box, success] = ...
        local_getManagedAxesLocalPixelBox_(axesHandle, figHandle)
%LOCAL_GETMANAGEDAXESLOCALPIXELBOX_ Read managed axes raw pixel Position.
%
% Position(3:4) gives the correct rendered axes size. Position(1:2) is kept
% as raw managed-layout readback and interpreted by
% local_getAbsolutePositionBox_ according to the parent layout arrangement.
%
% Only the axes Units property is changed. It is restored immediately by
% ONCLEANUP, and DRAWNOW is never called while Units='pixels'. No
% TiledChartLayout property is modified.

box = nan(1, 4);
success = false;

if ~local_isAxesLike_(axesHandle) || ...
        ~isprop(axesHandle, 'Position') || ...
        ~isprop(axesHandle, 'Units')
    return;
end

try
    originalUnits = axesHandle.Units;
    cleanupObj = onCleanup(@() ...
        local_restoreUnits_( ...
            axesHandle, originalUnits)); %#ok<NASGU>

    axesHandle.Units = 'pixels';
    box = reshape( ...
        double(axesHandle.Position), 1, 4);

    success = local_isValidBox_(box);
catch
end

if success
    return;
end

% Release-specific fallback. This remains secondary because the diagnostics
% showed that GETPIXELPOSITION(...,false) can disagree with Position read
% after setting the axes Units to pixels.
try
    box = reshape( ...
        double(getpixelposition(axesHandle, false)), ...
        1, 4);

    success = local_isValidBox_(box);
catch
end

end

function [box, success] = ...
        local_getLocalPixelPositionBox_(objectHandle, figHandle)
%LOCAL_GETLOCALPIXELPOSITIONBOX_ Read local Position without changing Units.
%
% GETPIXELPOSITION(...,false) is preferred because it reports a local pixel
% rectangle without assigning Units. This is essential for managed
% TiledChartLayout objects, where changing Units can trigger a new layout
% pass. HGCONVERTUNITS is used only when the immediate parent is not a
% tiledlayout.

box = nan(1, 4);
success = false;

try
    box = reshape( ...
        double(getpixelposition(objectHandle, false)), ...
        1, 4);

    if local_isValidBox_(box)
        success = true;
        return;
    end
catch
end

if ~isprop(objectHandle, 'Position') || ...
        ~isprop(objectHandle, 'Units')
    return;
end

try
    nativePosition = reshape( ...
        double(objectHandle.Position), 1, 4);
    nativeUnits = char(string(objectHandle.Units));
    parentHandle = local_parent_(objectHandle);

    if strcmpi(nativeUnits, 'pixels')
        box = nativePosition;
        success = local_isValidBox_(box);
        return;
    end

    if isa(parentHandle, ...
            'matlab.graphics.layout.TiledChartLayout')
        % A tiledlayout is not a reliable HGCONVERTUNITS parent. The
        % getpixelposition(false) path above is required for this case.
        return;
    end

    box = hgconvertunits( ...
        figHandle, ...
        nativePosition, ...
        nativeUnits, ...
        'pixels', ...
        parentHandle);

    box = reshape(double(box), 1, 4);
    success = local_isValidBox_(box);
catch
end

end

function [box, success] = ...
        local_getTextExtentBox_(textHandle, figHandle)
%LOCAL_GETTEXTEXTENTBOX_ Return a figure-relative pixel Text Extent box.
%
% For text parented to a tiledlayout-managed axes, the corrected absolute
% axes Position from local_getAbsolutePositionBox_ supplies the parent origin.

box = nan(1, 4);
success = false;

parentHandle = local_parent_(textHandle);
isManagedAxesText = false;

if local_isAxesLike_(parentHandle)
    axesParent = local_parent_(parentHandle);
    isManagedAxesText = isa( ...
        axesParent, ...
        'matlab.graphics.layout.TiledChartLayout');
end

% Recursive getpixelposition is unreliable for text whose axes is managed
% by a nested tiledlayout. Use Text.Extent plus the corrected axes origin for
% that case.
if ~isManagedAxesText
    try
        pixelBox = double(getpixelposition(textHandle, true));
        pixelBox = reshape(pixelBox, 1, 4);

        if local_isValidBox_(pixelBox) && ...
                pixelBox(3) > 1 && pixelBox(4) > 1
            box = pixelBox;
            success = true;
            return;
        end
    catch
    end
end

if ~isprop(textHandle, 'Extent') || ...
        ~isprop(textHandle, 'Units')
    return;
end

try
    originalUnits = textHandle.Units;
    cleanupObj = onCleanup(@() ...
        local_restoreUnits_(textHandle, originalUnits)); %#ok<NASGU>

    textHandle.Units = 'pixels';
    extentValue = double(textHandle.Extent);

    if numel(extentValue) < 4
        return;
    end

    extentValue = reshape(extentValue(1:4), 1, 4);

    if ~local_isValidBox_(extentValue)
        return;
    end

    if isempty(parentHandle) || isequal(parentHandle, figHandle)
        box = extentValue;
    else
        [parentBox, parentSuccess] = ...
            local_getAbsolutePositionBox_(parentHandle, figHandle);

        if ~parentSuccess
            return;
        end

        box = [ ...
            parentBox(1:2) + extentValue(1:2), ...
            extentValue(3:4)];
    end

    success = local_isValidBox_(box);
catch
end

end

function tf = local_isRenderableVisible_(objectHandle, figHandle)
%LOCAL_ISRENDERABLEVISIBLE_ Test object and non-axes ancestor visibility.
%
% Axes.Visible='off' does not automatically hide plotted children, so a
% hidden ancestor axes is not propagated to data children.

tf = true;
currentHandle = objectHandle;
isFirstObject = true;

while ~isempty(currentHandle)
    if isprop(currentHandle, 'Visible')
        try
            isVisible = ~strcmpi( ...
                char(string(currentHandle.Visible)), 'off');

            if ~isVisible && ...
                    (isFirstObject || ...
                     ~local_isAxesLike_(currentHandle))
                tf = false;
                return;
            end
        catch
        end
    end

    if isequal(currentHandle, figHandle)
        return;
    end

    currentHandle = local_parent_(currentHandle);
    isFirstObject = false;
end

end

function tf = local_isAxesLike_(objectHandle)
%LOCAL_ISAXESLIKE_ Identify Cartesian, polar, and geographic axes.

tf = ...
    isa(objectHandle, 'matlab.graphics.axis.Axes') || ...
    isa(objectHandle, 'matlab.graphics.axis.PolarAxes') || ...
    isa(objectHandle, 'matlab.graphics.axis.GeographicAxes');

end

function tf = local_isInternalObject_(objectHandle)
%LOCAL_ISINTERNALOBJECT_ Exclude menus, rulers, toolbars, and support peers.

objectType = local_type_(objectHandle);
objectClass = lower(class(objectHandle));
objectTag = '';

if isprop(objectHandle, 'Tag')
    try
        objectTag = lower(char(string(objectHandle.Tag)));
    catch
    end
end

excludedTypes = { ...
    'root', ...
    'figure', ...
    'uimenu', ...
    'uitoolbar', ...
    'uipushtool', ...
    'uitoggletool', ...
    'uicontextmenu'};

internalTokens = { ...
    '.internal.', ...
    '.decorator.', ...
    '.interaction.', ...
    '.toolbar.', ...
    '.datatip.', ...
    '.ruler.', ...
    'plotedit', ...
    'scribeoverlay'};

tf = ...
    ismember(objectType, excludedTypes) || ...
    any(contains(objectClass, internalTokens)) || ...
    contains(objectTag, 'scribeoverlay') || ...
    contains(objectTag, 'plotedit');

end

function tf = local_hasTag_(objectHandle, tagValue)
%LOCAL_HASTAG_ Compare a graphics Tag value.

tf = false;

if ~isprop(objectHandle, 'Tag')
    return;
end

try
    tf = strcmp(char(string(objectHandle.Tag)), tagValue);
catch
end

end

function parentHandle = local_parent_(objectHandle)
%LOCAL_PARENT_ Return Parent when available.

parentHandle = [];

try
    parentHandle = objectHandle.Parent;
catch
end

end

function objectType = local_type_(objectHandle)
%LOCAL_TYPE_ Return a lowercase graphics Type.

objectType = '';

try
    objectType = lower(char(string(objectHandle.Type)));
catch
end

end

function boundaryBox = local_unionBoxes_(boxes)
%LOCAL_UNIONBOXES_ Calculate a union of [left bottom width height] boxes.

leftValue = min(boxes(:, 1));
bottomValue = min(boxes(:, 2));
rightValue = max(boxes(:, 1) + boxes(:, 3));
topValue = max(boxes(:, 2) + boxes(:, 4));

boundaryBox = [ ...
    leftValue, ...
    bottomValue, ...
    rightValue - leftValue, ...
    topValue - bottomValue];

end

function local_drawPixelBox_( ...
        figHandle, rawBox, lineColor, lineStyle, lineWidth, ...
        debugTag, description)
%LOCAL_DRAWPIXELBOX_ Draw the visible part of a figure-relative pixel box.

try
    figurePosition = double(getpixelposition(figHandle));
    figureSize = figurePosition(3:4);
catch
    originalUnits = figHandle.Units;
    cleanupObj = onCleanup(@() ...
        local_restoreUnits_(figHandle, originalUnits)); %#ok<NASGU>

    figHandle.Units = 'pixels';
    figurePosition = double(figHandle.Position);
    figureSize = figurePosition(3:4);
end

rawLeft = rawBox(1);
rawBottom = rawBox(2);
rawRight = rawBox(1) + rawBox(3);
rawTop = rawBox(2) + rawBox(4);

displayLeft = max(0, rawLeft);
displayBottom = max(0, rawBottom);
displayRight = min(figureSize(1), rawRight);
displayTop = min(figureSize(2), rawTop);

displayBox = [ ...
    displayLeft, ...
    displayBottom, ...
    max(0, displayRight - displayLeft), ...
    max(0, displayTop - displayBottom)];

if displayBox(3) <= 0 || displayBox(4) <= 0
    warning('getContentBox:AnnotationOutsideFigure', ...
        ['Measured box "%s" lies outside the visible figure. ' ...
         'Raw box: [%s] pixels.'], ...
        description, ...
        strtrim(sprintf('%.9g ', rawBox)));
    return;
end

annotationHandle = annotation( ...
    figHandle, ...
    'rectangle', ...
    [0.01, 0.01, 0.01, 0.01], ...
    'Color', lineColor, ...
    'LineStyle', lineStyle, ...
    'LineWidth', lineWidth, ...
    'Tag', debugTag);

annotationHandle.Units = 'pixels';
annotationHandle.Position = displayBox;
annotationHandle.UserData = struct( ...
    'description', description, ...
    'rawBox', rawBox, ...
    'displayBox', displayBox, ...
    'isClipped', any(abs(displayBox - rawBox) > 0.5));

try
    annotationHandle.HitTest = 'off';
    annotationHandle.PickableParts = 'none';
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
%LOCAL_ISVALIDBOX_ Test a finite positive [left bottom width height] box.

tf = ...
    isnumeric(box) && ...
    numel(box) == 4 && ...
    all(isfinite(double(box(:)))) && ...
    box(3) > 0 && ...
    box(4) > 0;

end
