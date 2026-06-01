function [cwtres, f, coi] = cwtMulti_np(data, fs, wname)
%CWTMULTI_NP  Non-parallel continuous wavelet transform for multi-column data.
%
%   [cwtres, f, coi] = cwtMulti_np(data, fs)
%   [cwtres, f, coi] = cwtMulti_np(data, fs, wname)
%
% INPUTS:
%   data   - [nTime x nSignal] double matrix. Each column is one signal.
%   fs     - Sampling rate in Hz.
%   wname  - Wavelet name: 'amor' (default) | 'morse' | 'bump'
%
% OUTPUTS:
%   cwtres - [nSignal x nFreq x nTime] complex double matrix
%   f      - Frequency column vector, in descending order
%   coi    - Cone of influence ([nTime x 1])
%
% NOTES:
%   - This is the non-parallel version of `cwtMulti_*`.
%   - It is used as a safe CPU fallback when GPU MEX cannot handle a tail block.

narginchk(2, 3);

if nargin < 3 || isempty(wname)
    wname = 'amor';
end

validateattributes(data, {'double'}, {'2d', 'nonempty', 'real'}, mfilename, 'data', 1);
validateattributes(fs, {'numeric'}, {'scalar', 'positive'}, mfilename, 'fs', 2);

[nTime, nSignal] = size(data);

% Probe output size using the first signal
[cwtres1, f, coi] = cwt(data(:, 1), wname, fs);
nFreq = numel(f);

% Preallocate output
cwtres = complex(zeros(nSignal, nFreq, nTime, 'double'));
cwtres(1, :, :) = cwtres1;

% Remaining signals
for sIndex = 2:nSignal
    cwtres(sIndex, :, :) = cwt(data(:, sIndex), wname, fs);
end

return;
end