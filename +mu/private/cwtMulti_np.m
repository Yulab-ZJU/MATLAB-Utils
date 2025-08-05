function [cwtres, f, coi] = cwtMulti_np(data, fs)
% Non-parallel version of `cwtMulti`
[nSample, nTrial] = size(data);
[cwtres1, f, coi] = cwt(data(:, 1), 'amor', fs);
cwtres = complex(nan(nTrial, length(f), nSample));
cwtres(1, :, :) = cwtres1;

for tIndex = 2:nTrial
    cwtres(tIndex, :, :) = cwt(data(:, tIndex), 'amor', fs);
end

return;
end