function res = mGrangerWaveletFourierDiffPT(cwtres1, cwtres2, f, coi, fs, fRange, nperm)
% This function performs two-tailed permutation test on differential GC by 
% shuffling data in the order of trials.
% 
% The output [res] contains fields:
%     - p: a nChannelcmb*nFreq*nTime double matrix, where nChannelcmb=2*(nCh - 1).
%     - freq
%     - coi
%     - time
%     - channelcmb
% 
% [cwtres1] and [cwtres2] are nTrial*nCh*nFreq*nTime double matrices.
% The first channel is 'seed' and the rest channels are 'target'.
% The number of trials may be different for [cwtres1] and [cwtres2].
% 
% [f] is a descendent column vector in log scale.
% 
% [coi] does not influence the result.
% Leave it empty if you do not need it.
% 
% [fRange] specifies frequency limit for granger causality computation. (default: [] for all)
% 
% [nperm] specifies the total number of shuffling. (default: 1e3)

narginchk(5, 7);

if nargin < 6
    fRange = [];
end

if nargin < 7
    nperm = 1e3;
end

%% Wavelet transform
% Use existed cwt data
data1 = prepareDataFourier(cwtres1, f, coi, fs, fRange);
data2 = prepareDataFourier(cwtres2, f, coi, fs, fRange);
c = data1.c;

%% Origin GC
currentPath = pwd;
cd(fullfile(fileparts(which("ft_defaults")), 'connectivity', 'private'));

disp('Computing GC for dataset 1...');
t0 = tic;
res1 = mGrangerWaveletImpl(data1);
disp(['Done in ', num2str(toc(t0)), ' s.']);

disp('Computing GC for dataset 2...');
t0 = tic;
res2 = mGrangerWaveletImpl(data2);
disp(['Done in ', num2str(toc(t0)), ' s.']);

%% Permutation
disp('Permutation test for differential GC starts...');
t0 = tic;
[nTrial1, nCh, nFreq, nTime] = size(data1.fourierspctrm);
nTrial2 = size(data2.fourierspctrm, 1);

randord1 = zeros(nperm, nTrial1);
randord2 = zeros(nperm, nTrial2);
for index = 1:nperm
    randord1(index, :) = randperm(nTrial1);
    randord2(index, :) = randperm(nTrial2);
end

[grangerspctrm1, grangerspctrm2] = deal(zeros((nCh - 1) * 2, nFreq, nTime, nperm + 1));
grangerspctrm1(:, :, :, 1) = res1.grangerspctrm;
grangerspctrm2(:, :, :, 1) = res2.grangerspctrm;
delete(gcp('nocreate'));
parpool(4);
parfor_progress(nperm);
parfor index = 1:nperm
    % Trial randomization
    dataTemp = data1;
    dataTemp.fourierspctrm(:, 1, :, :) = data1.fourierspctrm(randord1(index, :), 1, :, :);
    grangerspctrm1(:, :, :, 1 + index) = mGrangerWaveletImpl(dataTemp).grangerspctrm;

    dataTemp = data2;
    dataTemp.fourierspctrm(:, 1, :, :) = data2.fourierspctrm(randord2(index, :), 1, :, :);
    grangerspctrm2(:, :, :, 1 + index) = mGrangerWaveletImpl(dataTemp).grangerspctrm;

    parfor_progress;
end
parfor_progress(0);

grangerspctrmDiff = grangerspctrm1 - grangerspctrm2;
p = sum((grangerspctrmDiff(:, :, :, 1) > 0 & grangerspctrmDiff(:, :, :, 2:end) > grangerspctrmDiff(:, :, :, 1)) | ...
        (grangerspctrmDiff(:, :, :, 1) < 0 & grangerspctrmDiff(:, :, :, 2:end) < grangerspctrmDiff(:, :, :, 1))) ./ nperm;

disp(['Permutation test for differential GC done in ', num2str(toc(t0)), ' s']);
cd(currentPath);

res = keepfields(res1, {'freq', 'time', 'channelcmb'});
res.p = p;
res.dimord = 'chancmb_freq_time';
res.freq = exp((res.freq - c) / 10);
res.coi = coi;
res.chancmbtype = {'from', 'to'};

return;
end