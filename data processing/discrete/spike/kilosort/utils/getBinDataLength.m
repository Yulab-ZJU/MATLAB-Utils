function nsample = getBinDataLength(BINPATH, nch, FORMAT)
% getBinDataLength  Get number of samples in binary data file
%
% Usage:
%   nsample = getBinDataLength(BINPATH, nch, FORMAT)
%
% Inputs:
%   BINPATH : path to binary file
%   nch     : number of channels
%   FORMAT  : 'i16' (int16, 2 bytes) or 'f32' (single, 4 bytes)
%
% Output:
%   nsample : number of samples per channel

% check file
if ~isfile(BINPATH)
    error('File not found: %s', BINPATH);
end

% file size
s = dir(BINPATH);
fbytes = s.bytes;

% bytes per sample
switch lower(FORMAT)
    case 'i16'
        bps = 2;
    case 'f32'
        bps = 4;
    otherwise
        error('Unsupported FORMAT: %s (use ''i16'' or ''f32'')', FORMAT);
end

% compute nsample
nsample = fbytes / (bps * nch);

if rem(nsample,1) ~= 0
    warning('File size not divisible by nch*bytesPerSample, result may be truncated');
    nsample = floor(nsample);
end

return;
end
