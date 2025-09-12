function [xv, yv, lines] = genPolygon(ax)
%GENPOLYGON  Interactive polygon drawing on 2D axes.
%
% Left-click: add point
% 'Z' key: undo last point
% Enter or Return: close polygon
% ESC: cancel and exit
%
% INPUTS:
%   ax - axes handle (default gca)
%
% OUTPUTS:
%   xv, yv - polygon vertices coordinates (column vectors)
%   lines  - array of Line objects representing polygon edges
%
% EXAMPLES:
%   pointsX = 10 * rand(20, 1);
%   pointsY = 10 * rand(20, 1);
%   figure;
%   ax = mu.subplot(1, 1, 1, "shape", "square-min");
%   hPoints = plot(ax, pointsX, pointsY, 'bo', 'DisplayName', 'Points');
%   [xv, yv, lines] = mu.genPolygon(ax);
%   [in, on] = inpolygon(pointsX, pointsY, xv, yv);
%   plot(ax, pointsX(in), pointsY(in), 'ro', 'DisplayName', 'Inside Points');
%   legend('Location', 'best');
%   title('Polygon Drawing and Point Inclusion Test');

if nargin < 1 || isempty(ax)
    ax = gca;
end

fig = ancestor(ax, 'figure');
ax.XLimMode = 'manual';
ax.YLimMode = 'manual';
hold(ax, 'on');

fig.Pointer = 'crosshair';

xv = [];
yv = [];
lines = gobjects(0);

disp('Instructions: Left-click to add points, Right-click for menu, Z to undo, Enter to close, ESC to cancel.');

% Create context menu
cmenu = uicontextmenu(fig);
uimenu(cmenu, 'Text', 'Revoke Last Point', 'MenuSelectedFcn', @revokeCallback);
uimenu(cmenu, 'Text', 'Confirm and return', 'MenuSelectedFcn', @confirmCallback);
ax.UIContextMenu = cmenu;

set(fig, 'WindowButtonDownFcn', @mouseClick);
set(fig, 'WindowKeyPressFcn', @keyPress);

uiwait(fig);
fig.Pointer = 'arrow';

%% 
    function mouseClick(~, ~)
        mouseBtn = get(fig, 'SelectionType');
        cp = get(ax, 'CurrentPoint');
        x = cp(1, 1);
        y = cp(1, 2);

        switch mouseBtn
            case 'normal' % left click
                if ~isempty(xv)
                    ltemp = plot(ax, [xv(end), x], [yv(end), y], 'k.-', 'LineWidth', 1);
                else
                    ltemp = plot(ax, x, y, 'k.-', 'LineWidth', 1);
                end
                lines(end+1) = ltemp;
                mu.setLegendOff(ltemp);

                xv(end+1,1) = x;
                yv(end+1,1) = y;

            case 'alt' % right click
                set(cmenu, 'Position', get(fig, 'CurrentPoint'));
        end
    end

    function keyPress(~, event)
        switch event.Key
            case 'z'
                revokeLastPoint();
            case {'return', 'enter'} % ENTER
                confirmAndReturn();
            case 'escape' % ESC
                delete(lines);
                xv = [];
                yv = [];
                lines = gobjects(0);
                uiresume(fig);
        end
    end

    function revokeCallback(~, ~)
        revokeLastPoint();
    end

    function revokeLastPoint()
        if ~isempty(lines)
            delete(lines(end));
            lines(end) = [];
            xv(end) = [];
            yv(end) = [];
        end
    end

    function confirmCallback(~, ~)
        confirmAndReturn();
    end

    function confirmAndReturn()
        if numel(xv) >= 3
            ltemp = plot(ax, [xv(end), xv(1)], [yv(end), yv(1)], 'k.-', 'LineWidth', 1);
            lines(end+1) = ltemp;
            set(get(get(ltemp, 'Annotation'), 'LegendInformation'), 'IconDisplayStyle', 'off');
            uiresume(fig);
        else
            warning('At least 3 points required to close polygon.');
        end
    end

end
