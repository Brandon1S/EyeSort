function mode = toggle_eeglab_autosave(newMode)
% TOGGLE_EEGLAB_AUTOSAVE - Disable or enable EEGLAB's automatic save prompts
%
% Usage:
%   >> currentMode = toggle_eeglab_autosave('disable'); % Disable auto-save prompts
%   >> currentMode = toggle_eeglab_autosave('enable');  % Re-enable auto-save prompts
%   >> currentMode = toggle_eeglab_autosave('query');   % Just return current setting
%
% Inputs:
%   newMode - 'disable', 'enable', or 'query'
%
% Outputs:
%   mode    - The current setting after function execution ('on' or 'off')
%
% Note: This function modifies the global EEGLAB options to control whether
%       pop_saveset() dialogs appear automatically when datasets are modified.
%       It should be used in pairs - disable before a batch operation and
%       enable after it is complete.

% Access global EEGLAB options
global EEG_OPTIONS;

% Initialize return value
mode = '';

% Create EEG_OPTIONS if it doesn't exist yet
if isempty(EEG_OPTIONS)
    EEG_OPTIONS = eeg_options;
end

% Store current setting
if isfield(EEG_OPTIONS, 'savedata')
    currentSetting = EEG_OPTIONS.savedata;
else
    currentSetting = 'on'; % Default in EEGLAB
end

% Process command
switch lower(newMode)
    case 'disable'
        % Store original setting if not already saved
        if ~isfield(EEG_OPTIONS, 'savedata_original')
            EEG_OPTIONS.savedata_original = currentSetting;
        end
        % Disable auto-save
        EEG_OPTIONS.savedata = 'off';
        fprintf('EEGLAB auto-save dialogs disabled\n');
        mode = 'off';
        
    case 'enable'
        % Restore original setting if available
        if isfield(EEG_OPTIONS, 'savedata_original')
            EEG_OPTIONS.savedata = EEG_OPTIONS.savedata_original;
            EEG_OPTIONS = rmfield(EEG_OPTIONS, 'savedata_original');
        else
            % If no original setting stored, default to 'on'
            EEG_OPTIONS.savedata = 'on';
        end
        fprintf('EEGLAB auto-save dialogs enabled\n');
        mode = EEG_OPTIONS.savedata;
        
    case 'query'
        % Just return current setting
        mode = currentSetting;
        
    otherwise
        error('Unknown mode: %s. Use ''disable'', ''enable'', or ''query''.', newMode);
end

end 