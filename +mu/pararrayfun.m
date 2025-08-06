function varargout = pararrayfun(fcn, varargin)
% PARARRAYFUN - Parallel version of arrayfun using parfor
%
% Usage:
%   Y = mu.pararrayfun(fcn, A)
%   Y = mu.pararrayfun(fcn, A1, A2, ..., 'UniformOutput', true/false, 'ErrorHandler', @errFcn)
%
% Notes:
%   - All input arrays must be the same size (or scalar-expandable)
%   - Supports multiple outputs from fcn
%   - 'UniformOutput' (default true)
%   - 'ErrorHandler' allows user-defined error handling

%% Parse inputs
narginchk(2, inf);

% Detect named parameters
isParam = cellfun(@(x) ischar(x) || (isstring(x) && isscalar(x)), varargin);
paramStart = find(contains(lower(string(varargin(isParam))), ["uniformoutput", "errorhandler"]), 1);
if isempty(paramStart)
    dataArgs = varargin;
    params = {};
else
    paramStartIdx = find(isParam, paramStart);
    dataArgs = varargin(1:paramStartIdx-1);
    params = varargin(paramStartIdx:end);
end

% Defaults
uniformOutput = true;
errorHandler = [];

% Parse named parameters
for i = 1:2:numel(params)
    name = lower(string(params{i}));
    val = params{i+1};
    switch name
        case "uniformoutput"
            uniformOutput = logical(val);
        case "errorhandler"
            errorHandler = val;
        otherwise
            error("Unknown parameter: %s", name);
    end
end

% Validate input sizes (broadcast scalars)
refSize = size(dataArgs{1});
numelData = numel(dataArgs{1});
nInputs = numel(dataArgs);

for i = 2:nInputs
    if ~isequal(size(dataArgs{i}), refSize)
        if isscalar(dataArgs{i})
            % scalar expand
            dataArgs{i} = repmat(dataArgs{i}, refSize);
        else
            error("All input arrays must be the same size or scalar-expandable.");
        end
    end
end

% Preallocate output
nout = nargout;
out = cell(numelData, nout);

%% Parallel loop over linear indices
parfor idx = 1:numelData
    args = cell(1, nInputs);
    for j = 1:nInputs
        args{j} = dataArgs{j}(idx);
    end
    localOut = cell(1, nout);
    try
        [localOut{:}] = fcn(args{:});
    catch err
        if isempty(errorHandler)
            rethrow(err);
        else
            [localOut{:}] = errorHandler(err);
        end
    end
    for k = 1:nout
        out{idx,k} = localOut{k};
    end
end

%% Format output
if uniformOutput
    for k = 1:nout
        try
            varargout{k} = reshape(cell2mat(out(:,k)), refSize);
        catch
            error("Outputs are not uniform. Set 'UniformOutput' to false.");
        end
    end
else
    for k = 1:nout
        varargout{k} = reshape(out(:,k), refSize);
    end
end

return;
end
