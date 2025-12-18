function hTabFig = groupFigures(varargin)
%GROUPFIGURES  Group multiple figures into tabs of one figure.
% NOTE:
%   - For MATLAB 2025a+
%   - BUG: figure handle left empty may lead to some bug.
%
% USAGE:
%   mu.groupFigures()                          % group all figures
%   mu.groupFigures([f1 f2 f3])                % group specified figures
%   mu.groupFigures(..., "TabLocation", "top") % specify tab location
%
% OUTPUT:
%   hTabFig - uitabgroup figure

%% Parse inputs
mIp = inputParser;
mIp.addOptional("Figs", [], @(x) isempty(x) || all(ishandle(x)));
mIp.addParameter("TabLocation", "top", @mustBeTextScalar);
mIp.addParameter("KeepOriginal", false, @(x) validateattributes(x, 'logical', {'scalar'}));
mIp.parse(varargin{:});
Figs = mIp.Results.Figs;
TabLocation = validatestring(mIp.Results.TabLocation, {'top', 'left', 'right', 'bottom'});

% If no figures provided, get all open figure windows
if isempty(Figs)
    Figs = findall(groot, "Type", "figure", "-not", "Tag", "Grouped Figure");
    Figs = flip(Figs);
end

if isempty(Figs)
    warning("No figures to group.");
    hTabFig = [];
    return;
end

%% Create new figure with uitabgroup
hTabFig = figure("NumberTitle", "off", "Tag", "Grouped Figure", "Name", "Grouped Figure");
tg = uitabgroup(hTabFig, "TabLocation", TabLocation);

%% Loop over figures and copy contents
for k = 1:numel(Figs)
    f = Figs(k);
    if ~ishandle(f) || ~strcmpi(get(f, "Type"), "figure")
        continue;
    end

    nm = get(f, "Name");
    if isempty(nm)
        nm = sprintf("Figure %d", f.Number);
    end

    t = uitab(tg, "Title", nm);

    % copy content to tab
    ch = allchild(f);
    if ~isempty(ch)
        copyobj(ch, t);
    end

    delete(f);
end

drawnow;
set(hTabFig, 'WindowState', get(0, "DefaultFigureWindowState"));
return;
end