function h = dashline(varargin)
%DASHLINE  Draw "dash-gap-dash" line by segmenting a polyline in data space.
%
% h = mu.dashline(x, y)
% h = mu.dashline(ax, x, y)
% h = mu.dashline(..., Name, Value, ...)
%
% This function creates a dashed appearance without using MATLAB's LineStyle='--'.
% It works by cutting the curve into many short solid segments ("dashes") separated
% by NaN breaks ("gaps"). Dash/gap are defined in *data-space arc length*.
%
% INPUT
%   ax : axes handle (optional, default gca)
%   x, y : numeric vectors with same length (NaNs allowed to break segments)
%
% NAME-VALUE
%   DashLength      : dash length in arc-length units (default 3)
%   GapLength       : gap length in arc-length units (default 2)
%   StartOffset     : start offset along arc-length (default 0)
%   KeepEndpoints   : true/false, keep very short leftover tail as dash (default true)
%   MinSegPoints    : minimum points per dash segment (default 2)
%
%   Plus any Line properties accepted by plot(), e.g.:
%     'Color','k','LineWidth',1.2,'Marker','none'
%
% OUTPUT
%   h : line handle (single line object with NaN breaks)
%
% EXAMPLE
%   t = linspace(0, 2*pi, 1000);
%   x = t; y = sin(t);
%   figure; ax = axes; hold(ax,'on');
%   mu.dashline(ax, x, y, 'DashLength',0.3, 'GapLength',0.2, 'LineWidth',1.5);
%
% NOTES
%   - DashLength and GapLength are in DATA units of arc length, not in points/pixels.
%   - If x,y are very non-uniform, segmentation still follows the actual curve length.

% -------------------------
% 0) Parse inputs
% -------------------------
[ax, x, y, opts, lineNV] = parseInputs_(varargin{:});

% Fast exit
if isempty(x) || isempty(y)
    h = plot(ax, nan, nan, lineNV{:});
    return;
end

% -------------------------
% 1) Build dashed polyline (NaN-separated)
% -------------------------
[xd, yd] = dashify_(x, y, opts);

% -------------------------
% 2) Plot once (efficient)
% -------------------------
h = plot(ax, xd, yd, lineNV{:});

end

%% ========================================================================
% Input parsing
% ========================================================================
function [ax, x, y, opts, lineNV] = parseInputs_(varargin)

% optional axes
if nargin >= 1 && isgraphics(varargin{1}, 'axes')
    ax = varargin{1};
    varargin = varargin(2:end);
else
    ax = gca;
end

% required x,y
if numel(varargin) < 2
    error('mu:dashline:NotEnoughInputs', 'Provide x and y.');
end
x = varargin{1};
y = varargin{2};
varargin = varargin(3:end);

% validate x,y
validateattributes(x, {'numeric'}, {'vector'});
validateattributes(y, {'numeric'}, {'vector'});
x = x(:);
y = y(:);
assert(numel(x) == numel(y), 'x and y must have the same number of elements.');

% split our NV from plot() NV
% Strategy: parse known options first, keep the rest for plot()
p = inputParser;
p.FunctionName = 'mu.dashline';

addParameter(p, 'DashLength',    3, @(v) validateattributes(v,{'numeric'},{'scalar','real','positive','finite'}));
addParameter(p, 'GapLength',     2, @(v) validateattributes(v,{'numeric'},{'scalar','real','nonnegative','finite'}));
addParameter(p, 'StartOffset',   0, @(v) validateattributes(v,{'numeric'},{'scalar','real','nonnegative','finite'}));
addParameter(p, 'KeepEndpoints', true, @(v) islogical(v) && isscalar(v));
addParameter(p, 'MinSegPoints',  2, @(v) validateattributes(v,{'numeric'},{'scalar','integer','>=',2}));

% We cannot directly know which NV belongs to plot(), so we parse with KeepUnmatched
p.KeepUnmatched = true;
parse(p, varargin{:});

opts = p.Results;

% Collect remaining NV for plot()
un = p.Unmatched;
fn = fieldnames(un);
lineNV = cell(1, 2*numel(fn));
for k = 1:numel(fn)
    lineNV{2*k-1} = fn{k};
    lineNV{2*k}   = un.(fn{k});
end

% Default line style (solid, no marker) if user didn't provide
% (we don't force, just provide gentle defaults)
if ~any(strcmpi(fn, 'LineStyle'))
    lineNV = [lineNV, {'LineStyle','-'}];
end
if ~any(strcmpi(fn, 'Marker'))
    lineNV = [lineNV, {'Marker','none'}];
end

end

%% ========================================================================
% Core: convert polyline to dashed polyline
% ========================================================================
function [xd, yd] = dashify_(x, y, opts)

dash = opts.DashLength;
gap  = opts.GapLength;
period = dash + gap;
off = opts.StartOffset;

% Handle NaNs as breaks
isBreak = isnan(x) | isnan(y);

% indices of continuous blocks
idx = find(~isBreak);
if isempty(idx)
    xd = nan; yd = nan;
    return;
end

% find start/end of each block
d = diff(idx);
blockStart = [idx(1); idx(find(d>1)+1)];
blockEnd   = [idx(d>1); idx(end)];

% accumulate dashed coordinates with NaN separators
XD = cell(numel(blockStart),1);
YD = cell(numel(blockStart),1);

for b = 1:numel(blockStart)
    ii = blockStart(b):blockEnd(b);
    xb = x(ii);
    yb = y(ii);

    if numel(xb) < 2
        XD{b} = nan; YD{b} = nan;
        continue;
    end

    % arc length parameter s
    dx = diff(xb);
    dy = diff(yb);
    ds = hypot(dx, dy);
    s = [0; cumsum(ds)];
    L = s(end);

    if L <= 0
        XD{b} = nan; YD{b} = nan;
        continue;
    end

    % decide dash intervals along s: [k*period+off, k*period+off+dash]
    k0 = floor((0 - off)/period);
    k1 = ceil((L - off)/period);

    xout = [];
    yout = [];

    for k = k0:k1
        s1 = k*period + off;
        s2 = s1 + dash;

        % clip to [0, L]
        a = max(s1, 0);
        b2 = min(s2, L);

        if b2 <= a
            continue;
        end

        % Interpolate endpoints and include interior points
        [xa, ya] = interpAtS_(xb, yb, s, a);
        [xb2, yb2] = interpAtS_(xb, yb, s, b2);

        % collect points inside (a,b2)
        inside = (s > a) & (s < b2);
        xin = xb(inside);
        yin = yb(inside);

        % assemble one dash segment
        segx = [xa; xin; xb2];
        segy = [ya; yin; yb2];

        % enforce minimum points per segment (avoid tiny segments)
        if numel(segx) < opts.MinSegPoints
            if opts.KeepEndpoints
                % keep as 2-point segment
                segx = [xa; xb2];
                segy = [ya; yb2];
            else
                continue;
            end
        end

        % append with NaN separator
        xout = [xout; segx; nan]; %#ok<AGROW>
        yout = [yout; segy; nan]; %#ok<AGROW>
    end

    XD{b} = xout;
    YD{b} = yout;
end

xd = vertcat(XD{:});
yd = vertcat(YD{:});

% Ensure not empty
if isempty(xd)
    xd = nan; yd = nan;
end

end

function [xi, yi] = interpAtS_(x, y, s, si)
% Linear interpolation along arc-length parameter s.
% Find segment where s(j) <= si <= s(j+1), interpolate.
if si <= s(1)
    xi = x(1); yi = y(1); return;
end
if si >= s(end)
    xi = x(end); yi = y(end); return;
end

j = find(s <= si, 1, 'last');
if j == numel(s)
    xi = x(end); yi = y(end); return;
end

s0 = s(j); s1 = s(j+1);
t = (si - s0) / max(eps, (s1 - s0));

xi = x(j) + t*(x(j+1) - x(j));
yi = y(j) + t*(y(j+1) - y(j));
end
