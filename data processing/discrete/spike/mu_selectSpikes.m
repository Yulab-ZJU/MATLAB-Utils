function out = mu_selectSpikes(varargin)
%MU_SELECTSPIKES  Efficient spike extraction around events with automatic overlap detection.
%
% - Uses fast histcounts method if no window overlap
% - Switches to binary search (discretize) if overlap detected
% - Segment trials by triggers or select spikes for specific clusters from trials
%
%     trial = mu_selectSpikes(sortdata, trialOrtEvt, window, [clus], [keepClus])
%     trial = mu_selectSpikes(trial, clus, [keepClus])
%
% INPUT:
%   1. Segment trials by triggers
%      sortdata    : [N × 2] (spikeTime, cluster) or [N × 1] (spikeTime only)
%      trialOrtEvt : struct with .onset field, or [tEvt] vector
%      window      : [start, end], relative to event
%      clus        : cluster index, empty for all (if exist)
%      keepClus    : default=true
%   2. Select spikes for specific clusters from trials
%      trial       : trial spike data (cell or struct)
%      clus        : cluster index, empty for all (if exist)
%      keepClus    : default=false
%
% OUTPUT:
%   1. Segment trials by triggers
%      If input [trialAllOrtEvt] is struct: returns with added .spike field
%      Else: returns cell array of spike data per event
%   2. Select spikes for specific clusters from trials
%      Returns with added .spike field

if isnumeric(varargin{1})
    % Segment trials by triggers
    narginchk(3, 5);

    sortdata = varargin{1};
    trialAllOrtEvt = varargin{2};
    window = varargin{3};
    clus = mu.ifelse(nargin < 4, [], @() varargin{4});
    keepClus = mu.ifelse(nargin < 5, mu.OptionState.On, @() mu.OptionState.create(varargin{5}));
    keepClus = keepClus.toLogical;

    % validate
    validateattributes(sortdata, 'numeric', {'2d', 'real'});

    % Sort spikeTimes
    hasCluster = size(sortdata, 2) > 1;
    if hasCluster
        sortdata = mu.ifelse(isempty(clus), sortdata, sortdata(ismember(sortdata(:, 2), clus), :));
        sortdata = sortrows(sortdata, 1, "ascend");
        spikeTimes = sortdata(:, 1);
        clusters = sortdata(:, 2);
    else
        spikeTimes = sort(sortdata, "ascend");
        if ~isempty(clus)
            warning("No cluster information found");
        end
    end

    % Parse input events
    switch class(trialAllOrtEvt)
        case 'struct'
            assert(isfield(trialAllOrtEvt, "onset"), "Input trial (struct) must contain 'onset' field.");
            tEvt = double([trialAllOrtEvt.onset]');
            isStruct = true;
        case {'double', 'single'}
            tEvt = double(trialAllOrtEvt(:));
            isStruct = false;
        otherwise
            error("Invalid input type");
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

    if ~isempty(clus)
        outCell = selectTrialClus(outCell, clus, keepClus);
    elseif ~keepClus
        outCell = cellfun(@(x) x(:, 1), outCell, "UniformOutput", false);
    end

    % Output
    if isStruct
        out = mu.addfield(trialAllOrtEvt, "spike", outCell);
    else
        out = outCell;
    end

elseif iscell(varargin{1}) || isstruct(varargin{1})
    % Select spikes for specific clusters from trials
    trial = varargin{1};
    clus = varargin{2};
    keepClus = mu.ifelse(nargin < 3, mu.OptionState.Off, @() mu.OptionState.create(varargin{3}));
    keepClus = keepClus.toLogical;

    out = selectTrialClus(trial, clus, keepClus);
end

return;
end

%%
function trial = selectTrialClus(trial, clus, keepClus)
    validateattributes(clus, 'numeric', {'vector', 'integer'});
    
    if iscell(trial)
        sz = cellfun(@(x) size(x, 2), trial);
        assert(all(sz == sz(1), 'all'), 'No cluster information found');
        if keepClus
            trial = cellfun(@(x) x(ismember(x(:, 2), clus(:)), :), trial, "UniformOutput", false);
        else
            trial = cellfun(@(x) x(ismember(x(:, 2), clus(:)), 1), trial, "UniformOutput", false);
        end
    elseif isstruct(trial)
        validateattributes(trial, 'struct', {'vector', 'nonempty'});
        assert(isfield(trial, 'spike'), '[trial] should contain field spike');
        if keepClus
            temp = arrayfun(@(x) x.spike(ismember(x.spike(:, 2), clus(:)), :), trial, "UniformOutput", false);
        else
            temp = arrayfun(@(x) x.spike(ismember(x.spike(:, 2), clus(:)), 1), trial, "UniformOutput", false);
        end
        trial = mu.addfield(trial, "spike", temp);
    else
        error('Invalid data type %s. It should either be cell or struct.', class(trial));
    end

    return;
end