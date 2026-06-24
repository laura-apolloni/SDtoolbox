function comparisonResults = compareDetectionsToAnnotationsModified(subj, rootFolder, startDatetime, chanNames, requireDepression, depressionPreWinMin, depressionPostWinMin, depressionSigma, depressionMinDurSec)
% COMPAREDETECTIONSTOANNOTATIONSMODIFIED
%   Modified version of compareDetectionsToAnnotations for use with
%   sourceLocalizerModified. Mirrors the original as closely as possible.
%
%   Key differences from the original:
%     - Constructs a fresh sourceLocalizerModified object and loads from EDF
%       (rather than loading sl.mat) so rawTimeSeries is available for the
%       depression qualifier.
%     - Calls prepareDeltaPosition instead of populateSpikes directly, so
%       the depression qualifier (filterSeqByDepression) can fire.
%     - Accepts chanNames explicitly since EDF channel labels may differ
%       from sl.chanNames saved in sl.mat (e.g. CSSD06 uses 'EEG AUX1-AuxR').
%     - Three optional depression qualifier parameters appended at the end.
%
%   Everything else — timeWindow, comparison math, output struct, plot call
%   — is identical to the original.
%
% Usage:
%   % Basic (no depression qualifier, mirrors original behavior):
%   comparisonResults = compareDetectionsToAnnotations_modified( ...
%       'CSSD06', rootFolder, startDatetime, ...
%       {'EEG AUX1-AuxR','EEG AUX2-AuxR','EEG AUX3-AuxR','EEG AUX4-AuxR', ...
%        'EEG AUX5-AuxR','EEG AUX6-AuxR','EEG AUX7-AuxR','EEG AUX8-AuxR'});
%
%   % With depression qualifier:
%   comparisonResults = compareDetectionsToAnnotations_modified( ...
%       'CSSD06', rootFolder, startDatetime, chanNames, true, 10, 1);

if nargin < 3, startDatetime      = [];    end
if nargin < 4, chanNames          = {};    end
if nargin < 5, requireDepression  = false; end
if nargin < 6, depressionPreWinMin  = 5;  end
if nargin < 7, depressionPostWinMin = 5;  end
if nargin < 8, depressionSigma    = 1;    end
if nargin < 9, depressionMinDurSec = 120; end

% Construct fresh object and load from EDF (not sl.mat) so timeSeries is
% raw and rawTimeSeries can be stashed before findSpikeTimes filters it.
sl = sourceLocalizerModified(subj, rootFolder);
if ~isempty(chanNames)
    sl.chanNames = chanNames;
end
sl.loadTimeSeries();

timeWindow = 5; % Minutes
timeWindow = timeWindow * 60 * sl.Fs; % Samples

%% Pull detections

% Use prepareDeltaPosition instead of populateSpikes directly so the
% depression qualifier (filterSeqByDepression) is available. All other
% detection behavior is identical to calling populateSpikes('forceNew',true).
sl.prepareDeltaPosition('forceNew', true, ...
    'detectionMode',        'auto', ...
    'requireDepression',    requireDepression, ...
    'depressionPreWinMin',  depressionPreWinMin, ...
    'depressionPostWinMin', depressionPostWinMin, ...
    'depressionSigma',      depressionSigma, ...
    'depressionMinDurSec',  depressionMinDurSec);

rasterDetected = sl.spikeDetectionResults.rasters;
[iiAuto,jjAuto] = find(rasterDetected); % In samples, from clip start...

%% Pull annotations

[s, clipDetails] = spreadsheetToSDTimes(sl.rootFolder, sl.subj, 'chanNames', sl.chanNames);
populateSeqFromAnnotations_laura(sl, s, clipDetails);

rasterAnnotated = sl.spikeDetectionResults.rasters;
[iiManual,jjManual] = find(rasterAnnotated);

%% Compare

timeMatch = abs(iiManual - iiAuto') <= timeWindow;
leadMatch = jjManual == jjAuto';

sens = any(timeMatch & leadMatch,2);
sens = sum(sens) / length(sens);

falseDetections = ~any(timeMatch & leadMatch);
falseDetections = sum(falseDetections) / length(falseDetections);

h = dbstack;
fprintf('[%s] Sensitivity is %.2f%%.\n',h.name,sens * 100)
fprintf('[%s] Ostensibly, %.2f%% of the automatic detections are false.\n',h.name,falseDetections * 100)

comparisonResults = struct( ...
    'rasterDetected',  rasterDetected, ...
    'rasterAnnotated', rasterAnnotated, ...
    'timeWindow',      timeWindow, ...
    'sens',            sens, ...
    'falseDetections', falseDetections);   % samples

sl.plotTimeSeries('spikePlottingMode','fromRaster', ...
    'comparisonResults', comparisonResults, ...
    'startDatetime',     startDatetime)

end
