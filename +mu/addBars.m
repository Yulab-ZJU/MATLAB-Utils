function varargout = addBars(varargin)
%ADDBARS  Add significant areas to axes (vertical patches) that auto-extend with YLim.
%
% SYNTAX:
%     h = mu.addBars(xval, [color], [alpha])
%     h = mu.addBars(ax, xval, ...)
%
% NOTES:
%   - Bars are patch objects with Tag="SigBars"
%   - A YLim listener is installed once per axes to auto-update bar height.

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

% -------- compute a reasonable bar width from existing visible XData
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

% -------- install YLim listener (once per axes)
installSigBarsYLimListener(ax);

% -------- draw patches
yRange = get(ax, "YLim");
hold(ax, "on");
h = gobjects(0);

idx = [0; find(diff(xval) > 1); numel(xval)];
for i = 1:numel(idx) - 1
    xLeft  = xval(idx(i) + 1) - width / 2;
    xRight = xval(idx(i + 1)) + width / 2;

    xv = [xLeft, xRight, xRight, xLeft];
    yv = [yRange(1), yRange(1), yRange(2), yRange(2)];

    hp = patch(ax, xv, yv, color, ...
        "FaceAlpha", FaceAlpha, ...
        "EdgeColor", "none", ...
        "Tag", "SigBars");

    hp.UserData = struct("xLeft", xLeft, "xRight", xRight);

    h(end + 1) = hp; %#ok<AGROW>
end

% update once (in case YLim changed during plotting)
updateSigBarsYData(ax);

mu.setLegendOff(h);
uistack(h, "bottom");

if nargout == 1
    varargout{1} = h;
elseif nargout > 1
    error("Unspecified output arg");
end

end

% ========================= helpers =========================

function installSigBarsYLimListener(ax)
% Install a single listener per axes; reuse if already installed & valid.
key = "SigBars_YLimListener";

if isappdata(ax, key)
    L = getappdata(ax, key);
    if ~isempty(L) && isvalid(L)
        return;
    end
end

L = addlistener(ax, "YLim", "PostSet", @(~,~) updateSigBarsYData(ax));
setappdata(ax, key, L);
end

function updateSigBarsYData(ax)
% Update all SigBars patches to match current YLim.
if ~isgraphics(ax, "axes"); return; end

y = ax.YLim;

hb = findobj(ax, "Type", "patch", "Tag", "SigBars");
if isempty(hb); return; end

for k = 1:numel(hb)
    if ~isgraphics(hb(k)); continue; end

    ud = hb(k).UserData;
    if isstruct(ud) && isfield(ud, "xLeft") && isfield(ud, "xRight")
        xv = [ud.xLeft, ud.xRight, ud.xRight, ud.xLeft];
    else
        xv = hb(k).XData;
    end

    hb(k).XData = xv;
    hb(k).YData = [y(1), y(1), y(2), y(2)];
end
end