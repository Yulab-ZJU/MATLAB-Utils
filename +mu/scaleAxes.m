function varargout = scaleAxes(varargin)
%SCALEAXES Link axis range of axes in figures, tiledlayouts, or axes arrays.
%
% SYNTAX:
%     mu.scaleAxes(axisName)
%     mu.scaleAxes(axisName, axisRange)
%     mu.scaleAxes(axisName, axisRange, cutoffRange)
%     mu.scaleAxes(axisName, axisRange, cutoffRange, symOpt)
%     mu.scaleAxes(axisName, autoScale, cutoffRange, symOpt)
%     mu.scaleAxes(..., namevalueOptions)
%     mu.scaleAxes(Targets, ...)
%     axisRange = mu.scaleAxes(...)
%
% INPUTS:
%   REQUIRED / OPTIONAL:
%     Targets     - Optional graphics targets. Can be:
%                   figure object array
%                   axes object array
%                   tiledlayout object array
%                   panel/tab/container graphics object array
%
%                   If omitted, gcf is used.
%
%                   All axes under Targets are collected by:
%                       findall(Targets, "Type", "axes")
%
%     axisName    - Axis name: "x", "y", "z", or "c".
%                   Default: "y".
%
%     autoScale   - "on" or "off".
%                   If "on", a data-driven range is computed.
%
%                   For axisName = "y":
%                       YData are collected from visible XLim range of each
%                       axes independently.
%
%                   For axisName = "c":
%                       CData are collected from image objects inside the
%                       visible XLim and YLim range of each axes.
%
%                   For axisName = "x" or "z":
%                       Current axis limits are used.
%
%     axisRange   - Axis limits, specified as a two-element vector.
%                   [] means use the best range.
%                   -Inf or Inf can be used as placeholders:
%                       [-Inf, 10] uses best lower limit and 10 as upper
%                       [0, Inf] uses 0 as lower and best upper limit
%
% NAME-VALUE:
%     cutoffRange      - If axisRange exceeds cutoffRange, axisRange will be
%                        clipped by cutoffRange.
%                        Format: [min, max].
%                        Default: [-Inf, Inf].
%
%     symOpt           - Symmetrical option:
%                        "none"     : no symmetrical adjustment
%                        "min"      : use min(abs(axisRange))
%                        "max"      : use max(abs(axisRange))
%                        "positive" : use positive side as magnitude
%                        "negative" : use negative side as magnitude
%
%     uiOpt            - "show" or "hide". If "show", open scaleAxes UI.
%                        Default: "hide".
%
%     IgnoreInvisible  - If true/on, invisible axes are excluded.
%                        Default: true.
%
%     autoTh           - Quantile thresholds for auto scaling.
%                        Default:
%                            [0, 1]       for "y"
%                            [0.01, 0.99] for "c"
%                            [0, 1]       for others
%
% OUTPUTS:
%     axisRange  - Axis limits applied.
%
% EXAMPLES:
%     mu.scaleAxes("y");
%     mu.scaleAxes("y", [-1, 1]);
%     mu.scaleAxes("y", "on");
%     mu.scaleAxes(gcf, "y", "on");
%     mu.scaleAxes(tiledlayoutObj, "c", "on", "symOpt", "max");
%     axisRange = mu.scaleAxes(axList, "y", [], [-5, 5]);
%
% NOTES:
%   1. Targets can be a tiledlayout object. The function finds all axes
%      inside it automatically.
%
%   2. autoScale="y" uses each axes' own XLim to collect visible YData.
%
%   3. autoScale="c" currently uses image objects. Truecolor RGB images
%      are skipped because CLim does not control truecolor rendering.
%
%   4. For image objects, XData/YData can be either full coordinate vectors
%      or two-element endpoint vectors. Endpoint vectors are expanded to
%      match CData size before visible-range masking.

%% Parse optional Targets input

if nargin > 0 && ~isempty(varargin{1}) && all(isgraphics(varargin{1}(:)))
    Targets = varargin{1};
    varargin = varargin(2:end);
else
    Targets = gcf;
end

%% Parse autoScale positional option
% Backward-compatible behavior:
%   mu.scaleAxes(axisName, "on", cutoffRange, symOpt)
%   mu.scaleAxes(Targets, axisName, "on", cutoffRange, symOpt)

autoScale = "off";

if numel(varargin) > 1 && local_isOnOffText(varargin{2})
    autoScale = string(varargin{2});
    varargin(2) = [];
end

autoScale = string(validatestring(autoScale, {'on', 'off'}));

%% Input parser

mIp = inputParser;

mIp.addRequired("Targets", @(x) all(isgraphics(x(:))));
mIp.addOptional("axisName", "y", @local_isAxisName);
mIp.addOptional("axisRange", [], @local_isRangeOrEmpty);
mIp.addOptional("cutoffRange0", [], @local_isRangeOrEmpty);
mIp.addOptional("symOpts0", [], @local_isSymOptOrEmpty);

mIp.addParameter("cutoffRange", [], @local_isRangeOrEmpty);
mIp.addParameter("symOpt", [], @local_isSymOptOrEmpty);
mIp.addParameter("uiOpt", mu.OptionState.Off, @mu.OptionState.validate);
mIp.addParameter("IgnoreInvisible", mu.OptionState.On, @mu.OptionState.validate);
mIp.addParameter("autoTh", [], @local_isAutoThOrEmpty);

mIp.parse(Targets, varargin{:});

Targets = mIp.Results.Targets;

axisName = string(validatestring(mIp.Results.axisName, {'x', 'y', 'z', 'c'}));

axisRange = mIp.Results.axisRange;
cutoffRange = mu.getor(mIp.Results, "cutoffRange0", mIp.Results.cutoffRange, true);
symOpt = mu.getor(mIp.Results, "symOpts0", mIp.Results.symOpt, true);

if isempty(symOpt)
    symOpt = "none";
else
    symOpt = string(validatestring(symOpt, {'none', 'min', 'max', 'positive', 'negative'}));
end

uiOpt = mu.OptionState.create(mIp.Results.uiOpt);
IgnoreInvisible = mu.OptionState.create(mIp.Results.IgnoreInvisible);
autoTh = mIp.Results.autoTh;

%% Axis property name and default auto thresholds

switch lower(axisName)
    case "x"
        axisLimStr = "XLim";

        if isempty(autoTh)
            autoTh = [0, 1];
        end

    case "y"
        axisLimStr = "YLim";

        if isempty(autoTh)
            autoTh = [0, 1];
        end

    case "z"
        axisLimStr = "ZLim";

        if isempty(autoTh)
            autoTh = [0, 1];
        end

    case "c"
        axisLimStr = "CLim";

        if isempty(autoTh)
            autoTh = [0.01, 0.99];
        end

    otherwise
        error("Wrong axis name input.");
end

%% Collect axes from Targets
% This supports:
%   figure
%   axes
%   tiledlayout
%   uipanel
%   uitab
%   other graphics containers
%
% findall also returns Targets themselves if Targets are axes.

allAxes = findall(Targets(:), "Type", "axes");
allAxes = allAxes(:);

if isempty(allAxes)
    error("No axes found in the input graphics object.");
end

%% Ignore invisible axes

if IgnoreInvisible.toLogical
    visibleMask = strcmpi(string({allAxes.Visible}), "on");
    allAxes = allAxes(visibleMask);

    if isempty(allAxes)
        error("No visible axes found. Please set [IgnoreInvisible] to false.");
    end
end

%% Best axis range from current limits

axisLim = get(allAxes, axisLimStr);

if iscell(axisLim)
    axisLim = cat(1, axisLim{:});
else
    axisLim = axisLim(:).';
end

axisLimMin = min(axisLim(:, 1));
axisLimMax = max(axisLim(:, 2));

%% Data-driven auto scaling

if strcmpi(autoScale, "on")

    switch lower(axisName)
        case "y"
            tempY = local_collectVisibleYData(allAxes);

            if ~isempty(tempY)
                tempY = tempY(isfinite(tempY));

                if ~isempty(tempY)
                    q = quantile(tempY, autoTh);
                    axisLimMin = q(1);
                    axisLimMax = q(2);
                end
            end

        case "c"
            tempC = local_collectVisibleImageCData(allAxes, IgnoreInvisible.toLogical);

            if ~isempty(tempC)
                tempC = tempC(isfinite(tempC));

                if ~isempty(tempC)
                    q = quantile(tempC, autoTh);
                    axisLimMin = q(1);
                    axisLimMax = q(2);
                end
            end

        case {"x", "z"}
            % Keep current best range from existing axis limits.
            % Data-driven x/z scaling can be added later if needed.

        otherwise
            error("Wrong axis name input.");
    end

end

bestRange = [min([axisLimMin, axisLimMax]), max([axisLimMin, axisLimMax])];

%% Resolve axisRange using bestRange

if isempty(axisRange)
    axisRange = bestRange;
else
    axisRange = double(axisRange(:).');

    if axisRange(1) == -inf
        axisRange(1) = bestRange(1);
    end

    if axisRange(2) == inf
        axisRange(2) = bestRange(2);
    end
end

%% Apply cutoffRange

if isempty(cutoffRange)
    cutoffRange = [-inf, inf];
else
    cutoffRange = double(cutoffRange(:).');
end

axisRange(1) = max(axisRange(1), cutoffRange(1));
axisRange(2) = min(axisRange(2), cutoffRange(2));

%% Apply symmetrical range option

if ~strcmpi(symOpt, "none")

    switch lower(symOpt)
        case "min"
            temp = min(abs(axisRange));

        case "max"
            temp = max(abs(axisRange));

        case "positive"
            vals = axisRange(axisRange > 0);

            if isempty(vals)
                temp = [];
            else
                temp = abs(max(vals));
            end

        case "negative"
            vals = axisRange(axisRange < 0);

            if isempty(vals)
                temp = [];
            else
                temp = abs(min(vals));
            end

        otherwise
            error("Invalid symmetrical option input.");
    end

    if ~isempty(temp) && isfinite(temp)
        axisRange = [-temp, temp];
    else
        warning("mu:scaleAxes:InvalidSymOpt", ...
            "Cannot apply symOpt=""%s"" because the required positive/negative side is missing.", symOpt);
    end

end

%% Set axis range

if all(isfinite(axisRange)) && axisRange(1) < axisRange(2)
    set(allAxes, axisLimStr, axisRange);
else
    warning("mu:scaleAxes:NoSuitableRange", ...
        "No suitable range found. axisRange = [%g, %g].", axisRange(1), axisRange(2));
end

%% Call scaleAxes UI

if uiOpt.toLogical
    scaleAxesApp( ...
        allAxes, ...
        char(axisName), ...
        double(axisRange), ...
        double([axisRange(1) - 0.25 * diff(axisRange), ...
                axisRange(2) + 0.25 * diff(axisRange)]));

    drawnow;
end

%% Output

if nargout == 1
    varargout{1} = axisRange;
elseif nargout > 1
    error("The number of outputs should be no greater than 1.");
end

return;
end

%% Local functions

function tf = local_isTextScalar(x)
%LOCAL_ISTEXTSCALAR True for char row vector or scalar string.

tf = ischar(x) || (isstring(x) && isscalar(x));

return;
end

function tf = local_isOnOffText(x)
%LOCAL_ISONOFFTEXT True for text scalar "on" or "off".

tf = local_isTextScalar(x) && any(strcmpi(string(x), ["on", "off"]));

return;
end

function tf = local_isAxisName(x)
%LOCAL_ISAXISNAME Validate axisName.

tf = local_isTextScalar(x) && any(strcmpi(string(x), ["x", "y", "z", "c"]));

return;
end

function tf = local_isRangeOrEmpty(x)
%LOCAL_ISRANGEOREMPTY Validate [] or numeric two-element increasing range.
%
% Allows Inf and -Inf placeholders.
% Rejects NaN.

tf = isempty(x) || ...
    (isnumeric(x) && ...
     isvector(x) && ...
     numel(x) == 2 && ...
     isreal(x) && ...
     all(~isnan(x(:))) && ...
     x(1) <= x(2));

return;
end

function tf = local_isSymOptOrEmpty(x)
%LOCAL_ISSYMOPTOREMPTY Validate [] or supported symOpt text.

tf = isempty(x) || ...
    (local_isTextScalar(x) && ...
     any(strcmpi(string(x), ["none", "min", "max", "positive", "negative"])));

return;
end

function tf = local_isAutoThOrEmpty(x)
%LOCAL_ISAUTOTHOREMPTY Validate [] or two quantile thresholds in [0, 1].

tf = isempty(x) || ...
    (isnumeric(x) && ...
     isvector(x) && ...
     numel(x) == 2 && ...
     isreal(x) && ...
     all(isfinite(x(:))) && ...
     all(x(:) >= 0) && ...
     all(x(:) <= 1) && ...
     x(1) <= x(2));

return;
end

function yAll = local_collectVisibleYData(allAxes)
%LOCAL_COLLECTVISIBLEYDATA Collect YData within each axes' own XLim.
%
% This function inspects children under each axes. Objects without XData or
% YData are skipped. For each axes, its own XLim is used, so axes with
% different x ranges are handled correctly.

yCells = cell(0, 1);

for aIndex = 1:numel(allAxes)
    ax = allAxes(aIndex);
    xRange = sort(double(ax.XLim));

    children = findall(ax);
    children = children(:);

    for cIndex = 1:numel(children)
        child = children(cIndex);

        if ~(isprop(child, "XData") && isprop(child, "YData"))
            continue;
        end

        try
            xData = child.XData;
            yData = child.YData;
        catch
            continue;
        end

        if ~(isnumeric(xData) && isnumeric(yData))
            continue;
        end

        if isempty(xData) || isempty(yData)
            continue;
        end

        xData = double(xData(:));
        yData = double(yData(:));

        if numel(xData) == numel(yData)
            valid = isfinite(xData) & ...
                    isfinite(yData) & ...
                    xData >= xRange(1) & ...
                    xData <= xRange(2);

            if any(valid)
                yCells{end + 1, 1} = yData(valid); %#ok<AGROW>
            end

        elseif isscalar(xData)
            % Rare case: scalar XData with vector YData.
            % Include all YData only if that scalar x is visible.
            if isfinite(xData) && xData >= xRange(1) && xData <= xRange(2)
                valid = isfinite(yData);

                if any(valid)
                    yCells{end + 1, 1} = yData(valid); %#ok<AGROW>
                end
            end
        end
    end
end

if isempty(yCells)
    yAll = [];
else
    yAll = cat(1, yCells{:});
end

return;
end

function cAll = local_collectVisibleImageCData(allAxes, ignoreInvisible)
%LOCAL_COLLECTVISIBLEIMAGECDATA Collect visible image CData inside axes limits.
%
% This function handles common image coordinate cases:
%   image.XData = [x1 x2]
%   image.YData = [y1 y2]
%   image.XData = xVector with numel equal to number of CData columns
%   image.YData = yVector with numel equal to number of CData rows
%
% Truecolor RGB images, whose CData is M-by-N-by-3, are skipped because CLim
% does not control truecolor rendering.

cCells = cell(0, 1);

for aIndex = 1:numel(allAxes)
    ax = allAxes(aIndex);

    xRange = sort(double(ax.XLim));
    yRange = sort(double(ax.YLim));

    images = findall(ax, "Type", "image");
    images = images(:);

    for iIndex = 1:numel(images)
        img = images(iIndex);

        if ignoreInvisible && isprop(img, "Visible") && strcmpi(string(img.Visible), "off")
            continue;
        end

        try
            C = img.CData;
            xData = img.XData;
            yData = img.YData;
        catch
            continue;
        end

        if isempty(C) || ~isnumeric(C)
            continue;
        end

        % Skip truecolor RGB/RGBA images.
        if ndims(C) > 2
            continue;
        end

        C = double(C);

        nRow = size(C, 1);
        nCol = size(C, 2);

        xVec = local_expandImageCoordinate(xData, nCol);
        yVec = local_expandImageCoordinate(yData, nRow);

        if numel(xVec) ~= nCol || numel(yVec) ~= nRow
            continue;
        end

        xMask = isfinite(xVec) & xVec >= xRange(1) & xVec <= xRange(2);
        yMask = isfinite(yVec) & yVec >= yRange(1) & yVec <= yRange(2);

        if any(xMask) && any(yMask)
            tempC = C(yMask, xMask);
            tempC = tempC(:);
            tempC = tempC(isfinite(tempC));

            if ~isempty(tempC)
                cCells{end + 1, 1} = tempC; %#ok<AGROW>
            end
        end
    end
end

if isempty(cCells)
    cAll = [];
else
    cAll = cat(1, cCells{:});
end

return;
end

function coordVec = local_expandImageCoordinate(coordData, nPoint)
%LOCAL_EXPANDIMAGECOORDINATE Convert image XData/YData to pixel coordinates.
%
% For image objects, XData/YData are often two-element endpoint vectors.
% Example:
%   XData = [0, 10], CData has 101 columns
%
% This helper converts that into:
%   linspace(0, 10, 101)
%
% If coordData already has nPoint elements, it is returned as a row vector.

if isempty(coordData)
    coordVec = 1:nPoint;
    return;
end

if ~isnumeric(coordData)
    coordVec = nan(1, nPoint);
    return;
end

coordData = double(coordData(:).');

if numel(coordData) == nPoint
    coordVec = coordData;

elseif numel(coordData) == 1
    coordVec = coordData + (0:nPoint - 1);

else
    % MATLAB image XData/YData commonly uses two endpoints.
    % For any other length mismatch, use the first and last values as
    % endpoints. This is safer than directly indexing CData with coordData.
    coordVec = linspace(coordData(1), coordData(end), nPoint);
end

return;
end