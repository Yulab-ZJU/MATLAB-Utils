function trialAll = mu_preprocess_generalProcessFcn(trialsData, rules)
% This function is to process trial data recorded by EEG App

if isempty(trialsData)
    trialAll = [];
    return;
end

trialAll = struct("trialNum", num2cell((1:numel(trialsData))'));
idx = arrayfun(@(x) find(rules.code == x), [trialsData.code]');
for vIndex = 1:length(rules.Properties.VariableNames)
    paramName = rules.Properties.VariableNames{vIndex};
    trialAll = mu.addfield(trialAll, paramName, rules(idx, :).(paramName));
end
trialAll = mu.addfield(trialAll, "RT", arrayfun(@(x) x.push - x.offset, trialsData(:), "UniformOutput", false));
trialAll = mu.addfield(trialAll, "key", {trialsData.key}');

return;
end