function plotSize = autoplotsize(num)
%AUTOPLOTSIZE  Determine optimal [nrow, ncol] for a given number of subplots.
%
% INPUTS:
%     num: the total number of subplots
%
% OUTPUTS:
%     plotSize: [nrow, ncol]

% Approximate square grid
ncol = ceil(sqrt(num));
nrow = ceil(num / ncol);
plotSize = [nrow, ncol];
return;
end