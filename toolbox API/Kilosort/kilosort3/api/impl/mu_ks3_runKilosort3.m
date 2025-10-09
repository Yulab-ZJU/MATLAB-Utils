function resultDirs = mu_ks3_runKilosort3(BINPATHs, EXCELPATH, sortIDs, th, skipSortExisted)
% Read parameters from Excel file
sortIDs = unique(sortIDs);
[params, tbl] = mu_ks_getParamsExcel(EXCELPATH, sortIDs);
nBatch = numel(params);

% Loop for each sort ID
resultDirs = cell(nBatch, 1);
for rIndex = 1:nBatch
    sorted = params(rIndex).sort;
    BLOCKPATHs = params(rIndex).BLOCKPATH;
    fs = params(rIndex).SR_AP;
    nCh = params(rIndex).chNum;
    badChs = params(rIndex).badChannel;

    % Init result dir path
    [~, ~, BLOCKNUMs] = cellfun(@(x) mu.getlastpath(x, 1), BLOCKPATHs, "UniformOutput", false);
    BLOCKNUMs = cellfun(@(x) split(x, '-'), BLOCKNUMs, "UniformOutput", false);
    BLOCKNUMs = cellfun(@(x) x{end}, BLOCKNUMs, "UniformOutput", false);
    resultDirs{rIndex} = fullfile(mu.getrootpath(BLOCKPATHs{1}, 1), ['Merge ', strjoin(BLOCKNUMs, '_')]);
    
    % Skip sorted
    if all(sorted) && skipSortExisted
        continue;
    end

    if exist(fullfile(resultDirs{rIndex}, "spike_times.npy"), "file")
        fprintf('Result folder %s already exists.\n', resultDirs{rIndex});
        if ~skipSortExisted
            disp('Delete result folder and re-sorting...');
            rmdir(resultDirs{rIndex}, "s");
        else
            disp('Skip sorted.');
            continue;
        end
    end

    % Generate merge bin file
    if ~exist(resultDirs{rIndex}, "dir")
        mkdir(resultDirs{rIndex});
    end
    [MERGEPATH, isMerged] = mu_ks_mergeBinFiles(fullfile(resultDirs{rIndex}, 'MergeWave.bin'), BINPATHs{rIndex}{:});

    % Get kilosort3 configuration
    ops = mu_ks3_config("NchanTOT", nCh, ...
                        "fs", fs, ...
                        "chanMap", mu_ks3_getChanMap(nCh, badChs), ...
                        "Th", th);

    % Run kilosort3
    mu_kilosort3(MERGEPATH, ops, resultDirs{rIndex});

    % Generate cluster_info.tsv
    mu_ks_genClusterInfo(resultDirs{rIndex}, fs);

    % Update Excel file
    tbl.sort(str2double(tbl.ID) == sortIDs(rIndex)) = "1";
    writetable(tbl, EXCELPATH);

    % Delete merge bin file
    if isMerged
        delete(MERGEPATH);
    end
    
end

return;
end