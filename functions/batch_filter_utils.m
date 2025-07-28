function [processed_count, com] = batch_filter_utils(action, varargin)
% BATCH_FILTER_UTILS - Utility functions for batch filtering operations
%
% Usage:
%   [processed_count, com] = batch_filter_utils('apply', batchFilePaths, batchFilenames, outputDir, filter_config)
%   batch_filter_utils('cleanup', batchFilePaths)

switch action
    case 'apply'
        [processed_count, com] = batch_apply_filters_internal(varargin{:});
    case 'cleanup'
        cleanup_temp_files_internal(varargin{:});
        processed_count = 0;
        com = '';
    otherwise
        error('Unknown action: %s', action);
end

end

function [processed_count, com] = batch_apply_filters_internal(batchFilePaths, batchFilenames, outputDir, filter_config)
% Apply filter configuration to all datasets in batch mode (memory efficient)

processed_count = 0;
failed_files = {};

% Create progress bar
h = waitbar(0, 'Applying filters to all datasets...', 'Name', 'Batch Filtering');

try
    for i = 1:length(batchFilePaths)
        waitbar(i/length(batchFilePaths), h, sprintf('Filtering dataset %d of %d: %s', i, length(batchFilePaths), batchFilenames{i}));
        
        try
            % Load dataset from file
            currentEEG = pop_loadset('filename', batchFilePaths{i});
            
            % Ensure the dataset has the required EyeSort processing
            if ~isfield(currentEEG, 'eyesort_field_names')
                warning('Dataset %s not processed with Text IA. Skipping...', batchFilenames{i});
                failed_files{end+1} = batchFilenames{i};
                continue;
            end
            
            % Convert configuration to filter parameters
            filter_params = convert_config_to_params(filter_config);
            
            % Apply the filter using the core function
            [filteredEEG, ~] = filter_datasets_core(currentEEG, filter_params{:});
            
            % Save the processed dataset
            [~, fileName, ~] = fileparts(batchFilenames{i});
            output_path = fullfile(outputDir, [fileName '_eyesort_filtered.set']);
            
            % Save with both .set and .fdt files
            pop_saveset(filteredEEG, 'filename', output_path, 'savemode', 'twofiles');
            
            processed_count = processed_count + 1;
            fprintf('Successfully filtered: %s\n', batchFilenames{i});
            
            % Clear dataset from memory to avoid accumulation
            clear currentEEG filteredEEG;
            
        catch ME
            warning('Failed to filter dataset %s: %s', batchFilenames{i}, ME.message);
            failed_files{end+1} = batchFilenames{i};
        end
    end
    
    % Close progress bar
    delete(h);
    
    % Show detailed results if there were failures
    if ~isempty(failed_files)
        warning_msg = sprintf('Batch filtering completed with some failures:\n\nSuccessful: %d\nFailed: %d\n\nFailed files:\n%s', ...
                            processed_count, length(failed_files), strjoin(failed_files, '\n'));
        msgbox(warning_msg, 'Batch Filtering Results', 'warn');
    end
    
    % Build command string for history
    com = sprintf('EEG = pop_filter_datasets(EEG); %% Batch filtered %d datasets', processed_count);
    
catch ME
    % Close progress bar if there was an error
    if exist('h', 'var') && ishandle(h)
        delete(h);
    end
    rethrow(ME);
end

end

function filter_params = convert_config_to_params(config)
% Convert GUI configuration structure to parameter list for core function

filter_params = {};

% Time-locked regions
if isfield(config, 'selectedRegions') && ~isempty(config.selectedRegions)
    filter_params{end+1} = 'timeLockedRegions';
    filter_params{end+1} = config.selectedRegions;
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
filter_params{end+1} = 'passOptions';
filter_params{end+1} = passOptions;

% Previous regions
if isfield(config, 'selectedPrevRegions') && ~isempty(config.selectedPrevRegions)
    filter_params{end+1} = 'prevRegions';
    filter_params{end+1} = config.selectedPrevRegions;
end

% Next regions
if isfield(config, 'selectedNextRegions') && ~isempty(config.selectedNextRegions)
    filter_params{end+1} = 'nextRegions';
    filter_params{end+1} = config.selectedNextRegions;
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
filter_params{end+1} = 'fixationOptions';
filter_params{end+1} = fixationOptions;

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
filter_params{end+1} = 'saccadeInOptions';
filter_params{end+1} = saccadeInOptions;

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
filter_params{end+1} = 'saccadeOutOptions';
filter_params{end+1} = saccadeOutOptions;

end

function cleanup_temp_files_internal(batchFilePaths)
% Clean up temporary files created during Text IA processing
temp_dir = fullfile(tempdir, 'eyesort_temp');

try
    for i = 1:length(batchFilePaths)
        file_path = batchFilePaths{i};
        
        % Only delete files that are in our temp directory and have the temp suffix
        if contains(file_path, 'eyesort_temp') && contains(file_path, '_textia_temp.set')
            if exist(file_path, 'file')
                delete(file_path);
                fprintf('Cleaned up temporary file: %s\n', file_path);
            end
        end
    end
    
    % Try to remove the temp directory if it's empty
    if exist(temp_dir, 'dir')
        try
            rmdir(temp_dir);
            fprintf('Cleaned up temporary directory: %s\n', temp_dir);
        catch
            % Directory might not be empty or have permissions issues, ignore
        end
    end
    
catch ME
    warning('EYESORT:CleanupFailed', 'Could not clean up some temporary files: %s', ME.message);
end
end

