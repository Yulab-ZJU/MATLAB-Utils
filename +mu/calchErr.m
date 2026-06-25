function chErr = calchErr(trialsData, padDir)
% See mu.calchFunc for more information
narginchk(1, 2);

if nargin < 2
    padDir = "tail";
end

chErr= mu.calchFunc(@mu.se, trialsData, padDir);
