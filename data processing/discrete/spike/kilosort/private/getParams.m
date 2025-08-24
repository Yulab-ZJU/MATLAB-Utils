function params = getParams(recordExcelPath, ids)

arguments
    recordExcelPath {mustBeTextScalar}
    ids (:,1) {mustBeInteger, mustBePositive}
end

tbl = readtable(recordExcelPath);
paramNames = tbl.Properties.VariableNames;
paramTypes = tbl(1, :);
paramTypes.ID = {'double'};

ids = unique(ids);
params = struct([]);
% loop for each id
for i = 1:numel(ids)
    idxCurrentID = ismember(tbl.ID, ids(i));
    assert(any(idxCurrentID), "No matched IDs found.");

    for pIndex = 1:numel(paramNames)
        paramName = paramNames{pIndex};
        paramVals = tbl.(paramName)(idxCurrentID);

        % type convertion
        if iscell(paramVals) && strcmpi(paramTypes.(paramName), 'double')
            paramVals = cellfun(@str2double, paramVals, "UniformOutput", false);
        end

        params(i, 1).(paramName) = paramVals;
    end

    % scalar
    params(i).ID = ids(i);
    params(i).SR_AP = params(i).SR_AP{1};
    params(i).SR_LFP = params(i).SR_LFP{1};
    params(i).sitePos = params(i).sitePos{1};
    params(i).depth = params(i).depth{1};
    params(i).recTech = params(i).recTech{1};
    params(i).chNum = params(i).chNum{1};
    params(i).badChannel = params(i).badChannel{1};
    params(i).cf = params(i).cf{1};
    params(i).dz = params(i).dz{1};
    params(i).ks_ChSel = params(i).ks_ChSel{1};
    params(i).ks_ID = params(i).ks_ID{1};
    params(i).comments = params(i).comments{1};

    % state flag
    params(i).sort = cat(1, params(i).sort{:});
    params(i).lfpExported = cat(1, params(i).lfpExported{:});
    params(i).spkExported = cat(1, params(i).spkExported{:});
end

return;
end