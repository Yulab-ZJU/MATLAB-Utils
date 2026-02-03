function setPlotMode(varargin)
%SETPLOTMODE  Set or restore default plotting properties.
%
% NOTES:
%   - Call before plotting to affect defaults via groot.
%   - Or pass figure/axes handles (scalar or array) to modify existing objects.
%   - Objects with tag "setPlotModeExclusion" will not be included.
%
% USAGE:
%   mu.setPlotMode('factory')
%   mu.setPlotMode('pdf')
%   mu.setPlotMode('your_setting.m')                      % file returns params cell
%   mu.setPlotMode(H, 'pdf', ...)
%   mu.setPlotMode(H, 'your_setting.m', ...)
%   mu.setPlotMode(H, TargetProperty, Value, ...)
%
% TargetProperty supports:
%   - Chain style: "AxesTitleFontSize" (Target1Target2...Property)
%   - Dot style:   "Axes.Title.FontSize" (Target.subTarget...Property)

% ------------------------------------------------------------
% 0) Optional graphics handle(s): allow multiple roots
% ------------------------------------------------------------
H = [];
if nargin >= 1 && all(isgraphics(varargin{1}))
    if ~mu.isTextScalar(varargin{1})
        H = varargin{1};
        varargin = varargin(2:end);
    end
end
if isempty(H)
    H = groot;
end

% Normalize roots array
if isequal(H, groot)
    roots = groot;
else
    roots = H(:);
end

% ------------------------------------------------------------
% 1) Optional plotMode (factory/pdf/manual or file path)
% ------------------------------------------------------------
plotMode = "manual";
if ~isempty(varargin) && mu.isTextScalar(varargin{1})
    s = string(varargin{1});
    if matches(s, ["factory","pdf","manual"], "IgnoreCase", true) || isfile(s)
        plotMode = s;
        varargin = varargin(2:end);
    end
end

validTargets = {'Line','Scatter','Patch','Axes','Text','Legend','Figure','Colorbar'};

% ------------------------------------------------------------
% 2) Presets / file mode
% ------------------------------------------------------------
if isfile(plotMode)
    temp = mu.path2func(plotMode);
    params = temp();
    assert(iscell(params) && mod(numel(params),2)==0, ...
        'Config file must return a cell array: {Name,Value,Name,Value,...}.');
    % Apply to each root
    for rr = 1:numel(roots)
        setTargetProperty(roots(rr), params(1:2:end), params(2:2:end), validTargets);
    end
else
    plotMode = validatestring(lower(plotMode), {'factory','pdf','manual'});
    switch plotMode
        case "factory"
            % reset each root (or groot)
            for rr = 1:numel(roots)
                try
                    reset(roots(rr));
                catch
                end
            end
        case "pdf"
            params = defaultPlotModePDF();
            for rr = 1:numel(roots)
                setTargetProperty(roots(rr), params(1:2:end), params(2:2:end), validTargets);
            end
        otherwise
            % manual
    end
end

% ------------------------------------------------------------
% 3) Name-value pairs
% ------------------------------------------------------------
if isempty(varargin)
    return;
end
assert(mod(numel(varargin),2) == 0, "Name-value inputs must come in pairs.");

names = varargin(1:2:end);
vals  = varargin(2:2:end);

for rr = 1:numel(roots)
    setTargetProperty(roots(rr), names, vals, validTargets);
end

end

% ============================================================
% Helpers
% ============================================================

function [path, prop, mode] = parseTargetPathProperty(paramName, validTargets, subTargetMap, proto, rootTypeHint)
%PARSETARGETPATHPROPERTY Parse:
%   - Absolute dotted:  "Axes.Title.FontSize"
%   - Relative dotted:  "Title.FontSize"   (relative to rootTypeHint, e.g. Axes)
%   - Chain:            "AxesTitleFontSize"
%   - Relative chain:   "TitleFontSize"    (relative to rootTypeHint)
%   - Property-only:    "LineWidth"

assert(ischar(paramName) || isstring(paramName), 'paramName must be char/string.');
paramName = char(paramName);
assert(~isempty(paramName), 'paramName must be non-empty.');

% allow user to pass "factoryDefaultXXX"
if startsWith(paramName, "factory", "IgnoreCase", true)
    paramName = paramName(8:end);
end

% helper: longest prefix match
    function [best, rest] = longestPrefixMatch(str, candidates)
        best = '';
        for ii = 1:numel(candidates)
            c = candidates{ii};
            if startsWith(str, c) && numel(c) > numel(best)
                best = c;
            end
        end
        if isempty(best), rest = str;
        else, rest = str(numel(best)+1:end);
        end
    end

% helper: validate a path against subTargetMap + prototype property existence
    function tf = isValidPath(pth, prp)
        if isempty(pth), tf = false; return; end
        % pth = {'Axes','Title',...}
        obj = proto.(pth{1});
        for kk = 2:numel(pth)
            step = pth{kk};
            if ~isprop(obj, step), tf = false; return; end
            obj = obj.(step);
        end
        tf = isprop(obj, prp);
    end

% ============================================================
% 1) Dot-style
% ============================================================
if contains(paramName, '.')
    toks = strsplit(paramName, '.');
    toks = toks(~cellfun(@isempty, toks));
    assert(numel(toks) >= 2, 'Invalid dotted name "%s".', paramName);

    prop = toks{end};
    head = toks(1:end-1);

    % Case 1: absolute dotted (head{1} is a valid target)
    if any(strcmp(head{1}, validTargets))
        path = head;
        mode = "explicit";
        % legality check (best effort)
        assert(isValidPath(path, prop), 'Invalid dotted path "%s".', paramName);
        return;
    end

    % Case 2: relative dotted (prepend rootTypeHint)
    if ~isempty(rootTypeHint) && any(strcmp(rootTypeHint, validTargets))
        path = [{rootTypeHint}, head];
        mode = "explicit";
        if isValidPath(path, prop)
            return;
        end
    end

    % Case 3: global inference (optional, only if unique)
    % Try every target as root and see which makes sense
    cand = {};
    for ii = 1:numel(validTargets)
        t0 = validTargets{ii};
        pth = [{t0}, head];
        if isValidPath(pth, prop)
            cand{end+1} = pth; %#ok<AGROW>
        end
    end
    if isscalar(cand)
        path = cand{1};
        mode = "explicit";
        return;
    elseif isempty(cand)
        error('Invalid dotted name "%s".', paramName);
    else
        % ambiguous
        s = cellfun(@(p) strjoin(p,'->'), cand, 'uni', 0);
        error('Ambiguous dotted name "%s". Candidates: %s', paramName, strjoin(s, ', '));
    end
end

% ============================================================
% 2) Chain-style (your original, with a relative fallback)
% ============================================================
assert(isstrprop(paramName(1),'upper'), 'Property name must start with an uppercase letter.');

% Try original: explicit target prefix
[path1, rest] = longestPrefixMatch(paramName, validTargets);

if ~isempty(path1)
    if isempty(rest)
        error('Invalid name "%s": missing property part.', paramName);
    end
    if ~isstrprop(rest(1),'upper')
        % not a true target prefix -> property-only
        path = {};
        prop = paramName;
        mode = "propertyOnly";
        return;
    end

    path = {path1};
    mode = "explicit";

    while true
        tLast = path{end};
        if ~isfield(subTargetMap, tLast), break; end
        subs = subTargetMap.(tLast);
        [sub, rest2] = longestPrefixMatch(rest, subs);
        if isempty(sub), break; end

        if isempty(rest2)
            error('Invalid name "%s": missing property after subtarget "%s".', paramName, sub);
        end
        if ~isstrprop(rest2(1),'upper')
            break;
        end
        path{end+1} = sub; %#ok<AGROW>
        rest = rest2;
    end

    prop = rest;
    return;
end

% If no explicit target prefix, try "relative chain": prepend rootTypeHint
if ~isempty(rootTypeHint) && any(strcmp(rootTypeHint, validTargets))
    param2 = [rootTypeHint, paramName];  % e.g. "Axes" + "TitleFontSize"
    [path1, rest] = longestPrefixMatch(param2, validTargets);
    if ~isempty(path1) && ~isempty(rest) && isstrprop(rest(1),'upper')
        path = {path1};
        mode = "explicit";

        while true
            tLast = path{end};
            if ~isfield(subTargetMap, tLast), break; end
            subs = subTargetMap.(tLast);
            [sub, rest2] = longestPrefixMatch(rest, subs);
            if isempty(sub), break; end
            if isempty(rest2), break; end
            if ~isstrprop(rest2(1),'upper'), break; end
            path{end+1} = sub; %#ok<AGROW>
            rest = rest2;
        end

        prop = rest;
        % verify by prototype if possible
        if isValidPath(path, prop)
            return;
        end
    end
end

% ============================================================
% 3) Property-only (apply to all targets that have it)
% ============================================================
path = {};
prop = paramName;
mode = "propertyOnly";
end

function setTargetProperty(rootH, names, vals, validTargets)
proto = getPrototypeHandles_(); % for isprop legality checks

% supported subtargets hierarchy
subTargetMap = struct();
subTargetMap.Axes     = {'Title','XLabel','YLabel','ZLabel','Subtitle','XAxis','YAxis'};
subTargetMap.Legend   = {'Title'};
subTargetMap.Colorbar = {'Label'};

for i = 1:numel(names)
    paramName = names{i};
    paramVal  = vals{i};

    assert(mu.isTextScalar(paramName), ...
        "Invalid param name at pair #%d: must be a text scalar.", i);

    paramName = char(paramName);

    rootTypeHint = "";
    if ~(isempty(rootH) || isequal(rootH, groot))
        % use handle's own type as hint for relative paths
        try rootTypeHint = lower(get(rootH, "Type")); catch, rootTypeHint = ""; end
        if rootTypeHint ~= ""
            rootTypeHint(1) = upper(rootTypeHint(1)); % "axes" -> "Axes"
        end
    end
    [paths, prop, mode] = parseTargetPathProperty(paramName, validTargets, subTargetMap, proto, rootTypeHint);


    % ------------------------------------------------------------
    % 1) Property-only: apply to all targets that have this property
    % ------------------------------------------------------------
    if mode == "propertyOnly"
        tar = {};
        for k = 1:numel(validTargets)
            t = validTargets{k};
            if isprop(proto.(t), prop)
                tar{end+1} = t; %#ok<AGROW>
            end
        end
        assert(~isempty(tar), ...
            'Invalid property "%s": none of the supported targets has this property.', prop);

        for k = 1:numel(tar)
            t = tar{k};
            tType = lower(t);

            if isequal(rootH, groot)
                defaultName = ['Default', t, prop];
                trySetDefault_(groot, defaultName, paramVal);
            else
                objs = findall(rootH, "Type", tType, "-not", "Tag", "setPlotModeExclusion");
                if ~isempty(objs)
                    try
                        set(objs, prop, paramVal);
                    catch ME
                        error('Failed to set %s.%s: %s', t, prop, ME.message);
                    end
                else
                    defaultName = ['Default', t, prop];
                    if ~trySetDefault_(rootH, defaultName, paramVal)
                        trySetDefault_(groot, defaultName, paramVal);
                    end
                end
            end
        end
        continue;
    end

    % ------------------------------------------------------------
    % 2) Explicit path: validate legality on prototype (best effort)
    % ------------------------------------------------------------
    if isscalar(paths)
        t0 = paths{1};
        assert(isprop(proto.(t0), prop), ...
            'Invalid property "%s" for target "%s".', prop, t0);
    else
        obj = proto.(paths{1});
        for kk = 2:numel(paths)
            step = paths{kk};
            assert(isprop(obj, step), 'Invalid subtarget "%s" under "%s".', step, paths{kk-1});
            obj = obj.(step);
        end
        assert(isprop(obj, prop), ...
            'Invalid property "%s" for target path "%s".', prop, strjoin(paths, '->'));
    end

    % ------------------------------------------------------------
    % 3) Apply explicit path
    %   Requirement:
    %   - If subtarget exists under current root: set only existing objects
    %   - If subtarget does NOT exist: try Default-setting on the root object
    % ------------------------------------------------------------
    rootType = lower(paths{1});

    if isequal(rootH, groot)
        % Only default attempt on groot (no existing objects concept)
        defaultName = ['Default', strjoin(paths,''), prop];
        trySetDefault_(groot, defaultName, paramVal);
        continue;
    end

    roots = findall(rootH, "Type", rootType, "-not", "Tag", "setPlotModeExclusion");

    if isempty(roots)
        % No such target objects under this root: try default on rootH then groot
        defaultName = ['Default', strjoin(paths,''), prop];
        if ~trySetDefault_(rootH, defaultName, paramVal)
            trySetDefault_(groot, defaultName, paramVal);
        end
        continue;
    end

    % Drill down for each root object of the target type
    for r = 1:numel(roots)
        baseObj = roots(r);

        obj = baseObj;
        missing = false;

        % traverse subtargets (if any)
        for kk = 2:numel(paths)
            step = paths{kk};
            try
                obj = obj.(step);
            catch
                obj = [];
            end
            if isempty(obj) || ~all(isgraphics(obj))
                missing = true;
                break;
            end
        end

        if ~missing
            % subtarget exists -> set ONLY existing
            try
                set(obj, prop, paramVal);
            catch ME
                error('Failed to set %s.%s: %s', strjoin(paths,'->'), prop, ME.message);
            end
        else
            % subtarget missing -> set Default on THIS root object (not on all)
            defaultName = ['Default', strjoin(paths,''), prop];
            % try set on base object, then fallback to the passed-in rootH, then groot
            if ~trySetDefault_(baseObj, defaultName, paramVal)
                if ~trySetDefault_(rootH, defaultName, paramVal)
                    trySetDefault_(groot, defaultName, paramVal);
                end
            end
        end
    end
end
end

function ok = trySetDefault_(hRoot, defaultName, value)
try
    set(hRoot, defaultName, value);
    ok = true;
catch
    ok = false;
end
end

function proto = getPrototypeHandles_()
% Create one invisible figure with representative objects for legality checks.
persistent P
if ~isempty(P) && isfield(P,'Figure') && isgraphics(P.Figure)
    proto = P;
    return;
end

oldFig = [];
oldAx  = [];
try oldFig = groot.CurrentFigure; end %#ok<TRYNC>
try oldAx  = groot.CurrentAxes;   end %#ok<TRYNC>
c = onCleanup(@()restoreCurrent_(oldFig, oldAx));

f  = figure('Visible','off', ...
            'HandleVisibility','off', ...
            'NumberTitle','off', ...
            'Name','mu.setPlotMode::proto');

ax = axes('Parent', f); hold(ax, 'on');

plot(ax, [0 1], [0 1]);
scatter(ax, 0, 0);
patch(ax, [0 1 1], [0 0 1], 'k');
text(ax, 0, 0, 'x');
legend(ax, {'demo'});
colorbar(ax);

P.Figure   = f;
P.Axes     = findall(f, 'Type', 'axes');     P.Axes     = P.Axes(1);
P.Line     = findall(f, 'Type', 'line');     P.Line     = P.Line(1);
P.Scatter  = findall(f, 'Type', 'scatter');  P.Scatter  = P.Scatter(1);
P.Patch    = findall(f, 'Type', 'patch');    P.Patch    = P.Patch(1);
P.Text     = findall(f, 'Type', 'text');     P.Text     = P.Text(1);
P.Legend   = findall(f, 'Type', 'legend');   P.Legend   = P.Legend(1);
P.Colorbar = findall(f, 'Type', 'colorbar'); P.Colorbar = P.Colorbar(1);

proto = P;
end

function restoreCurrent_(oldFig, oldAx)
H = groot;
try
    if isgraphics(oldFig, 'figure')
        H.CurrentFigure = oldFig;
    else
        H.CurrentFigure = [];
    end
catch
end
try
    if isgraphics(oldAx, 'axes')
        H.CurrentAxes = oldAx;
    else
        H.CurrentAxes = [];
    end
catch
end
end
