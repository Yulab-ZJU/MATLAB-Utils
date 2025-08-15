function [latency, P, spikes] = mu_calLatency(trials, windowOnset, windowBase, th, nStart, tTh)
% Return latency of neuron using spike data.
%
% If [trials] is a struct array, it should contain field [spike] for each trial.
% If [trials] is a cell array, its element contains spikes of each trial.
% [windowBase] and [windowOnset] are two-element vectors in millisecond.
% [th] for picking up [latency] from Poisson cumulative probability (default: 1e-6).
% [nStart] for skipping (nStart-1) spikes at the beginning (default: 5).
% [tTh] defines the maximum latency to be accepted, in ms (default: 50).
%
% REFERENCE doi: 10.1073/pnas.0610368104

narginchk(3, 6);

validateattributes(windowOnset, 'numeric', {'numel', 2, 'increasing'});
validateattributes(windowBase, 'numeric', {'numel', 2, 'increasing'});

if nargin < 4
    th = 1e-6;
end

if nargin < 5
    nStart = 5;
end

if nargin < 6
    tTh = 50;
end

validateattributes(th, 'numeric', {'scalar', 'positive', '<', 1});
validateattributes(nStart, 'numeric', {'scalar', 'positive', 'integer'});
validateattributes(tTh, 'numeric', {'scalar', 'positive'});

trials = reshape(trials, [numel(trials), 1]);
switch class(trials)
    case "cell"
        if any(~cellfun(@isvector, trials))
            error("All trial spike data should be a vector. Please select spike data from one cluster.");
        end
        
        temp = cellfun(@(x) x(:), trials, "UniformOutput", false);
    case "struct"
        if any(arrayfun(@(x) ~isvector(x.spike), trials))
            error("All trial spike data should be a vector. Please select spike data from one cluster.");
        end

        temp = arrayfun(@(x) x.spike(:), trials, "UniformOutput", false);
end
spikes = cat(1, temp{:});
sprate = mean(mu_calFR(trials, windowBase));
spikes = sort(spikes(spikes >= windowOnset(1) & spikes <= windowOnset(2)), "ascend");

n = nStart:numel(spikes);
spikes = spikes(nStart:end);
lambda = numel(trials) * sprate * spikes / 1000;

% Vectorized calculation of Poisson cumulative probability
P = 1 - poisscdf(n' - 1, lambda);

latency = spikes(find(P < th & spikes < tTh, 1));
return;
end