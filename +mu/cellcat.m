function A = cellcat(dim, C)
%CELLCAT  Concatenate cell array along specified dimension
arguments
    dim (1,1) {mustBeInteger, mustBePositive}
    C cell
end
A = cat(dim, C{:});
end