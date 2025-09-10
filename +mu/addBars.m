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
    varargin = varargin(2:end);
else
    ax = gca;
end

mIp = inputParser;
mIp.addRequired("ax", @(x) all(isgraphics(x)));
mIp.addRequired("xval", @(x) isvector(x) & isreal(x));
mIp.addOptional("color", "k", @(x) true);
mIp.addOptional("alpha", 0.1, @(x) validateattributes(x, {'numeric'}, {'scalar', '<=', 1, ">=", 0}));
mIp.parse(ax, varargin{:});

xval = mIp.Results.xval(:);
color = validatecolor(mIp.Results.color);
FaceAlpha = mIp.Results.alpha;

if isempty(xval)
    varargout{1} = [];
    return;
end

children = get(ax, "Children");
xdata = [];
for index = 1:length(children)
    try
        temp = get(children(index), "XData");
        xdata = [xdata; temp(:)];
    end
end
xdata = unique(xdata);
if numel(xdata) > 1
    width = min(diff(xdata));
else
    width = range(get(ax, "XLim")) * 0.01; % fallback: 1% x-axis range
end

yRange = get(ax, "YLim");

hold(ax, "on");
h = gobjects(0);

for i = 1:numel(xval)
    xv = [xval(i) - width / 2, ...
          xval(i) + width / 2, ...
          xval(i) + width / 2, ...
          xval(i) - width / 2];
    yv = [yRange(1), yRange(1), yRange(2), yRange(2)];
    h(end + 1) = patch(ax, xv, yv, color, ...
                       "FaceAlpha", FaceAlpha, ...
                       "EdgeColor", "none");
end

mu.setLegendOff(h);

if nargout == 1
    varargout{1} = h;
elseif nargout > 1
    error("Unspecified output arg");
end

end
