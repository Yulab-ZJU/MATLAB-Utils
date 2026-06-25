function setPlotMode(varargin)
%SETPLOTMODE  Set or restore plotting properties.
%
% NOTES:
%   - Call before plotting with "-default" to modify graphics defaults.
%   - Pass figure, tiledlayout, axes, or other graphics handles to modify
%     existing objects.
%   - Objects tagged "setPlotModeExclusion" and all their descendants are
%     excluded.
%   - Use "*" to match any supported graphics target. Only one wildcard is
%     allowed in one target path.
%   - Use "-except", Prop, Value to exclude findall(root, Prop, Value)
%     matches and their descendants in non-default mode.
%
% USAGE:
%   mu.setPlotMode("factory")
%   mu.setPlotMode("pdf")
%   mu.setPlotMode("your_setting.m")
%
%   mu.setPlotMode(H, "pdf")
%   mu.setPlotMode(H, "your_setting.m")
%   mu.setPlotMode(H, TargetProperty, Value, ...)
%
%   mu.setPlotMode(groot, "pdf", "-default")
%   mu.setPlotMode(H, "-except", "Tag", "foo", ...)
%
% TARGET-PROPERTY FORMATS:
%   Dot style:
%       "Axes.FontSize"
%       "Axes.Title.FontSize"
%       "TiledLayout.Padding"
%       "TiledLayout.Title.FontSize"
%
%   Chain style:
%       "AxesFontSize"
%       "AxesTitleFontSize"
%       "TiledLayoutPadding"
%       "TiledLayoutTitleFontSize"
%
% WILDCARD:
%       "*.FontName"
%       "*.FontSize"
%       "*.LineWidth"
%
% TILEDLAYOUT SUPPORT:
%   - TiledLayout itself can be targeted:
%       "TiledLayout.Padding"
%       "TiledLayout.TileSpacing"
%
%   - Its title text can be targeted:
%       "TiledLayout.Title.FontSize"
%       "TiledLayout.Title.FontWeight"
%
%   - Axes and graphics objects inside tiledlayout are found recursively.
%
% EXAMPLES:
%   % Apply PDF style to an existing figure:
%   mu.setPlotMode(gcf, "pdf");
%
%   % Apply style only within a tiledlayout:
%   mu.setPlotMode(tl, "pdf");
%
%   % Set defaults before plotting, then fix nested objects afterward:
%   mu.setPlotMode(groot, "pdf", "-default");
%   fig = figure;
%   tl = tiledlayout(fig, 2, 2);
%   ...
%   mu.setPlotMode(fig, "pdf");
%
%   % Manually modify tiledlayout:
%   mu.setPlotMode(tl, ...
%       "TiledLayout.Padding", "compact", ...
%       "TiledLayout.TileSpacing", "compact", ...
%       "TiledLayout.Title.FontSize", 10);
%
%   % Exclude an axes and its contents:
%   ax.Tag = "skip";
%   mu.setPlotMode(gcf, "pdf", "-except", "Tag", "skip");

% ------------------------------------------------------------
% 1) Parse inputs
% ------------------------------------------------------------
narginchk(1, inf);

firstArg = varargin{1};

% Target roots
if ~isempty(firstArg) && all(isgraphics(firstArg))
    roots = firstArg(:);
    varargin = varargin(2:end);
else
    roots = groot;
end

% Plot mode
plotMode = "manual";

if ~isempty(varargin)
    assert(mu.isTextScalar(varargin{1}), ...
        "Invalid plot mode or name-value input.");

    modeCandidate = string(varargin{1});

    if matches(modeCandidate, ...
            ["factory", "pdf", "manual"], ...
            "IgnoreCase", true) || ...
            isfile(modeCandidate)

        plotMode = modeCandidate;
        varargin = varargin(2:end);
    end
end

% Option: -default
idxDefault = cellfun( ...
    @(x) mu.isTextScalar(x) && strcmpi(x, "-default"), ...
    varargin);

setDefault = any(idxDefault);

if setDefault
    varargin = varargin(~idxDefault);
end

% Option: -except Prop Value
exceptArgs = {};

k = 1;

while k <= numel(varargin)
    if mu.isTextScalar(varargin{k}) && ...
            strcmpi(varargin{k}, "-except")

        assert(k + 2 <= numel(varargin), ...
            'Option "-except" requires Prop and Value.');

        prop = varargin{k + 1};
        val  = varargin{k + 2};

        assert(mu.isTextScalar(prop), ...
            'Option "-except" requires Prop to be text.');

        exceptArgs = [ ...
            exceptArgs, ...
            {char(prop)}, ...
            {val}]; %#ok<AGROW>

        varargin([k, k + 1, k + 2]) = [];
        continue;
    end

    k = k + 1;
end

% ------------------------------------------------------------
% 2) Presets / external setting file
% ------------------------------------------------------------
if isfile(plotMode)
    presetFcn = mu.path2func(plotMode);

    params = mu.nvnorm( ...
        presetFcn(), ...
        "OutType", "nv", ...
        "ValidateNV", true, ...
        "FieldCase", "keep");

    for rootIndex = 1:numel(roots)
        setTargetProperty_( ...
            roots(rootIndex), ...
            params, ...
            setDefault, ...
            exceptArgs);
    end
else
    plotMode = validatestring( ...
        lower(plotMode), ...
        {'factory', 'pdf', 'manual'});

    switch plotMode
        case "factory"
            for rootIndex = 1:numel(roots)
                try
                    reset(roots(rootIndex));
                catch
                end
            end

        case "pdf"
            params = defaultPlotModePDF();

            for rootIndex = 1:numel(roots)
                setTargetProperty_( ...
                    roots(rootIndex), ...
                    params, ...
                    setDefault, ...
                    exceptArgs);
            end

        case "manual"
            % Continue to manual name-value inputs.
    end
end

% ------------------------------------------------------------
% 3) Manual name-value pairs
% ------------------------------------------------------------
if isempty(varargin)
    return;
end

NVs = mu.nvnorm( ...
    varargin, ...
    "FieldCase", "keep", ...
    "OutType", "nv", ...
    "ValidateNV", false, ...
    "DuplicateNames", "lastwins");

for rootIndex = 1:numel(roots)
    setTargetProperty_( ...
        roots(rootIndex), ...
        NVs, ...
        setDefault, ...
        exceptArgs);
end

return;
end

%% ============================================================
% Main property assignment
% ============================================================

function setTargetProperty_(rootH, NVs, setDefault, exceptArgs)
proto = getPrototypeHandles_();

names = NVs(1:2:end);
vals  = NVs(2:2:end);

for index = 1:numel(names)
    paramName = char(names{index});
    paramVal  = vals{index};

    [targets, prop, isDefault] = ...
        parseTargetPathProperty_(paramName, proto);

    % ------------------------------------------------------------
    % Default route
    % ------------------------------------------------------------
    if setDefault || isDefault
        defaultName = buildDefaultName_(targets, prop);

        defaultSet = false;

        try
            set(rootH, defaultName, paramVal);
            defaultSet = true;
        catch
        end

        if ~defaultSet && rootH ~= groot
            try
                set(groot, defaultName, paramVal);
            catch
            end
        end

        continue;
    end

    % ------------------------------------------------------------
    % Existing-object route
    % ------------------------------------------------------------
    objs = resolveTargetsByChain_( ...
        rootH, targets, proto, exceptArgs);

    if isempty(objs)
        continue;
    end

    try
        set(objs, prop, paramVal);
    catch
        for objIndex = 1:numel(objs)
            try
                set(objs(objIndex), prop, paramVal);
            catch
            end
        end
    end
end
end

%% ============================================================
% Parse and validate target paths
% ============================================================

function [nameChainCell, prop, isDefault] = ...
    parseTargetPathProperty_(paramName, proto)

assert(mu.isTextScalar(paramName), ...
    "paramName must be text.");

paramName = char(paramName);

assert(~isempty(paramName), ...
    "paramName must be nonempty.");

% Explicit Default... prefix
if startsWith(paramName, "default", "IgnoreCase", true)
    paramName = paramName(8:end);
    isDefault = true;
else
    isDefault = false;
end

% Dot style
if contains(paramName, '.')
    parts = split(string(paramName), '.');

    assert(numel(parts) >= 2, ...
        "Invalid dotted target-property path.");

    nameChainCell = cellstr(parts(1:end-1));
    prop = char(parts(end));

    validateTargetPathProperty_( ...
        nameChainCell, prop, proto);

    return;
end

% Chain style
[nameChainCell, prop] = ...
    splitChainStyle_(paramName, proto);

validateTargetPathProperty_( ...
    nameChainCell, prop, proto);
end

function validateTargetPathProperty_(nameChainCell, prop, proto)
% Validate object hierarchy and the final settable property.

if isstring(nameChainCell)
    nameChainCell = cellstr(nameChainCell);
end

assert(iscell(nameChainCell) && ~isempty(nameChainCell), ...
    "Empty target chain.");

assert(mu.isTextScalar(prop) && ~isempty(prop), ...
    "Invalid property name.");

prop = char(prop);

starPos = find(strcmp(nameChainCell, '*'));

assert(numel(starPos) <= 1, ...
    "Only one '*' is allowed in a target path.");

protoTypes = fieldnames(proto);
protoTypes = protoTypes(:);

for index = 1:numel(nameChainCell)
    token = nameChainCell{index};

    assert(mu.isTextScalar(token), ...
        "Target token must be text.");

    token = char(token);

    if strcmp(token, '*')
        continue;
    end

    assert(isstrprop(token(1), 'upper'), ...
        ['Token "%s" must be first-letter capitalized ' ...
        'or equal to "*".'], token);
end

    function tf = validateConcrete_(tokens)
        tf = true;
        previousHandle = gobjects(0);

        for tokenIndex = 1:numel(tokens)
            token = tokens{tokenIndex};

            if tokenIndex == 1
                if isfield(proto, token)
                    previousHandle = proto.(token);
                else
                    previousHandle = ...
                        findPrototypeChildProperty_(proto, token);
                end

                if isempty(previousHandle) || ...
                        ~isscalar(previousHandle) || ...
                        ~isgraphics(previousHandle)
                    tf = false;
                    return;
                end

                continue;
            end

            if isfield(proto, token)
                thisHandle = proto.(token);

                if isempty(thisHandle) || ...
                        ~isscalar(thisHandle) || ...
                        ~isgraphics(thisHandle) || ...
                        ~isDescendant_(thisHandle, previousHandle)
                    tf = false;
                    return;
                end
            else
                if ~isChildPropHandle_(previousHandle, token)
                    tf = false;
                    return;
                end

                thisHandle = ...
                    getChildPropHandle_(previousHandle, token);

                if isempty(thisHandle) || ...
                        ~isscalar(thisHandle) || ...
                        ~isgraphics(thisHandle)
                    tf = false;
                    return;
                end
            end

            previousHandle = thisHandle;
        end

        if isempty(previousHandle) || ...
                ~isscalar(previousHandle) || ...
                ~isgraphics(previousHandle) || ...
                ~isprop(previousHandle, prop)
            tf = false;
            return;
        end

        if ~isSettable_(previousHandle, prop)
            tf = false;
        end
    end

if isempty(starPos)
    assert(validateConcrete_(nameChainCell), ...
        "Invalid target-path-property: %s.%s", ...
        strjoin(nameChainCell, '.'), prop);

    return;
end

position = starPos(1);
validReplacement = false;

for typeIndex = 1:numel(protoTypes)
    tokens = nameChainCell;
    tokens{position} = protoTypes{typeIndex};

    if validateConcrete_(tokens)
        validReplacement = true;
        break;
    end
end

assert(validReplacement, ...
    'Wildcard "*" has no valid replacement for property "%s".', ...
    prop);
end

function h = findPrototypeChildProperty_(proto, token)
h = gobjects(0);
protoNames = fieldnames(proto);

for index = 1:numel(protoNames)
    parentHandle = proto.(protoNames{index});

    if isChildPropHandle_(parentHandle, token)
        h = getChildPropHandle_(parentHandle, token);

        if ~isempty(h) && isgraphics(h)
            return;
        end
    end
end
end

%% ============================================================
% Prototype graphics objects
% ============================================================

function proto = getPrototypeHandles_()
persistent P

if ~isempty(P) && ...
        isfield(P, "Figure") && ...
        isgraphics(P.Figure)
    proto = P;
    return;
end

oldFig = [];
oldAx  = [];

try
    oldFig = groot.CurrentFigure;
catch
end

try
    oldAx = groot.CurrentAxes;
catch
end

cleanupObj = onCleanup(@() restoreCurrent_(oldFig, oldAx));

fig = figure( ...
    "Visible", "off", ...
    "HandleVisibility", "off", ...
    "NumberTitle", "off", ...
    "Name", "mu.setPlotMode::prototype");

tl = tiledlayout(fig, 1, 1, ...
    "Padding", "compact", ...
    "TileSpacing", "compact");

title(tl, "Layout title");

ax = nexttile(tl);
hold(ax, "on");

title(ax, "Axes title");
subtitle(ax, "Axes subtitle");
xlabel(ax, "X label");
ylabel(ax, "Y label");
zlabel(ax, "Z label");

lineObj = plot(ax, [nan, 1], [0, 1]);

contour( ...
    ax, ...
    [0, 1], ...
    [0, 1], ...
    [0, 1; 1, 1], ...
    [0, 1]);

contourObjects = findall(fig, "Type", "contour");

if isempty(contourObjects)
    contourObj = gobjects(0);
else
    contourObj = contourObjects(1);
end

scatterObj = scatter(ax, 0, 0);

patchObj = patch( ...
    ax, ...
    [0, 1, 1], ...
    [0, 0, 1], ...
    "k");

textObj = text(ax, 0, 0, "x");

legendObj = legend(ax, {"demo"});
colorbarObj = colorbar(ax);

P.Figure      = fig;
P.TiledLayout = tl;
P.Axes        = ax;
P.Line        = lineObj;
P.Contour     = contourObj;
P.Scatter     = scatterObj;
P.Patch       = patchObj;
P.Text        = textObj;
P.Legend      = legendObj;
P.Colorbar    = colorbarObj;

proto = P;
end

function restoreCurrent_(oldFig, oldAx)
try
    if isgraphics(oldFig, "figure")
        groot.CurrentFigure = oldFig;
    else
        groot.CurrentFigure = [];
    end
catch
end

try
    if isgraphics(oldAx, "axes")
        groot.CurrentAxes = oldAx;
    else
        groot.CurrentAxes = [];
    end
catch
end
end

%% ============================================================
% Target resolution on real graphics trees
% ============================================================

function objs = resolveTargetsByChain_( ...
    rootH, targets, proto, exceptArgs)

starPos = find(strcmp(targets, '*'));

if numel(starPos) > 1
    error("Only one '*' is allowed in a target path.");
end

if isempty(starPos)
    objs = resolveConcrete_( ...
        rootH, targets, exceptArgs);
    return;
end

protoTypes = fieldnames(proto);
position = starPos(1);
accumulated = gobjects(0);

for typeIndex = 1:numel(protoTypes)
    replacedTargets = targets;
    replacedTargets{position} = protoTypes{typeIndex};

    objectsTemp = resolveConcrete_( ...
        rootH, replacedTargets, exceptArgs);

    if ~isempty(objectsTemp)
        accumulated = [ ...
            accumulated; ...
            objectsTemp(:)]; %#ok<AGROW>
    end
end

if isempty(accumulated)
    objs = gobjects(0);
else
    objs = unique(accumulated, "stable");
end
end

function objs = resolveConcrete_(rootH, targets, exceptArgs)
% Resolve a target chain with no wildcard.

exclusionRoots = findall( ...
    rootH, ...
    "Tag", ...
    "setPlotModeExclusion");

if ~isempty(exceptArgs)
    try
        excludedByArgs = findall( ...
            rootH, exceptArgs{:});

        exclusionRoots = [ ...
            exclusionRoots; ...
            excludedByArgs(:)];
    catch ME
        error( ...
            "Invalid '-except' arguments for findall: %s", ...
            ME.message);
    end
end

if ~isempty(exclusionRoots)
    exclusionRoots = unique( ...
        exclusionRoots, "stable");
end

currentObjects = gobjects(0);

for targetIndex = 1:numel(targets)
    token = char(targets{targetIndex});

    if targetIndex == 1
        currentObjects = ...
            resolveTokenFromRoot_(rootH, token);
    else
        currentObjects = ...
            resolveTokenFromParents_(currentObjects, token);
    end

    if ~isempty(currentObjects)
        currentObjects = ...
            currentObjects(isgraphics(currentObjects));

        currentObjects = currentObjects( ...
            ~isExcludedByRoots_( ...
            currentObjects, exclusionRoots));
    end

    if isempty(currentObjects)
        objs = gobjects(0);
        return;
    end
end

objs = currentObjects;
end

function out = resolveTokenFromRoot_(rootH, token)
out = gobjects(0);

% Root itself
if tokenMatchesObject_(rootH, token)
    out(end + 1, 1) = rootH;
end

% Descendants
found = findObjectsByToken_(rootH, token);

if ~isempty(found)
    out = [out; found(:)];
end

if ~isempty(out)
    out = unique(out, "stable");
    return;
end

% Child-handle property
if isChildPropHandle_(rootH, token)
    out = getChildPropHandle_(rootH, token);
end
end

function out = resolveTokenFromParents_(parents, token)
out = gobjects(0);

% Search matching objects under every current parent.
for parentIndex = 1:numel(parents)
    parentObj = parents(parentIndex);

    if ~isgraphics(parentObj)
        continue;
    end

    if tokenMatchesObject_(parentObj, token)
        out(end + 1, 1) = parentObj; %#ok<AGROW>
    end

    found = findObjectsByToken_(parentObj, token);

    if ~isempty(found)
        out = [out; found(:)]; %#ok<AGROW>
    end
end

if ~isempty(out)
    out = unique(out, "stable");
    return;
end

% Search child-handle properties.
for parentIndex = 1:numel(parents)
    parentObj = parents(parentIndex);

    if isChildPropHandle_(parentObj, token)
        childObj = ...
            getChildPropHandle_(parentObj, token);

        if ~isempty(childObj)
            out = [out; childObj(:)]; %#ok<AGROW>
        end
    end
end

if ~isempty(out)
    out = unique(out, "stable");
end
end

function found = findObjectsByToken_(rootH, token)
% Find graphics descendants matching a token.
%
% TiledLayout is handled through class/type matching because support for
% findall(...,"Type","tiledlayout") can vary between MATLAB releases.

found = gobjects(0);

typeName = tokenToType_(token);

% Fast Type query
try
    h = findall(rootH, "Type", typeName);

    if ~isempty(h)
        found = [found; h(:)];
    end
catch
end

% Robust fallback, especially for TiledLayout.
try
    allObjects = findall(rootH);

    match = arrayfun( ...
        @(h) tokenMatchesObject_(h, token), ...
        allObjects);

    h = allObjects(match);

    if ~isempty(h)
        found = [found; h(:)];
    end
catch
end

if ~isempty(found)
    found = unique(found, "stable");
end
end

function tf = tokenMatchesObject_(obj, token)
tf = false;

if isempty(obj) || ~isgraphics(obj)
    return;
end

token = string(token);

switch lower(token)
    case "tiledlayout"
        className = string(class(obj));

        tf = ...
            contains(className, "TiledChartLayout") || ...
            strcmpi(localGraphicsType_(obj), "tiledlayout");

    otherwise
        expectedType = tokenToType_(token);
        actualType = localGraphicsType_(obj);

        tf = strcmpi(actualType, expectedType);
end
end

function typeName = tokenToType_(token)
token = lower(string(token));

switch token
    case "tiledlayout"
        typeName = "tiledlayout";

    otherwise
        typeName = token;
end
end

function typeName = localGraphicsType_(obj)
try
    typeName = string(obj.Type);
catch
    typeName = lower(string(class(obj)));
end
end

%% ============================================================
% Chain-style tokenizer
% ============================================================

function [targets, prop] = splitChainStyle_(inputName, proto)
% Greedy tokenization with property lookahead.
%
% Examples:
%   AxesFontSize
%   AxesTitleFontSize
%   TiledLayoutTileSpacing
%   TiledLayoutTitleFontSize

assert(mu.isTextScalar(inputName) && ~isempty(inputName), ...
    "Invalid chain-style property name.");

remaining = char(inputName);

protoTypes = fieldnames(proto);

childProps = { ...
    'Title', ...
    'Subtitle', ...
    'XLabel', ...
    'YLabel', ...
    'ZLabel', ...
    'Legend', ...
    'Colorbar'};

allowedTokens = [ ...
    protoTypes(:); ...
    childProps(:)];

[~, order] = sort( ...
    cellfun(@numel, allowedTokens), ...
    "descend");

allowedTokens = allowedTokens(order);

targets = {};
currentPrototype = gobjects(0);

while ~isempty(remaining)
    % Stop when remaining text is a property on the current object.
    if ~isempty(currentPrototype) && ...
            isgraphics(currentPrototype)

        actualProp = matchPropertyName_( ...
            currentPrototype, remaining);

        if ~isempty(actualProp)
            prop = actualProp;
            return;
        end
    end

    matched = false;

    for tokenIndex = 1:numel(allowedTokens)
        token = allowedTokens{tokenIndex};

        if strncmp(remaining, token, numel(token))
            targets{end + 1} = token; %#ok<AGROW>

            remaining = ...
                remaining(numel(token) + 1:end);

            matched = true;

            if isempty(currentPrototype)
                if isfield(proto, token)
                    currentPrototype = proto.(token);
                else
                    currentPrototype = ...
                        findPrototypeChildProperty_(proto, token);
                end
            else
                if isfield(proto, token)
                    candidate = proto.(token);

                    if isDescendant_( ...
                            candidate, currentPrototype)
                        currentPrototype = candidate;
                    else
                        currentPrototype = gobjects(0);
                    end
                elseif isChildPropHandle_( ...
                        currentPrototype, token)

                    currentPrototype = ...
                        getChildPropHandle_( ...
                        currentPrototype, token);
                else
                    currentPrototype = gobjects(0);
                end
            end

            break;
        end
    end

    if ~matched
        break;
    end
end

assert(~isempty(targets), ...
    'Cannot parse chain-style name "%s".', inputName);

assert(~isempty(remaining), ...
    'Chain-style name "%s" has no property tail.', inputName);

if ~isempty(currentPrototype) && ...
        isgraphics(currentPrototype)

    actualProp = matchPropertyName_( ...
        currentPrototype, remaining);

    if ~isempty(actualProp)
        prop = actualProp;
        return;
    end
end

prop = remaining;
end

function actualProp = matchPropertyName_(obj, candidate)
actualProp = "";

if ~isgraphics(obj)
    return;
end

if isprop(obj, candidate)
    actualProp = char(candidate);
    return;
end

propNames = properties(obj);
index = find(strcmpi(propNames, candidate), 1);

if ~isempty(index)
    actualProp = propNames{index};
end
end

%% ============================================================
% Utilities
% ============================================================

function tf = isDescendant_(obj, ancestorObj)
tf = false;

if isempty(obj) || ...
        isempty(ancestorObj) || ...
        ~isgraphics(obj) || ...
        ~isgraphics(ancestorObj)
    return;
end

currentObj = obj;

while isgraphics(currentObj)
    if currentObj == ancestorObj
        tf = true;
        return;
    end

    if ~isprop(currentObj, "Parent")
        break;
    end

    currentObj = currentObj.Parent;
end
end

function tf = isSettable_(obj, propName)
tf = false;

try
    value = get(obj, propName);
    set(obj, propName, value);
    tf = true;
catch
end
end

function tf = isChildPropHandle_(obj, propToken)
tf = false;

if isempty(obj) || ...
        ~isgraphics(obj) || ...
        ~isprop(obj, propToken)
    return;
end

try
    childObj = obj.(propToken);
    tf = ~isempty(childObj) && all(isgraphics(childObj));
catch
    tf = false;
end
end

function childObj = getChildPropHandle_(obj, propToken)
try
    childObj = obj.(propToken);

    if isempty(childObj) || ...
            ~all(isgraphics(childObj))
        childObj = gobjects(0);
    end
catch
    childObj = gobjects(0);
end
end

function tf = isExcludedByRoots_(objs, exclusionRoots)
% True when an object is an exclusion root or a descendant of one.

if isempty(exclusionRoots)
    tf = false(size(objs));
    return;
end

tf = false(size(objs));

for objIndex = 1:numel(objs)
    currentObj = objs(objIndex);

    while isgraphics(currentObj)
        if any(currentObj == exclusionRoots)
            tf(objIndex) = true;
            break;
        end

        if ~isprop(currentObj, "Parent")
            break;
        end

        currentObj = currentObj.Parent;
    end
end
end

function defaultName = buildDefaultName_(targets, prop)
tokens = cellfun( ...
    @char, ...
    targets(:).', ...
    "UniformOutput", false);

defaultName = [ ...
    'Default', ...
    strjoin(tokens, ''), ...
    char(prop)];
end