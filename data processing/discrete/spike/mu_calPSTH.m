function [psth, edges] = mu_calPSTH(trials, windowPSTH, binSize, step)
% If [trials] is a struct array, it should contain field [spike] for each trial.
% If [trials] is a cell array, its element contains spikes of each trial.
% If [trials] is a numeric vector, it represents spike times in one trial.
% [psth] will be returned as a column vector, in Hz.
% [windowPSTH] is a two-element vector in millisecond.
% [binSize] and [step] are in millisecond.

validateattributes(windowPSTH, 'numeric', {'numel', 2, 'increasing'});
validateattributes(binSize, 'numeric', {'scalar', 'positive'});
validateattributes(step, 'numeric', {'scalar', 'positive'});

edges = windowPSTH(1) + binSize / 2:step:windowPSTH(2) - binSize / 2; % ms

switch class(trials)
    case {'double', 'single'}
        if ~isvector(trials)
            error("All trial spike data should be a vector. Please select spike data from one cluster.");
        end

        psth = mu.histcounts(trials, edges, binSize) / (binSize / 1000); % Hz
    case 'cell'
        if any(~cellfun(@(x) isvector(x) || isempty(x), trials))
            error("All trial spike data should be a vector. Please select spike data from one cluster.");
        end

        nTrials = numel(trials);
        trials = cellfun(@(x) x(:), trials, "UniformOutput", false);
        temp = cat(1, trials{:});
        psth = mu.histcounts(temp, edges, binSize) / (binSize / 1000) / nTrials; % Hz
    case 'struct'
        if any(~arrayfun(@(x) isvector(x.spike) || isempty(x.spike), trials))
            error("All trial spike data should be a vector. Please select spike data from one cluster.");
        end

        temp = arrayfun(@(x) x.spike(:), trials, "UniformOutput", false);
        psth = mu.histcounts(cat(1, temp{:}), edges, binSize) / (binSize / 1000) / numel(trials); % Hz
end

return;
end