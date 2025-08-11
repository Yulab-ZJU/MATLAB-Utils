function neighbours = mu_prepareNeighboursArray(channels, topoSize, opt)
% [channels]: 1:nch
% [topoSize]: [nX,nY]
% [opt]: 'orthogonal' or 'surrounding' (default='surrounding')

narginchk(2, 3);

if nargin < 3
    opt = "surrounding"; % includes corners
end

if ~strcmpi(opt, "surrounding") && ~strcmpi(opt, "orthogonal")
    error("Invalid option");
end

% neighbours
A0 = reshape(channels, topoSize);
A = padarray(A0, [1, 1], 0);
neighbours = struct("label", cellfun(@(x) num2str(x), num2cell(channels'), 'UniformOutput', false), "neighblabel", cell(numel(A0), 1));
for index = 1:numel(A0)
    [row, col] = find(A == A0(index));
    temp = A(row - 1:row + 1, col - 1:col + 1);
    
    if strcmpi(opt, "orthogonal")
        temp([1, 3, 7, 9]) = 0;
    end

    temp(temp == 0 | temp == A0(index)) = [];

    neighbours(index).neighbch = temp;
    neighbours(index).neighblabel = arrayfun(@num2str, temp, "UniformOutput", false);
end

return;
end