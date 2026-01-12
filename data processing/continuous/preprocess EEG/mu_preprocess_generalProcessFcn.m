function trialAll = mu_preprocess_generalProcessFcn(trialsData, rules)
% This function is to process trial data recorded by EEG App

% Validate
pID = unique(rules.pID);
assert(isscalar(pID), "Rule file should include only one protocol");

if isempty(trialsData)
    trialAll = [];
    return;
end

if isfield(trialsData, "events")
    % New trialsData with field [trialIndex] and [events]
    % Multiple codes in one trial (possiblely)
    trialAll = insertRulesRowToEvents(trialsData, rules, ...
        "OnMissing", "warn", ...
        "OnDuplicate", "first", ...
        "ExcludeVars", "code");
else
    % Old version (will be aborted in a future release)
    % One trial - one code - one stimuli
    trialAll = struct("trialNum", num2cell((1:numel(trialsData))'));
    codeIdx = arrayfun(@(x) find(rules.code == x), [trialsData.code]');
    for vIndex = 1:length(rules.Properties.VariableNames)
        paramName = rules.Properties.VariableNames{vIndex};
        trialAll = mu.addfield(trialAll, paramName, rules.(paramName)(codeIdx));
    end
    trialAll = mu.addfield(trialAll, "RT", arrayfun(@(x) x.push - x.offset, trialsData(:), "UniformOutput", false));
    trialAll = mu.addfield(trialAll, "key", {trialsData.key}');
end

return;
end