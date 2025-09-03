function mu_ks4_bin2lfp(binFile, outMat, nch, fs, varargin)
% mu_ks4_bin2lfp - Convert raw binary electrophysiology data to LFP
%
% This function converts a single raw binary file into band-pass filtered
% LFP. It automatically selects the fastest processing method:
%   - Small files (<MemoryLimit) use memmap for full-file processing.
%   - Large files (>MemoryLimit) use chunked fread processing with
%     on-the-fly MAT writing to avoid high memory usage.
%
% Inputs:
%   binFile - path to binary file
%   outMat  - path to output .mat
%   nch     - number of channels
%   fs      - original sampling rate
%
% Name-Value pairs:
%   'fsLFP'       - output LFP sampling rate (default 1000 Hz)
%   'flp'         - low-pass cutoff (default 300 Hz)
%   'fhp'         - high-pass cutoff (default 0.5 Hz)
%   'fstop'       - stopband frequency (default 360 Hz)
%   'FORMAT'      - 'i16' or 'f32' (default 'i16')
%   'SkipPoints'  - number of samples to skip at beginning (default 0)
%   'MemoryLimit' - threshold in GB for memmap vs chunked (default 20 GB)

%% Parse inputs
mIp = inputParser;
mIp.addRequired('binFile', @mustBeTextScalar);
mIp.addRequired('outMat' , @mustBeTextScalar);
mIp.addRequired('nch'    , @(x) validateattributes(x, 'numeric', {'positive', 'scalar', 'integer'}));
mIp.addRequired('fs'     , @(x) validateattributes(x, 'numeric', {'positive', 'scalar'}));
mIp.addParameter('fsLFP'      , 1000, @(x) validateattributes(x, 'numeric', {'positive', 'scalar'}));
mIp.addParameter('flp'        , 300 , @(x) validateattributes(x, 'numeric', {'positive', 'scalar'}));
mIp.addParameter('fhp'        , 0.5 , @(x) validateattributes(x, 'numeric', {'positive', 'scalar'}));
mIp.addParameter('fstop'      , 360 , @(x) validateattributes(x, 'numeric', {'positive', 'scalar'}));
mIp.addParameter('FORMAT'     , 'i16');
mIp.addParameter('SkipPoints' , 0 , @(x) validateattributes(x, 'numeric', {'positive', 'scalar', 'integer'}));
mIp.addParameter('MemoryLimit', 20, @(x) validateattributes(x, 'numeric', {'positive', 'scalar'}));
mIp.parse(varargin{:});
opt = mIp.Results;

opt.FORMAT = validatestring(opt.FORMAT, {'i16', 'f32'});
switch opt.FORMAT
    case 'i16', precision='int16' ; bytesPerSample = 2;
    case 'f32', precision='single'; bytesPerSample = 4;
end

%% File info
assert(exist(binFile, "file"), 'File %s does not exist.', binFile);
fileInfo = dir(binFile);
totalBytes = fileInfo.bytes;
nTotalSamples = totalBytes / (nch * bytesPerSample);
nSamples = nTotalSamples - opt.SkipPoints;
assert(nSamples > 0, 'SkipPoints exceeds total samples');

%% Choose method
if totalBytes <= opt.MemoryLimit * 1e9
    method = 'memmap';
else
    method = 'chunk';
end
fprintf('Processing method: %s\n', method);

%% Design band-pass filter
d = designfilt('bandpassiir', ...
               'FilterOrder', 4, ...
               'HalfPowerFrequency1', opt.fhp, ...
               'HalfPowerFrequency2', opt.flp, ...
               'SampleRate', fs);
assert(opt.fsLFP < fs, 'Sample rate of LFP should not exceed %.4f Hz', fs);
decimFactor = round(fs / opt.fsLFP);

%% ----------------- Memmap method -----------------
if strcmp(method, 'memmap')
    fprintf('Using memmap processing...\n');
    m = memmapfile(binFile, 'Format', {precision, [nch, nTotalSamples], 'raw'});
    raw = double(m.Data.raw(:, opt.SkipPoints + 1:end));
    lfp = filtfilt(d, raw')';
    if decimFactor > 1
        lfp = decimate(lfp', decimFactor)';
    end
    save(outMat, 'lfp', '-v7.3');
    fprintf('Done. LFP size [%d x %d]\n', size(lfp, 1), size(lfp, 2));
    return;
end

%% ----------------- Chunked method with memmap writing -----------------
fprintf('Using chunked processing with on-the-fly MAT writing...\n');
fid = fopen(binFile, 'r');
assert(fid >= 0, 'Cannot open bin file');
cleanup = onCleanup(@() fclose(fid));
fseek(fid, opt.SkipPoints * nch * bytesPerSample, 'bof');

chunkSec = 30;  % seconds per chunk
chunkSamples = chunkSec * fs;
nRemaining = nSamples;
chunkIdx = 0;

% Create matfile object for incremental writing
mf = matfile(outMat, 'Writable', true);

% Pre-allocate size based on downsampling
nSamplesLFP = ceil(nSamples / decimFactor);
mf.lfp = zeros(nch, nSamplesLFP, 'double');

% Track writing index
writeStart = 1;

while nRemaining > 0
    nRead = min(chunkSamples, nRemaining);
    rawChunk = fread(fid, [nch, nRead], ['*', precision]);
    rawChunk = double(rawChunk);
    filtChunk = filtfilt(d, rawChunk')';
    if decimFactor > 1
        filtChunk = decimate(filtChunk', decimFactor)';
    end
    nChunkLFP = size(filtChunk, 2);
    writeEnd = writeStart + nChunkLFP - 1;
    mf.lfp(:, writeStart:writeEnd) = filtChunk;
    writeStart = writeEnd + 1;
    nRemaining = nRemaining - nRead;
    chunkIdx = chunkIdx + 1;
    fprintf('Processed chunk %d, samples written %d/%d\n', chunkIdx, writeEnd, nSamplesLFP);
end

fprintf('Done. LFP saved to %s\n', outMat);
return;
end
