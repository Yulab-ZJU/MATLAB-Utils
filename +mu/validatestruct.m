function [pass, msg] = validatestruct(s, varargin)
% Description: validate each field of a struct vector
% Input:
%     s: a struct vector
%     fieldname: field name of [s] to validate
%     validatefcn: validate function handle
% Output:
%     pass: pass validation or not
%     msg: validation failure message
%          It shows in 'sIndex - fieldName: error msg'

validateattributes(s, {'struct'}, {'vector'});
if mod(numel(varargin), 2) ~= 0
    error("Field names must be paired with validating function handles");
end

fIdx = 1:2:numel(varargin);
if ~all(cellfun(@(x) isfield(s, x), varargin(fIdx)))
    error("Invalid field names");
end

msgBuf = strings(0, 1);

% validate each field
for k = 1:numel(fIdx)
    fname = varargin{fIdx(k)};
    fcn = varargin{fIdx(k) + 1};

    % validate each struct
    for sIdx = 1:numel(s)
        val = s(sIdx).(fname);
        
        try
            isValid = fcn(val);
        catch ME
            if ~strcmp(ME.identifier, 'MATLAB:maxlhs')
                try
                    fcn(val);
                    isValid = true;
                catch ME
                    isValid = false;
                    msgBuf(end + 1) = sprintf('%d - %s: %s', sIdx, fname, ME.message); %#ok<AGROW>
                end
            end
        end

        if ~isValid
            msgBuf(end + 1) = sprintf('%d - %s', sIdx, fname); %#ok<AGROW>
        end

    end

end

if ~isempty(msgBuf)
    msg = "Validation Failed:" + newline + strjoin(msgBuf, newline);
    pass = false;
else
    msg = 'Validation passed';
    pass = true;
end

return;
end
