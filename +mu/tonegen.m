function [y, y_section, durs] = tonegen(f, durs, fs, options)
%TONEGEN  Efficient tone / complex-tone sequence generator.
%
% INPUTS:
%   REQUIRED:
%     f     - Fundamental frequency for each section, scalar or vector, in Hz.
%     durs  - Duration for each section, same size as f, in sec.
%     fs    - Design/sample rate of stimuli, in Hz.
%
%   NAME-VALUE:
%     fsDevice   - Output/playback sample rate, in Hz. Default = fs
%     harmonics  - Harmonics of complex tone. Default = 1
%     amps       - Amplitude specification:
%                  [] | scalar | vector | [numel(f) x numel(harmonics)] matrix
%     rfTime     - Rise-fall time, in sec. Default = 5e-3
%     rfOpt      - "both" | "rise" | "fall". Default = "both"
%     normOpt    - Normalize y to [-1,1]. Default = false / mu.OptionState.Off
%     oversample - Internal bounded oversampling factor. Default = 1
%     phaseOpt   - "continuous" | "reset". Default = "continuous"
%
% OUTPUTS:
%     y          - Output waveform column vector
%     y_section  - Section-wise output waveform, cell array
%     durs       - Actual section durations after sample quantization, column vector

arguments
    f (:,1) double {mustBeNonnegative}
    durs (:,1) double {mustBeNonnegative, mustHaveSameNumel(durs, f)}
    fs (1,1) double {mustBePositive}

    options.fsDevice (1,1) double {mustBePositive} = fs
    options.harmonics (:,1) double {mustBePositive} = 1
    options.amps = []
    options.rfTime (1,1) double {mustBeNonnegative} = 5e-3
    options.rfOpt (1,1) string {mustBeMember(options.rfOpt, ["both","rise","fall"])} = "both"
    options.normOpt = mu.OptionState.Off

    options.oversample {mustBeValidOversample(options.oversample)} = "auto"
    options.pointsPerCycle (1,1) double {mustBePositive} = 16
    options.maxOversample (1,1) double {mustBeInteger, mustBePositive} = 8

    options.phaseOpt (1,1) string {mustBeMember(options.phaseOpt, ["continuous","reset"])} = "continuous"
end

fsDevice   = options.fsDevice;
harmonics  = options.harmonics(:);
amps       = options.amps;
rfTime     = options.rfTime;
rfOpt      = options.rfOpt;
normOpt    = mu.OptionState.create(options.normOpt);
oversample = local_resolve_oversample( ...
    options.oversample, ...
    f, ...
    options.harmonics, ...
    fs, ...
    options.fsDevice, ...
    options.pointsPerCycle, ...
    options.maxOversample);
phaseOpt   = options.phaseOpt;

f    = f(:);
durs = durs(:);

nsection = numel(f);
nharm    = numel(harmonics);
hasZero  = any(f == 0);

%% basic duration checks
if hasZero
    nz = (f ~= 0);
    if any(durs(nz) < 2 * rfTime)
        error("For burst-like sections (f contains zero), every non-zero section duration must be >= 2*rfTime.");
    end
else
    if sum(durs) < 2 * rfTime
        error("Total duration should not be shorter than 2*rfTime.");
    end
end

%% amplitude expansion
amps = local_expand_amps(amps, nsection, nharm);

%% choose synthesis rate
fsSyn = max(fs, fsDevice) * oversample;
fMax  = max(f) * max(harmonics);

if fMax > 0 && fsSyn <= 2 * fMax
    warning("Internal synthesis rate fsSyn=%.3f Hz is close to Nyquist for max harmonic %.3f Hz. Consider larger fs/oversample.", ...
        fsSyn, fMax);
end

%% quantize section durations on synthesis grid
nSyn     = round(durs * fsSyn);
edgeSyn  = [0; cumsum(nSyn)];
totalSyn = edgeSyn(end);

dursSyn = nSyn / fsSyn; %#ok<NASGU>

nMax = max(nSyn);
sampleIdx = (0:max(nMax - 1, 0))';

%% synthesize whole waveform
ySyn = zeros(totalSyn, 1);
wantSections = (nargout >= 2);

phaseAcc = zeros(nharm, 1);

for i = 1:nsection
    ns = nSyn(i);
    idx = edgeSyn(i) + (1:ns);

    if ns == 0
        continue;
    end

    if f(i) == 0
        ySec = zeros(ns, 1);
        phaseAcc(:) = 0;
    else
        n = sampleIdx(1:ns);
        ySec = zeros(ns, 1);

        w0 = 2 * pi * f(i) / fsSyn;
        for ih = 1:nharm
            phi = 0;
            if phaseOpt == "continuous"
                phi = phaseAcc(ih);
            end
            ySec = ySec + amps(i, ih) * sin(w0 * harmonics(ih) * n + phi);
        end

        if hasZero
            ySec = local_apply_rf(ySec, fsSyn, rfTime, rfOpt);
        end

        if phaseOpt == "continuous"
            phaseAcc = mod(phaseAcc + 2 * pi * f(i) * harmonics * (ns / fsSyn), 2 * pi);
        else
            phaseAcc(:) = 0;
        end
    end

    ySyn(idx) = ySec;
end

if ~hasZero && ~isempty(ySyn)
    ySyn = local_apply_rf(ySyn, fsSyn, rfTime, rfOpt);
end

%% resample once if needed
if fsSyn == fsDevice
    y = ySyn;
    edgeOut = edgeSyn;
else
    [p, q] = rat(fsDevice / fsSyn, 1e-12);
    y = resample(ySyn, p, q);

    edgeOut = round(edgeSyn * fsDevice / fsSyn);
    edgeOut(end) = numel(y);

    edgeOut = max(edgeOut, 0);
    for i = 2:numel(edgeOut)
        edgeOut(i) = max(edgeOut(i), edgeOut(i - 1));
    end
end

%% split sections by slicing
if wantSections
    y_section = cell(nsection, 1);
    for i = 1:nsection
        i1 = edgeOut(i) + 1;
        i2 = edgeOut(i + 1);
        if i2 >= i1
            y_section{i} = y(i1:i2);
        else
            y_section{i} = zeros(0, 1);
        end
    end
else
    y_section = cell(0, 1);
end

%% actual durations on output grid
durs = diff(edgeOut) / fsDevice;
durs = durs(:);

%% normalize final output
if normOpt.toLogical
    mx = max(abs(y));
    if mx > 0
        y = y / mx;
    end
end

end


%% ========================================================================
function mustHaveSameNumel(a, b)
if numel(a) ~= numel(b)
    eid = "tonegen:InputSizeMismatch";
    msg = "durs must have the same number of elements as f.";
    throwAsCaller(MException(eid, msg));
end
end


%% ========================================================================
function amps = local_expand_amps(amps, nsection, nharm)

if isempty(amps)
    amps = ones(nsection, nharm);
    return;
end

if isscalar(amps)
    amps = repmat(amps, nsection, nharm);
    return;
end

if isvector(amps)
    amps = amps(:);
    if numel(amps) == nharm
        amps = repmat(amps(:)', nsection, 1);
        return;
    elseif numel(amps) == nsection
        amps = repmat(amps(:), 1, nharm);
        return;
    else
        error("Invalid amps vector: length must equal nsection or nharm.");
    end
end

if ismatrix(amps) && size(amps,1) == nsection && size(amps,2) == nharm
    return;
end

error("Invalid amps: should be scalar, vector, or [nsection x nharm] matrix.");

end


%% ========================================================================
function x = local_apply_rf(x, fs, rfTime, rfOpt)

if isempty(x) || rfTime == 0
    return;
end

x = mu.genRiseFallEdge(x, fs, rfTime, rfOpt);
x = x(:);

end


%% ========================================================================
function mustBeValidOversample(x)

if isstring(x) || ischar(x)
    x = string(x);
    if ~isscalar(x) || ~ismember(x, "auto")
        eid = "tonegen:InvalidOversample";
        msg = 'oversample must be a positive integer or "auto".';
        throwAsCaller(MException(eid, msg));
    end
    return;
end

if ~(isnumeric(x) && isscalar(x) && isfinite(x) && x >= 1 && mod(x,1) == 0)
    eid = "tonegen:InvalidOversample";
    msg = 'oversample must be a positive integer or "auto".';
    throwAsCaller(MException(eid, msg));
end

end


%% ========================================================================
function oversample = local_resolve_oversample(oversampleOpt, f, harmonics, fs, fsDevice, pointsPerCycle, maxOversample)

if isnumeric(oversampleOpt)
    oversample = oversampleOpt;
    return;
end

oversampleOpt = string(oversampleOpt);
if oversampleOpt ~= "auto"
    error('oversample must be a positive integer or "auto".');
end

fNonZero = f(f > 0);
if isempty(fNonZero)
    oversample = 1;
    return;
end

fMax = max(fNonZero) * max(harmonics);
fsBase = max(fs, fsDevice);

% target synthesis rate: enough points per cycle for the highest harmonic
targetFsSyn = max(fsBase, pointsPerCycle * fMax);

oversample = ceil(targetFsSyn / fsBase);
oversample = max(1, oversample);
oversample = min(oversample, maxOversample);

end