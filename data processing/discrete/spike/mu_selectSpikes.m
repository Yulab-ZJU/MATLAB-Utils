function out = mu_selectSpikes(sortdata, trialAllOrtEvt, window)
% Efficient spike extraction around events with automatic overlap detection.
%
% - Uses fast histcounts method if no window overlap
% - Switches to binary search (discretize) if overlap detected
%
% INPUT:
%   sortdata:       [N × 2] (spikeTime, cluster) or [N × 1] (spikeTime only)
%   trialAllOrtEvt: struct with .onset field, or [tEvt] vector
%   window:         [start, end], relative to event
%
% OUTPUT:
%   If input is struct: returns with added .spike field
%   Else: returns cell array of spike data per event

% Sort spikeTimes
hasCluster = size(sortdata, 2) > 1;
if hasCluster
    sortdata = sortrows(sortdata, 1, "ascend");
    spikeTimes = sortdata(:, 1);
    clusters = sortdata(:, 2);
else
    spikeTimes = sort(sortdata, "ascend");
end

% Parse input events
switch class(trialAllOrtEvt)
    case 'struct'
        if ~isfield(trialAllOrtEvt, "onset")
            error("Struct must contain 'onset' field.");
        end
        tEvt = double([trialAllOrtEvt.onset]');
        isStruct = true;
    case {'double', 'single'}
        tEvt = double(trialAllOrtEvt(:));
        isStruct = false;
    otherwise
        error("Invalid input type.");
end

numEvt = numel(tEvt);

% Detect overlap
isOverlap = any(tEvt(2:end) + window(1) < tEvt(1:end - 1) | tEvt(1:end - 1) + window(2) > tEvt(2:end));

% -- Case 1: No overlap, use fast histcounts --
if ~isOverlap
    winStart = tEvt + window(1);
    winEnd   = tEvt + window(2);

    edges = sort([winStart; winEnd]);
    [~, ~, binIdx] = histcounts(spikeTimes, [-Inf; edges; Inf]);

    % spikes in even-numbered bins are inside windows
    isInWin = mod(binIdx, 2) == 0 & binIdx > 0 & binIdx <= 2 * numEvt;
    binIdx = binIdx(isInWin);
    spikeTimes = spikeTimes(isInWin);
    if isempty(spikeTimes)
        out = repmat({[]}, numEvt, 1);
        return
    end
    if hasCluster
        clusters = clusters(isInWin);
    end

    trialIdx = binIdx / 2;
    spikeTimes = spikeTimes - tEvt(trialIdx);

    if hasCluster
        outCell = accumarray(trialIdx, (1:numel(spikeTimes))', [numEvt, 1], ...
            @(ix) {sortrows([spikeTimes(ix), clusters(ix)], 2)}, {zeros(0, 2)});
    else
        outCell = accumarray(trialIdx, (1:numel(spikeTimes))', [numEvt, 1], ...
            @(ix) {spikeTimes(ix)}, {zeros(0, 1)});
    end

else
    % -- Case 2: Overlap exists, use binary search + repeat allowed --
    outCell = cell(numEvt, 1);
    % binary search window bounds
    spkIdxStart = discretize(tEvt + window(1), [-Inf; spikeTimes; Inf]);
    spkIdxEnd   = discretize(tEvt + window(2), [-Inf; spikeTimes; Inf]);

    for i = 1:numEvt
        idx1 = spkIdxStart(i);
        idx2 = spkIdxEnd(i) - 1;
        if idx2 >= idx1 && idx1 > 0
            spkIdx = idx1:idx2;
            relTime = spikeTimes(spkIdx) - tEvt(i);
            if hasCluster
                outCell{i} = [relTime, clusters(spkIdx)];
            else
                outCell{i} = relTime;
            end
        else
            if hasCluster
                outCell{i} = zeros(0, 2);
            else
                outCell{i} = zeros(0, 1);
            end
        end
    end
end

% Output
if isStruct
    out = mu.addfield(trialAllOrtEvt, "spike", outCell);
else
    out = outCell;
end

return;
end
