function [psth, edges] = mu_calPSTH(trials, windowPSTH, binSize, step)
% If [trials] is a struct array, it should contain field [spike] for each trial.
% If [trials] is a cell array, its element contains spikes of each trial.
% If [trials] is a numeric vector, it represents spike times in one trial.
% [psth] will be returned as a column vector.
% [windowPSTH] is a two-element vector in millisecond.
% [binSize] and [step] are in millisecond.

edges = windowPSTH(1) + binSize / 2:step:windowPSTH(2) - binSize / 2; % ms
trials = trials(:);

switch class(trials)
    case "cell"
        if any(cellfun(@(x) size(x, 2), trials) > 1)
            trials = cellfun(@(x) x(:, 1), trials, "UniformOutput", false);
        end

        trials = cellfun(@(x) x(:), trials, "UniformOutput", false);
        temp = cat(1, trials{:});
        nTrials = length(trials);
        psth = mu.histcounts(temp, edges, binSize) / (binSize / 1000) / nTrials; % Hz
    case "struct"
        temp = arrayfun(@(x) x.spike(:), trials, "UniformOutput", false);
        psth = mu.histcounts(cat(1, temp{:}), edges, binSize) / (binSize / 1000) / length(trials); % Hz
    case "double"
        if isvector(trials)
            psth = mu.histcounts(trials, edges, binSize) / (binSize / 1000);
        else
            error("Invalid trials input");
        end

end

return;
end