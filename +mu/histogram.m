function varargout = histogram(varargin)
% HISTOGRAM  Grouped histogram with flexible inputs and display options
%
% Usage:
%   H = mu.histogram(X)
%   H = mu.histogram(X, edges)
%   H = mu.histogram(..., 'BinWidth', val, 'FaceColor', {...}, ...)
%   [H, N, edges] = mu.histogram(...)
%
% Inputs:
%   X           - numeric vector, matrix (each row = group), or cell vector of numeric vectors
%   edges       - optional numeric vector of bin edges
%
% Name-Value Pairs:
%   'width'             - bar width (0 < width <= 1), (default=0.8)
%   'LineWidth'         - bar edge linewidth, default 0.5
%   'FaceColor'         - cell array of colors or 'none', per group
%   'EdgeColor'         - cell array of colors or 'none', per group
%   'DisplayName'       - cell array of legend strings per group
%   'BinWidth'          - scalar bin width (overrides BinMethod)
%   'BinMethod'         - method for automatic binning (default 'auto')
%   'DistributionCurve' - 'show' or 'hide' (default 'hide')
%
% Outputs:
%   H       - bar handles array
%   N       - histogram counts matrix (#bins x #groups)
%   edges   - bin edges
%
% Example:
%   x1 = [2 2 3 4];
%   x2 = [1 2 6 8];
%   X = [x1; x2];
%   % For x1,x2 different in size use X = [{x1}; {x2}}];
%   [H, N, edges] = mu.histogram(X, "BinWidth", 1, ...
%                                 "FaceColor", {[1 0 0], [0 0 1]}, ...
%                                 "DisplayName", {'condition 1', 'condition 2'});

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
mIp.addParameter("FaceColor", [], @(x) iscell(x) || (isscalar(x) && strcmpi(x, "none")));
mIp.addParameter("EdgeColor", [], @(x) iscell(x) || (isscalar(x) && strcmpi(x, "none")));
mIp.addParameter("DisplayName", [], @(x) iscell(x));
mIp.addParameter("BinWidth", [], @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
mIp.addParameter("BinMethod", "auto");
mIp.addParameter("GroupSpace", 0.4, @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("CategorySpace", 0, @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("DistributionCurve", mu.OptionState.Off, @mu.OptionState.validate);
mIp.parse(varargin{:});

X = mIp.Results.X;
edges = mIp.Results.edges;
LineWidth = mIp.Results.LineWidth;
FaceColors = mIp.Results.FaceColor;
EdgeColors = mIp.Results.EdgeColor;
legendStrs = mIp.Results.DisplayName;
groupSpace = mIp.Results.GroupSpace;
categorySpace = mIp.Results.CategorySpace;
BinWidth = mIp.Results.BinWidth;
BinMethod = validatestring(mIp.Results.BinMethod, {'auto', 'scott', 'fd', 'integers', 'sturges', 'sqrt'});
DistributionCurve = mu.OptionState.create(mIp.Results.DistributionCurve);

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

if isscalar(FaceColors) && strcmpi(FaceColors, "none")
    FaceColors = repmat({'none'}, numel(X), 1);
end

if isscalar(EdgeColors) && strcmpi(EdgeColors, "none")
    EdgeColors = repmat({'none'}, numel(X), 1);
end

if ~isempty(FaceColors) && numel(FaceColors) ~= numel(X)
    error("Number of face colors should be the same as the data group number");
end

if ~isempty(EdgeColors) && numel(EdgeColors) ~= numel(X)
    error("Number of edge colors should be the same as the data group number");
end

if ~isempty(legendStrs) && numel(legendStrs) ~= numel(X)
    error("Number of legend strings should be the same as the data group number");
end

if isempty(edges)
    % trans cell array X into a numeric column vector
    X_All = cell2mat(cellfun(@(x) x(:), X(:), "UniformOutput", false));

    if isempty(BinWidth)
        [~, edges] = histcounts(X_All, "BinMethod", BinMethod);
    else
        [~, edges] = histcounts(X_All, "BinWidth", BinWidth);
    end

end

BinWidth = mode(diff(edges));

categoryWidthHalf = BinWidth * (1 - categorySpace) / 2;
positions = edges(1:end - 1) + BinWidth / 2;
groupEdgeLeft  = positions - categoryWidthHalf;
groupEdgeRight = positions + categoryWidthHalf;

nGroup = numel(X);
nCategory = numel(edges) - 1;
boxWidth = (1 - (nGroup - 1) * groupSpace) / nGroup * categoryWidthHalf * 2;
boxEdgeLeft  = arrayfun(@(x, y) x:boxWidth + groupSpace * categoryWidthHalf * 2:y, groupEdgeLeft, groupEdgeRight, "UniformOutput", false);
boxEdgeRight = arrayfun(@(x, y) x + boxWidth:boxWidth + groupSpace * categoryWidthHalf * 2:y + boxWidth, groupEdgeLeft, groupEdgeRight, "UniformOutput", false);
boxEdgeLeft  = cat(1, boxEdgeLeft {:}); % [nCategory × nGroup]
boxEdgeRight = cat(1, boxEdgeRight{:}); % [nCategory × nGroup]

[N, boxEdgeLower, boxEdgeUpper] = zeros(nCategory, nGroup);
for index = 1:nGroup
    N(:, index) = histcounts(X{index}, edges);
end
boxEdgeUpper = N;

for cIndex = 1:nCategory
    for gIndex = 1:nGroup
        left = boxEdgeLeft(cIndex, gIndex);
        right = boxEdgeRight(cIndex, gIndex);
        bottom = boxEdgeLower(cIndex, gIndex);
        top = boxEdgeUpper(cIndex, gIndex);
        
        xBox = [left, right, right, left];
        yBox = [top, top, bottom, bottom];
        patch(ax, "XData", xBox, ...
              "YData", yBox, ...
              "EdgeColor", EdgeColors{gIndex}, ...
              "FaceColor", FaceColors{gIndex}, ...
              "LineWidth", LineWidth);
    end
end

% H = bar(ax, edges(1:end - 1) + BinWidth / 2, N, 0.8, "grouped", "LineWidth", LineWidth);

if DistributionCurve.toLogical

    for index = 1:length(H)
        pd = fitdist(X{index}(:), "Kernel");
        temp = linspace(min(edges) - std(X{index}(:)), max(edges) + std(X{index}(:)), 1e3);
        L(index) = plot(ax, temp, pdf(pd, temp) * sum(N(:, index)) * BinWidth, "Color", "k", "LineWidth", 1);
        mu.setLegendOff(L(index));
    end

end

for index = 1:length(H)

    if ~isempty(FaceColors) && ~isempty(FaceColors{index})
        H(index).FaceColor = FaceColors{index};
        L(index).Color = FaceColors{index};
    end

    if ~isempty(EdgeColors) && ~isempty(EdgeColors{index})
        H(index).EdgeColor = EdgeColors{index};
    end

    if ~isempty(legendStrs) && ~isempty(char(legendStrs{index}))
        H(index).DisplayName = legendStrs{index};
    else
        mu.setLegendOff(H(index));
    end

end

if ~isempty(legendStrs)
    legend(ax, "Location", "best");
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