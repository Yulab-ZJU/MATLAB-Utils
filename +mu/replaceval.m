function res = replaceval(x, newVal, conditions)
%REPLACEVAL  Replace [x] with newVal if [x] is in [conditions] or satisfies conditions(x).
%
% INPUTS:
%     x           - input of any kind.
%     newVal      - value to replace with.
%     conditions  - can be:
%         1. numeric scalar/vector/matrix: 1, [1,2,3], [1,2;3,4]
%         2. string scalar/vector/matrix: "a", ["a","b"], ["a","b";"c","d"]
%         3. char: 'a', ['a';'b']
%         4. function_handle: @isinteger, @(x) x>0
%         5. cell array composed of the above types: {1,2,3}, {"a","b"}, {@(x) x>0, @(x) mod(x,2)==0}
%         6. multi-class cell array: {1, @(x) x<0}
%
% OUTPUTS:
%     res  - return [newVal] if the input [x] meets any of the [conditions], 
%            or return [x] if no condition is satisfied.
%
% NOTES:
%   - Each element is treated independently in numeric/string comparison.
%   - For a overall comparison between vectors/matrices, use cell as input instead.
%   - Among different conditions, the logical computation would be "or".
%
% EXAMPLES:
%     X = [-2, -1, 0, 1, 2];
%     A = {"a", 1, 2, "b"};
%
%     % Replace X(i) with 100 if X(i) is negative or even
%     Y1 = arrayfun(@(x) mu.replaceval(x, 100, {@(t) t<0, @(t) mod(t,2)==0}), X)
%
%     % Replace X(i) with 100 if X(i) is in [-3, -2, -1]
%     Y2 = arrayfun(@(x) mu.replaceval(x, 100, [-3, -2, -1]), X)
%     Y2_1 = arrayfun(@(x) mu.replaceval(x, 100, {-3, -2, -1}), X)
%
%     % Replace X(i) with 100 if X(i) equals 1 or is even
%     Y3 = arrayfun(@(x) mu.replaceval(x, 100, {1, @(t) mod(t,2)==0}), X)
%
%     % Replace A{i} with 100 if A{i} is a letter
%     B = cellfun(@(x) mu.replaceval(x, 100, @isletter), A, "uni", false)
%
%     >> Y1 = [100, 100, 100, 1, 100]
%     >> Y2 = [100, 100, 0, 1, 2]
%     >> Y2_1 = [100, 100, 0, 1, 2]
%     >> Y3 = [100, -1, 100, 100, 100]
%     >> B = {100, 1, 2, 100}

narginchk(2, 3);

if nargin < 3
    conditions = [];
end

if isnumeric(conditions)
    conditions = num2cell(conditions(:), 2);
elseif isa(conditions, "function_handle")
    conditions = {conditions};
elseif ischar(conditions) || isstring(conditions)
    conditions = cellstr(conditions);
elseif iscell(conditions)
    % do nothing
else
    error("Invalid conditions input");
end

% vectorize
conditions = conditions(:);

% find function_handle in conditions
idx = cellfun(@(y) isa(y, "function_handle"), conditions);

% replace value
if any(cell2mat(cellfun(@(y) y(x), conditions(idx), "UniformOutput", false))) || any(cellfun(@(y) isequal(x, y), conditions(~idx)))
    res = newVal;
else
    res = x;
end

return;
end