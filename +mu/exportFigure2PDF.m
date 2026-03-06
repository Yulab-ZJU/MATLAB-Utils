function exportFigure2PDF(figHandle, filename, width_mm, height_mm, opts)
%EXPORTFIGURE2PDF
% Export PDF using exportgraphics such that AFTER removing surrounding blank
% margins, the union boundary of all axes (Position expanded by TightInset)
% has final size [width_mm, height_mm] (or adjusted by expandMode) in mm.
%
% Boundary per-axes:
%   p  = ax.Position;      % [x y w h]
%   ti = ax.TightInset;    % [l b r t] relative to position
%   L = p(1) - ti(1);
%   B = p(2) - ti(2);
%   R = p(1) + p(3) + ti(3);
%   T = p(2) + p(4) + ti(4);

% ---- Parameters ----
arguments
    figHandle       (1,1) matlab.ui.Figure
    filename        {mustBeTextScalar}
    width_mm        (1,1) double {mustBePositive}
    height_mm       (1,1) double {mustBePositive}
    opts.expandMode {mustBeTextScalar} = "fixed"
    opts.adjustOpt  {mustBeTextScalar} = "on"
end

expandMode = validatestring(opts.expandMode, ...
    {'fixed','keepratio-width','keepratio-height','keepratio-min','keepratio-max'});

adjustOpt = mu.OptionState.create(opts.adjustOpt).toLogical;
tol = 5e-3;

% ---- Get border of axes ----
% Copy a new figure
tempFig = copyobj(figHandle, 0);
set(tempFig, "Visible", "off");
drawnow;  % ensure TightInset is up-to-date

% ---- Treat [w h] as the whole figure size ----
if ~adjustOpt
    set(tempFig, 'Units', 'centimeters');
    set(tempFig, 'Position', [0, 0, width_mm, height_mm]/10);
    set(tempFig, 'PaperUnits', 'centimeters');
    set(tempFig, 'PaperSize', [width_mm, height_mm]/10);
    set(tempFig, 'PaperPositionMode', 'manual');
    set(tempFig, 'PaperPosition', [0, 0, width_mm, height_mm]/10);

    exportgraphics(tempFig, filename, ...
                   'ContentType', 'vector', ...
                   'BackgroundColor', 'none');
    return;
end

% ---- Treat [w h] as axes box size ----
% `expandMode` works only when `adjustOpt` set 'on'
children = tempFig.Children;
if isempty(children)
    close(tempFig);
    error('exportFigure2PDF:NoContent', 'No content found in the figure.');
end
idx = arrayfun(@(h) isprop(h, "Units"), children);
children = children(idx);
set(children, "Units", "centimeters");

[bBox, WBox, HBox, posAll, ~] = getBorderBox(children, "centimeters");
whRatioBox = WBox / HBox;
whRatioPDF = width_mm / height_mm;

% normalize axes position to bbox
if numel(children) > 1
    posAll = cat(1, posAll{:});
end
posAll(:, 1) = (posAll(:, 1) - bBox(1)) / WBox; % x
posAll(:, 2) = (posAll(:, 2) - bBox(2)) / HBox; % y
posAll(:, 3) = posAll(:, 3) / WBox;             % w
posAll(:, 4) = posAll(:, 4) / HBox;             % h

% ---- Expand axes to fill figure ----
switch expandMode
    case 'fixed'
        W_mm = width_mm;
        H_mm = height_mm;
    case 'keepratio-width'
        W_mm = width_mm;
        H_mm = width_mm / whRatioBox;
    case 'keepratio-height'
        W_mm = height_mm * whRatioBox;
        H_mm = height_mm;
    case 'keepratio-min'
        if whRatioPDF > 1
            W_mm = height_mm * whRatioBox;
            H_mm = height_mm;
        else
            W_mm = width_mm;
            H_mm = width_mm / whRatioBox;
        end
    case 'keepratio-max'
        if whRatioPDF < 1
            W_mm = height_mm * whRatioBox;
            H_mm = height_mm;
        else
            W_mm = width_mm;
            H_mm = width_mm / whRatioBox;
        end
end

% Convert to centimeters
W_cm = W_mm / 10;
H_cm = H_mm / 10;

% Adjust figure paper position
tempFig.PaperUnits = "centimeters";
tempFig.PaperPositionMode = "manual";
tempFig.PaperPosition = [0, 0, W_cm, H_cm];
tempFig.PaperSize = [W_cm, H_cm];

for index = 1:numel(children)
    children(index).Position = [posAll(index, 1) * W_cm, ...
                           posAll(index, 2) * H_cm, ...
                           posAll(index, 3) * W_cm, ...
                           posAll(index, 4) * H_cm];
end

% Make labels visible
bBox = getBorderBox(children, "centimeters");
for index = 1:numel(children)
    pos = children(index).Position;
    pos(1) = mu.ifelse(bBox(1) < 0, pos(1) - bBox(1), pos(1));
    pos(2) = mu.ifelse(bBox(2) < 0, pos(2) - bBox(2), pos(2));
    children(index).Position = pos;
end

% Auto-adjustment
for n = 1:10
    [~, WBox, HBox] = getBorderBox(children, "centimeters");
    if (WBox - W_cm) / W_cm <= tol && ...
       (HBox - H_cm) / H_cm <= tol
        break;
    end
    for index = 1:numel(children)
        pos = children(index).Position;
        pos(3) = mu.ifelse((WBox - W_cm) / W_cm > tol, pos(3) / WBox * W_cm, pos(3));
        pos(4) = mu.ifelse((HBox - H_cm) / H_cm > tol, pos(4) / HBox * H_cm, pos(4));
        children(index).Position = pos;
    end
end

% ---- disable axes toolbars to avoid exporting them ----
for k = 1:numel(children)
    ax = children(k);
    if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
        ax.Toolbar.Visible = 'off';
    end
end

% ---- Export with exportgraphics ----
exportgraphics(tempFig, filename, ...
    'ContentType', 'vector', ...
    'BackgroundColor', 'none');

close(tempFig);
return;
end

%% Helper func
function [bBox, WBox, HBox, posAll, tiAll] = getBorderBox(children, units)
narginchk(1, 2);
if nargin < 2
    units = "normalized";
end
oldUnits = get(children(1), "Units");
set(children, "Units", units);

% [x, y, w, h]
posAll = get(children, "Position");

% [l, b, r, t]
tiAll = arrayfun(@(x) x.TightInset, children, "UniformOutput", false, "ErrorHandler", @errEmpty);
idx = find(cellfun(@isempty, tiAll)); % colorbar
for index = 1:numel(idx)
    child = children(idx(index));
    if strcmp(child.Type, "colorbar")
        tiAll{idx(index)} = getColorbarLabelInset(child);
    else % legend
        tiAll{idx(index)} = zeros(1, 4);
    end
end
if isscalar(tiAll)
    tiAll = tiAll{1};
end

if numel(children) > 1
    boxAll = cellfun(@(x, y) [x(1) - y(1), ...
                              x(2) - y(2), ...
                              x(1) + x(3) + y(3), ...
                              x(2) + x(4) + y(4)], ...
                     posAll, tiAll, ...
                     "UniformOutput", false);
    boxAll = cat(1, boxAll{:});
else
    boxAll = [posAll(1) - tiAll(1), ...
              posAll(2) - tiAll(2), ...
              posAll(1) + posAll(3) + tiAll(3), ...
              posAll(2) + posAll(4) + tiAll(4)];
end

% border of bBox
bBox = nan(1, 4);
bBox(1) = min(boxAll(:, 1));
bBox(2) = min(boxAll(:, 2));
bBox(3) = max(boxAll(:, 3));
bBox(4) = max(boxAll(:, 4));
WBox = bBox(3) - bBox(1);
HBox = bBox(4) - bBox(2);

set(children, "Units", oldUnits);
end

function inset = getColorbarLabelInset(cb)
cbPos = cb.Position;
labelExtent = cb.Label.Extent;

labelRect = [
    cbPos(1) + labelExtent(1) * cbPos(3), ... Left
    cbPos(2) + labelExtent(2) * cbPos(4), ... Bottom
    labelExtent(3) * cbPos(3),            ... Width
    labelExtent(4) * cbPos(4)             ... Height
];

labelRight = labelRect(1) + labelRect(3);
labelTop = labelRect(2) + labelRect(4);
cbRight = cbPos(1) + cbPos(3);
cbTop = cbPos(2) + cbPos(4);

left_inset = max(0, cbPos(1) - labelRect(1));
bottom_inset = max(0, cbPos(2) - labelRect(2));
right_inset = max(0, labelRight - cbRight);
top_inset = max(0, labelTop - cbTop);

inset = [left_inset, bottom_inset, right_inset, top_inset];
end