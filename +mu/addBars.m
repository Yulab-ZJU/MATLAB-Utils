function varargout = addBars(varargin)
%ADDBARS  Add significant areas to axes (vertical patches).
%
% SYNTAX:
%     h = mu.addBars(xval, [color], [alpha])
%     h = mu.addBars(ax, xval, ...)
%
% INPUTS:
%   REQUIRED:
%     xval   - X values, real vector
%   OPTIONAL:
%     ax     - Target axes (default=gca)
%     color  - Color of bars (default="k")
%     alpha  - Face alpha value of bars (default=0.1)
%
% OUTPUTS:
%     h      - patch object(s)

if isgraphics(varargin{1}, "axes")
    ax = varargin{1};
    xval = varargin{2};
    varargin = varargin(3:end);
else
    ax = gca;
    xval = varargin{1};
    varargin = varargin(2:end);
end

if isempty(xval)
    varargout{1} = [];
    return;
end

mIp = inputParser;
mIp.addRequired("ax", @(x) isscalar(x) && isgraphics(x, "axes"));
mIp.addRequired("xval", @(x) validateattributes(x, 'numeric', {'real', 'vector'}));
mIp.addOptional("color", "k", @(x) true);
mIp.addOptional("alpha", 0.1, @(x) validateattributes(x, {'numeric'}, {'scalar', '<=', 1, ">=", 0}));
mIp.parse(ax, xval, varargin{:});

xval = mIp.Results.xval(:);
color = validatecolor(mIp.Results.color);
FaceAlpha = mIp.Results.alpha;

children = get(ax, "Children");
temp = arrayfun(@(x) x.XData(:), children, "UniformOutput", false, "ErrorHandler", @errEmpty);
xdata = temp(~cellfun(@isempty, temp) & ...
             strcmp(get(children, "Visible"), "on") & ...
             ~strcmp(get(children, "Tag"), "SigBars"));
xdata = cat(1, xdata{:});
xdata = unique(xdata);
if numel(xdata) > 1
    width = min(diff(xdata));
else
    width = range(get(ax, "XLim")) * 0.01; % fallback: 1% x-axis range
end

yRange = get(ax, "YLim");

hold(ax, "on");
h = gobjects(0);
idx = [0; find(diff(xval) > 1); numel(xval)];
for i = 1:numel(idx) - 1
    xv = [xval(idx(i) + 1) - width / 2, ...
          xval(idx(i + 1)) + width / 2, ...
          xval(idx(i + 1)) + width / 2, ...
          xval(idx(i) + 1) - width / 2];
    yv = [yRange(1), yRange(1), yRange(2), yRange(2)];
    h(end + 1) = patch(ax, xv, yv, color, ...
                       "FaceAlpha", FaceAlpha, ...
                       "EdgeColor", "none", "Tag", "SigBars"); %#ok<AGROW>
end

mu.setLegendOff(h);
uistack(h, "bottom");

if nargout == 1
    varargout{1} = h;
elseif nargout > 1
    error("Unspecified output arg");
end

end
