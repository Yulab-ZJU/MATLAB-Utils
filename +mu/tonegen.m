function [y, y_section, durs] = tonegen(f, durs, fs, varargin)
%TONEGEN  Generates tone/complex tone sequence with specified 
%         [f1,f2,...fn] and [dur1,dur2,...,durn] for each section.
%
% INPUTS:
%   REQUIRED:
%     f     - Fundamental frequency for each section, scalar or vector, in Hz.
%     durs  - Duration for each section, must be the same size as [f], in sec.
%     fs    - Sample rate of the stimuli, in Hz.
%   NAME-VALUE:
%     fsDevice   - Sample rate of the device to play the audio file, in Hz. (default=fs)
%     harmonics  - Harmonics that form complex tone (default=1, pure tone)
%     amps       - Amplitude for each frequency and harmonic with each row for 
%                  a frequency and each column for a harmonic, in volt.
%                  (default=ones(numel(f), numel(harmonics)))
%     rfTime     - Rise-fall time, in sec. (default=5e-3)
%                  If [f] contains zero values (for tone burst), this will 
%                  be applied to every section.
%                  If [f] does not contain zero value (for continuous
%                  sound), this will be applied to the whole sound.
%     rfOpt      - "both" | "rise" | "fall" (default="both")
%     normOpt    - If set true, normalize sound to -1~1 (default=false)
%
% OUTPUTS:
%     y          - Sound stimulation, a row vector, in volt.
%     y_section  - Sound of each section, a cell array.
%     durs       - The actual duration for each section, a column vector, in sec.

mIp = inputParser;
mIp.addRequired("f", @(x) validateattributes(x, {'numeric'}, {'vector', 'nonnegative'}));
mIp.addRequired("durs", @(x) validateattributes(x, {'numeric'}, {'vector', 'nonnegative', 'numel', numel(f)}));
mIp.addRequired("fs", @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
mIp.addParameter("fsDevice", fs, @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
mIp.addParameter("harmonics", 1, @(x) validateattributes(x, {'numeric'}, {'vector', 'positive'}));
mIp.addParameter("amps", [], @(x) validateattributes(x, {'numeric'}, {'vector'}));
mIp.addParameter("rfTime", 5e-3, @(x) validateattributes(x, {'numeric'}, {'nonnegative', 'scalar'}));
mIp.addParameter("rfOpt", "both", @(x) any(validatestring(x, {'both', 'rise', 'fall'})));
mIp.addParameter("normOpt", mu.OptionState.Off);
mIp.parse(f, durs, fs, varargin{:});

fsDevice = mIp.Results.fsDevice;
harmonics = mIp.Results.harmonics;
amps = mIp.Results.amps;
rfTime = mIp.Results.rfTime;
rfOpt = mIp.Results.rfOpt;
normOpt = mu.OptionState.create(mIp.Results.normOpt);

if (~any(f) && any(durs / 2 < rfTime)) || (all(f) && sum(durs) / 2 < rfTime)
    error("Duration should not be shorter than rise-fall time");
end

if isempty(amps)
    amps = ones(numel(f), numel(harmonics));
elseif isvector(amps) && ~isscalar(amps)
    [a, b] = size(amps);

    if a < b % row vector
        amps = repmat(amps, [numel(f), 1]);
    else % column vector
        amps = repmat(amps, [1, numel(harmonics)]);
    end

elseif size(amps, 1) ~= numel(f) || size(amps, 2) ~= numel(harmonics)
    error("Invalid [amps]: should be each row for a frequency and each column for a harmonic");
end

nsection = numel(f);
f = f(:);
fsNew = mu.lcm([f(f ~= 0) * harmonics(end); fs; fsDevice]);
y_section = cell(nsection, 1);

for index = 1:nsection

    if f(index) == 0
        y_section{index} = zeros(fix(durs(index) * fsNew), 1);
        continue;
    end

    t = 1 / fsNew:1 / fsNew:durs(index);
    y_section{index} = sum(amps(index, :)' .* sin(2 * pi * f(index) * harmonics(:) * t), 1)';
    durs(index) = length(t) / fsNew;
end

if any(f == 0)
    y_section = cellfun(@(x) mu.genRiseFallEdge(x, fsNew, rfTime, rfOpt)', y_section, "UniformOutput", false);
end

y = cat(1, y_section{:});
y = mu.resampledata(y, fsNew, fsDevice);
y_section = cellfun(@(x) mu.resampledata(x(:), fsNew, fsDevice), y_section, "UniformOutput", false);

if ~any(f == 0)
    y = mu.genRiseFallEdge(y, fs, rfTime, rfOpt)';
end

if normOpt.toLogical
    y = mapminmax(y(:)', -1, 1)';
end

return;
end