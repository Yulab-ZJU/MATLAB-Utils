function tf = isapprox(A, B, opts)
%ISAPPROX  True if two arrays are approximately equal within tolerance.
%
%   tf = mu.isapprox(A, B)
%   tf = mu.isapprox(A, B, AbsTol)
%   tf = mu.isapprox(A, B, AbsTol, RelTol)
%   tf = mu.isapprox(A, B, ___, "EqualNaN", true)
%
% INPUTS
%   A, B    : Arrays to compare
%   AbsTol  : Absolute tolerance (default: 1e-10)
%   RelTol  : Relative tolerance (default: 1e-8)
%
% NAME-VALUE
%   "EqualNaN" : Whether NaNs at the same positions are treated as equal
%                (default: false)
%
% OUTPUT
%   tf : Logical scalar
%
% RULE
%   Two elements a and b are considered approximately equal if
%
%       abs(a - b) <= max(AbsTol, RelTol * max(abs(a), abs(b)))
%
% NOTES
%   - Sizes must match exactly.
%   - For non-floating numeric / logical / char arrays, exact equality is used.
%   - For cell / struct / table, this function does not recurse; use isequal instead.

% -------------------- parse inputs --------------------
arguments
    A    
    B    
    opts.AbsTol   (1,1) double = 1e-10
    opts.RelTol   (1,1) double = 1e-8
    opts.EqualNaN (1,1) logical = false
end
AbsTol = opts.AbsTol;
RelTol = opts.RelTol;
EqualNaN = opts.EqualNaN;

validateattributes(AbsTol, {'numeric'}, {'real', 'scalar', 'nonnegative'}, mfilename, 'AbsTol');
validateattributes(RelTol, {'numeric'}, {'real', 'scalar', 'nonnegative'}, mfilename, 'RelTol');

% -------------------- basic checks --------------------
if ~isequal(size(A), size(B))
    tf = false;
    return;
end

if ~strcmp(class(A), class(B))
    tf = false;
    return;
end

% -------------------- exact-comparison cases --------------------
if iscell(A) || isstruct(A) || istable(A) || isa(A, 'datetime') || isa(A, 'duration') || isa(A, 'categorical')
    tf = isequal(A, B);
    return;
end

if ~isnumeric(A) && ~islogical(A) && ~ischar(A) && ~isstring(A)
    tf = isequal(A, B);
    return;
end

if islogical(A) || ischar(A) || isstring(A) || isinteger(A)
    tf = isequal(A, B);
    return;
end

% -------------------- floating-point comparison --------------------
% Handle NaN
nanMaskA = isnan(A);
nanMaskB = isnan(B);

if any(nanMaskA(:) | nanMaskB(:))
    if ~EqualNaN
        tf = false;
        return;
    end

    if ~isequal(nanMaskA, nanMaskB)
        tf = false;
        return;
    end
end

% Handle Inf exactly
infMaskA = isinf(A);
infMaskB = isinf(B);
if ~isequal(infMaskA, infMaskB)
    tf = false;
    return;
end
if any(infMaskA(:))
    if ~isequal(A(infMaskA), B(infMaskB))
        tf = false;
        return;
    end
end

% Compare only finite, non-NaN elements
validMask = ~(nanMaskA | nanMaskB | infMaskA | infMaskB);
if ~any(validMask(:))
    tf = true;
    return;
end

a = A(validMask);
b = B(validMask);

diffAB = abs(a - b);
scaleAB = max(abs(a), abs(b));
tolAB = max(AbsTol, RelTol .* scaleAB);

tf = all(diffAB <= tolAB);
end