function s = addfield(s, varargin)
%ADDFIELD  Add or update a field in struct array s.
%
% SYNTAX:
%     s = mu.addfield(s, 'fName1', fVal1, 'fName2', fVal2, ...)
%
% INPUTS:
%   REQUIRED:
%     s        - Struct array
%     fName_i  - Field name
%     fVal_i   - [numel(s) x 1] cell array or numeric/logical array with numel(s) rows
%
% OUTPUTS:
%     s        - Struct array
%
% NOTES:
%   - For cell fVal: assign element-wise to each struct.
%   - For numeric matrix fVal: assign row-wise to each struct.

fNames = varargin(1:2:end);
fVals = varargin(2:2:end);

% Validate inputs
assert(isstruct(s), "[s] must be a struct");
cellfun(@mustBeTextScalar, fNames);

if numel(fNames) ~= numel(fVals)
    error("Mismatch name-value pairs");
end

if any(cellfun(@(x) isnumeric(x) || islogical(x), fVals))
    assert(isvector(s), "[s] must be a vector when there is numeric/logical [fVal]");
end

% Standardize field name to char
fNames = cellfun(@char, fNames, "UniformOutput", false);

for fIndex = 1:numel(fNames)
    fName = fNames{fIndex};
    fVal = fVals{fIndex};

    % Validate size of fVal
    if iscell(fVal)
        assert(isequal(size(fVal), size(s)), 'Size of cell [fVal] must equal size of [s].');
    elseif isnumeric(fVal) || islogical(fVal)
        assert(size(fVal, 1) == numel(s), 'Row count of numeric [fVal] must equal number of [s].');
    else
        error('[fVal] must be a cell array or numeric/logical array.');
    end

    s = addfieldImpl(s, fName, fVal);
end

return;
end

%% Impl
function s = addfieldImpl(s, fName, fVal)
    % Assign values without explicit loop
    if iscell(fVal)
        [s.(fName)] = fVal{:};
    else
        % Split numeric matrix rows into comma separated list
        sz = num2cell(size(fVal));
        sz{1} = ones(sz{1}, 1);
        valCell = mat2cell(fVal, sz{:});
        valCell = cellfun(@squeeze, valCell, "UniformOutput", false);
        [s.(fName)] = valCell{:};
    end
    
    return;
end
