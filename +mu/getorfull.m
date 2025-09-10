function v = getorfull(s, default)
%GETORFULL  Complete struct s with default fields.
%   v = mu.getorfull(s, default)
%   - Fields in s are preserved.
%   - Fields in default missing from s are added.
%   - Works for scalar or struct arrays.

arguments
    s (:,1) struct
    default (:,1) struct
end

if isscalar(default)
    if isempty(s)
        v = getorfullImpl(s, default);
    else
        v = arrayfun(@(x) getorfullImpl(x, default), s);
    end
else
    if numel(default) ~= numel(s)
        error("[default] should be scalar or same size as [s]");
    end
    v = arrayfun(@(x, y) getorfullImpl(x, y), s, default);
end

return;
end

%% Impl
function v = getorfullImpl(s, default)
    % Start with s (may be empty struct)
    v = s;

    % Add missing fields from default
    fieldNamesDefault = fieldnames(default);
    for k = 1:numel(fieldNamesDefault)
        if ~isfield(v, fieldNamesDefault{k})
            v.(fieldNamesDefault{k}) = default.(fieldNamesDefault{k});
        end
    end

    return;
end
