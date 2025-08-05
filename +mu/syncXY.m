function syncXY(ax)
% link x-y range
narginchk(0, 1);

if nargin < 1
    ax = gca;
end

xRange = get(ax, "XLim");
yRange = get(ax, "YLim");
xyRange = [min([xRange, yRange]), max([xRange, yRange])];
set(ax, "XLim", xyRange);
set(ax, "YLim", xyRange);
return;
end