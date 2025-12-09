function [res, trialsData] = calchFunc(fcn, trialsData, padDir)
%CALCHFUNC  Compute function across trials data with padding if needed.
%
% INPUTS:
%     fcn         - function handle with signature fcn(data, dim, varargin)
%     trialsData  - cell array, each cell [nCh x ... x nTime]
%     padDir      - 'head' or 'tail' (default='tail')
%
% OUTPUTS:
%     res         - result after applying fcn along trials dimension
%     trialsData  - padded trialsData (if padding applied)

if nargin < 3 || isempty(padDir)
    padDir = "tail";
end

trialsData = trialsData(:); % ensure column

nDims = cellfun(@ndims, trialsData);
if ~all(nDims == nDims(1))
    error("All trial data should have the same number of dimensions.");
end
dim = nDims(1);

sizes = cellfun(@size, trialsData, "UniformOutput", false);
for d = 1:dim-1
    sizesDim = cellfun(@(x) x(d), sizes);
    if ~all(sizesDim == sizesDim(1))
        error("All trial data must have same size for dimensions except last.");
    end
end

nTimes = cellfun(@(x) size(x, dim), trialsData);
if ~all(nTimes == nTimes(1))
    nTimeMax = max(nTimes);
    % Pad with NaNs along time dimension
    for k = 1:numel(trialsData)
        sz = size(trialsData{k});
        padSize = sz;
        padSize(dim) = nTimeMax - nTimes(k);
        if padSize(dim) > 0
            nanPad = nan(padSize, 'like', trialsData{k});
            if strcmpi(padDir, "head")
                trialsData{k} = cat(dim, nanPad, trialsData{k});
            elseif strcmpi(padDir, "tail")
                trialsData{k} = cat(dim, trialsData{k}, nanPad);
            else
                error("padDir must be 'head' or 'tail'.");
            end
        end
    end
end

% Concatenate trials along new dim
concatDim = dim + 1;
dataCat = cat(concatDim, trialsData{:});

% Decide how to call fcn (try to call with "omitnan" if supported)
if isequal(fcn, @std)
    res = std(dataCat, [], concatDim, "omitnan");
else
    try
        res = fcn(dataCat, concatDim, "omitnan");
    catch
        res = fcn(dataCat, concatDim);
    end
end

res = squeeze(res);

return;
end
