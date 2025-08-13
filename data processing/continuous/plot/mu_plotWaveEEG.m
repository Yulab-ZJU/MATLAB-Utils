function varargout = mu_plotWaveEEG(chData, window, EEGPos, varargin)
% Plot multi-group waves for multi-channel EEG data
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
%     window: time window [winStart,winEnd], in ms
%     EEGPos: EEG position struct. See EEGPos_Neuracle64.m
%
%   NAME-VALUE PARAMETERS
%   - 'LineWidth': General line width setting (default=1)
%   - 'Scaleplate' : Hide x, y ticks and show a scaleplate instead. This option only works when 
%                    plotting in actual electrode positions. (default='hide')
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
mIp.addParameter("margins", [.05, .05, .1, .1], @(x) validateattributes(x, 'numeric', {'numel', 4}));
mIp.addParameter("paddings", [.01, .05, .01, .05], @(x) validateattributes(x, 'numeric', {'numel', 4}));
mIp.addParameter("LineWidth", 1, @(x) validateattributes(x, 'numeric', {'scalar', 'positive'}));
mIp.addParameter("Scaleplate", "hide");
mIp.parse(chData, window, varargin{:});

defaultLineWidth = mIp.Results.LineWidth;
margins = mIp.Results.margins;
paddings = mIp.Results.paddings;
Scaleplate = validatestring(mIp.Results.Scaleplate, {'show', 'hide'});

GridSize = EEGPos.grid;
chsIgnore = mu.getor(EEGPos, "ignore");
locs = mu.getor(EEGPos, "locs");
channelNames = mu.getor(EEGPos, "channelNames");

% validate
chData = chData(:);
ngroup = numel(chData);
[~, nsample] = mu.checkdata({chData.chMean});
t = linspace(window(1), window(2), nsample);

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

if isempty(locs)
    % plot in grid map
    Fig = figure("WindowState", "maximized");
    for rIndex = 1:GridSize(1)

        for cIndex = 1:GridSize(2)
            ch = EEGPos.channels((rIndex - 1) * GridSize(2) + cIndex);

            if ch > size(chData(1).chMean, 1) || ismember(ch, chsIgnore)
                continue;
            end

            ax = mu.subplot(Fig, GridSize(1), GridSize(2), EEGPos.map(ch), ...
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

            if ~isempty(channelNames)
                title(ax, channelNames{ch});
            else
                title(ax, ['CH ', num2str(ch)]);
            end

            if ~mod(((rIndex - 1) * GridSize(2) + cIndex - 1), GridSize(2)) == 0
                yticklabels(ax, '');
            end

            if (rIndex - 1) * GridSize(2) + cIndex < (GridSize(1) - 1) * GridSize(2) + 1
                xticklabels(ax, '');
            end

        end

    end

else
    % plot in actual electrode positions
    [~, ~, Th, Rd, ~] = readlocs(locs);
    Th = pi / 180 * Th; % convert degrees to radians
    [XTemp, YTemp] = pol2cart(Th, Rd); % transform electrode locations from polar to cartesian coordinates
    channels = EEGPos.channels;

    % flip
    X = zeros(length(channels), 1);
    Y = zeros(length(channels), 1);
    idx = ~ismember(channels, chsIgnore);
    X(idx) = mapminmax(YTemp(idx), 0.2, 0.8);
    Y(idx) = mapminmax(XTemp(idx), 0.05, 0.92);
    dX = 0.05;
    dY = 0.06;

    Fig = figure("WindowState", "maximized");
    for ch = 1:length(channels)

        if ismember(ch, chsIgnore)
            continue;
        end

        ax = axes('Position', [X(ch) - dX / 2, Y(ch) - dY / 2, dX, dY]);
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

        if ~isempty(channelNames)
            title(ax, channelNames{ch});
        else
            title(ax, ['CH ', num2str(ch)]);
        end
        
    end

    X = X(idx);
    Y = Y(idx);
end

yrange = mu.scaleAxes(Fig, "y");

% legends
if isfield(chData, "legend") && any(~cellfun(@isempty, {chData.legend}))
    if isempty(locs)
        ax = mu.subplot(1, 1, 1, "paddings", zeros(1, 4), "margins", zeros(1, 4));
    else
        ax = axes("Position", [min(X) - dX / 2, min(Y) - dY / 2, max(X) - min(X) + dX, max(Y) - min(Y) + dY]);
    end
    hold(ax, "on");

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

% scaleplate
if strcmpi(Scaleplate, 'show') && ~isempty(locs)
    % create an axes at left-bottom
    ax = axes("Position", [min(X) - dX / 2, min(Y) - dY / 2, dX, dY]);
    hold(ax, "on");
    xlim(ax, window);
    ylim(ax, yrange);
    minXTickSeg = mode(diff(xticks(ax)));
    minYTickSeg = mode(diff(yticks(ax)));
    line(ax, [0, minXTickSeg], [0, 0], "Color", [0, 0, 0], "LineWidth", 1.5);
    line(ax, [0, 0], [0, minYTickSeg], "Color", [0, 0, 0], "LineWidth", 1.5);
    text(ax, minXTickSeg, 0, num2str(minXTickSeg), "HorizontalAlignment", "left", "VerticalAlignment", "middle", "FontSize", 14, "FontWeight", "bold");
    text(ax, 0, minYTickSeg, num2str(minYTickSeg), "HorizontalAlignment", "center", "VerticalAlignment", "bottom", "FontSize", 14, "FontWeight", "bold");
    set(ax, "Visible", "off");

    allAxes = findobj(Fig, "Type", "axes");
    set(allAxes, "XTickLabels", '');
    set(allAxes, "YTickLabels", '');
end

if nargout == 1
    varargout{1} = Fig;
end

return;
end
