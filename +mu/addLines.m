function addLines(varargin)
%ADDLINES  Add lines to all subplots in figures.
%
% SYNTAX:
%     mu.addLines(Lines, 'ConstantLine', true/false, 'Layer', 'top'/'bottom', 'IgnoreInvisible', true/false)
%     mu.addLines(Fig, Lines, ...)
%
% INPUTS:
%   REQUIRED:
%     Lines  - Struct array with fields:
%              [X]                       : default = []
%              [Y]                       : default = []
%              [color]                   : default = "k"
%              [width]                   : default = 1
%              [style]                   : default = "--"
%              [marker]                  : default = "none"
%              [markerSize]              : default = 6
%              [legend]                  : default = []
%              [label]                   : default = [], for ConstantLine
%              [labelHorizontalAlignment]: default = 'right' (|'center'|'left')
%              [labelVerticalAlignment]  : default = 'top' (|'middle'|'bottom')
%              [labelOrientation]        : default = 'aligned' (|'horizontal')
%              and other namevalue pairs: valid to function plot
%   OPTIONAL:
%     FigsOrAxes      - Figure object array or axes object array
%   NAME-VALUE:
%     ConstantLine    - If set true (default), use xline/yline to create
%                       vertical/horizontal lines when [X] or [Y] is left empty.
%     Layer           - 'top' (default) or 'bottom', layer to plot lines.
%     IgnoreInvisible - If set true, invisible axes in the target figure
%                       will be excluded from drawing (default=true)
%
% NOTES:
%   - If [X] or [Y] is left empty, then best x/y range will be used.
%   - If [X] or [Y] contains 1 element, then the line will be vertical to x or y axis.
%   - If not specified, line legend will not be shown.
%
% EXAMPLES:
%   % Example 1: Draw lines to mark stimuli oneset and offset at t=0, t=1000 ms
%   mu.addLines(Fig, struct("X", {0; 1000}));
%
%   % Example 2: Draw a dividing line y=x for ROC in current axes
%   syncXY(gca); % synchronize x&y range first
%   mu.addLines(gca);

if nargin > 0 && all(isgraphics(varargin{1}))
    FigsOrAxes = varargin{1};
    varargin = varargin(2:end);
else
    FigsOrAxes = gcf;
end

mIp = inputParser;
mIp.addRequired("FigsOrAxes", @(x) all(isgraphics(x)));
mIp.addOptional("Lines", [], @(x) isempty(x) || isstruct(x));
mIp.addParameter("ConstantLine", mu.OptionState.On);
mIp.addParameter("Layer", "top", @(x) ischar(x) || isstring(x));
mIp.addParameter("IgnoreInvisible", mu.OptionState.On);
mIp.parse(FigsOrAxes, varargin{:});

Lines = mIp.Results.Lines;
ConstantLineOpt = mu.OptionState.create(mIp.Results.ConstantLine);
Layer = validatestring(mIp.Results.Layer, {'top', 'bottom'});
IgnoreInvisible = mu.OptionState.create(mIp.Results.IgnoreInvisible).toLogical;

if isempty(Lines)
    Lines.X = [];
    Lines.Y = [];
end

if strcmp(class(FigsOrAxes), "matlab.ui.Figure") || strcmp(class(FigsOrAxes), "matlab.graphics.Graphics")
    allAxes = findobj(FigsOrAxes, "Type", "axes");
else
    allAxes = FigsOrAxes;
end

if IgnoreInvisible
    % exclude invisible axes
    allAxes(cellfun(@(x) eq(x, matlab.lang.OnOffSwitchState.off), {allAxes.Visible}')) = [];
end

%% Plot lines
for lIndex = 1:length(Lines)

    for aIndex = 1:length(allAxes)
        hold(allAxes(aIndex), "on");
        X = mu.getor(Lines(lIndex), "X");
        Y = mu.getor(Lines(lIndex), "Y");
        legendStr  = mu.getor(Lines(lIndex), "legend");
        color      = mu.getor(Lines(lIndex), "color",      mu.getor(Lines(1), "color", "k"),     true);
        lineWidth  = mu.getor(Lines(lIndex), "width",      mu.getor(Lines(1), "width", 1),       true);
        lineStyle  = mu.getor(Lines(lIndex), "style",      mu.getor(Lines(1), "style", "--"),    true);
        marker     = mu.getor(Lines(lIndex), "marker",     mu.getor(Lines(1), "marker", "none"), true);
        markerSize = mu.getor(Lines(lIndex), "markerSize", mu.getor(Lines(1), "markerSize", 6),  true);
        % for constant line
        label                    = mu.getor(Lines(lIndex), "label");
        labelHorizontalAlignment = mu.getor(Lines(lIndex), "labelHorizontalAlignment", mu.getor(Lines(1), "labelHorizontalAlignment", "right"), true);
        labelVerticalAlignment   = mu.getor(Lines(lIndex), "labelVerticalAlignment",   mu.getor(Lines(1), "labelVerticalAlignment", "top"),     true);
        labelOrientation         = mu.getor(Lines(lIndex), "labelOrientation",         mu.getor(Lines(1), "labelOrientation", "aligned"),       true);

        % other namevalue pairs
        allParams = string(fieldnames(Lines(lIndex)));
        builtinParams = ["X", "Y", "color", "width", "style", "marker", "markerSize", "legend", "label", ...
                         "labelHorizontalAlignment", "labelVerticalAlignment", "labelOrientation"];
        otherParams = allParams(~contains(allParams, builtinParams));
        params = {};
        for pIndex = 1:length(otherParams)
            params = [params, cellstr(otherParams{pIndex}), {Lines(lIndex).(otherParams{pIndex})}];
        end

        if isempty(X) && isscalar(Y) % yline
            if ConstantLineOpt.toLogical
                h = yline(allAxes(aIndex), Y, "Color", color, ...
                                              "LineWidth", lineWidth, ...
                                              "LineStyle", lineStyle, ...
                                              "Label", label, ...
                                              "LabelHorizontalAlignment", labelHorizontalAlignment, ...
                                              "LabelVerticalAlignment", labelVerticalAlignment, ...
                                              "LabelOrientation", labelOrientation, ...
                                              params{:});
            else
                X = get(allAxes(aIndex), "XLim");
                Y = repmat(Y, 1, 2);
                h = plot(allAxes(aIndex), X, Y, "Color", color, ...
                                                "Marker", marker, ...
                                                "MarkerSize", markerSize, ...
                                                "LineWidth", lineWidth, ...
                                                "LineStyle", lineStyle, ...
                                                params{:});
            end
        elseif isempty(Y) && isscalar(X) % xline
            if ConstantLineOpt.toLogical
                h = xline(allAxes(aIndex), X, "Color", color, ...
                                              "LineWidth", lineWidth, ...
                                              "LineStyle", lineStyle, ...
                                              "Label", label, ...
                                              "LabelHorizontalAlignment", labelHorizontalAlignment, ...
                                              "LabelVerticalAlignment", labelVerticalAlignment, ...
                                              "LabelOrientation", labelOrientation, ...
                                              params{:});
            else
                Y = get(allAxes(aIndex), "YLim");
                X = repmat(X, 1, 2);
                h = plot(allAxes(aIndex), X, Y, "Color", color, ...
                                                "Marker", marker, ...
                                                "MarkerSize", markerSize, ...
                                                "LineWidth", lineWidth, ...
                                                "LineStyle", lineStyle, ...
                                                params{:});
            end
        elseif isempty(X) && isempty(Y) % diagonal
            X = get(allAxes(aIndex), "XLim");
            Y = get(allAxes(aIndex), "YLim");
            h = plot(allAxes(aIndex), X, Y, "Color", color, ...
                                            "Marker", marker, ...
                                            "MarkerSize", markerSize, ...
                                            "LineWidth", lineWidth, ...
                                            "LineStyle", lineStyle, ...
                                            params{:});
        else % custom
            h = plot(allAxes(aIndex), X, Y, "Color", color, ...
                                            "Marker", marker, ...
                                            "MarkerSize", markerSize, ...
                                            "LineWidth", lineWidth, ...
                                            "LineStyle", lineStyle, ...
                                            params{:});
        end

        if ~isempty(legendStr)
            set(h, "DisplayName", legendStr);
            legend;
        else
            mu.setLegendOff(h);
        end

        uistack(h, Layer);
    end

end

return;
end
