function exportFigure2PDF(FigHandle, FileName, WidthMm, HeightMm, Opts)
%EXPORTFIGURE2PDF Export a MATLAB figure to a vector PDF with controlled size.
%
% This implementation supports two adjustment modes:
%
%   adjustPositionType = "TightInset"
%       WidthMm and HeightMm specify the final PDF page size. The complete
%       measured visible content is fitted into that page and centered.
%
%   adjustPositionType = "Position"
%       WidthMm and HeightMm specify the union size of the top-level layout
%       Position boxes. Margins required by labels, titles, legends,
%       colorbars, and other decorations are added to the final PDF page.
%
% Important implementation details:
%   1. Since R2025a, exportgraphics is called with Width, Height, Units,
%      Padding="figure", and PreserveAspectRatio="off". This prevents the
%      default tight crop from silently changing the requested PDF size.
%   2. Position mode checks overflow on all four sides and iteratively grows
%      the corresponding page margins. The Position-box size is unchanged.
%   3. TightInset mode keeps a small renderer-safety inset and centers the
%      fitted content, preventing edge clipping of text and graphics whose
%      rendered bounds slightly exceed MATLAB TightInset/Extent estimates.
%
% INPUTS:
%   FigHandle : figure handle
%   FileName  : output PDF path
%   WidthMm   : target width in millimeters
%   HeightMm  : target height in millimeters
%
% NAME-VALUE OPTIONS:
%   expandMode:
%       "fixed"             - use WidthMm and HeightMm directly
%       "keepratio-width"   - preserve ratio using WidthMm
%       "keepratio-height"  - preserve ratio using HeightMm
%       "keepratio-min"     - preserve ratio using the smaller constraint
%       "keepratio-max"     - preserve ratio using the larger constraint
%
%   adjustOpt:
%       "on"  - adjust layout boundary, default
%       "off" - WidthMm and HeightMm are the complete figure/page size
%
%   adjustPositionType:
%       "TightInset" - fit complete visible content into the requested page
%       "Position"   - preserve requested Position-box size and add margins
%
%   tol:
%       relative fitting/containment tolerance, default 1e-3
%
%   maxIter:
%       maximum fitting/containment iterations, default 100
%
%   debug:
%       true keeps the temporary figure visible after exporting
%
% EXAMPLE:
%   mu.exportFigure2PDF(gcf, "test.pdf", 140, 80, ...
%       "adjustPositionType", "Position");

arguments
    FigHandle (1, 1) matlab.ui.Figure
    FileName {mustBeTextScalar}
    WidthMm (1, 1) double {mustBePositive}
    HeightMm (1, 1) double {mustBePositive}

    Opts.expandMode {mustBeMember(Opts.expandMode, { ...
        'fixed', 'keepratio-width', 'keepratio-height', ...
        'keepratio-min', 'keepratio-max'})} = "fixed"

    Opts.adjustOpt {mustBeMember(Opts.adjustOpt, { ...
        'on', 'off', 'ON', 'OFF', 'On', 'Off'})} = "on"

    Opts.adjustPositionType {mustBeMember(Opts.adjustPositionType, { ...
        'TightInset', 'Position', 'tightinset', 'position'})} = "Position"

    Opts.tol (1, 1) double {mustBeNonnegative} = 1e-3
    Opts.maxIter (1, 1) double {mustBePositive, mustBeInteger} = 100
    Opts.debug (1, 1) logical = false
end

ExpandMode = validatestring(char(Opts.expandMode), { ...
    'fixed', ...
    'keepratio-width', ...
    'keepratio-height', ...
    'keepratio-min', ...
    'keepratio-max'});

AdjustOpt = strcmpi(char(Opts.adjustOpt), 'on');
AdjustPositionType = lower(string(validatestring( ...
    char(Opts.adjustPositionType), { ...
    'TightInset', 'Position', 'tightinset', 'position'})));

Tol = Opts.tol;
MaxIter = Opts.maxIter;

if startsWith(ExpandMode, 'keepratio') && ...
        AdjustPositionType == "tightinset"
    warning('exportFigure2PDF:AdjustPositionTypeChanged', ...
        ['expandMode="%s" requires preserving Position geometry. ' ...
         'adjustPositionType has been changed from "TightInset" ' ...
         'to "Position".'], ExpandMode);
    AdjustPositionType = "position";
end

FileName = string(FileName);

% Complete pending layout calculations before copying the source figure.
drawnow;

TempFig = copyobj(FigHandle, 0);
CleanupObj = onCleanup(@() CloseIfValid(TempFig));

try
    TempFig.WindowState = "normal";
catch
end

if ~Opts.debug
    TempFig.Visible = "off";
end

drawnow;

if ~AdjustOpt
    FinalPaperWidthCm = WidthMm / 10;
    FinalPaperHeightCm = HeightMm / 10;

    SetFigureSize(TempFig, FinalPaperWidthCm, FinalPaperHeightCm);
    DisableToolbars(TempFig);
    drawnow;

    ExportExactPage( ...
        TempFig, FileName, FinalPaperWidthCm, FinalPaperHeightCm);

    fprintf('============== PDF Exporting ==============\n');
    fprintf('Adjustment: off\n');
    fprintf('Final paper size: %.3g x %.3g cm\n', ...
        FinalPaperWidthCm, FinalPaperHeightCm);
    fprintf('PDF file exported to: %s\n', mu.getabspath(FileName));
    fprintf('================== Done ===================\n');
    return;
end

LayoutRoots = GetLayoutRoots(TempFig);

if isempty(LayoutRoots)
    error('exportFigure2PDF:NoLayoutChildren', ...
        ['No top-level layout objects with writable Units and Position ' ...
         'properties were found in the figure.']);
end

RootPositionCm = GetRootPositions( ...
    LayoutRoots, TempFig, "centimeters");

switch AdjustPositionType
    case "tightinset"
        [ReferenceBox, ReferenceWidth, ReferenceHeight] = ...
            GetContentBorderBox( ...
                TempFig, LayoutRoots, "centimeters");

    case "position"
        [ReferenceBox, ReferenceWidth, ReferenceHeight] = ...
            GetBoxUnion(RootPositionCm);

    otherwise
        error('exportFigure2PDF:InvalidPositionType', ...
            'Invalid adjustPositionType: %s.', AdjustPositionType);
end

if ReferenceWidth <= 0 || ReferenceHeight <= 0 || ...
        ~all(isfinite([ReferenceBox, ReferenceWidth, ReferenceHeight]))
    error('exportFigure2PDF:InvalidLayoutBox', ...
        'The measured layout boundary has invalid width or height.');
end

TargetRatio = WidthMm / HeightMm;
ReferenceRatio = ReferenceWidth / ReferenceHeight;

if AdjustPositionType == "tightinset"
    EffectiveExpandMode = 'fixed';
else
    EffectiveExpandMode = ExpandMode;
end

switch EffectiveExpandMode
    case 'fixed'
        TargetWidthMm = WidthMm;
        TargetHeightMm = HeightMm;

    case 'keepratio-width'
        TargetWidthMm = WidthMm;
        TargetHeightMm = WidthMm / ReferenceRatio;

    case 'keepratio-height'
        TargetWidthMm = HeightMm * ReferenceRatio;
        TargetHeightMm = HeightMm;

    case 'keepratio-min'
        if TargetRatio > ReferenceRatio
            TargetWidthMm = HeightMm * ReferenceRatio;
            TargetHeightMm = HeightMm;
        else
            TargetWidthMm = WidthMm;
            TargetHeightMm = WidthMm / ReferenceRatio;
        end

    case 'keepratio-max'
        if TargetRatio < ReferenceRatio
            TargetWidthMm = HeightMm * ReferenceRatio;
            TargetHeightMm = HeightMm;
        else
            TargetWidthMm = WidthMm;
            TargetHeightMm = WidthMm / ReferenceRatio;
        end
end

TargetWidthCm = TargetWidthMm / 10;
TargetHeightCm = TargetHeightMm / 10;

SetFigureSize(TempFig, TargetWidthCm, TargetHeightCm);

ScaleX = TargetWidthCm / ReferenceWidth;
ScaleY = TargetHeightCm / ReferenceHeight;

if ~strcmp(ExpandMode, 'fixed')
    UniformScale = min(ScaleX, ScaleY);
    ScaleX = UniformScale;
    ScaleY = UniformScale;
end

TargetRootPositionCm = RootPositionCm;
TargetRootPositionCm(:, 1) = ...
    (RootPositionCm(:, 1) - ReferenceBox(1)) * ScaleX;
TargetRootPositionCm(:, 2) = ...
    (RootPositionCm(:, 2) - ReferenceBox(2)) * ScaleY;
TargetRootPositionCm(:, 3) = RootPositionCm(:, 3) * ScaleX;
TargetRootPositionCm(:, 4) = RootPositionCm(:, 4) * ScaleY;

AssignAbsoluteRootPositions( ...
    LayoutRoots, TargetRootPositionCm, TempFig, "centimeters");

drawnow;

% Two screen pixels, with an absolute lower bound, are sufficient to absorb
% renderer rounding while remaining visually negligible.
RendererSafetyCm = max(0.05, ...
    2 * PixelToCentimeterScale(TempFig));

switch AdjustPositionType
    case "tightinset"
        [IterationCount, FinalContentBox, FinalContentWidth, ...
            FinalContentHeight] = FitTightInsetPage( ...
                TempFig, LayoutRoots, ...
                TargetWidthCm, TargetHeightCm, ...
                RendererSafetyCm, Tol, MaxIter);

        FinalPaperWidthCm = TargetWidthCm;
        FinalPaperHeightCm = TargetHeightCm;
        ReservedMarginsCm = [0, 0, 0, 0];

        if FinalContentWidth > ...
                FinalPaperWidthCm - 2 * RendererSafetyCm + Tol || ...
                FinalContentHeight > ...
                FinalPaperHeightCm - 2 * RendererSafetyCm + Tol
            warning('exportFigure2PDF:TightInsetNotConverged', ...
                ['TightInset fitting did not fully converge after %d ' ...
                 'iterations. Final measured content size is ' ...
                 '%.4g x %.4g cm; page size is %.4g x %.4g cm.'], ...
                IterationCount, FinalContentWidth, FinalContentHeight, ...
                FinalPaperWidthCm, FinalPaperHeightCm);
        end

    case "position"
        BaseRootPositionCm = GetRootPositions( ...
            LayoutRoots, TempFig, "centimeters");

        ReservedMarginsCm = EstimatePositionMargins( ...
            TempFig, LayoutRoots, RendererSafetyCm);

        [ReservedMarginsCm, FinalPaperWidthCm, ...
            FinalPaperHeightCm, FinalContentBox, ...
            FinalContentWidth, FinalContentHeight, ...
            IterationCount] = FitPositionPage( ...
                TempFig, LayoutRoots, BaseRootPositionCm, ...
                TargetWidthCm, TargetHeightCm, ...
                ReservedMarginsCm, RendererSafetyCm, Tol, MaxIter);
end

DisableToolbars(TempFig);
drawnow;

% Recheck all four page sides after toolbar/layout updates.
[FinalContentBox, FinalContentWidth, FinalContentHeight] = ...
    GetContentBorderBox(TempFig, LayoutRoots, "centimeters");

OverflowCm = [ ...
    max(0, -FinalContentBox(1)), ...
    max(0, -FinalContentBox(2)), ...
    max(0, FinalContentBox(3) - FinalPaperWidthCm), ...
    max(0, FinalContentBox(4) - FinalPaperHeightCm)];

if any(OverflowCm > max(Tol, 1e-6))
    warning('exportFigure2PDF:UnexpectedOverflow', ...
        ['Visible content extends outside the final page. ' ...
         'Overflow [L B R T] = [%g %g %g %g] cm.'], ...
        OverflowCm(1), OverflowCm(2), ...
        OverflowCm(3), OverflowCm(4));
end

TempFig.PaperUnits = "centimeters";
TempFig.PaperPositionMode = "manual";
TempFig.PaperPosition = [ ...
    0, 0, FinalPaperWidthCm, FinalPaperHeightCm];
TempFig.PaperSize = [FinalPaperWidthCm, FinalPaperHeightCm];

drawnow;

ExportExactPage( ...
    TempFig, FileName, FinalPaperWidthCm, FinalPaperHeightCm);

fprintf('============== PDF Exporting ==============\n');
fprintf('adjustPositionType: %s\n', AdjustPositionType);

if AdjustPositionType == "tightinset"
    fprintf(['PDF exporting: Iter=%d, tol=%.3g, ' ...
             'w_diff=%.3g, h_diff=%.3g\n'], ...
        IterationCount, Tol, ...
        (FinalContentWidth - FinalPaperWidthCm) / FinalPaperWidthCm, ...
        (FinalContentHeight - FinalPaperHeightCm) / FinalPaperHeightCm);
else
    fprintf('Target Position-box size: %.3g x %.3g cm\n', ...
        TargetWidthCm, TargetHeightCm);
    fprintf(['Reserved margins [L B R T]: ' ...
             '[%.3g %.3g %.3g %.3g] cm\n'], ...
        ReservedMarginsCm(1), ReservedMarginsCm(2), ...
        ReservedMarginsCm(3), ReservedMarginsCm(4));
end

fprintf(['Final content boundary [L B R T]: ' ...
         '[%.3g %.3g %.3g %.3g] cm\n'], ...
    FinalContentBox(1), FinalContentBox(2), ...
    FinalContentBox(3), FinalContentBox(4));

fprintf('Final paper size: %.3g x %.3g cm\n', ...
    FinalPaperWidthCm, FinalPaperHeightCm);
fprintf('PDF file exported to: %s\n', mu.getabspath(FileName));
fprintf('================== Done ===================\n');

if Opts.debug
    TempFig.Visible = "on";
    uiwait(TempFig);
end

clear CleanupObj;
end

%% Local functions
function [IterationCount, ContentBox, ContentWidth, ContentHeight] = ...
    FitTightInsetPage(FigHandle, LayoutRoots, PageWidthCm, PageHeightCm, ...
    SafetyCm, Tol, MaxIter)
% Fit measured visible content into a fixed page and center it.

InnerWidthCm = max(PageWidthCm - 2 * SafetyCm, eps);
InnerHeightCm = max(PageHeightCm - 2 * SafetyCm, eps);
IterationCount = 0;

for IterationIndex = 1:MaxIter
    IterationCount = IterationIndex;
    drawnow;

    [ContentBox, ContentWidth, ContentHeight] = ...
        GetContentBorderBox(FigHandle, LayoutRoots, "centimeters");

    WidthDifference = ...
        (ContentWidth - InnerWidthCm) / InnerWidthCm;
    HeightDifference = ...
        (ContentHeight - InnerHeightCm) / InnerHeightCm;

    if abs(WidthDifference) <= Tol && ...
            abs(HeightDifference) <= Tol
        break;
    end

    ScaleX = InnerWidthCm / ContentWidth;
    ScaleY = InnerHeightCm / ContentHeight;

    if ~all(isfinite([ScaleX, ScaleY])) || ...
            any([ScaleX, ScaleY] <= 0)
        error('exportFigure2PDF:InvalidFitScale', ...
            'Invalid TightInset fitting scale: [%g %g].', ...
            ScaleX, ScaleY);
    end

    % Damping suppresses oscillations caused by text/layout quantization.
    ScaleX = 1 + 0.8 * (ScaleX - 1);
    ScaleY = 1 + 0.8 * (ScaleY - 1);
    ScaleX = min(max(ScaleX, 0.5), 2);
    ScaleY = min(max(ScaleY, 0.5), 2);

    RootPositionCm = GetRootPositions( ...
        LayoutRoots, FigHandle, "centimeters");

    RootPositionCm(:, 1) = ...
        SafetyCm + ...
        (RootPositionCm(:, 1) - ContentBox(1)) * ScaleX;
    RootPositionCm(:, 2) = ...
        SafetyCm + ...
        (RootPositionCm(:, 2) - ContentBox(2)) * ScaleY;
    RootPositionCm(:, 3) = RootPositionCm(:, 3) * ScaleX;
    RootPositionCm(:, 4) = RootPositionCm(:, 4) * ScaleY;

    AssignAbsoluteRootPositions( ...
        LayoutRoots, RootPositionCm, FigHandle, "centimeters");
end

drawnow;
[ContentBox, ContentWidth, ContentHeight] = ...
    GetContentBorderBox(FigHandle, LayoutRoots, "centimeters");

% If renderer quantization leaves the content slightly too large, apply one
% final shrink-only correction before centering.
FinalScale = min([ ...
    1, ...
    InnerWidthCm / ContentWidth, ...
    InnerHeightCm / ContentHeight]);

if isfinite(FinalScale) && FinalScale > 0 && FinalScale < 1
    RootPositionCm = GetRootPositions( ...
        LayoutRoots, FigHandle, "centimeters");

    RootPositionCm(:, 1) = ...
        SafetyCm + ...
        (RootPositionCm(:, 1) - ContentBox(1)) * FinalScale;
    RootPositionCm(:, 2) = ...
        SafetyCm + ...
        (RootPositionCm(:, 2) - ContentBox(2)) * FinalScale;
    RootPositionCm(:, 3:4) = ...
        RootPositionCm(:, 3:4) * FinalScale;

    AssignAbsoluteRootPositions( ...
        LayoutRoots, RootPositionCm, FigHandle, "centimeters");
    drawnow;

    [ContentBox, ContentWidth, ContentHeight] = ...
        GetContentBorderBox(FigHandle, LayoutRoots, "centimeters");
end

TargetLeftCm = SafetyCm + ...
    max(0, InnerWidthCm - ContentWidth) / 2;
TargetBottomCm = SafetyCm + ...
    max(0, InnerHeightCm - ContentHeight) / 2;

ShiftRoots(LayoutRoots, FigHandle, ...
    TargetLeftCm - ContentBox(1), ...
    TargetBottomCm - ContentBox(2), ...
    "centimeters");

drawnow;

[ContentBox, ContentWidth, ContentHeight] = ...
    GetContentBorderBox(FigHandle, LayoutRoots, "centimeters");
end

function [MarginsCm, PageWidthCm, PageHeightCm, ContentBox, ...
    ContentWidth, ContentHeight, IterationCount] = FitPositionPage( ...
    FigHandle, LayoutRoots, BaseRootPositionCm, ...
    PositionWidthCm, PositionHeightCm, InitialMarginsCm, ...
    SafetyCm, Tol, MaxIter)
% Preserve the Position-box size while growing margins on any overflowing side.

MarginsCm = max(InitialMarginsCm, 0);
IterationCount = 0;
ContentBox = [NaN, NaN, NaN, NaN];
ContentWidth = NaN;
ContentHeight = NaN;

for IterationIndex = 1:MaxIter
    IterationCount = IterationIndex;

    PageWidthCm = ...
        PositionWidthCm + MarginsCm(1) + MarginsCm(3);
    PageHeightCm = ...
        PositionHeightCm + MarginsCm(2) + MarginsCm(4);

    SetFigureSize(FigHandle, PageWidthCm, PageHeightCm);

    TargetRootPositionCm = BaseRootPositionCm;
    TargetRootPositionCm(:, 1) = ...
        TargetRootPositionCm(:, 1) + MarginsCm(1);
    TargetRootPositionCm(:, 2) = ...
        TargetRootPositionCm(:, 2) + MarginsCm(2);

    AssignAbsoluteRootPositions( ...
        LayoutRoots, TargetRootPositionCm, ...
        FigHandle, "centimeters");
    drawnow;

    % Managed layouts can rewrite positions during drawnow.
    AssignAbsoluteRootPositions( ...
        LayoutRoots, TargetRootPositionCm, ...
        FigHandle, "centimeters");
    drawnow;

    RootPositionCheckCm = GetRootPositions( ...
        LayoutRoots, FigHandle, "centimeters");
    [PositionBoxNow, ~, ~] = GetBoxUnion(RootPositionCheckCm);

    ShiftRoots(LayoutRoots, FigHandle, ...
        MarginsCm(1) - PositionBoxNow(1), ...
        MarginsCm(2) - PositionBoxNow(2), ...
        "centimeters");
    drawnow;

    [ContentBox, ContentWidth, ContentHeight] = ...
        GetContentBorderBox(FigHandle, LayoutRoots, "centimeters");

    OverflowCm = [ ...
        max(0, SafetyCm - ContentBox(1)), ...
        max(0, SafetyCm - ContentBox(2)), ...
        max(0, ContentBox(3) + SafetyCm - PageWidthCm), ...
        max(0, ContentBox(4) + SafetyCm - PageHeightCm)];

    if all(OverflowCm <= max(Tol, 1e-6))
        break;
    end

    % Add only the missing space on the overflowing side. Left/bottom growth
    % shifts the Position box right/up on the next iteration; right/top
    % growth changes only the page boundary.
    MarginsCm = MarginsCm + OverflowCm;
end

PageWidthCm = ...
    PositionWidthCm + MarginsCm(1) + MarginsCm(3);
PageHeightCm = ...
    PositionHeightCm + MarginsCm(2) + MarginsCm(4);

% Rebuild the final geometry from the immutable Position-box reference.
SetFigureSize(FigHandle, PageWidthCm, PageHeightCm);
FinalRootPositionCm = BaseRootPositionCm;
FinalRootPositionCm(:, 1) = ...
    FinalRootPositionCm(:, 1) + MarginsCm(1);
FinalRootPositionCm(:, 2) = ...
    FinalRootPositionCm(:, 2) + MarginsCm(2);

AssignAbsoluteRootPositions( ...
    LayoutRoots, FinalRootPositionCm, FigHandle, "centimeters");
drawnow;
AssignAbsoluteRootPositions( ...
    LayoutRoots, FinalRootPositionCm, FigHandle, "centimeters");
drawnow;

FinalRootPositionCheckCm = GetRootPositions( ...
    LayoutRoots, FigHandle, "centimeters");
[FinalPositionBox, ~, ~] = GetBoxUnion(FinalRootPositionCheckCm);
ShiftRoots(LayoutRoots, FigHandle, ...
    MarginsCm(1) - FinalPositionBox(1), ...
    MarginsCm(2) - FinalPositionBox(2), ...
    "centimeters");
drawnow;

[ContentBox, ContentWidth, ContentHeight] = ...
    GetContentBorderBox(FigHandle, LayoutRoots, "centimeters");
end

function MarginsCm = EstimatePositionMargins( ...
    FigHandle, LayoutRoots, SafetyCm)
% Estimate [left bottom right top] margins using a temporary padded canvas.

OriginalRootPositionCm = GetRootPositions( ...
    LayoutRoots, FigHandle, "centimeters");
[OriginalPositionBox, PositionWidthCm, PositionHeightCm] = ...
    GetBoxUnion(OriginalRootPositionCm);

OldFigureUnits = FigHandle.Units;
FigHandle.Units = "centimeters";
OriginalFigurePositionCm = double(FigHandle.Position);
FigHandle.Units = OldFigureUnits;

CleanupObj = onCleanup(@() RestorePositionMarginProbe( ...
    FigHandle, LayoutRoots, OriginalFigurePositionCm, ...
    OriginalRootPositionCm));

ProbeLeftCm = max(3, 0.15 * PositionWidthCm);
ProbeRightCm = ProbeLeftCm;
ProbeBottomCm = max(3, 0.15 * PositionHeightCm);
ProbeTopCm = ProbeBottomCm;

ProbeFigureWidthCm = ...
    PositionWidthCm + ProbeLeftCm + ProbeRightCm;
ProbeFigureHeightCm = ...
    PositionHeightCm + ProbeBottomCm + ProbeTopCm;

SetFigureSize( ...
    FigHandle, ProbeFigureWidthCm, ProbeFigureHeightCm);

ProbeRootPositionCm = OriginalRootPositionCm;
ProbeRootPositionCm(:, 1) = ...
    ProbeRootPositionCm(:, 1) + ...
    ProbeLeftCm - OriginalPositionBox(1);
ProbeRootPositionCm(:, 2) = ...
    ProbeRootPositionCm(:, 2) + ...
    ProbeBottomCm - OriginalPositionBox(2);

AssignAbsoluteRootPositions( ...
    LayoutRoots, ProbeRootPositionCm, ...
    FigHandle, "centimeters");
drawnow;
AssignAbsoluteRootPositions( ...
    LayoutRoots, ProbeRootPositionCm, ...
    FigHandle, "centimeters");
drawnow;

ActualRootPositionCm = GetRootPositions( ...
    LayoutRoots, FigHandle, "centimeters");
[PositionBox, ~, ~] = GetBoxUnion(ActualRootPositionCm);
[ContentBox, ~, ~] = GetContentBorderBox( ...
    FigHandle, LayoutRoots, "centimeters");

RawMarginsCm = [ ...
    max(0, PositionBox(1) - ContentBox(1)), ...
    max(0, PositionBox(2) - ContentBox(2)), ...
    max(0, ContentBox(3) - PositionBox(3)), ...
    max(0, ContentBox(4) - PositionBox(4))];

% A modest safety factor handles font-renderer differences. The subsequent
% four-side containment loop corrects any remaining underestimation.
SafetyFactor = 1.1;
MarginsCm = RawMarginsCm * SafetyFactor;
MarginsCm(RawMarginsCm > 0) = ...
    MarginsCm(RawMarginsCm > 0) + SafetyCm;
MarginsCm = max(MarginsCm, 0);

clear CleanupObj;
end

function ExportExactPage(FigHandle, FileName, WidthCm, HeightCm)
% Export the complete figure canvas instead of exportgraphics' default crop.

FigHandle.PaperUnits = "centimeters";
FigHandle.PaperPositionMode = "manual";
FigHandle.PaperPosition = [0, 0, WidthCm, HeightCm];
FigHandle.PaperSize = [WidthCm, HeightCm];

drawnow;

if ~isMATLABReleaseOlderThan('R2025a')
    % R2025a and newer: explicit output dimensions plus Padding="figure"
    % preserve the full figure canvas and exact PDF page dimensions.
    exportgraphics(FigHandle, FileName, ...
        'ContentType', 'vector', ...
        'BackgroundColor', 'none', ...
        'Colorspace', 'rgb', ...
        'Resolution', 600, ...
        'Units', 'centimeters', ...
        'Width', WidthCm, ...
        'Height', HeightCm, ...
        'Padding', 'figure', ...
        'PreserveAspectRatio', 'off');
else
    % Compatibility fallback for releases without Width/Height/Padding.
    OldColor = FigHandle.Color;
    OldInvertHardcopy = FigHandle.InvertHardcopy;
    CleanupObj = onCleanup(@() RestorePrintProperties( ...
        FigHandle, OldColor, OldInvertHardcopy));

    FigHandle.Color = 'none';
    FigHandle.InvertHardcopy = 'off';

    try
        print(FigHandle, char(FileName), ...
            '-dpdf', '-vector', '-r600');
    catch
        print(FigHandle, char(FileName), ...
            '-dpdf', '-painters', '-r600');
    end

    clear CleanupObj;
end
end

function LayoutRoots = GetLayoutRoots(FigHandle)
% Return top-level writable objects that define the figure layout.

Children = FigHandle.Children;
Keep = false(size(Children));

for ObjectIndex = 1:numel(Children)
    ObjectHandle = Children(ObjectIndex);
    Keep(ObjectIndex) = ...
        isgraphics(ObjectHandle) && ...
        isprop(ObjectHandle, 'Units') && ...
        isprop(ObjectHandle, 'Position') && ...
        IsWritableProperty(ObjectHandle, 'Units') && ...
        IsWritableProperty(ObjectHandle, 'Position');
end

LayoutRoots = Children(Keep);
end

function IsWritable = IsWritableProperty(ObjectHandle, PropertyName)
try
    OldValue = ObjectHandle.(PropertyName);
    ObjectHandle.(PropertyName) = OldValue;
    IsWritable = true;
catch
    IsWritable = false;
end
end

function SetFigureSize(FigHandle, WidthCm, HeightCm)
try
    FigHandle.WindowState = "normal";
catch
end

OldUnits = FigHandle.Units;
FigHandle.Units = "centimeters";
FigHandle.Position = [1, 1, WidthCm, HeightCm];
FigHandle.Units = OldUnits;

FigHandle.PaperUnits = "centimeters";
FigHandle.PaperPositionMode = "manual";
FigHandle.PaperPosition = [0, 0, WidthCm, HeightCm];
FigHandle.PaperSize = [WidthCm, HeightCm];

drawnow;
end

function PositionAll = GetRootPositions( ...
    LayoutRoots, FigHandle, Units)
PositionAll = zeros(numel(LayoutRoots), 4);

for RootIndex = 1:numel(LayoutRoots)
    PositionAll(RootIndex, :) = GetAbsolutePosition( ...
        LayoutRoots(RootIndex), FigHandle, Units);
end
end

function AssignAbsoluteRootPositions( ...
    LayoutRoots, PositionAll, FigHandle, Units)
for RootIndex = 1:numel(LayoutRoots)
    SetAbsolutePosition( ...
        LayoutRoots(RootIndex), PositionAll(RootIndex, :), ...
        FigHandle, Units);
end
end

function ShiftRoots(LayoutRoots, FigHandle, DeltaX, DeltaY, Units)
PositionAll = GetRootPositions(LayoutRoots, FigHandle, Units);
PositionAll(:, 1) = PositionAll(:, 1) + DeltaX;
PositionAll(:, 2) = PositionAll(:, 2) + DeltaY;
AssignAbsoluteRootPositions( ...
    LayoutRoots, PositionAll, FigHandle, Units);
end

function [BorderBox, BoxWidth, BoxHeight] = GetContentBorderBox( ...
    FigHandle, LayoutRoots, Units)
% Recursively measure axes decorations, text, legends, and colorbars.

MeasurementObjects = CollectMeasurementObjects(LayoutRoots);
BoxAll = zeros(0, 4);

for ObjectIndex = 1:numel(MeasurementObjects)
    ObjectHandle = MeasurementObjects(ObjectIndex);
    TypeName = lower(string(GetObjectType(ObjectHandle)));

    try
        if TypeName == "text"
            TextBox = GetTextExtentAbsolute( ...
                ObjectHandle, FigHandle, Units);

            if all(isfinite(TextBox)) && ...
                    TextBox(3) >= 0 && TextBox(4) >= 0
                BoxAll(end + 1, :) = [ ...
                    TextBox(1), TextBox(2), ...
                    TextBox(1) + TextBox(3), ...
                    TextBox(2) + TextBox(4)]; %#ok<AGROW>
            end
            continue;
        end

        Position = GetAbsolutePosition( ...
            ObjectHandle, FigHandle, Units);

        if ~all(isfinite(Position)) || ...
                Position(3) < 0 || Position(4) < 0
            continue;
        end

        Inset = zeros(1, 4);

        if IsAxesLike(ObjectHandle)
            Inset = GetAbsoluteTightInset(ObjectHandle, Units);
        elseif TypeName == "colorbar"
            Inset = GetColorbarLabelInsetAbsolute( ...
                ObjectHandle, FigHandle, Units);
        end

        BoxAll(end + 1, :) = [ ...
            Position(1) - Inset(1), ...
            Position(2) - Inset(2), ...
            Position(1) + Position(3) + Inset(3), ...
            Position(2) + Position(4) + Inset(4)]; %#ok<AGROW>
    catch
        % Unsupported or transient graphics objects are ignored.
    end
end

if isempty(BoxAll)
    RootPosition = GetRootPositions( ...
        LayoutRoots, FigHandle, Units);
    [BorderBox, BoxWidth, BoxHeight] = GetBoxUnion(RootPosition);
    return;
end

BorderBox = [ ...
    min(BoxAll(:, 1)), ...
    min(BoxAll(:, 2)), ...
    max(BoxAll(:, 3)), ...
    max(BoxAll(:, 4))];
BoxWidth = BorderBox(3) - BorderBox(1);
BoxHeight = BorderBox(4) - BorderBox(2);
end

function MeasurementObjects = CollectMeasurementObjects(LayoutRoots)
MeasurementObjects = gobjects(0);

for RootIndex = 1:numel(LayoutRoots)
    RootHandle = LayoutRoots(RootIndex);
    Descendants = findall(RootHandle);
    RootObjects = gobjects(0);

    for ObjectIndex = 1:numel(Descendants)
        ObjectHandle = Descendants(ObjectIndex);

        if ~isgraphics(ObjectHandle) || ~IsVisible(ObjectHandle)
            continue;
        end

        TypeName = lower(string(GetObjectType(ObjectHandle)));
        IsRelevant = ...
            IsAxesLike(ObjectHandle) || ...
            TypeName == "legend" || ...
            TypeName == "colorbar" || ...
            TypeName == "text";

        if ~IsRelevant
            continue;
        end

        if TypeName == "text"
            try
                TextString = string(ObjectHandle.String);
                if isempty(TextString) || ...
                        all(strlength(TextString) == 0)
                    continue;
                end
            catch
            end
        end

        RootObjects(end + 1, 1) = ObjectHandle; %#ok<AGROW>
    end

    if isempty(RootObjects)
        RootObjects = RootHandle;
    end

    MeasurementObjects = [ ...
        MeasurementObjects; RootObjects(:)]; %#ok<AGROW>
end

if ~isempty(MeasurementObjects)
    MeasurementObjects = unique(MeasurementObjects, 'stable');
end
end

function IsAxes = IsAxesLike(ObjectHandle)
IsAxes = ...
    isa(ObjectHandle, 'matlab.graphics.axis.Axes') || ...
    isa(ObjectHandle, 'matlab.graphics.axis.PolarAxes') || ...
    isa(ObjectHandle, 'matlab.graphics.axis.GeographicAxes');
end

function IsObjectVisible = IsVisible(ObjectHandle)
IsObjectVisible = true;
try
    IsObjectVisible = strcmpi(string(ObjectHandle.Visible), "on");
catch
end
end

function TypeName = GetObjectType(ObjectHandle)
try
    TypeName = string(ObjectHandle.Type);
catch
    TypeName = string(class(ObjectHandle));
end
end

function Position = GetAbsolutePosition(ObjectHandle, FigHandle, Units)
try
    PixelPosition = double(getpixelposition(ObjectHandle, true));
catch
    PixelPosition = GetAbsolutePixelPositionFallback( ...
        ObjectHandle, FigHandle);
end

switch lower(string(Units))
    case "pixels"
        Position = PixelPosition;
    case "centimeters"
        Position = PixelPosition * PixelToCentimeterScale(FigHandle);
    case "inches"
        Position = PixelPosition / GetPixelsPerInch(FigHandle);
    otherwise
        error('exportFigure2PDF:UnsupportedUnits', ...
            'Unsupported absolute unit: %s.', Units);
end
end

function PixelPosition = GetAbsolutePixelPositionFallback( ...
    ObjectHandle, FigHandle)
OldUnits = ObjectHandle.Units;
CleanupObj = onCleanup(@() set(ObjectHandle, 'Units', OldUnits));
ObjectHandle.Units = "normalized";
LocalPosition = double(ObjectHandle.Position);
ParentHandle = ObjectHandle.Parent;

if ParentHandle == FigHandle
    FigurePixelPosition = double(getpixelposition(FigHandle));
    PixelPosition = [ ...
        LocalPosition(1) * FigurePixelPosition(3), ...
        LocalPosition(2) * FigurePixelPosition(4), ...
        LocalPosition(3) * FigurePixelPosition(3), ...
        LocalPosition(4) * FigurePixelPosition(4)];
    return;
end

ParentPixelPosition = double(getpixelposition(ParentHandle, true));
PixelPosition = [ ...
    ParentPixelPosition(1) + ...
        LocalPosition(1) * ParentPixelPosition(3), ...
    ParentPixelPosition(2) + ...
        LocalPosition(2) * ParentPixelPosition(4), ...
    LocalPosition(3) * ParentPixelPosition(3), ...
    LocalPosition(4) * ParentPixelPosition(4)];

clear CleanupObj;
end

function SetAbsolutePosition(ObjectHandle, Position, FigHandle, Units)
switch lower(string(Units))
    case "pixels"
        PixelPosition = Position;
    case "centimeters"
        PixelPosition = Position / PixelToCentimeterScale(FigHandle);
    case "inches"
        PixelPosition = Position * GetPixelsPerInch(FigHandle);
    otherwise
        error('exportFigure2PDF:UnsupportedUnits', ...
            'Unsupported absolute unit: %s.', Units);
end

ParentHandle = ObjectHandle.Parent;

if ParentHandle == FigHandle
    ParentPixelPosition = double(getpixelposition(FigHandle));
    ParentWidth = ParentPixelPosition(3);
    ParentHeight = ParentPixelPosition(4);
    LocalPosition = [ ...
        PixelPosition(1) / ParentWidth, ...
        PixelPosition(2) / ParentHeight, ...
        PixelPosition(3) / ParentWidth, ...
        PixelPosition(4) / ParentHeight];
else
    ParentPixelPosition = double(getpixelposition(ParentHandle, true));
    LocalPosition = [ ...
        (PixelPosition(1) - ParentPixelPosition(1)) / ...
            ParentPixelPosition(3), ...
        (PixelPosition(2) - ParentPixelPosition(2)) / ...
            ParentPixelPosition(4), ...
        PixelPosition(3) / ParentPixelPosition(3), ...
        PixelPosition(4) / ParentPixelPosition(4)];
end

OldUnits = ObjectHandle.Units;
CleanupObj = onCleanup(@() set(ObjectHandle, 'Units', OldUnits));
ObjectHandle.Units = "normalized";
ObjectHandle.Position = LocalPosition;
clear CleanupObj;
end

function Inset = GetAbsoluteTightInset(AxesHandle, Units)
OldUnits = AxesHandle.Units;
CleanupObj = onCleanup(@() set(AxesHandle, 'Units', OldUnits));
AxesHandle.Units = "pixels";
InsetPixels = double(AxesHandle.TightInset);
FigHandle = ancestor(AxesHandle, 'figure');

switch lower(string(Units))
    case "pixels"
        Inset = InsetPixels;
    case "centimeters"
        Inset = InsetPixels * PixelToCentimeterScale(FigHandle);
    case "inches"
        Inset = InsetPixels / GetPixelsPerInch(FigHandle);
    otherwise
        error('exportFigure2PDF:UnsupportedUnits', ...
            'Unsupported absolute unit: %s.', Units);
end

clear CleanupObj;
end

function Inset = GetColorbarLabelInsetAbsolute( ...
    ColorbarHandle, FigHandle, Units)
Inset = zeros(1, 4);

try
    ColorbarPosition = GetAbsolutePosition( ...
        ColorbarHandle, FigHandle, Units);
    LabelHandle = ColorbarHandle.Label;
    OldUnits = LabelHandle.Units;
    CleanupObj = onCleanup(@() set(LabelHandle, 'Units', OldUnits));
    LabelHandle.Units = "pixels";
    LabelExtentPixels = double(LabelHandle.Extent);

    switch lower(string(Units))
        case "pixels"
            LabelExtent = LabelExtentPixels;
        case "centimeters"
            LabelExtent = LabelExtentPixels * ...
                PixelToCentimeterScale(FigHandle);
        case "inches"
            LabelExtent = LabelExtentPixels / ...
                GetPixelsPerInch(FigHandle);
        otherwise
            return;
    end

    Location = lower(string(ColorbarHandle.Location));

    if ColorbarPosition(4) >= ColorbarPosition(3)
        ExtraWidth = max(0, LabelExtent(3));
        if contains(Location, "west")
            Inset(1) = ExtraWidth;
        else
            Inset(3) = ExtraWidth;
        end
    else
        ExtraHeight = max(0, LabelExtent(4));
        if contains(Location, "south")
            Inset(2) = ExtraHeight;
        else
            Inset(4) = ExtraHeight;
        end
    end

    clear CleanupObj;
catch
    Inset = zeros(1, 4);
end
end

function Box = GetTextExtentAbsolute(TextHandle, FigHandle, Units)
OldUnits = TextHandle.Units;
CleanupObj = onCleanup(@() set(TextHandle, 'Units', OldUnits));
TextHandle.Units = "pixels";
ExtentPixels = double(TextHandle.Extent);
ParentHandle = TextHandle.Parent;

if isa(ParentHandle, 'matlab.ui.Figure')
    ParentOriginPixels = [0, 0];
else
    try
        ParentPositionPixels = double( ...
            getpixelposition(ParentHandle, true));
        ParentOriginPixels = ParentPositionPixels(1:2);
    catch
        ParentOriginPixels = [0, 0];
    end
end

BoxPixels = [ ...
    ParentOriginPixels(1) + ExtentPixels(1), ...
    ParentOriginPixels(2) + ExtentPixels(2), ...
    ExtentPixels(3), ExtentPixels(4)];

switch lower(string(Units))
    case "pixels"
        Box = BoxPixels;
    case "centimeters"
        Box = BoxPixels * PixelToCentimeterScale(FigHandle);
    case "inches"
        Box = BoxPixels / GetPixelsPerInch(FigHandle);
    otherwise
        error('exportFigure2PDF:UnsupportedUnits', ...
            'Unsupported absolute unit: %s.', Units);
end

clear CleanupObj;
end

function [BorderBox, BoxWidth, BoxHeight] = GetBoxUnion(PositionAll)
if isempty(PositionAll)
    error('exportFigure2PDF:EmptyPositionList', ...
        'Cannot calculate a boundary from an empty position list.');
end

BoxAll = [ ...
    PositionAll(:, 1), ...
    PositionAll(:, 2), ...
    PositionAll(:, 1) + PositionAll(:, 3), ...
    PositionAll(:, 2) + PositionAll(:, 4)];

BorderBox = [ ...
    min(BoxAll(:, 1)), ...
    min(BoxAll(:, 2)), ...
    max(BoxAll(:, 3)), ...
    max(BoxAll(:, 4))];
BoxWidth = BorderBox(3) - BorderBox(1);
BoxHeight = BorderBox(4) - BorderBox(2);
end

function Scale = PixelToCentimeterScale(FigHandle)
Scale = 2.54 / GetPixelsPerInch(FigHandle);
end

function PixelsPerInch = GetPixelsPerInch(~)
try
    PixelsPerInch = double(groot.ScreenPixelsPerInch);
catch
    PixelsPerInch = 96;
end

if isempty(PixelsPerInch) || ...
        ~isfinite(PixelsPerInch) || PixelsPerInch <= 0
    PixelsPerInch = 96;
end
end

function DisableToolbars(FigHandle)
AxesAll = findall(FigHandle, '-property', 'Toolbar');

for AxesIndex = 1:numel(AxesAll)
    try
        ToolbarHandle = AxesAll(AxesIndex).Toolbar;
        if ~isempty(ToolbarHandle)
            ToolbarHandle.Visible = "off";
        end
    catch
    end
end
end

function RestorePositionMarginProbe( ...
    FigHandle, LayoutRoots, OriginalFigurePositionCm, ...
    OriginalRootPositionCm)
if isempty(FigHandle) || ~isvalid(FigHandle)
    return;
end

try
    FigHandle.WindowState = "normal";
catch
end

try
    OldUnits = FigHandle.Units;
    FigHandle.Units = "centimeters";
    FigHandle.Position = OriginalFigurePositionCm;
    FigHandle.Units = OldUnits;

    FigHandle.PaperUnits = "centimeters";
    FigHandle.PaperPositionMode = "manual";
    FigHandle.PaperPosition = [ ...
        0, 0, OriginalFigurePositionCm(3), ...
        OriginalFigurePositionCm(4)];
    FigHandle.PaperSize = OriginalFigurePositionCm(3:4);

    drawnow;
    AssignAbsoluteRootPositions( ...
        LayoutRoots, OriginalRootPositionCm, ...
        FigHandle, "centimeters");
    drawnow;
    AssignAbsoluteRootPositions( ...
        LayoutRoots, OriginalRootPositionCm, ...
        FigHandle, "centimeters");
    drawnow;
catch
    % Do not mask the original error during cleanup.
end
end

function RestorePrintProperties( ...
    FigHandle, OldColor, OldInvertHardcopy)
if isempty(FigHandle) || ~isvalid(FigHandle)
    return;
end

try
    FigHandle.Color = OldColor;
    FigHandle.InvertHardcopy = OldInvertHardcopy;
catch
end
end

function CloseIfValid(FigHandle)
if ~isempty(FigHandle) && isvalid(FigHandle)
    close(FigHandle);
end
end
