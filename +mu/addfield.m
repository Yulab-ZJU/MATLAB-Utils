function s = addfield(s, fName, fVal)
% ADDFIELD Add or update a field in struct array s
%
% s: struct array (vector)
% fName: field name (char vector, string scalar, or 1x1 cellstr)
% fVal: cell array with numel(s) elements or numeric matrix with size(s,1) rows
%
% For cell fVal: assign element-wise to each struct.
% For numeric matrix fVal: assign row-wise to each struct.

arguments
    s (1,:) struct
    fName {mustBeTextScalar}
    fVal {mustBeNonempty}
end

n = numel(s);

% Standardize field name to char
if iscell(fName)
    fName = fName{1};
elseif isstring(fName)
    fName = char(fName);
end

% Validate size of fVal
if iscell(fVal)
    assert(numel(fVal) == n, 'Length of cell fVal must equal number of structs.');
elseif isnumeric(fVal)
    assert(size(fVal,1) == n, 'Row count of numeric fVal must equal number of structs.');
else
    error('fVal must be a cell array or numeric matrix.');
end

% Assign values without explicit loop
if iscell(fVal)
    [s.(fName)] = fVal{:};
else
    % Split numeric matrix rows into comma separated list
    valCell = mat2cell(fVal, ones(1,n), size(fVal,2));
    [s.(fName)] = valCell{:};
end

return;
end
