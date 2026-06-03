%% demo_tiledlayout
% Demonstration of mu.tiledlayout.
%
% This demo covers:
%   1. Alignment control of tiledlayout.OuterPosition
%   2. H5/CSS-like margins and paddings for tiledlayout
%   3. Difference between mu-style paddings and MATLAB native Padding
%   4. Using mu.subplot with tiledlayout parent and spanning index
%   5. Nested tiledlayout with Tile and TileSpan
%
% Notes about annotation:
%   - Red box    : margin box
%   - Blue box   : drawable box after mu-style paddings
%   - Green box  : live tiledlayout.OuterPosition
%   - Gray box   : live tiledlayout.Position / InnerPosition
%   - Purple box : actual axes.Position converted from tiledlayout-inner
%                  coordinates to figure-normalized coordinates
%
% figure normalized coordinates
% └── live tiledlayout.OuterPosition, green
%     └── live tiledlayout.Position / InnerPosition, gray dotted
%         └── ax.Position, local to the gray inner box
%             └── converted axes.Position in figure coordinates, purple
%
% Important coordinate relation:
%   For axes inside tiledlayout, ax.Position is normalized to the live
%   tiledlayout.Position / InnerPosition box, not directly to the figure.
%
%   Therefore, before using annotation(fig, ...), convert:
%
%       axPosFig = tInnerFig + ax.Position .* tInnerFigSize

ccc;

oldDefaultAxesBox = get(0, "DefaultAxesBox");
cleanupObj = onCleanup(@() set(0, "DefaultAxesBox", oldDefaultAxesBox));

set(0, "DefaultAxesBox", "on");

%% Colors for annotation

C.margin   = [0.85, 0.20, 0.10];
C.padding  = [0.10, 0.35, 0.85];
C.layout   = [0.10, 0.60, 0.25];
C.tile     = [0.55, 0.25, 0.75];
C.grid     = [0.20, 0.20, 0.20];
C.native   = [0.95, 0.55, 0.10];
C.coord    = [0.15, 0.15, 0.15];

%% Demo 1: Alignment controls tiledlayout.OuterPosition

fig1 = figure( ...
    "Name", "mu.tiledlayout demo 1: alignment controls tiledlayout.OuterPosition", ...
    "WindowState", "maximized");

margins  = [0.08, 0.08, 0.10, 0.08];  % [left, right, bottom, top], relative to figure
paddings = [0.06, 0.06, 0.08, 0.06];  % [left, right, bottom, top], relative to margin box
nSize    = [0.52, 0.55];

[t1, opts1] = mu.tiledlayout(fig1, 2, 3, ...
    "margins", margins, ...
    "paddings", paddings, ...
    "nSize", nSize, ...
    "alignment", "left-bottom", ...
    "PositionType", "outerposition", ...
    "TileSpacing", "compact", ...
    "Padding", "compact");

local_fillTiles(t1, 6, "left-bottom");

drawnow;
pause(0.05);
drawnow;

local_annotateLayoutBox(fig1, t1, C, ...
    "alignment = ""left-bottom"": tiledlayout.OuterPosition is placed at the lower-left of the drawable box");

%% Demo 2: Same box model, different alignment

fig2 = figure( ...
    "Name", "mu.tiledlayout demo 2: compare alignments", ...
    "WindowState", "maximized");

alignmentList = ["left-bottom", "center", "right-top"];

for k = 1:numel(alignmentList)
    panelPos = local_threePanelPosition(k);

    p = uipanel(fig2, ...
        "Units", "normalized", ...
        "Position", panelPos, ...
        "BorderType", "line", ...
        "Title", "alignment = " + alignmentList(k), ...
        "FontWeight", "bold");

    [t, opts] = mu.tiledlayout(p, 2, 2, ...
        "margins", [0.08, 0.06, 0.14, 0.10], ...
        "paddings", [0.08, 0.08, 0.08, 0.08], ...
        "nSize", [0.58, 0.58], ...
        "alignment", alignmentList(k), ...
        "PositionType", "outerposition", ...
        "TileSpacing", "compact", ...
        "Padding", "compact");

    local_fillTiles(t, 4, alignmentList(k));

    drawnow;
    pause(0.02);
    drawnow;

    local_annotateLayoutBox(fig2, t, C, "");
end

annotation(fig2, "textbox", [0.12, 0.02, 0.76, 0.055], ...
    "String", "Same margins, paddings, and nSize. Only alignment changes the location of tiledlayout.OuterPosition inside the drawable box.", ...
    "Color", C.layout, ...
    "EdgeColor", C.layout, ...
    "BackgroundColor", "w", ...
    "FontWeight", "bold", ...
    "HorizontalAlignment", "center");

%% Demo 3: mu-style paddings vs MATLAB native Padding

fig3 = figure( ...
    "Name", "mu.tiledlayout demo 3: mu paddings vs native Padding", ...
    "WindowState", "maximized");

% Left: mu-style paddings create empty space outside tiledlayout.OuterPosition.
leftPanel = uipanel(fig3, ...
    "Units", "normalized", ...
    "Position", [0.05, 0.12, 0.42, 0.78], ...
    "Title", "mu-style paddings", ...
    "FontWeight", "bold", ...
    "BorderType", "line");

[t3a, opts3a] = mu.tiledlayout(leftPanel, 2, 2, ...
    "margins", [0.04, 0.04, 0.08, 0.08], ...
    "paddings", [0.18, 0.18, 0.18, 0.18], ...
    "nSize", [1, 1], ...
    "alignment", "center", ...
    "PositionType", "outerposition", ...
    "TileSpacing", "compact", ...
    "Padding", "compact");

local_fillTiles(t3a, 4, "mu paddings");

% Right: native Padding changes spacing inside tiledlayout.
rightPanel = uipanel(fig3, ...
    "Units", "normalized", ...
    "Position", [0.53, 0.12, 0.42, 0.78], ...
    "Title", "MATLAB native Padding", ...
    "FontWeight", "bold", ...
    "BorderType", "line");

[t3b, opts3b] = mu.tiledlayout(rightPanel, 2, 2, ...
    "margins", [0.04, 0.04, 0.08, 0.08], ...
    "paddings", [0, 0, 0, 0], ...
    "nSize", [1, 1], ...
    "alignment", "center", ...
    "PositionType", "outerposition", ...
    "TileSpacing", "compact", ...
    "Padding", "loose");

local_fillTiles(t3b, 4, "native Padding");

drawnow;
pause(0.05);
drawnow;

local_annotateLayoutBox(fig3, t3a, C, "");
local_annotateLayoutBox(fig3, t3b, C, "");

annotation(fig3, "textbox", [0.10, 0.02, 0.80, 0.055], ...
    "String", "mu-style paddings move/shrink tiledlayout.OuterPosition; native Padding controls internal spacing managed by MATLAB tiledlayout.", ...
    "Color", C.native, ...
    "EdgeColor", C.native, ...
    "BackgroundColor", "w", ...
    "FontWeight", "bold", ...
    "HorizontalAlignment", "center");

%% Demo 5: Nested tiledlayout with Tile and TileSpan

fig5 = figure( ...
    "Name", "mu.tiledlayout demo 5: nested tiledlayout", ...
    "WindowState", "maximized");

[outerT, outerOpts] = mu.tiledlayout(fig5, 3, 4, ...
    "margins", [0.06, 0.04, 0.08, 0.06], ...
    "paddings", [0.02, 0.02, 0.02, 0.02], ...
    "nSize", [0.90, 0.84], ...
    "alignment", "center", ...
    "PositionType", "outerposition", ...
    "TileSpacing", "compact", ...
    "Padding", "compact");

title(outerT, "Nested tiledlayout: inner layout uses Tile and TileSpan");

% A large normal axes in the outer layout
axOuter = nexttile(outerT, 1, [2, 2]);
plot(axOuter, cumsum(randn(100, 2)), "LineWidth", 1.1);
title(axOuter, "outer nexttile(1, [2,2])");

% Inner tiledlayout nested inside outer tiledlayout.
% Parent is a tiledlayout, so Position/alignment is ignored by MATLAB.
% Tile and TileSpan place the inner layout in the parent tile grid.
innerT = mu.tiledlayout(outerT, 2, 2, ...
    "Tile", 3, ...
    "TileSpan", [2, 2], ...
    "TileSpacing", "compact", ...
    "Padding", "compact");

title(innerT, "inner mu.tiledlayout(outerT, 2, 2, Tile=3, TileSpan=[2,2])");

local_fillTiles(innerT, 4, "inner");

drawnow;
pause(0.05);
drawnow;

local_annotateLayoutBox(fig5, outerT, C, "");

annotation(fig5, "textbox", [0.08, 0.02, 0.84, 0.06], ...
    "String", "Nested tiledlayout: parent is another tiledlayout, so use Tile and TileSpan. Position/alignment belongs to top-level parent containers.", ...
    "Color", C.tile, ...
    "EdgeColor", C.tile, ...
    "BackgroundColor", "w", ...
    "FontWeight", "bold", ...
    "HorizontalAlignment", "center");

%% Local helper functions

function local_fillTiles(t, nTile, label)
%LOCAL_FILLTILES Fill a tiledlayout with simple demo plots.

for k = 1:nTile
    ax = nexttile(t);
    plot(ax, rand(8, 1), "-o", "LineWidth", 1.0);
    title(ax, sprintf("%s | tile %d", string(label), k));
    grid(ax, "on");
end

end

function pos = local_threePanelPosition(k)
%LOCAL_THREEPANELPOSITION Return normalized position for three panels.

left = 0.04;
gap = 0.035;
width = (1 - 2 * left - 2 * gap) / 3;

pos = [ ...
    left + (k - 1) * (width + gap), ...
    0.12, ...
    width, ...
    0.78];

end

function local_annotateLayoutBox(fig, t, C, message)
%LOCAL_ANNOTATELAYOUTBOX Annotate margin box, drawable box, and live tiledlayout box.
%
% Do not use opts.layoutTargetPosition here. opts records the target box at
% creation time, but MATLAB tiledlayout can update OuterPosition/InnerPosition
% after axes, titles, tick labels, or axis image are added.
%
% Therefore, the green box is obtained from the live tiledlayout object:
%   t.OuterPosition
%
% The red and blue boxes are reconstructed from the stored mu.tiledlayout
% parameters in t.UserData.mu.tiledlayout.

drawnow;
pause(0.05);
drawnow;

if isempty(t) || ~isvalid(t)
    return;
end

% Retrieve stored mu-style layout parameters.
try
    opts = t.UserData.mu.tiledlayout;
catch
    warning("demo_tiledlayout:MissingUserData", ...
        "Cannot find t.UserData.mu.tiledlayout. Only live OuterPosition will be annotated.");

    layoutPos = local_getTiledLayoutOuterPositionInFigure(t, fig);
    annotation(fig, "rectangle", layoutPos, ...
        "Color", C.layout, ...
        "LineStyle", "-", ...
        "LineWidth", 1.8);

    local_addLabel(fig, layoutPos, "live tiledlayout.OuterPosition", C.layout, "southeast");
    return;
end

parentObj = t.Parent;
parentPos = local_parentPositionInFigure(parentObj, fig);

% Reconstruct red and blue boxes from mu-style margins/paddings.
% These are design boxes relative to the current parent.
marginBoxParent = [ ...
    opts.margins(1), ...
    opts.margins(3), ...
    1 - opts.margins(1) - opts.margins(2), ...
    1 - opts.margins(3) - opts.margins(4)];

drawableBoxParent = [ ...
    marginBoxParent(1) + opts.paddings(1) * marginBoxParent(3), ...
    marginBoxParent(2) + opts.paddings(3) * marginBoxParent(4), ...
    (1 - opts.paddings(1) - opts.paddings(2)) * marginBoxParent(3), ...
    (1 - opts.paddings(3) - opts.paddings(4)) * marginBoxParent(4)];

marginBox   = local_parent2fig(parentPos, marginBoxParent);
drawableBox = local_parent2fig(parentPos, drawableBoxParent);

% Live green box from the actual tiledlayout object after layout settles.
layoutPos = local_getTiledLayoutOuterPositionInFigure(t, fig);

annotation(fig, "rectangle", [0.005, 0.005, 0.99, 0.99], ...
    "Color", C.grid, ...
    "LineStyle", ":", ...
    "LineWidth", 1.0);

annotation(fig, "rectangle", marginBox, ...
    "Color", C.margin, ...
    "LineStyle", "--", ...
    "LineWidth", 1.4);

annotation(fig, "rectangle", drawableBox, ...
    "Color", C.padding, ...
    "LineStyle", ":", ...
    "LineWidth", 1.6);

annotation(fig, "rectangle", layoutPos, ...
    "Color", C.layout, ...
    "LineStyle", "-", ...
    "LineWidth", 1.8);

local_addLabel(fig, marginBox, "margin box", C.margin, "northwest");
local_addLabel(fig, drawableBox, "drawable box", C.padding, "northeast");
local_addLabel(fig, layoutPos, "live tiledlayout.OuterPosition", C.layout, "southeast");

if isa(parentObj, "matlab.ui.Figure")
    local_addBoxModelArrows(fig, marginBox, drawableBox, C);
end

if strlength(string(message)) > 0
    annotation(fig, "textbox", [0.10, 0.015, 0.80, 0.055], ...
        "String", message, ...
        "Color", C.layout, ...
        "EdgeColor", C.layout, ...
        "BackgroundColor", "w", ...
        "FontWeight", "bold", ...
        "HorizontalAlignment", "center");
end

end

function local_addBoxModelArrows(fig, marginBox, drawableBox, C)
%LOCAL_ADDBOXMODELARROWS Draw simple margin and padding arrows.

% Margin arrows
annotation(fig, "doublearrow", ...
    [0.01, marginBox(1)], ...
    [marginBox(2) + marginBox(4) + 0.025, marginBox(2) + marginBox(4) + 0.025], ...
    "Color", C.margin, ...
    "LineWidth", 1.2);

annotation(fig, "doublearrow", ...
    [marginBox(1) + marginBox(3), 0.99], ...
    [marginBox(2) + marginBox(4) + 0.025, marginBox(2) + marginBox(4) + 0.025], ...
    "Color", C.margin, ...
    "LineWidth", 1.2);

annotation(fig, "doublearrow", ...
    [0.035, 0.035], ...
    [0.01, marginBox(2)], ...
    "Color", C.margin, ...
    "LineWidth", 1.2);

annotation(fig, "doublearrow", ...
    [0.035, 0.035], ...
    [marginBox(2) + marginBox(4), 0.99], ...
    "Color", C.margin, ...
    "LineWidth", 1.2);

% Padding arrows
annotation(fig, "doublearrow", ...
    [marginBox(1), drawableBox(1)], ...
    [drawableBox(2) + drawableBox(4) / 2, drawableBox(2) + drawableBox(4) / 2], ...
    "Color", C.padding, ...
    "LineWidth", 1.2);

annotation(fig, "doublearrow", ...
    [drawableBox(1) + drawableBox(3), marginBox(1) + marginBox(3)], ...
    [drawableBox(2) + drawableBox(4) / 2, drawableBox(2) + drawableBox(4) / 2], ...
    "Color", C.padding, ...
    "LineWidth", 1.2);

annotation(fig, "doublearrow", ...
    [drawableBox(1) + drawableBox(3) + 0.018, drawableBox(1) + drawableBox(3) + 0.018], ...
    [marginBox(2), drawableBox(2)], ...
    "Color", C.padding, ...
    "LineWidth", 1.2);

annotation(fig, "doublearrow", ...
    [drawableBox(1) + drawableBox(3) + 0.018, drawableBox(1) + drawableBox(3) + 0.018], ...
    [drawableBox(2) + drawableBox(4), marginBox(2) + marginBox(4)], ...
    "Color", C.padding, ...
    "LineWidth", 1.2);

end

function parentPos = local_parentPositionInFigure(parentObj, fig)
%LOCAL_PARENTPOSITIONINFIGURE Parent normalized position in figure coordinates.

if isa(parentObj, "matlab.ui.Figure")
    parentPos = [0, 0, 1, 1];
else
    parentPos = local_normPosInFigure(parentObj, fig);
end

parentPos = local_clipNormPos(parentPos);

end

function out = local_parent2fig(parentPos, childPos)
%LOCAL_PARENT2FIG Convert child normalized position to figure coordinates.

if isempty(parentPos) || isempty(childPos)
    out = [];
    return;
end

out = [ ...
    parentPos(1) + childPos(1) * parentPos(3), ...
    parentPos(2) + childPos(2) * parentPos(4), ...
    childPos(3) * parentPos(3), ...
    childPos(4) * parentPos(4)];

out = local_clipNormPos(out);

end

function pos = local_normPosInFigure(obj, fig)
%LOCAL_NORMPOSINFIGURE Convert graphics object position to figure-normalized coordinates.
%
% This helper is used for ordinary containers, such as uipanel.

drawnow;

try
    oldFigUnits = fig.Units;
    fig.Units = "pixels";
    figPixelPos = fig.Position;
    fig.Units = oldFigUnits;

    objPixelPos = getpixelposition(obj, true);

    pos = [ ...
        objPixelPos(1) / figPixelPos(3), ...
        objPixelPos(2) / figPixelPos(4), ...
        objPixelPos(3) / figPixelPos(3), ...
        objPixelPos(4) / figPixelPos(4)];
catch
    oldUnits = obj.Units;
    obj.Units = "normalized";
    pos = obj.Position;
    obj.Units = oldUnits;
end

pos = local_clipNormPos(pos);

end

function local_addLabel(fig, pos, label, color, anchor)
%LOCAL_ADDLABEL Add annotation label around a rectangle.

pos = local_clipNormPos(pos);

switch lower(string(anchor))
    case "northwest"
        textPos = [pos(1), min(pos(2) + pos(4) + 0.006, 0.95), 0.32, 0.04];
        hAlign = "left";

    case "northeast"
        textPos = [max(pos(1) + pos(3) - 0.32, 0.01), min(pos(2) + pos(4) + 0.006, 0.95), 0.32, 0.04];
        hAlign = "right";

    case "southwest"
        textPos = [pos(1), max(pos(2) - 0.046, 0.01), 0.32, 0.04];
        hAlign = "left";

    case "southeast"
        textPos = [max(pos(1) + pos(3) - 0.32, 0.01), max(pos(2) - 0.046, 0.01), 0.32, 0.04];
        hAlign = "right";

    otherwise
        textPos = [pos(1), min(pos(2) + pos(4) + 0.006, 0.95), 0.32, 0.04];
        hAlign = "left";
end

annotation(fig, "textbox", textPos, ...
    "String", label, ...
    "Color", color, ...
    "EdgeColor", "none", ...
    "BackgroundColor", "w", ...
    "HorizontalAlignment", hAlign, ...
    "FontWeight", "bold");

end

function pos = local_clipNormPos(pos)
%LOCAL_CLIPNORMPOS Keep annotation position inside figure.

if isempty(pos)
    return;
end

pos = double(pos);

pos(1) = max(min(pos(1), 0.99), 0.01);
pos(2) = max(min(pos(2), 0.99), 0.01);
pos(3) = max(min(pos(3), 0.99 - pos(1)), 0.001);
pos(4) = max(min(pos(4), 0.99 - pos(2)), 0.001);

end

function pos = local_getTiledLayoutOuterPositionInFigure(t, fig)
%LOCAL_GETTILEDLAYOUTOUTERPOSITIONINFIGURE Get live t.OuterPosition in figure coordinates.
%
% t.OuterPosition is normalized to t.Parent. Convert it to figure-normalized
% coordinates for annotation.

drawnow;

parentPos = local_parentPositionInFigure(t.Parent, fig);

try
    oldUnits = t.Units;
    t.Units = "normalized";
    outerPosParent = t.OuterPosition;
    t.Units = oldUnits;
catch
    try
        outerPosParent = t.OuterPosition;
    catch
        outerPosParent = t.Position;
    end
end

pos = local_parent2fig(parentPos, outerPosParent);
pos = local_clipNormPos(pos);

end
