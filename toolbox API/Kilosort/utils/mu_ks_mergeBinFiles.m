function [outFile, isMerged] = mu_ks_mergeBinFiles(outFile, varargin)
% mu_ks_mergeBinFiles Concatenate multiple binary files using Windows CMD copy /b
%
%   mu_ks_mergeBinFiles(OUTFILE, FILE1, FILE2, ...) concatenates FILE1, FILE2, ...
%   into OUTFILE by calling Windows CMD command: copy /b.
%
%   Example:
%       mu_ks_mergeBinFiles('merged.bin', 'file1.bin', 'file2.dat', 'file3.bin')

% Validate inputs
if nargin < 2
    error('Usage: mergeBinFiles(OUTFILE, FILE1, FILE2, ...)');
end
cellfun(@(x) assert(exist(x, "file"), sprintf('File %s does not exist.', x)), varargin);
mustBeTextScalar(outFile);

isMerged = true;
if isscalar(varargin)
    outFile = varargin{1};
    isMerged = false;
    return;
end

% Wrap with ""
quotedFiles = strcat('"', varargin, '"');
quotedOut   = strcat('"', outFile, '"');

% Construct CMD: copy /b file1 + file2 + file3 outfile
cmd = sprintf('copy /b %s %s', strjoin(quotedFiles, ' + '), quotedOut);

% Call system command
[status, msg] = system(cmd);

if status ~= 0
    error('mergeBinFiles:CopyFailed', ...
        'Failed to merge files. CMD output:\n%s', msg);
else
    fprintf('Merged %d files into %s successfully.\n', numel(varargin), outFile);
end

return;
end
