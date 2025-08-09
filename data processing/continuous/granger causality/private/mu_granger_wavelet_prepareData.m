function data = mu_granger_wavelet_prepareData(cwtres, f, coi, fs, fRange)
% Prepare data for pairwise ganger causality computation using wavelet transform.
% [cwtres] is a nTrial*nCh*nFreq*nTime matrix.
% The first channel is 'seed' and the rest channels are 'target'.
% [f] is a descendent column vector in log scale.

narginchk(4, 5);

if nargin < 5
    fRange = [];
end

disp('Using existed cwt data...');
[nTrial, nCh, nFreq, nTime] = size(cwtres);

if numel(fRange) == 2 && fRange(2) > fRange(1)
    idx = find(f <= fRange(2), 1):find(f >= fRange(1), 1, "last");
    if ~isempty(idx)
        f = f(idx);
        cwtres = cwtres(:, :, idx, :); % rpt_chan_freq_time
    else
        error("Frequency range not found");
    end
end

% trans log-scaled [f] to linear-spaced and pad with zero
% cwt returns [f] as a descendent column vector
f = 10 * log(f);
c = 0 - f(end);
f = f + c;

data = [];
data.freq = f;
data.time = (0:nTime - 1) / fs;
data.label = [{'seed'}; cellstr(num2str((1:nCh - 1)'))];
data.dimord = 'rpt_chan_freq_time';
data.cumtapcnt = ones(nTime, length(f));
data.fourierspctrm = cwtres;
data.coi = coi;
data.c = c; % shift in [f]

return;
end