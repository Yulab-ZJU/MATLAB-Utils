function A = replacevalMat(A, newVal, oldVal, tol)
%REPLACEVALMAT Replace values in array A: any entry matching oldVal (or NaN) -> newVal.
%
% SYNTAX
%   A = mu.replacevalMat(A, newVal, oldVal)
%   A = mu.replacevalMat(A, newVal, oldVal, tol)
%
% INPUT
%   A      : numeric/logical array
%   newVal : numeric/logical scalar (replacement)
%   oldVal : numeric/logical array of values to be replaced; may contain NaN for float A
%   tol    : nonnegative scalar tolerance for floating point match (default 0)
%            match criterion: abs(A - v) <= tol
%
% NOTES
%   - NaN in oldVal means replacing NaNs in A (only meaningful for floating types).
%   - For tol>0, this function uses a chunked tolerance match to control memory.
%
% EXAMPLE
%   A = [0 1 1+1e-12 NaN];
%   A = mu.replacevalMat(A, 99, [1 NaN], 1e-9);

narginchk(3,4);
if nargin < 4 || isempty(tol)
    tol = 0;
end

% ---- Validate A ----
if ~(isnumeric(A) || islogical(A))
    error("replacevalMat:InvalidA", "A must be numeric or logical.");
end

% ---- Validate tol ----
if ~(isnumeric(tol) && isscalar(tol) && isfinite(tol) && tol >= 0)
    error("replacevalMat:InvalidTol", "tol must be a nonnegative finite scalar.");
end

% ---- Validate newVal ----
if ~(isnumeric(newVal) || islogical(newVal)) || ~isscalar(newVal)
    error("replacevalMat:InvalidNewVal", "newVal must be a numeric/logical scalar.");
end
if islogical(A) && ~islogical(newVal)
    error("replacevalMat:TypeMismatch", "When A is logical, newVal must be logical.");
end

% ---- Validate oldVal ----
if ~(isnumeric(oldVal) || islogical(oldVal))
    error("replacevalMat:InvalidOldVal", "oldVal must be numeric or logical.");
end
if isempty(oldVal)
    return;
end
if islogical(A) && ~islogical(oldVal)
    error("replacevalMat:TypeMismatch", "When A is logical, oldVal must be logical.");
end

% Integer A: disallow NaN/Inf in old/new and enforce range for newVal
if isinteger(A)
    nv = double(newVal);
    if ~isfinite(nv) || isnan(nv)
        error("replacevalMat:InvalidNewVal", "newVal must be finite for integer A.");
    end
    mn = double(intmin(class(A)));
    mx = double(intmax(class(A)));
    if nv < mn || nv > mx
        error("replacevalMat:OutOfRange", "newVal is out of range for class(A) = %s.", class(A));
    end

    ov = double(oldVal(:));
    if any(~isfinite(ov) | isnan(ov))
        error("replacevalMat:InvalidOldVal", "oldVal must be finite for integer A.");
    end

    if tol ~= 0
        error("replacevalMat:InvalidTol", "tol must be 0 when A is an integer type.");
    end
end

% ---- Normalize/cast oldVal for comparison ----
oldVal = oldVal(:);

% For logical/integer handled above; for numeric: try cast oldVal to like A
if (isnumeric(A) || islogical(A)) && ~strcmp(class(oldVal), class(A))
    if ~islogical(A)
        try
            oldVal = cast(oldVal, 'like', A);
        catch
            % Fallback: compare in double (only if A is floating or can be safely promoted)
            if ~isfloat(A)
                A = double(A);
            end
            oldVal = double(oldVal);
        end
    end
end

% ---- Separate NaN condition (only meaningful for float A) ----
hasNaN = isfloat(A) && any(isnan(oldVal));
if hasNaN
    oldValNoNaN = oldVal(~isnan(oldVal));
else
    oldValNoNaN = oldVal;
end

mask = false(size(A));

if hasNaN
    mask = mask | isnan(A);
end

% ---- Exact match path (fast) ----
if tol == 0 || ~isfloat(A)
    if ~isempty(oldValNoNaN)
        mask = mask | ismember(A, oldValNoNaN);
    end
    A(mask) = cast(newVal, 'like', A);
    return;
end

% ---- Tolerance match path (float only) ----
% Reduce redundant values to save work
oldValNoNaN = unique(oldValNoNaN);

if ~isempty(oldValNoNaN)
    % Chunk across oldVal to limit memory: abs(A - v) creates an array of size(A) per v
    % Tune chunk size heuristically; keep it modest.
    chunkSize = 32;
    for s = 1:chunkSize:numel(oldValNoNaN)
        e = min(s + chunkSize - 1, numel(oldValNoNaN));
        v = reshape(oldValNoNaN(s:e), 1, 1, []);  %#ok<NASGU>

        % implicit expansion: abs(A - v) -> [size(A) numel(v)]
        hit = any(abs(A - reshape(oldValNoNaN(s:e), 1, 1, [])) <= tol, 3);
        mask = mask | hit;

        % early exit if everything matched
        if all(mask(:))
            break;
        end
    end
end

A(mask) = cast(newVal, 'like', A);

return;
end
