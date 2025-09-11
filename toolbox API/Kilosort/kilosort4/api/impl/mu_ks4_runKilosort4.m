function resultDirs = mu_ks4_runKilosort4(BINPATHs, EXCELPATH, sortIDs, FORMAT, th, skipSortExisted)
% Read parameters from Excel file
sortIDs = unique(sortIDs);
[params, tbl] = mu_ks4_getParamsExcel(EXCELPATH, sortIDs);
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
    
    % Get kilosort configuration
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
    [settings, opts] = mu_ks4_getConfig(BINPATHs{rIndex}, resultDirs{rIndex}, nCh, FORMAT, fs, th, badChs);

    % Run kilosort4
    mu_kilosort4(settings, opts);

    % Generate cluster_info.tsv
    mu_ks_genClusterInfo(opts.results_dir, fs);

    % Update Excel file
    tbl.sort(str2double(tbl.ID) == sortIDs(rIndex)) = "1";
    writetable(tbl, EXCELPATH);
end

return;
end