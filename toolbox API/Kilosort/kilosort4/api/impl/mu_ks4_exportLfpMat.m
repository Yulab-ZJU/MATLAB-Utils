function mu_ks4_exportLfpMat(EXCELPATH, ...
                             sortIDs, ...
                             SAVEROOTPATH, ...
                             BINPATHs, ...
                             dataTDT, ...
                             FORMAT, ...
                             nch, ...
                             tShift, ...
                             fsLFP, ...
                             skipLfpExportExisted)

% Read parameters from Excel file
sortIDs = unique(sortIDs);
[params, tbl] = mu_ks_getParamsExcel(EXCELPATH, sortIDs);
nBatch = numel(params);

% loop for each sort ID
for rIndex = 1:nBatch
    sitePos = params(rIndex).sitePos;
    fs = params(rIndex).SR_AP; % Hz
    
    % Init paths
    % BLOCKPATH is '~\subject\date\Block-n'
    [~, TANKNAMEs, ~] = arrayfun(@(x) mu.getlastpath(x, 3), params(rIndex).BLOCKPATH, "UniformOutput", false);
    TANKNAMEs = cellfun(@(x) strjoin(x(1:2), filesep), TANKNAMEs, "UniformOutput", false);
    % SAVEPATH is '~\paradigm\subject\date_sitePos\lfpData.mat', where 'paradigm' refers to 'Block-n'
    SAVEPATHs = arrayfun(@(x, y) fullfile(SAVEROOTPATH, x, strcat(y, '_', sitePos)), params(rIndex).paradigm, TANKNAMEs, "UniformOutput", false);

    % Export LFP: loop for each block
    for pIndex = 1:numel(SAVEPATHs)
        if params(rIndex).lfpExported(pIndex) && skipLfpExportExisted
            continue;
        end

        if ~exist(SAVEPATHs{pIndex}, "dir")
            mkdir(SAVEPATHs{pIndex});
        end

        nSkip = roundn(tShift{rIndex}(pIndex) * fs, 0);
        outMat = fullfile(SAVEPATHs{pIndex}, 'lfpData.mat');
        mu_ks_bin2lfp(BINPATHs{rIndex}{pIndex}, outMat, nch, fs, ...
                       'SkipPoints', nSkip, ...
                       'FORMAT', FORMAT, ...
                       'fsLFP', fsLFP);

        % export triggers
        mf = matfile(outMat, 'Writable', true);
        data = dataTDT{rIndex}{pIndex};
        mf.data = data;

        % update Excel
        idx = find(str2double(tbl.ID) == sortIDs(rIndex));
        tbl.lfpExported(idx(pIndex)) = "1";
        writetable(tbl, EXCELPATH);
    end

end

return;
end