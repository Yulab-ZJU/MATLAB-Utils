function varargout = mu_plotWaveArray(chData, window, varargin)
% Plot multi-group waves for multi-channel data
%--------------------------------------------------------------------------------
% INPUT
%   REQUIRED
%     chData: n*1 struct of fields (* is required)
%       - *chMean: [nCh x nSample]
%       - chErr: [nCh x nSample], errorbar (if left empty, errorbar will not be shown)
%       - color: [R,G,B] or valid color string (default='r')
%       - errColor: errorbar color (default: color of [chMean] decreased by 30% in saturation)
%       - errAlpha: face alpha value of errorbar (default: 0.5)
%           0 for completely transparent.
%           1 for completely opaque.
%       - legend: string or char, not shown if set empty.
%       - lineWidth: specify line width for each group (default: using the general setting)
%     window: time window [winStart,winEnd]
%
%   NAME-VALUE PARAMETERS
%   - 'GridSize': [nrow,ncol] that specifies the subplot grid to plot 
%        (default=mu.autoplotsize(nch)).
%
%   - 'Channels': a vector/2-D matrix that specifies channel numbers to plot.
%        If [Channels] is a vector, it is reshaped to fit [GridSize].
%        If [Channels] is a 2-D matrix, size(Channels) should be equal 
%        to [GridSize] and for subplot to skip, use NAN value.
%        numel(Channels)<prod(GridSize) is okay. The last several subplots
%        are hided. numel(Channels)>prod(GridSize) reports an error.
%
%   - 'LineWidth': General line width setting (default=1)
%
%   - 'margings': [left,right,bottom,top] (default=[.05, .05, .1, .1])
%   - 'paddings': [left,right,bottom,top] (default=[.01, .03, .01, .01])
%        See `mu.subplot` for detail.
%
%-------------------------------------------------------------------------------- 
% OUTPUT:
%     Figure handle of the wave plot.
%

mIp = inputParser;
mIp.addRequired("chData", @(x) isstruct(x));
mIp.addRequired("window", @(x) validateattributes(x, {'numeric'}, {'numel', 2, 'increasing'}));
mIp.addParameter("GridSize", [], @(x) validateattributes(x, 'numeric', {'numel', 2, 'positive'}));
mIp.addParameter("Channels", [], @(x) validateattributes(x, 'numeric', {'2d'}));
mIp.addParameter("margins", [.05, .05, .1, .1], @(x) validateattributes(x, 'numeric', {'numel', 4}));
mIp.addParameter("paddings", [.01, .05, .01, .05], @(x) validateattributes(x, 'numeric', {'numel', 4}));
mIp.addParameter("LineWidth", 1, @(x) validateattributes(x, 'numeric', {'scalar', 'positive'}));
mIp.parse(chData, window, varargin{:});

GridSize = mIp.Results.GridSize;
Channels = mIp.Results.Channels;
defaultLineWidth = mIp.Results.LineWidth;
margins = mIp.Results.margins;
paddings = mIp.Results.paddings;

% validate
chData = chData(:);
ngroup = numel(chData);
[nch, nsample] = mu.checkdata({chData.chMean});
t = linspace(window(1), window(2), nsample);

% grid size and channel map
if isempty(GridSize)
    GridSize = mu.autoplotsize(nch);
end
if isempty(Channels)
    Channels = reshape(1:prod(GridSize), flip(GridSize))';
else
    if isvector(Channels)
        assert(numel(Channels) <= prod(GridSize), "The number of channels should not exceed grid size");
        Channels = [Channels(:); nan(prod(GridSize) - numel(Channels), 1)];
    else % matrix
        assert(isequal(size(Channels), GridSize), "Size of Channels should be equal to GridSize");
        Channels = Channels';
    end
end
Channels(Channels > nch) = nan;

% colors
if ~isfield(chData, "color")
    chData = mu.addfield(chData, "color", num2cell(lines(ngroup), 2));
end
[errColor, errAlpha] = deal(cell(ngroup, 1));
for gIndex = 1:ngroup
    color = validatecolor(chData(gIndex).color);
    hsi = rgb2hsv(color);
    if hsi(2) == 0 % gray or black
        hsi(3) = min([1.1 * hsi(3), 0.9]);
    else
        hsi(2) = 0.7 * hsi(2);
    end
    errColor{gIndex} = mu.getor(chData(gIndex), "errColor", hsv2rgb(hsi));
    errAlpha{gIndex} = mu.getor(chData(gIndex), "errAlpha", 0.5);
end
chData = mu.addfield(chData, "errColor", errColor);
chData = mu.addfield(chData, "errAlpha", errAlpha);

% plot
Fig = figure("WindowState", "maximized");
for rIndex = 1:GridSize(1)

    for cIndex = 1:GridSize(2)
        ch = Channels(rIndex, cIndex);

        if isnan(ch)
            continue;
        end

        ax = mu.subplot(Fig, GridSize(1), GridSize(2), (rIndex - 1) * GridSize(2) + cIndex, ...
                        "margins", margins, "paddings", paddings);
        hold(ax, "on");

        for gIndex = 1:length(chData)
            chMean = chData(gIndex).chMean;
            chErr = mu.getor(chData(gIndex), "chErr");

            color = validatecolor(chData(gIndex).color);
            errColor = chData(gIndex).errColor;
            errAlpha = chData(gIndex).errAlpha;

            if ~isempty(chErr)
                y1 = chMean(ch, :) + chErr(ch, :);
                y2 = chMean(ch, :) - chErr(ch, :);
                fill(ax, [t, fliplr(t)], [y1, fliplr(y2)], errColor, 'edgealpha', 0, 'facealpha', errAlpha);
            end

            plot(ax, t, chMean(ch, :), "Color", color, "LineWidth", mu.getor(chData(gIndex), "lineWidth", defaultLineWidth));
        end

        xlim(ax, window);
        title(ax, ['CH ', num2str(ch)]);

        if ~mod(((rIndex - 1) * GridSize(2) + cIndex - 1), GridSize(2)) == 0
            yticklabels(ax, '');
        end

        if (rIndex - 1) * GridSize(2) + cIndex < (GridSize(1) - 1) * GridSize(2) + 1
            xticklabels(ax, '');
        end

    end

end

mu.scaleAxes(Fig, "y");

% legends
if isfield(chData, "legend") && any(~cellfun(@isempty, {chData.legend}))
    legendHandles = gobjects(1, ngroup);

    ax = mu.subplot(1, 1, 1, "paddings", zeros(1, 4), "margins", zeros(1, 4));
    for gIndex = 1:ngroup
        if isempty(chData(gIndex).legend)
            continue;
        end
        legendHandles(gIndex) = line(ax, nan, nan, ...
                                     "Color", chData(gIndex).color, ...
                                     "LineWidth", mu.getor(chData(gIndex), "lineWidth", defaultLineWidth));
    end
    idx = isgraphics(legendHandles);
    legend(ax, legendHandles(idx), {chData(idx).legend}', 'Location', 'northeast', 'AutoUpdate', 'off');
    set(ax, "Visible", "off");
end

if nargout == 1
    varargout{1} = Fig;
end

return;
end
