function A = slicedata(A, dim, idx)
% Create dynamic indexing: A(:, ..., idx, :, :, ..., :)
s = repmat({':'}, 1, ndims(A));
s{dim} = idx;
A = A(s{:});
return;
end