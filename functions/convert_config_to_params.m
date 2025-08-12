function label_params = convert_config_to_params(config)
% CONVERT_CONFIG_TO_PARAMS - Convert GUI configuration to label parameters
%
% Usage:
%   label_params = convert_config_to_params(config)
%
% Inputs:
%   config - Label configuration structure from GUI
%
% Outputs:
%   label_params - Cell array of name-value parameter pairs for label_datasets_core

label_params = {};

% Time-locked regions
if isfield(config, 'selectedRegions') && ~isempty(config.selectedRegions)
    label_params{end+1} = 'timeLockedRegions';
    label_params{end+1} = config.selectedRegions;
end

% Pass options
passOptions = [];
if isfield(config, 'passFirstPass') && config.passFirstPass
    passOptions(end+1) = 2;
end
if isfield(config, 'passSecondPass') && config.passSecondPass
    passOptions(end+1) = 3;
end
if isfield(config, 'passThirdBeyond') && config.passThirdBeyond
    passOptions(end+1) = 4;
end
if isempty(passOptions)
    passOptions = 1;
end
label_params{end+1} = 'passOptions';
label_params{end+1} = passOptions;

% Previous regions
if isfield(config, 'selectedPrevRegions') && ~isempty(config.selectedPrevRegions)
    label_params{end+1} = 'prevRegions';
    label_params{end+1} = config.selectedPrevRegions;
end

% Next regions
if isfield(config, 'selectedNextRegions') && ~isempty(config.selectedNextRegions)
    label_params{end+1} = 'nextRegions';
    label_params{end+1} = config.selectedNextRegions;
end

% Fixation options
fixationOptions = [];
if isfield(config, 'fixFirstInRegion') && config.fixFirstInRegion
    fixationOptions(end+1) = 2;
end
if isfield(config, 'fixSingleFixation') && config.fixSingleFixation
    fixationOptions(end+1) = 3;
end
if isfield(config, 'fixSecondMultiple') && config.fixSecondMultiple
    fixationOptions(end+1) = 4;
end
if isfield(config, 'fixAllSubsequent') && config.fixAllSubsequent
    fixationOptions(end+1) = 5;
end
if isfield(config, 'fixLastInRegion') && config.fixLastInRegion
    fixationOptions(end+1) = 6;
end
if isempty(fixationOptions)
    fixationOptions = 1;
end
label_params{end+1} = 'fixationOptions';
label_params{end+1} = fixationOptions;

% Saccade in options
saccadeInOptions = [];
if isfield(config, 'saccadeInForward') && config.saccadeInForward
    saccadeInOptions(end+1) = 2;
end
if isfield(config, 'saccadeInBackward') && config.saccadeInBackward
    saccadeInOptions(end+1) = 3;
end
if isempty(saccadeInOptions)
    saccadeInOptions = 1;
end
label_params{end+1} = 'saccadeInOptions';
label_params{end+1} = saccadeInOptions;

% Saccade out options
saccadeOutOptions = [];
if isfield(config, 'saccadeOutForward') && config.saccadeOutForward
    saccadeOutOptions(end+1) = 2;
end
if isfield(config, 'saccadeOutBackward') && config.saccadeOutBackward
    saccadeOutOptions(end+1) = 3;
end
if isempty(saccadeOutOptions)
    saccadeOutOptions = 1;
end
label_params{end+1} = 'saccadeOutOptions';
label_params{end+1} = saccadeOutOptions;

end 