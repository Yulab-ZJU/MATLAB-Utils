function ROOTPATH = getrootpath(P, N)
% If [N] is set non-zero, return N-backward root path of path [P].
%
% e.g.
%     currentPath = fileparts(mfilename("fullpath"))
%     >> currentPath = 'D:\Education\Lab\MATLAB Utils\file'
%
%     ROOTPATH = mu.getrootpath(currentPath, 1)
%     >> ROOTPATH = 'D:\Education\Lab\MATLAB Utils\'

if N <= 0
    error('N should be positive.');
end

split = mu.path2func(fullfile(matlabroot, 'toolbox/matlab/strfun/split.m'));

P = char(P);

if endsWith(P, '\')
    P = P(1:end - 1);
end

temp = split(P, '\')';

if length(temp) <= N
    error('Could not backward any more.');
end

ROOTPATH = [fullfile(temp{1:end - N}), '\'];

return;
end