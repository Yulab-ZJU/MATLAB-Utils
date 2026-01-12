function trialAll = mu_unwrapTrialEvents(trialAll, opts)
% Unwrap [trialAll] with event flow
%   [trialAll] should contain .events and .trialIndex

arguments
    trialAll (:,1) struct
    opts.type {mustBeText} = ''
end

assert(isfield(trialAll, "trialIndex"), "[trialAll] should contain field .trialIndex");
assert(isfield(trialAll, "events"), "[trialAll] should contain field .events");
assert(isfield(trialAll(1).events, "type"), "field .events should include .type");

% Unwrap all
trialAll = arrayfun(@(x) mu.addfield(x.events, "trialIndex", num2cell(repmat(x.trialIndex, numel(x.events), 1))), trialAll, "UniformOutput", false);
trialAll = cat(1, trialAll{:});
trialAll = orderfields(trialAll, ["trialIndex"; setdiff(fieldnames(trialAll), "trialIndex", 'stable')]);

types = unique(cellstr({trialAll.type}'), 'stable');
opts.type = cellstr(opts.type);
idx = matches(types, opts.type);

if any(idx)
    trialAll = trialAll(matches(cellstr({trialAll.type}'), opts.type(:)));
end

return;
end