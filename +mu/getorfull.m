function v = getorfull(s, default, varargin)
%GETORFULL  Complete struct/NV with default fields.
%
%   v = mu.getorfull(s, default)
%   v = mu.getorfull(s, default, 'ReplaceEmpty', true/false)
%
% INPUT
%   s       : struct | struct array | NV cell vector {'Name',Value,...}
%   default : struct (scalar or same size as s)
%          OR full NV cell vector {'Name',Value,...}  (scalar default only)
%
% OPTIONS (Name-Value in varargin)
%   'ReplaceEmpty' : true/false (default false)
%
% RULES
%   - Fields in s are preserved.
%   - Fields missing from s are added from default.
%   - If ReplaceEmpty=true, fields that exist in s but are empty (isempty==true)
%     will be replaced by the value from default (if default has that field).
%   - If s is NV, output is NV. If s is struct, output is struct.
%
% NOTE
%   - Name-Value pairs are NOT accepted as defaults in varargin.
%   - default can be a full NV cell vector (single default struct).

% -------------------------
% 1) Parse options (Name-Value) ONLY
% -------------------------
p = inputParser;
p.FunctionName = "mu.getorfull";
addParameter(p, "ReplaceEmpty", false, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opt = p.Results;

% -------------------------
% 2) Normalize s to struct
% -------------------------
sIsNV = isNVLike(s);

if sIsNV
    sStruct = nv2structLocal(s);
elseif isstruct(s)
    sStruct = s;
elseif isempty(s)
    sStruct = struct();
else
    error("mu:getorfull:InvalidS", "Input [s] must be a struct/struct array or an NV cell vector.");
end

% -------------------------
% 3) Normalize default to struct
%    - allow struct or full NV cell
% -------------------------
if isstruct(default)
    defaultStruct = default;

elseif isNVLike(default)
    % full NV default only supports scalar default
    defaultStruct = nv2structLocal(default);

else
    error("mu:getorfull:InvalidDefault", ...
        "[default] must be a struct (scalar or same size as [s]) or a full NV cell vector {'Name',Value,...}.");
end

% -------------------------
% 4) Merge (supports scalar default OR same-size default array)
% -------------------------
if isscalar(defaultStruct)
    if isempty(sStruct)
        vStruct = getorfullImpl(sStruct, defaultStruct, opt);
    else
        vStruct = arrayfun(@(x) getorfullImpl(x, defaultStruct, opt), sStruct);
    end
else
    % Only struct default can be non-scalar; NV default converted to scalar struct above anyway.
    if ~isequal(size(defaultStruct), size(sStruct))
        error("mu:getorfull:SizeMismatch", "[default] should be scalar or same size as [s].");
    end
    vStruct = arrayfun(@(x, y) getorfullImpl(x, y, opt), sStruct, defaultStruct);
end

% -------------------------
% 5) Output follows input type
% -------------------------
if sIsNV
    v = struct2nvLocal(vStruct);
else
    v = vStruct;
end

end

%% ========================================================================
% Impl
% ========================================================================
function v = getorfullImpl(s, default, opt)
    if isempty(s)
        v = default;
        return;
    end

    v = s;

    fieldNamesDefault = fieldnames(default);
    for k = 1:numel(fieldNamesDefault)
        fn = fieldNamesDefault{k};

        if ~isfield(v, fn)
            v.(fn) = default.(fn);
        elseif opt.ReplaceEmpty && isempty(v.(fn))
            v.(fn) = default.(fn);
        end
    end
end

%% ========================================================================
% Helpers: NV detection + conversions (mu-first, fallback)
% ========================================================================
function tf = isNVLike(x)
    tf = iscell(x) && (isempty(x) || (isvector(x) && mod(numel(x),2)==0));
    if tf && ~isempty(x)
        names = x(1:2:end);
        tf = all(cellfun(@(t) (ischar(t) && isrow(t)) || (isstring(t) && isscalar(t)), names));
    end
end

function S = nv2structLocal(nv)
    if isempty(nv)
        S = struct();
        return;
    end

    if exist("mu.nv2struct","file") == 2
        S = mu.nv2struct(nv{:});
        if isempty(S), S = struct(); end
        return;
    end

    % fallback: flat only, last-wins
    S = struct();
    for i = 1:2:numel(nv)
        name = nv{i};
        if isstring(name), name = char(name); end
        S.(name) = nv{i+1};
    end
end

function nv = struct2nvLocal(S)
    if exist("mu.struct2nv","file") == 2
        nv = mu.struct2nv(S);
        return;
    end

    % fallback: flat only
    f = fieldnames(S);
    nv = cell(1, 2*numel(f));
    for i = 1:numel(f)
        nv{2*i-1} = f{i};
        nv{2*i}   = S.(f{i});
    end
end
