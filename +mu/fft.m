function [A, f, phase] = fft(X, fs, varargin)
% FFT Compute single-sided amplitude and phase spectrum of input data
%
%   [A, f, phase] = mu.fft(X, fs, N, dim, 'foi', foi)
%
% INPUTS:
%   X   - Input data (vector, matrix, or N-D array)
%   fs  - Sampling frequency in Hz
%   N   - FFT length ([] for length, 'nextpow2' for next power of 2)
%   dim - Dimension to perform FFT along (default: first non-singleton)
%   foi - Frequency of interest (scalar or [min max])
%
% OUTPUTS:
%   A     - Amplitude spectrum (single-sided)
%   f     - Frequency vector
%   phase - Phase spectrum (single-sided)

% ---- Parse inputs ----
p = inputParser;
p.addRequired('X', @(x) validateattributes(x, {'numeric'}, {'real','nonempty'}));
p.addRequired('fs', @(x) validateattributes(x, {'numeric'}, {'scalar','positive'}));
p.addOptional('N', []);
p.addOptional('dim', [], @(x) isempty(x) || (isscalar(x) && x > 0 && mod(x,1) == 0));
p.addParameter('foi', [], @(x) validateattributes(x, {'numeric'}, {'vector','increasing','positive'}));
p.parse(X, fs, varargin{:});

N = p.Results.N;
foi = p.Results.foi;
userDim = p.Results.dim;

% ---- Determine FFT dimension ----
if isvector(X)
    X = X(:);
    dim = 1;
else
    if isempty(userDim)
        dim = find(size(X) > 1, 1);
    else
        dim = userDim;
    end
end

% ---- Determine FFT length ----
if isempty(N)
    N = size(X, dim);
elseif (ischar(N) || isstring(N)) && strcmpi(N, 'nextpow2')
    N = 2 ^ nextpow2(size(X, dim));
else
    validateattributes(N, 'numeric', {'scalar', 'integer', 'positive'});
end

% ---- Ensure even length ----
N = floor(N / 2) * 2;

% ---- Compute N-point FFT ----
Y = fft(X, N, dim);

% ---- Single-sided ----
nfft = floor(N/2) + 1;
idx = repmat({':'}, 1, ndims(X));
idx{dim} = 1:nfft;

A = abs(Y(idx{:})) / size(X, dim);
phase = angle(Y(idx{:}));

% Double amplitudes except DC and Nyquist
multIdx = repmat({':'}, 1, ndims(A));
multIdx{dim} = 2:(nfft-1);
A(multIdx{:}) = 2 * A(multIdx{:});

% ---- Frequency vector ----
f = linspace(0, fs/2, nfft)';

% ---- Frequency of interest ----
if ~isempty(foi)
    if any(foi > fs/2)
        error('foi cannot exceed Nyquist frequency (fs/2)');
    end
    if isscalar(foi)
        freqIdx = dsearchn(f, foi);
        idx{dim} = freqIdx;
        A = A(idx{:});
        phase = phase(idx{:});
        f = f(freqIdx);
    elseif numel(foi) == 2
        freqIdx = find(f >= foi(1) & f <= foi(2));
        idx{dim} = freqIdx;
        A = A(idx{:});
        phase = phase(idx{:});
        f = f(freqIdx);
    else
        error('foi must be scalar or two-element vector');
    end
end

return;
end
