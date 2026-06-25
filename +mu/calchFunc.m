function [res, trialsData] = calchFunc(fcn, trialsData, padDir)
%CALCHFUNC Compute a function across trials with optional NaN padding.
%
% INPUTS:
%   fcn
%       Function handle applied across trials.
%
%       Expected signatures:
%           fcn(data, dim)
%           fcn(data, dim, "omitnan")
%
%       Special handling:
%           @std is called as:
%               std(data, [], dim, "omitnan")
%
%   trialsData
%       Cell array. Each cell contains one trial:
%
%           trialsData{k}: [nCh x ... x nTime]
%
%       All dimensions except the last dimension must be identical across
%       trials. The last dimension is treated as time and can differ across
%       trials. If time lengths differ, shorter trials are padded with NaNs.
%
%   padDir
%       Padding direction along the last dimension:
%
%           "tail"  - pad NaNs after existing data. Default.
%           "head"  - pad NaNs before existing data.
%
% OUTPUTS:
%   res
%       Result after applying fcn along the newly created trial dimension.
%
%       Important:
%           This function removes only the newly created trial dimension.
%           It does not use squeeze, so singleton dimensions in the original
%           trial data are preserved as much as MATLAB array rules allow.
%
%   trialsData
%       Padded trialsData.
%
%       This output is constructed only when requested:
%
%           [res, trialsData] = calchFunc(...)
%
%       If only res is requested, padded trial cells are not generated,
%       reducing memory use.

%% Inputs

if nargin < 2
    error("calchFunc requires at least fcn and trialsData.");
end

if nargin < 3 || isempty(padDir)
    padDir = "tail";
end

if ~isa(fcn, "function_handle")
    error("fcn should be a function handle.");
end

if ~iscell(trialsData)
    error("trialsData should be a cell array.");
end

trialsData = trialsData(:);
nTrial = numel(trialsData);

if nTrial == 0
    error("trialsData should not be empty.");
end

padDir = validatestring(padDir, {'head', 'tail'});

%% Basic data checks

isNumericTrial = cellfun(@isnumeric, trialsData);

if ~all(isNumericTrial)
    error("All trial data should be numeric arrays.");
end

isEmptyTrial = cellfun(@isempty, trialsData);

if any(isEmptyTrial)
    error("trialsData should not contain empty arrays.");
end

% Keep class consistent. Direct preallocation uses the first trial as the
% template, so mixed classes may otherwise cause silent casting.
trialClasses = cellfun(@class, trialsData, "UniformOutput", false);

if ~all(strcmp(trialClasses, trialClasses{1}))
    error("All trial data should have the same numeric class.");
end

firstData = trialsData{1};

%% Dimension and size checks

nDims = cellfun(@ndims, trialsData);

if ~all(nDims == nDims(1))
    error("All trial data should have the same number of dimensions.");
end

dim = nDims(1);

% sizeMat:
%   each row is one trial
%   columns are dimensions 1:dim
sizeMat = zeros(nTrial, dim);

for k = 1:nTrial
    sz = size(trialsData{k});

    % size(x) may omit trailing singleton dimensions. Keep a stable vector.
    if numel(sz) < dim
        sz(numel(sz) + 1:dim) = 1;
    end

    sizeMat(k, :) = sz(1:dim);
end

baseSize = sizeMat(1, :);

% All dimensions except the last one must be identical.
if dim > 1
    sameNonTimeDims = all(sizeMat(:, 1:dim - 1) == baseSize(1:dim - 1), "all");
else
    sameNonTimeDims = true;
end

if ~sameNonTimeDims
    error("All trial data must have same size for dimensions except the last.");
end

nTimes = sizeMat(:, dim);
nTimeMax = max(nTimes);
needPadding = any(nTimes ~= nTimeMax);

% NaN padding requires floating-point data.
if needPadding && ~isfloat(firstData)
    error("NaN padding requires floating-point trial data.");
end

%% Preallocate concatenated data directly
%
% Final layout:
%   dataCat: [original dimensions with time padded to nTimeMax, nTrial]
%
% Example:
%   trial data: [nCh x nFreq x nTime]
%   dataCat   : [nCh x nFreq x nTimeMax x nTrial]

concatDim = dim + 1;
catSize = [baseSize(1:dim - 1), nTimeMax, nTrial];

if needPadding
    dataCat = nan(catSize, "like", firstData);
else
    % No padding needed. Use zeros and fully overwrite it below.
    % This avoids unnecessary NaN initialization.
    dataCat = zeros(catSize, "like", firstData);
end

for k = 1:nTrial
    thisData = trialsData{k};
    thisNTime = nTimes(k);

    idx = repmat({':'}, 1, concatDim);

    switch padDir
        case 'head'
            timeIdx = nTimeMax - thisNTime + 1:nTimeMax;

        case 'tail'
            timeIdx = 1:thisNTime;
    end

    idx{dim} = timeIdx;
    idx{concatDim} = k;

    dataCat(idx{:}) = thisData;
end

%% Optional padded trialsData output

if nargout > 1
    paddedTrialsData = cell(nTrial, 1);

    for k = 1:nTrial
        idx = repmat({':'}, 1, concatDim);
        idx{concatDim} = k;

        paddedTrialsData{k} = dataCat(idx{:});
    end

    trialsData = paddedTrialsData;
end

%% Apply function along trial dimension

if isequal(fcn, @std)
    res = std(dataCat, [], concatDim, "omitnan");
else
    try
        res = fcn(dataCat, concatDim, "omitnan");
    catch
        res = fcn(dataCat, concatDim);
    end
end

%% Remove only the newly created trial dimension
%
% Do not call squeeze(res), because squeeze removes all singleton dimensions.
% For example, original data [nCh x 1 x nTime] should remain
% [nCh x 1 x nTime], not become [nCh x nTime].
%
% targetSize is the original trial size after time padding:
%   [nCh x ... x nTimeMax]

targetSize = catSize;
targetSize(concatDim) = [];

res = local_reshapeToTargetSize(res, targetSize);

return;
end

%% Local functions

function res = local_reshapeToTargetSize(res, targetSize)
%LOCAL_RESHAPETOTARGETSIZE Remove only the aggregated trial dimension.
%
% This helper reshapes res to the original non-trial dimensions if possible.
% If fcn returns a custom-sized result, the result is left unchanged.

targetSize = double(targetSize(:).');

% MATLAB arrays are at least 2-D. Preserve this convention.
if isempty(targetSize)
    targetSize = [1, 1];
elseif isscalar(targetSize)
    targetSize = [targetSize, 1];
end

if numel(res) == prod(targetSize)
    res = reshape(res, targetSize);
end

return;
end