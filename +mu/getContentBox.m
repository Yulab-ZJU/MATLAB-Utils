function [contentBox, elementBoxes] = getContentBox(figHandle, opts)
%GETCONTENTBOX Measure Position or TightInset content using layout roots.
%
%   contentBox = mu.getContentBox(figHandle)
%   [contentBox, elementBoxes] = mu.getContentBox(figHandle)
%   [...] = mu.getContentBox(..., Name, Value)
%
% The transform and annotation roots are deliberately coarse:
%
%   - if the figure contains one or more tiledlayout objects, only the
%     outermost tiledlayout objects are returned as roots;
%   - axes and nested tiledlayout objects inside those roots are measured
%     internally but are not returned or annotated individually;
%   - if the figure contains no tiledlayout, visible axes are returned as
%     roots.
%
% Public tiledlayout text is preserved. In TightInset mode, common Title,
% Subtitle, XLabel, and YLabel objects are included when their pixel bounds
% can be read. When MATLAB does not expose a usable bound, the corresponding
% side of the owning tiledlayout OuterPosition is used conservatively.
%
% All rectangles are figure-relative pixels:
%
%   [left, bottom, width, height]
%
% NAME-VALUE OPTIONS
%   PositionType
%       'position', default
%           Measure each root Position.
%
%       'tightinset'
%           For a tiledlayout root, measure the union of TightInset-expanded
%           descendant axes, visible legend/colorbar descendants, and public
%           tiledlayout text. For an axes root, measure Position expanded by
%           TightInset.
%
%   Annotation
%       false, default
%           Do not draw diagnostic rectangles.
%
%       true
%           Draw one dashed rectangle per returned root and one thick red
%           rectangle for the total content union. Internal axes inside a
%           tiledlayout are never annotated individually.
%
% OUTPUT
%   contentBox
%       Union of the selected root boxes.
%
%   elementBoxes
%       Structure with fields:
%           units
%           positionType
%           rootMode
%           contentBox
%           items
%           byType
%           typeUnion
%           typeNames
%
% Each item contains both:
%
%   item.position
%       Root Position used when the root is adjusted.
%
%   item.box
%       Selected Position or TightInset measurement used for content sizing.

arguments
    figHandle         (1,1) matlab.ui.Figure

    opts.PositionType {mustBeMember(opts.PositionType, {'Position', 'TightInset'})} = 'Position'
    opts.Annotation   (1,1) logical = false
end

positionType = lower(validatestring( ...
    opts.PositionType, ...
    {'position', 'tightinset'}, ...
    mfilename, ...
    'PositionType'));

debugTag = 'mu.getContentBox.annotation';
local_deleteAnnotations_(figHandle, debugTag);

drawnow;

allObjects = findall(figHandle);

layoutMask = false(numel(allObjects), 1);

for objectIndex = 1:numel(allObjects)
    layoutMask(objectIndex) = ...
        local_isTiledLayout_(allObjects(objectIndex)) && ...
        ~local_isInternalObject_(allObjects(objectIndex));
end

layoutHandles = allObjects(layoutMask);
rootLayoutHandles = gobjects(0);

for layoutIndex = 1:numel(layoutHandles)
    layoutHandle = layoutHandles(layoutIndex);

    if ~local_hasTiledLayoutAncestor_(layoutHandle, figHandle)
        rootLayoutHandles(end + 1, 1) = layoutHandle; 
    end
end

if ~isempty(rootLayoutHandles)
    rootMode = 'tiledlayout';
    rootHandles = rootLayoutHandles;
else
    rootMode = 'axes';
    rootHandles = gobjects(0);

    for objectIndex = 1:numel(allObjects)
        objectHandle = allObjects(objectIndex);

        if ~local_isAxesLike_(objectHandle) || ...
                local_isInternalObject_(objectHandle) || ...
                ~local_isRenderableAxes_(objectHandle)
            continue;
        end

        rootHandles(end + 1, 1) = objectHandle; 
    end
end

if isempty(rootHandles)
    error('getContentBox:NoMeasurementRoots', ...
        'No outermost tiledlayout or renderable axes root was found.');
end

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

for rootIndex = 1:numel(rootHandles)
    rootHandle = rootHandles(rootIndex);

    [positionBox, positionSuccess] = ...
        local_getRootPositionBox_(rootHandle, figHandle);

    if ~positionSuccess
        warning('getContentBox:PositionMeasurementFailed', ...
            'Could not measure Position for %s.', class(rootHandle));
        continue;
    end

    if strcmp(positionType, 'tightinset')
        if local_isTiledLayout_(rootHandle)
            [selectedBox, selectedSuccess] = ...
                local_getLayoutTightBox_(rootHandle, figHandle);
            method = [ ...
                'descendant axes TightInset union, public layout text, ' ...
                'and visible layout decorations'];
        else
            [selectedBox, selectedSuccess] = ...
                local_getAxesTightBox_(rootHandle, figHandle);
            method = 'axes Position expanded by TightInset';
        end
    else
        selectedBox = positionBox;
        selectedSuccess = true;
        method = 'root Position';
    end

    if ~selectedSuccess
        selectedBox = positionBox;
        method = [method, ' fallback to Position']; %#ok<*AGROW>
    end

    if local_isTiledLayout_(rootHandle)
        typeName = 'tiledlayout';
        axesHandle = [];
    else
        typeName = 'axes';
        axesHandle = rootHandle;
    end

    items(end + 1) = struct( ...
        'handle', rootHandle, ...
        'type', typeName, ...
        'subtype', class(rootHandle), ...
        'position', reshape(double(positionBox), 1, 4), ...
        'box', reshape(double(selectedBox), 1, 4), ...
        'method', method, ...
        'axesHandle', axesHandle, ...
        'isMeasured', true, ...
        'includedInContentBox', true);
end

if isempty(items)
    error('getContentBox:NoValidMeasurements', ...
        'No valid Position or TightInset root box was measured.');
end

selectedBoxes = vertcat(items.box);
contentBox = local_unionBoxes_(selectedBoxes);

typeNames = unique(string({items.type}), 'stable');
byType = struct;
typeUnion = struct;

for typeIndex = 1:numel(typeNames)
    typeName = typeNames(typeIndex);
    typeMask = strcmp(string({items.type}), typeName);
    typeBoxes = vertcat(items(typeMask).box);
    fieldName = matlab.lang.makeValidName(char(typeName));

    byType.(fieldName) = typeBoxes;
    typeUnion.(fieldName) = local_unionBoxes_(typeBoxes);
end

elementBoxes = struct;
elementBoxes.units = 'pixels';
elementBoxes.positionType = positionType;
elementBoxes.rootMode = rootMode;
elementBoxes.contentBox = contentBox;
elementBoxes.items = items;
elementBoxes.byType = byType;
elementBoxes.typeUnion = typeUnion;
elementBoxes.typeNames = cellstr(typeNames);

if opts.Annotation
    local_deleteAnnotations_(figHandle, debugTag);
    typeColors = lines(max(1, numel(typeNames)));

    for itemIndex = 1:numel(items)
        typeIndex = find( ...
            typeNames == string(items(itemIndex).type), ...
            1, ...
            'first');

        local_drawPixelBox_( ...
            figHandle, ...
            items(itemIndex).box, ...
            typeColors(typeIndex, :), ...
            '--', ...
            1.5, ...
            debugTag, ...
            sprintf('%s %s: %s', ...
                positionType, ...
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
        sprintf('total %s box', positionType));

    drawnow;
end

end

function [positionBox, success] = ...
        local_getRootPositionBox_(rootHandle, figHandle)
%LOCAL_GETROOTPOSITIONBOX_ Measure a root Position in figure pixels.

if local_isTiledLayout_(rootHandle)
    [positionBox, success] = ...
        local_getLayoutPositionBox_(rootHandle, figHandle);
else
    [positionBox, success] = ...
        local_getAxesPositionBox_(rootHandle, figHandle);
end

end

function [positionBox, success] = ...
        local_getLayoutPositionBox_(layoutHandle, figHandle)
%LOCAL_GETLAYOUTPOSITIONBOX_ Read tiledlayout Position as figure-relative.
%
% Nested tiledlayout Position values are treated as figure-relative. The
% recursive GETPIXELPOSITION result is preferred because it does not require
% changing layout Units.

positionBox = nan(1, 4);
success = false;

try
    positionBox = reshape( ...
        double(getpixelposition(layoutHandle, true)), ...
        1, 4);

    success = local_isValidBox_(positionBox);

    if success
        return;
    end
catch
end

if ~isprop(layoutHandle, 'Position') || ...
        ~isprop(layoutHandle, 'Units')
    return;
end

try
    positionBox = hgconvertunits( ...
        figHandle, ...
        double(layoutHandle.Position), ...
        char(string(layoutHandle.Units)), ...
        'pixels', ...
        figHandle);

    positionBox = reshape(double(positionBox), 1, 4);
    success = local_isValidBox_(positionBox);
catch
end

end

function [outerBox, success] = ...
        local_getLayoutOuterBox_(layoutHandle, figHandle)
%LOCAL_GETLAYOUTOUTERBOX_ Read tiledlayout OuterPosition in figure pixels.
%
% The layout units are never changed. Nested layout OuterPosition is treated
% as figure-relative.

outerBox = nan(1, 4);
success = false;

if ~isprop(layoutHandle, 'OuterPosition') || ...
        ~isprop(layoutHandle, 'Units')
    [outerBox, success] = ...
        local_getLayoutPositionBox_(layoutHandle, figHandle);
    return;
end

try
    outerBox = hgconvertunits( ...
        figHandle, ...
        double(layoutHandle.OuterPosition), ...
        char(string(layoutHandle.Units)), ...
        'pixels', ...
        figHandle);

    outerBox = reshape(double(outerBox), 1, 4);
    success = local_isValidBox_(outerBox);
catch
end

if ~success
    [outerBox, success] = ...
        local_getLayoutPositionBox_(layoutHandle, figHandle);
end

end

function [positionBox, success] = ...
        local_getAxesPositionBox_(axesHandle, figHandle)
%LOCAL_GETAXESPOSITIONBOX_ Read axes Position in figure pixels.
%
% For axes parented by tiledlayout, Position and TightInset are interpreted
% relative to the direct parent tiledlayout OuterPosition.

positionBox = nan(1, 4);
success = false;
parentHandle = local_parent_(axesHandle);

if local_isTiledLayout_(parentHandle)
    [layoutOuterBox, layoutSuccess] = ...
        local_getLayoutOuterBox_(parentHandle, figHandle);

    if ~layoutSuccess
        return;
    end

    [rawPositionPx, rawSuccess] = ...
        local_getAxesPixelGeometry_(axesHandle);

    if ~rawSuccess
        return;
    end

    positionBox = [ ...
        layoutOuterBox(1:2) + ...
            rawPositionPx(1:2) - [1, 1], ...
        rawPositionPx(3:4)];

    success = local_isValidBox_(positionBox);
    return;
end

try
    positionBox = reshape( ...
        double(getpixelposition(axesHandle, true)), ...
        1, 4);

    success = local_isValidBox_(positionBox);

    if success
        return;
    end
catch
end

[positionBox, success] = ...
    local_getGenericAbsolutePositionBox_(axesHandle, figHandle);

end

function [tightBox, success] = ...
        local_getAxesTightBox_(axesHandle, figHandle)
%LOCAL_GETAXESTIGHTBOX_ Expand absolute axes Position by TightInset.

tightBox = nan(1, 4);
success = false;

[positionBox, positionSuccess] = ...
    local_getAxesPositionBox_(axesHandle, figHandle);

if ~positionSuccess
    return;
end

[~, tightInsetPx, geometrySuccess] = ...
    local_getAxesPixelGeometry_(axesHandle);

if ~geometrySuccess || ...
        any(~isfinite(tightInsetPx)) || ...
        any(tightInsetPx < 0)
    tightBox = positionBox;
    success = true;
    return;
end

tightBox = [ ...
    positionBox(1) - tightInsetPx(1), ...
    positionBox(2) - tightInsetPx(2), ...
    positionBox(3) + tightInsetPx(1) + tightInsetPx(3), ...
    positionBox(4) + tightInsetPx(2) + tightInsetPx(4)];

success = local_isValidBox_(tightBox);

end

function [positionPx, tightInsetPx, success] = ...
        local_getAxesPixelGeometry_(axesHandle)
%LOCAL_GETAXESPIXELGEOMETRY_ Read Position and TightInset in pixel units.
%
% The axes Units value is restored immediately. DRAWNOW is never called while
% Units='pixels'.

positionPx = nan(1, 4);
tightInsetPx = nan(1, 4);
success = false;

if ~isprop(axesHandle, 'Units') || ...
        ~isprop(axesHandle, 'Position')
    return;
end

try
    originalUnits = axesHandle.Units;
    cleanupObj = onCleanup(@() ...
        local_restoreUnits_(axesHandle, originalUnits)); 

    axesHandle.Units = 'pixels';
    positionPx = reshape(double(axesHandle.Position), 1, 4);

    if isprop(axesHandle, 'TightInset')
        tightInsetPx = reshape(double(axesHandle.TightInset), 1, 4);
    else
        tightInsetPx = zeros(1, 4);
    end

    success = ...
        local_isValidBox_(positionPx) && ...
        all(isfinite(tightInsetPx));
catch
end

end

function [tightBox, success] = ...
        local_getLayoutTightBox_(layoutHandle, figHandle)
%LOCAL_GETLAYOUTTIGHTBOX_ Measure content inside one tiledlayout root.
%
% Descendant axes are measured but are not returned as separate root items.

tightBoxes = zeros(0, 4);
descendants = findall(layoutHandle);

for objectIndex = 1:numel(descendants)
    objectHandle = descendants(objectIndex);

    if local_isAxesLike_(objectHandle) && ...
            ~local_isInternalObject_(objectHandle) && ...
            local_isRenderableAxes_(objectHandle)
        [axesTightBox, axesSuccess] = ...
            local_getAxesTightBox_(objectHandle, figHandle);

        if axesSuccess
            tightBoxes(end + 1, :) = axesTightBox; 
        end

    elseif local_isDecoration_(objectHandle) && ...
            local_isVisibleObject_(objectHandle)
        [decorationBox, decorationSuccess] = ...
            local_getGenericAbsolutePositionBox_( ...
                objectHandle, figHandle);

        if decorationSuccess
            tightBoxes(end + 1, :) = decorationBox; 
        end
    end
end

if isempty(tightBoxes)
    [tightBox, success] = ...
        local_getLayoutPositionBox_(layoutHandle, figHandle);
else
    tightBox = local_unionBoxes_(tightBoxes);
    success = local_isValidBox_(tightBox);
end

layoutObjects = descendants( ...
    arrayfun(@local_isTiledLayout_, descendants));

if ~any(layoutObjects == layoutHandle)
    layoutObjects(end + 1, 1) = layoutHandle;
end

for layoutIndex = 1:numel(layoutObjects)
    [tightBox, success] = local_includeLayoutPublicText_( ...
        layoutObjects(layoutIndex), ...
        tightBox, ...
        success, ...
        figHandle);
end

end

function [boundaryBox, success] = local_includeLayoutPublicText_( ...
        layoutHandle, boundaryBox, success, figHandle)
%LOCAL_INCLUDELAYOUTPUBLICTEXT_ Include common tiledlayout text conservatively.

propertyNames = {'Title', 'Subtitle', 'XLabel', 'YLabel'};
sideNames = {'top', 'top', 'bottom', 'left'};

[outerBox, outerSuccess] = ...
    local_getLayoutOuterBox_(layoutHandle, figHandle);

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

    if isempty(textHandle) || ...
            ~isgraphics(textHandle) || ...
            ~local_hasTextContent_(textHandle)
        continue;
    end

    [textBox, textSuccess] = ...
        local_getGenericAbsolutePositionBox_( ...
            textHandle, figHandle);

    if textSuccess
        if success
            boundaryBox = local_unionBoxes_([boundaryBox; textBox]);
        else
            boundaryBox = textBox;
            success = true;
        end

        continue;
    end

    if ~outerSuccess
        continue;
    end

    if ~success
        boundaryBox = outerBox;
        success = true;
        continue;
    end

    leftValue = boundaryBox(1);
    bottomValue = boundaryBox(2);
    rightValue = boundaryBox(1) + boundaryBox(3);
    topValue = boundaryBox(2) + boundaryBox(4);

    switch sideNames{propertyIndex}
        case 'top'
            topValue = max( ...
                topValue, ...
                outerBox(2) + outerBox(4));

        case 'bottom'
            bottomValue = min(bottomValue, outerBox(2));

        case 'left'
            leftValue = min(leftValue, outerBox(1));
    end

    boundaryBox = [ ...
        leftValue, ...
        bottomValue, ...
        rightValue - leftValue, ...
        topValue - bottomValue];
end

end

function [positionBox, success] = ...
        local_getGenericAbsolutePositionBox_(objectHandle, figHandle)
%LOCAL_GETGENERICABSOLUTEPOSITIONBOX_ Read positioned objects recursively.

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

    localPosition = hgconvertunits( ...
        figHandle, ...
        nativePosition, ...
        nativeUnits, ...
        'pixels', ...
        parentHandle);

    localPosition = reshape(double(localPosition), 1, 4);

    if ~local_isValidBox_(localPosition)
        return;
    end

    if isempty(parentHandle) || isequal(parentHandle, figHandle)
        positionBox = localPosition;
    else
        [parentBox, parentSuccess] = ...
            local_getGenericAbsolutePositionBox_( ...
                parentHandle, figHandle);

        if ~parentSuccess
            return;
        end

        positionBox = [ ...
            parentBox(1:2) + localPosition(1:2) - [1, 1], ...
            localPosition(3:4)];
    end

    success = local_isValidBox_(positionBox);
catch
end

end

function tf = local_hasTiledLayoutAncestor_(objectHandle, figHandle)
%LOCAL_HASTILEDLAYOUTANCESTOR_ Detect a tiledlayout ancestor.

tf = false;
parentHandle = local_parent_(objectHandle);

while ~isempty(parentHandle) && ~isequal(parentHandle, figHandle)
    if local_isTiledLayout_(parentHandle)
        tf = true;
        return;
    end

    parentHandle = local_parent_(parentHandle);
end

end

function tf = local_isTiledLayout_(objectHandle)
%LOCAL_ISTILEDLAYOUT_ Identify TiledChartLayout objects.

tf = isa(objectHandle, ...
    'matlab.graphics.layout.TiledChartLayout');

end

function tf = local_isAxesLike_(objectHandle)
%LOCAL_ISAXESLIKE_ Identify public axes objects.

className = lower(class(objectHandle));

tf = ...
    isa(objectHandle, 'matlab.graphics.axis.AbstractAxes') || ...
    contains(className, 'matlab.graphics.axis.axes') || ...
    contains(className, 'matlab.graphics.axis.polaraxes') || ...
    contains(className, 'matlab.graphics.axis.geographicaxes');

if contains(className, '.internal.') || ...
        contains(className, '.decorator.')
    tf = false;
end

end

function tf = local_isRenderableAxes_(axesHandle)
%LOCAL_ISRENDERABLEAXES_ Determine whether an axes contributes content.

tf = false;

try
    if isprop(axesHandle, 'Visible') && ...
            strcmpi(char(string(axesHandle.Visible)), 'on')
        tf = true;
    end
catch
end

if tf
    return;
end

try
    tf = any(isgraphics(axesHandle.Children));
catch
end

end

function tf = local_isDecoration_(objectHandle)
%LOCAL_ISDECORATION_ Identify visible legend and colorbar objects.

className = lower(class(objectHandle));

tf = ...
    contains(className, 'illustration.legend') || ...
    contains(className, 'illustration.colorbar') || ...
    endsWith(className, '.legend') || ...
    endsWith(className, '.colorbar');

end

function tf = local_isVisibleObject_(objectHandle)
%LOCAL_ISVISIBLEOBJECT_ Check public graphics visibility.

tf = true;

if isprop(objectHandle, 'Visible')
    try
        tf = strcmpi(char(string(objectHandle.Visible)), 'on');
    catch
    end
end

end

function tf = local_hasTextContent_(textHandle)
%LOCAL_HASTEXTCONTENT_ Test whether a public text object contains text.

tf = false;

if ~isprop(textHandle, 'String')
    return;
end

try
    textValue = string(textHandle.String);
    tf = any(strlength(textValue) > 0);
catch
end

end

function tf = local_isInternalObject_(objectHandle)
%LOCAL_ISINTERNALOBJECT_ Exclude toolbar and interaction implementation data.

className = lower(class(objectHandle));

tf = ...
    contains(className, '.internal.') || ...
    contains(className, '.interaction.') || ...
    contains(className, '.toolbar.') || ...
    contains(className, 'matlab.graphics.shape.internal.');

end

function parentHandle = local_parent_(objectHandle)
%LOCAL_PARENT_ Return Parent when available.

parentHandle = [];

try
    parentHandle = objectHandle.Parent;
catch
end

end

function boundaryBox = local_unionBoxes_(boxes)
%LOCAL_UNIONBOXES_ Calculate the union of valid boxes.

if isempty(boxes)
    boundaryBox = [];
    return;
end

validMask = false(size(boxes, 1), 1);

for boxIndex = 1:size(boxes, 1)
    validMask(boxIndex) = local_isValidBox_(boxes(boxIndex, :));
end

boxes = boxes(validMask, :);

if isempty(boxes)
    boundaryBox = [];
    return;
end

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
%LOCAL_DRAWPIXELBOX_ Draw a clipped figure-relative rectangle.

if ~local_isValidBox_(rawBox)
    return;
end

try
    figurePosition = reshape( ...
        double(getpixelposition(figHandle)), 1, 4);
    figureSize = figurePosition(3:4);
catch
    originalUnits = figHandle.Units;
    cleanupObj = onCleanup(@() ...
        local_restoreUnits_(figHandle, originalUnits)); 

    figHandle.Units = 'pixels';
    figurePosition = reshape(double(figHandle.Position), 1, 4);
    figureSize = figurePosition(3:4);
end

leftValue = max(0, rawBox(1));
bottomValue = max(0, rawBox(2));
rightValue = min(figureSize(1), rawBox(1) + rawBox(3));
topValue = min(figureSize(2), rawBox(2) + rawBox(4));

displayBox = [ ...
    leftValue, ...
    bottomValue, ...
    max(0, rightValue - leftValue), ...
    max(0, topValue - bottomValue)];

if displayBox(3) <= 0 || displayBox(4) <= 0
    warning('getContentBox:AnnotationOutsideFigure', ...
        ['Measured root "%s" lies outside the visible figure. ' ...
         'Raw box: [%s] pixels.'], ...
        description, ...
        strtrim(sprintf('%.12g ', rawBox)));
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
    'displayBox', displayBox);

try
    annotationHandle.HitTest = 'off';
    annotationHandle.PickableParts = 'none';
catch
end

end

function local_deleteAnnotations_(figHandle, debugTag)
%LOCAL_DELETEANNOTATIONS_ Delete diagnostic rectangles created here.

debugHandles = findall(figHandle, 'Tag', debugTag);

if ~isempty(debugHandles)
    delete(debugHandles(isgraphics(debugHandles)));
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
