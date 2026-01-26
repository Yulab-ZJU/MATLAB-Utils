function addDataTips(H, tips)
%ADDDATATIPS  Apply datacursor-based tips to any graphics objects.
%
% Inputs
%   H    : gobjects array (line / patch / scatter / mixed)
%   tips : array of matlab.graphics.datatip.DataTipTextRow
%          e.g., tips = [dataTipTextRow("Data1", data1, '%.4g'); ...
%                        dataTipTextRow("Data2", data2, '%.4g')]
%
% This function converts DataTipTextRow definitions into
% datacursormode UpdateFcn-compatible text, and attaches them
% to graphics objects via UserData.
%
% Compatible with R2025a+ and older versions.

arguments
    H    (:,1) {isgraphics}
    tips (:,1) matlab.graphics.datatip.DataTipTextRow
end

% ---------- convert DataTipTextRow -> text lines ----------
tipLines = {};
for i = 1:numel(tips)
    row = tips(i);

    try
        lbl = string(row.Label);
        val = row.Value;
        fmt = row.Format;

        if isempty(val)
            continue;
        end

        if isnumeric(val)
            if isscalar(val)
                txt = sprintf('\\bf{%s}:\\rm %s', lbl, sprintf(fmt, val));
            else
                txt = sprintf('\\bf{%s}:\\rm %s', lbl, sprintf(fmt, val(1), val(end)));
            end
        else
            txt = sprintf('\\bf{%s}:\\rm %s', lbl, string(val));
        end

        tipLines{end + 1, 1} = txt; %#ok<AGROW>
    catch
        % skip malformed rows safely
    end
end

if isempty(tipLines)
    return;
end

% ---------- attach to each graphics object ----------
for k = 1:numel(H)
    hObj = H(k);
    if ~isgraphics(hObj)
        continue;
    end

    if ~isstruct(hObj.UserData)
        hObj.UserData = struct();
    end

    hObj.UserData.mu_tipLines = tipLines;
end

% ---------- bind datacursor UpdateFcn once per figure ----------
fig = ancestor(H(1), 'figure');

if isempty(fig) || ~isgraphics(fig)
    return;
end

if ~isappdata(fig, 'mu_datatip_bound') || ~getappdata(fig, 'mu_datatip_bound')
    dcm = datacursormode(fig);
    dcm.Enable = 'on';
    dcm.UpdateFcn = @dataTipUpdateFcn;
    setappdata(fig, 'mu_datatip_bound', true);
end

return;
end

%% helper
function txt = dataTipUpdateFcn(~, evt)
    % Generic datacursor UpdateFcn

    h = evt.Target;
    pos = evt.Position;
    
    % Always show cursor position
    txt = {sprintf('\\bf{X}:\\rm %.4g', pos(1)); sprintf('\\bf{Y}:\\rm %.4g', pos(2))};
    
    % Append custom tip lines if present
    if isgraphics(h) && isstruct(h.UserData) && isfield(h.UserData, 'mu_tipLines')
        lines = h.UserData.mu_tipLines;
        if iscell(lines)
            for i = 1:numel(lines)
                txt{end + 1, 1} = lines{i};
            end
        end
    end
end
