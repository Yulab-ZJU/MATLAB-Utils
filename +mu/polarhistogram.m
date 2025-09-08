function varargout = polarhistogram(varargin)
% POLARHISTOGRAM  Grouped polar histogram (self-drawn polar axes)
%
% Usage:
%   H = polarHistogram(theta)
%   H = polarHistogram(theta, edges)
%   H = polarHistogram(..., 'Name', Value, ...)
%   [H, N, edges] = polarHistogram(...)
%
% Inputs:
%   theta - numeric vector (radian), matrix (each row = group),
%           or cell array of numeric vectors
%
% Name-Value:
%   'LineWidth'            (0.5)   bar edge linewidth
%   'FaceColor'            {}      cell per group or 'none'
%   'EdgeColor'            {}      cell per group or 'none'
%   'DisplayName'          {}      legend strings per group
%   'BinWidth'             []      rad; overrides BinMethod
%   'BinMethod'            'auto'  ('auto','scott','fd','integers','sturges','sqrt')
%   'FaceAlpha'            (0.7)   0~1
%   'Normalization'        'count' ('count','probability','pdf','countdensity')
%   'Center'               (0)     center shift (rad)
%   'GroupSpacing'         (0.1)   0~<1
%   'ShowAxes'             (false) show XY axes (for debug)
%   'RTicks'               []      radial ticks (values in plotted unit)
%   'RTickLabel'           {}      labels for RTicks
%   'ThetaTicks'           0:30:330 angular ticks (deg)
%   'ThetaTickLabel'       {}      labels for ThetaTicks
%   'RTickLabelPlacement'  'auto'  'auto' or numeric degrees for label angle
%
% Output:
%   H     - patch handles (#bins x #groups)
%   N     - raw counts (#bins x #groups)
%   edges - bin edges (rad)

%% -------- Parse inputs
p = inputParser;
p.addRequired("theta", @(x) isnumeric(x) || iscell(x));
p.addOptional("edges", [], @(x) isnumeric(x) && isvector(x));
p.addParameter("LineWidth", 0.5, @isscalar);
p.addParameter("FaceColor", [], @(x) iscell(x) || (isscalar(x) && ischar(x)));
p.addParameter("EdgeColor", [], @(x) iscell(x) || (isscalar(x) && ischar(x)));
p.addParameter("DisplayName", [], @(x) iscell(x));
p.addParameter("BinWidth", [], @(x) isempty(x) || (isscalar(x) && x>0));
p.addParameter("BinMethod", "auto", @(x) ischar(x) || isstring(x));
p.addParameter("FaceAlpha", 0.7, @(x) isscalar(x) && x>=0 && x<=1);
p.addParameter("Normalization", "count", @(x) ismember(char(x), {'count','probability','pdf','countdensity'}));
p.addParameter("Center", 0, @isscalar);
p.addParameter("GroupSpacing", 0.1, @(x) isscalar(x) && x>=0 && x<1);
p.addParameter("ShowAxes", false, @(x) islogical(x) && isscalar(x));
p.addParameter("RTicks", [], @(x) isnumeric(x) && isvector(x));
p.addParameter("RTickLabel", {}, @(x) iscell(x) || isstring(x));
p.addParameter("ThetaTicks", 0:30:330, @(x) isnumeric(x) && isvector(x));
p.addParameter("ThetaTickLabel", {}, @(x) iscell(x) || isstring(x));
p.addParameter("RTickLabelPlacement", "auto", @(x) (ischar(x) && strcmpi(x,'auto')) || (isscalar(x)&&isnumeric(x)));
p.parse(varargin{:});

theta        = p.Results.theta;
edges        = p.Results.edges;
LineWidth    = p.Results.LineWidth;
FaceColors   = p.Results.FaceColor;
EdgeColors   = p.Results.EdgeColor;
legendStrs   = p.Results.DisplayName;
BinWidth     = p.Results.BinWidth;
BinMethod    = char(p.Results.BinMethod);
FaceAlpha    = p.Results.FaceAlpha;
Normalization= char(p.Results.Normalization);
Center       = p.Results.Center;
groupSpacing = p.Results.GroupSpacing;
ShowAxes     = p.Results.ShowAxes;
RTicks       = p.Results.RTicks;
RTickLabel   = cellstr(string(p.Results.RTickLabel));
ThetaTicks   = p.Results.ThetaTicks(:).';
ThetaTickLabel = cellstr(string(p.Results.ThetaTickLabel));
RTickLabelPlacement = p.Results.RTickLabelPlacement;

%% -------- Normalize theta to cell
if isnumeric(theta)
    if isvector(theta), theta = {theta(:)'}; else, theta = mat2cell(theta, ones(size(theta,1),1)); end
else
    assert(all(cellfun(@(x) isnumeric(x)&&isvector(x), theta)), 'Each group must be numeric vector');
end
nGroup = numel(theta);

%% -------- Colors defaults
if isempty(FaceColors)
    cmap = lines(nGroup);
    FaceColors = arrayfun(@(i) cmap(i,:), 1:nGroup, 'UniformOutput', false);
elseif ischar(FaceColors) && strcmpi(FaceColors,'none')
    FaceColors = repmat({'none'}, nGroup, 1);
end
if isempty(EdgeColors) || (ischar(EdgeColors) && strcmpi(EdgeColors,'none'))
    EdgeColors = repmat({'none'}, nGroup, 1);
end

%% -------- Bin edges
thetaAll = mod(cell2mat(theta(:)), 2*pi);
if isempty(edges)
    if isempty(BinWidth)
        [~, edges] = histcounts(thetaAll, 'BinMethod', BinMethod);
    else
        [~, edges] = histcounts(thetaAll, 'BinWidth', BinWidth);
    end
end
edges = sort(mod(edges + Center, 2*pi));
binWidth = mean(diff(edges));
nBin = numel(edges)-1;

%% -------- Raw counts per group
N = zeros(nBin, nGroup);
for g=1:nGroup
    th = mod(theta{g}+Center, 2*pi);
    N(:,g) = histcounts(th, edges);
end

%% -------- Normalization for plotting radius
N_plot = zeros(size(N));
for g=1:nGroup
    switch Normalization
        case 'count'
            N_plot(:,g) = N(:,g);
        case 'probability'
            s = sum(N(:,g)); N_plot(:,g) = (s>0) .* (N(:,g)/max(s,eps)*100);
        case 'pdf'
            s = sum(N(:,g)); N_plot(:,g) = (s>0) .* (N(:,g)/(max(s,eps)*binWidth)*100);
        case 'countdensity'
            N_plot(:,g) = N(:,g)/binWidth*100;
    end
end

%% -------- Radius range (consider user RTicks)
maxData = max([N_plot(:); 0]);
if isempty(RTicks)
    maxRadius = maxData * 1.1;
else
    maxRadius = max(maxData, max(RTicks)) * 1.1;
end
if maxRadius==0, maxRadius = 1; end

%% -------- Prepare axes
cla; axis equal; hold on
ax = gca;
ax.XLim = [-maxRadius maxRadius];
ax.YLim = [-maxRadius maxRadius];
ax.XColor = 'none'; ax.YColor = 'none';
if ShowAxes, ax.XColor = [0 0 0]; ax.YColor = [0 0 0]; end

%% -------- Default RTicks / RTickLabel
if isempty(RTicks)
    nCircles = 4;
    RTicks = linspace(0, maxRadius/1.1, nCircles+1); % use before *1.1
    RTicks = RTicks(2:end);
end
if isempty(RTickLabel)
    if strcmp(Normalization,'count')
        RTickLabel = arrayfun(@(r) sprintf('%d', round(r)), RTicks, 'UniformOutput', false);
    else
        RTickLabel = arrayfun(@(r) sprintf('%.0f%%', r), RTicks, 'UniformOutput', false);
    end
end

%% -------- Default ThetaTickLabel
if isempty(ThetaTickLabel)
    ThetaTickLabel = arrayfun(@(ang) sprintf('%d°', ang), ThetaTicks, 'UniformOutput', false);
end

%% -------- Draw radial circles
for r = RTicks
    th = linspace(0, 2*pi, 256);
    [x,y] = pol2cart(th, r*ones(size(th)));
    plot(x,y,'Color',[0.75 0.75 0.75],'LineStyle','-');
end

%% -------- Draw angular lines + labels
for i = 1:numel(ThetaTicks)
    ang = ThetaTicks(i);
    [x,y] = pol2cart(deg2rad(ang), [0 maxRadius]);
    plot(x,y,'Color',[0.8 0.8 0.8]);
    text(cosd(ang)*(maxRadius*1.02), sind(ang)*(maxRadius*1.02), ...
        ThetaTickLabel{i}, 'HorizontalAlignment','center', 'VerticalAlignment','middle');
end

%% -------- Draw wedges (group-separated inside each bin)
effectiveBinWidth = binWidth*(1 - groupSpacing);
subWidth = effectiveBinWidth / max(nGroup,1);
H = gobjects(nBin,nGroup);

for g=1:nGroup
    for b=1:nBin
        v = N_plot(b,g);
        if v<=0, continue; end
        binStart = edges(b) + (g-1)*subWidth; % shift inside bin
        binEnd   = binStart + subWidth;
        thetaWedge = linspace(binStart, binEnd, 24);
        rInner = zeros(size(thetaWedge));
        rOuter = v*ones(size(thetaWedge));
        th = [thetaWedge, fliplr(thetaWedge)];
        rr = [rInner,      fliplr(rOuter)];
        [x,y] = pol2cart(th, rr);
        H(b,g) = patch(x,y, FaceColors{g}, ...
            'FaceAlpha', FaceAlpha, ...
            'EdgeColor', EdgeColors{g}, ...
            'LineWidth', LineWidth);
    end
end

%% -------- Legend
if ~isempty(legendStrs)
    lgdH = gobjects(1,nGroup);
    for g=1:nGroup
        lgdH(g) = patch(NaN,NaN,FaceColors{g}, 'FaceAlpha',FaceAlpha, ...
                        'EdgeColor',EdgeColors{g}, 'LineWidth',LineWidth, ...
                        'DisplayName',legendStrs{g});
    end
    legend(lgdH, legendStrs, 'Location','bestoutside', 'AutoUpdate','off');
end

%% -------- Decide RTickLabel angle (auto or fixed)
labelAngleDeg = 90; % default top
if ischar(RTickLabelPlacement) && strcmpi(RTickLabelPlacement,'auto')
    % accumulate angular "density" to find emptiest direction
    nAngleBins = 72;                 % 5° bins
    edgesAng   = linspace(0, 2*pi, nAngleBins+1);
    dens = zeros(1, nAngleBins);
    for g=1:nGroup
        for b=1:nBin
            v = N_plot(b,g);
            if v<=0, continue; end
            a0 = edges(b) + (g-1)*subWidth; % shifted start
            a1 = a0 + subWidth;             % shifted end
            % handle wrap-around
            if a1 < a0, a1 = a1 + 2*pi; end
            bins = findAngleBins(a0, a1, edgesAng);
            dens(bins) = dens(bins) + v;
        end
    end
    if all(dens==0)
        labelAngleDeg = 90;
    else
        [~, idxMin] = min(dens);
        labelAngleDeg = rad2deg( (edgesAng(idxMin)+edgesAng(idxMin+1))/2 );
        labelAngleDeg = mod(labelAngleDeg, 360);
    end
elseif isnumeric(RTickLabelPlacement) && isscalar(RTickLabelPlacement)
    labelAngleDeg = mod(double(RTickLabelPlacement), 360);
end

%% -------- Draw RTick labels at chosen angle
for i = 1:numel(RTicks)
    [x,y] = pol2cart(deg2rad(labelAngleDeg), RTicks(i));
    ha = 'center'; va = 'bottom';
    if labelAngleDeg>90 && labelAngleDeg<270, va = 'top'; end % below when on left side
    text(x, y, RTickLabel{i}, 'HorizontalAlignment',ha, 'VerticalAlignment',va);
end

% %% -------- Title
% switch Normalization
%     case 'count',        ttl = 'Polar Histogram - Count (Separated Groups)';
%     case 'probability',  ttl = 'Polar Histogram - Probability (%) - Separated Groups';
%     case 'pdf',          ttl = 'Polar Histogram - Probability Density (%) - Separated Groups';
%     case 'countdensity', ttl = 'Polar Histogram - Count Density (%) - Separated Groups';
% end
% title(ttl);

%% -------- Outputs
if nargout>0, varargout{1}=H; end
if nargout>1, varargout{2}=N; end
if nargout>2, varargout{3}=edges; end
end

% ---------- helpers ----------
function bins = findAngleBins(a0, a1, edgesAng)
% Return indices in edgesAng that overlap [a0,a1] (a1 may exceed 2π)
T = 2*pi;
bins = [];
while a0 < a1
    a0n = mod(a0, T); a1n = min(a1, floor(a0/T)*T + T);
    idx = find(edgesAng(1:end-1) <= a1n & edgesAng(2:end) > a0n);
    bins = [bins, idx]; %#ok<AGROW>
    a0 = a1n;  % advance
end
bins = unique(bins);
end
