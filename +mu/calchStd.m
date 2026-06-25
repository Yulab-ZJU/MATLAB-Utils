function chStd = calchStd(trialsData, padDir)
% See mu.calchFunc for more information
narginchk(1, 2);

if nargin < 2
    padDir = "tail";
end

chStd= mu.calchFunc(@std, trialsData, padDir);
