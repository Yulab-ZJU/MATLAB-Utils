function A = cell2mat(C, RecursiveOpt)
%CELL2MAT  Convert cell array to matrix with optional recursive support.
%
% SYNTAX:
%   A = mu.cell2mat(C)             % default RecursiveOpt=false
%   A = mu.cell2mat(C, true/false) % explicitly set recursion
%
% NOTES:
%   - Optimized version using rowfun for consistent behavior.
%   - Supports cell/string/numeric types in input cells.
%   - If RecursiveOpt=false, behaves like cat(1,C{:}) for vectors.

narginchk(1, 2);

validateattributes(C, {'cell'}, {'2d'});

if nargin < 2
    RecursiveOpt = mu.OptionState.Off;
end
RecursiveOpt = mu.OptionState.create(RecursiveOpt).toLogical;

[a, b] = size(C);

% Convert all elements to uniform type first (string handles char/string/cellstr)
C = cellfun(@(x) convertToUniformType(x, RecursiveOpt), C, 'UniformOutput', false);

if ~RecursiveOpt
    % Non-recursive mode, keep behavior simple
    if a == 1 || b == 1
        A = cat(1, C{:});
    else
        temp = cellfun(@(r) cat(2, r{:}), num2cell(C, 2), 'UniformOutput', false);
        A = cat(1, temp{:});
    end
else
    % Recursive mode
    if a == 1 || b == 1 % Handle both row and column vectors
        A = cat(1 + isrow(C), C{:});
    else % Handle 2-D case using rowfun
        % Apply row-wise concatenation
        temp = mu.rowfun(@(x) cat(2, x{:}), C, 'UniformOutput', false);
        % Vertical concatenation of rows
        A = cat(1, temp{:});
    end
end

end

%% Helper function to ensure uniform output type
function y = convertToUniformType(x, RecursiveOpt)
    if ischar(x) || isstring(x)
        y = string(x);
    elseif iscell(x) && RecursiveOpt
        y = convertToUniformType(mu.cell2mat(x, true), true); % Recursive handling
    else
        y = x;
    end
end
