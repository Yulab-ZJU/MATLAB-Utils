function A = cell2mat(C)
% CELL2MAT Convert cell array to matrix with support for mixed types
%   Supports cell/string/numeric types in input cells
%   Optimized version using rowfun for consistent behavior

[a, b] = size(C);

% Convert all elements to uniform type first (string handles char/string/cellstr)
C = cellfun(@(x) convertToUniformType(x), C, 'UniformOutput', false);

if a == 1 || b == 1 % Handle both row and column vectors
    A = cat(1 + isrow(C), C{:});
else % Handle 2-D case using rowfun
    % Apply row-wise concatenation
    temp = mu.rowfun(@(x) cat(2, x{:}), C, 'UniformOutput', false);
    
    % Vertical concatenation of rows
    A = cat(1, temp{:});
end
end

%% Helper function to ensure uniform output type
function y = convertToUniformType(x)
    if ischar(x) || isstring(x)
        y = string(x);
    elseif iscell(x)
        y = convertToUniformType(cell2mat(x)); % Recursive handling of nested cells
    else
        y = x;
    end
end