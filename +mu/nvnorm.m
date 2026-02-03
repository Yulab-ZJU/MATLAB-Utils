function out = nvnorm(in, opts)
%NVNORM  Normalize Name-Value list or struct to NV or struct with validation.
%
% out = mu.nvnorm(in)
% out = mu.nvnorm(in, OutType="nv")
% out = mu.nvnorm(in, OutType="S", FieldCase="lower")
%
% INPUT
%   in   : struct | struct array | NV cell vector
%
% OPTIONS (opts)
%   OutType            : "nv" | "S" (default "nv")
%   FieldCase          : "keep" | "lower" | "upper" (default "keep")
%   AllowStructArray   : true/false (default true)
%   StructArrayNV      : "cell" | "error" | "first" (default "cell")
%                        - when in is struct array and OutType="nv"
%   ValidateNV         : true/false (default true)
%   RequireValidName   : true/false (default true)  % name must be valid fieldname or dotted path
%   AllowDotted        : true/false (default true)  % allow "a.b.c" paths
%   DottedDelimiter    : "." (default ".")
%   DuplicateNames     : "allow" | "error" | "lastwins" (default "lastwins")
%
% OUTPUT
%   out  : NV cell vector (1x2N) OR struct (scalar or array)
%
% NOTES
%   - If mu.nv2struct / mu.struct2nv exist, they will be used preferentially.
%   - FieldCase is applied to every name segment (for dotted paths too).
%
% Example
%   nv = {'Alpha',1,'Beta.Gamma',2};
%   S  = mu.nvnorm(nv, OutType="S", FieldCase="lower");
%   % S.alpha = 1; S.beta.gamma = 2

arguments
    in
    opts.OutType   (1,1) string {mustBeMember(opts.OutType, ["nv","S"])} = "nv"
    opts.FieldCase (1,1) string {mustBeMember(opts.FieldCase, ["keep","lower","upper"])} = "keep"

    opts.AllowStructArray (1,1) logical = true
    opts.StructArrayNV    (1,1) string {mustBeMember(opts.StructArrayNV, ["cell","error","first"])} = "cell"

    opts.ValidateNV       (1,1) logical = true
    opts.RequireValidName (1,1) logical = true
    opts.AllowDotted      (1,1) logical = true
    opts.DottedDelimiter  (1,1) string = "."

    opts.DuplicateNames (1,1) string {mustBeMember(opts.DuplicateNames, ["allow","error","lastwins"])} = "lastwins"
end

if isempty(in)
    out = mu.ifelse(strcmpi(opts.OutType, "nv"), {}, struct([]));
    return;
end

% -------------------------
% 0) Dispatch by input type
% -------------------------
if isstruct(in)
    S = normalizeStructFieldCase(in, opts);
    out = convertFromStruct(S, opts);
    return;
end

% NV-like input must be cell vector
if ~iscell(in)
    error("nvnorm:InvalidInput", "Input must be a struct or an NV cell vector.");
end

nv = in;

% -------------------------
% 1) Validate NV
% -------------------------
if opts.ValidateNV
    validateNV(nv, opts);
end

% -------------------------
% 2) Apply FieldCase to NV names (including dotted segments)
% -------------------------
nv = normalizeNVNamesCase(nv, opts);

% -------------------------
% 3) Convert to requested output type
% -------------------------
switch opts.OutType
    case "nv"
        out = nv;
    case "S"
        out = nv2structPreferMu(nv, opts);
end

end

%% ========================================================================
% Helpers
% ========================================================================

function out = convertFromStruct(S, opts)
    % struct -> NV or struct (already cased)
    if opts.OutType == "S"
        out = S;
        return;
    end

    % OutType == "nv"
    if numel(S) > 1
        if ~opts.AllowStructArray
            error("nvnorm:StructArrayNotAllowed", "Struct array input is not allowed (AllowStructArray=false).");
        end
        switch opts.StructArrayNV
            case "error"
                error("nvnorm:StructArrayToNV", "Struct array cannot be converted to a single NV. Use StructArrayNV='cell' or 'first'.");
            case "first"
                out = struct2nvPreferMu(S(1), opts);
            case "cell"
                out = arrayfun(@(x) struct2nvPreferMu(x, opts), S, 'UniformOutput', false);
        end
    else
        out = struct2nvPreferMu(S, opts);
    end
end

function validateNV(nv, opts)
    if ~isvector(nv)
        error("nvnorm:BadNV", "NV must be a vector cell array.");
    end
    if mod(numel(nv), 2) ~= 0
        error("nvnorm:BadNV", "NV must contain an even number of elements (Name/Value pairs).");
    end
    if isempty(nv)
        return;
    end

    names = nv(1:2:end);

    % name type check
    for i = 1:numel(names)
        n = names{i};
        if ~( (ischar(n) && isrow(n)) || (isstring(n) && isscalar(n)) )
            error("nvnorm:BadNVName", "NV name at pair #%d must be a char row or string scalar.", i);
        end
        ns = string(n);
        if strlength(ns) == 0
            error("nvnorm:BadNVName", "NV name at pair #%d is empty.", i);
        end

        % name validity check (fieldname or dotted path)
        if opts.RequireValidName
            if opts.AllowDotted && contains(ns, opts.DottedDelimiter)
                seg = split(ns, opts.DottedDelimiter);
                if any(seg == "")
                    error("nvnorm:BadNVName", "NV name '%s' has empty dotted segment.", ns);
                end
                for k = 1:numel(seg)
                    if ~isvarname(char(seg(k)))
                        error("nvnorm:BadNVName", ...
                            "NV name '%s' has invalid segment '%s' (must be valid fieldname).", ns, seg(k));
                    end
                end
            else
                if ~isvarname(char(ns))
                    error("nvnorm:BadNVName", "NV name '%s' is not a valid fieldname.", ns);
                end
            end
        end
    end

    % duplicate policy (after case normalization, because collisions happen there)
    namesStr = string(names);
    namesNorm = normalizeNameCaseAndDotted(namesStr, opts);

    switch opts.DuplicateNames
        case "allow"
            % nothing
        case "error"
            if numel(unique(namesNorm, 'stable')) ~= numel(namesNorm)
                d = findDuplicate(namesNorm);
                error("nvnorm:DuplicateNames", "Duplicate NV names detected after normalization: '%s'.", d);
            end
        case "lastwins"
            % ok; conversion to struct will naturally last-wins in our fallback
    end
end

function s = findDuplicate(namesNorm)
    [u,~,ic] = unique(namesNorm, 'stable');
    counts = accumarray(ic, 1);
    idx = find(counts > 1, 1, 'first');
    s = char(u(idx));
end

function nv = normalizeNVNamesCase(nv, opts)
    if isempty(nv), return; end
    for i = 1:2:numel(nv)
        nv{i} = char(normalizeNameCaseAndDotted(string(nv{i}), opts));
    end
end

function outName = normalizeNameCaseAndDotted(names, opts)
    for i = 1:numel(names)
        name = names(i);

        % apply FieldCase to each dotted segment (or whole name)
        delim = opts.DottedDelimiter;
        if opts.AllowDotted && contains(name, delim)
            seg = split(name, delim);
            seg = applyCase(seg, opts.FieldCase);
            outName = join(seg, delim);
        else
            outName = applyCase(name, opts.FieldCase);
        end
    end
end

function y = applyCase(x, fieldCase)
    switch fieldCase
        case "lower"
            y = lower(x);
        case "upper"
            y = upper(x);
        otherwise
            y = x;
    end
end

function S = normalizeStructFieldCase(S, opts)
    if opts.FieldCase == "keep"
        return;
    end

    if numel(S) > 1
        if ~opts.AllowStructArray
            error("nvnorm:StructArrayNotAllowed", "Struct array input is not allowed (AllowStructArray=false).");
        end
        S = arrayfun(@(x) normalizeStructFieldCaseScalar(x, opts), S);
    else
        S = normalizeStructFieldCaseScalar(S, opts);
    end
end

function S2 = normalizeStructFieldCaseScalar(S1, opts)
    f = fieldnames(S1);
    if isempty(f)
        S2 = S1;
        return;
    end
    f2 = cellstr(applyCase(string(f), opts.FieldCase));

    % detect collisions after case conversion
    if numel(unique(f2)) ~= numel(f2)
        dup = findDuplicate(string(f2));
        error("nvnorm:FieldCollision", "Fieldname collision after FieldCase conversion: '%s'.", dup);
    end

    S2 = struct();
    for i = 1:numel(f)
        S2.(f2{i}) = S1.(f{i});
    end
end

function nv = struct2nvPreferMu(S, opts)
    % Prefer mu.struct2nv if available, but still enforce FieldCase
    if exist("mu.struct2nv", "file") == 2
        nv = mu.struct2nv(S, FieldCase=opts.FieldCase);
        if opts.ValidateNV
            validateNV(nv, opts);
        end
        return;
    end

    % fallback: flat only (no nested flattening)
    f = fieldnames(S);
    if isempty(f)
        nv = {};
        return;
    end
    nv = cell(1, 2*numel(f));
    for i = 1:numel(f)
        nm = normalizeNameCaseAndDotted(string(f{i}), opts);
        nv{2*i-1} = char(nm);
        nv{2*i}   = S.(f{i});
    end

    if opts.ValidateNV
        validateNV(nv, opts);
    end
end

function S = nv2structPreferMu(nv, opts)
    % Prefer mu.nv2struct if available
    if exist("mu.nv2struct", "file") == 2
        S = mu.nv2struct(nv{:});
        % apply FieldCase again (in case mu.nv2struct doesn't)
        S = normalizeStructFieldCase(S, opts);
        return;
    end

    % fallback supporting dotted paths, last-wins
    S = struct();
    delim = opts.DottedDelimiter;

    for i = 1:2:numel(nv)
        name = string(nv{i});
        val  = nv{i+1};

        if opts.AllowDotted && contains(name, delim)
            seg = split(name, delim);
            S = setNestedField(S, seg, val);
        else
            S.(char(name)) = val;
        end
    end
end

function S = setNestedField(S, seg, val)
    % seg is string array of field path
    if isscalar(seg)
        S.(char(seg(1))) = val;
        return;
    end

    head = char(seg(1));
    tail = seg(2:end);

    if ~isfield(S, head) || ~isstruct(S.(head))
        S.(head) = struct();
    end
    S.(head) = setNestedField(S.(head), tail, val);
end
