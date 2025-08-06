function varargout = parcellfun(fcn, varargin)
% PARCELLFUN - Parallel cellfun with block-wise processing
%
% Syntax:
%   Y = mu.parcellfun(fcn, C1, C2, ..., 'UniformOutput', true/false, 'BlockSize', N, 'ErrorHandler', @eh)
%
% Inputs:
%   fcn             - Function handle to apply to each group of elements
%   C1, C2, ...     - Cell arrays of same size
%   'UniformOutput' (optional) - logical (default: false)
%   'BlockSize'     (optional) - scalar int, elements per block (default: auto)
%   'ErrorHandler'  (optional) - function handle @(err, idx) to catch errors
%
% Outputs:
%   varargout       - Same as cellfun output

% ---------------- Separate cell inputs ----------------
isParam = cellfun(@(x) ischar(x) || isstring(x), varargin);
paramIdx = find(isParam, 1, 'first');
if isempty(paramIdx)
    Cinputs = varargin;
    params = {};
else
    Cinputs = varargin(1:paramIdx - 1);
    params = varargin(paramIdx:end);
end

% ---------------- Parse optional arguments ----------------
mIp = inputParser;
mIp.addParameter("UniformOutput", false, @(x) islogical(x) || isnumeric(x));
mIp.addParameter("ErrorHandler", [], @(x) isempty(x) || isa(x, 'function_handle'));
mIp.addParameter("BlockSize", [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
mIp.parse(params{:});
uniformOutput = mIp.Results.UniformOutput;
blockSize = mIp.Results.BlockSize;
errorHandler = mIp.Results.ErrorHandler;

% ---------------- Check input sizes ----------------
sz = cellfun(@size, Cinputs, "UniformOutput", false);

N = numel(Cinputs{1});
for k = 2:numel(Cinputs)
    if numel(Cinputs{k}) ~= N
        error('All cell inputs must have the same number of elements.');
    end
end

% ---------------- Determine block size ----------------
if isempty(blockSize)
    pool = gcp('nocreate');
    nWorkers = isempty(pool) * 0 + (~isempty(pool) * pool.NumWorkers);
    blockSize = max(1, ceil(N / max(nWorkers, 1)));
end
blockEdges = 1:blockSize:N;
nBlocks = numel(blockEdges);

% ---------------- Preallocate output ----------------
nout = nargout;
outCell = cell(nBlocks, nout);

% ---------------- Parallel block loop ----------------
parfor b = 1:nBlocks
    idxStart = blockEdges(b);
    idxEnd = min(N, blockEdges(b) + blockSize - 1);
    nBlock = idxEnd - idxStart + 1;

    % Extract slices of inputs for this block
    blockSlices = cellfun(@(C) C(idxStart:idxEnd), Cinputs, 'UniformOutput', false);

    % Local block outputs
    blockOut = cell(1, nout);
    for k = 1:nout
        blockOut{k} = cell(nBlock, 1);
    end

    % Loop over elements in block
    for i = 1:nBlock
        args = cellfun(@(C) C{i}, blockSlices, 'UniformOutput', false);
        tmpOut = cell(1, nout);  % <-- FIX: define tmpOut here inside loop

        try
            [tmpOut{:}] = fcn(args{:});
        catch err
            if isempty(errorHandler)
                rethrow(err);
            else
                [tmpOut{:}] = errorHandler(err, idxStart + i - 1);
            end
        end

        for k = 1:nout
            blockOut{k}{i} = tmpOut{k};
        end
        
    end

    % Store block results
    for k = 1:nout
        outCell{b, k} = blockOut{k};
    end
end

% ---------------- Concatenate block results ----------------
varargout = cell(1, nout);
for k = 1:nout
    if uniformOutput
        varargout{k} = vertcat(outCell{:, k});
    else
        varargout{k} = [outCell{:, k}];
        if iscolumn(Cinputs{1})
            varargout{k} = varargout{k}(:);
        end
    end
end

return;
end
