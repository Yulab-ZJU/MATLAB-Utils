function res = insertrows(X, rows, val)
%INSERTROWS  Insert rows filled with [val] into 2-D matrix X at specified row indices.
%
% NOTE:
%   Insert vals between rows(i)-1 and rows(i).
%
% INPUTS:
%   REQUIRED:
%     X     - input 2D numeric matrix
%     rows  - vector of row indices at which to insert new rows
%   OPTIONAL:
%     val   - scalar value to fill the inserted rows (default=0)
%
% OUTPUTS:
%     res   - inserted matrix

narginchk(2, 3);
if nargin < 3
    val = 0;
end

validateattributes(val, {'numeric'}, {'scalar'});
validateattributes(X, {'numeric'}, {'2d'});

rows = unique(rows(:))';  % ensure unique sorted row indices
nOrigRows = size(X,1);
nInsert = numel(rows);
nResRows = nOrigRows + nInsert;
nCols = size(X, 2);

% Validate insertion positions
if any(rows < 1) || any(rows > nResRows)
    error('Row indices to insert must be between 1 and %d.', nResRows);
end

res = ones(nResRows, nCols) * val;

% Create logical index vector for insertion rows
insertMask = false(1, nResRows);
insertMask(rows) = true;

% Indices for original rows in output
origIdx = ~insertMask;

% Assign original rows from X to correct positions
res(origIdx, :) = X;

return;
end
