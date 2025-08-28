function resultDirs = ks4_runKilosort4(BINPATHs, EXCELPATH, sortIDs, FORMAT, th, skipSortExisted)
% Read parameters from Excel file
[params, tbl] = getParamsExcel(EXCELPATH, sortIDs);

% Loop for each sort ID
resultDirs = cell(numel(params), 1);
for index = 1:numel(params)
    sorted = params(index).sort;
    BLOCKPATHs = params(index).BLOCKPATH;
    fs = params(index).SR_AP;
    nCh = params(index).chNum;
    badChs = params(index).badChannel;

    % Init result dir path
    [~, ~, BLOCKNUMs] = cellfun(@(x) mu.getlastpath(x, 1), BLOCKPATHs, "UniformOutput", false);
    BLOCKNUMs = cellfun(@(x) split(x, '-'), BLOCKNUMs, "UniformOutput", false);
    BLOCKNUMs = cellfun(@(x) x{end}, BLOCKNUMs, "UniformOutput", false);
    resultDirs{index} = fullfile(mu.getrootpath(BLOCKPATHs{1}, 1), ['Merge ', strjoin(BLOCKNUMs, '_')]);
    
    % Skip sorted
    if all(sorted) && skipSortExisted
        continue;
    end
    
    % Get kilosort configuration
    if exist(resultDirs{index}, "dir")
        fprintf('Result folder %s already exists.\n', resultDirs{index});
        if ~skipSortExisted
            disp('Delete result folder and re-sorting...');
            rmdir(resultDirs{index}, "s");
        else
            disp('Skip sorted.');
            continue;
        end
    end
    [settings, opts] = getConfigKilosort4(BINPATHs{index}, resultDirs{index}, nCh, FORMAT, fs, th, badChs);

    % Run kilosort4
    kilosort4(settings, opts);

    % Update Excel file
    tbl.sort(tbl.ID == sortIDs(index)) = {'1'};
    writetable(tbl, EXCELPATH);
end

return;
end