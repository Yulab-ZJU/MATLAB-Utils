function [BINPATHs, TRIGPATHs, nch] = mu_ks4_exportBins(EXCELPATH, sortIDs, FORMAT, skipBinExportExisted)
% Read parameters from Excel file
sortIDs = unique(sortIDs);
params = mu_ks4_getParamsExcel(EXCELPATH, sortIDs);
nBatch = numel(params);

% loop for each sort ID
[BINPATHs, TRIGPATHs] = deal(cell(nBatch, 1));
for rIndex = 1:nBatch
    % Convert data to bin files
    BLOCKPATHs = params(rIndex).BLOCKPATH;
    DATAPATHs = params(rIndex).datPath;
    recTech = params(rIndex).recTech;

    % normalize paths
    BLOCKPATHs = cellfun(@mu.getabspath, BLOCKPATHs, "UniformOutput", false);

    % Export to binary data
    switch lower(recTech)
        case 'tdt'
            [BINPATHs{rIndex}, nch] = mu_ks4_getBins_TDT(BLOCKPATHs, "Format", FORMAT, "SkipExisted", skipBinExportExisted);
            TRIGPATHs{rIndex} = BLOCKPATHs{rIndex};
        case 'rhd'
            [BINPATHs{rIndex}, TRIGPATHs{rIndex}] = mu_ks4_getBins_RHD(DATAPATHs, "Format", FORMAT, "SkipExisted", skipBinExportExisted);
            nch = 128;
        case {'neuropixel', 'neuropixels', 'np'}
            [BINPATHs{rIndex}, TRIGPATHs{rIndex}] = mu_ks4_getBins_NP(DATAPATHs, skipBinExportExisted);
            nch = 385;
        otherwise
            error('Unsupported type: %s', recTech);
    end

end

return;
end