function varargout = parrowfun(fcn, A, varargin)
% PARROWFUN - Parallel version of rowfun using parfor
%
% Description:
%   Applies the function handle `fcn` to each row of the input array `A` in parallel.
%   Supports additional inputs with the same number of rows as `A`.
%
% Syntax:
%   C = mu.parrowfun(fcn, A)
%   C = mu.parrowfun(fcn, A, B1, B2, ..., 'UniformOutput', true/false, 'ErrorHandler', @errFcn)
%
% Inputs:
%   fcn          - Function handle to apply to each row
%   A            - An N-by-... array (numeric, cell, or any data type)
%   B1, B2, ...  - Additional inputs, each with same number of rows as A
%   'UniformOutput' (optional) - Logical flag (default true), controls output format
%   'ErrorHandler'  (optional) - Function handle to handle errors during `fcn` execution
%
% Outputs:
%   When 'UniformOutput' is true (default), outputs are returned as arrays
%   When false, outputs are returned as cell arrays
%
% Example:
%   C = parrowfun(@(x) sum(x.^2), A);
%   C = parrowfun(@(x,y) x+y, A, B, 'UniformOutput', false);

%% Input parsing and validation
mIp = inputParser;
mIp.addRequired("fcn", @(x) isa(x,'function_handle'));
mIp.addRequired("A");

% Find indices of optional parameter names 'UniformOutput' or 'ErrorHandler'
idxParam = find(cellfun(@(x) ischar(x) && ...
    any(strcmpi(x, {'UniformOutput','ErrorHandler'})), varargin));

if isempty(idxParam)
    bIdx = 1:numel(varargin);  % All varargin before parameters are data inputs
else
    bIdx = 1:idxParam(1)-1;     % Data inputs before parameter name
end

% Add optional inputs for validation (must have same number of rows as A)
for k = 1:numel(bIdx)
    name = sprintf('B%d', k);
    val = varargin{bIdx(k)};
    assignin('caller', name, val); % Used for inputParser optional inputs
    mIp.addOptional(name, [], @(x) size(x,1) == size(A,1));
end

% Add parameter-value pairs
mIp.addParameter('UniformOutput', true, @(x) isscalar(x) && (islogical(x) || ismember(x,[0 1])));
mIp.addParameter('ErrorHandler', [], @(x) isempty(x) || isa(x,'function_handle'));

% Parse inputs
mIp.parse(fcn, A, varargin{:});
uniform = mIp.Results.UniformOutput;
errorHandler = mIp.Results.ErrorHandler;

%% Convert each row of inputs into cell arrays (for parfor)
nRows = size(A,1);
rowSizes = ones(nRows,1);  % Split exactly by single rows
Ac = mat2cell(A, rowSizes);

% Convert extra inputs to cell arrays, each cell contains one row
vararginReduced = varargin(bIdx);
Bc = cellfun(@(x) mat2cell(x, rowSizes), vararginReduced, 'UniformOutput', false);

% Combine all inputs for each row into a cell array
allInputs = [{Ac}, Bc];

%% Initialize output storage
nout = nargout;  % Number of function outputs
out = cell(nRows, nout);  % Preallocate cell array for outputs

%% Parallel loop over rows
parfor i = 1:nRows
    % Collect inputs for current iteration
    args = cell(1, numel(allInputs));
    for j = 1:numel(allInputs)
        args{j} = allInputs{j}{i};
    end
    
    % Call user function with error handling
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
    
    % Store outputs for this iteration
    for k = 1:nout
        out{i, k} = localOut{k};
    end
end

%% Format outputs based on UniformOutput flag
if uniform
    for k = 1:nout
        try
            varargout{k} = cellfun(@(x) x, out(:,k), 'UniformOutput', true);
        catch
            error('Outputs are not uniform. Consider setting UniformOutput to false.');
        end
    end
else
    for k = 1:nout
        varargout{k} = out(:,k);
    end
end

end
