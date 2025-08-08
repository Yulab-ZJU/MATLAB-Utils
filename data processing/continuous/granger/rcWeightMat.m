function W = rcWeightMat(topoSize)
    % This function builds contiguity weights matrix for map [X].
    % Input [topoSize] specifies [nX,nY] for your topo map [X].
    % Output [W] is a nchan-by-nchan matrix with each row W(i,:) as a vectorized
    % weight matrix for element X(i), where nchan=prod(sz).

    if numel(topoSize) ~= 2
        error("Topo size should be specified as a vector of [nX,nY].");
    end

    % convert [nX,nY] to [nRows,nCols]
    sz = flip(topoSize);

    % initialize
    nchan = prod(sz);
    W = zeros(nchan, nchan);

    % loop for each point on the map
    for cIndex = 1:nchan
        temp = zeros(sz);
        [row, col] = ind2sub(sz, cIndex);

        neighborIdx = [row,     col - 1; ...
                       row,     col + 1; ...
                       row - 1, col    ; ...
                       row + 1, col    ];
        neighborIdx = neighborIdx(all(neighborIdx > 0 & neighborIdx(:, 1) < sz(1) & neighborIdx(:, 2) < sz(2), 2), :);
        for nIndex = 1:size(neighborIdx, 1)
            temp(neighborIdx(nIndex, 1), neighborIdx(nIndex, 2)) = 1;
        end

        neighborIdx = [row - 1, col - 1; ...
                       row - 1, col + 1; ...
                       row + 1, col - 1; ...
                       row + 1, col + 1];
        neighborIdx = neighborIdx(all(neighborIdx > 0 & neighborIdx(:, 1) < sz(1) & neighborIdx(:, 2) < sz(2), 2), :);
        for nIndex = 1:size(neighborIdx, 1)
            temp(neighborIdx(nIndex, 1), neighborIdx(nIndex, 2)) = 0.5;
        end

        temp = temp';
        W(cIndex, :) = temp(:);
    end
    
    return;
end