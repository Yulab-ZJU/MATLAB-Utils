function fr = mu_calFR(trials, windowFR)
% If [trials] is a struct array, it should contain field [spike] for each trial.
% If [trials] is a cell array, its element contains spikes of each trial.
% If [trials] is a numeric vector, it is a spike vector.
% [fr] will be returned as a column vector, in Hz.
% [windowFR] is a two-element vector in millisecond.

validateattributes(windowFR, 'numeric', {'numel', 2, 'increasing'});

switch class(trials)
    case {'single', 'double'}
        if ~isvector(trials)
            error("All trial spike data should be a vector. Please select spike data from one cluster.");
        end

        fr = sum(trials >= windowFR(1) & trials <= windowFR(2)) / diff(windowFR) * 1000;
    case 'cell'
        if any(~cellfun(@isvector, trials))
            error("All trial spike data should be a vector. Please select spike data from one cluster.");
        end

        fr = cellfun(@(x) sum(x >= windowFR(1) & x <= windowFR(2)) / diff(windowFR) * 1000, trials);
    case 'struct'
        if any(arrayfun(@(x) ~isvector(x.spike), trials))
            error("All trial spike data should be a vector. Please select spike data from one cluster.");
        end

        fr = arrayfun(@(x) sum(x.spike >= windowFR(1) & x.spike <= windowFR(2)) / diff(windowFR) * 1000, trials);
end

return;
end