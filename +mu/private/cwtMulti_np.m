function [cwtres, f, coi] = cwtMulti_np(data, fs, wname)
narginchk(2, 3);

if nargin < 3
    wname = 'amor';
end

% Non-parallel version of `cwtMulti`
[nSample, nTrial] = size(data);
[cwtres1, f, coi] = cwt(data(:, 1), wname, fs);
cwtres = complex(nan(nTrial, length(f), nSample));
cwtres(1, :, :) = cwtres1;

for tIndex = 2:nTrial
    cwtres(tIndex, :, :) = cwt(data(:, tIndex), wname, fs);
end

return;
end