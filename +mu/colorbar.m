function cb = colorbar(varargin)
% COLORBAR Create colorbar outside tightPosition (IncludeLabels true).
% SYNTAX:
%   cb = colorbar(ax, 'Location', loc, 'Interval', interval, 'Width', width, 'Label', label, ...)
%   If ax omitted, defaults to gca.

mIp = inputParser;
mIp.KeepUnmatched = true;
mIp.addOptional('ax', gca, @(x) isa(x, 'matlab.graphics.axis.Axes'));
mIp.addParameter('Location', 'eastoutside', @(x) ischar(x) || isStringScalar(x));
mIp.addParameter('Interval', 0.01, @(x) isnumeric(x) && isscalar(x));
mIp.addParameter('Width', [], @(x) isnumeric(x) && isscalar(x));
mIp.addParameter('Label', [], @(x) isempty(x) || ischar(x) || isStringScalar(x));
mIp.parse(varargin{:});

ax = mIp.Results.ax;
loc = lower(string(mIp.Results.Location));
interval = mIp.Results.Interval;
label = mIp.Results.Label;

pos0 = ax.tightPosition("IncludeLabels", true);
pos = ax.Position;

if isempty(mIp.Results.Width)
    tempCB = colorbar(ax, 'Location', loc);
    tempPos = tempCB.Position;
    switch loc
        case {'northoutside', 'southoutside'}
            width = tempPos(4);
        case {'eastoutside', 'westoutside'}
            width = tempPos(3);
        otherwise
            error('Unsupported Location option.');
    end
    delete(tempCB);
else
    width = mIp.Results.Width;
end

switch loc
    case 'northoutside'
        cbPos = [pos(1), pos0(2) + pos0(4) + interval * pos(4), pos(3), width];
    case 'southoutside'
        cbPos = [pos(1), pos0(2) - interval * pos(4), pos(3), width];
    case 'eastoutside'
        cbPos = [pos0(1) + pos0(3) + interval * pos(3), pos(2), width, pos(4)];
    case 'westoutside'
        cbPos = [pos0(1) - interval * pos(3), pos(2), width, pos(4)];
    otherwise
        error('Unsupported Location option.');
end

args = namedargs2cell(mIp.Unmatched);
cb = colorbar(ax, args{:});
cb.Location = loc;
cb.Position = cbPos;

if ~isempty(label)
    cb.Label.String = label;
    if strcmpi(loc, 'eastoutside')
        cb.Label.Rotation = -90;
        cb.Label.VerticalAlignment = "baseline";
    elseif strcmpi(loc, 'westoutside')
        cb.Label.Rotation = 90;
        cb.Label.VerticalAlignment = "baseline";
    end
end

if strcmpi(loc, 'northoutside') || strcmpi(loc, 'southoutside')
    cb.TickLength = width / 5;
end

return;
end
