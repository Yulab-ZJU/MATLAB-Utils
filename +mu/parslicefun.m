function varargout = parslicefun(fcn, dim, varargin)
% PARSLICEFUN - Parallel mu.slicefun with block-wise processing
%
% Syntax:
%   Y = mu.parslicefun(fcn, A1, A2, ..., 'UniformOutput', true/false, 'BlockSize', N, 'ErrorHandler', @eh)
%
% Inputs:
%   fcn             - Function handle to apply to each group of elements
%   A1, A2, ...     - Arrays of same size
%   'UniformOutput' (optional) - logical (default: true)
%   'BlockSize'     (optional) - scalar int, elements per block (default: auto)
%   'ErrorHandler'  (optional) - function handle @(err) to catch errors
%
% Outputs:
%   varargout       - Same as mu.slicefun output

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
mIp.addRequired("dim", @(x) validateattributes(x, 'numeric', {'integer', 'scalar', 'positive'}));
mIp.addParameter("UniformOutput", true, @(x) islogical(x) || isnumeric(x));
mIp.addParameter("ErrorHandler", [], @(x) isempty(x) || isa(x, 'function_handle'));
mIp.addParameter("BlockSize", [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
mIp.parse(dim, params{:});
uniformOutput = mIp.Results.UniformOutput;
blockSize = mIp.Results.BlockSize;
errorHandler = mIp.Results.ErrorHandler;

% ---------------- Check input sizes ----------------
sz = cellfun(@(x) size(x, dim), Ainputs);
if ~all(sz == sz(1))
    error('All array inputs must have the same size of the %d-th dimension.', dim);
end
nDimSize = sz(1);

% ---------------- Determine block size ----------------
if isempty(blockSize)
    pool = gcp('nocreate');
    if ~isempty(pool)
        nWorkers = isempty(pool) * 0 + (~isempty(pool) * pool.NumWorkers);
    else
        nWorkers = parcluster('local').NumWorkers;
    end
    blockSize = max(1, ceil(nDimSize / max(nWorkers, 1)));
end
nBlocks = ceil(nDimSize / blockSize);

% ---------------- Preallocate output ----------------
nout = nargout;
outCell = cell(nBlocks, nout);

% ---------------- Parallel block loop ----------------
for bIndex = 1:nBlocks
    % Slice inputs for this block
    startIdx = (bIndex - 1) * blockSize + 1;
    endIdx = min(bIndex * blockSize, nDimSize);
    idx = startIdx:endIdx;
    slicedInputs = cellfun(@(a) mu.slicemat(a, idx, dim), Ainputs, 'UniformOutput', false);

    % Apply function
    if ~isempty(errorHandler)
        [outCell{bIndex, 1:nout}] = mu.slicefun(fcn, dim, slicedInputs{:}, 'UniformOutput', false, 'ErrorHandler', errorHandler);
    else
        [outCell{bIndex, 1:nout}] = mu.slicefun(fcn, dim, slicedInputs{:}, 'UniformOutput', false);
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