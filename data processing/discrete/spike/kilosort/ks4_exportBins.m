function [BINPATHs, TRIGPATHs, nch] = ks4_exportBins(recordExcelPath, sortIDs, FORMAT, skipBinExportExisted)
% Read parameters from Excel file
params = getParamsExcel(recordExcelPath, sortIDs);

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
            [BINPATHs{index}, nch] = TDT2bins(BLOCKPATHs, "Format", FORMAT, "SkipExisted", skipBinExportExisted);
            TRIGPATHs{index} = BLOCKPATHs{index};
        case 'rhd'
            [BINPATHs{index}, TRIGPATHs{index}] = RHD2bins(DATAPATHs, "Format", FORMAT, "SkipExisted", skipBinExportExisted);
            nch = 128;
        case {'neuropixel', 'neuropixels', 'np'}
            [BINPATHs{index}, TRIGPATHs{index}] = NP2bins(DATAPATHs, skipBinExportExisted);
            nch = 385;
        otherwise
            error('Unsupported type: %s', recTech);
    end

end

return;
end