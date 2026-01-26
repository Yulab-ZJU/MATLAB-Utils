function varargout = histogram(varargin)
%HISTOGRAM  Grouped histogram with flexible inputs and display options.
%
% SYNTAX:
%   mu.histogram(X)
%   H = mu.histogram(X)
%   H = mu.histogram(X, edges)
%   H = mu.histogram(..., 'BinWidth', val, 'FaceColor', {...}, ...)
%   [H, N, edges] = mu.histogram(...)
%
% INPUTS:
%   REQUIRED:
%     X      - numeric vector, matrix (each row = group), or cell vector of numeric vectors
%     edges  - optional numeric vector of bin edges
%   NAME-VALUE:
%     LineWidth          - Bar edge linewidth, default=0.5
%     FaceColor          - Cell array of colors or 'none', per group, default: auto-determined
%     EdgeColor          - Cell array of colors or 'none', per group, default='k'
%     GroupSpace         - Normalized space between groups, default=0
%     BinSpace           - Normalized space between bars, default=0
%     DisplayName        - Cell array of legend strings per group
%     BinWidth           - Scalar bin width (overrides BinMethod)
%     BinMethod          - Method for automatic binning (default='auto')
%     DistributionCurve  - 'show' or 'hide' (default='hide')
%     FitCurveLineWidth  - Line width of fitting curves, default=1
%
% OUTPUTS:
%     H       - bar handles array
%     N       - histogram counts matrix (#bins x #groups)
%     edges   - bin edges
%
% EXAMPLE:
%   x1 = [2 2 3 4];
%   x2 = [1 2 6 8];
%   X = [x1; x2];
%   % For x1,x2 different in size use X = [{x1}; {x2}}];
%   [H, N, edges] = mu.histogram(X, "BinWidth", 1, ...
%                                   "FaceColor", {[1 0 0], [0 0 1]}, ...
%                                   "DisplayName", {'condition 1', 'condition 2'});

if strcmp(class(varargin{1}), "matlab.graphics.Graphics")
    ax = varargin{1};
    varargin = varargin(2:end);
else
    ax = gca;
end
hold(ax, "on");

mIp = inputParser;
mIp.addRequired("X", @(x) validateattributes(x, {'numeric', 'cell'}, {'2d'}));
mIp.addOptional("edges", [], @(x) validateattributes(x, {'numeric'}, {'vector'}));
mIp.addParameter("LineWidth", 0.5, @(x) validateattributes(x, {'numeric'}, {'positive'}));
mIp.addParameter("FaceColor", [], @(x) iscell(x) || strcmpi(x, "none"));
mIp.addParameter("EdgeColor", {'k'}, @(x) iscell(x) || strcmpi(x, "none"));
mIp.addParameter("DisplayName", [], @(x) iscell(x));
mIp.addParameter("BinWidth", [], @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
mIp.addParameter("BinMethod", "auto");
mIp.addParameter("GroupSpace", 0, @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("BinSpace", 0, @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("DistributionCurve", mu.OptionState.Off, @mu.OptionState.validate);
mIp.addParameter("FitCurveLineWidth", 1, @(x) validateattributes(x, 'numeric', {'scalar', 'positive'}));
mIp.parse(varargin{:});

X = mIp.Results.X;
edges = mIp.Results.edges;
LineWidth = mIp.Results.LineWidth;
FaceColors = mIp.Results.FaceColor;
EdgeColors = mIp.Results.EdgeColor;
legendStrs = mIp.Results.DisplayName;
groupSpace = mIp.Results.GroupSpace;
binSpace = mIp.Results.BinSpace;
BinWidth = mIp.Results.BinWidth;
BinMethod = validatestring(mIp.Results.BinMethod, {'auto', 'scott', 'fd', 'integers', 'sturges', 'sqrt'});
DistributionCurve = mu.OptionState.create(mIp.Results.DistributionCurve).toLogical;
FitCurveLineWidth = mIp.Results.FitCurveLineWidth;

% Convert X to cell
if isnumeric(X)
    % Convert X to cell vector
    if isvector(X)
        X = {X(:)'};
    else
        % divide by rows
        X = mat2cell(X, ones(size(X, 1), 1));
    end
elseif iscell(X)
    if ~any(cellfun(@(x) isvector(x) && isnumeric(x), X))
        error("Each data group in X should be a numeric vector");
    end
end
nGroup = numel(X);

if ~isempty(legendStrs) && numel(legendStrs) ~= nGroup
    error("Number of legend strings should be the same as the data group number");
end

% Determine colors
colors = num2cell(lines(nGroup), 2);
if strcmpi(FaceColors, "none")
    FaceColors = repmat({'none'}, nGroup, 1);
else
    if isempty(FaceColors)
        FaceColors = colors;
    else
        FaceColors = cellfun(@validatecolor, FaceColors, "UniformOutput", false);
    end
    assert(numel(FaceColors) == nGroup, 'The number of FaceColor should equal to the number of groups %d', nGroup);
end

if strcmpi(EdgeColors, "none") || isempty(EdgeColors)
    EdgeColors = repmat({'none'}, nGroup, 1);
else
    EdgeColors = cellfun(@validatecolor, EdgeColors, "UniformOutput", false);
    if isscalar(EdgeColors)
        EdgeColors = repmat(EdgeColors, nGroup, 1);
    end
    assert(numel(EdgeColors) == nGroup, 'The number of EdgeColor should equal to the number of groups %d', nGroup);
end

% Determine bin edges
if isempty(edges)
    % trans cell array X into a numeric column vector
    X_All = cell2mat(cellfun(@(x) x(:), X(:), "UniformOutput", false));
    if isempty(BinWidth)
        [~, edges] = histcounts(X_All, "BinMethod", BinMethod);
    else
        [~, edges] = histcounts(X_All, "BinWidth", BinWidth);
    end
end
nBin = numel(edges) - 1;
BinWidth = mode(diff(edges));

% Determine bar edges
binWidthHalf = BinWidth * (1 - binSpace) / 2;
positions = edges(1:end - 1) + BinWidth / 2;
groupEdgeLeft  = positions - binWidthHalf;
groupEdgeRight = positions + binWidthHalf;

barWidth = (1 - (nGroup - 1) * groupSpace) / nGroup * binWidthHalf * 2;
barEdgeLeft  = arrayfun(@(x, y) x:barWidth + groupSpace * binWidthHalf * 2:y, groupEdgeLeft, groupEdgeRight, "UniformOutput", false);
barEdgeRight = arrayfun(@(x, y) x + barWidth:barWidth + groupSpace * binWidthHalf * 2:y + barWidth, groupEdgeLeft, groupEdgeRight, "UniformOutput", false);
barEdgeLeft  = cat(1, barEdgeLeft {:}); % [nBin × nGroup]
barEdgeRight = cat(1, barEdgeRight{:}); % [nBin × nGroup]

[N, barEdgeLower] = deal(zeros(nBin, nGroup));
for gIndex = 1:nGroup
    N(:, gIndex) = histcounts(X{gIndex}, edges);
end
barEdgeUpper = N;

% Plot grouped histograms
legendHandles = gobjects(1, nGroup);
for cIndex = 1:nBin
    for gIndex = 1:nGroup
        left = barEdgeLeft(cIndex, gIndex);
        right = barEdgeRight(cIndex, gIndex);
        bottom = barEdgeLower(cIndex, gIndex);
        top = barEdgeUpper(cIndex, gIndex);
        
        xBox = [left, right, right, left];
        yBox = [top, top, bottom, bottom];
        H(cIndex, gIndex) = patch(ax, "XData", xBox, ...
                                      "YData", yBox, ...
                                      "LineWidth", LineWidth, ...
                                      "FaceColor", FaceColors{gIndex}, ...
                                      "EdgeColor", EdgeColors{gIndex});

        if ~isempty(legendStrs) && ~isempty(char(legendStrs{gIndex})) && cIndex == 1
            legendHandles(gIndex) = patch(ax, "XData", nan, ...
                                              "YData", nan, ...
                                              "LineWidth", LineWidth, ...
                                              "FaceColor", FaceColors{gIndex}, ...
                                              "EdgeColor", EdgeColors{gIndex});
        end
    end
end

% Plot distribution curves
if DistributionCurve
    for gIndex = 1:nGroup
        pd = fitdist(X{gIndex}(:), "Kernel");
        temp = linspace(min(edges) - std(X{gIndex}(:)), max(edges) + std(X{gIndex}(:)), 1e3);
        L(gIndex) = plot(ax, temp, pdf(pd, temp) * sum(N(:, gIndex)) * BinWidth, ...
                         "Color", FaceColors{gIndex}, ...
                         "LineWidth", FitCurveLineWidth);
        mu.setLegendOff(L(gIndex));
    end
end

% Show legends
if ~isempty(legendStrs)
    validHandles = isgraphics(legendHandles);
    legend(ax, legendHandles(validHandles), ...
               legendStrs(validHandles), ...
               'Location', 'best', ...
               'AutoUpdate', 'off');
end

xlim(ax, [min(edges), max(edges)]);

if nargout > 0
    varargout{1} = H;
end

if nargout > 1
    varargout{2} = N;
end

if nargout > 2
    varargout{3} = edges;
end

return;
end