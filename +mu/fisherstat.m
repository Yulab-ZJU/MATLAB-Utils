function [H, pFisher, chi_square_stat, sigLevel] = fisherstat(p, dim, alphaVal)
% FISHERSTAT Combine p-values using Fisher's method along a specified dimension
%
% INPUTS:
%   p        - N-D array of p-values (numeric, 0 < p <= 1)
%   dim      - dimension along which to combine (default: 1)
%   alphaVal - significance threshold (default: 0.05)
%
% OUTPUTS:
%   H               - logical array, true if combined p < alphaVal
%   pFisher         - combined p-value by Fisher's method
%   chi_square_stat - Fisher's chi-square statistic
%   sigLevel        - chi-square critical value for given alphaVal

narginchk(1,3);

if nargin < 2 || isempty(dim)
    dim = 1;
end
if nargin < 3 || isempty(alphaVal)
    alphaVal = 0.05;
end

validateattributes(p, {'numeric'}, {'>=', 0, '<=', 1, 'nonempty'});
validateattributes(dim, {'numeric'}, {'scalar', 'integer', 'positive'});
validateattributes(alphaVal, {'numeric'}, {'scalar', '>', 0, '<', 1});

% Count valid (non-NaN) p-values along dim
validCount = sum(~isnan(p), dim);

% Sum of log p-values along dim, ignoring NaNs
sumLogP = sum(log(p), dim, 'omitnan');

% Fisher statistic
chi_square_stat = -2 .* sumLogP;

% Degrees of freedom: 2 * validCount
% Use max with 1 to avoid df=0 or negative
df = 2 .* max(validCount, 1);

% Compute combined p-value
pFisher = 1 - chi2cdf(chi_square_stat, df);

% Critical value for significance at alphaVal
sigLevel = chi2inv(1 - alphaVal, df);

% Logical decision: significant if combined p < alphaVal
H = pFisher < alphaVal;

return;
end
