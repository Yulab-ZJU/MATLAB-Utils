function [B, I] = shuffledata(A, dim)
% SHUFFLEDATA Randomly shuffle data along a specified dimension.
%   B = SHUFFLEDATA(A) shuffles vector A or, for N-D array, shuffles along
%   the first dimension by default. Each slice along other dimensions is
%   independently shuffled.
%
%   B = SHUFFLEDATA(A, DIM) shuffles A along dimension DIM.
%
%   [B, I] = SHUFFLEDATA(...) also returns the index map I such that:
%       B = A(I)
%
%   Examples:
%       shuffledata([1 2 3 4])        % shuffles a vector
%       shuffledata(rand(5, 10), 1)   % shuffles each column
%       shuffledata(rand(5, 10), 2)   % shuffles each row

% Check input
if ~isnumeric(A)
    error('Input A must be numeric.');
end

% Determine shuffle dimension if not provided
if nargin < 2 || isempty(dim)
    if isvector(A)
        dim = find(size(A) > 1, 1);  % preserve orientation
        if isempty(dim), dim = 1; end
    else
        dim = 1;  % default to 1st dimension
    end
end

nd = ndims(A);
if dim < 1 || dim > nd
    error('Specified dimension must be between 1 and ndims(A).');
end

% Early return for trivial case
if isempty(A) || size(A, dim) <= 1
    B = A;
    I = reshape(1:numel(A), size(A));
    return;
end

% Permute target dimension to front
perm = 1:nd;
perm([1, dim]) = [dim, 1];
A_perm = permute(A, perm);
sz_perm = size(A_perm);

len = sz_perm(1);                        % shuffle length
numSlices = prod(sz_perm(2:end));       % number of slices

% Generate shuffle indices
[~, idx] = sort(rand(len, numSlices), 1);  % [len x numSlices]

% Flatten and shuffle
A_flat = reshape(A_perm, len, numSlices);
colIdx = repelem((1:numSlices)', len, 1);
linIdx = sub2ind([len, numSlices], idx(:), colIdx);
B_flat = A_flat(linIdx);
B_perm = reshape(B_flat, sz_perm);

% Inverse permute
B = ipermute(B_perm, perm);

% Return shuffle index map
if nargout > 1
    I = ipermute(reshape(linIdx, sz_perm), perm);
end

return;
end
