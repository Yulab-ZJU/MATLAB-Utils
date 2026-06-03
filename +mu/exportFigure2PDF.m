function exportFigure2PDF(figHandle, filename, width_mm, height_mm, opts)
%EXPORTFIGURE2PDF
% Export PDF using exportgraphics.
%
% Two adjustment modes are supported:
%
%   adjustPositionType = "TightInset"  (default, legacy behavior)
%       AFTER removing surrounding blank margins, the union boundary of all
%       layout children expanded by TightInset has final size
%       [width_mm, height_mm] in mm. This keeps the exported PDF content box
%       fixed, but axes plot-box lengths can vary when tick labels/xlabel/
%       ylabel/title are different.
%
%   adjustPositionType = "Position"
%       The union boundary of all layout children Position boxes is scaled
%       to [width_mm, height_mm] in mm. Then the figure canvas is expanded
%       adaptively and children are shifted so that tick labels/xlabel/ylabel/
%       title remain visible. This keeps axes plot-box lengths consistent
%       across figures with different label/tick-label extents.
%
% NOTICE:
%   Images created with `imagesc` are compressed when exported to pdf in
%   R2025a and later versions. Please use `mu.image` for better performance.
%
% Boundary per-axes in TightInset mode:
%   p  = ax.Position;      % [x y w h]
%   ti = ax.TightInset;    % [l b r t] relative to position
%   L = p(1) - ti(1);
%   B = p(2) - ti(2);
%   R = p(1) + p(3) + ti(3);
%   T = p(2) + p(4) + ti(4);
%
% Boundary per-axes in Position mode:
%   L = p(1);
%   B = p(2);
%   R = p(1) + p(3);
%   T = p(2) + p(4);

% ---- Parameters ----
arguments
    figHandle       (1,1) matlab.ui.Figure
    filename        {mustBeTextScalar}
    width_mm        (1,1) double {mustBePositive}
    height_mm       (1,1) double {mustBePositive}
    opts.expandMode {mustBeTextScalar} = "fixed"
    opts.adjustOpt  = "on"
    opts.adjustPositionType {mustBeTextScalar} = "TightInset"
    opts.tol        (1,1) double {mustBeNonnegative} = 1e-3
end

expandMode = validatestring(opts.expandMode, ...
    {'fixed','keepratio-width','keepratio-height','keepratio-min','keepratio-max'});

adjustOpt = mu.OptionState.create(opts.adjustOpt).toLogical;

adjustPositionType = validatestring(opts.adjustPositionType, ...
    {'TightInset','Position','tightinset','position'});
adjustPositionType = lower(string(adjustPositionType));

tol = opts.tol;

% ---- Copy a new figure ----
tempFig = copyobj(figHandle, 0);
% set(tempFig, "Visible", "off");
drawnow;  % ensure TightInset is up-to-date

cleanupObj = onCleanup(@() local_closeIfValid(tempFig));

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

% ---- Treat [w h] as adjusted layout box size ----
% `expandMode` works only when `adjustOpt` is set to 'on'.
children = tempFig.Children;
if isempty(children)
    error('exportFigure2PDF:NoContent', 'No content found in the figure.');
end

idx = arrayfun(@(h) isprop(h, "Units") && isprop(h, "Position"), children);
children = children(idx);

if isempty(children)
    error('exportFigure2PDF:NoLayoutChildren', ...
        'No children with Units and Position properties found in the figure.');
end

set(children, "Units", "centimeters");

switch adjustPositionType
    case "tightinset"
        [bBox, WBox, HBox, posAll, ~] = getBorderBox(children, "centimeters");

    case "position"
        [bBox, WBox, HBox, posAll] = getPositionBox(children, "centimeters");

    otherwise
        error("Invalid adjustPositionType: %s.", adjustPositionType);
end

whRatioBox = WBox / HBox;
whRatioPDF = width_mm / height_mm;

% Normalize child Position to the selected reference bbox.
if numel(children) > 1
    posAll = cat(1, posAll{:});
end
posAll(:, 1) = (posAll(:, 1) - bBox(1)) / WBox; % x
posAll(:, 2) = (posAll(:, 2) - bBox(2)) / HBox; % y
posAll(:, 3) = posAll(:, 3) / WBox;             % w
posAll(:, 4) = posAll(:, 4) / HBox;             % h

% ---- Decide target box size ----
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

% Convert to centimeters.
W_cm = W_mm / 10;
H_cm = H_mm / 10;

% Initial figure paper position.
tempFig.PaperUnits = "centimeters";
tempFig.PaperPositionMode = "manual";
tempFig.PaperPosition = [0, 0, W_cm, H_cm];
tempFig.PaperSize = [W_cm, H_cm];

% Place children according to the normalized Position boxes.
for index = 1:numel(children)
    children(index).Position = [posAll(index, 1) * W_cm, ...
                                posAll(index, 2) * H_cm, ...
                                posAll(index, 3) * W_cm, ...
                                posAll(index, 4) * H_cm];
end

drawnow;

% ---- Adjustment according to selected position type ----
switch adjustPositionType
    case "tightinset"
        % Legacy auto-adjustment:
        % shrink/move axes until the TightInset-expanded border box fits
        % in the target paper size [W_cm, H_cm].
        for n = 1:100
            [~, WBoxNow, HBoxNow] = getBorderBox(children, "centimeters");
            if (WBoxNow - W_cm) / W_cm <= tol && ...
               (HBoxNow - H_cm) / H_cm <= tol
                break;
            end

            for cIndex1 = 1:numel(children)
                pos = children(cIndex1).Position;

                % Scaling
                scaleFactorX = W_cm / WBoxNow;
                scaleFactorY = H_cm / HBoxNow;
                pos(3) = mu.ifelse((WBoxNow - W_cm) / W_cm > tol, pos(3) * scaleFactorX, pos(3));
                pos(4) = mu.ifelse((HBoxNow - H_cm) / H_cm > tol, pos(4) * scaleFactorY, pos(4));

                % Adjust position so that scaling happens from the top-right corner.
                pos(1) = pos(1) * scaleFactorX;  % Shift left
                pos(2) = pos(2) * scaleFactorY;  % Shift down

                children(cIndex1).Position = pos;

                % Make labels visible.
                bBoxNow = getBorderBox(children, "centimeters");
                for cIndex2 = 1:numel(children)
                    pos = children(cIndex2).Position;
                    pos(1) = mu.ifelse(bBoxNow(1) < 0, pos(1) - bBoxNow(1), pos(1));
                    pos(2) = mu.ifelse(bBoxNow(2) < 0, pos(2) - bBoxNow(2), pos(2));
                    children(cIndex2).Position = pos;
                end
            end
        end

        [bBoxFinal, WBoxFinal, HBoxFinal] = getBorderBox(children, "centimeters");
        finalPaperW_cm = W_cm;
        finalPaperH_cm = H_cm;
        reservedMargins_cm = [0, 0, 0, 0];

    case "position"
        % Position-based adjustment:
        % keep the Position union at [W_cm, H_cm], then adaptively enlarge
        % the paper and shift all children to provide room for labels/ticks.
        %
        % This guarantees consistent axes plot-box length because child
        % Position widths/heights are not rescaled by TightInset.
        n = 1;

        [tightBox0, ~, ~] = getBorderBox(children, "centimeters");

        reservedMargins_cm = [ ...
            max(0, -tightBox0(1)), ...
            max(0, -tightBox0(2)), ...
            max(0,  tightBox0(3) - W_cm), ...
            max(0,  tightBox0(4) - H_cm)];

        finalPaperW_cm = W_cm + reservedMargins_cm(1) + reservedMargins_cm(3);
        finalPaperH_cm = H_cm + reservedMargins_cm(2) + reservedMargins_cm(4);

        % Expand paper first.
        tempFig.PaperPosition = [0, 0, finalPaperW_cm, finalPaperH_cm];
        tempFig.PaperSize = [finalPaperW_cm, finalPaperH_cm];

        % Shift all children right/up by the adaptive left/bottom reserve.
        for cIndex = 1:numel(children)
            pos = children(cIndex).Position;
            pos(1) = pos(1) + reservedMargins_cm(1);
            pos(2) = pos(2) + reservedMargins_cm(2);
            children(cIndex).Position = pos;
        end

        drawnow;

        [bBoxFinal, WBoxFinal, HBoxFinal] = getBorderBox(children, "centimeters");
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
    'BackgroundColor', 'none', ...
    'Colorspace', 'rgb', ...
    'Resolution', 600);

fprintf('============== PDF Exporting ==============\n');
fprintf('adjustPositionType: %s\n', adjustPositionType);
fprintf('PDF exporting: Iter=%d, tol=%.3g, w_diff=%.3g, h_diff=%.3g\n', ...
    n, tol, (WBoxFinal - finalPaperW_cm) / finalPaperW_cm, (HBoxFinal - finalPaperH_cm) / finalPaperH_cm);

if adjustPositionType == "position"
    fprintf('Position target size: %.3g x %.3g cm\n', W_cm, H_cm);
    fprintf('Adaptive reserved margins [L B R T]: [%.3g %.3g %.3g %.3g] cm\n', ...
        reservedMargins_cm(1), reservedMargins_cm(2), reservedMargins_cm(3), reservedMargins_cm(4));
    fprintf('Final paper size: %.3g x %.3g cm\n', finalPaperW_cm, finalPaperH_cm);
end

fprintf('PDF file exported to: %s\n', mu.getabspath(filename));
fprintf('================== Done ===================\n');

return;
end

%% Helper functions

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
idx = find(cellfun(@isempty, tiAll)); % colorbar or legend
for index = 1:numel(idx)
    child = children(idx(index));
    if strcmp(child.Type, "colorbar")
        tiAll{idx(index)} = getColorbarLabelInset(child);
    else % legend or other objects without TightInset
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

function [bBox, WBox, HBox, posAll] = getPositionBox(children, units)
narginchk(1, 2);
if nargin < 2
    units = "normalized";
end

oldUnits = get(children(1), "Units");
set(children, "Units", units);

% [x, y, w, h]
posAll = get(children, "Position");

if numel(children) > 1
    boxAll = cellfun(@(x) [x(1), ...
                           x(2), ...
                           x(1) + x(3), ...
                           x(2) + x(4)], ...
                     posAll, ...
                     "UniformOutput", false);
    boxAll = cat(1, boxAll{:});
else
    boxAll = [posAll(1), ...
              posAll(2), ...
              posAll(1) + posAll(3), ...
              posAll(2) + posAll(4)];
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

function local_closeIfValid(figHandle)
if ~isempty(figHandle) && isvalid(figHandle)
    close(figHandle);
end
end
