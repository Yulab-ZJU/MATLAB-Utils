function out = nvdropempty(in, opts)
%NVDROPEMPTY  Drop empty values from NV cell or struct.
%
% out = mu.nvdropempty(in)
% out = mu.nvdropempty(in, OutType="follow")
% out = mu.nvdropempty(in, FieldCase="lower", ValidateNV=true)
%
% INPUT
%   in : NV cell vector {'Name',Value,...} OR struct (scalar/array)
%
% OPTIONS
%   OutType         : "follow" | "nv" | "S" (default "follow")
%                     - follow: output type follows input type
%   FieldCase       : "keep" | "lower" | "upper" (default "keep")
%                     - applied to struct fieldnames (via mu.nvnorm if available)
%                     - for NV, only affects Name strings (optional)
%   ValidateNV      : true/false (default true)
%   StructArrayMode : "all" | "error" | "keep" (default "all")
%                     - When input is struct array:
%                       "all"  : remove a field only if ALL elements are empty for that field
%                       "error": error if a field is empty in some elements but not all
%                       "keep" : never remove fields for struct arrays
%
% RULE
%   - "empty" is defined by isempty(value).
%   - For NV, remove pairs whose VALUE is empty.
%   - For struct scalar, remove fields whose VALUE is empty.
%   - For struct array, see StructArrayMode.
%
% NOTE
%   If mu.nvnorm exists, it is used for normalization & validation.

arguments
    in
    opts.OutType (1,1) string {mustBeMember(opts.OutType, ["follow","nv","S"])} = "follow"
    opts.FieldCase (1,1) string {mustBeMember(opts.FieldCase, ["keep","lower","upper"])} = "keep"
    opts.ValidateNV (1,1) logical = true
    opts.StructArrayMode (1,1) string {mustBeMember(opts.StructArrayMode, ["all","error","keep"])} = "all"
end

% determine desired output type
if opts.OutType == "follow"
    if isstruct(in)
        outType = "S";
    else
        outType = "nv";
    end
else
    outType = opts.OutType;
end

% ---- Dispatch ----
if isstruct(in)
    S = in;

    % normalize struct field case if mu.nvnorm exists
    if exist("mu.nvnorm","file") == 2 && opts.FieldCase ~= "keep"
        S = mu.nvnorm(S, OutType="S", FieldCase=opts.FieldCase, ValidateNV=false);
    elseif opts.FieldCase ~= "keep"
        % fallback: simple rename for scalar; for array do per-element but check collisions
        S = renameStructFieldCaseFallback_(S, opts.FieldCase);
    end

    S2 = dropEmptyFromStruct_(S, opts.StructArrayMode);

    if outType == "S"
        out = S2;
    else
        out = struct2nvPreferMu_(S2, opts);
    end
    return;
end

% NV-like
if ~iscell(in)
    error("mu:nvdropempty:InvalidInput", "Input must be a struct or an NV cell vector.");
end

nv = in;

% normalize/validate NV if mu.nvnorm exists (strongly recommended)
if exist("mu.nvnorm","file") == 2
    if opts.ValidateNV
        nv = mu.nvnorm(nv, OutType="nv", FieldCase=opts.FieldCase, ValidateNV=true);
    else
        nv = mu.nvnorm(nv, OutType="nv", FieldCase=opts.FieldCase, ValidateNV=false);
    end
else
    if opts.ValidateNV
        validateNVFallback_(nv);
    end
    % apply FieldCase to NV names in fallback (optional)
    if opts.FieldCase ~= "keep"
        nv = applyFieldCaseToNVNamesFallback_(nv, opts.FieldCase);
    end
end

nv2 = dropEmptyNVValues_(nv);

if outType == "nv"
    out = nv2;
else
    out = nv2structPreferMu_(nv2);
end

end

%% ================= helpers =================

function nv = dropEmptyNVValues_(nv)
% Remove NV pairs whose VALUE is empty. nv is 1x(2N) cell.
if isempty(nv), return; end
vals = nv(2:2:end);
keep = ~cellfun(@isempty, vals);
names = nv(1:2:end);
nv = reshape([names(keep); vals(keep)], 1, []);
end

function S2 = dropEmptyFromStruct_(S, mode)
if isempty(S)
    S2 = S;
    return;
end

if isscalar(S)
    f = fieldnames(S);
    keep = true(size(f));
    for i = 1:numel(f)
        keep(i) = ~isempty(S.(f{i}));
    end
    S2 = rmfield(S, f(~keep));
    return;
end

% struct array
switch mode
    case "keep"
        S2 = S;
        return;

    case "all"
        f = fieldnames(S);
        rm = false(size(f));
        for i = 1:numel(f)
            % remove only if ALL empty
            rm(i) = all(arrayfun(@(x) isempty(x.(f{i})), S));
        end
        if any(rm)
            S2 = rmfield(S, f(rm));
        else
            S2 = S;
        end

    case "error"
        f = fieldnames(S);
        for i = 1:numel(f)
            empt = arrayfun(@(x) isempty(x.(f{i})), S);
            if any(empt) && ~all(empt)
                error("mu:nvdropempty:StructArrayMixedEmpty", ...
                    "Field '%s' is empty in some elements but not all. Set StructArrayMode='all' or 'keep'.", f{i});
            end
        end
        S2 = dropEmptyFromStruct_(S, "all");

end
end

function nv = struct2nvPreferMu_(S, opts)
if exist("mu.struct2nv","file") == 2
    % pass FieldCase if your mu.struct2nv supports it (you added earlier)
    try
        nv = mu.struct2nv(S, FieldCase=opts.FieldCase);
    catch
        nv = mu.struct2nv(S);
    end
else
    % fallback flat only
    f = fieldnames(S);
    nv = cell(1, 2*numel(f));
    for i = 1:numel(f)
        nv{2*i-1} = f{i};
        nv{2*i}   = S.(f{i});
    end
end
end

function S = nv2structPreferMu_(nv)
if exist("mu.nv2struct","file") == 2
    S = mu.nv2struct(nv{:});
else
    % fallback flat only
    S = struct();
    for i = 1:2:numel(nv)
        name = nv{i};
        if isstring(name), name = char(name); end
        S.(name) = nv{i+1};
    end
end
end

function validateNVFallback_(nv)
if ~isvector(nv) || mod(numel(nv),2)~=0
    error("mu:nvdropempty:BadNV", "NV must be a vector cell array with even number of elements.");
end
if isempty(nv), return; end
names = nv(1:2:end);
for i = 1:numel(names)
    n = names{i};
    if ~((ischar(n) && isrow(n)) || (isstring(n) && isscalar(n)))
        error("mu:nvdropempty:BadNVName", "NV name at pair #%d must be char row or string scalar.", i);
    end
    if strlength(string(n))==0
        error("mu:nvdropempty:BadNVName", "NV name at pair #%d is empty.", i);
    end
end
end

function nv = applyFieldCaseToNVNamesFallback_(nv, fieldCase)
if isempty(nv), return; end
for i = 1:2:numel(nv)
    s = string(nv{i});
    switch fieldCase
        case "lower", s = lower(s);
        case "upper", s = upper(s);
    end
    nv{i} = char(s);
end
end

function S = renameStructFieldCaseFallback_(S, fieldCase)
if fieldCase == "keep" || isempty(S)
    return;
end
if ~isscalar(S)
    % struct array: rename based on first element, must not collide
    f = fieldnames(S);
    f2 = cellstr(applyCase_(string(f), fieldCase));
    if numel(unique(f2)) ~= numel(f2)
        error("mu:nvdropempty:FieldCollision", "Fieldname collision after FieldCase conversion.");
    end
    % rebuild array
    Snew = repmat(struct(), size(S));
    for k = 1:numel(S)
        for i = 1:numel(f)
            Snew(k).(f2{i}) = S(k).(f{i});
        end
    end
    S = Snew;
else
    f = fieldnames(S);
    f2 = cellstr(applyCase_(string(f), fieldCase));
    if numel(unique(f2)) ~= numel(f2)
        error("mu:nvdropempty:FieldCollision", "Fieldname collision after FieldCase conversion.");
    end
    Snew = struct();
    for i = 1:numel(f)
        Snew.(f2{i}) = S.(f{i});
    end
    S = Snew;
end
end

function y = applyCase_(x, fieldCase)
switch fieldCase
    case "lower", y = lower(x);
    case "upper", y = upper(x);
    otherwise,    y = x;
end
end
