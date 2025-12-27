function setPlotMode(varargin)
%SETPLOTMODE  Set or restore default plotting properties.
%
% NOTES:
%   - Call before plotting to affect defaults via groot.
%   - Or pass a figure/axes handle to modify existing objects; if none exist for a target,
%     falls back to setting corresponding default on the handle, then groot.
%   - When calling mu.setPlotMode(Fig,'pdf'), this function will call mu.setAxes(Fig,"default")
%     to format all axes in Fig.
%
% USAGE:
%   mu.setPlotMode('factory')
%   mu.setPlotMode('pdf')
%   mu.setPlotMode(..., TargetProperty, Value, ...)
%   mu.setPlotMode(root, ..., TargetProperty, Value, ...)
%   mu.setPlotMode(root, ..., Property, Value, ...)  % apply to all targets having Property

% ------------------------------------------------------------
% 0) Optional graphics handle (Figure or Axes recommended)
% ------------------------------------------------------------
H = [];
if nargin >= 1 && isgraphics(varargin{1})
    % only treat as handle when it's not a text mode specifier
    if ~mu.isTextScalar(varargin{1})
        H = varargin{1};
        varargin = varargin(2:end);
    else
        % could still be a graphics handle in string form (unlikely), ignore
    end
end

% ------------------------------------------------------------
% 1) Optional plotMode
% ------------------------------------------------------------
plotMode = 'manual';
if ~isempty(varargin) && ...
   mu.isTextScalar(varargin{1}) && ...
   matches(varargin{1}, {'factory', 'pdf', 'manual'}, "IgnoreCase", true)
    plotMode = varargin{1};
    varargin = varargin(2:end);
end
plotMode = validatestring(lower(plotMode), {'factory', 'pdf', 'manual'});

validTargets = {'Line', 'Scatter', 'Patch', 'Axes', 'Text', 'Legend', 'Figure', 'Colorbar'};

% PDF preset defaults (TargetProperty style)
params = {'LineLineWidth'   , 0.3, ...
          'ScatterLineWidth', 0.3, ...
          'PatchLineWidth'  , 0.3, ...
          'LineMarkerSize'  , 1, ...
          'ScatterSizeData' , 1};

% ------------------------------------------------------------
% 2) Presets
% ------------------------------------------------------------
switch plotMode
    case 'factory'
        if isempty(H)
            reset(groot);
        else
            reset(H); % This will not change current plots but will affect the following plots
        end

    case 'pdf'
        setTargetProperty(H, params(1:2:end), params(2:2:end), validTargets);

        % --- NEW: format axes appearance when H is provided ---
        if ~isempty(H)
            try
                % Ensure all axes under H are formatted
                mu.setAxes(H, "default");
            catch
                % If mu.setAxes is not available or errors, do not stop setPlotMode
                warning('Failed to apply mu.setAxes(H,"default") during pdf preset.');
            end
        end
end

% ------------------------------------------------------------
% 3) Parse name-value pairs (must be even count)
% ------------------------------------------------------------
if isempty(varargin)
    return;
end
assert(mod(numel(varargin),2) == 0, "Name-value inputs must come in pairs.");

names = varargin(1:2:end);
vals  = varargin(2:2:end);

setTargetProperty(H, names, vals, validTargets);
return;
end

% ============================================================
% Helpers
% ============================================================

function [tar, prop] = parseTargetProperty(paramName, validTargets)
%PARSETARGETPROPERTY  Parse TargetProperty or Property-only name.
%
% RULES:
%   - Target and Property must start with uppercase letters.
%   - If paramName starts with a valid target AND the remaining Property
%     starts with an uppercase letter -> explicit TargetProperty.
%   - If paramName starts with a valid target BUT remaining part does NOT
%     start with uppercase (e.g. LineWidth) -> treat as Property-only.
%   - If paramName does not start with any valid target -> Property-only.
%
% OUTPUT:
%   tar  - target name ('' if Property-only)
%   prop - property name

assert(ischar(paramName) || isstring(paramName), ...
    'paramName must be a char or string.');
paramName = char(paramName);

assert(~isempty(paramName) && isstrprop(paramName(1), 'upper'), ...
    'Property name must start with an uppercase letter.');

tar  = '';
prop = paramName;

bestTar = '';
for k = 1:numel(validTargets)
    t = validTargets{k};
    if startsWith(paramName, t)
        if numel(t) > numel(bestTar)
            bestTar = t;
        end
    end
end

if ~isempty(bestTar)
    rest = paramName(numel(bestTar)+1:end);
    if ~isempty(rest) && isstrprop(rest(1), 'upper')
        tar  = bestTar;
        prop = rest;
    else
        tar  = '';
        prop = paramName;
    end
end
end

function setTargetProperty(H, names, vals, validTargets)
proto = getPrototypeHandles_(); % for isprop legality checks

for i = 1:numel(names)
    paramName = names{i};
    paramVal  = vals{i};

    assert(mu.isTextScalar(paramName), ...
        "Invalid param name at pair #%d: must be a text scalar.", i);

    paramName = char(paramName);

    % allow user to pass "DefaultXXX" too
    if startsWith(paramName, "factory", "IgnoreCase", true)
        paramName = paramName(8:end);
    end

    [tar0, prop] = parseTargetProperty(paramName, validTargets);

    % Resolve targets:
    %   - explicit target: single (and property must belong to that target)
    %   - property-only: all targets that actually have this property
    if isempty(tar0)
        tar = {};
        for k = 1:numel(validTargets)
            t = validTargets{k};
            if isprop(proto.(t), prop)
                tar{end+1} = t; %#ok<AGROW>
            end
        end
        assert(~isempty(tar), ...
            'Invalid property "%s": none of the supported targets has this property.', prop);
    else
        assert(isprop(proto.(tar0), prop), ...
            'Invalid property "%s" for target "%s".', prop, tar0);
        tar = {tar0};
    end

    % Apply per target
    for k = 1:numel(tar)
        t = tar{k};
        tType = lower(t); % 'Colorbar' -> 'colorbar'

        if isempty(H)
            % No handle: set defaults on groot
            defaultName = ['Default', t, prop];
            trySetDefault_(groot, defaultName, paramVal);

        else
            % Handle provided: set existing objects under H; otherwise set defaults on H then groot
            objs = findall(H, "Type", tType);

            if ~isempty(objs)
                try
                    set(objs, prop, paramVal);
                catch ME
                    error('Failed to set %s.%s: %s', t, prop, ME.message);
                end
            else
                defaultName = ['Default', t, prop];
                if ~trySetDefault_(H, defaultName, paramVal)
                    trySetDefault_(groot, defaultName, paramVal);
                end
            end
        end
    end
end
end

function ok = trySetDefault_(hRoot, defaultName, value)
% Try set(hRoot, defaultName, value). Return true if succeeded.
ok = false;
try
    if isprop(hRoot, defaultName)
        set(hRoot, defaultName, value);
        ok = true;
    end
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

f  = figure('Visible','off');
ax = axes('Parent', f); hold on;

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
