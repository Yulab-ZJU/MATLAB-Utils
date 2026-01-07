function groups = nchoosek(data, nPool, header)
%NCHOOSEK Generate all combinations for multiple pool sizes with optional header.
%
% SYNTAX:
%   groups = mu.nchoosek(data, nPool)
%   groups = mu.nchoosek(data, nPool, header)
%
% INPUT:
%   data   : numeric/logical vector OR cell vector (row/col ok). Elements are the pool.
%   nPool  : scalar or vector of nonnegative integers (e.g., 2 or [2 3]).
%   header : (optional) prefix to prepend to every combination.
%            - If data is numeric/logical: header must be numeric/logical row vector.
%            - If data is cell: header must be a cell row vector.
%
% OUTPUT:
%   groups : N-by-1 cell. Each cell contains one row combination:
%            - numeric/logical data -> 1-by-K numeric row vector (with header if provided)
%            - cell data            -> 1-by-K cell row vector (with header if provided)
%
% NOTES:
%   - Automatically removes duplicate K in nPool and ignores invalid K (<0 or > numel(data)).
%   - For very large combination counts, throws an error before memory blows up.
%
% EXAMPLES:
%   % numeric
%   mu.nchoosek(1:5, 2)
%   mu.nchoosek(1:4, [2 3], [100 200])
%
%   % cell labels
%   labs = {'A','B','C','D'};
%   mu.nchoosek(labs, 2)
%   mu.nchoosek(labs, [1 3], {'Head'})
%
% See also: nchoosek, perms

narginchk(2, 3);

% ---------- Normalize & validate data ----------
if iscell(data)
    data = data(:).';           % row cell
    isCellData = true;
else
    validateattributes(data, {'numeric','logical'}, {'vector'});
    data = data(:).';           % row numeric/logical
    isCellData = false;
end
n = numel(data);

% ---------- Normalize & validate nPool ----------
validateattributes(nPool, {'numeric'}, {'vector','integer','nonnegative'});
nPool = unique(nPool(:).');     % row unique
nPool = nPool(nPool <= n);      % drop invalid K
if isempty(nPool)
    groups = {};
    return;
end

% ---------- Normalize & validate header ----------
if nargin < 3 || isempty(header)
    header = [];
else
    if isCellData
        assert(iscell(header), 'When data is cell, header must be a cell row vector.');
        header = header(:).';
    else
        validateattributes(header, {'numeric','logical'}, {'vector'});
        header = header(:).';
    end
end

% ---------- Pre-check combination counts to avoid OOM ----------
% Simple heuristic hard-cap；如需更大可自行调高
maxCombWarn = 2e7; % 2千万行上限（经验阈值，避免内存炸）
totalRows = 0;
for K = nPool
    totalRows = totalRows + nchoosek(n, K);
    if totalRows > maxCombWarn
        error('mu.nchoosek:TooManyCombinations', ...
            'Total combinations exceed %g. (n=%d, Ks=%s). Consider using smaller Ks or chunked generation.', ...
            maxCombWarn, n, mat2str(nPool));
    end
end

% ---------- Build per-K combinations then concatenate ----------
parts = cell(numel(nPool), 1);
for ii = 1:numel(nPool)
    K = nPool(ii);

    % Work with indices to unify numeric & cell data
    idxK = nchoosek(1:n, K);    % (#comb × K)

    if isCellData
        % Map indices to cell elements -> each row a 1×K cell
        % num2cell over rows of idxK, then per row index into data
        rowIdx = num2cell(idxK, 2);
        combK = cellfun(@(r) data(r), rowIdx, 'UniformOutput', false); % each: 1×K cell row
        if ~isempty(header)
            % header must be cell row
            combK = cellfun(@(row) [header, row], combK, 'UniformOutput', false);
        end
    else
        % Numeric/logical: directly materialize values
        vals = data(idxK); % (#comb × K)
        if isempty(header)
            % 每行转成一个元胞
            combK = mat2cell(vals, ones(size(vals,1),1), size(vals,2));
        else
            % 先拼接 header
            H = repmat(header, size(vals,1), 1);      % (#comb × numel(header))
            allVals = [H, vals];                      % (#comb × (h+K))
            combK = mat2cell(allVals, ones(size(allVals,1),1), size(allVals,2));
        end
    end

    parts{ii} = combK; % (#comb×1) cell
end

% 垂直拼接
groups = vertcat(parts{:});

% 若没有任何组合（可能 Ks 里全是 0 且 header 空? 也会返回一个空行组合）
% 保持与 nchoosek 的一致性：K=0 时返回 1×0（带上 header 后可能为 1×numel(header)）
% 这里无需额外处理

return;
end
