function v = getorfull(s, default)
% Description:
%     Complete [s] with [default]. [default] is specified as a
%     struct containing some fields of [s] with default values.
%     Fields not in [default] but in [s] or not in [s] but in
%     [default] will be reserved.
%     For fields in both [s] and [default], field values in [s]
%     will be reserved.
%     For [s] as struct array, [default] should be a scalar or of
%     the same length of [s].
%     If [s] and [default] are struct arrays of the same length, 
%     [s] will be completed with [default] in corresponding indices.
%     
% Example:
%     A = struct("a1", 1, "a2", 2);
%     B = struct("a1", 11, "a3", 3);
%
%     C = mu.getorfull(A, B) returns
%     >> C.a1 = 1
%     >> C.a2 = 2
%     >> C.a3 = 3
%
%     D = mu.getorfull(B, A) returns
%     >> D.a1 = 11
%     >> D.a2 = 2
%     >> D.a3 = 3

if ~isstruct(default) || (~isstruct(s) && ~isempty(s))
    error("Inputs should be type struct");
end

if isscalar(default)
    if isempty(s)
        v = getorfullImpl(s, default);
    else
        v = arrayfun(@(x) getorfullImpl(x, default), s);
    end
else
    if numel(default) ~= numel(s)
        error("[default] should be a scalar or of the same size as [s]");
    end
    v = arrayfun(@(x, y) getorfullImpl(x, y), s, default);
end

return;
end

%% Impl
function v = getorfullImpl(s, default)
    fieldNamesAll = fieldnames(default);

    for fIndex = 1:length(fieldNamesAll)
        v.(fieldNamesAll{fIndex}) = mu.getor(s, fieldNamesAll{fIndex}, default.(fieldNamesAll{fIndex}));
    end

    if ~isempty(s)
        fieldNamesS = fieldnames(s);

        for fIndex = 1:length(fieldNamesS)
            v.(fieldNamesS{fIndex}) = s.(fieldNamesS{fIndex});
        end

    end

    return;
end
