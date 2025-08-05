function [cwtres, f, coi] = cwtMulti(data, fs)
% Apply cwt to multi-channel/trial data. The result is returned in a 
% nTrial*nFreq*nTime complex double matrix.
% 
% This procedure is for cross-spectral density matrix computation in 
% nonparametric computation of granger causality.
% The default wavelet used is 'morlet'. Wavelets available: 
%     - 'amor' ('morlet', default)
%     - 'morse'
%     - 'bump'
%
% It can be encoded by gpucoder for parallel computation. See \+mu\demo\demo_gpucoder.m

[nSample, nTrial] = size(data);
[~, f, coi] = cwt(data(:, 1), 'amor', fs);
cwtres = complex(nan(nTrial, length(f), nSample));

parfor tIndex = 1:nTrial
    cwtres(tIndex, :, :) = cwt(data(:, tIndex), 'amor', fs);
end

return;
end