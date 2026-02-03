function setPlotMode(varargin)
%SETPLOTMODE  Set or restore default plotting properties.
%
% NOTES:
%   - Call before plotting to affect defaults via groot.
%   - Or pass figure/axes handles (scalar or array) to modify existing objects.
%   - Objects with tag "setPlotModeExclusion" will not be included (nor their descendants).
%   - Use '*' to match any target (ONLY one '*' allowed in a target path).
%   - Use "-except", Prop, Value (repeatable) to exclude findall(root,Prop,Value) matches
%     (and their descendants) in non-default mode.
%
% USAGE:
%   mu.setPlotMode('factory')
%   mu.setPlotMode('pdf')
%   mu.setPlotMode('your_setting.m')                      % file returns params cell
%   mu.setPlotMode(H, 'pdf', ...)
%   mu.setPlotMode(H, 'your_setting.m', ...)
%   mu.setPlotMode(H, TargetProperty, Value, ...)
%   mu.setPlotMode(H, "-default", ...)
%   mu.setPlotMode(H, "-except","Tag","foo", ...)
%
% TargetProperty supports:
%   - Chain style: "AxesTitleFontSize" (Target1Target2...Property)
%   - Dot style:   "Axes.Title.FontSize" (Target.subTarget...Property)

% ------------------------------------------------------------
% 1) Parse inputs
% ------------------------------------------------------------
narginchk(1, inf);

% Target root
if all(isgraphics(varargin{1}))
    if ~mu.isTextScalar(varargin{1})
        roots = varargin{1};
        varargin = varargin(2:end);
    end
else
    roots = groot;
end
roots = roots(:);

% Plot mode
plotMode = "manual";
if ~isempty(varargin)
    assert(mu.isTextScalar(varargin{1}), "Invalid plot mode/name-value input");
    s = string(varargin{1});
    if matches(s, ["factory", "pdf", "manual"], "IgnoreCase", true) || isfile(s)
        plotMode = s;
        varargin = varargin(2:end);
    end
end

% Options: -default
idxDefault = cellfun(@(x) mu.isTextScalar(x) && strcmpi(x, "-default"), varargin);
if any(idxDefault)
    varargin = varargin(~idxDefault);
    setDefault = true;
else
    setDefault = false;
end

% Options: -except Prop Value   (repeatable)
exceptArgs = {}; % used as findall(rootH, exceptArgs{:})
k = 1;
while k <= numel(varargin)
    if mu.isTextScalar(varargin{k}) && strcmpi(varargin{k}, "-except")
        assert(k+2 <= numel(varargin), 'Option "-except" requires Prop and Value.');
        prop = varargin{k+1};
        val  = varargin{k+2};
        assert(mu.isTextScalar(prop), 'Option "-except" requires Prop to be char/string.');
        exceptArgs = [exceptArgs, {char(prop)}, {val}]; %#ok<AGROW>
        varargin([k k+1 k+2]) = [];
        continue
    end
    k = k + 1;
end

% ------------------------------------------------------------
% 2) Presets / file mode
% ------------------------------------------------------------
if isfile(plotMode)
    temp = mu.path2func(plotMode);
    params = mu.nvnorm(temp(), "OutType", "nv", "ValidateNV", true, "FieldCase", "keep");
    for rr = 1:numel(roots)
        setTargetProperty_(roots(rr), params, setDefault, exceptArgs);
    end
else
    plotMode = validatestring(lower(plotMode), {'factory', 'pdf', 'manual'});
    switch plotMode
        case "factory"
            for rr = 1:numel(roots)
                try reset(roots(rr)); end %#ok<TRYNC>
            end
        case "pdf"
            params = defaultPlotModePDF();
            for rr = 1:numel(roots)
                setTargetProperty_(roots(rr), params, setDefault, exceptArgs);
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

NVs = mu.nvnorm(varargin, ...
    "FieldCase", "keep", ...
    "OutType", "nv", ...
    "ValidateNV", true, ...
    "AllowDotted", true, ...
    "DuplicateNames", "lastwins");

for rr = 1:numel(roots)
    setTargetProperty_(roots(rr), NVs, setDefault, exceptArgs);
end

return;
end

% ============================================================
% Helpers
% ============================================================
function setTargetProperty_(rootH, NVs, setDefault, exceptArgs)
proto = getPrototypeHandles_(); % legality checks

names = NVs(1:2:end);
vals  = NVs(2:2:end);

for i = 1:numel(names)
    paramName = char(names{i});
    paramVal  = vals{i};

    [tars, prop, isDefault] = parseTargetPathProperty_(paramName, proto);

    % ------------------------------------------------------------
    % Default route: always set Default... on root when requested
    % ------------------------------------------------------------
    if setDefault || isDefault
        defName = buildDefaultName_(tars, prop);
        try
            set(rootH, defName, paramVal);
        catch
            try set(groot, defName, paramVal); end %#ok<TRYNC>
        end
        continue
    end

    % ------------------------------------------------------------
    % Non-default route: set existing objects only (exclude filtered)
    % ------------------------------------------------------------
    objs = resolveTargetsByChain_(rootH, tars, proto, exceptArgs);

    if isempty(objs)
        continue
    end

    try
        set(objs, prop, paramVal);
    catch
        for kk = 1:numel(objs)
            try set(objs(kk), prop, paramVal); end %#ok<TRYNC>
        end
    end
end

end

function [nameChainCell, prop, isDefault] = parseTargetPathProperty_(paramName, proto)
assert(mu.isTextScalar(paramName), 'paramName must be char/string.');
paramName = char(paramName);
assert(~isempty(paramName), 'paramName must be non-empty.');

% allow "DefaultXXX"
if startsWith(paramName, "default", "IgnoreCase", true)
    paramName = paramName(8:end);  % remove "Default"
    isDefault = true;
else
    isDefault = false;
end

if contains(paramName, '.')
    temp = split(paramName, '.');
    assert(numel(temp) >= 2, 'Invalid dotted paramName.');
    nameChainCell = cellstr(temp(1:end-1));
    prop = char(temp(end));
    validateTargetPathProperty_(nameChainCell, prop, proto);
else
    [nameChainCell, prop] = splitChainStyle_(paramName, proto);
    validateTargetPathProperty_(nameChainCell, prop, proto);
end
end

function validateTargetPathProperty_(nameChainCell, prop, proto)
% Validate legality of each level + hierarchy + property on last level.
% Supports '*' (only one).

if isstring(nameChainCell), nameChainCell = cellstr(nameChainCell); end
assert(iscell(nameChainCell) && ~isempty(nameChainCell), 'Empty target chain.');
assert(mu.isTextScalar(prop) && ~isempty(prop), 'Invalid property name.');

prop = char(prop);

% only one '*'
starPos = find(strcmp(nameChainCell, '*'));
assert(numel(starPos) <= 1, 'Only one ''*'' is allowed in the target path.');

protoTypes = fieldnames(proto);
protoTypes = protoTypes(:);

for k = 1:numel(nameChainCell)
    tk = nameChainCell{k};
    assert(mu.isTextScalar(tk), 'Target token must be char/string.');
    tk = char(tk);
    if strcmp(tk, '*'), continue; end
    assert(isstrprop(tk(1),'upper'), 'Token "%s" must be First-letter capitalized or "*".', tk);
end

    function tf = validateConcrete_(tokens)
        tf = true;

        hPrev = [];
        for ii = 1:numel(tokens)
            tk = tokens{ii};

            if ii == 1
                if isfield(proto, tk)
                    hPrev = proto.(tk);
                else
                    okAny = false;
                    for pp = 1:numel(protoTypes)
                        hP = proto.(protoTypes{pp});
                        if isChildPropHandle_(hP, tk)
                            hPrev = getChildPropHandle_(hP, tk);
                            okAny = true;
                            break
                        end
                    end
                    tf = okAny;
                end
                if ~tf || ~isgraphics(hPrev), tf = false; return; end
                continue
            end

            if isfield(proto, tk)
                hThis = proto.(tk);
            else
                if ~isChildPropHandle_(hPrev, tk), tf = false; return; end
                hThis = getChildPropHandle_(hPrev, tk);
            end

            if ~isgraphics(hThis) || ~isDescendant_(hThis, hPrev)
                tf = false; return
            end
            hPrev = hThis;
        end

        if ~isprop(hPrev, prop), tf = false; return; end
        if ~isSettable_(hPrev, prop), tf = false; return; end
    end

if isempty(starPos)
    assert(validateConcrete_(nameChainCell), 'Invalid target-path-property: %s.%s', strjoin(nameChainCell,'.'), prop);
    return
end

pos = starPos(1);
okAny = false;
for r = 1:numel(protoTypes)
    tokens = nameChainCell;
    tokens{pos} = protoTypes{r};
    if validateConcrete_(tokens)
        okAny = true;
        break
    end
end
assert(okAny, 'Wildcard "*" has no valid replacement for property "%s".', prop);

end

function proto = getPrototypeHandles_()
persistent P
if ~isempty(P) && isfield(P,'Figure') && isgraphics(P.Figure)
    proto = P; return;
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

plot(ax, [nan 1], [0 1]);
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
    if isgraphics(oldFig, 'figure'), H.CurrentFigure = oldFig; else, H.CurrentFigure = []; end
catch
end
try
    if isgraphics(oldAx, 'axes'), H.CurrentAxes = oldAx; else, H.CurrentAxes = []; end
catch
end
end

% ============================================================
% Target resolution on REAL root
% ============================================================
function objs = resolveTargetsByChain_(rootH, tars, proto, exceptArgs)
% Resolve chain tokens under rootH, returning objects corresponding to the LAST token.
% Non-default mode uses this: if empty -> do nothing.
%
% Exclusions: Tag=="setPlotModeExclusion" and -except matches (and all their descendants).

starPos = find(strcmp(tars, '*'));
if numel(starPos) > 1
    error('Only one ''*'' is allowed in the target path.');
end

if isempty(starPos)
    objs = resolveConcrete_(rootH, tars, exceptArgs);
    return
end

protoTypes = fieldnames(proto);
pos = starPos(1);
acc = gobjects(0);
for r = 1:numel(protoTypes)
    t2 = tars;
    t2{pos} = protoTypes{r};
    o = resolveConcrete_(rootH, t2, exceptArgs);
    if ~isempty(o)
        acc = [acc; o(:)]; %#ok<AGROW>
    end
end
objs = unique(acc);

end

function objs = resolveConcrete_(rootH, tars, exceptArgs)
% Resolve a chain with NO '*'.

% Build exclusion roots once
exclRoots = findall(rootH, 'Tag', 'setPlotModeExclusion');
if ~isempty(exceptArgs)
    try
        exclRoots = [exclRoots; findall(rootH, exceptArgs{:})];
    catch ME
        error('Invalid "-except" args for findall: %s', ME.message);
    end
end
exclRoots = unique(exclRoots);

cur = gobjects(0);
for ii = 1:numel(tars)
    tk = char(tars{ii});

    if ii == 1
        cur = resolveTokenFromRoot_(rootH, tk);
    else
        cur = resolveTokenFromParents_(cur, tk);
    end

    if ~isempty(cur)
        cur = cur(isgraphics(cur));
        cur = cur(~isExcludedByRoots_(cur, exclRoots));
    end

    if isempty(cur)
        objs = gobjects(0);
        return
    end
end

objs = cur;
end

function out = resolveTokenFromRoot_(rootH, tk)
out = gobjects(0);

% as type
if isgraphics(rootH) && isgraphics(rootH, lower(tk))
    out(end+1,1) = rootH;
end
try
    h = findall(rootH, 'Type', lower(tk));
    if ~isempty(h), out = [out; h(:)]; end
catch
end
if ~isempty(out)
    out = unique(out);
    return
end

% as child-prop
if isChildPropHandle_(rootH, tk)
    out = getChildPropHandle_(rootH, tk);
end
end

function out = resolveTokenFromParents_(parents, tk)
out = gobjects(0);

for i = 1:numel(parents)
    p = parents(i);
    if ~isgraphics(p), continue; end

    if isgraphics(p, lower(tk))
        out(end+1,1) = p; %#ok<AGROW>
    end
    try
        h = findall(p, 'Type', lower(tk));
        if ~isempty(h), out = [out; h(:)]; end %#ok<AGROW>
    catch
    end
end
if ~isempty(out)
    out = unique(out);
    return
end

tmp = gobjects(0);
for i = 1:numel(parents)
    p = parents(i);
    if isChildPropHandle_(p, tk)
        h = getChildPropHandle_(p, tk);
        if ~isempty(h), tmp = [tmp; h(:)]; end %#ok<AGROW>
    end
end
out = unique(tmp);
end

% ============================================================
% Chain-style tokenizer
% ============================================================
function [tars, prop] = splitChainStyle_(s, proto)
% Greedy tokenization with lookahead:
% stop when remaining tail is a valid property of the current object.

assert(mu.isTextScalar(s) && ~isempty(s), 'Invalid chain-style name.');
rest = char(s);

protoTypes = fieldnames(proto);
childProps = { ...
    'Title','Subtitle','XLabel','YLabel','ZLabel', ...
    'Legend','Colorbar' ...
};
allowed = [protoTypes(:); childProps(:)];
[~, idx] = sort(cellfun(@numel, allowed), 'descend');
allowed = allowed(idx);

tars = {};
hCur = []; % current prototype handle in parsing

while ~isempty(rest)
    % stop if rest is a valid property on current object
    if ~isempty(hCur) && isgraphics(hCur)
        if isprop(hCur, rest)
            prop = rest; return
        end
        p = properties(hCur);
        hit = find(strcmpi(p, rest), 1);
        if ~isempty(hit)
            prop = p{hit}; return
        end
    end

    matched = false;
    for k = 1:numel(allowed)
        tk = allowed{k};
        if strncmp(rest, tk, numel(tk))
            tars{end+1} = tk; %#ok<AGROW>
            rest = rest(numel(tk)+1:end);
            matched = true;

            % update hCur
            if isempty(hCur)
                if isfield(proto, tk)
                    hCur = proto.(tk);
                else
                    hCur = [];
                    protoNames = fieldnames(proto);
                    for pp = 1:numel(protoNames)
                        hp = proto.(protoNames{pp});
                        if isChildPropHandle_(hp, tk)
                            hCur = getChildPropHandle_(hp, tk);
                            if isgraphics(hCur), break; end
                        end
                    end
                end
            else
                if isfield(proto, tk)
                    hCur = proto.(tk);
                else
                    if isChildPropHandle_(hCur, tk)
                        hCur = getChildPropHandle_(hCur, tk);
                    else
                        hCur = [];
                    end
                end
            end
            break
        end
    end

    if ~matched
        break
    end
end

assert(~isempty(tars), 'Cannot parse chain-style name "%s".', s);
assert(~isempty(rest), 'Chain-style "%s" has no property tail.', s);

% final property (prefer exact then case-insensitive)
if ~isempty(hCur) && isgraphics(hCur)
    if isprop(hCur, rest), prop = rest; return; end
    p = properties(hCur);
    hit = find(strcmpi(p, rest), 1);
    if ~isempty(hit), prop = p{hit}; return; end
end
prop = rest;
end

% ============================================================
% Utilities
% ============================================================
function tf = isDescendant_(obj, ancestor)
tf = false;
if ~isgraphics(obj) || ~isgraphics(ancestor), return; end
h = obj;
while isgraphics(h)
    if h == ancestor, tf = true; return; end
    if ~isprop(h,'Parent'), break; end
    h = h.Parent;
end
end

function tf = isSettable_(h, propName)
tf = false;
try
    v = get(h, propName);
    set(h, propName, v);
    tf = true;
catch
end
end

function tf = isChildPropHandle_(h, propToken)
tf = false;
if ~isgraphics(h) || ~isprop(h, propToken), return; end
try
    c = h.(propToken);
    tf = isgraphics(c);
catch
end
end

function c = getChildPropHandle_(h, propToken)
try
    c = h.(propToken);
    if ~isgraphics(c), c = gobjects(0); end
catch
    c = gobjects(0);
end
end

function tf = isExcludedByRoots_(objs, exclRoots)
% True if obj is exclRoot itself OR a descendant of any exclRoot.
if isempty(exclRoots)
    tf = false(size(objs));
    return
end
tf = false(size(objs));
for i = 1:numel(objs)
    h = objs(i);
    while isgraphics(h)
        if any(h == exclRoots)
            tf(i) = true;
            break
        end
        if ~isprop(h,'Parent'), break; end
        h = h.Parent;
    end
end
end

function defName = buildDefaultName_(tars, prop)
defName = ['Default' strjoin(cellfun(@char, tars(:).', 'UniformOutput', false), '') char(prop)];
end
