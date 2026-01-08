function [spikeTimes, clusterIdxs, dataTDT, tShift] = ...
    mu_ks_exportSpkMat(EXCELPATH, ...
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
[params, tbl] = mu_ks_getParamsExcel(EXCELPATH, sortIDs);
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

    simCell = mu.cell2mat(cellfun(@(x, y) mu.nchoosek(find(all(spikeFrMerge(x > simThr) > frThr0) & x > simThr & ~ismember(1:length(idSimilar), y)), 1:sum(x > simThr)-1, y), num2cell(idSimilar, 2), num2cell(1:length(idSimilar))', "UniformOutput", false));
    if ~isempty(simCell)
        similarPool = mu.uniquecell(simCell);
        segIdx = find(cellfun(@(x, y) max(x) < min(y), similarPool, [similarPool(2:end); similarPool(end)]));
        mergePool = cellfun(@(x) similarPool(x(1) : x(2)), num2cell([[1; segIdx+1], [segIdx; length(similarPool)]], 2), "UniformOutput", false);

        [K, Qi, Q00, Q01, rir] = cellfun(@(x) cellfun(@(y) ccg(cell2mat(spikeTrainMerge(ismember(1:length(clusterUnique), y)')), cell2mat(spikeTrainMerge(ismember(1:length(clusterUnique), y)')), 500, 1/1000), x, "UniformOutput", false), mergePool, "UniformOutput", false);
        Q = cellfun(@(x, y, z) cellfun(@(m, n, k) min(m/(max(n, k))), x, y, z), Qi, Q00, Q01,"UniformOutput",false);
        R = cellfun(@(x) cellfun(@(y) min(y), x), rir, "UniformOutput",false);
        accIdx = cellfun(@(x, y, z) find(x < QThr & y < RThr & cellfun(@(k) mean(spikeFrMerge(k)) > frThrMean, z)), Q, R, mergePool, "UniformOutput", false);
        % bestIdx : the largest set meeting the criterion or the min Q value in several sets with same size
        [~, bestIdx] = cellfun(@(x, y, z)  max(sum([2*(cellfun(@length, x(y)) == max(cellfun(@length, x(y)))), z(y)-min(z(y)) == 0], 2)), mergePool, accIdx, Q, "UniformOutput", false);
        mergeIdx = mu.cell2mat(cellfun(@(x, y, z, k) [x(y(z)) k(y(z))], mergePool, accIdx, bestIdx, Q, "UniformOutput", false));
        [~, idx]= mu.uniquecell(cellfun(@(x) double(clusterUnique(x)), mergeIdx(:, 1), "UniformOutput", false));
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

            temp = TreeItem("epocs");
            for eIndex = 1:numel(epocsNames)
                temp.addChild(epocsNames{eIndex});
            end
            ckl = checklist(temp);
            uiwait(ckl.UIFigure, 20);
            epocsNameSelected = ckl.selectedData;
            delete(ckl);
            if isempty(epocsNameSelected)
                % auto-determine
                if any(matches(fieldnames(dataTDT{rIndex}{pIndex}.epocs), ["ordr", "ord0"]))
                    tempField = string(epocsNames(matches(fieldnames(dataTDT{rIndex}{pIndex}.epocs), ["ordr", "ord0"])));
                else
                    tempField = "Swep";
                end
            else
                tempField = {ckl.selectedData.Text};
                if numel(tempField) > 1
                    warning("Please select only one epocs field. Use the first selected field.");
                    tempField = tempField{1};
                end
            end

            trialNum = numel(dataTDT{rIndex}{pIndex}.epocs.(tempField).onset);
            TDTStim  = dataTDT{rIndex}{pIndex}.epocs.(tempField);
            TTL_Onset_temp = find(diff(TTL) > 0.9) + 1; % rise edges of digital signal
            TTL_Onset_temp(find(diff(TTL_Onset_temp) < 0.05) + 1) = [];

            % if trialNum ~= numel(TTL_Onset_temp)
            %     TTL_Temp   = TTL_Onset_temp' / fs; % for checking
            %     checkPool1 = [{TTL_Temp}, {TDTStim.onset}]; % stim time point; column 1: recording; column 2: TDT
            %     checkPool2 = [{diff(TTL_Temp)}', {diff(TDTStim.onset)}]; % ISI; column 1: recording; column 2: TDT
            %     % Correct variable [TTL_Onset_temp]
            %     keyboard;
            %     isContinue = validateInput('Continue? (y/n): ', @(x) matches(x, ["n", "y"], "IgnoreCase", true), 's');
            %     if matches(isContinue, ["n", "N"])
            %         assert(trialNum == numel(TTL_Onset_temp), "The TTL sync signal does not match the TDT epocs [Swep] store!");
            %     end
            % end

            % Align TDT trigger with TTL trigger
            nShift = TTL_Onset_temp(1) - roundn(dataTDT{rIndex}{pIndex}.epocs.(tempField).onset(1) * fs(rIndex), 0);
            TTL_Onset{rIndex}{pIndex} = (TTL_Onset_temp - nShift) / fs(rIndex); % sec

        else % Use TDT trigger
            nShift = 0;
            TTL_Onset{rIndex}{pIndex} = dataTDT{rIndex}{pIndex}.epocs.(tempField).onset; % sec
        end

        % Trigger aligment
        spikeTimes{rIndex}{pIndex} = (spikeIdx - nShift) / fs(rIndex); % sec
        clusterIdxs{rIndex}{pIndex} = clusterIdx;
        tShift{rIndex}(pIndex) = nShift / fs(rIndex); % sec

        % Export to MAT
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