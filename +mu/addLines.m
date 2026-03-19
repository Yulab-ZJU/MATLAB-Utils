function addLines(varargin)
%ADDLINES  Add lines to all subplots in figures.
%
% SYNTAX:
%     mu.addLines(LineStruct, 'ConstantLine', true/false, 'Layer', 'top'/'bottom', 'IgnoreInvisible', true/false)
%     mu.addLines(Fig, Lines, ...)
%
% INPUTS:
%   REQUIRED:
%     Lines  - Struct array with fields:
%              [X] : default = []
%              [Y] : default = []
%              and other namevalue pairs (case-ignored) that is valid to function plot
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
ConstantLineOpt = mu.OptionState.create(mIp.Results.ConstantLine).toLogical;
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
        ax = allAxes(aIndex);
        l = Lines(lIndex);

        hold(ax, "on");

        X = mu.getor(l, "X");
        Y = mu.getor(l, "Y");

        if isfield(l, "X"), l = rmfield(l, "X"); end
        if isfield(l, "Y"), l = rmfield(l, "Y"); end

        % get params
        params = mu.struct2nv(l, "FieldCase", "lower", "KeepEmpty", true);
        l = mu.nv2struct(params); % normalize to lower case

        if isempty(X) && isscalar(Y) % yline
            if ConstantLineOpt
                h = yline(ax, Y);
            else
                X = get(ax, "XLim");
                Y = repmat(Y, 1, 2);
                h = plot(ax, X, Y);
            end
        elseif isempty(Y) && isscalar(X) % xline
            if ConstantLineOpt
                h = xline(ax, X);
            else
                Y = get(ax, "YLim");
                X = repmat(X, 1, 2);
                h = plot(ax, X, Y);
            end
        elseif isempty(X) && isempty(Y) % diagonal
            X = get(ax, "XLim");
            Y = get(ax, "YLim");
            h = plot(ax, X, Y);
        else % custom
            h = plot(ax, X, Y);
        end

        if ~isempty(params)
            set(h, params{:});
        end

        if ~isfield(l, "displayname")
            mu.setLegendOff(h);
        end

        uistack(h, Layer);
    end

end

return;
end
