function locs = findvectorloc(X, pat, direction)
%FINDVECTORLOC  Find location of vector [pat] in vector [X].
%
% SYNTAX:
%     locs = findvectorloc(X, pat)
%     locs = findvectorloc(X, pat, direction)
%
% INPUTS:
%   REQUIRED:
%     X         - data vector (numeric, char, or string)
%     pat       - pattern vector (same type as X)
%   OPTIONAL:
%     direction - "first" (default) or "last"
%
% OUTPUTS:
%     locs      - indices column vector

narginchk(2, 3);

if nargin < 3
    direction = "first";
end

% Validate direction input (case-insensitive)
direction = validatestring(direction, {'first', 'last'});

% Validate inputs are vectors and types match
validateattributes(X, {'numeric', 'char', 'string'}, {'vector'});
validateattributes(pat, {'numeric', 'char', 'string'}, {'vector'});
if ~strcmp(class(pat), class(X))
    error("Input [X] and [pat] must be the same type (number | char | string).");
end

% Ensure row vectors for strfind (avoids unnecessary copy if already row)
if ~isrow(X)
    X = X.';
end
if ~isrow(pat)
    pat = pat.';
end

locs = strfind(X, pat).';

% If direction is 'last', adjust indices accordingly
if direction == "last"
    locs = locs + length(pat) - 1;
end

return;
end
