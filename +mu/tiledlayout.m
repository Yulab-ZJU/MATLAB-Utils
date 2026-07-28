function varargout = tiledlayout(varargin)
%TILEDLAYOUT Create tiledlayout with mu-style position control.
%
% This function is a lightweight wrapper of MATLAB built-in tiledlayout.
% It adds mu-style box-model controls for TiledChartLayout position:
%
%   margins   : outer space around the layout target box, relative to parent
%   paddings  : inner space inside the margin box, relative to the margin box
%   nSize     : size of tiledlayout target box relative to drawable box
%   alignment : location of tiledlayout target box inside drawable box
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
% You can switch to legacy inner-position behavior:
%
%   PositionType = "innerposition"
%
% SYNTAX:
%   t = mu.tiledlayout(row, col)
%   t = mu.tiledlayout(Parent, row, col)
%   t = mu.tiledlayout("flow")
%   t = mu.tiledlayout("horizontal")
%   t = mu.tiledlayout("vertical")
%   t = mu.tiledlayout(Parent, arrangement)
%   t = mu.tiledlayout(___, Name, Value)
%   [t, opts] = mu.tiledlayout(___)
%
% arrangement:
%   "flow"       - automatically arrange tiles in rows and columns
%   "horizontal" - arrange tiles in a single horizontal row
%   "vertical"   - arrange tiles in a single vertical column
%
% NOTES:
%   - MATLAB native "Padding" is different from mu-style "paddings".
%   - MATLAB native "TileSpacing", "Padding", and other native options are
%     forwarded to tiledlayout.
%   - When Parent is another tiledlayout, Position/OuterPosition cannot be
%     controlled by this function. Use Tile and TileSpan instead.
%   - "horizontal" and "vertical" require a MATLAB release that supports
%     these native tiledlayout arrangements.

arguments (Repeating)
    varargin
end

%% Basic input check

if isempty(varargin)
    error(['mu.tiledlayout requires row/col or an arrangement input: ', ...
        '"flow", "horizontal", or "vertical".']);
end

%% Extract optional parent

[Parent, Args] = ExtractParent(varargin);

if isempty(Args)
    error(['mu.tiledlayout requires row/col or an arrangement input ', ...
        'after Parent: "flow", "horizontal", or "vertical".']);
end

%% Parse layout specification

[LayoutSpec, Args] = ParseLayoutSpec(Args);

%% Parse mu-style options and keep native tiledlayout options

[MuOpts, TileArgs] = ParseMuOptions(Args);

%% Add compact native defaults if not explicitly provided

TileArgs = AddDefaultNativeOptions(TileArgs);

%% Resolve margins and paddings

Margins = MuOpts.margins;
Paddings = MuOpts.paddings;

if ~isempty(MuOpts.margin_left)
    Margins(1) = MuOpts.margin_left;
end
if ~isempty(MuOpts.margin_right)
    Margins(2) = MuOpts.margin_right;
end
if ~isempty(MuOpts.margin_bottom)
    Margins(3) = MuOpts.margin_bottom;
end
if ~isempty(MuOpts.margin_top)
    Margins(4) = MuOpts.margin_top;
end

if ~isempty(MuOpts.padding_left)
    Paddings(1) = MuOpts.padding_left;
end
if ~isempty(MuOpts.padding_right)
    Paddings(2) = MuOpts.padding_right;
end
if ~isempty(MuOpts.padding_bottom)
    Paddings(3) = MuOpts.padding_bottom;
end
if ~isempty(MuOpts.padding_top)
    Paddings(4) = MuOpts.padding_top;
end

ValidateBoxVector(Margins, "margins");
ValidateBoxVector(Paddings, "paddings");

%% Parse nSize

NSize = MuOpts.nSize;
validateattributes(NSize, 'numeric', {'vector', 'real', 'positive'});

if isscalar(NSize)
    NX = NSize;
    NY = NSize;
elseif numel(NSize) == 2
    NX = NSize(1);
    NY = NSize(2);
else
    error("nSize should be a scalar or a 2-element vector.");
end

%% Parse alignment

[AlignmentHorizontal, AlignmentVertical, AlignmentRaw] = ...
    ParseAlignment(MuOpts.alignment, ...
                   MuOpts.alignment_horizontal, ...
                   MuOpts.alignment_vertical);

%% Create tiledlayout
% Keep the direct tiledlayout(...) call. In +mu/tiledlayout.m this resolves
% to MATLAB's native tiledlayout in the current name-resolution context.

switch LayoutSpec.mode
    case "fixed"
        T = tiledlayout(Parent, ...
            LayoutSpec.row, LayoutSpec.col, TileArgs{:});

    case {"flow", "horizontal", "vertical"}
        T = tiledlayout(Parent, LayoutSpec.mode, TileArgs{:});

    otherwise
        error("Invalid layout mode: %s.", LayoutSpec.mode);
end

T.Tag = "mu.tiledlayout";

%% Set tiledlayout target position using margins/paddings/nSize/alignment

IsNestedTiledLayout = IsTiledLayout(Parent);

if IsNestedTiledLayout
    % MATLAB controls nested tiledlayout position through Layout.Tile and
    % Layout.TileSpan. Position and OuterPosition should not be used here.
    if ~isempty(MuOpts.Tile)
        T.Layout.Tile = MuOpts.Tile;
    end

    if ~isempty(MuOpts.TileSpan)
        T.Layout.TileSpan = MuOpts.TileSpan;
    end

    warning("mu:tiledlayout:PositionIgnoredForNestedTiledLayout", ...
        "Parent is a tiledlayout. Position/alignment options are ignored. " + ...
        "Use Tile and TileSpan instead.");

    PositionInfo = EmptyPositionInfo();

else
    PositionInfo = ComputeLayoutPosition( ...
        Margins, Paddings, NX, NY, ...
        AlignmentHorizontal, AlignmentVertical);

    try
        T.Units = "normalized";
    catch
        % Some MATLAB versions may not expose Units for tiledlayout.
    end

    PositionType = lower(string(MuOpts.PositionType));

    switch PositionType
        case "outerposition"
            try
                T.PositionConstraint = "outerposition";
            catch
            end

            try
                T.OuterPosition = PositionInfo.position;
            catch
                warning("mu:tiledlayout:OuterPositionFallback", ...
                    "Could not set tiledlayout.OuterPosition. " + ...
                    "Falling back to tiledlayout.Position.");
                T.Position = PositionInfo.position;
                PositionType = "innerposition";
            end

        case {"innerposition", "position"}
            try
                T.PositionConstraint = "innerposition";
            catch
            end

            T.Position = PositionInfo.position;
            PositionType = "innerposition";

        otherwise
            error("Invalid PositionType: %s.", PositionType);
    end

    % User-provided PositionConstraint has final priority.
    if ~isempty(MuOpts.PositionConstraint)
        T.PositionConstraint = MuOpts.PositionConstraint;
    end

    MuOpts.PositionType = PositionType;
end

%% Optional debug annotation

if ToLogical(MuOpts.LayoutBox) && ~IsNestedTiledLayout
    DrawLayoutBox(ancestor(Parent, "figure"), PositionInfo, MuOpts);
end

%% Store useful layout info

Opts = struct();

Opts.parent = Parent;
Opts.hostFigure = ancestor(Parent, "figure");

Opts.layoutMode = LayoutSpec.mode;

if LayoutSpec.mode == "fixed"
    Opts.row = LayoutSpec.row;
    Opts.col = LayoutSpec.col;
    Opts.gridSize = [LayoutSpec.row, LayoutSpec.col];
else
    Opts.row = [];
    Opts.col = [];
    Opts.gridSize = [];
end

Opts.margins = Margins;
Opts.paddings = Paddings;

Opts.marginsRatio = Margins;
Opts.paddingsRatio = Paddings;

Opts.nSize = [NX, NY];

Opts.alignment = AlignmentRaw;
Opts.alignment_horizontal = AlignmentHorizontal;
Opts.alignment_vertical = AlignmentVertical;

Opts.PositionType = string(MuOpts.PositionType);
Opts.PositionConstraint = MuOpts.PositionConstraint;

Opts.marginBoxPosition = PositionInfo.marginBox;
Opts.drawablePosition = PositionInfo.drawableBox;

Opts.layoutTargetPosition = PositionInfo.position;

% Backward-compatible alias.
Opts.layoutPosition = PositionInfo.position;

Opts.tileArgs = TileArgs;
Opts.tiledLayout = T;
Opts.isNestedTiledLayout = IsNestedTiledLayout;

% Actual MATLAB-managed positions after setting.
Opts.actualPosition = TryGetPosition(T, "Position");
Opts.actualOuterPosition = TryGetPosition(T, "OuterPosition");
Opts.actualInnerPosition = TryGetPosition(T, "InnerPosition");

try
    UserData = T.UserData;
    if ~isstruct(UserData)
        UserData = struct();
    end
    UserData.mu.tiledlayout = Opts;
    T.UserData = UserData;
catch
    % UserData assignment is useful but not essential.
end

%% Outputs

if nargout >= 1
    varargout{1} = T;
end

if nargout == 2
    varargout{2} = Opts;
end

end

%% Local functions

function [Parent, Args] = ExtractParent(Args)
%EXTRACTPARENT Extract optional first-position parent.
%
% Numeric figure handles are intentionally not accepted here, because
% mu.tiledlayout(2, 3) should always mean row=2, col=3.

if ~isempty(Args) && IsExplicitParent(Args{1})
    Parent = Args{1};
    Args = Args(2:end);
else
    Parent = gcf;
end

end

function TF = IsExplicitParent(X)
%ISEXPLICITPARENT True for supported object-style parent containers.

TF = isscalar(X) && ...
    (isa(X, "matlab.ui.Figure") || ...
     isa(X, "matlab.ui.container.Panel") || ...
     isa(X, "matlab.ui.container.Tab") || ...
     IsTiledLayout(X));

end

function TF = IsTiledLayout(X)
%ISTILEDLAYOUT True for MATLAB tiledlayout parent.

TF = isscalar(X) && ...
    isa(X, "matlab.graphics.layout.TiledChartLayout");

end

function [LayoutSpec, Args] = ParseLayoutSpec(Args)
%PARSELAYOUTSPEC Parse fixed or adaptive tiledlayout input.

if isempty(Args)
    error("Missing tiledlayout layout specification.");
end

FirstArg = Args{1};

if IsTextScalar(FirstArg)
    Arrangement = lower(string(FirstArg));
    ValidArrangements = ["flow", "horizontal", "vertical"];

    if any(Arrangement == ValidArrangements)
        LayoutSpec = struct();
        LayoutSpec.mode = Arrangement;
        LayoutSpec.row = [];
        LayoutSpec.col = [];

        Args = Args(2:end);
        return;
    end

    error('Invalid tiledlayout arrangement "%s". Valid arrangements are ', ...
        '"flow", "horizontal", and "vertical".', Arrangement);
end

if numel(Args) < 2
    error(['Fixed tiledlayout mode requires row and col inputs, or use ', ...
        '"flow", "horizontal", or "vertical".']);
end

Row = Args{1};
Col = Args{2};

validateattributes(Row, 'numeric', {'scalar', 'positive', 'integer'});
validateattributes(Col, 'numeric', {'scalar', 'positive', 'integer'});

LayoutSpec = struct();
LayoutSpec.mode = "fixed";
LayoutSpec.row = Row;
LayoutSpec.col = Col;

Args = Args(3:end);

end

function [MuOpts, TileArgs] = ParseMuOptions(Args)
%PARSEMUOPTIONS Parse mu-specific options and keep native options.
%
% Unknown name-value pairs are passed to MATLAB tiledlayout unchanged.

if mod(numel(Args), 2) ~= 0
    error("Name-value inputs should appear in pairs.");
end

MuOpts = struct();

% mu-style layout options
MuOpts.margins = [0, 0, 0, 0];
MuOpts.paddings = [0, 0, 0, 0];
MuOpts.nSize = [1, 1];

MuOpts.alignment = "center";
MuOpts.alignment_horizontal = [];
MuOpts.alignment_vertical = [];

MuOpts.margin_left = [];
MuOpts.margin_right = [];
MuOpts.margin_bottom = [];
MuOpts.margin_top = [];

MuOpts.padding_left = [];
MuOpts.padding_right = [];
MuOpts.padding_bottom = [];
MuOpts.padding_top = [];

% Nested tiledlayout options
MuOpts.Tile = [];
MuOpts.TileSpan = [];

% Debug options
MuOpts.LayoutBox = "off";

% Position behavior
MuOpts.PositionType = "outerposition";
MuOpts.PositionConstraint = [];

TileArgs = {};

K = 1;
while K <= numel(Args)
    Name = Args{K};
    Value = Args{K + 1};

    if ~IsTextScalar(Name)
        error("Name-value option names should be text scalars.");
    end

    NameStr = lower(string(Name));

    switch NameStr
        case "margins"
            validateattributes(Value, 'numeric', ...
                {'vector', 'real', 'numel', 4});
            MuOpts.margins = double(Value);

        case "paddings"
            validateattributes(Value, 'numeric', ...
                {'vector', 'real', 'numel', 4});
            MuOpts.paddings = double(Value);

        case "nsize"
            validateattributes(Value, 'numeric', ...
                {'vector', 'real', 'positive'});
            MuOpts.nSize = double(Value);

        case "alignment"
            MuOpts.alignment = Value;

        case "alignment_horizontal"
            MuOpts.alignment_horizontal = Value;

        case "alignment_vertical"
            MuOpts.alignment_vertical = Value;

        case "margin_left"
            validateattributes(Value, 'numeric', {'scalar', 'real'});
            MuOpts.margin_left = double(Value);

        case "margin_right"
            validateattributes(Value, 'numeric', {'scalar', 'real'});
            MuOpts.margin_right = double(Value);

        case "margin_bottom"
            validateattributes(Value, 'numeric', {'scalar', 'real'});
            MuOpts.margin_bottom = double(Value);

        case "margin_top"
            validateattributes(Value, 'numeric', {'scalar', 'real'});
            MuOpts.margin_top = double(Value);

        case "padding_left"
            validateattributes(Value, 'numeric', {'scalar', 'real'});
            MuOpts.padding_left = double(Value);

        case "padding_right"
            validateattributes(Value, 'numeric', {'scalar', 'real'});
            MuOpts.padding_right = double(Value);

        case "padding_bottom"
            validateattributes(Value, 'numeric', {'scalar', 'real'});
            MuOpts.padding_bottom = double(Value);

        case "padding_top"
            validateattributes(Value, 'numeric', {'scalar', 'real'});
            MuOpts.padding_top = double(Value);

        case "tile"
            validateattributes(Value, 'numeric', ...
                {'scalar', 'positive', 'integer'});
            MuOpts.Tile = Value;

        case "tilespan"
            validateattributes(Value, 'numeric', ...
                {'vector', 'positive', 'integer', 'numel', 2});
            MuOpts.TileSpan = Value;

        case {"layoutbox", "layout_box", "box"}
            MuOpts.LayoutBox = Value;

        case {"positiontype", "position_type"}
            MuOpts.PositionType = validatestring(Value, ...
                {'outerposition', 'innerposition', 'position'});

            if strcmpi(MuOpts.PositionType, "position")
                MuOpts.PositionType = "innerposition";
            end

        case "positionconstraint"
            MuOpts.PositionConstraint = validatestring(Value, ...
                {'outerposition', 'innerposition'});

        otherwise
            % Keep native MATLAB tiledlayout options unchanged.
            TileArgs = [TileArgs, Args(K:K + 1)]; %#ok<AGROW>
    end

    K = K + 2;
end

end

function TileArgs = AddDefaultNativeOptions(TileArgs)
%ADDDEFAULTNATIVEOPTIONS Add compact defaults unless supplied by the user.

if ~HasName(TileArgs, "TileSpacing")
    TileArgs = [{"TileSpacing", "compact"}, TileArgs];
end

if ~HasName(TileArgs, "Padding")
    TileArgs = [{"Padding", "compact"}, TileArgs];
end

end

function TF = HasName(Args, TargetName)
%HASNAME True if name-value cell array contains a property name.

TF = false;

if isempty(Args)
    return;
end

Names = Args(1:2:end);

for K = 1:numel(Names)
    if IsTextScalar(Names{K}) && strcmpi(string(Names{K}), TargetName)
        TF = true;
        return;
    end
end

end

function ValidateBoxVector(X, Name)
%VALIDATEBOXVECTOR Validate [left, right, bottom, top].

validateattributes(X, 'numeric', ...
    {'vector', 'real', 'numel', 4, 'nonnegative'});

assert(X(1) + X(2) < 1, ...
    "%s: left + right should be smaller than 1.", Name);

assert(X(3) + X(4) < 1, ...
    "%s: bottom + top should be smaller than 1.", Name);

end

function [AlignmentHorizontal, AlignmentVertical, AlignmentRaw] = ...
    ParseAlignment(Alignment, AlignmentHorizontal, AlignmentVertical)
%PARSEALIGNMENT Parse mu-style alignment options.

ValidAlignment = { ...
    'left-bottom', ...
    'left-center', ...
    'left-top', ...
    'center-bottom', ...
    'center', ...
    'center-top', ...
    'right-bottom', ...
    'right-center', ...
    'right-top'};

AlignmentRaw = Alignment;

if isnumeric(Alignment)
    validateattributes(Alignment, 'numeric', ...
        {'vector', 'numel', 2, 'real'});
else
    Alignment = validatestring(Alignment, ValidAlignment);
end

if isnumeric(AlignmentHorizontal)
    if isempty(AlignmentHorizontal)
        if isnumeric(Alignment)
            AlignmentHorizontal = Alignment(1);
        else
            Temp = split(string(Alignment), "-");
            if isscalar(Temp)
                AlignmentHorizontal = "center";
            else
                AlignmentHorizontal = Temp(1);
            end
        end
    else
        validateattributes(AlignmentHorizontal, 'numeric', ...
            {'scalar', 'real'});
    end
else
    AlignmentHorizontal = validatestring(AlignmentHorizontal, ...
        {'left', 'center', 'right'});
end

if isnumeric(AlignmentVertical)
    if isempty(AlignmentVertical)
        if isnumeric(Alignment)
            AlignmentVertical = Alignment(2);
        else
            Temp = split(string(Alignment), "-");
            if isscalar(Temp)
                AlignmentVertical = "center";
            else
                AlignmentVertical = Temp(2);
            end
        end
    else
        validateattributes(AlignmentVertical, 'numeric', ...
            {'scalar', 'real'});
    end
else
    AlignmentVertical = validatestring(AlignmentVertical, ...
        {'bottom', 'center', 'top'});
end

end

function Info = ComputeLayoutPosition( ...
    Margins, Paddings, NX, NY, AlignmentHorizontal, AlignmentVertical)
%COMPUTELAYOUTPOSITION Compute target tiledlayout box.
%
% Coordinate system is normalized parent coordinates.

MarginBox = [ ...
    Margins(1), ...
    Margins(3), ...
    1 - Margins(1) - Margins(2), ...
    1 - Margins(3) - Margins(4)];

DrawableBox = [ ...
    MarginBox(1) + Paddings(1) * MarginBox(3), ...
    MarginBox(2) + Paddings(3) * MarginBox(4), ...
    (1 - Paddings(1) - Paddings(2)) * MarginBox(3), ...
    (1 - Paddings(3) - Paddings(4)) * MarginBox(4)];

LayoutW = DrawableBox(3) * NX;
LayoutH = DrawableBox(4) * NY;

assert(LayoutW <= DrawableBox(3) + eps, ...
    "nSize(1) makes tiledlayout wider than drawable box.");

assert(LayoutH <= DrawableBox(4) + eps, ...
    "nSize(2) makes tiledlayout taller than drawable box.");

X = Align1D( ...
    DrawableBox(1), DrawableBox(3), LayoutW, ...
    AlignmentHorizontal, "horizontal");

Y = Align1D( ...
    DrawableBox(2), DrawableBox(4), LayoutH, ...
    AlignmentVertical, "vertical");

Position = [X, Y, LayoutW, LayoutH];

Info = struct();
Info.marginBox = MarginBox;
Info.drawableBox = DrawableBox;
Info.position = Position;

end

function Start = Align1D(BoxStart, BoxSize, ItemSize, Alignment, Direction)
%ALIGN1D Align one dimension inside a box.
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

if isnumeric(Alignment)
    if Alignment >= 0
        Ratio = Alignment;
    else
        Ratio = 1 + Alignment;
    end

    Start = BoxStart + (BoxSize - ItemSize) * Ratio;
    return;
end

Alignment = string(Alignment);

switch Direction
    case "horizontal"
        switch Alignment
            case "left"
                Ratio = 0;
            case "center"
                Ratio = 0.5;
            case "right"
                Ratio = 1;
            otherwise
                error("Invalid horizontal alignment.");
        end

    case "vertical"
        switch Alignment
            case "bottom"
                Ratio = 0;
            case "center"
                Ratio = 0.5;
            case "top"
                Ratio = 1;
            otherwise
                error("Invalid vertical alignment.");
        end

    otherwise
        error("Invalid direction.");
end

Start = BoxStart + (BoxSize - ItemSize) * Ratio;

end

function Info = EmptyPositionInfo()
%EMPTYPOSITIONINFO Empty position info for nested tiledlayout mode.

Info = struct();
Info.marginBox = [];
Info.drawableBox = [];
Info.position = [];

end

function Position = TryGetPosition(T, PropertyName)
%TRYGETPOSITION Safely get a tiledlayout position-like property.

try
    Position = T.(PropertyName);
catch
    Position = [];
end

end

function DrawLayoutBox(FigureHandle, PositionInfo, MuOpts)
%DRAWLAYOUTBOX Draw debug boxes using annotation.

if isempty(FigureHandle) || ~isvalid(FigureHandle)
    return;
end

MarginBox = PositionInfo.marginBox;
DrawableBox = PositionInfo.drawableBox;
LayoutPosition = PositionInfo.position;

if isempty(MarginBox) || isempty(DrawableBox) || isempty(LayoutPosition)
    return;
end

annotation(FigureHandle, "rectangle", MarginBox, ...
    "Color", [0.85, 0.20, 0.10], ...
    "LineStyle", "--", ...
    "LineWidth", 1.2);

annotation(FigureHandle, "rectangle", DrawableBox, ...
    "Color", [0.10, 0.35, 0.85], ...
    "LineStyle", ":", ...
    "LineWidth", 1.2);

annotation(FigureHandle, "rectangle", LayoutPosition, ...
    "Color", [0.10, 0.60, 0.25], ...
    "LineStyle", "-", ...
    "LineWidth", 1.5);

switch lower(string(MuOpts.PositionType))
    case "outerposition"
        Label = "tiledlayout.OuterPosition";
    otherwise
        Label = "tiledlayout.Position / InnerPosition";
end

annotation(FigureHandle, "textbox", ...
    [LayoutPosition(1), ...
     min(LayoutPosition(2) + LayoutPosition(4) + 0.005, 0.95), ...
     0.35, 0.04], ...
    "String", Label, ...
    "Color", [0.10, 0.60, 0.25], ...
    "EdgeColor", "none", ...
    "BackgroundColor", "w", ...
    "FontWeight", "bold");

if isfield(MuOpts, "alignment")
    annotation(FigureHandle, "textbox", [0.02, 0.02, 0.52, 0.03], ...
        "String", sprintf( ...
            "Alignment = %s controls %s inside drawable box", ...
            string(MuOpts.alignment), Label), ...
        "Color", [0.10, 0.60, 0.25], ...
        "EdgeColor", [0.10, 0.60, 0.25], ...
        "BackgroundColor", "w", ...
        "HorizontalAlignment", "center");
end

end

function TF = IsTextScalar(X)
%ISTEXTSCALAR True for char row vector or scalar string.

TF = (ischar(X) && (isrow(X) || isempty(X))) || ...
     (isstring(X) && isscalar(X));

end

function TF = ToLogical(X)
%TOLOGICAL Convert common on/off style inputs to logical.

if islogical(X)
    validateattributes(X, 'logical', {'scalar'});
    TF = X;
    return;
end

if isnumeric(X)
    validateattributes(X, 'numeric', {'scalar'});
    TF = logical(X);
    return;
end

if IsTextScalar(X)
    X = lower(string(X));

    switch X
        case {"on", "show", "true", "yes", "1"}
            TF = true;

        case {"off", "hide", "false", "no", "0"}
            TF = false;

        otherwise
            error("Invalid logical option: %s.", X);
    end

    return;
end

try
    TF = X.toLogical;
catch
    error("Cannot convert input to logical.");
end

end
