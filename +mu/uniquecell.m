function [uniqueCA, idx] = uniquecell(cellRaw, varargin)
%UNIQUECELL  Unique sets & set filtering (simple / largest set / minimum set)
%
% SYNTAX:
%   [uniqueCA, idx] = mu.uniquecell(cellRaw)
%   [uniqueCA, idx] = mu.uniquecell(cellRaw, TYPE)
%
% INPUT:
%   cellRaw : cell array, each cell is a numeric vector (row/col ok).
%   TYPE    : "simple" (default) | "largest set" | "minimum set"
%             - "simple": unique sets ignoring order & duplicates inside a set
%             - "largest set": keep sets that are NOT a proper subset of any other
%             - "minimum set": keep sets that do NOT strictly contain any other
%
% OUTPUT:
%   uniqueCA : cell array of row vectors (sorted ascending, unique within each set)
%   idx      : column vector of indices (1-based) into cellRaw(:) for representative sets
%
% NOTES:
%   - Each set is canonicalized: make row, drop NaN duplicates (keep single NaN), unique & sort.
%   - Floating numbers are keyed with '%.15g' to avoid precision pitfalls but keep speed.
%   - Stable: preserves the first occurrence as representative.
%
% EXAMPLES:
%   C = { [3 2 2 1], [1 2 3], [2], [2 3 4], [3 4], [], [NaN NaN 1], [1 NaN] };
%   [U, I] = mu.uniquecell(C, "simple");
%   [Umax, Imax] = mu.uniquecell(C, "largest set");
%   [Umin, Imin] = mu.uniquecell(C, "minimum set");

% ---------- Parse inputs ----------
mIp = inputParser;
mIp.addRequired("cellRaw", @(x) iscell(x));
mIp.addOptional("type", "simple", @(x) any(validatestring(x, {'simple', 'largest set', 'minimum set'})));
mIp.parse(cellRaw, varargin{:});
type = validatestring(mIp.Results.type, {'simple', 'largest set', 'minimum set'});

% ---------- Canonicalize each set ----------
%  - numeric; allow empty; allow NaN (keep single NaN)
A = cellRaw(:);
n = numel(A);
canon = cell(n,1);
for i = 1:n
    v = A{i};
    if isempty(v)
        canon{i} = zeros(1,0); % empty row
        continue;
    end
    validateattributes(v, {'numeric'}, {'vector'}, mfilename, 'cellRaw{i}');
    v = v(:)';                      % row
    v = unique(v, 'stable');        % drop duplicates (preserve one NaN if present)
    % sort with NaN last to keep key稳定（也可把NaN当作最大）
    % MATLAB sort将NaN放到末尾（默认），正合需要
    v = sort(v, 'ascend');
    canon{i} = v;
end

% ---------- Build stable keys for uniqueness ----------
% 键：使用 '%.15g' 并以逗号连接；空集=>空字符串
keys = cell(n,1);
for i = 1:n
    v = canon{i};
    if isempty(v)
        keys{i} = '';  %#ok<*AGROW>
    else
        % 将 NaN 转成字面 'NaN'，保持确定性
        % num2str 对 NaN 也会给 'NaN'；用 arrayfun 保证逐元素
        parts = arrayfun(@(x) sprintf('%.15g', x), v, 'UniformOutput', false);
        % 对 NaN，sprintf('%.15g', NaN) 返回 'nan'（低版本可能如此） -> 规范成 'NaN'
        for k = 1:numel(parts)
            if any(strcmpi(parts{k}, {'nan', '+nan', '-nan'}))
                parts{k} = 'NaN';
            end
        end
        keys{i} = strjoin(parts, ',');
    end
end

% ---------- Unique by key (stable representative) ----------
[uqKeys, ia, ~] = unique(keys, 'stable');
uniqueCA = canon(ia);  % representative sets
idx = ia(:);           % indices into original cellRaw(:)

if strcmp(type, 'simple')
    % 简单模式，直接返回
    return;
end

% ---------- Build membership matrix for set relations ----------
% Universe of elements（含 NaN 作为独立标签）
% 处理 NaN：把 NaN 映射到一个专门的桶（不会与任何数值相等）
U = unique([uniqueCA{:}]);   % this keeps NaN if present
% 将 NaN 单独提取
hasNaN = any(isnan(U));
if hasNaN
    Unum = U(~isnan(U));
    UhasNaN = true;
else
    Unum = U;
    UhasNaN = false;
end
mElem = numel(Unum) + double(UhasNaN);

% 元素 -> 列索引映射（数值用 containers.Map，NaN占最后一列）
if ~isempty(Unum)
    keyNum = arrayfun(@(x) sprintf('%.15g', x), Unum, 'UniformOutput', false);
    map = containers.Map(keyNum, num2cell(1:numel(Unum)));
else
    map = containers.Map('KeyType','char','ValueType','any');
end
if UhasNaN
    nanCol = numel(Unum) + 1;
else
    nanCol = [];
end

% nSet × mElem 的逻辑矩阵
nSet = numel(uniqueCA);
M = false(nSet, mElem);
for i = 1:nSet
    v = uniqueCA{i};
    if isempty(v), continue; end
    isN = isnan(v);
    if any(~isN)
        parts = arrayfun(@(x) sprintf('%.15g', x), v(~isN), 'UniformOutput', false);
        cols = cellfun(@(k) map(k), parts);
        M(i, cols) = true;
    end
    if any(isN)
        M(i, nanCol) = true;
    end
end

% ---------- Inclusion comparisons ----------
% 对每个 i，与所有 j 比较：
%   i ⊆ j  <=>  ~( M(i,:) & ~M(j,:) ) 对所有列都为 true
% 向量化实现：对固定 i，conflict = bsxfun(@and, M(i,:), ~M);   % nSet×mElem
% subsetIJ = all(~conflict, 2);                                  % nSet×1
% equalIJ  = all(bsxfun(@eq, M(i,:), M), 2);                     % nSet×1
%  - largest set:  ~any( subsetIJ & ~equalIJ )
%  - minimum set:  ~any( subsetJI & ~equalJI )，其中 subsetJI 需基于 j⊆i，即把角色换位

isLargest = true(nSet,1);
isMinimum = true(nSet,1);

for i = 1:nSet
    % i ⊆ j ?
    conflict_ij = bsxfun(@and, M(i,:), ~M);         % nSet×mElem
    subset_ij = all(~conflict_ij, 2);               % nSet×1
    equal_ij  = all(bsxfun(@eq, M(i,:), M), 2);     % nSet×1

    % j ⊆ i ?  (角色互换：对每个 j，检查 j 的行与 i 的行)
    conflict_ji = bsxfun(@and, M, ~M(i,:));         % nSet×mElem
    subset_ji = all(~conflict_ji, 2);               % nSet×1
    equal_ji  = all(bsxfun(@eq, M, M(i,:)), 2);     % nSet×1

    % 存在 j 使得 i ⊂ j ？
    hasProperSuperset = any(subset_ij & ~equal_ij);
    % 存在 j 使得 j ⊂ i ？
    hasProperSubset   = any(subset_ji & ~equal_ji);

    if hasProperSuperset
        isLargest(i) = false;
    end
    if hasProperSubset
        isMinimum(i) = false;
    end
end

switch type
    case 'largest set'
        keep = isLargest;
    case 'minimum set'
        keep = isMinimum;
    otherwise
        keep = true(size(isLargest));
end

uniqueCA = uniqueCA(keep);
idx      = idx(keep);

return;
end
