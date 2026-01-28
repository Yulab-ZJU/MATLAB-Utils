function h = dotplot(varargin)
%DOTPLOT  Swarm/dot plot with optional Spread (IQR/SE/STD), CenterLine, and CI.
%
% h = mu.dotplot(X)
% h = mu.dotplot(ax, X)
% h = mu.dotplot(..., 'Name',Value, ...)
%
% INPUT
%   ax : axes handle (default gca)
%   X  : cell(1,nGroup) each is [n x 1] numeric vector
%        or numeric matrix [n x nGroup]
%
% TOP-LEVEL Name-Value
%   'Orientation'   : 'vertical'(default) | 'horizontal'
%   'HDirection'    : 'right'(default) | 'left', horizontal data direction
%   'GroupLabels'   : cellstr/string (default auto 1:nGroup)
%   'Colors'        : [nGroup x 3] | [1 x 3] | cell(1,nGroup) of RGB
%   'Positions'     : numeric (1 x nGroup) (default 1:nGroup)
%   'GroupSpace'    : Scalar [0–1] spacing between groups (default: 0.2)
%
% CELL-SPEC OPTIONS (mu.boxplot-style)
%   'Spread'           : 'show' or 'hide' (default 'hide')
%   'SpreadParameters' : {'metric','IQR'/'SE'/'STD', ...
%                         'range',[25 75]          , ... % for IQR only
%                         'plottype','patch'/'line', ...
%                         NV}
%                        Metric:
%                           - IQR (default): also supports 'range',[25 75] (percentiles)
%                           - SE/STD
%                        Plottype:
%                           - patch (default): width auto (half the maximum jitter); default gray face
%                           - line
%                        Remaining NV passed to line() or patch()
%   
%   'CenterLine'           : 'show' or 'hide' (default 'show')
%   'CenterLineParameters' : {'stat','median'/'mean', NV}
%                            Statistic: default 'median'
%                            Remaining NV passed to line()
%
%   'CI'           : 'show' or 'hide' (default 'show')
%   'CIParameters' : {'method','bootstrap'/'t', 'nperm',5000, 'alpha',0.05, NV}
%                     Method: default 'bootstrap'
%                     Remaining NV passed to line()
%
%   'Dot'           : 'show' or 'hide' (default 'show')
%   'DotParameters' : {'jitter',0.25, NV}
%                     Remaining NV passed to swarmchart()/scatter()
%
% OUTPUT
%   h : struct with fields
%       .Ax, .Dots, .Spread, .Center, .CI
%
% Notes
%   - horizontal mode draws dots as (x=data, y=group+jitter) and summaries on that axis.
%   - If CI method='bootstrap', uses percentile CI on the chosen center statistic.
%
% Style defaults: semi-transparent filled dots with white edges.
%
% Examples:
%   rng(1)
%   X = {randn(30,1) * 0.15 + 0.6};
%   figure;
%   mu.subplot(1, 1, 1, [0.2, 0.6]);
%   mu.dotplot(X, "CenterLineParameters", {'color', 'k'}, "CIParameters", {'linewidth', 1});
%   ylabel("Ratio");
%   title("Example 1: single group, vertical (default)");
%
%   rng(2)
%   X = {
%     randn(40,1)*0.10 + 0.55
%     randn(42,1)*0.12 + 0.65
%     randn(38,1)*0.08 + 0.75
%   };
%   figure;
%   mu.subplot(1, 1, 1, [0.2, 0.6]);
%   mu.dotplot(X, ...
%     "GroupLabels", ["Reg 4-4","Irreg 4-4","Irreg 4-4.06"], ...
%     "GroupSpace", 0.25);
%   ylabel("Detection ratio");
%   title("Example 2: multi-group vertical");
% 
%   rng(3)
%   X = {
%       randn(40,1)*0.10 + 0.6
%       randn(40,1)*0.10 + 0.7
%   };
%   figure;
%   mu.subplot(1, 1, 1, [0.4, 0.4]);
%   mu.dotplot(X, ...
%       "Orientation","horizontal", ...
%       "HDirection","left", ...
%       "GroupLabels", ["Before","After"]);
%   xlabel("Ratio (reversed)");
%   title("Example 3: horizontal, reversed direction");

if isgraphics(varargin{1}(1), "axes")
    ax = varargin{1}(1);
    varargin = varargin(2:end);
else
    ax = gca;
end

%%% -------------------- Validate & Defaults -------------------- %%%
DefaultCenterLineParams = struct("stat", "median", ...
                                 "color", "auto"); % use group Colors

DefaultCIParams = struct("method", "bootstrap", ...
                         "nperm", 5e3, ...
                         "alpha", 0.05, ...
                         "linewidth", 0.75, ...
                         "color", "auto"); % use center line color

defaultSizeData = get(0, "DefaultScatterSizeData");
defaultSizeData = mu.ifelse(isempty(defaultSizeData), 36, defaultSizeData);
DefaultDotParams = struct("jitter", 0.25, ...
                          "marker", "o", ...
                          "markeredgecolor", "w", ...
                          "markerfacecolor", "auto", ... % use group colors
                          "markerfacealpha", 0.3, ...
                          "sizedata", defaultSizeData, ...
                          "linewidth", get(0, "DefaultScatterLineWidth")/5);

DefaultSpreadParams = struct("metric", "IQR", ...
                             "plottype", "patch", ...
                             "range", [25, 75], ...            % for IQR
                             "facecolor", [0.6, 0.6, 0.6], ... % for patch
                             "edgecolor", "none", ...          % for patch
                             "facealpha", 0.4);                % for patch

mIp = inputParser;
mIp.addRequired("X", @(x) validateattributes(x, 'cell', {'vector'}));
mIp.addParameter("Orientation", "vertical", @mustBeTextScalar);
mIp.addParameter("HDirection" , "right", @mustBeTextScalar);
mIp.addParameter("GroupLabels", '', @mustBeText);
mIp.addParameter("Positions", [], @(x) validateattributes(x, 'numeric', {'vector', 'real'}));
mIp.addParameter("GroupSpace", 0.2, @(x) validateattributes(x, 'numeric', {'scalar', 'real'}));
mIp.addParameter("Colors", []);
mIp.addParameter("Spread", mu.OptionState.On, @mu.OptionState.validate);
mIp.addParameter("SpreadParameters", {}, @iscell);
mIp.addParameter("CenterLine", mu.OptionState.On, @mu.OptionState.validate);
mIp.addParameter("CenterLineParameters", {}, @iscell);
mIp.addParameter("CI", mu.OptionState.On, @mu.OptionState.validate);
mIp.addParameter("CIParameters", {}, @iscell);
mIp.addParameter("Dot", mu.OptionState.On, @mu.OptionState.validate);
mIp.addParameter("DotParameters", {}, @iscell);
mIp.parse(varargin{:});

X = mIp.Results.X(:);
ngroup = numel(X);
cellfun(@(x) validateattributes(x, 'numeric', {'vector', 'real'}), X);

Orientation = validatestring(mIp.Results.Orientation, {'vertical', 'horizontal'});
HDirection  = validatestring(mIp.Results.HDirection, {'right', 'left'});

GroupSpace = mIp.Results.GroupSpace;
Positions  = mIp.Results.Positions(:);
Positions  = mu.ifelse(isempty(Positions), (1:ngroup)', Positions);
assert(numel(Positions) == ngroup, "numel(Positions) should be equal to %d", ngroup);
if isscalar(Positions)
    GroupWidth = 1 - GroupSpace;
else
    GroupWidth = diff(Positions) * (1 - GroupSpace);
    GroupWidth = [GroupWidth; GroupWidth(end)];
end

GroupLabels = mIp.Results.GroupLabels;
GroupLabels = mu.ifelse(isempty(GroupLabels), compose("%d", 1:ngroup), cellstr(GroupLabels));
assert(numel(GroupLabels) == ngroup, "numel(GroupLabels) should be equal to %d", ngroup);

Colors = mIp.Results.Colors;
if isempty(Colors)
    Colors = lines(ngroup);
else
    Colors = validatecolor(Colors, "multiple");
    if size(Colors, 1) == 1 % one color for all groups
        Colors = repmat(Colors, ngroup, 1);
    end
    assert(size(Colors, 1) == ngroup, "numel(Colors) should be equal to %d", ngroup);
end

Spread = mu.OptionState.create(mIp.Results.Spread).toLogical;
SpreadParams = mu.nv2struct(mIp.Results.SpreadParameters, "format", "lower");
SpreadParams = mu.getorfull(SpreadParams, DefaultSpreadParams);
switch upper(SpreadParams.metric)
    case "IQR"
        r = SpreadParams.range;
        validateattributes(r, 'numeric', {'numel', 2, 'increasing', 'nonnegative', '<=', 100});
        sval = cellfun(@(x) [prctile(x, r(1)), prctile(x, r(2))], X, "UniformOutput", false);
    case "SE"
        sval = cellfun(@(x) [-1, 1] * mu.se(x), X, "UniformOutput", false);
    case "STD"
        sval = cellfun(@(x) [-1, 1] * std(x), X, "UniformOutput", false);
    otherwise
        error("Invalid metric %s. Should be IQR/SE/STD", SpreadParams.metric);
end
sval = cat(1, sval{:}); % [ngroup x 2]
SpreadParams = rmfield(SpreadParams, ["range", "metric"]);

CenterLine = mu.OptionState.create(mIp.Results.CenterLine).toLogical;
CenterLineParams = mu.nv2struct(mIp.Results.CenterLineParameters, "format", "lower");
CenterLineParams = mu.getorfull(CenterLineParams, DefaultCenterLineParams);

CI = mu.OptionState.create(mIp.Results.CI).toLogical;
CIParams = mu.nv2struct(mIp.Results.CIParameters, "format", "lower");
CIParams = mu.getorfull(CIParams, DefaultCIParams);

Dot = mu.OptionState.create(mIp.Results.Dot).toLogical;
DotParams = mu.nv2struct(mIp.Results.DotParameters, "format", "lower");
DotParams = mu.getorfull(DotParams, DefaultDotParams);

%%% -------------------- Plot -------------------- %%%
hold(ax, "on");
h = struct();

for gIndex = 1:ngroup
    ydata = X{gIndex};
    n  = numel(ydata);
    x0 = Positions(gIndex);
    gw = GroupWidth(gIndex);
    C = Colors(gIndex, :);

    [h(gIndex).Dots, h(gIndex).Center, h(gIndex).Spread, h(gIndex).CI] = deal(gobjects(1));

    % ---------- Spread ---------- %
    if Spread
        paramsTemp = rmfield(SpreadParams, "plottype");
        switch SpreadParams.plottype
            case "patch"
                facecolor = mu.getor(paramsTemp, "facecolor");
                if strcmpi(facecolor, "auto")
                    paramsTemp.facecolor = C;
                end
                if strcmpi(Orientation, "vertical")
                    h(gIndex).Spread = patch(ax, "XData", [x0 - gw/8, x0 + gw/8, x0 + gw/8, x0 - gw/8], ...
                                                 "YData", [sval(gIndex, 1), sval(gIndex, 1), sval(gIndex, 2), sval(gIndex, 2)]);
                else % horizontal
                    h(gIndex).Spread = patch(ax, "XData", [sval(gIndex, 1), sval(gIndex, 1), sval(gIndex, 2), sval(gIndex, 2)], ...
                                                 "YData", [x0 - gw/8, x0 + gw/8, x0 + gw/8, x0 - gw/8]);
                end
                applyNV_(h(gIndex).Spread, paramsTemp);
            case "line"
                linecolor = mu.getor(paramsTemp, "color");
                if strcmpi(linecolor, "auto")
                    paramsTemp.color = C;
                end
                paramsTemp = rmfield(paramsTemp, ["facecolor", "facealpha", "edgecolor"]);
                if strcmpi(Orientation, "vertical")
                    h(gIndex).Spread = line(ax, [x0, x0], sval(gIndex, :));
                else % horizontal
                    h(gIndex).Spread = line(ax, sval(gIndex, :), [x0, x0]);
                end
                applyNV_(h(gIndex).Spread, paramsTemp);
            otherwise
                error("Invalid plot type %s. Should be patch/linne", SpreadParams.plottype);
        end
    end

    % ---------- Dot ---------- %
    paramsTemp = rmfield(DotParams, "jitter");
    if strcmpi(paramsTemp.markerfacecolor, "auto")
        paramsTemp.markerfacecolor = C;
    end
    if Dot
        if strcmpi(Orientation, "vertical")
            xdata = ones(size(ydata)) * x0;
            h(gIndex).Dots = swarmchart(ax, xdata, ydata, "XJitterWidth", DotParams.jitter * gw);
        else % horizontal
            xdata = uniformSymmetricJitter(x0, gw/4, [n, 1]);
            h(gIndex).Dots = scatter(ax, ydata, xdata);
        end
        applyNV_(h(gIndex).Dots, paramsTemp);
    end

    % ---------- Center line ---------- %
    paramsTemp = CenterLineParams;
    if strcmpi(paramsTemp.color, "auto")
        paramsTemp.color = C;
    end
    linecolorCenter = paramsTemp.color;
    if isempty(mu.getor(paramsTemp, "linewidth"))
        paramsTemp.linewidth = mu.getor(CIParams, "linewidth", get(0, "DefaultLineLineWidth")) * 2;
    end
    if CenterLine
        switch CenterLineParams.stat
            case "median"
                center = median(ydata);
            case "mean"
                center = mean(ydata);
        end
        if strcmpi(Orientation, "vertical")
            h(gIndex).Center = line(ax, [x0 - gw/4, x0 + gw/4], [center, center]);
        else % horizontal
            h(gIndex).Center = line(ax, [center, center], [x0 - gw/4, x0 + gw/4]);
        end
        applyNV_(h(gIndex).Center, paramsTemp);
    end

    % ---------- CI ---------- %
    paramsTemp = CIParams;
    if strcmpi(paramsTemp.color, "auto")
        paramsTemp.color = linecolorCenter;
    end
    if CI
        estFun = str2func(CenterLineParams.stat);
        alpha = CIParams.alpha;
        switch lower(CIParams.method)
            case "bootstrap"
                % bootstrap percentile CI
                B = CIParams.nperm;
                if isempty(B) || B < 200, B = 2000; end
                n = numel(ydata);
                boot = zeros(B, 1);
                for b=1:B
                    boot(b) = estFun(ydata(randi(n, n, 1)));
                end
                lo = prctile(boot, 100*(alpha/2));
                hi = prctile(boot, 100*(1-alpha/2));

            case "t"
                % t-based CI (assumes approx normality of estimator; best for mean)
                est = estFun(ydata);
                n = sum(isfinite(ydata));
                se = std(y, 'omitnan') / sqrt(max(1, n));
                tcrit = tinv(1 - alpha/2, max(1,n - 1));
                lo = est - tcrit * se;
                hi = est + tcrit * se;

            otherwise
                error("Invalid CI method %s. Should be bootstrap/t.", CIParams.method);
        end
        if strcmpi(Orientation, "vertical")
            h(gIndex).CI = line(ax, [x0, x0], [lo, hi]);
        else % horizontal
            h(gIndex).CI = line(ax, [lo, hi], [x0, x0]);
        end
        applyNV_(h(gIndex).CI, paramsTemp);
    end

end

% Group labels
if strcmpi(Orientation, "vertical")
    xlim([Positions(1) - GroupWidth(1)/2, Positions(end) + GroupWidth(end)/2]);
    xticks(ax, Positions);
    xticklabels(ax, GroupLabels);
else
    ylim([Positions(1) - GroupWidth(1)/2, Positions(end) + GroupWidth(end)/2]);
    yticks(ax, Positions);
    yticklabels(ax, GroupLabels);
end

% Horizontal direction
if strcmpi(Orientation, "horizontal") && strcmpi(HDirection, "left")
    set(ax, "XDir", "reverse");
    set(ax, "YAxisLocation", "right")
end

return;
end

%% Helper
function applyNV_(obj, NV)
    % assign properties if possible
    params = fieldnames(NV);
    for pIndex = 1:numel(params)
        p = params{pIndex};
        if isprop(obj, p)
            v = NV.(p);
            set(obj, p, v);
        end
    end
end