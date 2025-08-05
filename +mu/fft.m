function [A, f, Aoi, Phase] = fft(X, fs, varargin)
% This function computes the single-sided amplitude and phase spectrum of input data X using the Fast Fourier Transform (FFT).
% 
% Inputs:
%   X   - Input data, either a vector or a 2-D matrix.
%   fs  - Sampling frequency in Hz.
%   N   - Number of points for FFT (optional, default is the data length).
%   dim - Dimension along which to perform FFT (optional, default is 2).
%         For [nSample, nCh] data, use dim=1.
%         For [nCh, nSample] data, use dim=2.
%         If X is a vector, dim input is ignored.
%   foi - Frequency of interest, specified as a one- or two-element vector (optional).
%
% Outputs:
%   A     - Amplitude of the single-sided Fourier spectrum.
%   f     - Frequency vector for the N-point single-sided FFT.
%   Aoi   - Amplitude at the frequency of interest (foi).
%   Phase - Phase of the single-sided Fourier

mIp = inputParser;
mIp.addRequired("X", @(x) validateattributes(x, 'numeric', {'real', '2d'}));
mIp.addRequired("fs", @(x) validateattributes(x, 'numeric', {'scalar', 'positive'}));
mIp.addOptional("N", [], @(x) isempty(x) || (isscalar(x) && x > 0 && x == mod(x, 1)));
mIp.addOptional("dim", 2, @(x) ismember(x, [1, 2]));
mIp.addOptional("foi", [], @(x) validateattributes(x, 'numeric', {'2d', 'increasing', 'positive', "<=", fs/2}));
mIp.parse(X, fs, varargin{:});
N = mIp.Results.N;
dim = mIp.Results.dim;
foi = mIp.Results.foi;

if isvector(X)
    X = X(:)';
    dim = 2;
else
    X = permute(X, [3 - dim, dim]);
end

if isempty(N)
    % N = 2 ^ nextpow2(size(X, 2));
    N = floor(size(X, 2) / 2) * 2;
end

N = floor(N / 2) * 2;
Y = fft(X, N, 2);
A = abs(Y(:, 1:N / 2 + 1) / size(X, 2));
A(:, 2:end - 1) = 2 * A(:, 2:end - 1);
f = linspace(0, fs / 2, N / 2 + 1);
Phase = angle(Y(:, 1:N / 2 + 1));

if nargin < 5
    Aoi = [];
else

    if isscalar(foi)
        [~, idx] = min(abs(f - foi));
    
        if f(idx) < foi
            Aoi = (A(:, idx) + A(:, min(idx + 1, length(f)))) / 2;
        elseif f(idx) > foi
            Aoi = (A(:, idx) + A(:, max(idx - 1, 1))) / 2;
        else
            Aoi = A(:, idx);
        end

    elseif numel(foi) == 2
        idx = find(f > foi(1) & f < foi(2));

        if ~isempty(idx)
            idx(1) = max([idx(1) - 1, 1]);
            idx(2) = min([idx(2) + 1, length(f)]);
            Aoi = mean(A(:, idx), 2);
        else
            error("No data matched");
        end

    else
        error("Invalid frequency of interest");
    end

end

A = permute(A, [3 - dim, dim]);
Phase = permute(Phase, [3 - dim, dim]);
return;
end