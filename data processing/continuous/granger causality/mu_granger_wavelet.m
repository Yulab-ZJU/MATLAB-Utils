function res = mu_granger_wavelet(cwtres, f, coi, fs, fRange, nperm)
%MU_GRANGER_WAVELET Compute nonparametric GC using precomputed CWT data.
%
%   res = mu_granger_wavelet(cwtres, f, coi, fs, fRange, nperm)
%
%   cwtres:
%       nTrial x nCh x nFreq x nTime complex array.
%
%   Channel convention:
%       channel 1 = seed
%       channels 2:end = targets
%
%   f:
%       nFreq x 1 frequency vector in Hz, usually descending as returned by cwt.
%
%   coi:
%       cone of influence. Passed through and not used for masking here.
%
%   fs:
%       sampling rate in Hz.
%
%   fRange:
%       optional frequency range, [low high] Hz.
%       If empty, all frequencies are used.
%
%   nperm:
%       if nperm > 1, computes seed-trial-shuffled surrogate GC.
%       This is NOT DEV-vs-STD label permutation.
%
%   Output:
%       res.grangerspctrm:
%           nChanCmb x nFreq x nTime, if nperm == 1
%           nChanCmb x nFreq x nTime x (nperm + 1), if nperm > 1
%
%       When nperm > 1:
%           res.grangerspctrm(:,:,:,1)     = observed GC
%           res.grangerspctrm(:,:,:,2:end) = seed-trial-shuffled surrogate GC

narginchk(4, 6);

if nargin < 5 || isempty(fRange)
    fRange = [];
end

if nargin < 6 || isempty(nperm)
    nperm = 1;
end

%% Prepare data once
data = mu_granger_wavelet_helper("prepareData", cwtres, f, coi, fs, fRange);
c = data.c;

[nTrial, nCh, nFreq, nTime] = size(data.fourierspctrm);

%% Enter FieldTrip private path once
fprintf('Granger causality computation starts...\n');
t0 = tic;

currentPath = pwd;
cleanupObj = onCleanup(@() cd(currentPath));

ftPath = fileparts(which("ft_defaults"));
if isempty(ftPath)
    error("mu_granger_wavelet:FieldTripNotFound", ...
        "Cannot find ft_defaults. Please add FieldTrip to MATLAB path.");
end

cd(fullfile(ftPath, 'connectivity', 'private'));

%% Observed GC
res = mu_granger_wavelet_helper("impl", data);

res.dimord = 'chancmb_freq_time';
res.freq = exp((res.freq - c) / 10);
res.coi = data.coi;
res.chancmbtype = {'from', 'to'};

%% Seed-trial-shuffled surrogate
if nperm > 1
    fprintf('Performing seed-trial-shuffled surrogate GC, nperm = %d...\n', nperm);

    grangerspctrm = zeros((nCh - 1) * 2, nFreq, nTime, nperm + 1, ...
        "like", res.grangerspctrm);

    grangerspctrm(:, :, :, 1) = res.grangerspctrm;

    for iperm = 1:nperm

        randord = randperm(nTrial);

        dataTemp = data;
        dataTemp.fourierspctrm(:, 1, :, :) = ...
            data.fourierspctrm(randord, 1, :, :);

        temp = mu_granger_wavelet_helper("impl", dataTemp);

        grangerspctrm(:, :, :, iperm + 1) = temp.grangerspctrm;

        if iperm == 1 || mod(iperm, 50) == 0 || iperm == nperm
            fprintf('Seed-trial shuffle %d / %d finished.\n', iperm, nperm);
        end
    end

    res.grangerspctrm = grangerspctrm;
    res.dimord = 'chancmb_freq_time_perm';
end

fprintf('Nonparametric GC computation done in %.2f s.\n', toc(t0));
end