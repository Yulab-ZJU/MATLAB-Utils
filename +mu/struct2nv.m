function nv = struct2nv(S, opts)
%STRUCT2NV  Convert struct to Name-Value cell array (flattened).
%
% nv = mu.struct2nv(S)
% nv = mu.struct2nv(S, Name=Value, ...)

arguments
    S (1,1) struct

    opts.Prefix string = ""
    opts.NameStyle (1,1) string ...
        {mustBeMember(opts.NameStyle, ["dotted","underscore","none"])} = "dotted"

    opts.FieldCase (1,1) string ...
        {mustBeMember(opts.FieldCase, ["keep","lower","upper"])} = "keep"

    opts.Recurse (1,1) logical = true
    opts.KeepEmpty (1,1) logical = true
    opts.KeepMissing (1,1) logical = true
    opts.SortFields (1,1) logical = false

    opts.IgnoreFields string = string.empty
    opts.IgnoreEmptyStruct (1,1) logical = true

    opts.AllowStructArray (1,1) logical = false
    opts.IndexStyle (1,1) string ...
        {mustBeMember(opts.IndexStyle, ["paren","brace","dot"])} = "paren"

    opts.MaxDepth (1,1) double {mustBeNonnegative} = inf
end

% -------------------------
% struct array handling
% -------------------------
if numel(S) > 1 && ~opts.AllowStructArray
    S = S(1);
end

% -------------------------
% main
% -------------------------
nv = walkStruct(S, applyCase(opts.Prefix), 0);
nv = reshape(nv, 1, []);

% ============================================================
% nested helpers
% ============================================================
    function out = walkStruct(SS, prefix, depth)
        if depth > opts.MaxDepth
            out = {};
            return;
        end

        out = {};

        % ---- struct array ----
        if numel(SS) > 1 && opts.AllowStructArray
            for ii = 1:numel(SS)
                idxName = addIndex(prefix, ii);
                out = [out, walkStruct(SS(ii), idxName, depth)]; %#ok<AGROW>
            end
            return;
        end

        f = fieldnames(SS);
        if isempty(f)
            if opts.IgnoreEmptyStruct
                return;
            elseif strlength(prefix) > 0
                out = {char(prefix), SS};
            end
            return;
        end

        if opts.SortFields
            f = sort(f);
        end

        for i = 1:numel(f)
            rawKey = string(f{i});
            key = applyCase(rawKey);

            if any(strcmpi(key, opts.IgnoreFields))
                continue;
            end

            val = SS.(f{i});
            name = joinName(prefix, key);

            if isstruct(val) && opts.Recurse
                if isempty(fieldnames(val)) && opts.IgnoreEmptyStruct
                    continue;
                end
                out = [out, walkStruct(val, name, depth+1)]; %#ok<AGROW>
            else
                if ~opts.KeepEmpty
                    if isempty(val) || (isstring(val) && isscalar(val) && strlength(val)==0)
                        continue;
                    end
                end
                out = [out, {char(name), val}]; %#ok<AGROW>
            end
        end
    end

    function name = joinName(prefix, key)
        if strlength(prefix) == 0
            name = key;
            return;
        end
        switch opts.NameStyle
            case "dotted"
                name = prefix + "." + key;
            case "underscore"
                name = prefix + "_" + key;
            case "none"
                name = key;
        end
    end

    function s = addIndex(prefix, ii)
        if strlength(prefix) == 0
            base = "S";
        else
            base = prefix;
        end
        switch opts.IndexStyle
            case "paren"
                s = base + "(" + ii + ")";
            case "brace"
                s = base + "{" + ii + "}";
            case "dot"
                s = base + "." + ii;
        end
    end

    function s = applyCase(s)
        switch opts.FieldCase
            case "lower"
                s = lower(s);
            case "upper"
                s = upper(s);
            otherwise % "keep"
                % do nothing
        end
    end
end
