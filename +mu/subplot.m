function varargout = subplot(varargin)
% Description: advanced subplot function
% Schematic:
%     % The following figure is created by script:
%     figure("WindowState", "maximized");
%     set(0, "DefaultAxesBox", "on");
%     % div1
%     mu.subplot(1, 2, 1, "paddings", [1/9, 1/18, 2/9, 1/9], ...
%                         "shape", "fill");
%     text(0.05, 0.95, 'div1', 'Color', 'r');
%     % ax1
%     mu.subplot(1, 2, 1, "paddings", [1/9, 1/18, 2/9, 1/9], ...
%                         "margins", [1/5, 1/2, 1/6, 1/6]);
%     text(0.05, 0.95, 'ax1', 'Color', 'r');
%     % div2
%     mu.subplot(1, 2, 2, "paddings", [1/9, 1/18, 2/9, 1/9], ...
%                         "shape", "fill");
%     text(0.05, 0.95, 'div2', 'Color', 'r');
%     % ax2
%     mu.subplot(1, 2, 2, "paddings", [1/9, 1/18, 2/9, 1/9], ...
%                         "margins", zeros(1, 4), ...
%                         "nSize", [1/4, 1/2], ...
%                         "alignment", "left-bottom");
%     text(0.05, 0.95, 'ax2', 'Color', 'r');
%     set(0, "DefaultAxesBox", "factory");
%
%  ____________________________________________________________________
% |figure _________________________________________________________    |
% |      |div1  _______               |div2                        |   |
% |      |     |       |              |                            |   |
% |      |     | ax1   |←------------→|_______                     |   |
% |      |     |       | margin_right |       |                    |   |
% |      |     |_______|              | ax2   |                    |   |
% |←----→|____________________________|_______|____________________|   |
% |padding_left      ↑ padding_bottom                                  |
% |__________________↓_________________________________________________|
%
%
% Notes:
%     All parameters here are normalized in unit.
%     MAXIMIZE your figure before using mu.subplot to create axes is recommended.
% Inputs:
%     Fig: figure handle (default=gcf)
%     row/col/index: same usage of function subplot
%     nSize: [nX, nY] specifies size of subplot (default: [1, 1]).
%            [nSize] is relative to axes.
%     margins: margins of subplot specified as [left, right, bottom, top].
%              [margins] is relative to div. (default: [0.05, 0.05, 0.08, 0.05])
%              You can also set them separately using name-value pair (prior to [margins]):
%              - [margin_left]
%              - [margin_right]
%              - [margin_bottom]
%              - [margin_top]
%     paddings: paddings of subplot specified as [left, right, bottom, top].
%               [paddings] is relative to figure. (default: [0.03, 0.03, 0.08, 0.05])
%               You can also set them separately using name-value pair (prior to [paddings]):
%               - [padding_left]
%               - [padding_right]
%               - [padding_bottom]
%               - [padding_top]
%     shape: 'auto'(default), 'square-min', 'square-max', 'fill'
%            (NOTICE: 'fill' option is prior to [margins] and [nSize] options)
%     alignment: how axes aligns to <div>, either preset string or a 2-element vector that 
%                specifies axes center [x,y] relative to <div> (normalized).
%                If set positive, relative to left and bottom.
%                If set negative, relative to right and top.
%                This option influences how the axes is expanded or shrinked using [nSize] option.
%                Optional values:
%                - 'left-bottom'
%                - 'left-center'
%                - 'left-top'
%                - 'center-bottom'
%                - 'center' (default)
%                - 'center-top'
%                - 'right-bottom'
%                - 'right-center'
%                - 'right-top'
%                You can also specify 'alignment_horizontal' and
%                'alignment_vertical' separately (prior to 'alignment').
%     divBox: show <div> box (default: "hide"). This is a developer option to locate axes.
% Outputs:
%     ax: subplot axes object
%     opts: subplot options

%% Parameter validation
if strcmp(class(varargin{1}), "matlab.ui.Figure")
    Fig = varargin{1};
    varargin = varargin(2:end);
else
    Fig = gcf;
end

mIp = inputParser;
mIp.addRequired("Fig",   @(x) isscalar(x) && isa(x, "matlab.ui.Figure"));
mIp.addRequired("row",   @(x) validateattributes(x, 'numeric', {'numel', 1, 'positive', 'integer'}));
mIp.addRequired("col",   @(x) validateattributes(x, 'numeric', {'numel', 1, 'positive', 'integer'}));
mIp.addRequired("index", @(x) validateattributes(x, 'numeric', {'vector', 'positive', 'integer'}));
mIp.addOptional("nSize0",    [], @(x) validateattributes(x, 'numeric', {'vector', 'real'}));
mIp.addOptional("margins0",  [], @(x) validateattributes(x, 'numeric', {'vector', 'real', 'numel', 4}));
mIp.addOptional("paddings0", [], @(x) validateattributes(x, 'numeric', {'vector', 'real', 'numel', 4}));
mIp.addOptional("shape0", [], @mustBeTextScalar);
mIp.addParameter("nSize", [1, 1], @(x) validateattributes(x, 'numeric', {'vector', 'real'}));
mIp.addParameter("margins",  [0.05, 0.05, 0.08, 0.05], @(x) validateattributes(x, 'numeric', {'vector', 'real', 'numel', 4}));
mIp.addParameter("paddings", [0.03, 0.03, 0.08, 0.05], @(x) validateattributes(x, 'numeric', {'vector', 'real', 'numel', 4}));
mIp.addParameter("shape", "auto", @mustBeTextScalar);
mIp.addParameter("alignment"           , "center", @(x) isnumeric(x) || mu.isTextScalar(x));
mIp.addParameter("alignment_horizontal", []      , @(x) isnumeric(x) || mu.isTextScalar(x));
mIp.addParameter("alignment_vertical"  , []      , @(x) isnumeric(x) || mu.isTextScalar(x));
mIp.addParameter("margin_left"   , [], @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("margin_right"  , [], @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("margin_bottom" , [], @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("margin_top"    , [], @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("padding_left"  , [], @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("padding_right" , [], @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("padding_bottom", [], @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("padding_top"   , [], @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("divBox", mu.OptionState.Off, @mu.OptionState.validate);
mIp.parse(Fig, varargin{:})

% Grid size
Fig   = mIp.Results.Fig  ;
row   = mIp.Results.row  ;
col   = mIp.Results.col  ;
index = mIp.Results.index;
if isscalar(index)
    assert(index <= col * row, 'Grid index %d should not exceed grid size %d x %d', index, col, row);
    [cIndex, rIndex] = ind2sub([col, row], index);
elseif numel(index) == 2
    rIndex = index(1);
    cIndex = index(2);
    assert(rIndex <= row, 'Row number should not exceed %d', row);
    assert(cIndex <= col, 'Column number should not exceed %d', col);
else
    error('Grid number should either be a scalar or a 2-element vector');
end

% Alignment
validShape = {'auto', 'square-min', 'square-max', 'fill'};
validAlignment = {'left-bottom', ...
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

% Axes scaling
nSize = mu.getor(mIp.Results, "nSize0", mIp.Results.nSize, true);
nX = nSize(1);
if isscalar(nSize)
    nY = nSize(1);
elseif numel(nSize) == 2 % nSize = [nX, nY]
    nY = nSize(2);
else
    error('Size should be a scalar or a 2-element vector');
end

if isempty(mIp.Results.shape0)
    shape = validatestring(mIp.Results.shape, validShape);
else
    shape = validatestring(mIp.Results.shape0, validShape);
end

% Margins and paddings
margins        = mu.getor(mIp.Results, "margins0" , mIp.Results.margins , true);
paddings       = mu.getor(mIp.Results, "paddings0", mIp.Results.paddings, true);
margin_left    = mIp.Results.margin_left   ;
margin_right   = mIp.Results.margin_right  ;
margin_bottom  = mIp.Results.margin_bottom ;
margin_top     = mIp.Results.margin_top    ;
padding_left   = mIp.Results.padding_left  ;
padding_right  = mIp.Results.padding_right ;
padding_bottom = mIp.Results.padding_bottom;
padding_top    = mIp.Results.padding_top   ;

if ~isempty(margin_left   ), margins (1) = margin_left   ; end
if ~isempty(margin_right  ), margins (2) = margin_right  ; end
if ~isempty(margin_bottom ), margins (3) = margin_bottom ; end
if ~isempty(margin_top    ), margins (4) = margin_top    ; end
if ~isempty(padding_left  ), paddings(1) = padding_left  ; end
if ~isempty(padding_right ), paddings(2) = padding_right ; end
if ~isempty(padding_bottom), paddings(3) = padding_bottom; end
if ~isempty(padding_top   ), paddings(4) = padding_top   ; end

% Show <div> box
divBox = mu.OptionState.create(mIp.Results.divBox);

%% Axes position computation
% paddings or margins is [Left, Right, Bottom, Top]
divWidth  = (1 - paddings(1) - paddings(2)) / col;
divHeight = (1 - paddings(3) - paddings(4)) / row;

divX = paddings(1) + divWidth  * (cIndex - 1);
divY = paddings(3) + divHeight * (row - rIndex);
axesWidth  = (1 - margins(1) - margins(2)) * divWidth  * nX;
axesHeight = (1 - margins(3) - margins(4)) * divHeight * nY;

% Adjust for maximized figure size
FigSize = get(0, "screensize");
adjIdx = FigSize(4) / FigSize(3);

borderMin = min([axesWidth / adjIdx, axesHeight]);
borderMax = max([axesWidth / adjIdx, axesHeight]);
switch shape
    case 'auto'
        % default: without adjustment
    case 'square-min'
        axesWidth  = borderMin * adjIdx;
        axesHeight = borderMin;
    case 'square-max'
        axesWidth  = borderMax * adjIdx;
        axesHeight = borderMax;
    case 'fill'
        axesWidth  = divWidth;
        axesHeight = divHeight;
        margins   = zeros(1, 4);
    otherwise
        error('Invalid shape input');
end

if isnumeric(alignment_horizontal)
    if alignment_horizontal >= 0
        axesX = divX + ((1 - margins(1) - margins(2)) * alignment_horizontal + margins(1)) * divWidth - axesWidth / 2;
        X = (1 - margins(1) - margins(2)) * alignment_horizontal + margins(1);
    else
        axesX = divX + ((1 - margins(1) - margins(2)) * (1 + alignment_horizontal) + margins(1)) * divWidth - axesWidth / 2;
        X = (1 - margins(1) - margins(2)) * (1 + alignment_horizontal) + margins(1);
    end
else
    switch alignment_horizontal
        case 'left'
            axesX = divX + margins(1) * divWidth;
            X = margins(1) + axesWidth / divWidth / 2;
        case 'center'
            axesX = divX + (1 + margins(1) - margins(2)) * divWidth / 2 - axesWidth / 2;
            X = (1 + margins(1) - margins(2)) / 2;
        case 'right'
            axesX = divX + divWidth  * (1 - margins(2)) - axesWidth;
            X = 1 - margins(2) - axesWidth / divWidth / 2;
    end
end

if isnumeric(alignment_vertical)
    if alignment_vertical >= 0
        axesY = divY + ((1 - margins(3) - margins(4)) * alignment_vertical + margins(3)) * divHeight - axesHeight / 2;
        Y = (1 - margins(3) - margins(4)) * alignment_vertical + margins(3);
    else
        axesY = divY + ((1 - margins(3) - margins(4)) * (1 + alignment_vertical) + margins(3)) * divHeight - axesHeight / 2;
        Y = (1 - margins(3) - margins(4)) * (1 + alignment_vertical) + margins(3);
    end
else
    switch alignment_vertical
        case 'bottom'
            axesY = divY + margins(3) * divHeight;
            Y = margins(3) + axesHeight / divHeight / 2;
        case 'center'
            axesY = divY + (1 + margins(3) - margins(4)) * divHeight / 2 - axesHeight / 2;
            Y = (1 + margins(3) - margins(4)) / 2;
        case 'top'
            axesY = divY + divHeight * (1 - margins(4)) - axesHeight;
            Y = 1 - margins(4) - axesHeight / divHeight / 2;
    end
end

%% Show <div> box
if divBox.toLogical
    divAx = axes(Fig, "Position", [divX, divY, divWidth, divHeight], "Box", "on");
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
ax = axes(Fig, "Position", [axesX, axesY, axesWidth, axesHeight]);

%% Outputs
if nargout >= 1
    varargout{1} = ax;
end

if nargout == 2
    opts.row = row;
    opts.col = col;
    opts.index = index;
    opts.margins = margins;
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
