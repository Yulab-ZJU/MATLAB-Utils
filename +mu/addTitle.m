function T = addTitle(varargin)
% Description: add a total title to the figure

if strcmp(class(varargin{1}), "matlab.ui.Figure")
    Fig = varargin{1};
    varargin = varargin(2:end);
else
    Fig = gcf;
end

mIp = inputParser;
mIp.addRequired("Fig", @(x) isa(x, "matlab.ui.Figure"));
mIp.addRequired("str", @(x) isStringScalar(x) || (ischar(x) && isStringScalar(string(x))));
mIp.addParameter("HorizontalAlignment", 'center', @(x) ischar(x) || isstring(x));
mIp.addParameter("Position", [0.5, 1.1], @(x) validateattributes(x, {'numeric'}, {'numel', 2}));
mIp.addParameter("FontSize", 14, @(x) validateattributes(x, {'numeric'}, {'scalar', 'integer', 'positive'}));
mIp.addParameter("FontWeight", 'normal', @(x) ischar(x) || isstring(x));
mIp.addParameter("Interpreter", "none", @(x) ischar(x) || isstring(x));
mIp.parse(Fig, varargin{:});

str = mIp.Results.str; % title string
alignment = validatestring(mIp.Results.HorizontalAlignment, {'left', 'right', 'center'});
pos = mIp.Results.Position; % normalized [x, y]
fontSize = mIp.Results.FontSize;
fontWeight = validatestring(mIp.Results.FontWeight, {'normal', 'bold'});
interpreter = validatestring(mIp.Results.Interpreter, {'none', 'tex', 'latex'});

ax = mu.subplot(Fig, 1, 1, 1);
T = text(ax, pos(1), pos(2), str, ...
         "FontSize", fontSize, ...
         "FontWeight", fontWeight, ...
         "HorizontalAlignment", alignment, ...
         "Interpreter", interpreter);
uistack(ax, "bottom");
set(ax, "Visible", "off");
ax.Toolbar.Visible = "off";

return;
end