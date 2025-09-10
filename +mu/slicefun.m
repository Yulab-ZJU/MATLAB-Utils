function varargout = slicefun(fcn, dim, A, varargin)
%SLICEFUN  Apply [fcn] along the dimension [k] of [A] (based on cellfun).
%
% INPUTS:
%     fcn              - function handle, function to apply to each row
%     dim              - dimension along which [fcn] will be applied
%     A                - a N-D data of any type
%     B1,...,Bn        - same as [A]
%     "UniformOutput"  - true/false (default=true)
%     "ErrorHandler"   - function handle of error
%
% OUTPUTS:
%     When "UniformOutput" is set false, return size(A,1)*1 cell with results of fcn(a,...)
%     When "UniformOutput" is set true, return size(A,1)*1 vector
%
% NOTES:
%   - Inputs can be all data type valid for mat2cell().
%   - Cell arrays can also be segmented by mat2cell().
%
% EXAMPLES:
%     C = mu.slicefun(@mFcn, 2, A, B, "UniformOutput", false);

%% Validation
% Input parser
mIp = inputParser;
mIp.addRequired("fcn", @(x) isa(x, 'function_handle'));
mIp.addRequired("dim", @(x) isnumeric(x) && isscalar(x));
mIp.addRequired("A");
mIp.addParameter("UniformOutput", true, @(x) islogical(x) || isnumeric(x));
mIp.addParameter("ErrorHandler", [], @(x) isempty(x) || isa(x, 'function_handle'));

% Separate B1,...,Bn from Name-Value pairs
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

% Validate Bi size
for i = 1:numel(bArgs)
    Bi = bArgs{i};
    assert(size(Bi, dim) == size(A, dim), ...
        "slicefun:InputSizeMismatch", ...
        "Size mismatch: B%d must match A along dimension %d.", i, dim);
end

% Convert A and Bi to cell slices along dim
sz = size(A);
segLens = ones(sz(dim), 1);
cellSizeVec = num2cell(sz);
cellSizeVec{dim} = segLens;
A_cells = mat2cell(A, cellSizeVec{:});
B_cells = cell(1, numel(bArgs));
for i = 1:numel(bArgs)
    Bi = bArgs{i};
    szB = size(Bi);
    segLensB = ones(szB(dim), 1);
    cellSizeVecB = num2cell(szB);
    cellSizeVecB{dim} = segLensB;
    B_cells{i} = mat2cell(Bi, cellSizeVecB{:});
end

% Apply function
if isempty(mIp.Results.ErrorHandler)
    [varargout{1:nargout}] = cellfun(fcn, A_cells, B_cells{:}, ...
                                     "UniformOutput", mIp.Results.UniformOutput);
else
    [varargout{1:nargout}] = cellfun(fcn, A_cells, B_cells{:}, ...
                                     "UniformOutput", mIp.Results.UniformOutput, ...
                                     "ErrorHandler", mIp.Results.ErrorHandler);
end

return;
end
