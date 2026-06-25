function varargout = tiledlayout(varargin)
%TILEDLAYOUT Create tiledlayout with mu-style position control.
%
% This function is a lightweight wrapper of MATLAB built-in tiledlayout.
% It adds mu-style box-model controls for TiledChartLayout position:
%
%   margins  : outer space around the layout target box, relative to parent
%   paddings : inner space inside the margin box, relative to the margin box
%   nSize    : size of tiledlayout target box relative to drawable box
%   alignment: location of tiledlayout target box inside drawable box
%
% H5/CSS-like box model:
%
%   Parent
%   └── margins
%       └── margin box
%           └── paddings
%               └── drawable box
%                   └── tiledlayout target box
%
% By default, the target box controls tiledlayout.OuterPosition:
%
%   PositionType = "outerposition"  % default
%
% This means the visible tiledlayout region, including titles, tick labels,
% and other decorations managed by MATLAB, is constrained inside the green
% target box in the demo.
%
% You can switch to legacy inner-position behavior:
%
%   PositionType = "innerposition"
%
% SYNTAX:
%   t = mu.tiledlayout(row, col)
%   t = mu.tiledlayout(Parent, row, col)
%   t = mu.tiledlayout("flow")
%   t = mu.tiledlayout(Parent, "flow")
%   t = mu.tiledlayout(___, Name, Value)
%   [t, opts] = mu.tiledlayout(___)
%
% NOTES:
%   - MATLAB native "Padding" is different from mu-style "paddings".
%   - MATLAB native "TileSpacing", "Padding", and other native options are
%     forwarded to tiledlayout.
%   - When Parent is another tiledlayout, Position/OuterPosition cannot be
%     controlled by this function. Use Tile and TileSpan instead.

%% Basic input check

if isempty(varargin)
    error('mu.tiledlayout requires row/col or "flow" input.');
end

%% Extract optional parent

[Parent, args] = local_extractParent(varargin);

if isempty(args)
    error('mu.tiledlayout requires row/col or "flow" input after Parent.');
end

%% Parse layout specification

[layoutSpec, args] = local_parseLayoutSpec(args);

%% Parse mu-style options and keep native tiledlayout options

[muOpts, tileArgs] = local_parseMuOptions(args);

%% Add compact native defaults if not explicitly provided

tileArgs = local_addDefaultNativeOptions(tileArgs);

%% Resolve margins and paddings

margins  = muOpts.margins;
paddings = muOpts.paddings;

if ~isempty(muOpts.margin_left)  , margins(1) = muOpts.margin_left;   end
if ~isempty(muOpts.margin_right) , margins(2) = muOpts.margin_right;  end
if ~isempty(muOpts.margin_bottom), margins(3) = muOpts.margin_bottom; end
if ~isempty(muOpts.margin_top)   , margins(4) = muOpts.margin_top;    end

if ~isempty(muOpts.padding_left)  , paddings(1) = muOpts.padding_left;   end
if ~isempty(muOpts.padding_right) , paddings(2) = muOpts.padding_right;  end
if ~isempty(muOpts.padding_bottom), paddings(3) = muOpts.padding_bottom; end
if ~isempty(muOpts.padding_top)   , paddings(4) = muOpts.padding_top;    end

local_validateBoxVector(margins,  "margins");
local_validateBoxVector(paddings, "paddings");

%% Parse nSize

nSize = muOpts.nSize;
validateattributes(nSize, "numeric", {'vector', 'real', 'positive'});

if isscalar(nSize)
    nX = nSize;
    nY = nSize;
elseif numel(nSize) == 2
    nX = nSize(1);
    nY = nSize(2);
else
    error("nSize should be a scalar or a 2-element vector.");
end

%% Parse alignment

[alignment_horizontal, alignment_vertical, alignmentRaw] = ...
    local_parseAlignment(muOpts.alignment, ...
                         muOpts.alignment_horizontal, ...
                         muOpts.alignment_vertical);

%% Create tiledlayout
% Keep direct tiledlayout(...) call. In +mu/tiledlayout.m this resolves to
% MATLAB's native tiledlayout in the current MATLAB name-resolution context.

switch layoutSpec.mode
    case "fixed"
        t = tiledlayout(Parent, ...
            layoutSpec.row, layoutSpec.col, tileArgs{:});

    case "flow"
        t = tiledlayout(Parent, ...
            "flow", tileArgs{:});

    otherwise
        error("Invalid layout mode.");
end

t.Tag = "mu.tiledlayout";

%% Set tiledlayout target position using margins/paddings/nSize/alignment

isNestedTiledLayout = local_isTiledLayout(Parent);

if isNestedTiledLayout
    % MATLAB controls nested tiledlayout position through Layout.Tile and
    % Layout.TileSpan. Position and OuterPosition should not be used here.
    if ~isempty(muOpts.Tile)
        t.Layout.Tile = muOpts.Tile;
    end

    if ~isempty(muOpts.TileSpan)
        t.Layout.TileSpan = muOpts.TileSpan;
    end

    warning("mu:tiledlayout:PositionIgnoredForNestedTiledLayout", ...
        "Parent is a tiledlayout. Position/alignment options are ignored. Use Tile and TileSpan instead.");

    positionInfo = local_emptyPositionInfo();

else
    positionInfo = local_computeLayoutPosition( ...
        margins, paddings, nX, nY, ...
        alignment_horizontal, alignment_vertical);

    try
        t.Units = "normalized";
    catch
        % Some MATLAB versions may not expose Units for tiledlayout.
    end

    positionType = lower(string(muOpts.PositionType));

    switch positionType
        case "outerposition"
            % Recommended behavior:
            % The mu-computed target box corresponds to tiledlayout.OuterPosition.
            % MATLAB then shrinks the inner region as needed to accommodate
            % title, tick labels, labels, etc.
            try
                t.PositionConstraint = "outerposition";
            catch
            end

            try
                t.OuterPosition = positionInfo.position;
            catch
                % Fallback for MATLAB versions where OuterPosition cannot
                % be set. This falls back to inner-position behavior.
                warning("mu:tiledlayout:OuterPositionFallback", ...
                    "Could not set tiledlayout.OuterPosition. Falling back to tiledlayout.Position.");
                t.Position = positionInfo.position;
                positionType = "innerposition";
            end

        case {"innerposition", "position"}
            % Legacy behavior:
            % The mu-computed target box corresponds to tiledlayout.Position
            % or InnerPosition. Decorations may extend beyond the green box.
            try
                t.PositionConstraint = "innerposition";
            catch
            end

            t.Position = positionInfo.position;
            positionType = "innerposition";

        otherwise
            error("Invalid PositionType: %s.", positionType);
    end

    % User-provided PositionConstraint has final priority.
    % Use carefully: it may override the PositionType behavior above.
    if ~isempty(muOpts.PositionConstraint)
        t.PositionConstraint = muOpts.PositionConstraint;
    end

    muOpts.PositionType = positionType;
end

%% Optional debug annotation

if local_toLogical(muOpts.LayoutBox) && ~isNestedTiledLayout
    local_drawLayoutBox(ancestor(Parent, "figure"), positionInfo, muOpts);
end

%% Store useful layout info

opts = struct();

opts.parent = Parent;
opts.hostFigure = ancestor(Parent, "figure");

opts.layoutMode = layoutSpec.mode;

if layoutSpec.mode == "fixed"
    opts.row = layoutSpec.row;
    opts.col = layoutSpec.col;
    opts.gridSize = [layoutSpec.row, layoutSpec.col];
else
    opts.row = [];
    opts.col = [];
    opts.gridSize = [];
end

opts.margins = margins;
opts.paddings = paddings;

opts.marginsRatio = margins;
opts.paddingsRatio = paddings;

opts.nSize = [nX, nY];

opts.alignment = alignmentRaw;
opts.alignment_horizontal = alignment_horizontal;
opts.alignment_vertical = alignment_vertical;

opts.PositionType = string(muOpts.PositionType);
opts.PositionConstraint = muOpts.PositionConstraint;

opts.marginBoxPosition = positionInfo.marginBox;
opts.drawablePosition = positionInfo.drawableBox;

% The target box computed by mu.tiledlayout.
% If PositionType = "outerposition", this targets t.OuterPosition.
% If PositionType = "innerposition", this targets t.Position/InnerPosition.
opts.layoutTargetPosition = positionInfo.position;

% Backward-compatible alias.
opts.layoutPosition = positionInfo.position;

opts.tileArgs = tileArgs;
opts.tiledLayout = t;
opts.isNestedTiledLayout = isNestedTiledLayout;

% Actual MATLAB-managed positions after setting.
opts.actualPosition      = local_tryGetPosition(t, "Position");
opts.actualOuterPosition = local_tryGetPosition(t, "OuterPosition");
opts.actualInnerPosition = local_tryGetPosition(t, "InnerPosition");

try
    ud = t.UserData;
    if ~isstruct(ud)
        ud = struct();
    end
    ud.mu.tiledlayout = opts;
    t.UserData = ud;
catch
    % UserData assignment is useful but not essential.
end

%% Outputs

if nargout >= 1
    varargout{1} = t;
end

if nargout == 2
    varargout{2} = opts;
end

return;
end

%% Local functions

function [Parent, args] = local_extractParent(args)
%LOCAL_EXTRACTPARENT Extract optional first-position parent.
%
% Numeric figure handles are intentionally not accepted here, because
% mu.tiledlayout(2, 3) should always mean row=2, col=3.

if ~isempty(args) && local_isExplicitParent(args{1})
    Parent = args{1};
    args = args(2:end);
else
    Parent = gcf;
end

return;
end

function tf = local_isExplicitParent(x)
%LOCAL_ISEXPLICITPARENT True for supported object-style parent containers.

tf = isscalar(x) && ...
    (isa(x, "matlab.ui.Figure") || ...
     isa(x, "matlab.ui.container.Panel") || ...
     isa(x, "matlab.ui.container.Tab") || ...
     local_isTiledLayout(x));

return;
end

function tf = local_isTiledLayout(x)
%LOCAL_ISTILEDLAYOUT True for MATLAB tiledlayout parent.

tf = isscalar(x) && isa(x, "matlab.graphics.layout.TiledChartLayout");

return;
end

function [layoutSpec, args] = local_parseLayoutSpec(args)
%LOCAL_PARSELAYOUTSPEC Parse fixed or flow tiledlayout input.

if isempty(args)
    error("Missing tiledlayout layout specification.");
end

firstArg = args{1};

if local_isTextScalar(firstArg) && strcmpi(string(firstArg), "flow")
    layoutSpec = struct();
    layoutSpec.mode = "flow";
    layoutSpec.row = [];
    layoutSpec.col = [];

    args = args(2:end);
    return;
end

if numel(args) < 2
    error("Fixed tiledlayout mode requires row and col inputs.");
end

row = args{1};
col = args{2};

validateattributes(row, "numeric", {'scalar', 'positive', 'integer'});
validateattributes(col, "numeric", {'scalar', 'positive', 'integer'});

layoutSpec = struct();
layoutSpec.mode = "fixed";
layoutSpec.row = row;
layoutSpec.col = col;

args = args(3:end);

return;
end

function [muOpts, tileArgs] = local_parseMuOptions(args)
%LOCAL_PARSEMUOPTIONS Parse mu-specific options and keep native options.
%
% Unknown name-value pairs are passed to MATLAB tiledlayout unchanged.

if mod(numel(args), 2) ~= 0
    error("Name-value inputs should appear in pairs.");
end

muOpts = struct();

% mu-style layout options
muOpts.margins  = [0, 0, 0, 0];
muOpts.paddings = [0, 0, 0, 0];
muOpts.nSize    = [1, 1];

muOpts.alignment = "center";
muOpts.alignment_horizontal = [];
muOpts.alignment_vertical   = [];

muOpts.margin_left   = [];
muOpts.margin_right  = [];
muOpts.margin_bottom = [];
muOpts.margin_top    = [];

muOpts.padding_left   = [];
muOpts.padding_right  = [];
muOpts.padding_bottom = [];
muOpts.padding_top    = [];

% Nested tiledlayout options
muOpts.Tile = [];
muOpts.TileSpan = [];

% Debug options
muOpts.LayoutBox = "off";

% Position behavior
muOpts.PositionType = "outerposition";
muOpts.PositionConstraint = [];

tileArgs = {};

k = 1;
while k <= numel(args)
    name  = args{k};
    value = args{k + 1};

    if ~local_isTextScalar(name)
        error("Name-value option names should be text scalars.");
    end

    nameStr = lower(string(name));

    switch nameStr
        case "margins"
            validateattributes(value, "numeric", {'vector', 'real', 'numel', 4});
            muOpts.margins = double(value);

        case "paddings"
            validateattributes(value, "numeric", {'vector', 'real', 'numel', 4});
            muOpts.paddings = double(value);

        case "nsize"
            validateattributes(value, "numeric", {'vector', 'real', 'positive'});
            muOpts.nSize = double(value);

        case "alignment"
            muOpts.alignment = value;

        case "alignment_horizontal"
            muOpts.alignment_horizontal = value;

        case "alignment_vertical"
            muOpts.alignment_vertical = value;

        case "margin_left"
            validateattributes(value, "numeric", {'scalar', 'real'});
            muOpts.margin_left = double(value);

        case "margin_right"
            validateattributes(value, "numeric", {'scalar', 'real'});
            muOpts.margin_right = double(value);

        case "margin_bottom"
            validateattributes(value, "numeric", {'scalar', 'real'});
            muOpts.margin_bottom = double(value);

        case "margin_top"
            validateattributes(value, "numeric", {'scalar', 'real'});
            muOpts.margin_top = double(value);

        case "padding_left"
            validateattributes(value, "numeric", {'scalar', 'real'});
            muOpts.padding_left = double(value);

        case "padding_right"
            validateattributes(value, "numeric", {'scalar', 'real'});
            muOpts.padding_right = double(value);

        case "padding_bottom"
            validateattributes(value, "numeric", {'scalar', 'real'});
            muOpts.padding_bottom = double(value);

        case "padding_top"
            validateattributes(value, "numeric", {'scalar', 'real'});
            muOpts.padding_top = double(value);

        case "tile"
            validateattributes(value, "numeric", {'scalar', 'positive', 'integer'});
            muOpts.Tile = value;

        case "tilespan"
            validateattributes(value, "numeric", {'vector', 'positive', 'integer', 'numel', 2});
            muOpts.TileSpan = value;

        case {"layoutbox", "layout_box", "box"}
            muOpts.LayoutBox = value;

        case {"positiontype", "position_type"}
            muOpts.PositionType = validatestring(value, ...
                {'outerposition', 'innerposition', 'position'});

            if strcmpi(muOpts.PositionType, "position")
                muOpts.PositionType = "innerposition";
            end

        case "positionconstraint"
            muOpts.PositionConstraint = validatestring(value, ...
                {'outerposition', 'innerposition'});

        otherwise
            % Keep native MATLAB tiledlayout options, for example:
            %   "TileSpacing", "compact"
            %   "Padding", "compact"
            %   "TileIndexing", "rowmajor"
            % Do not convert these values to string, because some native
            % options can be numeric/logical/object values.
            tileArgs = [tileArgs, args(k:k+1)]; %#ok<AGROW>
    end

    k = k + 2;
end

return;
end

function tileArgs = local_addDefaultNativeOptions(tileArgs)
%LOCAL_ADDDEFAULTNATIVEOPTIONS Add compact defaults unless user supplied them.
%
% Keep tileArgs as a cell array and preserve value types.

if ~local_hasName(tileArgs, "TileSpacing")
    tileArgs = [{"TileSpacing", "compact"}, tileArgs];
end

if ~local_hasName(tileArgs, "Padding")
    tileArgs = [{"Padding", "compact"}, tileArgs];
end

return;
end

function tf = local_hasName(args, targetName)
%LOCAL_HASNAME True if name-value cell array contains a property name.

tf = false;

if isempty(args)
    return;
end

names = args(1:2:end);

for k = 1:numel(names)
    if local_isTextScalar(names{k}) && strcmpi(string(names{k}), targetName)
        tf = true;
        return;
    end
end

return;
end

function local_validateBoxVector(x, name)
%LOCAL_VALIDATEBOXVECTOR Validate [left, right, bottom, top].

validateattributes(x, "numeric", {'vector', 'real', 'numel', 4, 'nonnegative'});

assert(x(1) + x(2) < 1, ...
    "%s: left + right should be smaller than 1.", name);

assert(x(3) + x(4) < 1, ...
    "%s: bottom + top should be smaller than 1.", name);

return;
end

function [alignment_horizontal, alignment_vertical, alignmentRaw] = ...
    local_parseAlignment(alignment, alignment_horizontal, alignment_vertical)
%LOCAL_PARSEALIGNMENT Parse mu-style alignment options.

validAlignment = { ...
    'left-bottom', ...
    'left-center', ...
    'left-top', ...
    'center-bottom', ...
    'center', ...
    'center-top', ...
    'right-bottom', ...
    'right-center', ...
    'right-top'};

alignmentRaw = alignment;

if isnumeric(alignment)
    validateattributes(alignment, "numeric", {'vector', 'numel', 2, 'real'});
else
    alignment = validatestring(alignment, validAlignment);
end

if isnumeric(alignment_horizontal)
    if isempty(alignment_horizontal)
        if isnumeric(alignment)
            alignment_horizontal = alignment(1);
        else
            temp = split(string(alignment), "-");
            if isscalar(temp)
                alignment_horizontal = "center";
            else
                alignment_horizontal = temp(1);
            end
        end
    else
        validateattributes(alignment_horizontal, "numeric", {'scalar', 'real'});
    end
else
    alignment_horizontal = validatestring(alignment_horizontal, ...
        {'left', 'center', 'right'});
end

if isnumeric(alignment_vertical)
    if isempty(alignment_vertical)
        if isnumeric(alignment)
            alignment_vertical = alignment(2);
        else
            temp = split(string(alignment), "-");
            if isscalar(temp)
                alignment_vertical = "center";
            else
                alignment_vertical = temp(2);
            end
        end
    else
        validateattributes(alignment_vertical, "numeric", {'scalar', 'real'});
    end
else
    alignment_vertical = validatestring(alignment_vertical, ...
        {'bottom', 'center', 'top'});
end

return;
end

function info = local_computeLayoutPosition( ...
    margins, paddings, nX, nY, alignment_horizontal, alignment_vertical)
%LOCAL_COMPUTELAYOUTPOSITION Compute target tiledlayout box.
%
% Coordinate system is normalized parent coordinates.

marginBox = [ ...
    margins(1), ...
    margins(3), ...
    1 - margins(1) - margins(2), ...
    1 - margins(3) - margins(4)];

drawableBox = [ ...
    marginBox(1) + paddings(1) * marginBox(3), ...
    marginBox(2) + paddings(3) * marginBox(4), ...
    (1 - paddings(1) - paddings(2)) * marginBox(3), ...
    (1 - paddings(3) - paddings(4)) * marginBox(4)];

layoutW = drawableBox(3) * nX;
layoutH = drawableBox(4) * nY;

assert(layoutW <= drawableBox(3) + eps, ...
    "nSize(1) makes tiledlayout wider than drawable box.");
assert(layoutH <= drawableBox(4) + eps, ...
    "nSize(2) makes tiledlayout taller than drawable box.");

x = local_align1D( ...
    drawableBox(1), drawableBox(3), layoutW, alignment_horizontal, "horizontal");

y = local_align1D( ...
    drawableBox(2), drawableBox(4), layoutH, alignment_vertical, "vertical");

position = [x, y, layoutW, layoutH];

info = struct();
info.marginBox = marginBox;
info.drawableBox = drawableBox;
info.position = position;

return;
end

function start = local_align1D(boxStart, boxSize, itemSize, alignment, direction)
%LOCAL_ALIGN1D Align one dimension inside a box.
%
% Numeric positive alignment:
%   0   -> left/bottom
%   0.5 -> center
%   1   -> right/top
%
% Numeric negative alignment:
%   -1   -> left/bottom
%   -0.5 -> center
%   0    -> right/top

if isnumeric(alignment)
    if alignment >= 0
        ratio = alignment;
    else
        ratio = 1 + alignment;
    end

    start = boxStart + (boxSize - itemSize) * ratio;
    return;
end

alignment = string(alignment);

switch direction
    case "horizontal"
        switch alignment
            case "left"
                ratio = 0;
            case "center"
                ratio = 0.5;
            case "right"
                ratio = 1;
            otherwise
                error("Invalid horizontal alignment.");
        end

    case "vertical"
        switch alignment
            case "bottom"
                ratio = 0;
            case "center"
                ratio = 0.5;
            case "top"
                ratio = 1;
            otherwise
                error("Invalid vertical alignment.");
        end

    otherwise
        error("Invalid direction.");
end

start = boxStart + (boxSize - itemSize) * ratio;

return;
end

function info = local_emptyPositionInfo()
%LOCAL_EMPTYPOSITIONINFO Empty position info for nested tiledlayout mode.

info = struct();
info.marginBox = [];
info.drawableBox = [];
info.position = [];

return;
end

function pos = local_tryGetPosition(t, propName)
%LOCAL_TRYGETPOSITION Safely get a tiledlayout position-like property.

try
    pos = t.(propName);
catch
    pos = [];
end

return;
end

function local_drawLayoutBox(fig, positionInfo, muOpts)
%LOCAL_DRAWLAYOUTBOX Draw debug boxes using annotation.

if isempty(fig) || ~isvalid(fig)
    return;
end

marginBox   = positionInfo.marginBox;
drawableBox = positionInfo.drawableBox;
layoutPos   = positionInfo.position;

if isempty(marginBox) || isempty(drawableBox) || isempty(layoutPos)
    return;
end

annotation(fig, "rectangle", marginBox, ...
    "Color", [0.85, 0.20, 0.10], ...
    "LineStyle", "--", ...
    "LineWidth", 1.2);

annotation(fig, "rectangle", drawableBox, ...
    "Color", [0.10, 0.35, 0.85], ...
    "LineStyle", ":", ...
    "LineWidth", 1.2);

annotation(fig, "rectangle", layoutPos, ...
    "Color", [0.10, 0.60, 0.25], ...
    "LineStyle", "-", ...
    "LineWidth", 1.5);

switch lower(string(muOpts.PositionType))
    case "outerposition"
        label = "tiledlayout.OuterPosition";
    otherwise
        label = "tiledlayout.Position / InnerPosition";
end

annotation(fig, "textbox", ...
    [layoutPos(1), min(layoutPos(2) + layoutPos(4) + 0.005, 0.95), 0.35, 0.04], ...
    "String", label, ...
    "Color", [0.10, 0.60, 0.25], ...
    "EdgeColor", "none", ...
    "BackgroundColor", "w", ...
    "FontWeight", "bold");

if isfield(muOpts, "alignment")
    annotation(fig, "textbox", [0.02, 0.02, 0.52, 0.03], ...
        "String", sprintf("Alignment = %s controls %s inside drawable box", ...
        string(muOpts.alignment), label), ...
        "Color", [0.10, 0.60, 0.25], ...
        "EdgeColor", [0.10, 0.60, 0.25], ...
        "BackgroundColor", "w", ...
        "HorizontalAlignment", "center");
end

return;
end

function tf = local_isTextScalar(x)
%LOCAL_ISTEXTSCALAR True for char row vector or scalar string.

tf = (ischar(x) && (isrow(x) || isempty(x))) || ...
     (isstring(x) && isscalar(x));

return;
end

function tf = local_toLogical(x)
%LOCAL_TOLOGICAL Convert common on/off style inputs to logical.

if islogical(x)
    validateattributes(x, "logical", {'scalar'});
    tf = x;
    return;
end

if isnumeric(x)
    validateattributes(x, "numeric", {'scalar'});
    tf = logical(x);
    return;
end

if local_isTextScalar(x)
    x = lower(string(x));

    switch x
        case {"on", "show", "true", "yes", "1"}
            tf = true;

        case {"off", "hide", "false", "no", "0"}
            tf = false;

        otherwise
            error("Invalid logical option: %s.", x);
    end

    return;
end

try
    tf = x.toLogical;
catch
    error("Cannot convert input to logical.");
end

return;
end