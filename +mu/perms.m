function res = perms(v, k, sortCol)
%PREMS  Return a N^k-by-k matrix containing all possible permutations of k-element 
%       for vector [v], where N=numel(v).
% If [sortCol] is set "first", [res] is sorted ascend according to the first column.
% If [sortCol] is set "last", [res] is sorted ascend according to the last column.
% 
% EXAMPLES:
%     v = 1:10;
%     k = 3;
%     cmb = mu.perms(v, k, "first")
%     >> cmb = [1, 1, 1
%               1, 1, 2
%               1, 1, 3
%               ...
%               5, 2, 1
%               5, 2, 2
%               5, 2, 3
%               ...
%               10, 10, 9
%               10, 10, 10]

narginchk(2, 3);

if nargin < 3
    sortCol = "first";
end

v = v(:);
res = cell(k, 1);
[res{:}] = ind2sub(repmat(numel(v), 1, k), 1:numel(v) ^ k);
res = cell2mat(res)';
if strcmpi(sortCol, "first")
    res = fliplr(res);
elseif strcmpi(sortCol, "last")
    % do nothing
else
    error("Invalid order");
end
res = v(res);

return;
end