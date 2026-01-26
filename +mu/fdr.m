function [h, crit_p, adj_ci_cvrg, adj_p] = fdr(pvals, opts)
%FDR  NaN-safe wrapper of fdr_bh (BH/BY FDR control).
%
% This function applies FDR correction to p-values while excluding NaNs
% from the correction. Output arrays keep the same size as input. NaN
% locations in input pvals remain NaN in adj_p.
%
% Usage:
%   [h, crit_p, adj_ci_cvrg, adj_p] = mu.fdr(pvals)
%   [h, crit_p, adj_ci_cvrg, adj_p] = mu.fdr(pvals, 0.05, "dep", "yes")
%
% Required inputs:
%   pvals  : numeric array of p-values (any size). May contain NaNs.
%
% Name-value inputs:
%   q      : desired FDR level in (0,1). Default 0.05.
%   method : "pdep" (BH) or "dep" (BY, more strict). Default "pdep".
%   report : "yes" or "no". Default "no".
%
% Outputs:
%   h           : logical array, same size as pvals. NaN positions -> false.
%   crit_p      : scalar critical (uncorrected) p threshold. If no valid pvals,
%                 crit_p=NaN. If no significant pvals, crit_p=0 (same as fdr_bh).
%   adj_ci_cvrg : scalar adjusted CI coverage; NaN if none significant or no valid.
%   adj_p       : numeric array, same size as pvals; NaN positions preserved.
%
% Requirements:
%   - fdr_bh.m must be on MATLAB path.

arguments
    pvals {mustBeNumeric}

    opts.q (1,1) double {mustBeFinite, mustBeGreaterThan(opts.q,0), mustBeLessThan(opts.q,1)} = 0.05
    opts.method (1,1) string {mustBeMember(opts.method, ["pdep","dep"])} = "pdep"
    opts.report (1,1) string {mustBeMember(opts.report, ["yes","no"])} = "no"
end

% Keep original size
sz = size(pvals);

% Validate p-range only on non-NaNs
mask = ~isnan(pvals);
if any(mask, "all")
    pv = pvals(mask);
    if any(pv < 0)
        error("mu:fdr:BadPvals", "Some non-NaN p-values are < 0.");
    end
    if any(pv > 1)
        error("mu:fdr:BadPvals", "Some non-NaN p-values are > 1.");
    end
else
    % All NaNs: return shape-consistent outputs
    h = false(sz);
    crit_p = NaN;
    adj_ci_cvrg = NaN;
    adj_p = NaN(sz);
    return
end

% Make sure dependency is available
if exist("fdr_bh", "file") ~= 2
    error("mu:fdr:MissingDependency", ...
        "Required function fdr_bh.m is not found on the MATLAB path.");
end

% Run correction only on valid entries
[p_h, crit_p, adj_ci_cvrg, p_adj_p] = fdr_bh(pv, opts.q, char(opts.method), char(opts.report));

% Reconstruct outputs
h = false(sz);
h(mask) = logical(p_h);

adj_p = NaN(sz);
adj_p(mask) = p_adj_p;

% Note: h cannot hold NaN; NaN positions are false by design.
end
