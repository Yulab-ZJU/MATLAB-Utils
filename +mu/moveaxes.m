function moveaxes(sourceAx, targetAx)
%MOVEAXES  Move an axes to target axes' figure and position,
%and move its legend/colorbar with it. Target axes will be deleted.
%
% sourceAx: axes to move (handle preserved)
% targetAx: axes as placeholder (position + destination figure), will be deleted

arguments
    sourceAx (1,1) matlab.graphics.axis.Axes
    targetAx (1,1) matlab.graphics.axis.Axes
end

dstFig = ancestor(targetAx, "figure");
pos    = targetAx.Position;
units  = targetAx.Units;

% --- find decorations (before moving axes)
srcFig = ancestor(sourceAx, "figure");
leg = findLegendForAxes(srcFig, sourceAx);
cb  = findColorbarForAxes(srcFig, sourceAx);

% --- delete placeholder first (avoid layout/overlap surprises)
delete(targetAx);

% --- move axes
sourceAx.Units = units;
sourceAx.Parent = dstFig;
sourceAx.Position = pos;

% --- move legend (if any)
if ~isempty(leg) && isvalid(leg)
    try
        leg.Parent = dstFig;
    catch
    end
    % Ensure it still points to the moved axes (version-safe best effort)
    try
        leg.Axes = sourceAx;
    catch
        % some versions don't expose settable Axes; usually it still works once Parent updated
    end
end

% --- move colorbar (if any)
if ~isempty(cb) && isvalid(cb)
    try
        cb.Parent = dstFig;
    catch
    end
    % Rebind to moved axes if possible
    try
        cb.Axes = sourceAx;
    catch
        % fallback for older versions
        try
            set(cb, "Axes", sourceAx);
        catch
        end
    end
end

end

% ================= helpers =================

function leg = findLegendForAxes(fig, ax)
leg = [];
if isempty(fig) || ~isgraphics(fig, "figure"), return; end

% Most robust: find legend whose Axes includes this axes (or equals)
cands = findobj(fig, "Type", "legend");
for k = 1:numel(cands)
    L = cands(k);
    try
        A = L.Axes;
        if isequal(A, ax) || (isgraphics(A,"axes") && any(A == ax))
            leg = L; return;
        end
    catch
        % very old behavior: try heuristic via plot children
        try
            if any(ancestor(L.PlotChildren, "axes") == ax)
                leg = L; return;
            end
        catch
        end
    end
end
end

function cb = findColorbarForAxes(fig, ax)
cb = [];
if isempty(fig) || ~isgraphics(fig, "figure"), return; end

cands = findobj(fig, "Type", "colorbar");
for k = 1:numel(cands)
    C = cands(k);
    try
        if isequal(C.Axes, ax)
            cb = C; return;
        end
    catch
        % older versions: sometimes use AssociatedAxes
        try
            if isequal(C.AssociatedAxes, ax)
                cb = C; return;
            end
        catch
        end
    end
end
end
