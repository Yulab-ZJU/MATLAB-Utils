function [params, tbl] = mu_ks4_getParamsExcel(recordExcelPath, ids)

arguments
    recordExcelPath {mustBeTextScalar}
    ids (:,1) {mustBeInteger, mustBePositive}
end

opts = detectImportOptions(recordExcelPath);
opts = setvartype(opts, 'string');
tbl = readtable(recordExcelPath, opts);
paramNames = tbl.Properties.VariableNames;
paramTypes = tbl(1, :);
paramTypes.ID = "double";

ids = unique(ids);
params = struct([]);
% loop for each id
for i = 1:numel(ids)
    idxCurrentID = ismember(str2double(tbl.ID), ids(i));
    assert(any(idxCurrentID), "No matched IDs found.");

    for pIndex = 1:numel(paramNames)
        paramName = paramNames{pIndex};
        paramVals = tbl.(paramName)(idxCurrentID);

        % type convertion
        if strcmpi(paramTypes.(paramName), 'double')
            if strcmpi(paramName, 'badChannel') && ~all(ismissing(paramVals))
                paramVals = cellfun(@(x) evalin("caller", x), paramVals);
            else
                paramVals = cellfun(@str2double, paramVals);
            end
        end

        params(i, 1).(paramName) = paramVals;
    end

    % scalar
    params(i).ID = ids(i);
    params(i).SR_AP = params(i).SR_AP(1);
    if isfield(params(i), "SR_LFP")
        params(i).SR_LFP = params(i).SR_LFP(1);
    end
    params(i).sitePos = params(i).sitePos(1);
    params(i).depth = params(i).depth(1);
    params(i).recTech = params(i).recTech(1);
    params(i).chNum = params(i).chNum(1);
    params(i).badChannel = params(i).badChannel(1);
    if isnan(params(i).badChannel)
        params(i).badChannel = [];
    end
    params(i).cf = params(i).cf(1);
    params(i).dz = params(i).dz(1);
    params(i).ks_ChSel = params(i).ks_ChSel(1);
    params(i).ks_ID = params(i).ks_ID(1);
    params(i).comments = params(i).comments(1);
end

return;
end