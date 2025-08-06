function varargout = parcellfun(fcn, varargin)
% PARCELLFUN - Parallel version of cellfun using parfor
% Usage:
%   Y = mu.parcellfun(fcn, A)
%   Y = mu.parcellfun(fcn, A1, A2, ..., 'UniformOutput', true/false, 'ErrorHandler', @errFcn)
%
% Notes:
%   - Inputs A1, A2, ... must be cell arrays of the same length
%   - Supports multiple outputs
%   - 'UniformOutput' is true by default
%   - 'ErrorHandler' allows handling errors without breaking execution

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
for index = 1:2:numel(params)
    name = lower(string(params{index}));
    val = params{index + 1};
    switch name
        case "uniformoutput"
            uniformOutput = logical(val);
        case "errorhandler"
            errorHandler = val;
        otherwise
            error("Unknown parameter: %s", name);
    end
end

% Validate input lengths
n = numel(dataArgs{1});
for index = 2:numel(dataArgs)
    if numel(dataArgs{index}) ~= n
        error("All input cell arrays must be of the same length.");
    end
end

% Allocate output
nout = nargout;
out = cell(n, nout);

%% Parallel loop
parfor i = 1:n
    args = cell(1, numel(dataArgs));
    for j = 1:numel(dataArgs)
        args{j} = dataArgs{j}{i};
    end

    % init temp output
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
        out{i, k} = localOut{k};
    end
end

%% Post-process output
if uniformOutput
    for k = 1:nout
        try
            varargout{k} = cell2mat(out(:, k));
        catch
            error("Non-uniform outputs. Set 'UniformOutput' to false.");
        end
    end
else
    for k = 1:nout
        varargout{k} = out(:, k);
    end
end

return;
end
