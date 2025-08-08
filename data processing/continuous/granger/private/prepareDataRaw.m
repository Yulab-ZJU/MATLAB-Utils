function data = prepareDataRaw(trialsDataSeed, trialsDataTarget, fs, fRange)
narginchk(3, 4);

if nargin < 4
    fRange = [];
end

%% Wavelet transform
disp('Performing cwt on data...');
t0 = tic;
trialsData = cellfun(@(x, y) [x; y], trialsDataSeed, trialsDataTarget, "UniformOutput", false);
[cwtres, f, coi] = cwtAny(trialsData, fs, "mode", "GPU");
disp(['cwt computation done in ', num2str(toc(t0)), ' s']);

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

t = (0:size(trialsData{1}, 2) - 1) / fs;

data = [];
data.freq = f;
data.time = t;
data.label = [{'seed'}; cellstr(num2str((1:size(trialsDataTarget{1}, 1))'))];
data.dimord = 'rpt_chan_freq_time';
data.cumtapcnt = ones(length(t), length(f));
data.fourierspctrm = cwtres;
data.coi = coi;
data.c = c; % shift in [f]

return;
end