function varargout = addWaveError(varargin)
%ADDWAVERROR  Add shaded area around a time series curve.
%
% SYNTAX:
%     mu.addWaveError(t, Y, E)
%     mu.addWaveError(ax, t, Y, E, "Color", rgb, "Alpha", alpha)
%     h = mu.addWaveError(...)
%
% INPUTS:
%   REQUIRED:
%     t   - x (time) value vector
%     Y   - y value vector
%     E   - error value vector
%   OPTIONAL:
%     ax     - target axes (default=gca)
%   NAMEVALUE:
%     Color  - Color variable (default='k')
%     Alpha  - Transparency. 0 for completely transparent, 1 for opaque (default=0.3)
%
% OUTPUTS:
%     h  - patch object

if isgraphics(varargin{1}, "axes")
    ax = varargin{1};
    t  = varargin{2};
    Y  = varargin{3};
    E  = varargin{4};
    varargin(1:4) = [];
else
    ax = gca;
    t  = varargin{1};
    Y  = varargin{2};
    E  = varargin{3};
    varargin(1:3) = [];
end

mIp = inputParser;
mIp.addRequired("ax", @(x) isgraphics(x, "axes"));
mIp.addRequired("t", @(x) validateattributes(x, 'numeric', {'vector', 'real'}));
mIp.addRequired("Y", @(x) validateattributes(x, 'numeric', {'vector', 'real'}));
mIp.addRequired("E", @(x) validateattributes(x, 'numeric', {'vector', 'real'}));
mIp.addParameter("Color", "k");
mIp.addParameter("Alpha", 0.3, @(x) validateattributes(x, 'numeric', {'scalar', 'positive', '<=', 1}));
mIp.parse(ax, t, Y, E, varargin{:});

t = mIp.Results.t(:)';
Y = mIp.Results.Y;
E = mIp.Results.E;
C = validatecolor(mIp.Results.Color);
AlphaVal = mIp.Results.Alpha;

y1 = Y(:)' + E(:)';
y2 = Y(:)' - E(:)';
hold(ax, "on");
h = fill([t, fliplr(t)], [y1, fliplr(y2)], C, "EdgeColor", "none", "FaceAlpha", AlphaVal);
mu.setLegendOff(h);

if nargout > 0
    varargout{1} = h;
end

return;
end