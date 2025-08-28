function [BINPATHs, TRIGPATHs, nch] = mu_ks4_exportBins(EXCELPATH, sortIDs, FORMAT, skipBinExportExisted)
% Read parameters from Excel file
params = mu_ks4_getParamsExcel(EXCELPATH, sortIDs);

% loop for each sort ID
[BINPATHs, TRIGPATHs] = deal(cell(numel(params), 1));
for index = 1:numel(params)
    % Convert data to bin files
    BLOCKPATHs = params(index).BLOCKPATH;
    DATAPATHs = params(index).datPath;
    recTech = params(index).recTech;

    % normalize paths
    BLOCKPATHs = cellfun(@mu.getabspath, BLOCKPATHs, "UniformOutput", false);

    % Export to binary data
    switch lower(recTech)
        case 'tdt'
            [BINPATHs{index}, nch] = mu_ks4_getBins_TDT(BLOCKPATHs, "Format", FORMAT, "SkipExisted", skipBinExportExisted);
            TRIGPATHs{index} = BLOCKPATHs{index};
        case 'rhd'
            [BINPATHs{index}, TRIGPATHs{index}] = mu_ks4_getBins_RHD(DATAPATHs, "Format", FORMAT, "SkipExisted", skipBinExportExisted);
            nch = 128;
        case {'neuropixel', 'neuropixels', 'np'}
            [BINPATHs{index}, TRIGPATHs{index}] = mu_ks4_getBins_NP(DATAPATHs, skipBinExportExisted);
            nch = 385;
        otherwise
            error('Unsupported type: %s', recTech);
    end

end

return;
end