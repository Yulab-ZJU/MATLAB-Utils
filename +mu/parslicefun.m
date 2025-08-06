function varargout = parslicefun(fcn, dim, A, varargin)
% parslicefun - Parallel version of mu.slicefun using parfor
% Description:
%     Applies function fcn to slices of A along dimension dim in parallel.
%     Supports multiple input arrays and optional error handling.
%
% Inputs:
%     fcn - Function handle to apply
%     dim - Dimension to slice
%     A - Input array
%     varargin - Additional arrays and optional Name-Value pairs:
%         'UniformOutput' - (default: true)
%         'ErrorHandler'  - function handle to use when error occurs
%
% Outputs:
%     varargout - Outputs of the function, either cell array or regular array

%% Input parsing
mIp = inputParser;
mIp.addRequired("fcn", @(x) isa(x, 'function_handle'));
mIp.addRequired("dim", @(x) isnumeric(x) && isscalar(x));
mIp.addRequired("A");
mIp.addParameter("UniformOutput", true, @(x) islogical(x) || isnumeric(x));
mIp.addParameter("ErrorHandler", [], @(x) isempty(x) || isa(x, 'function_handle'));

% Split varargin into data and params
isParamName = @(x) ischar(x) || isstring(x);
splitIdx = find(cellfun(@(x) isParamName(x) && any(strcmpi(x, ["UniformOutput", "ErrorHandler"])), varargin), 1);
if isempty(splitIdx)
    bArgs = varargin;
    paramArgs = {};
else
    bArgs = varargin(1:splitIdx-1);
    paramArgs = varargin(splitIdx:end);
end

mIp.parse(fcn, dim, A, paramArgs{:});
UniformOutput = mIp.Results.UniformOutput;
ErrorHandler = mIp.Results.ErrorHandler;

%% Validate B sizes
for i = 1:numel(bArgs)
    assert(size(bArgs{i}, dim) == size(A, dim), ...
        "parslicefun:InputSizeMismatch", ...
        "Size mismatch: B%d must match A along dimension %d.", i, dim);
end

%% Prepare slicing
sz = size(A);
segN = sz(dim);
idx = repmat({':'}, 1, ndims(A));
A_cells = cell(segN, 1);
for k = 1:segN
    idx{dim} = k;
    A_cells{k} = A(idx{:});
end

B_cells_all = cell(numel(bArgs), 1);
for i = 1:numel(bArgs)
    Bi = bArgs{i};
    Bi_cells = cell(segN, 1);
    for k = 1:segN
        idx{dim} = k;
        Bi_cells{k} = Bi(idx{:});
    end
    B_cells_all{i} = Bi_cells;
end

%% Parallel computation
result = cell(segN, 1);
if isempty(ErrorHandler)
    parfor k = 1:segN
        args = cellfun(@(C) C{k}, B_cells_all, 'UniformOutput', false);
        result{k} = fcn(A_cells{k}, args{:});
    end
else
    parfor k = 1:segN
        try
            args = cellfun(@(C) C{k}, B_cells_all, 'UniformOutput', false);
            result{k} = fcn(A_cells{k}, args{:});
        catch err
            result{k} = ErrorHandler(err);  % ignore index for compatibility
        end
    end
end

%% Format output
if UniformOutput
    try
        varargout{1} = cell2mat(result);
    catch
        error("parslicefun:OutputConversion", ...
            "Cannot convert cell output to matrix. Set 'UniformOutput' to false.");
    end
else
    varargout{1} = result;
end

return;
end
