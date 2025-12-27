function setAxes(varargin)
%SETAXES  Set the values of axes parameters with name-value pairs.

narginchk(0, inf);

if nargin < 1 || mu.isTextScalar(varargin{1})
    target = gca;
else
    target = varargin{1};
    varargin(1) = [];
end

if strcmp(class(target), "matlab.ui.Figure") || strcmp(class(target), "matlab.graphics.Graphics")
    target = findobj(target(:), "Type", "axes");
else
    target = target(:);
end

if strcmpi(varargin{1}, "default")
    warning("This usage is obsolete and will be remove soon. Please use mu.setPlotMode('pdf') instead.");

    set(target, "TickDir", "out");
    set(target, "TickLength", [0.02, 0.01]);
    set(target, "FontName", "Arial");
    set(target, "FontSize", 8);
    set(target, "FontWeight", "normal");
    set(target, "Box", "off");
    set(target, "LineWidth", 0.3);
    set(target, "XColor", [0, 0, 0]);
    set(target, "YColor", [0, 0, 0]);
    set(target, "Layer", "top");
    varargin = varargin(2:end);
end

if mod(numel(varargin), 2) ~= 0
    error("The number of input arguments must be even.");
end

for index = 1:2:numel(varargin)
    set(target, varargin{index}, varargin{index + 1});
end

return;
end