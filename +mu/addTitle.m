function addTitle(varargin)
%ADDTITLE Add a global title to a figure or tiledlayout.
%
% SYNTAX:
%     mu.addTitle(str)
%     mu.addTitle(Fig, str)
%     mu.addTitle(TiledLayout, str)
%     mu.addTitle(..., "HorizontalAlignment", "center"/"left"/"right", ...
%                      "Position", [norm_x, norm_y], ...
%                      "FontSize", FontSize, ...
%                      "FontWeight", "bold"/"normal", ...
%                      "Interpreter", "none"/"latex"/"tex")
%
% INPUTS:
%   REQUIRED:
%     str  - Title string. Can be char, scalar string, or cellstr.
%
%   OPTIONAL:
%     Fig          - Target figure. If omitted, gcf is used.
%     TiledLayout  - Target tiledlayout object.
%
% NAME-VALUE:
%     HorizontalAlignment  - "center", "left", or "right".
%                            Default: "center".
%
%     Position             - Normalized position [x, y].
%                            For figure target, this is the text position
%                            inside the invisible overlay axes.
%                            Default: [0.5, 1.1].
%
%                            For tiledlayout target, the native tiledlayout
%                            title position is used by default. Position is
%                            applied only if the user explicitly provides it.
%
%     FontSize             - Font size. Default: 14.
%
%     FontWeight           - "normal" or "bold". Default: "normal".
%
%     Interpreter          - "none", "tex", or "latex". Default: "none".
%
% NOTES:
%   1. If the target is a figure, this function creates an invisible axes
%      and places a text object on it. This keeps compatibility with the
%      old mu.addTitle behavior.
%
%   2. If the target is a tiledlayout, this function calls MATLAB native
%      title(tiledLayoutObj, str). This is preferred because tiledlayout
%      can reserve and manage title space automatically.

%% Parse target

if nargin < 1
    error("mu.addTitle requires at least a title string input.");
end

if local_isFigure(varargin{1}) || local_isTiledLayout(varargin{1})
    Target = varargin{1};
    varargin = varargin(2:end);
else
    Target = gcf;
end

%% Input parser

mIp = inputParser;

mIp.addRequired("Target", @(x) local_isFigure(x) || local_isTiledLayout(x));
mIp.addRequired("str", @(x) mu.isTextScalar(x) || iscellstr(x)); %#ok<ISCLSTR>

mIp.addParameter("HorizontalAlignment", "center", @mu.isTextScalar);
mIp.addParameter("Position", [0.5, 1.1], @(x) validateattributes(x, {'numeric'}, {'numel', 2, 'real'}));
mIp.addParameter("FontSize", 14, @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
mIp.addParameter("FontWeight", "normal", @mu.isTextScalar);
mIp.addParameter("Interpreter", "none", @mu.isTextScalar);

mIp.parse(Target, varargin{:});

Target = mIp.Results.Target;
str = mIp.Results.str;

alignment = validatestring(mIp.Results.HorizontalAlignment, {'left', 'right', 'center'});
pos = double(mIp.Results.Position(:).');
fontSize = mIp.Results.FontSize;
fontWeight = validatestring(mIp.Results.FontWeight, {'normal', 'bold'});
interpreter = validatestring(mIp.Results.Interpreter, {'none', 'tex', 'latex'});

positionWasSpecified = ~any(strcmp(mIp.UsingDefaults, "Position"));

%% Get host figure and current axes

if local_isFigure(Target)
    Fig = Target;
else
    Fig = ancestor(Target, "figure");
end

ax0 = [];
try
    ax0 = get(Fig, "CurrentAxes");
catch
end

%% Add title

if local_isTiledLayout(Target)
    % Native tiledlayout title.
    % This lets MATLAB reserve title space automatically and avoids adding
    % an extra axes into the tiledlayout/figure hierarchy.
    T = title(Target, str);

    set(T, ...
        "FontSize", fontSize, ...
        "FontWeight", fontWeight, ...
        "HorizontalAlignment", alignment, ...
        "Interpreter", interpreter);

    % For tiledlayout, Position is normally managed by MATLAB. Apply custom
    % Position only if the user explicitly provides it.
    if positionWasSpecified
        try
            oldUnits = T.Units;
            T.Units = "normalized";

            tPos = T.Position;
            if numel(tPos) >= 3
                T.Position = [pos(1), pos(2), tPos(3)];
            else
                T.Position = [pos(1), pos(2), 0];
            end

            T.Units = oldUnits;
        catch
            warning("mu:addTitle:TiledLayoutPositionIgnored", ...
                "Could not apply Position to tiledlayout title. MATLAB may manage tiledlayout title position automatically.");
        end
    end

else
    % Figure-level title using an invisible overlay axes.
    % This preserves the original behavior of mu.addTitle.

    ax = mu.subplot(Fig, 1, 1, 1);

    ax.XLim = [0, 1];
    ax.YLim = [0, 1];

    T = text(ax, pos(1), pos(2), str, ...
        "FontSize", fontSize, ...
        "FontWeight", fontWeight, ...
        "HorizontalAlignment", alignment, ...
        "Interpreter", interpreter);

    uistack(ax, "bottom");

    set(ax, ...
        "Visible", "off", ...
        "HitTest", "off", ...
        "PickableParts", "none");

    if isprop(ax, "Toolbar") && ~isempty(ax.Toolbar)
        ax.Toolbar.Visible = "off";
    end

    set(T, ...
        "HitTest", "off", ...
        "PickableParts", "none");
end

%% Restore current axes

if ~isempty(ax0) && isvalid(ax0)
    try
        axes(ax0);
    catch
        try
            set(Fig, "CurrentAxes", ax0);
        catch
        end
    end
end

return;
end

%% Local functions

function tf = local_isFigure(x)
%LOCAL_ISFIGURE True for scalar MATLAB figure.

tf = isscalar(x) && isa(x, "matlab.ui.Figure");

return;
end

function tf = local_isTiledLayout(x)
%LOCAL_ISTILEDLAYOUT True for scalar tiledlayout object.

tf = isscalar(x) && isa(x, "matlab.graphics.layout.TiledChartLayout");

return;
end