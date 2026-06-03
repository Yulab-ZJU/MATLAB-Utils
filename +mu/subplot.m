function varargout = subplot(varargin)
%SUBPLOT Advanced subplot function.
%
% This function creates axes with more flexible control than MATLAB built-in
% subplot. It divides a parent container into row-by-column "div" regions,
% and then places one axes object inside the selected div.
%
% H5/CSS-like box model:
%
%   figure/parent
%   └── margin area
%       └── div
%           └── padding area
%               └── axes
%
% In this function:
%   margins  : outer space around the whole subplot grid, relative to parent
%   paddings : inner space inside each div, relative to div
%
% FEATURES:
%   1) Spanning index:
%
%      index = scalar
%          MATLAB-style linear index.
%
%      index = [rowIndex, colIndex]
%          Row-column index.
%
%      index = [rowStart, colStart, rowSpan, colSpan]
%          Explicit spanning index.
%
%      index = linearIndexVector
%          MATLAB-style multiple linear indices. The indices must form a
%          rectangular block. For example, in a 3-by-4 grid:
%             [1, 2, 5, 6] spans rows 1:2 and columns 1:2 when TileIndexing
%             is "rowmajor".
%
%      Because [1, 2] is ambiguous, auto mode keeps backward compatibility
%      and treats it as [rowIndex, colIndex]. Use:
%             "indexMode", "linear"
%      if you want [1, 2] to mean linear tiles 1 and 2.
%
%   2) Parent can be a tiledlayout object:
%
%      t = tiledlayout(2, 3);
%      ax = mu.subplot(t, 2, 3, [1, 1, 2, 2]);   % compatible syntax
%      ax = mu.subplot(t, [1, 1, 2, 2]);         % shorthand syntax
%
%      In tiledlayout mode, axes are created by nexttile. Therefore MATLAB's
%      tiledlayout engine controls positions. The following options are
%      parsed but not applied to axes position:
%         margins, paddings, nSize, shape, alignment, divBox, PositionType.
%
%      For shorthand syntax, row/col are inferred from t.GridSize. This
%      requires a fixed tiledlayout. For flow tiledlayout or when GridSize
%      cannot be inferred, use the compatible syntax with row/col.
%
%   3) PositionType for manual-position mode:
%
%      "PositionType", "position"
%          Backward-compatible behavior. The computed box is assigned to
%          ax.Position.
%
%      "PositionType", "outerposition"
%          The computed box is assigned to ax.OuterPosition. This keeps
%          xlabel/ylabel/title/tick labels inside the allocated subplot box
%          more effectively and reduces overlap between neighboring panels.
%
% INPUTS:
% REQUIRED:
%   row/col/index - Same usage as MATLAB built-in subplot, with additional
%                   spanning index support.
%
% OPTIONAL:
%   Parent - Figure handle or tiledlayout object. If omitted, gcf is used.
%
% NAME-VALUE:
%   nSize - [nX, nY] specifies size of axes. Default: [1, 1].
%           nSize is relative to the drawable area inside each div.
%
%   margins - Margins specified as [left, right, bottom, top].
%             Margins are outer spaces around the whole subplot grid,
%             relative to figure. Default: [0.03, 0.03, 0.08, 0.05].
%
%   paddings - Paddings specified as [left, right, bottom, top].
%              Paddings are inner spaces inside each subplot div,
%              relative to div. Default: [0.05, 0.05, 0.08, 0.05].
%
%   shape - 'auto'(default), 'square-min', 'square-max', or 'fill'.
%           Option 'fill' fills the whole div and ignores paddings/nSize,
%           but keeps margins.
%
%   alignment - How axes aligns to the div. It can be either a preset string
%               or a 2-element numeric vector that specifies axes center
%               [x, y] relative to the padded div area.
%
%   indexMode - 'auto'(default), 'linear', 'subscript', or 'span'.
%
%   PositionType - 'position'(default) or 'outerposition'.
%                  In manual-position mode, this controls whether the
%                  computed target box is assigned to ax.Position or
%                  ax.OuterPosition.
%
%   divBox - Show div box. Default: "hide".
%
% OUTPUTS:
%   ax   - Subplot axes object.
%   opts - Subplot options and computed positions.
%
% NOTES:
%   - All position parameters are normalized in normal figure mode.
%   - In tiledlayout mode, MATLAB controls axes layout through nexttile.
%   - In tiledlayout mode, ax.Position is normalized to the parent
%     tiledlayout inner coordinate system, not directly to the figure.

%% Parameter validation

if isempty(varargin)
    error('mu.subplot requires at least row, col, and index inputs.');
end

% Extract optional parent.
% Supported explicit first argument:
%   mu.subplot(Fig, row, col, index, ...)
%   mu.subplot(tiledLayoutObj, row, col, index, ...)
%   mu.subplot(tiledLayoutObj, index, ...)
%
% Numeric figure handles are intentionally not treated as parents here,
% because mu.subplot(1, 2, 3) should still mean row=1, col=2, index=3.
[Parent, varargin] = local_extractParent(varargin);

% Shorthand for tiledlayout parent:
%   mu.subplot(t, index, Name, Value, ...)
% is expanded to:
%   mu.subplot(t, row, col, index, Name, Value, ...)
% where [row, col] are inferred from t.GridSize.
if local_isTiledLayout(Parent)
    varargin = local_expandTiledLayoutShorthand(Parent, varargin);
end

if numel(varargin) < 3
    error("mu.subplot requires inputs: row, col, index, or Parent, row, col, index. For tiledlayout parent, mu.subplot(t, index, ...) is also supported.");
end

mIp = inputParser;

mIp.addRequired("Parent", @local_isValidParent);
mIp.addRequired("row", @(x) validateattributes(x, 'numeric', {'numel', 1, 'positive', 'integer'}));
mIp.addRequired("col", @(x) validateattributes(x, 'numeric', {'numel', 1, 'positive', 'integer'}));
mIp.addRequired("index", @(x) validateattributes(x, 'numeric', {'vector', 'positive', 'integer'}));

% Positional optional inputs are kept for backward calling style:
% mu.subplot(row, col, index, nSize, margins, paddings, shape)
mIp.addOptional("nSize0", [], @(x) validateattributes(x, 'numeric', {'vector', 'real'}));
mIp.addOptional("margins0", [], @(x) validateattributes(x, 'numeric', {'vector', 'real', 'numel', 4}));
mIp.addOptional("paddings0", [], @(x) validateattributes(x, 'numeric', {'vector', 'real', 'numel', 4}));
mIp.addOptional("shape0", [], @mustBeTextScalar);

mIp.addParameter("nSize", [1, 1], @(x) validateattributes(x, 'numeric', {'vector', 'real'}));

% H5/CSS-like definition:
%   margins  -> outer space around grid, relative to figure
%   paddings -> inner space inside div, relative to div
mIp.addParameter("margins", [0.03, 0.03, 0.08, 0.05], @(x) validateattributes(x, 'numeric', {'vector', 'real', 'numel', 4}));
mIp.addParameter("paddings", [0.05, 0.05, 0.08, 0.05], @(x) validateattributes(x, 'numeric', {'vector', 'real', 'numel', 4}));

mIp.addParameter("shape", "auto", @mustBeTextScalar);
mIp.addParameter("indexMode", "auto", @mustBeTextScalar);

% In manual-position mode:
%   "position"      -> computed target box is assigned to ax.Position
%   "outerposition" -> computed target box is assigned to ax.OuterPosition
%
% In tiledlayout mode, this option is parsed but ignored because nexttile
% manages axes positions.
mIp.addParameter("PositionType", "position", @mustBeTextScalar);

mIp.addParameter("alignment"           , "center", @(x) isnumeric(x) || mu.isTextScalar(x));
mIp.addParameter("alignment_horizontal", []      , @(x) isnumeric(x) || mu.isTextScalar(x));
mIp.addParameter("alignment_vertical"  , []      , @(x) isnumeric(x) || mu.isTextScalar(x));

mIp.addParameter("margin_left"  , [], @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("margin_right" , [], @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("margin_bottom", [], @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("margin_top"   , [], @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));

mIp.addParameter("padding_left"  , [], @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("padding_right" , [], @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("padding_bottom", [], @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("padding_top"   , [], @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));

mIp.addParameter("divBox", mu.OptionState.Off, @mu.OptionState.validate);

mIp.parse(Parent, varargin{:});

%% Parent and grid size

Parent = mIp.Results.Parent;
row    = mIp.Results.row;
col    = mIp.Results.col;
index  = mIp.Results.index;

isTiledParent = local_isTiledLayout(Parent);
HostFig = local_getHostFigure(Parent);

indexMode = validatestring(mIp.Results.indexMode, ...
    {'auto', 'linear', 'subscript', 'span'});

tileIndexing = local_getTileIndexing(Parent);

indexInfo = local_parseGridIndex(index, row, col, indexMode, tileIndexing);

rIndex = indexInfo.rStart;
cIndex = indexInfo.cStart;
rSpan  = indexInfo.rSpan;
cSpan  = indexInfo.cSpan;

%% Alignment

validShape = {'auto', 'square-min', 'square-max', 'fill'};

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

alignment = mIp.Results.alignment;

if isnumeric(alignment)
    validateattributes(alignment, 'numeric', {'numel', 2, 'real'});
else
    alignment = validatestring(alignment, validAlignment);
end

alignment_horizontal = mIp.Results.alignment_horizontal;

if isnumeric(alignment_horizontal)
    if isempty(alignment_horizontal)
        if isnumeric(alignment)
            alignment_horizontal = alignment(1);
        else
            temp = split(alignment, '-');
            alignment_horizontal = mu.ifelse(isscalar(temp), 0.5, temp{1});
        end
    else
        validateattributes(alignment_horizontal, 'numeric', {'scalar', 'real'});
    end
else
    alignment_horizontal = validatestring(alignment_horizontal, {'left', 'center', 'right'});
end

alignment_vertical = mIp.Results.alignment_vertical;

if isnumeric(alignment_vertical)
    if isempty(alignment_vertical)
        if isnumeric(alignment)
            alignment_vertical = alignment(2);
        else
            temp = split(alignment, '-');
            alignment_vertical = mu.ifelse(isscalar(temp), 0.5, @() temp{2});
        end
    else
        validateattributes(alignment_vertical, 'numeric', {'scalar', 'real'});
    end
else
    alignment_vertical = validatestring(alignment_vertical, {'bottom', 'center', 'top'});
end

%% Axes scaling

nSize = mu.getor(mIp.Results, "nSize0", mIp.Results.nSize, true);

nX = nSize(1);

if isscalar(nSize)
    nY = nSize(1);
elseif numel(nSize) == 2
    nY = nSize(2);
else
    error('Size should be a scalar or a 2-element vector.');
end

if isempty(mIp.Results.shape0)
    shape = validatestring(mIp.Results.shape, validShape);
else
    shape = validatestring(mIp.Results.shape0, validShape);
end

positionType = validatestring(mIp.Results.PositionType, ...
    {'position', 'outerposition'});

%% Margins and paddings

margins  = mu.getor(mIp.Results, "margins0" , mIp.Results.margins , true);
paddings = mu.getor(mIp.Results, "paddings0", mIp.Results.paddings, true);

margin_left   = mIp.Results.margin_left;
margin_right  = mIp.Results.margin_right;
margin_bottom = mIp.Results.margin_bottom;
margin_top    = mIp.Results.margin_top;

padding_left   = mIp.Results.padding_left;
padding_right  = mIp.Results.padding_right;
padding_bottom = mIp.Results.padding_bottom;
padding_top    = mIp.Results.padding_top;

% Individual margin settings overwrite the corresponding value in margins.
if ~isempty(margin_left)  , margins(1) = margin_left;   end
if ~isempty(margin_right) , margins(2) = margin_right;  end
if ~isempty(margin_bottom), margins(3) = margin_bottom; end
if ~isempty(margin_top)   , margins(4) = margin_top;    end

% Individual padding settings overwrite the corresponding value in paddings.
if ~isempty(padding_left)  , paddings(1) = padding_left;   end
if ~isempty(padding_right) , paddings(2) = padding_right;  end
if ~isempty(padding_bottom), paddings(3) = padding_bottom; end
if ~isempty(padding_top)   , paddings(4) = padding_top;    end

local_validateBoxVector(margins,  "margins");
local_validateBoxVector(paddings, "paddings");

%% Show div box option

divBox = mu.OptionState.create(mIp.Results.divBox);

%% TiledLayout mode

if isTiledParent
    % In tiledlayout mode, MATLAB owns the axes position. Therefore, we use
    % nexttile and do not apply normalized Position, margins, paddings,
    % nSize, shape, alignment, or PositionType.

    local_checkTiledGridSize(Parent, row, col);

    tileIndex = indexInfo.tileIndex;
    tileSpan  = [rSpan, cSpan];

    if rSpan == 1 && cSpan == 1
        ax = nexttile(Parent, tileIndex);
    else
        ax = nexttile(Parent, tileIndex, tileSpan);
    end

    if divBox.toLogical
        warning("mu:subplot:TiledLayoutDivBoxIgnored", ...
            "divBox is ignored when Parent is a tiledlayout object.");
    end

    if nargout >= 1
        varargout{1} = ax;
    end

    if nargout == 2
        opts = local_createBaseOpts( ...
            Parent, HostFig, row, col, index, indexMode, tileIndexing, indexInfo, ...
            margins, paddings, nSize, shape);

        opts.layoutMode = "tiledlayout";
        opts.tileIndex = tileIndex;
        opts.tileSpan = tileSpan;
        opts.tiledLayout = Parent;

        % Position is controlled by tiledlayout/nexttile.
        % Do not fabricate manual-position metrics here.
        opts.PositionType = string(positionType);
        opts.PositionTypeApplied = "ignored";
        opts.positionUnits = "tiledlayout-managed";
        opts.positionControlledBy = "tiledlayout/nexttile";

        % Raw axes positions from MATLAB.
        % For axes inside tiledlayout, ax.Position and ax.OuterPosition are
        % normalized to the parent tiledlayout inner coordinate system, not
        % directly to the figure.
        opts.axesPosition = ax.Position;
        opts.axesOuterPosition = ax.OuterPosition;
        opts.axesPositionReference = "Parent tiledlayout Position/InnerPosition";
        opts.axesPositionIsFigureNormalized = false;

        opts.divPosition = [];
        opts.drawablePosition = [];

        opts.marginsInPositionUnits  = [];
        opts.paddingsInPositionUnits = [];
        opts.axesGapsInPositionUnits = [];

        opts.marginsInPixels  = [];
        opts.paddingsInPixels = [];
        opts.axesGapsInPixels = [];

        opts.alignment = [];

        varargout{2} = opts;
    end

    return;
end

%% Axes position computation for normal figure mode

% The outer margin defines the available grid area in the figure.
unitDivWidth  = (1 - margins(1) - margins(2)) / col;
unitDivHeight = (1 - margins(3) - margins(4)) / row;

% Spanning div:
%   rIndex/cIndex specify the top-left tile of the span.
%   rSpan/cSpan specify how many rows/columns are covered.
divWidth  = unitDivWidth  * cSpan;
divHeight = unitDivHeight * rSpan;

divX = margins(1) + unitDivWidth * (cIndex - 1);
divY = margins(3) + unitDivHeight * (row - (rIndex + rSpan - 1));

% The inner padding defines the drawable axes area inside the spanning div.
axesWidth  = (1 - paddings(1) - paddings(2)) * divWidth  * nX;
axesHeight = (1 - paddings(3) - paddings(4)) * divHeight * nY;

oldUnits = HostFig.Units;
HostFig.Units = "pixels";
figPos = HostFig.Position;
HostFig.Units = oldUnits;
adjIdx = figPos(4) / figPos(3);

borderMin = min([axesWidth / adjIdx, axesHeight]);
borderMax = max([axesWidth / adjIdx, axesHeight]);

isFillShape = false;

switch shape
    case 'auto'
        % Default: no shape adjustment.

    case 'square-min'
        axesWidth  = borderMin * adjIdx;
        axesHeight = borderMin;

    case 'square-max'
        axesWidth  = borderMax * adjIdx;
        axesHeight = borderMax;

    case 'fill'
        % Fill the whole spanning div.
        % fill ignores paddings and nSize, but still respects outer margins.
        axesWidth  = divWidth;
        axesHeight = divHeight;
        paddings   = zeros(1, 4);
        isFillShape = true;

    otherwise
        error('Invalid shape input.');
end

% Drawable position before nSize and alignment.
drawableX = divX + paddings(1) * divWidth;
drawableY = divY + paddings(3) * divHeight;
drawableW = (1 - paddings(1) - paddings(2)) * divWidth;
drawableH = (1 - paddings(3) - paddings(4)) * divHeight;

%% Horizontal and vertical alignment

if isFillShape
    % shape="fill" means exactly fill the div. Alignment should not move it.
    axesX = divX;
    axesY = divY;
    X = 0.5;
    Y = 0.5;
else
    if isnumeric(alignment_horizontal)
        if alignment_horizontal >= 0
            % Numeric positive alignment:
            %   0   -> left edge of padded region
            %   0.5 -> center of padded region
            %   1   -> right edge of padded region
            axesX = divX ...
                + ((1 - paddings(1) - paddings(2)) * alignment_horizontal + paddings(1)) * divWidth ...
                - axesWidth / 2;

            X = (1 - paddings(1) - paddings(2)) * alignment_horizontal + paddings(1);
        else
            % Numeric negative alignment:
            %   -1   -> left edge of padded region
            %   -0.5 -> center of padded region
            %   0    -> right edge of padded region
            axesX = divX ...
                + ((1 - paddings(1) - paddings(2)) * (1 + alignment_horizontal) + paddings(1)) * divWidth ...
                - axesWidth / 2;

            X = (1 - paddings(1) - paddings(2)) * (1 + alignment_horizontal) + paddings(1);
        end
    else
        switch alignment_horizontal
            case 'left'
                axesX = divX + paddings(1) * divWidth;
                X = paddings(1) + axesWidth / divWidth / 2;

            case 'center'
                axesX = divX ...
                    + (1 + paddings(1) - paddings(2)) * divWidth / 2 ...
                    - axesWidth / 2;

                X = (1 + paddings(1) - paddings(2)) / 2;

            case 'right'
                axesX = divX + divWidth * (1 - paddings(2)) - axesWidth;
                X = 1 - paddings(2) - axesWidth / divWidth / 2;
        end
    end

    if isnumeric(alignment_vertical)
        if alignment_vertical >= 0
            % Numeric positive alignment:
            %   0   -> bottom edge of padded region
            %   0.5 -> center of padded region
            %   1   -> top edge of padded region
            axesY = divY ...
                + ((1 - paddings(3) - paddings(4)) * alignment_vertical + paddings(3)) * divHeight ...
                - axesHeight / 2;

            Y = (1 - paddings(3) - paddings(4)) * alignment_vertical + paddings(3);
        else
            % Numeric negative alignment:
            %   -1   -> bottom edge of padded region
            %   -0.5 -> center of padded region
            %   0    -> top edge of padded region
            axesY = divY ...
                + ((1 - paddings(3) - paddings(4)) * (1 + alignment_vertical) + paddings(3)) * divHeight ...
                - axesHeight / 2;

            Y = (1 - paddings(3) - paddings(4)) * (1 + alignment_vertical) + paddings(3);
        end
    else
        switch alignment_vertical
            case 'bottom'
                axesY = divY + paddings(3) * divHeight;
                Y = paddings(3) + axesHeight / divHeight / 2;

            case 'center'
                axesY = divY ...
                    + (1 + paddings(3) - paddings(4)) * divHeight / 2 ...
                    - axesHeight / 2;

                Y = (1 + paddings(3) - paddings(4)) / 2;

            case 'top'
                axesY = divY + divHeight * (1 - paddings(4)) - axesHeight;
                Y = 1 - paddings(4) - axesHeight / divHeight / 2;
        end
    end
end

%% Target layout distances
% All Position values are in normalized figure units in manual-position mode.
%
% axesTargetPosition:
%   The box computed by mu.subplot before axes creation.
%
% PositionType="position":
%   axesTargetPosition is assigned to ax.Position.
%
% PositionType="outerposition":
%   axesTargetPosition is assigned to ax.OuterPosition.

positionUnits = "normalized";

divPosition = [divX, divY, divWidth, divHeight];
axesTargetPosition = [axesX, axesY, axesWidth, axesHeight];

marginsInPositionUnits = margins;

paddingsInPositionUnits = [ ...
    paddings(1) * divWidth, ...
    paddings(2) * divWidth, ...
    paddings(3) * divHeight, ...
    paddings(4) * divHeight];

axesTargetGapsInPositionUnits = local_boxGaps( ...
    axesTargetPosition, ...
    divPosition);

% Backward-compatible alias.
% In PositionType="position" mode, this is exactly the old meaning.
% In PositionType="outerposition" mode, this means gaps from div to the
% target outer box.
axesGapsInPositionUnits = axesTargetGapsInPositionUnits;

try
    figPixelPos = getpixelposition(HostFig, true);
    scaleLRBT = [figPixelPos(3), figPixelPos(3), figPixelPos(4), figPixelPos(4)];

    marginsInPixels  = marginsInPositionUnits  .* scaleLRBT;
    paddingsInPixels = paddingsInPositionUnits .* scaleLRBT;

    axesTargetGapsInPixels = axesTargetGapsInPositionUnits .* scaleLRBT;
    axesGapsInPixels = axesTargetGapsInPixels;
catch
    scaleLRBT = [];

    marginsInPixels  = [];
    paddingsInPixels = [];

    axesTargetGapsInPixels = [];
    axesGapsInPixels = [];
end

%% Show div box

if divBox.toLogical
    divAx = axes(HostFig, ...
        "Position", divPosition, ...
        "Box", "on");

    set(divAx, "LineWidth", 1);
    set(divAx, "TickLength", [0, 0]);
    set(divAx, "XLim", [0, 1]);
    set(divAx, "YLim", [0, 1]);
    set(divAx, "XTick", [0, 1]);
    set(divAx, "YTick", [0, 1]);
    set(divAx, "XTickLabels", num2str([0; 1]));
    set(divAx, "YTickLabels", num2str([0; 1]));

    if ~isempty(X)
        xline(divAx, X, "r--");
        mu.addTicks(divAx, "x", X);
    end

    if ~isempty(Y)
        yline(divAx, Y, "r--");
        mu.addTicks(divAx, "y", Y);
    end
end

%% Draw axes

switch positionType
    case 'position'
        % Backward-compatible behavior:
        % The computed target box is used as ax.Position.
        ax = axes(HostFig, ...
            "Units", "normalized", ...
            "Position", axesTargetPosition);

    case 'outerposition'
        % New behavior:
        % The computed target box is used as ax.OuterPosition.
        %
        % This keeps xlabel/ylabel/title/tick labels inside the allocated
        % subplot box. MATLAB will shrink ax.Position automatically.
        ax = axes(HostFig, ...
            "Units", "normalized");

        try
            ax.PositionConstraint = "outerposition";
        catch
            % Older MATLAB versions may not support PositionConstraint.
        end

        ax.OuterPosition = axesTargetPosition;

    otherwise
        error("Invalid PositionType: %s.", positionType);
end

% Actual positions immediately after axes creation.
% Note:
%   After adding xlabel/ylabel/title, MATLAB may update ax.Position further,
%   especially in PositionType="outerposition" mode. ax.OuterPosition should
%   remain constrained by the target box when PositionConstraint supports it.
actualAxesPosition = ax.Position;
actualAxesOuterPosition = ax.OuterPosition;

axesPositionGapsInPositionUnits = local_boxGaps( ...
    actualAxesPosition, ...
    divPosition);

axesOuterPositionGapsInPositionUnits = local_boxGaps( ...
    actualAxesOuterPosition, ...
    divPosition);

if ~isempty(scaleLRBT)
    axesPositionGapsInPixels = axesPositionGapsInPositionUnits .* scaleLRBT;
    axesOuterPositionGapsInPixels = axesOuterPositionGapsInPositionUnits .* scaleLRBT;
else
    axesPositionGapsInPixels = [];
    axesOuterPositionGapsInPixels = [];
end

%% Outputs

if nargout >= 1
    varargout{1} = ax;
end

if nargout == 2
    opts = local_createBaseOpts( ...
        Parent, HostFig, row, col, index, indexMode, tileIndexing, indexInfo, ...
        margins, paddings, nSize, shape);

    opts.layoutMode = "manual-position";
    opts.alignment = [X, Y];

    opts.unitDivSize = [unitDivWidth, unitDivHeight];
    opts.divPosition = divPosition;
    opts.drawablePosition = [drawableX, drawableY, drawableW, drawableH];

    % PositionType control.
    opts.PositionType = string(positionType);
    opts.PositionTypeApplied = string(positionType);

    % Computed target box.
    % This is the box calculated by mu.subplot before axes creation.
    opts.axesTargetPosition = axesTargetPosition;

    % Backward-compatible field:
    %   PositionType="position"      -> target ax.Position
    %   PositionType="outerposition" -> target ax.OuterPosition
    %
    % This preserves the old meaning of opts.axesPosition as the computed
    % target box, while actualAxesPosition records the live MATLAB value.
    opts.axesPosition = axesTargetPosition;

    % Actual MATLAB axes boxes immediately after creation.
    opts.actualAxesPosition = actualAxesPosition;
    opts.actualAxesOuterPosition = actualAxesOuterPosition;

    opts.axesPositionReference = "figure";
    opts.axesPositionIsFigureNormalized = true;

    % Actual distances in the same units as divPosition/axesPosition.
    opts.positionUnits = positionUnits;

    opts.marginsInPositionUnits  = marginsInPositionUnits;
    opts.paddingsInPositionUnits = paddingsInPositionUnits;

    % Backward-compatible alias. This describes gaps from div to the computed
    % target box.
    opts.axesGapsInPositionUnits = axesGapsInPositionUnits;

    % More explicit gap fields.
    opts.axesTargetGapsInPositionUnits = axesTargetGapsInPositionUnits;
    opts.axesPositionGapsInPositionUnits = axesPositionGapsInPositionUnits;
    opts.axesOuterPositionGapsInPositionUnits = axesOuterPositionGapsInPositionUnits;

    opts.marginsInPixels  = marginsInPixels;
    opts.paddingsInPixels = paddingsInPixels;

    % Backward-compatible alias.
    opts.axesGapsInPixels = axesGapsInPixels;

    % More explicit pixel gap fields.
    opts.axesTargetGapsInPixels = axesTargetGapsInPixels;
    opts.axesPositionGapsInPixels = axesPositionGapsInPixels;
    opts.axesOuterPositionGapsInPixels = axesOuterPositionGapsInPixels;

    varargout{2} = opts;
end

return;
end

%% Local functions

function [Parent, args] = local_extractParent(args)
%LOCAL_EXTRACTPARENT Extract explicit first-position parent if present.

if ~isempty(args) && local_isExplicitFirstParent(args{1})
    Parent = args{1};
    args = args(2:end);
else
    Parent = gcf;
end

return;
end

function tf = local_isExplicitFirstParent(x)
%LOCAL_ISEXPLICITFIRSTPARENT True for object-style figure/tiledlayout parent.

tf = isscalar(x) && ...
    (isa(x, "matlab.ui.Figure") || local_isTiledLayout(x));

return;
end

function args = local_expandTiledLayoutShorthand(parent, args)
%LOCAL_EXPANDTILEDLAYOUTSHORTHAND Expand mu.subplot(t, index, ...) syntax.
%
% Supported tiledlayout syntaxes:
%   mu.subplot(t, row, col, index, ...)  % compatible explicit syntax
%   mu.subplot(t, index, ...)            % shorthand syntax
%
% For shorthand syntax, row/col are inferred from parent.GridSize.

if isempty(args)
    error("mu.subplot with tiledlayout parent requires index input, or row, col, index inputs.");
end

if local_isExplicitTiledRowColIndexSyntax(args)
    return;
end

% Avoid silently interpreting mu.subplot(t, 1, 2) as
% mu.subplot(t, index=1, nSize=2). In tiledlayout mode, nSize does not
% apply anyway, so this is more likely a missing-index error.
if numel(args) == 2 && isnumeric(args{1}) && isnumeric(args{2}) ...
        && isscalar(args{1}) && isscalar(args{2})
    error(['Ambiguous tiledlayout syntax mu.subplot(t, a, b). ', ...
           'Use mu.subplot(t, row, col, index) for explicit syntax, ', ...
           'or mu.subplot(t, [a, b], "indexMode", "linear") for linear index vector.']);
end

index = args{1};

if ~isnumeric(index)
    error("mu.subplot(tiledlayoutParent, index, ...) requires a numeric index as the first input after tiledlayout parent.");
end

restArgs = args(2:end);

% Shorthand supports name-value options after index. Positional optional
% arguments such as nSize/margins/paddings are intentionally not supported
% here because tiledlayout mode ignores them anyway and numeric rest inputs
% are ambiguous with explicit row/col syntax.
if ~isempty(restArgs)
    if mod(numel(restArgs), 2) ~= 0
        error("Name-value inputs after mu.subplot(t, index, ...) should appear in pairs.");
    end

    names = restArgs(1:2:end);
    if ~all(cellfun(@local_isTextScalar, names))
        error("After mu.subplot(t, index, ...), remaining inputs should be name-value pairs.");
    end
end

[row, col] = local_getFixedTiledGridSize(parent);

args = [{row, col, index}, restArgs];

return;
end

function tf = local_isExplicitTiledRowColIndexSyntax(args)
%LOCAL_ISEXPLICITTILEDROWCOLINDEXSYNTAX True for mu.subplot(t,row,col,index,...).

tf = numel(args) >= 3 ...
    && isnumeric(args{1}) && isscalar(args{1}) ...
    && isnumeric(args{2}) && isscalar(args{2}) ...
    && isnumeric(args{3});

return;
end

function [row, col] = local_getFixedTiledGridSize(t)
%LOCAL_GETFIXEDTILEDGRIDSIZE Infer [row, col] from a fixed tiledlayout.

try
    gridSize = t.GridSize;
catch
    error("Cannot infer row/col from tiledlayout. Use mu.subplot(t, row, col, index, ...) instead.");
end

if isempty(gridSize) || numel(gridSize) ~= 2 ...
        || any(~isfinite(double(gridSize))) ...
        || any(double(gridSize) <= 0)
    error("Cannot infer a fixed row/col grid from this tiledlayout. Use mu.subplot(t, row, col, index, ...) instead.");
end

row = double(gridSize(1));
col = double(gridSize(2));

return;
end

function tf = local_isValidParent(x)
%LOCAL_ISVALIDPARENT Validate supported parent types.

tf = isscalar(x) && ...
    (isa(x, "matlab.ui.Figure") || local_isTiledLayout(x));

return;
end

function tf = local_isTiledLayout(x)
%LOCAL_ISTILEDLAYOUT True for MATLAB tiledlayout parent.

tf = isscalar(x) && isa(x, "matlab.graphics.layout.TiledChartLayout");

return;
end

function fig = local_getHostFigure(parent)
%LOCAL_GETHOSTFIGURE Get host figure for figure or tiledlayout parent.

if isa(parent, "matlab.ui.Figure")
    fig = parent;
elseif local_isTiledLayout(parent)
    fig = ancestor(parent, "figure");
else
    error("Unsupported parent type.");
end

return;
end

function local_checkTiledGridSize(t, row, col)
%LOCAL_CHECKTILEDGRIDSIZE Warn if user-specified row/col mismatch tiledlayout.

try
    gridSize = t.GridSize;

    if numel(gridSize) == 2 && all(isfinite(gridSize)) ...
            && all(gridSize > 0) ...
            && ~isequal(double(gridSize(:))', double([row, col]))

        warning("mu:subplot:TiledLayoutGridMismatch", ...
            "Input row/col = [%d, %d], but tiledlayout GridSize = [%d, %d]. " + ...
            "mu.subplot will interpret index using the input row/col.", ...
            row, col, gridSize(1), gridSize(2));
    end
catch
    % Some MATLAB versions or layout modes may not expose GridSize reliably.
end

return;
end

function tileIndexing = local_getTileIndexing(parent)
%LOCAL_GETTILEINDEXING Get tile indexing mode for tiledlayout parent.

tileIndexing = "rowmajor";

if local_isTiledLayout(parent)
    try
        tileIndexing = lower(string(parent.TileIndexing));
    catch
        tileIndexing = "rowmajor";
    end
end

if ~ismember(tileIndexing, ["rowmajor", "columnmajor"])
    tileIndexing = "rowmajor";
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

function gaps = local_boxGaps(boxPos, parentBox)
%LOCAL_BOXGAPS Compute [left, right, bottom, top] gaps between two boxes.
%
% boxPos and parentBox are both [x, y, w, h] in the same coordinate system.

gaps = [ ...
    boxPos(1) - parentBox(1), ...
    parentBox(1) + parentBox(3) - boxPos(1) - boxPos(3), ...
    boxPos(2) - parentBox(2), ...
    parentBox(2) + parentBox(4) - boxPos(2) - boxPos(4)];

return;
end

function info = local_parseGridIndex(index, row, col, indexMode, tileIndexing)
%LOCAL_PARSEGRIDINDEX Convert index into a rectangular spanning block.

index = index(:)';

switch indexMode
    case 'linear'
        info = local_parseLinearIndex(index, row, col, tileIndexing);

    case 'subscript'
        assert(numel(index) == 2, ...
            'When indexMode="subscript", index should be [rowIndex, colIndex].');

        info = local_parseSubscriptIndex(index, row, col, tileIndexing);

    case 'span'
        assert(numel(index) == 4, ...
            'When indexMode="span", index should be [rowStart, colStart, rowSpan, colSpan].');

        info = local_parseSpanIndex(index, row, col, tileIndexing);

    case 'auto'
        if isscalar(index)
            info = local_parseLinearIndex(index, row, col, tileIndexing);

        elseif numel(index) == 2
            % Backward-compatible behavior:
            % [r, c] still means row-column index.
            info = local_parseSubscriptIndex(index, row, col, tileIndexing);

        elseif numel(index) == 4 && local_isValidSpanIndex(index, row, col)
            info = local_parseSpanIndex(index, row, col, tileIndexing);

        else
            info = local_parseLinearIndex(index, row, col, tileIndexing);
        end

    otherwise
        error('Invalid indexMode input.');
end

return;
end

function tf = local_isValidSpanIndex(index, row, col)
%LOCAL_ISVALIDSPANINDEX Check whether index is valid span syntax.

tf = numel(index) == 4 ...
    && index(1) >= 1 ...
    && index(2) >= 1 ...
    && index(3) >= 1 ...
    && index(4) >= 1 ...
    && index(1) <= row ...
    && index(2) <= col ...
    && index(1) + index(3) - 1 <= row ...
    && index(2) + index(4) - 1 <= col;

return;
end

function info = local_parseSubscriptIndex(index, row, col, tileIndexing)
%LOCAL_PARSESUBSCRIPTINDEX Parse [rowIndex, colIndex].

rStart = index(1);
cStart = index(2);

assert(rStart <= row, 'Row number should not exceed %d.', row);
assert(cStart <= col, 'Column number should not exceed %d.', col);

info = local_makeIndexInfo( ...
    rStart, cStart, 1, 1, row, col, ...
    "subscript", tileIndexing);

return;
end

function info = local_parseSpanIndex(index, row, col, tileIndexing)
%LOCAL_PARSESPANINDEX Parse [rowStart, colStart, rowSpan, colSpan].

rStart = index(1);
cStart = index(2);
rSpan  = index(3);
cSpan  = index(4);

assert(local_isValidSpanIndex(index, row, col), ...
    'Invalid spanning index. Expected [rowStart, colStart, rowSpan, colSpan] within a %d-by-%d grid.', ...
    row, col);

info = local_makeIndexInfo( ...
    rStart, cStart, rSpan, cSpan, row, col, ...
    "span", tileIndexing);

return;
end

function info = local_parseLinearIndex(index, row, col, tileIndexing)
%LOCAL_PARSELINEARINDEX Parse scalar or vector MATLAB-style linear indices.
%
% A vector of linear indices must form a complete rectangular block.

assert(all(index <= row * col), ...
    'Linear grid index should not exceed grid size %d x %d.', row, col);

assert(numel(unique(index)) == numel(index), ...
    'Linear grid index vector should not contain duplicate indices.');

[rList, cList] = local_linearIndexToSubscript(index, row, col, tileIndexing);

rStart = min(rList);
rEnd   = max(rList);
cStart = min(cList);
cEnd   = max(cList);

rSpan = rEnd - rStart + 1;
cSpan = cEnd - cStart + 1;

expectedTileList = local_tileListFromSpan(rStart, cStart, rSpan, cSpan, row, col, tileIndexing);

assert(isequal(sort(index(:)), sort(expectedTileList(:))), ...
    ['Linear grid index vector should describe a complete rectangular block. ', ...
     'For example, in a 3-by-4 row-major grid, [1, 2, 5, 6] is valid, but [1, 3] is not.']);

info = local_makeIndexInfo( ...
    rStart, cStart, rSpan, cSpan, row, col, ...
    "linear", tileIndexing);

return;
end

function [rList, cList] = local_linearIndexToSubscript(index, row, col, tileIndexing)
%LOCAL_LINEARINDEXTOSUBSCRIPT Convert linear tile index to row/column index.

index = index(:)';

switch string(tileIndexing)
    case "rowmajor"
        rList = floor((index - 1) / col) + 1;
        cList = mod(index - 1, col) + 1;

    case "columnmajor"
        cList = floor((index - 1) / row) + 1;
        rList = mod(index - 1, row) + 1;

    otherwise
        error("Invalid tileIndexing: %s.", string(tileIndexing));
end

return;
end

function idx = local_subscriptToLinearIndex(r, c, row, col, tileIndexing)
%LOCAL_SUBSCRIPTTOLINEARINDEX Convert row/column index to linear tile index.

switch string(tileIndexing)
    case "rowmajor"
        idx = (r - 1) * col + c;

    case "columnmajor"
        idx = (c - 1) * row + r;

    otherwise
        error("Invalid tileIndexing: %s.", string(tileIndexing));
end

return;
end

function info = local_makeIndexInfo(rStart, cStart, rSpan, cSpan, row, col, mode, tileIndexing)
%LOCAL_MAKEINDEXINFO Build index information structure.

tileList = local_tileListFromSpan(rStart, cStart, rSpan, cSpan, row, col, tileIndexing);
tileIndex = local_subscriptToLinearIndex(rStart, cStart, row, col, tileIndexing);

info = struct();
info.mode = string(mode);
info.tileIndexing = string(tileIndexing);
info.rStart = rStart;
info.cStart = cStart;
info.rEnd = rStart + rSpan - 1;
info.cEnd = cStart + cSpan - 1;
info.rSpan = rSpan;
info.cSpan = cSpan;
info.tileIndex = tileIndex;
info.tileList = tileList(:)';

return;
end

function tileList = local_tileListFromSpan(rStart, cStart, rSpan, cSpan, row, col, tileIndexing)
%LOCAL_TILELISTFROMSPAN Return linear tile indices in a spanning block.

rEnd = rStart + rSpan - 1;
cEnd = cStart + cSpan - 1;

assert(rStart >= 1 && cStart >= 1 && rEnd <= row && cEnd <= col, ...
    'Tile span exceeds grid size %d x %d.', row, col);

tileList = zeros(rSpan * cSpan, 1);
cnt = 0;

for r = rStart:rEnd
    for c = cStart:cEnd
        cnt = cnt + 1;
        tileList(cnt) = local_subscriptToLinearIndex(r, c, row, col, tileIndexing);
    end
end

return;
end

function opts = local_createBaseOpts( ...
    Parent, HostFig, row, col, index, indexMode, tileIndexing, indexInfo, ...
    margins, paddings, nSize, shape)
%LOCAL_CREATEBASEOPTS Common opts output for both layout modes.
%
% This helper only stores base information that is explicitly passed in.
% Position metrics should be attached in the main function after they are
% actually computed.

opts = struct();

opts.parent = Parent;
opts.hostFigure = HostFig;

opts.row = row;
opts.col = col;
opts.index = index;
opts.indexMode = string(indexMode);
opts.tileIndexing = string(tileIndexing);
opts.indexInfo = indexInfo;

opts.rowIndex = indexInfo.rStart;
opts.colIndex = indexInfo.cStart;
opts.rowSpan = indexInfo.rSpan;
opts.colSpan = indexInfo.cSpan;
opts.rowRange = [indexInfo.rStart, indexInfo.rEnd];
opts.colRange = [indexInfo.cStart, indexInfo.cEnd];
opts.tileIndex = indexInfo.tileIndex;
opts.tileList = indexInfo.tileList;

% Input ratios after parsing and individual override.
% Kept for backward compatibility.
opts.margins  = margins;
opts.paddings = paddings;

% More explicit aliases.
opts.marginsRatio  = margins;
opts.paddingsRatio = paddings;

opts.nSize = nSize;
opts.shape = shape;

return;
end

function tf = local_isTextScalar(x)
%LOCAL_ISTEXTSCALAR True for char row vector or scalar string.

tf = (ischar(x) && (isrow(x) || isempty(x))) || ...
     (isstring(x) && isscalar(x));

return;
end
