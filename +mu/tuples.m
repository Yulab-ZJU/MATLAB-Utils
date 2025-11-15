function res = tuples(v, k, sortCol)
%TUPLES Generate all possible k-tuples over the vector v (N^k-by-k).
%
%   res = tuples(v, k)
%   res = tuples(v, k, sortCol)
%
% DESCRIPTION
%   This function returns a matrix containing all possible ordered k-tuples
%   constructed from the elements of vector v. If v has N elements, the total
%   number of possible k-tuples is N^k. The output is an N^k-by-k matrix where
%   each row corresponds to one k-tuple.
%
% INPUT
%   v        : A vector of symbols (numeric, char, or any indexable dtype).
%   k        : The length of each tuple (positive integer).
%   sortCol  : (optional) Determines how the tuples are ordered:
%              "first"  - The first column changes slowest (default).
%              "last"   - The first column changes fastest.
%
%              In other words:
%              * "first" gives lexicographic order on columns left→right.
%              * "last"  gives lexicographic order on columns right→left.
%
% OUTPUT
%   res      : A matrix of size (N^k)-by-k, containing all k-tuples using
%              elements from v.
%
% EXAMPLES
%   v = 1:3; k = 2;
%   mu.tuples(v, k, "first")
%
%   ans =
%        1     1
%        1     2
%        1     3
%        2     1
%        2     2
%        2     3
%        3     1
%        3     2
%        3     3
%
%   mu.tuples(v, k, "last")
%
%   ans =
%        1     1
%        2     1
%        3     1
%        1     2
%        2     2
%        3     2
%        1     3
%        2     3
%        3     3
%
% NOTES
%   - This implementation uses direct base-N expansion and is significantly
%     faster and more memory-efficient than ind2sub-based approaches.
%   - The output ordering is exact and reproducible.
%
% -------------------------------------------------------------------------

narginchk(2, 3);
if nargin < 3
    sortCol = "first";
end
sortCol = validatestring(sortCol, {'first', 'last'});

% Ensure v is a column vector
v = v(:);
n = numel(v);

% Validate k
if ~(isscalar(k) && k > 0 && k == floor(k))
    error('k must be a positive integer.');
end

% Number of total tuples
N = n^k;

% Preallocate index matrix (each entry in 0..n-1)
idxMat = zeros(N, k);

% Construct linear index vector 0..N-1
x = (0:N-1).';

% Fill index matrix by base-n digit extraction
% Highest place is the first column (left-most)
for col = k:-1:1
    idxMat(:, col) = mod(x, n);
    x = floor(x / n);
end

% Reorder columns depending on requested sorting style
if strcmpi(sortCol, "last")
    idxMat = fliplr(idxMat);
end

% Convert 0-based indices to 1-based, then map to v
idxMat = idxMat + 1;
res = v(idxMat);

return;
end
