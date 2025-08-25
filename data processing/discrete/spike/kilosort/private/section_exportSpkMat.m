function [spikeTimes, clusterIdxs, dataTDT, tShift] = section_exportSpkMat(RESPATHs, TRIGPATHs, BLOCKPATHs, nsamples, fs)
% init params
simThr = 0.7;
QThr = 0.15;
RThr = 0.05;
frThrMean = 1;
frThr0 = 0.5;

% loop for each result
[spikeTimes, clusterIdxs] = deal(cell(numel(RESPATHs), 1));
dataTDT = struct([]);
for rIndex = 1:numel(RESPATHs)
    % Read from NPY files
    RESPATH = RESPATHs{rIndex};
    spikeIdx = double(readNPY(fullfile(RESPATH, 'spike_times.npy')));
    clusterIdx = double(readNPY(fullfile(RESPATH, 'spike_clusters.npy')));
    idSimilar = readNPY(fullfile(RESPATH, 'similar_templates.npy'));

    % Align to start point of each block
    if rIndex > 1
        spikeIdx = spikeIdx - nsamples(rIndex - 1);
    end

    % Read from Trigger file
    dataTDT(rIndex) = TDTbin2mat(BLOCKPATHs{rIndex}, 'TYPE', {'epocs'});
    if isfile(TRIGPATHs{rIndex}) % TTL.mat for RHD and NP
        load(TRIGPATHs{rIndex}, "TTL");
        trialNum = numel(dataTDT(rIndex).epocs.Swep.onset);
        TTL_Onset = find(diff(TTL) > 0.9, 1) + 1;

        if trialNum < numel(TTL_Onset)
            TTL_Onset(find(diff(TTL_Onset) < 0.05) + 1) = [];
        end
        
        if trialNum < numel(TTL_Onset)
            keyboard;
            isContinue = input('continue? y/n \n', 's');
            if strcmpi(isContinue, "n")
                error("the TTL sync signal does not match the TDT epocs [Swep] store!");
            end
        end

        % Align TDT trigger with TTL trigger
        tShift(rIndex) = roundn((TTL_Onset(1) - dataTDT(rIndex).epocs.Swep.onset(1)) * fs, 0);
        spikeIdx = spikeIdx - roundn((TTL_Onset(1) - dataTDT(rIndex).epocs.Swep.onset(1)) * fs, 0);
        
    else % use TDT trigger
        % do nothing
        tShift(rIndex) = 0;
    end

    clusterUnique = unique(clusterIdx);
    idSimilar = idSimilar(ismember(1:length(idSimilar), clusterUnique + 1), ismember(1:length(idSimilar), clusterUnique + 1));

    spikeTime  = spikeIdx / fs;
    spikeTrain = arrayfun(@(x) spikeTime(clusterIdx == x), clusterUnique, "UniformOutput", false);
    spikeFR    = cellfun(@numel, spikeTrain) / (nsamples(rIndex) / fs);

    simCell = mu.cell2mat(cellfun(@(x, y) mNchoosek(find(all(spikeFR(x > simThr) > frThr0) & x > simThr & ~ismember(1:length(idSimilar), y)), 1:sum(x > simThr)-1, y), num2cell(idSimilar, 2), num2cell(1:length(idSimilar))', "UniformOutput", false));
    if ~isempty(simCell)
        similarPool = mUniqueCell(simCell);
        segIdx = find(cellfun(@(x, y) max(x) < min(y), similarPool, [similarPool(2:end); similarPool(end)]));
        mergePool = cellfun(@(x) similarPool(x(1) : x(2)), num2cell([[1; segIdx+1], [segIdx; length(similarPool)]], 2), "UniformOutput", false);

        [K, Qi, Q00, Q01, rir] = cellfun(@(x) cellfun(@(y) ccg(cell2mat(spikeTrain(ismember(1:length(clusterUnique), y)')), cell2mat(spikeTrain(ismember(1:length(clusterUnique), y)')), 500, 1/1000), x, "UniformOutput", false), mergePool, "UniformOutput", false);
        Q = cellfun(@(x, y, z) cellfun(@(m, n, k) min(m/(max(n, k))), x, y, z), Qi, Q00, Q01,"UniformOutput",false);
        R = cellfun(@(x) cellfun(@(y) min(y), x), rir, "UniformOutput",false);
        accIdx = cellfun(@(x, y, z) find(x < QThr & y < RThr & cellfun(@(k) mean(spikeFR(k)) > frThrMean, z)), Q, R, mergePool, "UniformOutput", false);
        % bestIdx : the largest set meeting the criterion or the min Q value in several sets with same size
        [~, bestIdx] = cellfun(@(x, y, z)  max(sum([2*(cellfun(@length, x(y)) == max(cellfun(@length, x(y)))), z(y)-min(z(y)) == 0], 2)), mergePool, accIdx, Q, "UniformOutput", false);
        mergeIdx = mu.cell2mat(cellfun(@(x, y, z, k) [x(y(z)) k(y(z))], mergePool, accIdx, bestIdx, Q, "UniformOutput", false));
        [~, idx]= mUniqueCell(cellfun(@(x) double(clusterUnique(x)), mergeIdx(:, 1), "UniformOutput", false));
        mergeIdx = mergeIdx(idx, :);

        if ~isempty(mergeIdx)
            mergeCluster = cellfun(@(x) clusterUnique(x), mergeIdx(:, 1), "UniformOutput", false);
            for index = 1 : length(mergeCluster)
                clusterIdx(ismember(clusterIdx, mergeCluster{index}(2:end))) = mergeCluster{index}(1);
                spikeFR(mergeIdx{index}(1)) = mean(spikeFR(mergeIdx{index}));
            end
            idToDel = spikeFR < frThr0 | ismember(clusterUnique, cell2mat(cellfun(@(x) x(2:end), mergeCluster, "UniformOutput", false)));
        else
            idToDel = spikeFR < frThr0;
        end
    else
        idToDel = spikeFR < frThr0;
    end

    % read from tsv file
    filename = fullfile(RESPATH, 'cluster_info.tsv');
    fileID = fopen(filename, 'r');
    if fileID == -1
        error('File does not exist: %s', filename);
    end
    fieldNames = textscan(fileID, '%s%s%s%s%s%s%s%s%s%s%s', 'HeaderLines', 0);
    array = [fieldNames{:}];
    array = array(:, ismember(array(1, :), ["cluster_id", "ch"]));
    fields = array(1, :);
    values = array(2:end, 1:end);
    values = cellfun(@(x) str2double(x), values, "UniformOutput", false);
    array = [fields; values];
    cluster_info = cell2struct(array(2:end, :), array(1, :), 2);
    fclose(fileID);

    % match cluster_id with channel
    id = [cluster_info.cluster_id]';
    ch = [cluster_info.ch]';
    idCh = sortrows([id, ch], 1);
    idCh(idToDel, :) = [];
    chs = unique(idCh(:, 2));
    for cIndex = 1 : length(chs)
        idx = find(idCh(:, 2) == chs(cIndex));
        for index = 1 :length(idx)
            idCh(idx(index), 2) = (index - 1)*1000 + chs(cIndex);
        end
    end

    clusterIdx = idCh(:, 1);
    chIdx = idCh(:, 2) + 1;
    spikeTimes{rIndex} = arrayfun(@(x) [spikeTime(clusterAll == x), chIdx(clusterIdx == x) * ones(sum(clusterAll == x), 1)], clusterIdx, "UniformOutput", false);
    clusterIdxs{rIndex} = clusterIdx;
end

return;
end

%% Utils
function groups = mNchoosek(data, nPool, header)
    narginchk(2, 3);
    if nargin < 3
        header = [];
    else
        if iscolumn(header)
            header = header';
        end
    end
    if isempty(data) || isempty(nPool)
        groups = [];
    else
        groups = cellfun(@(y) [header, y], mu.cell2mat(cellfun(@(x) num2cell(nchoosek(data, x), 2), num2cell(nPool)', "UniformOutput", false)), "UniformOutput", false);
    end
    return;
end

function [uniqueCA, idx] = mUniqueCell(cellRaw, varargin)
    mIp = inputParser;
    mIp.addRequired("cellRaw", @(x) iscell(x));
    mIp.addOptional("type", "simple", @(x) any(validatestring(x, {'simple', 'largest set', 'minimum set'})));
    mIp.parse(cellRaw, varargin{:});
    
    type = mIp.Results.type;
    
    temp = reshape(cellRaw, [], 1);
    idxTemp = 1 : length(temp);
    [temp, uniqIdx] = unique(string(cellfun(@(x) strjoin(mat2cellStr(sort(x)), ","), temp, "UniformOutput", false)));
    idxTemp = idxTemp(uniqIdx);
    temp = cellfun(@(k) str2double(strsplit(k, ",")), temp, "UniformOutput", false);
    [~, index] = sortrows(cell2mat(cellfun(@(x) [x, zeros(1, max(cellfun(@length, temp) - length(x)))], temp, "UniformOutput", false)), 1:cellfun(@length, temp), "ascend");
    idxTemp = idxTemp(index);
    temp = temp(index);
    if matches(type, "simple")
        uniqueCA = temp;
        idx = idxTemp';
    elseif matches(type, "largest set")
        largest_set = ~any(cell2mat(cellfun(@(x, y) ~ismember((1:length(temp))', y) & cellfun(@(k) all(ismember(k, x)), temp), temp, num2cell(1:length(temp))', "UniformOutput", false)'), 2);
        uniqueCA = temp(largest_set);
        idx = idxTemp(largest_set)';
    elseif matches(type, "minimum set")
        minimum_set = ~any(cell2mat(cellfun(@(x, y) ~ismember((1:length(temp))', y) & cellfun(@(k) all(ismember(k, x)), temp), temp, num2cell(1:length(temp))', "UniformOutput", false)'), 1)';
        uniqueCA = temp(minimum_set);
        idx = idxTemp(minimum_set)';
    end
    return;
end