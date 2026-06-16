function out = mu_selectSpikes(varargin)
%MU_SELECTSPIKES Extract event-aligned spikes or select clusters from trials.
%
% SYNTAX:
%   Segment continuous spike data around events:
%
%     out = mu_selectSpikes(sortdata, events, window)
%     out = mu_selectSpikes(sortdata, events, window, clus)
%     out = mu_selectSpikes(sortdata, events, window, clus, keepClus)
%     out = mu_selectSpikes(..., "OutputMode", outputMode)
%
%   Select clusters from already segmented trials:
%
%     out = mu_selectSpikes(trial)
%     out = mu_selectSpikes(trial, clus)
%     out = mu_selectSpikes(trial, clus, keepClus)
%
% INPUTS:
%   sortdata
%       Continuous spike data:
%
%           N-by-1: spike time
%           N-by-2: [spike time, cluster ID]
%
%       Spike times do not need to be sorted. Sorting is performed only
%       when necessary.
%
%   events
%       Event information, specified as either:
%
%           numeric vector of event onset times
%           struct array containing a scalar numeric .onset field
%
%       Events do not need to be sorted. Results are returned in the
%       original event order.
%
%   window
%       Two-element relative time window:
%
%           [windowStart, windowEnd]
%
%       Spike inclusion follows the half-open interval:
%
%           eventTime + windowStart <= spikeTime
%           spikeTime < eventTime + windowEnd
%
%       That is, the left boundary is included and the right boundary is
%       excluded.
%
%   clus
%       Numeric vector of cluster IDs to retain. An empty value retains all
%       clusters. Default: [].
%
%   keepClus
%       Whether to retain the cluster column in data output.
%
%       Segmentation mode default: true.
%       Existing-trial mode default: false.
%
%       Accepted values are those supported by mu.OptionState.
%
% NAME-VALUE:
%   OutputMode
%       Output representation in segmentation mode:
%
%       "data"  - Return event-aligned spike data. Default.
%
%                 Numeric event input:
%                     returns an nEvent-by-1 cell array.
%
%                 Struct event input:
%                     returns the input struct with a .spike field.
%
%       "count" - Return an nEvent-by-1 spike-count vector. No event-spike
%                 data are copied. This is recommended when only firing
%                 counts are needed.
%
%       "index" - Return a compact scalar struct describing the index range
%                 of spikes belonging to every event. No event-spike data
%                 are copied.
%
%                 Fields include:
%                     .startIndex
%                     .endIndexExclusive
%                     .count
%                     .eventTime
%                     .window
%                     .spikeTimes
%                     .clusters
%                     .sourceIndex
%
%                 For event i:
%
%                     idx = startIndex(i):endIndexExclusive(i)-1;
%
%                 sourceIndex maps the sorted, cluster-filtered spikes back
%                 to rows of the original sortdata input.
%
% OUTPUT:
%   out
%       Output format depends on the input mode and OutputMode.
%
% ALGORITHM:
%   Events and spike times are sorted only when necessary.
%
%   Strictly separated event windows:
%       Uses histcounts followed by mat2cell. This avoids one callback per
%       event and is efficient when each spike belongs to at most one
%       window.
%
%   Touching or overlapping event windows:
%       Uses a monotonic two-pointer sweep. Because event-window boundaries
%       and spike times are sorted, each pointer moves through spikeTimes
%       at most once. Boundary search therefore costs approximately:
%
%           O(nEvent + nSpike)
%
%       Creating "data" output still costs O(K), where K is the total number
%       of event-spike associations. Under heavy overlap, K can be much
%       larger than the original number of spikes. Use OutputMode="count"
%       or "index" to avoid that replication.
%
% NOTES:
%   Cluster filtering is performed before trial segmentation. It is not
%   repeated separately for every trial.

%% Validate top-level input

if nargin < 1
    error("mu:selectSpikes:NotEnoughInputs", ...
        "At least one input is required.");
end

firstInput = varargin{1};

if isnumeric(firstInput)
    out = local_segmentSpikes(varargin{:});

elseif iscell(firstInput) || isstruct(firstInput)
    out = local_selectFromTrials(varargin{:});

else
    error("mu:selectSpikes:InvalidInputType", ...
        "The first input must be numeric spike data, a cell array, or a struct array.");
end

end

%% Segmentation mode

function out = local_segmentSpikes(sortdata, trialOrEvent, window, varargin)
%LOCAL_SEGMENTSPIKES Segment continuous spike data around events.

if nargin < 3
    error("mu:selectSpikes:NotEnoughSegmentationInputs", ...
        "Segmentation mode requires sortdata, events, and window.");
end

[clus, keepClus, outputMode] = local_parseSegmentOptions(varargin);

%% Validate continuous spike data

validateattributes(sortdata, "numeric", ...
    {"2d", "real"}, mfilename, "sortdata");

nColumn = size(sortdata, 2);

if nColumn ~= 1 && nColumn ~= 2
    error("mu:selectSpikes:InvalidSortDataSize", ...
        "sortdata must have one or two columns, not %d.", nColumn);
end

hasCluster = nColumn == 2;

if ~isempty(sortdata) && any(~isfinite(sortdata(:, 1)))
    error("mu:selectSpikes:InvalidSpikeTime", ...
        "Spike times must be finite.");
end

if hasCluster && ~isempty(sortdata)
    clusterColumn = sortdata(:, 2);

    if any(~isfinite(clusterColumn)) || any(clusterColumn ~= fix(clusterColumn))
        error("mu:selectSpikes:InvalidClusterID", ...
            "Cluster IDs in sortdata(:,2) must be finite integer-valued numbers.");
    end
end

clus = local_validateClusterSelection(clus);

if ~hasCluster && ~isempty(clus)
    error("mu:selectSpikes:NoClusterInformation", ...
        "clus was specified, but sortdata contains no cluster column.");
end

%% Validate window

validateattributes(window, "numeric", ...
    {"vector", "numel", 2, "real", "finite"}, ...
    mfilename, "window");

window = double(window(:).');

if window(1) >= window(2)
    error("mu:selectSpikes:InvalidWindow", ...
        "window must satisfy window(1) < window(2).");
end

%% Parse events

[tEvt, isStructEvent] = local_parseEvents(trialOrEvent);
numEvt = numel(tEvt);

%% Preserve original spike-row indices

numSpikeOriginal = size(sortdata, 1);
sourceIndex = (1:numSpikeOriginal).';

%% Filter clusters once, before sorting and segmentation

if hasCluster && ~isempty(clus)
    clusterMask = ismember(sortdata(:, 2), clus);

    sortdata = sortdata(clusterMask, :);
    sourceIndex = sourceIndex(clusterMask);
end

spikeTimes = double(sortdata(:, 1));

if hasCluster
    clusters = double(sortdata(:, 2));
else
    clusters = zeros(0, 1);
end

%% Sort spike times only when required

if ~issorted(spikeTimes)
    [spikeTimes, spikeOrder] = sort(spikeTimes, "ascend");
    sourceIndex = sourceIndex(spikeOrder);

    if hasCluster
        clusters = clusters(spikeOrder);
    end
end

%% Sort events only when required

if issorted(tEvt)
    tEvtSorted = tEvt;
    eventOrder = (1:numEvt).';
else
    [tEvtSorted, eventOrder] = sort(tEvt, "ascend");
end

winStart = tEvtSorted + window(1);
winEnd = tEvtSorted + window(2);

%% Compact output modes
%
% Both count and index use the linear two-pointer boundary search. They do
% not generate per-event spike arrays.

if outputMode == "count" || outputMode == "index"
    [startIndexSorted, endIndexExclusiveSorted] = ...
        local_findWindowBounds(spikeTimes, winStart, winEnd);

    countSorted = endIndexExclusiveSorted - startIndexSorted;

    startIndex = local_restoreEventOrder(startIndexSorted, eventOrder);
    endIndexExclusive = local_restoreEventOrder( ...
        endIndexExclusiveSorted, eventOrder);
    count = local_restoreEventOrder(countSorted, eventOrder);

    if outputMode == "count"
        out = count;
        return;
    end

    out = struct();
    out.startIndex = startIndex;
    out.endIndexExclusive = endIndexExclusive;
    out.count = count;

    out.eventTime = tEvt;
    out.window = window;
    out.windowBoundary = "[start, end)";

    out.spikeTimes = spikeTimes;

    if hasCluster
        out.clusters = clusters;
    else
        out.clusters = [];
    end

    out.sourceIndex = sourceIndex;
    out.hasCluster = hasCluster;
    out.clusterSelection = clus;

    return;
end

%% Data output mode

if numEvt == 0
    outCell = cell(0, 1);
    out = local_attachSpikeOutput(trialOrEvent, outCell, isStructEvent);
    return;
end

% histcounts requires strictly increasing edges. Therefore touching windows
% are handled by the two-pointer branch together with overlapping windows.
canUseHistcounts = numEvt == 1 || ...
    all(winStart(2:end) > winEnd(1:end - 1));

if canUseHistcounts
    outCellSorted = local_extractSeparatedWindows( ...
        spikeTimes, clusters, tEvtSorted, winStart, winEnd, ...
        hasCluster, keepClus);
else
    [startIndexSorted, endIndexExclusiveSorted] = ...
        local_findWindowBounds(spikeTimes, winStart, winEnd);

    outCellSorted = local_extractIndexedWindows( ...
        spikeTimes, clusters, tEvtSorted, ...
        startIndexSorted, endIndexExclusiveSorted, ...
        hasCluster, keepClus);
end

% Restore the order of the original event input.
outCell = cell(numEvt, 1);
outCell(eventOrder) = outCellSorted;

out = local_attachSpikeOutput(trialOrEvent, outCell, isStructEvent);

end

%% Parse segmentation optional inputs

function [clus, keepClus, outputMode] = local_parseSegmentOptions(args)
%LOCAL_PARSESEGMENTOPTIONS Parse positional and Name-Value options.
%
% Positional compatibility:
%   ..., clus
%   ..., clus, keepClus
%
% Name-Value:
%   ..., "OutputMode", "data"/"count"/"index"

clus = [];
keepClus = true;

optionNames = "OutputMode";

if ~isempty(args) && ~local_isOptionName(args{1}, optionNames)
    clus = args{1};
    args(1) = [];
end

if ~isempty(args) && ~local_isOptionName(args{1}, optionNames)
    keepClus = mu.OptionState.create(args{1}).toLogical;
    args(1) = [];
end

mIp = inputParser;
mIp.CaseSensitive = false;
mIp.PartialMatching = false;

mIp.addParameter("OutputMode", "data", @local_isTextScalar);
mIp.parse(args{:});

outputMode = string(validatestring( ...
    mIp.Results.OutputMode, ...
    {'data', 'count', 'index'}));

end

%% Parse events

function [tEvt, isStructEvent] = local_parseEvents(trialOrEvent)
%LOCAL_PARSEEVENTS Extract event times from numeric or struct input.

if isstruct(trialOrEvent)
    if ~isfield(trialOrEvent, "onset")
        error("mu:selectSpikes:MissingOnset", ...
            "Struct event input must contain an onset field.");
    end

    isStructEvent = true;

    if isempty(trialOrEvent)
        tEvt = zeros(0, 1);
        return;
    end

    isValidOnset = arrayfun(@(x) ...
        isnumeric(x.onset) && ...
        isreal(x.onset) && ...
        isscalar(x.onset) && ...
        isfinite(x.onset), ...
        trialOrEvent);

    if ~all(isValidOnset)
        badIndex = find(~isValidOnset, 1);

        error("mu:selectSpikes:InvalidOnset", ...
            "trialOrEvent(%d).onset must be a finite real numeric scalar.", ...
            badIndex);
    end

    tEvt = double([trialOrEvent.onset].');

elseif isnumeric(trialOrEvent)
    validateattributes(trialOrEvent, "numeric", ...
        {"vector", "real", "finite"}, ...
        mfilename, "events");

    tEvt = double(trialOrEvent(:));
    isStructEvent = false;

else
    error("mu:selectSpikes:InvalidEventInput", ...
        "Events must be a numeric vector or a struct array with an onset field.");
end

end

%% Strictly separated windows

function outCell = local_extractSeparatedWindows( ...
    spikeTimes, clusters, tEvt, winStart, winEnd, ...
    hasCluster, keepClus)
%LOCAL_EXTRACTSEPARATEDWINDOWS Extract strictly non-overlapping windows.
%
% Edges are arranged as:
%   [-Inf, start1, end1, start2, end2, ..., Inf]
%
% With MATLAB histcounts rules, even-numbered bins correspond to:
%   [start_i, end_i)

numEvt = numel(tEvt);

if hasCluster && keepClus
    numOutputColumns = 2;
else
    numOutputColumns = 1;
end

if isempty(spikeTimes)
    outCell = local_createEmptyTrialCells(numEvt, numOutputColumns);
    return;
end

edges = reshape([winStart, winEnd].', [], 1);
[~, ~, binIndex] = histcounts(spikeTimes, [-Inf; edges; Inf]);

isInside = binIndex > 0 & ...
           binIndex <= 2 * numEvt & ...
           mod(binIndex, 2) == 0;

if ~any(isInside)
    outCell = local_createEmptyTrialCells(numEvt, numOutputColumns);
    return;
end

trialIndex = binIndex(isInside) / 2;

selectedTimes = spikeTimes(isInside);
relativeTimes = selectedTimes - tEvt(trialIndex);

if hasCluster && keepClus
    selectedData = [relativeTimes, clusters(isInside)];
else
    selectedData = relativeTimes;
end

count = accumarray( ...
    trialIndex, ...
    1, ...
    [numEvt, 1], ...
    @sum, ...
    0);

outCell = mat2cell(selectedData, count, numOutputColumns);

end

%% Overlapping or touching windows

function outCell = local_extractIndexedWindows( ...
    spikeTimes, clusters, tEvt, ...
    startIndex, endIndexExclusive, ...
    hasCluster, keepClus)
%LOCAL_EXTRACTINDEXEDWINDOWS Build per-event data from contiguous ranges.
%
% The unavoidable cost of this function is proportional to the total number
% of event-spike associations. A spike appearing in several overlapping
% windows is copied once for every corresponding event.

numEvt = numel(tEvt);

if hasCluster && keepClus
    numOutputColumns = 2;
else
    numOutputColumns = 1;
end

outCell = local_createEmptyTrialCells(numEvt, numOutputColumns);

for eventIndex = 1:numEvt
    idx1 = startIndex(eventIndex);
    idx2Exclusive = endIndexExclusive(eventIndex);

    if idx2Exclusive <= idx1
        continue;
    end

    spikeIndex = idx1:idx2Exclusive - 1;
    relativeTimes = spikeTimes(spikeIndex) - tEvt(eventIndex);

    if hasCluster && keepClus
        outCell{eventIndex} = [ ...
            relativeTimes, ...
            clusters(spikeIndex)];
    else
        outCell{eventIndex} = relativeTimes;
    end
end

end

%% Linear two-pointer boundary search

function [startIndex, endIndexExclusive] = ...
    local_findWindowBounds(spikeTimes, winStart, winEnd)
%LOCAL_FINDWINDOWBOUNDS Find contiguous spike ranges for sorted windows.
%
% INPUT REQUIREMENTS:
%   spikeTimes, winStart, and winEnd must be sorted in ascending order.
%
% WINDOW RULE:
%   [winStart, winEnd)
%
% OUTPUT:
%   startIndex(i)
%       First index satisfying spikeTimes >= winStart(i).
%
%   endIndexExclusive(i)
%       First index satisfying spikeTimes >= winEnd(i).
%
% COMPLEXITY:
%   Both pointers only move forward. Total boundary-search complexity is:
%
%       O(nSpike + nEvent)

numEvt = numel(winStart);
numSpike = numel(spikeTimes);

startIndex = zeros(numEvt, 1);
endIndexExclusive = zeros(numEvt, 1);

leftPointer = 1;
rightPointer = 1;

for eventIndex = 1:numEvt
    thisStart = winStart(eventIndex);
    thisEnd = winEnd(eventIndex);

    while leftPointer <= numSpike && ...
            spikeTimes(leftPointer) < thisStart
        leftPointer = leftPointer + 1;
    end

    if rightPointer < leftPointer
        rightPointer = leftPointer;
    end

    while rightPointer <= numSpike && ...
            spikeTimes(rightPointer) < thisEnd
        rightPointer = rightPointer + 1;
    end

    startIndex(eventIndex) = leftPointer;
    endIndexExclusive(eventIndex) = rightPointer;
end

end

%% Existing-trial mode

function out = local_selectFromTrials(trial, varargin)
%LOCAL_SELECTFROMTRIALS Select clusters from segmented trial data.

if numel(varargin) > 2
    error("mu:selectSpikes:TooManyTrialSelectionInputs", ...
        "Existing-trial mode accepts at most trial, clus, and keepClus.");
end

clus = [];

if ~isempty(varargin)
    clus = varargin{1};
end

if numel(varargin) >= 2
    keepClus = mu.OptionState.create(varargin{2}).toLogical;
else
    keepClus = false;
end

clus = local_validateClusterSelection(clus);

out = local_selectTrialClusters(trial, clus, keepClus);

end

function trial = local_selectTrialClusters(trial, clus, keepClus)
%LOCAL_SELECTTRIALCLUSTERS Filter cluster IDs from cell or struct trials.

selectClusters = ~isempty(clus);

if iscell(trial)
    originalSize = size(trial);
    spikeCell = trial(:);
    isStructInput = false;

elseif isstruct(trial)
    if ~isfield(trial, "spike")
        error("mu:selectSpikes:MissingSpikeField", ...
            "Struct trial input must contain a spike field.");
    end

    spikeCell = reshape({trial.spike}, [], 1);
    isStructInput = true;

else
    error("mu:selectSpikes:InvalidTrialInput", ...
        "trial must be a cell array or struct array.");
end

% No transformation is necessary.
if ~selectClusters && keepClus
    return;
end

numTrial = numel(spikeCell);
outputCell = cell(numTrial, 1);

for trialIndex = 1:numTrial
    spike = spikeCell{trialIndex};

    if ~isnumeric(spike) || ~isreal(spike) || ndims(spike) > 2
        error("mu:selectSpikes:InvalidTrialSpikeData", ...
            "Spike data in trial %d must be a real numeric matrix.", ...
            trialIndex);
    end

    if isempty(spike)
        if selectClusters && keepClus
            outputCell{trialIndex} = zeros(0, 2);
        else
            outputCell{trialIndex} = zeros(0, 1);
        end

        continue;
    end

    if size(spike, 2) < 1
        error("mu:selectSpikes:InvalidTrialSpikeSize", ...
            "Spike data in trial %d has no time column.", trialIndex);
    end

    if selectClusters
        if size(spike, 2) < 2
            error("mu:selectSpikes:NoClusterInformation", ...
                "Spike data in trial %d has no cluster column.", ...
                trialIndex);
        end

        rowMask = ismember(spike(:, 2), clus);

        if keepClus
            outputCell{trialIndex} = spike(rowMask, :);
        else
            outputCell{trialIndex} = spike(rowMask, 1);
        end

    else
        outputCell{trialIndex} = spike(:, 1);
    end
end

if isStructInput
    for trialIndex = 1:numel(trial)
        trial(trialIndex).spike = outputCell{trialIndex};
    end
else
    trial = reshape(outputCell, originalSize);
end

end

%% Output helpers

function out = local_attachSpikeOutput(eventInput, outCell, isStructEvent)
%LOCAL_ATTACHSPIKEOUTPUT Return cell output or attach it to event structs.

if ~isStructEvent
    out = outCell;
    return;
end

out = eventInput;

if isempty(out)
    if ~isfield(out, "spike")
        out = local_addFieldToEmptyStruct(out, "spike");
    end

    return;
end

for eventIndex = 1:numel(out)
    out(eventIndex).spike = outCell{eventIndex};
end

end

function s = local_addFieldToEmptyStruct(s, fieldName)
%LOCAL_ADDFIELDTOEMPTYSTRUCT Add a field while preserving empty struct shape.

existingFields = fieldnames(s);

if any(strcmp(existingFields, fieldName))
    return;
end

allFields = [existingFields; {fieldName}];
template = cell2struct(cell(numel(allFields), 1), allFields, 1);
s = repmat(template, size(s));

end

function outCell = local_createEmptyTrialCells(numTrial, numColumn)
%LOCAL_CREATEEMPTYTRIALCELLS Create consistently shaped empty spike arrays.

emptySpike = zeros(0, numColumn);
outCell = repmat({emptySpike}, numTrial, 1);

end

function values = local_restoreEventOrder(sortedValues, eventOrder)
%LOCAL_RESTOREEVENTORDER Restore values to the original event order.

values = zeros(size(sortedValues), "like", sortedValues);
values(eventOrder) = sortedValues;

end

%% Validation helpers

function clus = local_validateClusterSelection(clus)
%LOCAL_VALIDATECLUSTERSELECTION Validate and normalize cluster selection.

if isempty(clus)
    clus = [];
    return;
end

validateattributes(clus, "numeric", ...
    {"vector", "real", "finite", "integer"}, ...
    mfilename, "clus");

clus = double(clus(:));

end

function tf = local_isOptionName(value, validNames)
%LOCAL_ISOPTIONNAME Test whether value is a recognized Name-Value name.

tf = local_isTextScalar(value) && ...
    any(strcmpi(string(value), string(validNames)));

end

function tf = local_isTextScalar(value)
%LOCAL_ISTEXTSCALAR True for scalar string or character row vector.

tf = (isstring(value) && isscalar(value)) || ...
     (ischar(value) && isrow(value));

end