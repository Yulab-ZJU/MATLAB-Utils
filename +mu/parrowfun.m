function varargout = parrowfun(fcn, varargin)
% PARROWFUN - Parallel mu.rowfun with block-wise processing
%
% Syntax:
%   Y = mu.parrowfun(fcn, A1, A2, ..., 'UniformOutput', true/false, 'BlockSize', N, 'ErrorHandler', @eh)
%
% Inputs:
%   fcn             - Function handle to apply to each group of elements
%   A1, A2, ...     - Arrays of same size
%   'UniformOutput' (optional) - logical (default: true)
%   'BlockSize'     (optional) - scalar int, elements per block (default: auto)
%   'ErrorHandler'  (optional) - function handle @(err) to catch errors
%
% Outputs:
%   varargout       - Same as mu.rowfun output

% ---------------- Separate cell inputs ----------------
isParam = cellfun(@(x) ischar(x) || isstring(x), varargin);
paramIdx = find(isParam, 1, 'first');
if isempty(paramIdx)
    Ainputs = varargin;
    params = {};
else
    Ainputs = varargin(1:paramIdx - 1);
    params = varargin(paramIdx:end);
end

% ---------------- Parse optional arguments ----------------
mIp = inputParser;
mIp.addParameter("UniformOutput", true, @(x) islogical(x) || isnumeric(x));
mIp.addParameter("ErrorHandler", [], @(x) isempty(x) || isa(x, 'function_handle'));
mIp.addParameter("BlockSize", [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
mIp.parse(params{:});
uniformOutput = mIp.Results.UniformOutput;
blockSize = mIp.Results.BlockSize;
errorHandler = mIp.Results.ErrorHandler;

% ---------------- Check input sizes ----------------
sz = cellfun(@(x) size(x, 1), Ainputs);
if ~all(sz == sz(1))
    error('All array inputs must have the same size of the first dimension.');
end
nRows = sz(1);

% ---------------- Determine block size ----------------
if isempty(blockSize)
    pool = gcp('nocreate');
    nWorkers = isempty(pool) * 0 + (~isempty(pool) * pool.NumWorkers);
    blockSize = max(1, ceil(nRows / max(nWorkers, 1)));
end
nBlocks = ceil(nRows / blockSize);

% ---------------- Preallocate output ----------------
nout = nargout;
outCell = cell(nBlocks, nout);

% ---------------- Parallel block loop ----------------
parfor bIndex = 1:nBlocks
    % Slice inputs for this block
    startIdx = (bIndex - 1) * blockSize + 1;
    endIdx = min(bIndex * blockSize, nRows);
    idx = startIdx:endIdx;
    slicedInputs = cellfun(@(a) slice_N_dim(a, idx, 1), Ainputs, 'UniformOutput', false);

    % Apply function
    if ~isempty(errorHandler)
        [outCell{bIndex, 1:nout}] = mu.rowfun(fcn, slicedInputs{:}, 'UniformOutput', false, 'ErrorHandler', errorHandler);
    else
        [outCell{bIndex, 1:nout}] = mu.rowfun(fcn, slicedInputs{:}, 'UniformOutput', false);
    end

end

% ---------------- Concatenate or collect output ----------------
for k = 1:nout
    % Flatten all block outputs into a column vector
    outVec = vertcat(outCell{:, k});

    if uniformOutput
        % Attempt to concatenate the content of each cell into numeric array
        % Each element of outVec should be scalar or compatible
        varargout{k} = cellfun(@(x) x, outVec, 'UniformOutput', true);
    else
        % Always return as cell array with original shape
        varargout{k} = outVec;
    end
end

return;
end