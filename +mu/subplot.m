function varargout = subplot(varargin)
%SUBPLOT Advanced subplot function.
%
% This function creates axes with more flexible control than MATLAB built-in
% subplot. It divides a figure into row-by-column "div" regions, and then
% places one axes object inside the selected div.
%
% H5/CSS-like box model:
%
%   figure
%   └── margin area
%       └── div
%           └── padding area
%               └── axes
%
% In this function:
%   margins  : outer space around the whole subplot grid, relative to figure
%   paddings : inner space inside each div, relative to div
%
% SCHEMATIC:
%   See /demo/demo_subplot.m for details.
% INPUTS:
%   REQUIRED:
%   row/col/index - Same usage as MATLAB built-in subplot.
%
%   OPTIONAL:
%   Fig - Figure handle. If omitted, gcf is used.
%
%   NAME-VALUE:
%   nSize - [nX, nY] specifies size of axes. Default: [1, 1].
%           nSize is relative to the drawable area inside each div.
%
%   margins - Margins specified as [left, right, bottom, top].
%             Margins are outer spaces around the whole subplot grid,
%             relative to figure. Default: [0.03, 0.03, 0.08, 0.05].
%             You can also set them separately using:
%             margin_left, margin_right, margin_bottom, margin_top.
%
%   paddings - Paddings specified as [left, right, bottom, top].
%              Paddings are inner spaces inside each subplot div,
%              relative to div. Default: [0.05, 0.05, 0.08, 0.05].
%              You can also set them separately using:
%              padding_left, padding_right, padding_bottom, padding_top.
%
%   shape - 'auto'(default), 'square-min', 'square-max', or 'fill'.
%           Option 'fill' fills the whole div and ignores paddings/nSize,
%           but keeps margins.
%
%   alignment - How axes aligns to the div. It can be either a preset string
%               or a 2-element numeric vector that specifies axes center
%               [x, y] relative to the padded div area.
%               If positive, relative to left and bottom.
%               If negative, relative to right and top.
%               Optional values:
%               'left-bottom', 'left-center', 'left-top',
%               'center-bottom', 'center', 'center-top',
%               'right-bottom', 'right-center', 'right-top'.
%
%   alignment_horizontal - 'left', 'center', 'right', or numeric scalar.
%                          This has higher priority than alignment.
%
%   alignment_vertical - 'bottom', 'center', 'top', or numeric scalar.
%                        This has higher priority than alignment.
%
%   divBox - Show div box. Default: "hide".
%            This is a developer option to locate the div area.
%
% OUTPUTS:
%   ax   - Subplot axes object.
%   opts - Subplot options and computed positions.
%
% NOTES:
%   - All position parameters are normalized.
%   - Maximizing your figure before using mu.subplot is recommended.

%% Parameter validation

if isempty(varargin)
    error('mu.subplot requires at least row, col, and index inputs.');
end

if isscalar(varargin{1}) && isgraphics(varargin{1}, "figure")
    Fig = varargin{1};
    varargin = varargin(2:end);
else
    Fig = gcf;
end

mIp = inputParser;

mIp.addRequired("Fig", @(x) isscalar(x) && isa(x, "matlab.ui.Figure"));
mIp.addRequired("row", @(x) validateattributes(x, 'numeric', {'numel', 1, 'positive', 'integer'}));
mIp.addRequired("col", @(x) validateattributes(x, 'numeric', {'numel', 1, 'positive', 'integer'}));
mIp.addRequired("index", @(x) validateattributes(x, 'numeric', {'vector', 'positive', 'integer'}));

% Positional optional inputs are kept for backward calling style:
% mu.subplot(row, col, index, nSize, margins, paddings, shape)
% But their semantics are now H5/CSS-like:
% margins = outer space, paddings = inner space.
mIp.addOptional("nSize0", [], @(x) validateattributes(x, 'numeric', {'vector', 'real'}));
mIp.addOptional("margins0", [], @(x) validateattributes(x, 'numeric', {'vector', 'real', 'numel', 4}));
mIp.addOptional("paddings0", [], @(x) validateattributes(x, 'numeric', {'vector', 'real', 'numel', 4}));
mIp.addOptional("shape0", [], @mustBeTextScalar);

mIp.addParameter("nSize", [1, 1], @(x) validateattributes(x, 'numeric', {'vector', 'real'}));

% IMPORTANT:
% Defaults are swapped compared with the old implementation to preserve
% the old visual layout as much as possible after the semantic correction.
%
% New definition:
%   margins  -> outer space around grid, relative to figure
%   paddings -> inner space inside div, relative to div
mIp.addParameter("margins", [0.03, 0.03, 0.08, 0.05], @(x) validateattributes(x, 'numeric', {'vector', 'real', 'numel', 4}));
mIp.addParameter("paddings", [0.05, 0.05, 0.08, 0.05], @(x) validateattributes(x, 'numeric', {'vector', 'real', 'numel', 4}));

mIp.addParameter("shape", "auto", @mustBeTextScalar);

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

mIp.parse(Fig, varargin{:});

%% Grid size

Fig   = mIp.Results.Fig;
row   = mIp.Results.row;
col   = mIp.Results.col;
index = mIp.Results.index;

if isscalar(index)
    assert(index <= col * row, ...
        'Grid index %d should not exceed grid size %d x %d.', ...
        index, col, row);

    [cIndex, rIndex] = ind2sub([col, row], index);

elseif numel(index) == 2
    rIndex = index(1);
    cIndex = index(2);

    assert(rIndex <= row, 'Row number should not exceed %d.', row);
    assert(cIndex <= col, 'Column number should not exceed %d.', col);

else
    error('Grid number should either be a scalar or a 2-element vector.');
end

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

%% Margins and paddings

% H5/CSS-like definition:
%   margins  = outer space around the subplot grid, relative to figure
%   paddings = inner space inside each subplot div, relative to div
%
% Order is [left, right, bottom, top].

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

%% Show div box

divBox = mu.OptionState.create(mIp.Results.divBox);

%% Axes position computation

% Sanity checks. These catch collapsed layouts early, before MATLAB creates
% invisible or negative-sized axes.
assert(margins(1) + margins(2) < 1, ...
    'The sum of margin_left and margin_right should be smaller than 1.');
assert(margins(3) + margins(4) < 1, ...
    'The sum of margin_bottom and margin_top should be smaller than 1.');
assert(paddings(1) + paddings(2) < 1, ...
    'The sum of padding_left and padding_right should be smaller than 1.');
assert(paddings(3) + paddings(4) < 1, ...
    'The sum of padding_bottom and padding_top should be smaller than 1.');

% The outer margin defines the available grid area in the figure.
% This is the key correction:
%   old code: div size was controlled by paddings
%   new code: div size is controlled by margins
divWidth  = (1 - margins(1) - margins(2)) / col;
divHeight = (1 - margins(3) - margins(4)) / row;

divX = margins(1) + divWidth  * (cIndex - 1);
divY = margins(3) + divHeight * (row - rIndex);

% The inner padding defines the drawable axes area inside each div.
% This is the second key correction:
%   old code: axes size was controlled by margins
%   new code: axes size is controlled by paddings
axesWidth  = (1 - paddings(1) - paddings(2)) * divWidth  * nX;
axesHeight = (1 - paddings(3) - paddings(4)) * divHeight * nY;

% Adjust for maximized figure size.
% This keeps square-min/square-max visually square on a maximized figure.
FigSize = get(0, "screensize");
adjIdx = FigSize(4) / FigSize(3);

borderMin = min([axesWidth / adjIdx, axesHeight]);
borderMax = max([axesWidth / adjIdx, axesHeight]);

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
        % Fill the whole div.
        % In the new H5/CSS-like definition, fill ignores paddings and nSize,
        % but still respects the outer margins.
        axesWidth  = divWidth;
        axesHeight = divHeight;
        paddings   = zeros(1, 4);

    otherwise
        error('Invalid shape input.');
end

%% Horizontal alignment

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

%% Vertical alignment

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

%% Show div box

if divBox.toLogical
    divAx = axes(Fig, ...
        "Position", [divX, divY, divWidth, divHeight], ...
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
        mu.addTicks(divAx, "y", Y);
    end
end

%% Draw axes

ax = axes(Fig, "Position", [axesX, axesY, axesWidth, axesHeight]);

%% Outputs

if nargout >= 1
    varargout{1} = ax;
end

if nargout == 2
    opts.row = row;
    opts.col = col;
    opts.index = index;

    % These are returned with the new H5/CSS-like meanings.
    opts.margins  = margins;
    opts.paddings = paddings;

    opts.nSize = nSize;
    opts.shape = shape;
    opts.alignment = [X, Y];

    opts.divPosition = [divX, divY, divWidth, divHeight];
    opts.axesPosition = [axesX, axesY, axesWidth, axesHeight];

    varargout{2} = opts;
end

return;
end