function setPlotMode(varargin)
%SETPLOTMODE  Set or restore default plotting properties.
%
% NOTES:
%   - Call before plotting to affect defaults via groot.
%   - Or pass figure/axes handles (scalar or array) to modify existing objects.
%   - Objects with tag "setPlotModeExclusion" will not be included.
%   - Use '*' to match any target.
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
% 1) Parse inputs
% ------------------------------------------------------------
narginchk(1, inf);

% Target root
if all(isgraphics(varargin{1}))
    if ~mu.isTextScalar(varargin{1})
        roots = varargin{1};
        varargin = varargin(2:end);
    end
else % set groot as target if no target specified
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

% SetDefault option
idx = cellfun(@(x) mu.isTextScalar(x) && strcmpi(x, "-default"), varargin);
if any(idx)
    varargin = varargin(~idx);
    setDefault = true;
else
    setDefault = false;
end

% ------------------------------------------------------------
% 1) Presets / file mode
% ------------------------------------------------------------
if isfile(plotMode)
    temp = mu.path2func(plotMode);
    params = mu.nvnorm(temp(), "OutType", "nv", "ValidateNV", true, "FieldCase", "keep");
    % Apply to each root
    for rr = 1:numel(roots)
        setTargetProperty_(roots(rr), params, setDefault);
    end
else
    plotMode = validatestring(lower(plotMode), {'factory', 'pdf', 'manual'});
    switch plotMode
        case "factory"
            % reset each root (or groot)
            for rr = 1:numel(roots)
                try reset(roots(rr)); end %#ok<TRYNC>
            end
        case "pdf"
            params = defaultPlotModePDF();
            for rr = 1:numel(roots)
                setTargetProperty_(roots(rr), params, setDefault);
            end
        otherwise
            % manual
    end
end

% ------------------------------------------------------------
% 2) Name-value pairs
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
    setTargetProperty_(roots(rr), NVs, setDefault);
end

return;
end

% ============================================================
% Helpers
% ============================================================
function setTargetProperty_(rootH, NVs, setDefault)
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
            % as a fallback, also try groot (harmless if invalid)
            try set(groot, defName, paramVal); end %#ok<TRYNC>
        end
        continue
    end

    % ------------------------------------------------------------
    % Non-default route: set existing objects only
    % ------------------------------------------------------------
    objs = resolveTargetsByChain_(rootH, tars, proto);

    if isempty(objs)
        % no object found -> do nothing in non-default mode
        continue
    end

    % apply property
    try
        set(objs, prop, paramVal);
    catch
        % robust per-object set (avoid one bad object killing all)
        for k = 1:numel(objs)
            try set(objs(k), prop, paramVal); end %#ok<TRYNC>
        end
    end
end

end

function [nameChainCell, prop, isDefault] = parseTargetPathProperty_(paramName, proto)
%PARSETARGETPATHPROPERTY Parse:
%   - Dot style:  "Axes.Title.FontSize" / "Title.FontSize"
%   - Chain:      "AxesTitleFontSize" / "TitleFontSize"
%
% OUTPUT
%   nameChainCell : cellstr of tokens (targets/subtargets), may include '*'
%   prop          : property name on last object
%   isDefault     : true if user wrote "Default..."

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
    % ---------------------------
    % Dot-style
    % ---------------------------
    temp = split(paramName, '.');
    assert(numel(temp) >= 2, 'Invalid dotted paramName.');
    nameChainCell = cellstr(temp(1:end-1));
    prop = char(temp(end));

    validateTargetPathProperty_(nameChainCell, prop, proto);
else
    % ---------------------------
    % Chain-style (greedy tokenization)
    % ---------------------------
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

% proto types
protoTypes = fieldnames(proto);
protoTypes = protoTypes(:);

% validate each token (format only; existence checked later)
for k = 1:numel(nameChainCell)
    tk = nameChainCell{k};
    assert(mu.isTextScalar(tk), 'Target token must be char/string.');
    tk = char(tk);
    if strcmp(tk, '*')
        continue
    end
    assert(isstrprop(tk(1),'upper'), 'Token "%s" must be First-letter capitalized or "*".', tk);
end

% concrete chain validator (no '*')
    function tf = validateConcrete_(tokens)
        tf = true;

        % build prototype handles along the chain
        hPrev = [];
        for ii = 1:numel(tokens)
            tk = tokens{ii};

            if ii == 1
                % first token: just fetch its prototype handle if type,
                % or treat as child-prop of an assumed container? (no container in proto)
                if isfield(proto, tk)
                    hPrev = proto.(tk);
                else
                    % first token is child-prop token; validate that at least one proto type has this child
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

            % subsequent token: either type token or child-prop token; must be descendant of previous
            if isfield(proto, tk)
                hThis = proto.(tk);
            else
                if ~isChildPropHandle_(hPrev, tk)
                    tf = false; return
                end
                hThis = getChildPropHandle_(hPrev, tk);
            end

            if ~isgraphics(hThis) || ~isDescendant_(hThis, hPrev)
                tf = false; return
            end
            hPrev = hThis;
        end

        % property must exist & be settable on final prototype handle
        if ~isprop(hPrev, prop)
            tf = false; return
        end
        if ~isSettable_(hPrev, prop)
            tf = false; return
        end
    end

% if no '*': validate directly
if isempty(starPos)
    assert(validateConcrete_(nameChainCell), 'Invalid target-path-property: %s.%s', strjoin(nameChainCell,'.'), prop);
    return
end

% one '*': try all proto types as replacement (type wildcard)
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

% ============================================================
% Target resolution on REAL root
% ============================================================
function objs = resolveTargetsByChain_(rootH, tars, proto)
% Resolve chain tokens under rootH, returning objects corresponding to the LAST token.
% Non-default mode uses this: if empty -> do nothing.

% expand '*' (only one) at runtime to proto types
starPos = find(strcmp(tars, '*'));
if numel(starPos) > 1
    error('Only one ''*'' is allowed in the target path.');
end

if isempty(starPos)
    objs = resolveConcrete_(rootH, tars);
    return
end

% enumerate replacements for '*'
protoTypes = fieldnames(proto);
pos = starPos(1);
acc = gobjects(0);
for r = 1:numel(protoTypes)
    t2 = tars;
    t2{pos} = protoTypes{r};
    o = resolveConcrete_(rootH, t2);
    if ~isempty(o)
        acc = [acc; o(:)]; %#ok<AGROW>
    end
end
objs = unique(acc);

end

function objs = resolveConcrete_(rootH, tars)
% Resolve a chain with NO '*'.

cur = gobjects(0);
for ii = 1:numel(tars)
    tk = char(tars{ii});

    if ii == 1
        cur = resolveTokenFromRoot_(rootH, tk);
    else
        cur = resolveTokenFromParents_(cur, tk);
    end

    % exclude tagged objects
    if ~isempty(cur)
        cur = cur(isgraphics(cur));
        cur = cur(~hasExclusionTag_(cur));
    end

    if isempty(cur)
        objs = gobjects(0);
        return
    end
end

objs = cur;

end

function out = resolveTokenFromRoot_(rootH, tk)
% token at level 1: can be a type token (Axes/Line/...) or child prop (Title/Legend/...)

out = gobjects(0);

% try as type
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

% try as child-prop (Title/XLabel/Legend/Colorbar/...)
if isChildPropHandle_(rootH, tk)
    out = getChildPropHandle_(rootH, tk);
end

end

function out = resolveTokenFromParents_(parents, tk)
% token at level >=2: resolve from each parent

out = gobjects(0);

% type token path
% include parent itself if matches, plus descendants
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

% child-prop token path
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
% stop when the remaining tail is a valid property of the current object.

assert(mu.isTextScalar(s) && ~isempty(s), 'Invalid chain-style name.');
rest = char(s);

% Allowed tokens = proto fieldnames + common child-props + '*'
protoTypes = fieldnames(proto);
childProps = { ...
    'Title','Subtitle','XLabel','YLabel','ZLabel', ...
    'Legend','Colorbar' ...
};
allowed = [protoTypes(:); childProps(:)];
allowed = allowed(:);
% sort by length descending for greedy
[~, idx] = sort(cellfun(@numel, allowed), 'descend');
allowed = allowed(idx);

tars = {};
hCur = [];  % current prototype handle resolved along the chain

while ~isempty(rest)
    matched = false;

    % If we already have a current object, and the remaining tail is a property of it,
    % stop tokenization and treat the remainder as property.
    if ~isempty(hCur) && isgraphics(hCur)
        if isprop(hCur, rest)
            prop = rest;
            return
        end
        % case-insensitive fallback (optional)
        p = properties(hCur);
        hit = find(strcmpi(p, rest), 1);
        if ~isempty(hit)
            prop = p{hit};
            return
        end
    end

    % Must match one more token
    for k = 1:numel(allowed)
        tk = allowed{k};
        if strncmp(rest, tk, numel(tk))
            tars{end+1} = tk; %#ok<AGROW>
            rest = rest(numel(tk)+1:end);
            matched = true;

            % update hCur along the prototype chain
            if isempty(hCur)
                % first token: type or child-prop must be resolvable from some proto
                if isfield(proto, tk)
                    hCur = proto.(tk);
                else
                    % child-prop token at start: find any proto type that has it
                    hCur = [];
                    protoNames = fieldnames(proto);
                    for pp = 1:numel(protoNames)
                        hp = proto.(protoNames{pp});
                        if isgraphics(hp) && isprop(hp, tk)
                            try
                                hc = hp.(tk);
                                if isgraphics(hc)
                                    hCur = hc;
                                    break
                                end
                            catch
                            end
                        end
                    end
                end
            else
                % subsequent token: type token or child-prop token
                if isfield(proto, tk)
                    hNext = proto.(tk);
                else
                    hNext = [];
                    if isprop(hCur, tk)
                        try
                            hc = hCur.(tk);
                            if isgraphics(hc), hNext = hc; end
                        catch
                        end
                    end
                end
                hCur = hNext;
            end

            break
        end
    end

    if ~matched
        % no more tokens; remainder must be property of current object
        break
    end
end

assert(~isempty(tars), 'Cannot parse chain-style name "%s".', s);
assert(~isempty(rest), 'Chain-style "%s" has no property tail.', s);

% final property assignment (prefer exact, then case-insensitive)
if ~isempty(hCur) && isgraphics(hCur)
    if isprop(hCur, rest)
        prop = rest;
        return
    end
    p = properties(hCur);
    hit = find(strcmpi(p, rest), 1);
    if ~isempty(hit)
        prop = p{hit};
        return
    end
end

% fallback: accept raw tail (validator will throw if invalid)
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

function tf = hasExclusionTag_(h)
tf = false(size(h));
for i = 1:numel(h)
    try
        tf(i) = isprop(h(i),'Tag') && strcmp(h(i).Tag, 'setPlotModeExclusion');
    catch
        tf(i) = false;
    end
end
end

function defName = buildDefaultName_(tars, prop)
% Build DefaultXXXX name like DefaultAxesTitleFontSize from tokens + prop.
% Keep token casing as-is.
defName = ['Default' strjoin(cellfun(@char, tars(:).', 'UniformOutput', false), '') char(prop)];
end
