function h = copyobj(source, target, opts)
%COPYOBJ  Copy all children from one graphics container to another.
%
%   h = mu.copyobj(source, target)
%   h = mu.copyobj(source, target, Name, Value)
%
% This function copies the CONTENTS of the source container into the target
% container, while preserving the target container itself. Therefore,
% target-specific properties such as Position / OuterPosition / Layout are
% kept unchanged.
%
% INPUTS
%   source : graphics container handle
%            e.g., axes, panel, figure, uipanel, uitab, etc.
%   target : graphics container handle
%
% NAME-VALUE
%   "Replace"          : true/false (default: true)
%                        If true, delete all existing children in target
%                        before copying source children.
%
%   "CopyContainerProps" : true/false (default: false)
%                        If true, copy common container properties from
%                        source to target, excluding geometry/layout-related
%                        properties such as Position/OuterPosition/Units.
%
%   "ReverseOrder"     : true/false (default: true)
%                        MATLAB stores children in reverse visual stacking
%                        order. Keeping this true preserves the visual order
%                        of objects after copying.
%
% OUTPUT
%   h : handles of copied children in target
%
% NOTES
%   1. The target container itself is NOT replaced.
%   2. Geometry/layout properties of target are preserved.
%   3. This is safer than built-in copyobj(source, parent) when target is
%      managed by tiledlayout, subplot, app containers, etc.
%
% Example:
%   ax1 = axes; plot(ax1, rand(10,1));
%   ax2 = axes('Position', [0.6 0.1 0.3 0.3]);
%   mu.copyobj(ax1, ax2);
%
%   % ax2 keeps its own Position, but gets the contents of ax1.

% -------------------- parse inputs --------------------
arguments
    source                  (1,1)
    target                  (1,1)
    opts.Replace            (1,1) logical = true
    opts.CopyContainerProps (1,1) logical = false
    opts.ReverseOrder       (1,1) logical = true
end

assert(isgraphics(source) && isgraphics(target));

replaceFlag   = opts.Replace;
copyPropsFlag = opts.CopyContainerProps;
reverseFlag   = opts.ReverseOrder;

% -------------------- validate compatibility --------------------
if source == target
    error("mu.copyobj:SameHandle", "source and target must be different handles.");
end

sourceChildren = allchild(source);

if reverseFlag
    sourceChildren = flipud(sourceChildren);
end

% -------------------- clear target contents if requested --------------------
if replaceFlag
    delete(allchild(target));
end

% -------------------- copy children --------------------
if isempty(sourceChildren)
    h = gobjects(0);
else
    h = copyobj(sourceChildren, target);
end

% -------------------- copy selected container properties --------------------
if copyPropsFlag
    localCopyContainerProperties(source, target);
end

end

function localCopyContainerProperties(source, target)
% Copy a conservative set of container properties while preserving
% geometry/layout-related properties of target.

% Do not touch these target-defining properties
skipProps = string({ ...
    'Position', 'OuterPosition', 'InnerPosition', 'Units', ...
    'Layout', 'Parent', 'Children', 'Type', ...
    'BeingDeleted', 'BusyAction', 'Interruptible', ...
    'ButtonDownFcn', 'CreateFcn', 'DeleteFcn', ...
    'UIContextMenu', 'Tag', 'UserData'});

% A small safe property set for common containers.
candProps = string({ ...
    'Color', ...
    'Visible', ...
    'Clipping', ...
    'FontName', 'FontSize', 'FontWeight', 'FontAngle', ...
    'LineWidth', ...
    'XLim', 'YLim', 'ZLim', ...
    'XScale', 'YScale', 'ZScale', ...
    'XDir', 'YDir', 'ZDir', ...
    'CLim', 'ALim', ...
    'Box', ...
    'View', ...
    'CameraPosition', 'CameraTarget', 'CameraUpVector', 'CameraViewAngle', ...
    'Projection', ...
    'DataAspectRatio', 'PlotBoxAspectRatio', ...
    'XGrid', 'YGrid', 'ZGrid', ...
    'XMinorGrid', 'YMinorGrid', 'ZMinorGrid', ...
    'XColor', 'YColor', 'ZColor', ...
    'TickDir', 'TickLength', ...
    'NextPlot'});

for p = candProps
    if any(skipProps == p)
        continue;
    end

    try
        if isprop(source, p) && isprop(target, p)
            target.(p) = source.(p);
        end
    catch
        % ignore incompatible properties silently
    end
end

% Copy title/labels for axes-like containers
try
    if isa(source, 'matlab.graphics.axis.Axes') && isa(target, 'matlab.graphics.axis.Axes')
        localCopyTextObject(source.Title,  target.Title);
        localCopyTextObject(source.XLabel, target.XLabel);
        localCopyTextObject(source.YLabel, target.YLabel);
        localCopyTextObject(source.ZLabel, target.ZLabel);
    end
catch
    % ignore
end
end

function localCopyTextObject(src, dst)
textProps = { ...
    'String', 'Interpreter', ...
    'FontName', 'FontSize', 'FontWeight', 'FontAngle', ...
    'Color', 'Visible'};

for k = 1:numel(textProps)
    p = textProps{k};
    try
        if isprop(src, p) && isprop(dst, p)
            dst.(p) = src.(p);
        end
    catch
        % ignore
    end
end
end