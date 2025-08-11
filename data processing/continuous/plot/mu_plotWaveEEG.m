function varargout = mu_plotWaveEEG(chData, window, EEGPos, varargin)
% Plot multi-group waves for multi-channel EEG data
%--------------------------------------------------------------------------------
% INPUT
%   REQUIRED
%     chData: n*1 struct of fields (* is required)
%       - *chMean: [nCh x nSample]
%       - chErr: [nCh x nSample], errorbar (if left empty, errorbar will not be shown)
%       - color: [R,G,B] or valid color string (default='r')
%       - legend: string or char, not shown if set empty.
%       - lineWidth: specify line width for each group (default: using the general setting)
%     window: time window [winStart,winEnd], in ms
%     EEGPos: EEG position struct. See EEGPos_Neuracle64.m
%
%   NAME-VALUE PARAMETERS
%   - 'LineWidth': General line width setting (default=1.5)
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
mIp.addParameter("paddings", [.01, .03, .01, .01], @(x) validateattributes(x, 'numeric', {'numel', 4}));
mIp.addParameter("LineWidth", 1.5, @(x) validateattributes(x, 'numeric', {'scalar', 'positive'}));
mIp.parse(chData, window, varargin{:});

defaultLineWidth = mIp.Results.LineWidth;
margins = mIp.Results.margins;
paddings = mIp.Results.paddings;

GridSize = EEGPos.grid;
chsIgnore = mu.getor(EEGPos, "ignore");
locs = mu.getor(EEGPos, "locs");
channelNames = mu.getor(EEGPos, "channelNames");

chData = chData(:);
if ~isfield(chData, "color")
    chData = mu.addfield(chData, "color", num2cell(lines(numel(chData)), 2));
end

if isempty(locs)
    % plot in grid map
    Fig = figure("WindowState", "maximized");
    for rIndex = 1:GridSize(1)

        for cIndex = 1:GridSize(2)
            ch = (rIndex - 1) * GridSize(2) + cIndex;

            if ch > size(chData(1).chMean, 1) || ismember(ch, chsIgnore)
                continue;
            end

            ax = mu.subplot(Fig, GridSize(1), GridSize(2), EEGPos.map(ch), ...
                            "margins", margins, "paddings", paddings);
            hold(ax, "on");

            for gIndex = 1:length(chData)
                chMean = chData(gIndex).chMean;
                t = linspace(window(1), window(2), size(chMean, 2));
                legendStr = mu.getor(chData(gIndex), "legend", '');
                lineWidth = mu.getor(chData(gIndex), "lineWidth", defaultLineWidth);
                h = plot(ax, t, chMean(ch, :), "LineWidth", lineWidth, "Color", chData(gIndex).color, "DisplayName", legendStr);

                if isempty(legendStr) || ch > 1
                    mu.setLegendOff(h);
                end

            end

            xlim(ax, window);

            if ~isempty(channelNames)
                title(ax, channelNames{ch});
            else
                title(ax, ['CH ', num2str(ch)]);
            end

            yticks(ax, []);
            yticklabels(ax, '');

            if ch < (GridSize(1) - 1) * GridSize(2) + 1
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
            t = linspace(window(1), window(2), size(chMean, 2));
            legendStr = mu.getor(chData(gIndex), "legend", '');
            lineWidth = mu.getor(chData(gIndex), "lineWidth", defaultLineWidth);
            h = plot(ax, t, chMean(ch, :), "LineWidth", lineWidth, "Color", chData(gIndex).color, "DisplayName", legendStr);

            if isempty(legendStr) || ch > 1
                mu.setLegendOff(h);
            end

        end

        xlim(ax, window);

        if ~isempty(channelNames)
            title(ax, channelNames{ch});
        else
            title(ax, ['CH ', num2str(ch)]);
        end
        
    end
    
end

mu.scaleAxes(Fig, "y", "on", "autoTh", [0, 1]);

if nargout == 1
    varargout{1} = Fig;
end

return;
end
