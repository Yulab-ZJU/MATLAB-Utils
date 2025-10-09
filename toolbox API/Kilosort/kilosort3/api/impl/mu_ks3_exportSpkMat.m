function [spikeTimes, clusterIdxs, dataTDT, tShift] = ...
    mu_ks3_exportSpkMat(EXCELPATH, ...
                        sortIDs, ...
                        SAVEROOTPATH, ...
                        BINPATHs, ...
                        RESPATHs, ...
                        TRIGPATHs, ...
                        FORMAT, ...
                        nch, ...
                        skipSpkExportExisted)

% Get params
sortIDs = unique(sortIDs);
[params, tbl] = mu_ks4_getParamsExcel(EXCELPATH, sortIDs);
nBatch = numel(params);

% Get data length of each binary file
nsamples = cellfun(@(x) cellfun(@(y) mu_ks_getBinDataLength(y, nch, FORMAT), x), BINPATHs, "UniformOutput", false);

[BLOCKPATHs, SAVEPATHs] = deal(cell(nBatch, 1));
fs = nan(nBatch, 1);
for rIndex = 1:nBatch
    BLOCKPATHs{rIndex} = cellstr(params(rIndex).BLOCKPATH);
    sitePos = params(rIndex).sitePos;
    fs(rIndex) = params(rIndex).SR_AP; % Hz

    % ~\subject\date\Block-n
    [~, TANKNAMEs, ~] = arrayfun(@(x) mu.getlastpath(x, 3), params(rIndex).BLOCKPATH, "UniformOutput", false);
    % ~\subject\date
    TANKNAMEs = cellfun(@(x) strjoin(x(1:2), filesep), TANKNAMEs, "UniformOutput", false);

    % ~\paradigm\subject\date_sitePos
    % paradigm -> Block-n
    SAVEPATHs{rIndex} = arrayfun(@(x, y) fullfile(SAVEROOTPATH, x, strcat(y, '_', sitePos)), params(rIndex).paradigm, TANKNAMEs, "UniformOutput", false);
end

simThr = 0.7;
QThr = 0.15;
RThr = 0.05;
frThrMean = 1;
frThr0 = 0.5;

% loop for each result
[spikeTimes, clusterIdxs, dataTDT, TTL_Onset, tShift] = deal(cell(numel(RESPATHs), 1));
for rIndex = 1:numel(RESPATHs)
    % Read from NPY files
    RESPATH = RESPATHs{rIndex};
    spikeIdxMerge = double(readNPY(fullfile(RESPATH, 'spike_times.npy')));
    clusterIdxMerge = double(readNPY(fullfile(RESPATH, 'spike_clusters.npy')));
    idSimilar = readNPY(fullfile(RESPATH, 'similar_templates.npy'));

    % Exclude clusters with few spikes
    clusterUnique = unique(clusterIdxMerge);
    idSimilar = idSimilar(ismember(1:length(idSimilar), clusterUnique + 1), ismember(1:length(idSimilar), clusterUnique + 1));

    spikeTimeMerge  = spikeIdxMerge / fs(rIndex);
    spikeTrainMerge = arrayfun(@(x) spikeTimeMerge(clusterIdxMerge == x), clusterUnique, "UniformOutput", false);
    spikeFrMerge    = cellfun(@numel, spikeTrainMerge) / (sum(nsamples{rIndex}) / fs(rIndex));

    simCell = mCell2mat(cellfun(@(x, y) mNchoosek(find(all(spikeFrMerge(x > simThr) > frThr0) & x > simThr & ~ismember(1:length(idSimilar), y)), 1:sum(x > simThr)-1, y), num2cell(idSimilar, 2), num2cell(1:length(idSimilar))', "UniformOutput", false));
    if ~isempty(simCell)
        similarPool = mUniqueCell(simCell);
        segIdx = find(cellfun(@(x, y) max(x) < min(y), similarPool, [similarPool(2:end); similarPool(end)]));
        mergePool = cellfun(@(x) similarPool(x(1) : x(2)), num2cell([[1; segIdx+1], [segIdx; length(similarPool)]], 2), "UniformOutput", false);

        [K, Qi, Q00, Q01, rir] = cellfun(@(x) cellfun(@(y) ccg(cell2mat(spikeTrainMerge(ismember(1:length(clusterUnique), y)')), cell2mat(spikeTrainMerge(ismember(1:length(clusterUnique), y)')), 500, 1/1000), x, "UniformOutput", false), mergePool, "UniformOutput", false);
        Q = cellfun(@(x, y, z) cellfun(@(m, n, k) min(m/(max(n, k))), x, y, z), Qi, Q00, Q01,"UniformOutput",false);
        R = cellfun(@(x) cellfun(@(y) min(y), x), rir, "UniformOutput",false);
        accIdx = cellfun(@(x, y, z) find(x < QThr & y < RThr & cellfun(@(k) mean(spikeFrMerge(k)) > frThrMean, z)), Q, R, mergePool, "UniformOutput", false);
        % bestIdx : the largest set meeting the criterion or the min Q value in several sets with same size
        [~, bestIdx] = cellfun(@(x, y, z)  max(sum([2*(cellfun(@length, x(y)) == max(cellfun(@length, x(y)))), z(y)-min(z(y)) == 0], 2)), mergePool, accIdx, Q, "UniformOutput", false);
        mergeIdx = mCell2mat(cellfun(@(x, y, z, k) [x(y(z)) k(y(z))], mergePool, accIdx, bestIdx, Q, "UniformOutput", false));
        [~, idx]= mUniqueCell(cellfun(@(x) double(clusterUnique(x)), mergeIdx(:, 1), "UniformOutput", false));
        mergeIdx = mergeIdx(idx, :);

        if ~isempty(mergeIdx)
            mergeCluster = cellfun(@(x) clusterUnique(x), mergeIdx(:, 1), "UniformOutput", false);
            for index = 1 : length(mergeCluster)
                clusterIdxMerge(ismember(clusterIdxMerge, mergeCluster{index}(2:end))) = mergeCluster{index}(1);
                spikeFrMerge(mergeIdx{index}(1)) = mean(spikeFrMerge(mergeIdx{index}));
            end
            idToDel = spikeFrMerge < frThr0 | ismember(clusterUnique, cell2mat(cellfun(@(x) x(2:end), mergeCluster, "UniformOutput", false)));
        else
            idToDel = spikeFrMerge < frThr0;
        end
    else
        idToDel = spikeFrMerge < frThr0;
    end

    % Read from tsv file
    clusterInfo = readtable(fullfile(RESPATH, 'cluster_info.tsv'), ...
        'FileType', 'text', 'Delimiter', '\t');

    % Match cluster_id with channel
    id = clusterInfo.cluster_id;
    ch = clusterInfo.ch;
    idCh = sortrows([id, ch], 1);
    idCh(idToDel, :) = [];
    chs = unique(idCh(:, 2));
    for cIndex = 1 : length(chs)
        idx = find(idCh(:, 2) == chs(cIndex));
        for index = 1 :length(idx)
            idCh(idx(index), 2) = (index - 1) * 1000 + chs(cIndex);
        end
    end
    chIdxMerge = idCh(:, 2) + 1;

    idxReserve = ismember(clusterIdxMerge, idCh(:, 1));
    spikeIdxMerge = spikeIdxMerge(idxReserve);
    clusterIdxMerge = clusterIdxMerge(idxReserve);

    [~, loc] = ismember(clusterIdxMerge, idCh(:, 1));
    clusterIdxMerge = chIdxMerge(loc);

    % Loop for each paradigm
    nsample = [1; cumsum(nsamples{rIndex}(:)); inf];
    for pIndex = 1:numel(BLOCKPATHs{rIndex})
        % Align to start point of each block
        validIdx = spikeIdxMerge >= nsample(pIndex) & spikeIdxMerge < nsample(pIndex + 1);
        spikeIdx = spikeIdxMerge(validIdx) - nsample(pIndex);
        clusterIdx = clusterIdxMerge(validIdx);

        % Read from Trigger file
        dataTDT{rIndex}{pIndex} = TDTbin2mat(BLOCKPATHs{rIndex}{pIndex}, 'TYPE', {'epocs'});
        if isfile(TRIGPATHs{rIndex}{pIndex}) % TTL.mat for RHD and NP
            load(TRIGPATHs{rIndex}{pIndex}, "board_dig_in_data", "TTL");
            try TTL = board_dig_in_data; end
            epocsNames = fieldnames(dataTDT{rIndex}{pIndex}.epocs);
            if any(matches(fieldnames(dataTDT{rIndex}{pIndex}.epocs), ["ordr", "ord0"]))
                tempField = string(epocsNames(matches(fieldnames(dataTDT{rIndex}{pIndex}.epocs), ["ordr", "ord0"])));
            else
                tempField = "Swep";
            end

            trialNum = numel(dataTDT{rIndex}{pIndex}.epocs.(tempField).onset);
            TDTStim  = dataTDT{rIndex}{pIndex}.epocs.(tempField);
            TTL_Onset_temp = find(diff(TTL) > 0.9) + 1; % rise edges of digital signal
            TTL_Onset_temp(find(diff(TTL_Onset_temp) < 0.05) + 1) = [];

            if trialNum ~= numel(TTL_Onset_temp)
                TTL_Temp   = TTL_Onset_temp' / fs; % for checking
                checkPool1 = [{TTL_Temp}, {TDTStim.onset}]; % stim time point; column 1: recording; column 2: TDT
                checkPool2 = [{diff(TTL_Temp)}', {diff(TDTStim.onset)}]; % ISI; column 1: recording; column 2: TDT
                % Correct variable [TTL_Onset_temp]
                keyboard;
                isContinue = validateInput('Continue? (y/n): ', @(x) matches(x, ["n", "y"], "IgnoreCase", true), 's');
                if matches(isContinue, ["n", "N"])
                    assert(trialNum == numel(TTL_Onset_temp), "The TTL sync signal does not match the TDT epocs [Swep] store!");
                end
            end

            % Align TDT trigger with TTL trigger
            nShift = TTL_Onset_temp(1) - roundn(dataTDT{rIndex}{pIndex}.epocs.(tempField).onset(1) * fs(rIndex), 0);
            TTL_Onset{rIndex}{pIndex} = (TTL_Onset_temp - nShift) / fs(rIndex); % sec

        else % Use TDT trigger
            nShift = 0;
            TTL_Onset{rIndex}{pIndex} = dataTDT{rIndex}{pIndex}.epocs.(tempField).onset; % sec
        end

        spikeTimes{rIndex}{pIndex} = (spikeIdx - nShift) / fs(rIndex); % sec
        clusterIdxs{rIndex}{pIndex} = clusterIdx;
        tShift{rIndex}(pIndex) = nShift / fs(rIndex); % sec

        exported = params(rIndex).spkExported(pIndex);

        if exported && skipSpkExportExisted
            continue;
        end

        data = [];
        data.epocs = dataTDT{rIndex}{pIndex}.epocs;
        data.sortdata = [spikeTimes{rIndex}{pIndex}, clusterIdxs{rIndex}{pIndex}];
        data.TTL_Onset = TTL_Onset{rIndex}{pIndex};
        data.fs = fs(rIndex);
        data.params = params(rIndex);

        if ~exist(SAVEPATHs{rIndex}{pIndex}, "dir")
            mkdir(SAVEPATHs{rIndex}{pIndex});
        end

        save(fullfile(SAVEPATHs{rIndex}{pIndex}, 'spkData.mat'), "data");

        % update Excel
        idx = find(str2double(tbl.ID) == sortIDs(rIndex));
        tbl.spkExported(idx(pIndex)) = "1";
        writetable(tbl, EXCELPATH);
    end
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
        temp = cellfun(@(x) num2cell(nchoosek(data, x), 2), num2cell(nPool)', "UniformOutput", false);
        temp = cat(1, temp{:});
        groups = cellfun(@(y) [header, y], temp, "UniformOutput", false);
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

function A = mCell2mat(C)
    % Elements of C can be cell/string/numeric
    
    [a, b] = size(C);
    
    if a == 1 % for row vector
        A = cat(2, C{:});
    elseif b == 1 % for column vector
        A = cat(1, C{:});
    else % for 2-D matrix
        temp = mu.rowfun(@(x) cat(2, x{:}), C, "UniformOutput", false);
        A = cat(1, temp{:});
    end
    
    return;
end

function str = mat2cellStr(mat)
    [Col, Raw] = size(mat);
    str = cellfun(@(x) num2str(x), num2cell(mat), "UniformOutput", false);
    str = reshape(str, [Col, Raw]);
    return;
end