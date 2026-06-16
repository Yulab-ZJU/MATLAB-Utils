function out = reslice(C, dim)
%RESLICE Reslice equally sized arrays stored in a cell array.
%
% SYNTAX:
%     out = mu.reslice(C, dim)
%
% INPUTS:
%     C
%         Cell array containing equally sized numeric or logical arrays.
%         Cell-array shape is unrestricted; elements are processed in
%         MATLAB linear-index order:
%
%             C{1}, C{2}, ..., C{nt}
%
%         Each element has size:
%
%             [k1, k2, ..., kn]
%
%     dim
%         Positive integer scalar specifying the array dimension to reslice.
%         dim must not exceed the effective number of dimensions of the
%         arrays.
%
% OUTPUTS:
%     out
%         kdim-by-1 cell array.
%
%         The i-th output cell contains the i-th slice from every input
%         array, concatenated along dimension dim. Its size is:
%
%             [k1, ..., k(dim-1), nt, k(dim+1), ..., kn]
%
% EXAMPLE:
%     C = {
%         rand(3, 4)
%         rand(3, 4)
%         rand(3, 4)
%     };
%
%     out = mu.reslice(C, 2);
%
%     % numel(out) = 4
%     % size(out{1}) = [3, 3]
%     % Dimension 2 now represents trials.
%
% NOTES:
%     This implementation uses cat, permute, and num2cell. It is concise
%     and generally fast, but may require several full-size temporary
%     arrays for large datasets.

%% Validate inputs

if ~iscell(C)
    error("mu:reslice:InvalidInput", ...
        "C must be a cell array.");
end

if isempty(C)
    error("mu:reslice:EmptyInput", ...
        "C must contain at least one array.");
end

validateattributes(dim, "numeric", ...
    {"scalar", "real", "finite", "positive", "integer"}, ...
    mfilename, "dim");

C = C(:);
nTrial = numel(C);

isValidArray = cellfun(@(x) isnumeric(x) || islogical(x), C);

if ~all(isValidArray)
    badIndex = find(~isValidArray, 1);

    error("mu:reslice:InvalidCellContent", ...
        "C{%d} is not a numeric or logical array.", badIndex);
end

%% Determine and validate array sizes

nd = ndims(C{1});

if dim > nd
    error("mu:reslice:InvalidDimension", ...
        "dim=%d exceeds the effective number of dimensions (%d).", ...
        dim, nd);
end

sizeMat = ones(nTrial, nd);

for k = 1:nTrial
    thisSize = size(C{k});
    sizeMat(k, 1:numel(thisSize)) = thisSize;
end

referenceSize = sizeMat(1, :);

mismatchIndex = find( ...
    any(sizeMat ~= referenceSize, 2), ...
    1);

if ~isempty(mismatchIndex)
    error("mu:reslice:SizeMismatch", ...
        "C{%d} has size [%s], whereas C{1} has size [%s].", ...
        mismatchIndex, ...
        num2str(sizeMat(mismatchIndex, :)), ...
        num2str(referenceSize));
end

%% Concatenate input arrays along a new trial dimension

trialDim = nd + 1;

% Before concatenation:
%     C{k}: [k1, ..., kdim, ..., kn]
%
% After concatenation:
%     D:    [k1, ..., kdim, ..., kn, nTrial]
D = cat(trialDim, C{:});

%% Exchange the selected dimension with the trial dimension

permOrder = 1:trialDim;
permOrder([dim, trialDim]) = permOrder([trialDim, dim]);

% After permutation:
%     D: [k1, ..., nTrial, ..., kn, kdim]
D = permute(D, permOrder);

%% Split the original selected dimension into output cells

% Dimensions 1:nd are retained inside each cell.
% The remaining dimension, trialDim, becomes the cell-array dimension.
out = num2cell(D, 1:nd);

% Return a predictable column cell array.
out = reshape(out, referenceSize(dim), 1);

end