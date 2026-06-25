function res = mu_granger_wavelet_pt(cwtres1, cwtres2, fs, f, t, opts)
%MU_GRANGER_WAVELET_PT Fast trial-label permutation test for wavelet-based GC.
%
%   res = mu_granger_wavelet_pt(cwtres1, cwtres2, fs, f, t, opts)
%
%   This function tests GC differences between two groups of trials using
%   trial-label permutation.
%
%   cwtres1:
%       nTrial1 x nCh x nFreq x nTime complex array.
%
%   cwtres2:
%       nTrial2 x nCh x nFreq x nTime complex array.
%
%   Channel convention:
%       channel 1 = seed
%       channels 2:end = targets
%
%   Definition:
%       dGC = GC(group2) - GC(group1)
%
%   Therefore, if called as:
%       res = mu_granger_wavelet_pt(cwtSTD, cwtDEV, ...)
%
%   then:
%       p_right tests DEV > STD
%       p_left  tests DEV < STD
%
%   opts fields:
%       opts.nperm       default 1000
%       opts.frange      nBand x 2, Hz, e.g. [4 8]
%       opts.trange      nWin x 2, ms, e.g. [0 100]
%       opts.coi         passed through; no masking
%       opts.seed        random seed, default []
%       opts.verbose     default true
%       opts.keepPerm    save dGC_perm, default true
%       opts.saveSingle  save output arrays as single, default true
%       opts.cropInput   crop cwtres to union of frange/trange before GC, default true
%
%       opts.useParallel use parfor for permutations, default false
%       opts.nWorkers    number of local workers, default [] for MATLAB default
%
%   Output:
%       res.dGC_obs:
%           nChanCmb x nFWin x nTWin
%
%       res.dGC_perm:
%           nChanCmb x nFWin x nTWin x nPerm, if opts.keepPerm = true
%
%       res.p_right:
%           one-tailed p-value for group2 > group1
%
%       res.p_left:
%           one-tailed p-value for group2 < group1
%
%       res.p_both:
%           two-sided p-value, 2 * min(p_left, p_right)

arguments
    cwtres1
    cwtres2
    fs (1,1) double {mustBePositive}
    f (:,1) double {mustBeFinite}
    t (:,1) double {mustBeFinite}

    opts.nperm (1,1) double {mustBeInteger, mustBePositive} = 1000
    opts.frange double = []
    opts.trange double = []
    opts.coi = []
    opts.seed = []
    opts.verbose (1,1) logical = true
    opts.keepPerm (1,1) logical = true
    opts.saveSingle (1,1) logical = true
    opts.cropInput (1,1) logical = true

    opts.useParallel (1,1) logical = false
    opts.nWorkers = []
end

%% Basic checks
if ndims(cwtres1) ~= 4 || ndims(cwtres2) ~= 4
    error("mu_granger_wavelet_pt:InputDim", ...
        "cwtres1 and cwtres2 must be nTrial x nCh x nFreq x nTime.");
end

sz1 = size(cwtres1);
sz2 = size(cwtres2);

if ~isequal(sz1(2:4), sz2(2:4))
    error("mu_granger_wavelet_pt:SizeMismatch", ...
        "cwtres1 and cwtres2 must have the same nCh, nFreq and nTime.");
end

nTrial1 = sz1(1);
nTrial2 = sz2(1);
nCh = sz1(2);
nFreq = sz1(3);
nTime = sz1(4);

if nCh < 2
    error("mu_granger_wavelet_pt:TooFewChannels", ...
        "At least two channels are required.");
end

if numel(f) ~= nFreq
    error("mu_granger_wavelet_pt:FreqMismatch", ...
        "numel(f) must match size(cwtres, 3).");
end

if numel(t) ~= nTime
    error("mu_granger_wavelet_pt:TimeMismatch", ...
        "numel(t) must match size(cwtres, 4).");
end

%% Seed handling
% One base seed controls:
%   1. permutation label generation
%   2. deterministic seeds before Wilson factorization calls
if isempty(opts.seed)
    rng("shuffle");
    baseSeed = randi(1e8);
else
    baseSeed = double(opts.seed);
end

rng(baseSeed, "twister");

%% Optional input cropping
fUse = f;
tUse = t;
coiUse = opts.coi;

if opts.cropInput
    fIdx = mu_granger_wavelet_helper("makeUnionIndex", f, opts.frange);
    tIdx = mu_granger_wavelet_helper("makeUnionIndex", t, opts.trange);

    cwtres1 = cwtres1(:, :, fIdx, tIdx);
    cwtres2 = cwtres2(:, :, fIdx, tIdx);

    fUse = f(fIdx);
    tUse = t(tIdx);

    if ~isempty(coiUse) && isvector(coiUse) && numel(coiUse) == numel(t)
        coiUse = coiUse(tIdx);
    end
end

%% Window index for output averaging
freqWins = mu_granger_wavelet_helper("makeWindowIndex", fUse, opts.frange, "frequency");
timeWins = mu_granger_wavelet_helper("makeWindowIndex", tUse, opts.trange, "time");

nFWin = numel(freqWins);
nTWin = numel(timeWins);

if isempty(opts.frange)
    freqOut = fUse;
else
    freqOut = mean(sort(opts.frange, 2), 2);
end

if isempty(opts.trange)
    timeOut = tUse;
else
    timeOut = mean(sort(opts.trange, 2), 2);
end

%% Prepare combined data once
if opts.verbose
    fprintf("Preparing combined CWT data once...\n");
end

cwtresAll = cat(1, cwtres1, cwtres2);
clear cwtres1 cwtres2;

dataAll = mu_granger_wavelet_helper("prepareData", cwtresAll, fUse, coiUse, fs, []);
clear cwtresAll;

nAll = nTrial1 + nTrial2;

%% FieldTrip private path
currentPath = pwd;
cleanupObj = onCleanup(@() cd(currentPath));

ftPath = fileparts(which("ft_defaults"));
if isempty(ftPath)
    error("mu_granger_wavelet_pt:FieldTripNotFound", ...
        "Cannot find ft_defaults. Please add FieldTrip to MATLAB path.");
end

ftPrivatePath = fullfile(ftPath, 'connectivity', 'private');
cd(ftPrivatePath);

%% Observed dGC
if opts.verbose
    fprintf("Computing observed GC difference...\n");
end

idxObs1 = 1:nTrial1;
idxObs2 = (nTrial1 + 1):nAll;

% Make observed computation deterministic.
rng(localSeed_(baseSeed, 1), "twister");
gc1 = mu_granger_wavelet_helper("computeGCFromData", dataAll, idxObs1);

rng(localSeed_(baseSeed, 2), "twister");
gc2 = mu_granger_wavelet_helper("computeGCFromData", dataAll, idxObs2);

dGC_obs_full = gc2.grangerspctrm - gc1.grangerspctrm;
dGC_obs = mu_granger_wavelet_helper("averageMap", dGC_obs_full, freqWins, timeWins);

[nChanCmb, ~, ~] = size(dGC_obs);

clear dGC_obs_full gc2;

%% Pre-generate permutation indices
if opts.verbose
    fprintf("Generating permutation indices, nperm = %d...\n", opts.nperm);
end

rng(localSeed_(baseSeed, 100), "twister");

idx1Mat = zeros(opts.nperm, nTrial1, "uint32");
idx2Mat = zeros(opts.nperm, nTrial2, "uint32");

for iperm = 1:opts.nperm
    ord = randperm(nAll);

    idx1Mat(iperm, :) = uint32(ord(1:nTrial1));
    idx2Mat(iperm, :) = uint32(ord(nTrial1 + 1:end));
end

%% Permutation test
if opts.verbose
    fprintf("Starting trial-label permutation, nperm = %d, parallel = %d...\n", ...
        opts.nperm, opts.useParallel);
end

% In parallel mode we need a temporary permutation result array anyway,
% because parfor cannot update countRight/countLeft reduction arrays with
% arbitrary 3-D matrix additions safely.
if opts.saveSingle
    dGC_perm_work = zeros(nChanCmb, nFWin, nTWin, opts.nperm, "single");
else
    dGC_perm_work = zeros(nChanCmb, nFWin, nTWin, opts.nperm, "like", dGC_obs);
end

t0 = tic;

if opts.useParallel

    pool = gcp("nocreate");

    if isempty(pool)
        if isempty(opts.nWorkers)
            pool = parpool();
        else
            pool = parpool(opts.nWorkers);
        end
    else
        if ~isempty(opts.nWorkers) && pool.NumWorkers ~= opts.nWorkers
            warning("mu_granger_wavelet_pt:PoolWorkerMismatch", ...
                "Existing pool has %d workers, but opts.nWorkers = %d. Using existing pool.", ...
                pool.NumWorkers, opts.nWorkers);
        end
    end

    if opts.verbose
        fprintf("Running permutations with parfor using %d workers...\n", pool.NumWorkers);
    end

    % Copy dataAll once per worker, not once per iteration.
    dataConst = parallel.pool.Constant(dataAll);

    parfor iperm = 1:opts.nperm

        % Make private FieldTrip functions visible on each worker.
        cd(ftPrivatePath);

        dataLocal = dataConst.Value;

        idx1 = double(idx1Mat(iperm, :));
        idx2 = double(idx2Mat(iperm, :));

        % Deterministic seeds for Wilson random initialization.
        rng(localSeed_(baseSeed, 100000 + iperm * 2 - 1), "twister");
        gc1_perm = mu_granger_wavelet_helper("computeGCFromData", dataLocal, idx1);

        rng(localSeed_(baseSeed, 100000 + iperm * 2), "twister");
        gc2_perm = mu_granger_wavelet_helper("computeGCFromData", dataLocal, idx2);

        dGC_perm_full = gc2_perm.grangerspctrm - gc1_perm.grangerspctrm;
        dGC_perm_this = mu_granger_wavelet_helper("averageMap", ...
            dGC_perm_full, freqWins, timeWins);

        if opts.saveSingle
            dGC_perm_work(:, :, :, iperm) = single(dGC_perm_this);
        else
            dGC_perm_work(:, :, :, iperm) = dGC_perm_this;
        end
    end

    if opts.verbose
        fprintf("Parallel permutations finished in %.2f sec.\n", toc(t0));
    end

else

    pb = [];
    if opts.verbose
        try
            pb = mu.dispstate();
        catch
            pb = [];
        end
    end

    for iperm = 1:opts.nperm

        idx1 = double(idx1Mat(iperm, :));
        idx2 = double(idx2Mat(iperm, :));

        rng(localSeed_(baseSeed, 100000 + iperm * 2 - 1), "twister");
        gc1_perm = mu_granger_wavelet_helper("computeGCFromData", dataAll, idx1);

        rng(localSeed_(baseSeed, 100000 + iperm * 2), "twister");
        gc2_perm = mu_granger_wavelet_helper("computeGCFromData", dataAll, idx2);

        dGC_perm_full = gc2_perm.grangerspctrm - gc1_perm.grangerspctrm;
        dGC_perm_this = mu_granger_wavelet_helper("averageMap", ...
            dGC_perm_full, freqWins, timeWins);

        if opts.saveSingle
            dGC_perm_work(:, :, :, iperm) = single(dGC_perm_this);
        else
            dGC_perm_work(:, :, :, iperm) = dGC_perm_this;
        end

        if opts.verbose
            msg = sprintf("Permutation %d / %d: done in %.2f sec", ...
                iperm, opts.nperm, toc(t0));

            if ~isempty(pb)
                pb.update(msg);
                if iperm == 1 || mod(iperm, 50) == 0 || iperm == opts.nperm
                    pb.finish();
                end
            elseif iperm == 1 || mod(iperm, 50) == 0 || iperm == opts.nperm
                fprintf("%s\n", msg);
            end
        end
    end
end

%% P values
% Use the same permutation null whether keepPerm is true or false.
countRight = sum(dGC_perm_work >= dGC_obs, 4);
countLeft  = sum(dGC_perm_work <= dGC_obs, 4);

p_right = (double(countRight) + 1) ./ (opts.nperm + 1);
p_left  = (double(countLeft)  + 1) ./ (opts.nperm + 1);
p_both  = min(1, 2 .* min(p_left, p_right));

%% Output
res = struct();

if opts.saveSingle
    res.dGC_obs = single(dGC_obs);
    res.p_right = single(p_right);
    res.p_left  = single(p_left);
    res.p_both  = single(p_both);
else
    res.dGC_obs = dGC_obs;
    res.p_right = p_right;
    res.p_left  = p_left;
    res.p_both  = p_both;
end

if opts.keepPerm
    res.dGC_perm = dGC_perm_work;
end

res.freq = freqOut;
res.time = timeOut;
res.freq_input = fUse;
res.time_input = tUse;

res.frange = opts.frange;
res.trange = opts.trange;

res.nperm = opts.nperm;
res.nTrial1 = nTrial1;
res.nTrial2 = nTrial2;

if isempty(opts.frange) && isempty(opts.trange)
    res.dimord = "chancmb_freq_time";
else
    res.dimord = "chancmb_fwin_twin";
end

res.chancmbtype = {'from', 'to'};
res.channelcmb = gc1.channelcmb;

res.diffDefinition = "dGC = GC(group2) - GC(group1)";
res.pRightDefinition = "p_right tests GC(group2) > GC(group1)";
res.pLeftDefinition  = "p_left tests GC(group2) < GC(group1)";
res.pBothDefinition  = "p_both = min(1, 2 * min(p_left, p_right))";

res.seed = baseSeed;
res.useParallel = opts.useParallel;

if opts.useParallel
    pool = gcp("nocreate");
    if isempty(pool)
        res.nWorkers = 0;
    else
        res.nWorkers = pool.NumWorkers;
    end
else
    res.nWorkers = 0;
end

res.runtimeSec = toc(t0);
end

%% ========================================================================
function s = localSeed_(baseSeed, offset)
%LOCALSEED_ Generate a valid deterministic RNG seed.
%
% MATLAB rng seed must be a nonnegative integer smaller than 2^32.

s = mod(double(baseSeed) + double(offset), 2^32 - 1);

if s < 0
    s = s + 2^32 - 1;
end

s = floor(s);

end