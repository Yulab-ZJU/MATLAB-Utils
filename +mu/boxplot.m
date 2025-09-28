function varargout = boxplot(varargin)
%BOXPLOT  Custom grouped boxplot visualization with advanced styling options.
% ════════════════════════════════════════════════════════════════════════
% SYNTAX:
%   [ax, res] = mu.boxplot(X) creates a grouped boxplot for data in cell array X,
%   where each cell corresponds to a group and columns within the cell are categories.
%
%   mu.boxplot(ax, X) draws on specified axes.
%
%   mu.boxplot(..., Name, Value) accepts additional options:
% ════════════════════════════════════════════════════════════════════════
% INPUTS:
% ════════════════════════════════════════════════════════════════════════
%  DATA FORMAT
% ════════════════════════════════════════════════════════════════════════
%   'X'                  : Cell array (1 x nGroup) of matrices [nSample x nCategory]
%                          Each group can contain same-size category columns
%                          Use NaN to pad unequal-length data
%
% ════════════════════════════════════════════════════════════════════════
%  GROUPING CONTROLS
% ════════════════════════════════════════════════════════════════════════
%   'GroupLabels'        : Cell array of strings for each group (primary labels)
%   'CategoryLabels'     : Cell array of strings for each category (secondary labels)
%   'GroupLegends'       : Legend labels for each group (linked to color)
%   'GroupSpace'         : Scalar [0–1] spacing between groups (default: 0.1)
%   'CategorySpace'      : Scalar [0–1] spacing between categories (default: 0.4)
%   'GroupLines'         : Logical, show vertical lines between categories (default: false)
%
% ════════════════════════════════════════════════════════════════════════
%  BOX APPEARANCE
% ════════════════════════════════════════════════════════════════════════
%   'Positions'          : Vector of category center positions (length = nCategory)
%   'BoxEdgeType'        : 'SE', 'STD', or [low high] percentiles (default: [25, 75])
%   'Notch'              : 'on' or 'off' (default: 'off')
%   'Whisker'            : Scalar (×IQR) or [low high] percentiles (default: 1.5)
%   'Colors'             : Color spec: single RGB row, group-level RGBs (nGroup×3), 
%                          or full map (nGroup×nCategory×3)
%   'BoxParameters'      : Patch property pairs for boxes
%   'CenterLineParameters' : Line property pairs for mean/median line
%   'WhiskerParameters'  : Line property pairs for whiskers
%   'WhiskerCapParameters': Line property pairs for whisker caps
%
% ════════════════════════════════════════════════════════════════════════
%  DATA POINTS & OUTLIERS
% ════════════════════════════════════════════════════════════════════════
%   'IndividualDataPoint' : 'show' or 'hide' (default: 'hide')
%   'SymbolParameters'    : Scatter properties for individual data points
%   'Jitter'              : Scalar jitter width in X (default: 0.1)
%   'Outlier'             : 'show' or 'hide' (default: 'show')
%   'OutlierParameters'   : Scatter properties for outliers
%
% ════════════════════════════════════════════════════════════════════════
% OUTPUTS:
% ════════════════════════════════════════════════════════════════════════
%   ax   : Handle to axes used for plotting
%   res  : Struct with computed box edge locations, medians, whiskers, etc.
%
% ════════════════════════════════════════════════════════════════════════
% EXAMPLES:
% ════════════════════════════════════════════════════════════════════════
%     data = {randn(50,3), randn(60,3)}; % 2 groups, 3 categories
%     figure;
%     mu.boxplot(data, ...
%                'GroupLabels', {'Control', 'Treatment'}, ...
%                'CategoryLabels', {'A', 'B', 'C'}, ...
%                'Colors', lines(2), ...
%                'Notch', 'on', ...
%                'IndividualDataPoint', 'show');
%     
%   % see `demo\demo_boxplot.mlx` for more examples.
% ════════════════════════════════════════════════════════════════════════
%  ⚠️  NOTES & CAUTIONS
% ════════════════════════════════════════════════════════════════════════
%   - All groups must contain the same number of categories (columns).
%     Use NaN-padding if some groups lack certain categories.
%
%   - The 'Whisker' input:
%       * scalar: interpreted as multiplier of IQR (e.g. 1.5)
%       * 2-element vector: treated as [low, high] percentiles (e.g. [5, 95])
%
%   - The 'BoxEdgeType' input:
%       * 'SE' : mean ± standard error (based on sample size)
%       * 'STD': mean ± standard deviation
%       * [low, high]: e.g., [25, 75] for quartiles
%
%   - 'Colors' can be:
%       * Single RGB triplet → all boxes same color
%       * Cell array of RGB rows → per group
%       * Full RGB matrix → per category & group (no legend support)
%
%   - For full control, set LineWidth, MarkerSize, Alpha, etc. in
%     'BoxParameters', 'SymbolParameters', etc.
%
%   - Clipping behavior: data points near edges may be clipped.
%     If necessary, manually adjust axis limits or set 'Clipping', 'off'.
%
%   - For hierarchical x-axis labels (group/category), font size follows ax.FontSize.
%     Set it **before** calling mu.boxplot.
%
% ════════════════════════════════════════════════════════════════════════
%
% Copyright (c) 2025 HX Xu. All rights reserved.
% 

if isgraphics(varargin{1}(1), "axes")
    ax = varargin{1}(1);
    varargin = varargin(2:end);
else
    ax = gca;
end

<<<<<<< HEAD
defaultBoxParameters = {"LineStyle", "-", ...
                        "LineWidth", get(0, "defaultLineLineWidth"), ...
=======
defaultSizeData = get(0, "DefaultScatterSizeData");
defaultSizeData = mu.ifelse(isempty(defaultSizeData), 36, defaultSizeData);
defaultLineLineStyle = get(0, "DefaultLineLineStyle");

% Patch
defaultBoxParameters = {"LineStyle", get(0, "DefaultPatchLineStyle"), ...
                        "LineWidth", get(0, "DefaultPatchLineWidth"), ...
>>>>>>> dd43c029748d3558ebf8c44014d8fd3b3d923d53
                        "FaceColor", "none", ...
                        "FaceAlpha", 0.5};

% Line
defaultCenterLineParameters = {"Type", "Median", ...
                               "LineStyle", defaultLineLineStyle, ...
                               "LineWidth", "auto", ...
                               "Color", "auto"};
defaultWhiskerParameters = {"LineStyle", defaultLineLineStyle, ...
                            "LineWidth", "auto", ...
                            "Color", "auto"};
defaultWhiskerCapParameters = {"LineStyle", defaultLineLineStyle, ...
                               "LineWidth", "auto", ...
                               "Color", "auto", ...
                               "Width", 0.4};

% Scatter
defaultSymbolParameters = {"Marker", "o", ...
                           "MarkerEdgeColor", "w", ...
                           "MarkerFaceColor", "auto", ...
                           "MarkerFaceAlpha", 0.3, ...
<<<<<<< HEAD
                           "SizeData", get(0, "defaultScatterSizeData"), ...
                           "LineWidth", get(0, "defaultScatterLineWidth")/5};
defaultOutlierParameters = {"Marker", "+", ...
                            "MarkerEdgeColor", "auto", ...
                            "MarkerFaceColor", "auto", ...
                            "SizeData", get(0, "defaultScatterSizeData"), ...
                            "LineWidth", get(0, "defaultScatterLineWidth")};
=======
                           "SizeData", defaultSizeData, ...
                           "LineWidth", get(0, "DefaultScatterLineWidth")/5};
defaultOutlierParameters = {"Marker", "+", ...
                            "MarkerEdgeColor", "auto", ...
                            "MarkerFaceColor", "auto", ...
                            "SizeData", defaultSizeData, ...
                            "LineWidth", get(0, "DefaultScatterLineWidth")};
>>>>>>> dd43c029748d3558ebf8c44014d8fd3b3d923d53

mIp = inputParser;
mIp.addRequired("ax", @(x) isgraphics(x, "axes"));
mIp.addRequired("X", @(x) validateattributes(x, 'cell', {'vector'}));
mIp.addParameter("Positions", [], @(x) validateattributes(x, 'numeric', {'vector', 'increasing'}));
mIp.addParameter("GroupLabels", '');
mIp.addParameter("GroupLegends", '');
mIp.addParameter("GroupSpace", 0.1, @(x) validateattributes(x, 'numeric', {'scalar'}));
mIp.addParameter("GroupLines", false, @(x) validateattributes(x, 'logical', {'scalar'}));
mIp.addParameter("CategoryLabels", '');
mIp.addParameter("CategorySpace", 0.4, @(x) validateattributes(x, 'numeric', {'scalar'}));
mIp.addParameter("Colors", []);
mIp.addParameter("BoxEdgeType", [25, 75]);
mIp.addParameter("Whisker", 1.5);
mIp.addParameter("Notch", mu.OptionState.Off, @mu.OptionState.validate);
mIp.addParameter("BoxParameters", defaultBoxParameters, @iscell);
mIp.addParameter("CenterLineParameters", defaultCenterLineParameters, @iscell);
mIp.addParameter("WhiskerParameters", defaultWhiskerParameters, @iscell);
mIp.addParameter("WhiskerCapParameters", defaultWhiskerCapParameters, @iscell);
mIp.addParameter("IndividualDataPoint", mu.OptionState.Off, @mu.OptionState.validate);
mIp.addParameter("SymbolParameters", defaultSymbolParameters, @iscell);
mIp.addParameter("Jitter", 0.1, @(x) validateattributes(x, 'numeric', {'scalar'}));
mIp.addParameter("Outlier", mu.OptionState.On, @mu.OptionState.validate);
mIp.addParameter("OutlierParameters", defaultOutlierParameters, @iscell);

mIp.parse(ax, varargin{:});

X = mIp.Results.X;
positions = mIp.Results.Positions;
groupLabels = cellstr(mIp.Results.GroupLabels);
groupSpace = mIp.Results.GroupSpace;
groupLines = mIp.Results.GroupLines;
categoryLabels = cellstr(mIp.Results.CategoryLabels);
groupLegends = cellstr(mIp.Results.GroupLegends);
categorySpace = mIp.Results.CategorySpace;
colors = mIp.Results.Colors;
boxEdgeType = mIp.Results.BoxEdgeType;
notchOpt = mu.OptionState.create(mIp.Results.Notch);
boxParameters = getOrCellParameters(mIp.Results.BoxParameters, defaultBoxParameters);
centerLineParameters = getOrCellParameters(mIp.Results.CenterLineParameters, defaultCenterLineParameters);
whisker = mIp.Results.Whisker;
whiskerParameters = getOrCellParameters(mIp.Results.WhiskerParameters, defaultWhiskerParameters);
whiskerCapParameters = getOrCellParameters(mIp.Results.WhiskerCapParameters, defaultWhiskerCapParameters);
individualDataPoint = mu.OptionState.create(mIp.Results.IndividualDataPoint);
symbolParameters = getOrCellParameters(mIp.Results.SymbolParameters, defaultSymbolParameters);
jitterWidth = mIp.Results.Jitter;
outlierOpt = mu.OptionState.create(mIp.Results.Outlier);
outlierParameters = getOrCellParameters(mIp.Results.OutlierParameters, defaultOutlierParameters);

% Validate
X = X(:);
nCategory = cellfun(@(x) size(x, 2), X); % category number under each group
if ~all(nCategory == nCategory(1))
    error("All groups should contain the same categories. If not, please fill NAN values for that column.");
end
nCategory = nCategory(1);
nGroup = numel(X);

if ~isempty(whisker)
    if isscalar(whisker)
        validateattributes(whisker, 'numeric', {'positive'});
    elseif numel(whisker) == 2
        validateattributes(whisker, 'numeric', {'numel', 2, 'increasing', 'positive', '<=', 100});
    else
        error("The input whisker percentiles should be an increasing 2-element vector (for percentile) or a scalar (for IQR).");
    end
end

boxLineWidth = getNameValue(boxParameters, "LineWidth");
if strcmpi(getNameValue(centerLineParameters, "LineWidth"), "auto")
    centerLineParameters = changeNameValue(centerLineParameters, "LineWidth", boxLineWidth);
end
if strcmpi(getNameValue(whiskerParameters, "LineWidth"), "auto")
    whiskerParameters = changeNameValue(whiskerParameters, "LineWidth", boxLineWidth);
end
if strcmpi(getNameValue(whiskerCapParameters, "LineWidth"), "auto")
    whiskerCapParameters = changeNameValue(whiskerCapParameters, "LineWidth", boxLineWidth);
end

boxFaceColor = getNameValue(boxParameters, "FaceColor");
symbolMarkerFaceColor = getNameValue(symbolParameters, "MarkerFaceColor");
outlierMarkerFaceColor = getNameValue(outlierParameters, "MarkerFaceColor");
outlierMarkerEdgeColor = getNameValue(outlierParameters, "MarkerEdgeColor");

% Compute quartiles and sample size for notch
q1 = cellfun(@(x) prctile(x, 25, 1), X, 'UniformOutput', false);
q2 = cellfun(@(x) prctile(x, 50, 1), X, 'UniformOutput', false); % median
q3 = cellfun(@(x) prctile(x, 75, 1), X, 'UniformOutput', false);
nNonNaN = cellfun(@(x) sum(~isnan(x), 1), X, 'UniformOutput', false); % non-NaN counts

q1 = cat(1, q1{:})'; % [nCategory × nGroup]
q2 = cat(1, q2{:})'; % [nCategory × nGroup]
q3 = cat(1, q3{:})'; % [nCategory × nGroup]
iqr = q3 - q1; % [nCategory × nGroup]
nNonNaN = cat(1, nNonNaN{:})';

% Notch bounds
notchLower = q2 - 1.57 * (q3 - q1) ./ sqrt(nNonNaN);
notchUpper = q2 + 1.57 * (q3 - q1) ./ sqrt(nNonNaN);

% Compute group edge (left & right) for each group
if isempty(positions)
    positions = (1:nCategory)';
else
    positions = positions(:);
    if numel(positions) ~= nCategory
        error("The number of Positions should be equal to the number of categories.");
    end
end
if isscalar(positions)
    categoryWidth0 = 1;
else
    categoryWidth0 = min(diff(positions));
end
categoryEdgeLeft = positions - categoryWidth0 / 2;
categoryWidthHalf = categoryWidth0 * (1 - categorySpace) / 2;
groupEdgeLeft  = positions - categoryWidthHalf;
groupEdgeRight = positions + categoryWidthHalf;

% Compute box width
boxWidth = (1 - (nGroup - 1) * groupSpace) / nGroup * categoryWidthHalf * 2;

% Compute box edge (left & right) for each category
boxEdgeLeft  = arrayfun(@(x, y) x:boxWidth + groupSpace * categoryWidthHalf * 2:y, groupEdgeLeft, groupEdgeRight, "UniformOutput", false);
boxEdgeRight = arrayfun(@(x, y) x + boxWidth:boxWidth + groupSpace * categoryWidthHalf * 2:y + boxWidth, groupEdgeLeft, groupEdgeRight, "UniformOutput", false);
boxEdgeLeft  = cat(1, boxEdgeLeft {:}); % [nCategory × nGroup]
boxEdgeRight = cat(1, boxEdgeRight{:}); % [nCategory × nGroup]

% Compute box edge - top & bottom
if strcmpi(boxEdgeType, "se")
    boxEdgeLower = cellfun(@(x) mean(x, 1, "omitnan") - mu.se(x, 1, "omitnan"), X, "UniformOutput", false);
    boxEdgeUpper = cellfun(@(x) mean(x, 1, "omitnan") + mu.se(x, 1, "omitnan"), X, "UniformOutput", false);
elseif strcmpi(boxEdgeType, "std")
    boxEdgeLower = cellfun(@(x) mean(x, 1, "omitnan") - std(x, [], 1, "omitnan"), X, "UniformOutput", false);
    boxEdgeUpper = cellfun(@(x) mean(x, 1, "omitnan") + std(x, [], 1, "omitnan"), X, "UniformOutput", false);
elseif isnumeric(boxEdgeType) && numel(boxEdgeType) == 2 && boxEdgeType(2) > boxEdgeType(1)
    boxEdgeLower = cellfun(@(x) prctile(x, boxEdgeType(1), 1), X, "UniformOutput", false);
    boxEdgeUpper = cellfun(@(x) prctile(x, boxEdgeType(2), 1), X, "UniformOutput", false);
else
    error("[BoxEdgeType] should be 'SE', 'STD', or a 2-element percentile vector (default=[25,75])");
end
boxEdgeLower = cat(1, boxEdgeLower{:})'; % [nCategory × nGroup]
boxEdgeUpper = cat(1, boxEdgeUpper{:})'; % [nCategory × nGroup]

% Compute whisker
if isscalar(whisker) % whisker length * IQR
    % Compute lower whisker: max(q1 - whisker * IQR, min(data))
    mins = cell2mat(cellfun(@(x) min(x, [], 1), X, 'UniformOutput', false))'; % [nCategory × nGroup]
    maxs = cell2mat(cellfun(@(x) max(x, [], 1), X, 'UniformOutput', false))'; % [nCategory × nGroup]

    whiskerLower = max(q1 - whisker * iqr, mins); % [nCategory × nGroup]
    whiskerUpper = min(q3 + whisker * iqr, maxs); % [nCategory × nGroup]
elseif numel(whisker) == 2 % percentile
    whiskerLower = cellfun(@(x) prctile(x, whisker(1), 1), X, "UniformOutput", false);
    whiskerUpper = cellfun(@(x) prctile(x, whisker(2), 1), X, "UniformOutput", false);
    whiskerLower = cat(1, whiskerLower{:})'; % [nCategory × nGroup]
    whiskerUpper = cat(1, whiskerUpper{:})'; % [nCategory × nGroup]
else % empty
    % do not show whisker
    whiskerLower = [];
    whiskerUpper = [];
end
whiskerCapWidth = getNameValue(whiskerCapParameters, "Width") * boxWidth;
whiskerCapParameters = removeNameValue(whiskerCapParameters, "Width");
whiskerColor = getNameValue(whiskerParameters, "Color");
whiskerCapColor = getNameValue(whiskerCapParameters, "Color");

% Compute outliers
if outlierOpt.toLogical && ~isempty(whisker)
    outliers = cell(nCategory, nGroup);
    for cIndex = 1:nCategory
        for gIndex = 1:nGroup
            idx = X{gIndex}(:, cIndex) < whiskerLower(cIndex, gIndex) | X{gIndex}(:, cIndex) > whiskerUpper(cIndex, gIndex);
            outliers{cIndex, gIndex} = X{gIndex}(idx, cIndex);
        end
    end
end

% Colors
if isempty(colors)
    colors = lines(nGroup);
end
if isnumeric(colors) % single color for all boxes
    if size(colors, 1) == 1
        colors = repmat({repmat(validatecolor(colors), nCategory, 1)}, nGroup, 1);
    elseif size(colors, 1) == nGroup
        colors = mu.rowfun(@(x) repmat(validatecolor(x), nCategory, 1), colors, "UniformOutput", false);
    elseif size(colors, 1) == nCategory * nGroup
        colors = mat2cell(validatecolor(colors, 'multiple'), repmat(nCategory, nGroup, 1), 3);
        warning("Group legends may not work if colors are specified for each category");
    else
        error("The number of colors should either be 1, group number, or category number*group number");
    end
elseif iscell(colors)
    if numel(colors) ~= nGroup
        error("The number of colors should be equal to the number of groups.");
    end
    colors = cellfun(@(x) validatecolor(x, 'multiple'), colors(:), "UniformOutput", false);

    % specifies colors for each category in each group
    nColor = cellfun(@(x) size(x, 1), colors);
    for gIndex = 1:nGroup
        if nColor(gIndex) == 1
            colors{gIndex} = repmat(colors{gIndex}, nCategory, 1);
        elseif nColor(gIndex) ~= nCategory
            error("The number of colors should be equal to the number of categories.");
        end
    end

end

% Center lines
CenterLineType = getNameValue(centerLineParameters, "Type");
if isempty(CenterLineType)
    CenterLineType = 'Mean';
end
CenterLineColor = getNameValue(centerLineParameters, "Color");
centerLineParameters = removeNameValue(centerLineParameters, "Type");

% Boxplot
legendHandles = gobjects(1, nGroup);
legendLabels = cell(1, nGroup);
hold(ax, 'on');
for cIndex = 1:nCategory

    for gIndex = 1:nGroup
        left = boxEdgeLeft(cIndex, gIndex);
        right = boxEdgeRight(cIndex, gIndex);
        mid = (left + right) / 2;

        data = X{gIndex}(:, cIndex);

        % plot outliers
        params = outlierParameters;
        if strcmpi(outlierMarkerEdgeColor, "auto")
            params = changeNameValue(params, "MarkerEdgeColor", colors{gIndex}(cIndex, :));
        end
        if strcmpi(outlierMarkerFaceColor, "auto")
            params = changeNameValue(params, "MarkerFaceColor", colors{gIndex}(cIndex, :));
        end
        if outlierOpt.toLogical && ~isempty(outliers{cIndex, gIndex})
            data = data(~ismember(data, outliers{cIndex, gIndex}));
            scatter(mid * ones(numel(outliers{cIndex, gIndex}), 1), outliers{cIndex, gIndex}, params{:});
        end

        % plot individual data points
        if individualDataPoint.toLogical
            params = symbolParameters;
            if strcmpi(symbolMarkerFaceColor, "auto")
                params = changeNameValue(params, "MarkerFaceColor", colors{gIndex}(cIndex, :));
            end

            swarmchart(mid * ones(numel(data), 1), data, ...
                       "XJitterWidth", jitterWidth * categoryWidth0, params{:});
        end
        
        % plot box
        params = boxParameters;
        if strcmpi(boxFaceColor, "auto")
            params = changeNameValue(params, "FaceColor", colors{gIndex}(cIndex, :));
        end
        if notchOpt.toLogical
            notchWidth = boxWidth * 0.3;
            top = q3(cIndex, gIndex);
            bottom = q1(cIndex, gIndex);

            xBox = [left, left, ...
                    mid - notchWidth, ...
                    left, left, ...
                    right, right, ...
                    mid + notchWidth, ...
                    right, right];
            yBox = [top, notchUpper(cIndex, gIndex), ...
                    q2(cIndex, gIndex), ...
                    notchLower(cIndex, gIndex), bottom, ...
                    bottom, notchLower(cIndex, gIndex), ...
                    q2(cIndex, gIndex), ...
                    notchUpper(cIndex, gIndex), top];

            CenterLineType = 'Median';
            centerLineX = [mid - notchWidth, mid + notchWidth];
        else
            bottom = boxEdgeLower(cIndex, gIndex);
            top = boxEdgeUpper(cIndex, gIndex);

            xBox = [left, right, right, left];
            yBox = [top, top, bottom, bottom];
            centerLineX = [left, right];
        end
        patch(ax, "XData", xBox, ...
                  "YData", yBox, ...
                  "EdgeColor", colors{gIndex}(cIndex, :), ...
                  params{:});

        % set legends
        if cIndex == 1
            if strcmpi(boxFaceColor, "none")
                params = changeNameValue(params, "FaceColor", get(ax, "Color"));
            end
            legendHandles(gIndex) = patch(ax, "XData", nan, ...
                                              "YData", nan, ...
                                              "EdgeColor", colors{gIndex}(cIndex, :), ...
                                              params{:});
            if ~isempty(groupLegends) && numel(groupLegends) >= gIndex
                legendLabels{gIndex} = groupLegends{gIndex};
            end
        end
        
        % plot center line
        params = centerLineParameters;
        if strcmpi(CenterLineColor, "auto")
            params = changeNameValue(params, "Color", colors{gIndex}(cIndex, :));
        end
        if strcmpi(CenterLineType, 'mean')
            yCenterLine = mean(X{gIndex}(:, cIndex), 1, "omitnan");
        elseif strcmpi(CenterLineType, 'median')
            yCenterLine = median(X{gIndex}(:, cIndex), 1, "omitnan");
        else
            error("Invalid center line type");
        end
        line(ax, centerLineX, [yCenterLine, yCenterLine], params{:});

        % plot whisker
        if ~isempty(whisker)
            % whisker
            params = whiskerParameters;
            if strcmpi(whiskerColor, "auto")
                params = changeNameValue(params, "Color", colors{gIndex}(cIndex, :));
            end
            line(ax, [mid, mid], [bottom, whiskerLower(cIndex, gIndex)], params{:});
            line(ax, [mid, mid], [top,    whiskerUpper(cIndex, gIndex)], params{:});
            
            % whisker cap
            params = whiskerCapParameters;
            if strcmpi(whiskerCapColor, "auto")
                params = changeNameValue(params, "Color", colors{gIndex}(cIndex, :));
            end
            line(ax, [mid - whiskerCapWidth / 2, mid + whiskerCapWidth / 2], ...
                     [whiskerLower(cIndex, gIndex), whiskerLower(cIndex, gIndex)], params{:});
            line(ax, [mid - whiskerCapWidth / 2, mid + whiskerCapWidth / 2], ...
                     [whiskerUpper(cIndex, gIndex), whiskerUpper(cIndex, gIndex)], params{:});
        end

        % plot group division lines
        if groupLines && cIndex > 1 && gIndex == 1
            xline(ax, categoryEdgeLeft(cIndex));
        end

    end

end

% set x-axis range
if isequal(positions, (1:nCategory)')
    xlim(ax, [0.5, nCategory + 0.5]);
end
drawnow;

% set labels
setupAxisLabels(ax, nGroup, nCategory, boxEdgeLeft, boxEdgeRight, groupLabels, categoryLabels);

% show legends
if ~all(cellfun(@isempty, groupLegends))
    validHandles = isgraphics(legendHandles);
    legend(ax, legendHandles(validHandles), ...
               legendLabels(validHandles), ...
               'Location', 'best', ...
               'AutoUpdate', 'off');
end

if nargout >= 1
    varargout{1} = ax;
end

if nargout == 2
    res = [];

    % Box edges: category-by-group
    res.boxEdgeLeft = boxEdgeLeft;
    res.boxEdgeRight = boxEdgeRight;
    res.boxCenters = (boxEdgeLeft + boxEdgeRight) / 2;
    res.boxEdgeLower = boxEdgeLower;
    res.boxEdgeUpper = boxEdgeUpper;
    res.q1 = q1;
    res.q3 = q3;
    res.median = q2;
    res.whiskerLower = whiskerLower;
    res.whiskerUpper = whiskerUpper;
    res.dimord = 'category_group';

    res.whisker = whisker;
    res.Positions = positions;
    res.centerLineType = CenterLineType;

    varargout{2} = res;
end

% redirect gca to ax
axes(ax);
return;
end

%% Utils
function A = getOrCellParameters(C, default)
    params0 = cellstr(default(1:2:end));
    params = cellstr(C(1:2:end));
    A = C(:)';

    for index = 1:numel(params0)
        if ~ismember(params0(index), params)
            A = [A, params0(index), default(2 * index)];
        end
    end

    return;
end

function val = getNameValue(C, key)
    if mod(numel(C), 2) ~= 0
        error("Name-values should be paired");
    end

    map = containers.Map(cellstr(C(1:2:end)), C(2:2:end));

    if isKey(map, key)
        val = map(key);
    else
        val = [];
    end

    return;
end

function C = changeNameValue(C, key, val)
    if mod(numel(C), 2) ~= 0
        error("Name-values should be paired");
    end

    map = containers.Map(cellstr(C(1:2:end)), C(2:2:end));

    if isKey(map, key)
        map(key) = val;
    else
        error(strcat(key, " is not a parameter"));
    end
    
    C = [map.keys; map.values];
    C = C(:)';
    return;
end

function C = removeNameValue(C, key)
    if mod(numel(C), 2) ~= 0
        error("Name-values should be paired");
    end

    map = containers.Map(cellstr(C(1:2:end)), C(2:2:end));

    if isKey(map, key)
        remove(map, key);
    end

    C = [map.keys; map.values];
    C = C(:)';
    return;
end

function setupAxisLabels(ax, nGroup, nCategory, boxEdgeLeft, boxEdgeRight, GroupLabels, CategoryLabels)
    hasGroupLabels = ~all(cellfun(@isempty, GroupLabels));
    hasCategoryLabels = ~all(cellfun(@isempty, CategoryLabels));

    % label positions
    boxCenters = (boxEdgeLeft + boxEdgeRight) / 2; % [nCategory × nGroup]

    if hasGroupLabels && ~hasCategoryLabels
        set(ax, "XTick", sort(boxCenters(:), "ascend"), ...
                "XTickLabel", repmat(GroupLabels(:)', 1, nCategory));
    elseif ~hasGroupLabels && hasCategoryLabels
        set(ax, "XTick", mean(boxCenters, 2), ...
                "XTickLabel", CategoryLabels);
    elseif hasGroupLabels && hasCategoryLabels
        % remove current xticklabels
        set(ax, "XTick", sort(boxCenters(:), "ascend"), "XTickLabel", []);

        % current axes positions
        pos = get(ax, "Position");
        labelAx = axes("Position", [pos(1), pos(2) - pos(4) * 0.15, pos(3), pos(4) * 0.15], "Visible", "off");

        % label position
        labelPosY_group = 0.8;
        labelPosY_category = 0.5;

        % group labels (primary labels)
        for gIndex = 1:nGroup
            for cIndex = 1:nCategory
                text(labelAx, boxCenters(cIndex, gIndex), labelPosY_group, GroupLabels{gIndex}, ...
                     "HorizontalAlignment", "center", ...
                     "VerticalAlignment", "middle", ...
                     "FontName", "Arial", ...
                     "FontSize", get(ax, "FontSize"));
            end
        end

        % category labels (secondary labels)
        for cIndex = 1:nCategory
            text(labelAx, cIndex, labelPosY_category, CategoryLabels{cIndex}, ...
                 "HorizontalAlignment", "center", ...
                 "VerticalAlignment", "middle", ...
                 "FontName", "Arial", ...
                 "FontWeight", "bold", ...
                 "FontSize", get(ax, "FontSize"));
        end

        xlim(labelAx, xlim(ax));
        ylim(labelAx, [0, 1]);
    else
        set(ax, 'XTick', [], 'XTickLabel', []);
    end

    return;
end