function varargout = colorbar(varargin)
%COLORBAR  Create colorbar outside tightPosition (IncludeLabels true).
%
% SYNTAX:
%   cb = colorbar(ax, 'Location', loc, 'Interval', interval, 'Width', width, 'Label', label, ...)
%   If ax omitted, defaults to gca.

mIp = inputParser;
mIp.KeepUnmatched = true;
mIp.addOptional('ax', gca, @(x) isa(x, 'matlab.graphics.axis.Axes'));
mIp.addParameter('Location', 'eastoutside', @mustBeTextScalar);
mIp.addParameter('Interval', 0.01, @(x) isnumeric(x) && isscalar(x));
mIp.addParameter('Width', [], @(x) isnumeric(x) && isscalar(x));
mIp.addParameter('Label', [], @mustBeTextScalar);
mIp.addParameter('ShowLimOnly', false, @(x) validateattributes(x, 'logical', {'scalar'}));
mIp.addParameter('Format', 'default', @mustBeTextScalar);
mIp.addParameter('ScaleFactor', 1, @(x) validateattributes(x, 'numeric', {'scalar', 'positive', 'integer'}));
mIp.parse(varargin{:});

ax = mIp.Results.ax;
loc = lower(string(mIp.Results.Location));
interval = mIp.Results.Interval;
label = char(mIp.Results.Label);
showLimOnly = mIp.Results.ShowLimOnly;
format = mIp.Results.Format;
scaleFactor = mIp.Results.ScaleFactor;

assert(fix(log10(scaleFactor)) == log10(scaleFactor), "Scale factor should be power of 10.");

pos0 = ax.tightPosition("IncludeLabels", true);
pos = ax.Position;

if isempty(mIp.Results.Width)
    tempCB = colorbar(ax, 'Location', loc);
    tempPos = tempCB.Position;
    switch loc
        case {'northoutside', 'southoutside'}
            width = min(tempPos(4), 0.02);
        case {'eastoutside', 'westoutside'}
            width = min(tempPos(3), 0.01);
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
cb.FontName = 'Arial';
cb.FontWeight = 'normal';
cb.Color = [0 0 0];

if strcmpi(loc, 'northoutside') || strcmpi(loc, 'southoutside')
    cb.TickLength = width / 5;
end

if showLimOnly
    cb.Ticks = cb.Limits;
end

if strcmpi(format, 'default')
    if scaleFactor ~= 1
        cb.TickLabels = compose('%g', cb.Ticks * scaleFactor);
        cb.TickLabelsMode = "auto";
    end
else
    try
        cb.TickLabels = compose(format, cb.Ticks * scaleFactor);
    catch e
        disp(e.message);
    end
end

if scaleFactor ~= 1
    if ~isempty(label)
        label = [label, ' (\timesE^{', num2str(-log10(scaleFactor)), '})'];
    else
        label = ['\timesE^{', num2str(-log10(scaleFactor)), '}'];
    end
end

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

if nargout > 0
    varargout{1} = cb;
end

return;
end
