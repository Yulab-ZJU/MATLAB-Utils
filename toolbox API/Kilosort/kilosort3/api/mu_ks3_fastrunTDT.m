function mu_ks3_fastrunTDT(BLOCKPATHs, paradigms, SAVEROOTPATH, opts)

% Arguments check
arguments
    BLOCKPATHs                (1,:) {mustBeFolder}
    paradigms                 (1,:) {mustBeText}
    SAVEROOTPATH              {mustBeTextScalar}

    opts.th                   (1,2) double {mustBePositive} = [8, 7]
    opts.nch                  (1,1) double {mustBePositive, mustBeInteger} = []
    opts.resultsDir           {mustBeTextScalar} = ''

    opts.skipBinExportExisted (1,1) logical = true
    opts.skipSortExisted      (1,1) logical = true
    opts.KeepWhFile           (1,1) logical = false
    opts.skipMatExportExisted (1,1) logical = true

    opts.FORMAT               {mustBeTextScalar} = 'i16'
    opts.badChs               (1,:) double {mustBePositive} = []
    opts.sitePos              {mustBeTextScalar} = ''

    opts.TrigField            {mustBeTextScalar} = 'Swep'
end
BLOCKPATHs = cellstr(BLOCKPATHs);
assert(numel(paradigms) == numel(BLOCKPATHs), 'The number of paradigms must match the number of BLOCKs.');
opts.FORMAT = validatestring(opts.FORMAT, {'i16', 'f32'});

% Init result dir path
if isempty(opts.resultsDir)
    [~, ~, BLOCKNUMs] = cellfun(@(x) mu.getlastpath(x, 1), BLOCKPATHs, "UniformOutput", false);
    BLOCKNUMs = cellfun(@(x) split(x, '-'), BLOCKNUMs, "UniformOutput", false);
    BLOCKNUMs = cellfun(@(x) x{end}, BLOCKNUMs, "UniformOutput", false);
    opts.resultsDir = fullfile(mu.getrootpath(BLOCKPATHs{1}, 1), ['Merge ', strjoin(BLOCKNUMs, '_')]);
end

% File check
skipSorting = false;
if exist(fullfile(opts.resultsDir, "spike_times.npy"), "file")
    fprintf('Result folder %s already exists.\n', opts.resultsDir);
    if ~opts.skipSortExisted
        disp('Delete result folder and re-sorting...');
        rmdir(opts.resultsDir, "s");
    else
        disp('Skip sorted.');
        skipSorting = true;
    end
end

% --------------- Start of sorting ---------------
% Generate bin files
if ~exist(opts.resultsDir, "dir")
    mkdir(opts.resultsDir);
end
[BINPATHs, nch, fs] = mu_ks_getBins_TDT(BLOCKPATHs, "Format", opts.FORMAT, "SkipExisted", opts.skipBinExportExisted);

if ~skipSorting
    [MERGEPATH, isMerged] = mu_ks_mergeBinFiles(fullfile(opts.resultsDir, 'MergeWave.bin'), BINPATHs{:});
    
    if isempty(opts.nch)
        opts.nch = nch;
    end

    % Get kilosort3 configuration
    config = mu_ks3_config("NchanTOT", nch, ...
        "fs", fs, ...
        "chanMap", mu_ks3_getChanMap(opts.nch, opts.badChs), ...
        "Th", opts.th);
    
    % Run ks3
    mu_kilosort3(MERGEPATH, config, opts.resultsDir, "KeepWhFile", opts.KeepWhFile);
    
    % Generate cluster_info.tsv
    mu_ks_genClusterInfo(opts.resultsDir, fs);
    
    % Delete merge bin file
    if isMerged
        delete(MERGEPATH);
    end
end
% --------------- End of sorting ---------------

% --------------- Start of exporting MAT ---------------
% Get data length of each binary file
nsamples = cellfun(@(x) mu_ks_getBinDataLength(x, nch, opts.FORMAT), BINPATHs);

% ~\subject\date\Block-n
[~, TANKNAMEs, ~] = cellfun(@(x) mu.getlastpath(x, 3), BLOCKPATHs, "UniformOutput", false);
% ~\subject\date
TANKNAMEs = cellfun(@(x) strjoin(x(1:2), filesep), TANKNAMEs, "UniformOutput", false);

% ~\paradigm\subject\date_sitePos
% paradigm -> Block-n
if isempty(opts.sitePos)
    SAVEPATHs = cellfun(@(x, y) fullfile(SAVEROOTPATH, x, y), paradigms, TANKNAMEs, "UniformOutput", false);
else
    SAVEPATHs = cellfun(@(x, y) fullfile(SAVEROOTPATH, x, strcat(y, '_', opts.sitePos)), paradigms, TANKNAMEs, "UniformOutput", false);
end

if all(cellfun(@(x) exist(fullfile(x, 'spkData.mat'), "file"), SAVEPATHs)) && opts.skipMatExportExisted
    return;
end

simThr = 0.7;
QThr = 0.15;
RThr = 0.05;
frThrMean = 1;
frThr0 = 0.5;

% Read from NPY files
spikeIdxMerge   = double(readNPY(fullfile(opts.resultsDir, 'spike_times.npy')));
clusterIdxMerge = double(readNPY(fullfile(opts.resultsDir, 'spike_clusters.npy')));
idSimilar       = readNPY(fullfile(opts.resultsDir, 'similar_templates.npy'));

% Exclude clusters with few spikes
clusterUnique = unique(clusterIdxMerge);
idSimilar = idSimilar(ismember(1:length(idSimilar), clusterUnique + 1), ismember(1:length(idSimilar), clusterUnique + 1));

spikeTimeMerge  = spikeIdxMerge / fs;
spikeTrainMerge = arrayfun(@(x) spikeTimeMerge(clusterIdxMerge == x), clusterUnique, "UniformOutput", false);
spikeFrMerge    = cellfun(@numel, spikeTrainMerge) / (sum(nsamples) / fs);

simCell = mu.cell2mat(cellfun(@(x, y) mu.nchoosek(find(all(spikeFrMerge(x > simThr) > frThr0) & x > simThr & ~ismember(1:length(idSimilar), y)), 1:sum(x > simThr)-1, y), num2cell(idSimilar, 2), num2cell(1:length(idSimilar))', "UniformOutput", false));
if ~isempty(simCell)
    similarPool = mu.uniquecell(simCell);
    segIdx = find(cellfun(@(x, y) max(x) < min(y), similarPool, [similarPool(2:end); similarPool(end)]));
    mergePool = cellfun(@(x) similarPool(x(1) : x(2)), num2cell([[1; segIdx+1], [segIdx; length(similarPool)]], 2), "UniformOutput", false);

    [~, Qi, Q00, Q01, rir] = cellfun(@(x) cellfun(@(y) ccg(cell2mat(spikeTrainMerge(ismember(1:length(clusterUnique), y)')), cell2mat(spikeTrainMerge(ismember(1:length(clusterUnique), y)')), 500, 1/1000), x, "UniformOutput", false), mergePool, "UniformOutput", false);
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
clusterInfo = readtable(fullfile(opts.resultsDir, 'cluster_info.tsv'), 'FileType', 'text', 'Delimiter', '\t');

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
[dataTDT, TTL_Onset, spikeTimes, clusterIdxs] = deal(cell(numel(BLOCKPATHs), 1));
nsample = [1; cumsum(nsamples(:)); inf];
for pIndex = 1:numel(BLOCKPATHs)
    % Align to start point of each block
    validIdx = spikeIdxMerge >= nsample(pIndex) & spikeIdxMerge < nsample(pIndex + 1);
    spikeIdx = spikeIdxMerge(validIdx) - nsample(pIndex);
    clusterIdx = clusterIdxMerge(validIdx);

    % Read from Trigger file
    dataTDT{pIndex} = TDTbin2mat(BLOCKPATHs{pIndex}, 'TYPE', {'epocs'});

    % Use TDT trigger
    TTL_Onset{pIndex} = dataTDT{pIndex}.epocs.(opts.TrigField).onset; % sec

    % Trigger aligment
    spikeTimes{pIndex} = spikeIdx / fs; % sec
    clusterIdxs{pIndex} = clusterIdx;

    if exist(fullfile(SAVEPATHs{pIndex}, 'spkData.mat'), "file") && opts.skipMatExportExisted
        continue;
    end

    data = [];
    data.epocs = dataTDT{pIndex}.epocs;
    data.sortdata = [spikeTimes{pIndex}, clusterIdxs{pIndex}];
    data.TTL_Onset = TTL_Onset{pIndex};
    data.fs = fs;

    if ~exist(SAVEPATHs{pIndex}, "dir")
        mkdir(SAVEPATHs{pIndex});
    end

    save(fullfile(SAVEPATHs{pIndex}, 'spkData.mat'), "data");
end
% --------------- End of exporting MAT ---------------

return;
end