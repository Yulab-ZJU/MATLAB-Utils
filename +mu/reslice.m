function out = reslice(C, dim)
%RESLICE  Reslice a cell array of multi-dimensional arrays along a specified dimension.
%
% SYNTAX:
%     out = mu.reslice(C, dim)
% 
% INPUTS:
%     C    - nt x 1 cell array. Each cell contains an n-dimensional array of the same size.
%     dim  - The dimension along which to reslice the data (an integer between 1 and n).
% 
% OUTPUTS:
%     out  -  ki x 1 cell array, where ki is the size of the `dim`-th dimension.
%             Each output cell contains data of size:
%             [k1, ..., k_{dim-1}, nt, k_{dim+1}, ..., kn],
%             i.e., the `nt` data slices are combined along a new dimension,
%             and the result is sliced along the original `dim`-th dimension.

sz = size(C{1});
nd = ndims(C{1});

if dim < 1 || dim > nd
    error('Invalid dimension dim = %d', dim);
end

% cat cell data
D = cat(nd + 1, C{:});  % size = [sz, nt]

% swap dimension k and dimension nd+1
perm = 1:nd + 1;
perm([dim, nd + 1]) = perm([nd + 1, dim]);
D = permute(D, perm);

out = num2cell(D, 1:nd);
out = reshape(out, [sz(dim), 1]);

return;
end
