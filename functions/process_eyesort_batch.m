function process_eyesort_batch(datasetFolder, varargin)
%% PROCESS_EYESORT_BATCH - Batch process EEG datasets through EyeSort pipeline
%
% This function processes multiple EEG datasets through the complete EyeSort
% pipeline using modular core functions. No GUI required.
%
% USAGE:
%   process_eyesort_batch(datasetFolder)
%   process_eyesort_batch(datasetFolder, 'config_file', configPath)
%   process_eyesort_batch(datasetFolder, 'param1', value1, 'param2', value2, ...)
%
% INPUTS:
%   datasetFolder - Path to folder containing .set files to process
%
% OPTIONAL PARAMETERS:
%   'config_file'     - Path to config file (if not provided, uses parameters below)
%   'output_folder'   - Output folder for processed datasets (default: same as input)
%   'save_datasets'   - Whether to save processed datasets (default: true)
%   
%   Parameters for compute_text_based_ia:
%   'txt_file_path'        - Path to interest area text file
%   'offset'               - Pixel offset for text start
%   'px_per_char'          - Pixels per character
%   'num_regions'          - Number of regions
%   'region_names'         - Cell array of region names
%   'condition_col_name'   - Condition column name
%   'item_col_name'        - Item column name
%   'start_code'           - Trial start event code
%   'end_code'             - Trial end event code
%   'condition_triggers'   - Cell array of condition trigger codes
%   'item_triggers'        - Cell array of item trigger codes
%   'fixation_type'        - Fixation event type identifier
%   'fixation_x_field'     - Field name for fixation X position
%   'saccade_type'         - Saccade event type identifier
%   'saccade_start_x_field'- Field name for saccade start X position
%   'saccade_end_x_field'  - Field name for saccade end X position
%   
%   Parameters for filter_datasets_core:
%   'time_locked_regions'  - Cell array of regions to filter on
%   'pass_options'         - Pass type options (1=any, 2=first, 3=second, etc.)
%   'prev_regions'         - Cell array of previous region names
%   'next_regions'         - Cell array of next region names
%   'fixation_options'     - Fixation type options
%   'saccade_in_options'   - Saccade in direction options
%   'saccade_out_options'  - Saccade out direction options
%   'conditions'           - Array of condition numbers
%   'items'                - Array of item numbers
%
% EXAMPLES:
%   % Using config file
%   process_eyesort_batch('/path/to/datasets', 'config_file', 'eyesort_config.m')
%   
%   % Using direct parameters
%   process_eyesort_batch('/path/to/datasets', ...
%       'txt_file_path', 'stimuli.txt', ...
%       'offset', 100, ...
%       'px_per_char', 12, ...
%       'num_regions', 4, ...
%       'region_names', {'Introduction', 'Target', 'Spillover', 'Ending'})

%% Parse inputs
p = inputParser;
addRequired(p, 'datasetFolder', @(x) ischar(x) && exist(x, 'dir'));
addParameter(p, 'config_file', '', @ischar);
addParameter(p, 'output_folder', '', @ischar);
addParameter(p, 'save_datasets', true, @islogical);

% Parameters for compute_text_based_ia
addParameter(p, 'txt_file_path', '', @ischar);
addParameter(p, 'offset', [], @isnumeric);
addParameter(p, 'px_per_char', [], @isnumeric);
addParameter(p, 'num_regions', [], @isnumeric);
addParameter(p, 'region_names', {}, @iscell);
addParameter(p, 'condition_col_name', '', @ischar);
addParameter(p, 'item_col_name', '', @ischar);
addParameter(p, 'start_code', '', @ischar);
addParameter(p, 'end_code', '', @ischar);
addParameter(p, 'condition_triggers', {}, @iscell);
addParameter(p, 'item_triggers', {}, @iscell);
addParameter(p, 'fixation_type', '', @ischar);
addParameter(p, 'fixation_x_field', '', @ischar);
addParameter(p, 'saccade_type', '', @ischar);
addParameter(p, 'saccade_start_x_field', '', @ischar);
addParameter(p, 'saccade_end_x_field', '', @ischar);

% Parameters for filter_datasets_core
addParameter(p, 'time_locked_regions', {}, @iscell);
addParameter(p, 'pass_options', [], @isnumeric);
addParameter(p, 'prev_regions', {}, @iscell);
addParameter(p, 'next_regions', {}, @iscell);
addParameter(p, 'fixation_options', [], @isnumeric);
addParameter(p, 'saccade_in_options', [], @isnumeric);
addParameter(p, 'saccade_out_options', [], @isnumeric);
addParameter(p, 'conditions', [], @isnumeric);
addParameter(p, 'items', [], @isnumeric);

parse(p, datasetFolder, varargin{:});
params = p.Results;

%% Load configuration
if ~isempty(params.config_file)
    fprintf('Loading configuration from: %s\n', params.config_file);
    config = load_eyesort_config(params.config_file);
else
    fprintf('Using parameters provided directly to function\n');
    config = params;
end

%% Set output folder
if isempty(params.output_folder)
    config.output_folder = datasetFolder;
else
    config.output_folder = params.output_folder;
end

%% Validate required parameters
required_fields = {'txt_file_path', 'offset', 'px_per_char', 'num_regions', ...
                   'region_names', 'condition_col_name', 'item_col_name', ...
                   'start_code', 'end_code', 'condition_triggers', 'item_triggers', ...
                   'fixation_type', 'fixation_x_field', 'saccade_type', ...
                   'saccade_start_x_field', 'saccade_end_x_field'};

for i = 1:length(required_fields)
    field = required_fields{i};
    if ~isfield(config, field) || isempty(config.(field))
        error('Required parameter "%s" is missing or empty', field);
    end
end

%% Find dataset files
fprintf('Searching for .set files in: %s\n', datasetFolder);
datasetFiles = dir(fullfile(datasetFolder, '*.set'));
if isempty(datasetFiles)
    error('No .set files found in the specified folder: %s', datasetFolder);
end

fprintf('Found %d dataset(s) to process:\n', length(datasetFiles));
for i = 1:length(datasetFiles)
    fprintf('  %d. %s\n', i, datasetFiles(i).name);
end

%% Process each dataset
for i = 1:length(datasetFiles)
    datasetPath = fullfile(datasetFiles(i).folder, datasetFiles(i).name);
    fprintf('\n=== Processing dataset %d/%d: %s ===\n', i, length(datasetFiles), datasetFiles(i).name);
    
    try
        % Load dataset
        fprintf('Loading dataset...\n');
        EEG = pop_loadset(datasetPath);
        
        % Step 1: Compute text-based interest areas
        fprintf('Step 1: Computing text-based interest areas...\n');
        EEG = compute_text_based_ia(EEG, config.txt_file_path, config.offset, config.px_per_char, ...
                                   config.num_regions, config.region_names, ...
                                   config.condition_col_name, config.item_col_name, ...
                                   config.start_code, config.end_code, ...
                                   config.condition_triggers, config.item_triggers, ...
                                   config.fixation_type, config.fixation_x_field, ...
                                   config.saccade_type, config.saccade_start_x_field, config.saccade_end_x_field, ...
                                   'batch_mode', true);
        
        % Step 2: Trial labeling (already called within compute_text_based_ia)
        fprintf('Step 2: Trial labeling completed within interest area computation\n');
        
        % Step 3: Apply filters (if specified)
        if isfield(config, 'time_locked_regions') && ~isempty(config.time_locked_regions)
            fprintf('Step 3: Applying dataset filters...\n');
            
            filter_args = {'timeLockedRegions', config.time_locked_regions};
            
            if isfield(config, 'pass_options') && ~isempty(config.pass_options)
                filter_args = [filter_args, {'passOptions', config.pass_options}];
            end
            if isfield(config, 'prev_regions') && ~isempty(config.prev_regions)
                filter_args = [filter_args, {'prevRegions', config.prev_regions}];
            end
            if isfield(config, 'next_regions') && ~isempty(config.next_regions)
                filter_args = [filter_args, {'nextRegions', config.next_regions}];
            end
            if isfield(config, 'fixation_options') && ~isempty(config.fixation_options)
                filter_args = [filter_args, {'fixationOptions', config.fixation_options}];
            end
            if isfield(config, 'saccade_in_options') && ~isempty(config.saccade_in_options)
                filter_args = [filter_args, {'saccadeInOptions', config.saccade_in_options}];
            end
            if isfield(config, 'saccade_out_options') && ~isempty(config.saccade_out_options)
                filter_args = [filter_args, {'saccadeOutOptions', config.saccade_out_options}];
            end
            if isfield(config, 'conditions') && ~isempty(config.conditions)
                filter_args = [filter_args, {'conditions', config.conditions}];
            end
            if isfield(config, 'items') && ~isempty(config.items)
                filter_args = [filter_args, {'items', config.items}];
            end
            
            [EEG, ~] = filter_datasets_core(EEG, filter_args{:});
        else
            fprintf('Step 3: Skipping filters (no time_locked_regions specified)\n');
        end
        
        % Save processed dataset
        if config.save_datasets
            [~, name, ~] = fileparts(datasetFiles(i).name);
            outputPath = fullfile(config.output_folder, [name '_eyesort_processed.set']);
            fprintf('Saving processed dataset to: %s\n', outputPath);
            pop_saveset(EEG, outputPath);
        end
        
        fprintf('Dataset %d processed successfully!\n', i);
        
    catch ME
        fprintf('ERROR processing dataset %d (%s): %s\n', i, datasetFiles(i).name, ME.message);
        fprintf('Stack trace:\n');
        for j = 1:length(ME.stack)
            fprintf('  %s (line %d)\n', ME.stack(j).name, ME.stack(j).line);
        end
        fprintf('Continuing with next dataset...\n');
    end
end

fprintf('\n=== Batch processing complete! ===\n');
fprintf('Processed %d dataset(s)\n', length(datasetFiles));

end

function config = load_eyesort_config(configPath)
%% Load configuration from file
% The config file should be a MATLAB script that sets variables

if ~exist(configPath, 'file')
    error('Configuration file not found: %s', configPath);
end

% Run the config file in a function workspace to capture variables
[~, ~, ext] = fileparts(configPath);
if strcmp(ext, '.m')
    % Run MATLAB script
    try
        run(configPath);
    catch ME
        error('Error running config file %s: %s', configPath, ME.message);
    end
    
    % Capture all variables from the workspace
    config = struct();
    vars = whos;
    for i = 1:length(vars)
        if ~strcmp(vars(i).name, 'config') % Don't include the config struct itself
            config.(vars(i).name) = eval(vars(i).name);
        end
    end
else
    error('Unsupported config file format. Please use .m files.');
end

end 