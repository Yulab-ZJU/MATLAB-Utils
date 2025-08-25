function resultDirs = section_runKilosort4(BINPATHs, recordExcelPath, sortIDs, FORMAT, th, skipSortExisted)
% Read parameters from Excel file
[params, tbl] = getParamsExcel(recordExcelPath, sortIDs);

% Loop for each sort ID
resultDirs = cell(numel(params), 1);
for index = 1:numel(params)
    sorted = params(index).sort;

    % Skip sorted
    if all(sorted) && skipSortExisted
        continue;
    end

    BLOCKPATHs = params(index).BLOCKPATH;
    fs = params(index).SR_AP;
    nCh = params(index).chNum;
    badChs = params(index).badChannel;

    % Get kilosort configuration
    [~, ~, BLOCKNUMs] = cellfun(@(x) mu.getlastpath(x, 1), BLOCKPATHs, "UniformOutput", false);
    BLOCKNUMs = cellfun(@(x) split(x, '-'), BLOCKNUMs, "UniformOutput", false);
    BLOCKNUMs = cellfun(@(x) x{end}, BLOCKNUMs, "UniformOutput", false);
    resultDirs{index} = fullfile(mu.getrootpath(BLOCKPATHs{1}, 1), ['Merge ', join(BLOCKNUMs, '_')]);
    if exist(resultDirs{index}, "dir")
        fprintf('Result folder %s already exists.\n', resultDirs{index});
        if skipSortExisted
            delete(resultDirs{index});
        else
            disp('Skip sorted.');
            continue;
        end
    end
    [settings, opts] = getConfigKilosort4(BINPATHs{index}, resultDirs{index}, nCh, FORMAT, fs, th, badChs);

    % Run kilosort4
    kilosort4(settings, opts);

    % Update Excel file
    tbl(tbl.ID == sortIDs(index), :).sort = 1;
    writetable(tbl, recordExcelPath);
end

return;
end