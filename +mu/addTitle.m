function T = addTitle(varargin)
%ADDTITILE  Add a total title to the figure.
%
% SYNTAX:
%     mu.addTitle(str)
%     mu.addTitle(Fig, str)
%     mu.addTitle(..., 'HorizontalAlignment', 'center'/'left'/'right', ...
%                      'Position', [norm_x, norm_y], ...
%                      'FontSize', FontSize, ...
%                      'FontWeight', 'bold'/'normal', ...
%                      'Interpreter', 'none'/'latex'/'tex')
%     T = mu.addTitle(...)
%
% INPUTS:
%   REQUIRED:
%     str  - Title string
%   OPTIONAL:
%     Fig  - Target figure (default: gcf)
%   NAME-VALUE:
%     HorizontalAlignment  - 'center'/'left'/'right'
%     Position             - Normalized position [x,y] (default=[.5, 1.1] for center-top)
%     FontSize             - default=14
%     FontWeight           - 'bold'/'normal' (defaul='bold')
%     Interpreter          - 'none'/'latex'/'tex' (default='none')
%
% OUTPUTS:
%     T  - text object

if strcmp(class(varargin{1}), "matlab.ui.Figure")
    Fig = varargin{1};
    varargin = varargin(2:end);
else
    Fig = gcf;
end

mIp = inputParser;
mIp.addRequired("Fig", @(x) isa(x, "matlab.ui.Figure"));
mIp.addRequired("str", @(x) mu.isTextScalar(x) || iscellstr(x)); %#ok<ISCLSTR>
mIp.addParameter("HorizontalAlignment", 'center', @mu.isTextScalar);
mIp.addParameter("Position", [0.5, 1.1], @(x) validateattributes(x, {'numeric'}, {'numel', 2}));
mIp.addParameter("FontSize", 14, @(x) validateattributes(x, {'numeric'}, {'scalar', 'integer', 'positive'}));
mIp.addParameter("FontWeight", 'normal', @mu.isTextScalar);
mIp.addParameter("Interpreter", "none", @mu.isTextScalar);
mIp.parse(Fig, varargin{:});

str = mIp.Results.str; % title string
alignment = validatestring(mIp.Results.HorizontalAlignment, {'left', 'right', 'center'});
pos = mIp.Results.Position; % normalized [x, y]
fontSize = mIp.Results.FontSize;
fontWeight = validatestring(mIp.Results.FontWeight, {'normal', 'bold'});
interpreter = validatestring(mIp.Results.Interpreter, {'none', 'tex', 'latex'});

ax = mu.subplot(Fig, 1, 1, 1);
ax.XLim = [0, 1];
ax.YLim = [0, 1];
T = text(ax, pos(1), pos(2), str, ...
         "FontSize", fontSize, ...
         "FontWeight", fontWeight, ...
         "HorizontalAlignment", alignment, ...
         "Interpreter", interpreter);
uistack(ax, "bottom");
set(ax, "Visible", "off");
ax.Toolbar.Visible = "off";
set(ax, 'HitTest', 'off', 'PickableParts', 'none');
set(T,  'HitTest', 'off', 'PickableParts', 'none');

return;
end