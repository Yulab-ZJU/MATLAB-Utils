function B = slice_N_dim(A, idx, N)
    % Create dynamic indexing: A(:, ..., idx, :, :, ..., :)
    s = repmat({':'}, 1, ndims(A));
    s{N} = idx;
    B = A(s{:});
end