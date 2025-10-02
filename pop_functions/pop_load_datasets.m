function [EEG, com] = pop_load_datasets(EEG)

% *******************************
% * THE LOAD DATASETS FUNCTION  *
% *******************************

% pop_load_datasets() - A "pop" function to load multiple EEG .set files
%                       via a GUI dialog
%                       Now supports directory-based batch processing
%
% Usage:
%    >> [EEG, com] = pop_load_datasets(EEG);
%
% Inputs:
%    EEG  - an EEGLAB EEG structure (can be empty if no dataset is loaded yet).
%
% Outputs:
%    EEG  - Updated EEG structure (the *last* loaded dataset).
%    com  - Command string for the EEGLAB history.
%
% DESCRIPTION: Function is designed to allow the user to load in a single dataset or a directory of datasets to prepare for the rest of the EyeSort pipeline.

    % ---------------------------------------------------------------------
    % 1) Initialize outputs
    % ---------------------------------------------------------------------
    com = ''; 
    if nargin < 1 || isempty(EEG)
        % If no EEG is provided, create an empty set
        EEG = eeg_emptyset;
    end

    % Keep track of selected datasets in a local variable
    selected_datasets = {};
    
    % Create the figure
    hFig = figure('Name','Load EEG Dataset(s)',...
                  'NumberTitle','off',...
                  'MenuBar','none',...
                  'ToolBar','none',...
                  'Color',[0.94 0.94 0.94], ...
                  'Resize', 'off'); 

    % supergui geometry - simplified unified interface
    geomhoriz = { ...
        1,              ... Row 1: Instructions
        [1 0.5 0.5],    ... Row 2: Browse Files and Browse Directory buttons
        1,              ... Row 3: Dataset listbox
        [0.5 0.5 1],    ... Row 4: Remove Selected and Clear All buttons
        1,              ... Row 5: Spacer
        1,              ... Row 6: Output directory label
        [1 0.5],        ... Row 7: Browse output directory
        1,              ... Row 8: Output directory listbox
        [0.5 1],        ... Row 9: Remove output directory button
        1,              ... Row 10: Spacer
        [1 0.5 0.5],    ... Row 11: Control buttons
    };
    
    geomvert = [1.5, 1, 3, 1, 0.5, 1, 1, 1.5, 1, 0.5, 1];
    
    uilist = { ...
        {'Style', 'text', 'string', 'Select Dataset(s) and Output Directory (both required): One file = interactive mode, multiple files = batch processing', 'FontWeight', 'bold', 'HorizontalAlignment', 'left'}, ...
        ...
        {'Style', 'text', 'string', 'Load EEG Dataset(s):', 'FontSize', 12}, ...
        {'Style', 'pushbutton', 'string', 'Browse Files', 'callback', @(~,~) browse_for_files()}, ...
        {'Style', 'pushbutton', 'string', 'Browse Directory', 'callback', @(~,~) browse_for_directory()}, ...
        ...
        {'Style', 'listbox', 'tag', 'datasetList', 'string', selected_datasets, 'Max', 1, 'Min', 1, 'HorizontalAlignment', 'left'}, ...
        ...
        {'Style', 'pushbutton', 'string', 'Remove Selected', 'callback', @(~,~) remove_dataset()}, ...
        {'Style', 'pushbutton', 'string', 'Clear All', 'callback', @(~,~) clear_all_datasets()}, ...
        {}, ...
        ...
        {}, ...
        ...
        {'Style', 'text', 'string', 'Output Directory (Required - where processed datasets will be saved):', 'FontSize', 12, 'FontWeight', 'bold'}, ...
        ...
        {'Style', 'text', 'string', 'Where processed datasets will be saved:', 'FontSize', 10}, ...
        {'Style', 'pushbutton', 'string', 'Browse Output Directory', 'callback', @(~,~) browse_for_output()}, ...
        ...
        {'Style', 'listbox', 'tag', 'outputDirList', 'string', {}, 'Max', 1, 'Min', 1, 'HorizontalAlignment', 'left'}, ...
        ...
        {'Style', 'pushbutton', 'string', 'Remove Selected', 'callback', @(~,~) remove_output_directory()}, ...
        {}, ...
        ...
        {}, ...
        ...
        {}, ...
        {'Style', 'pushbutton', 'string', 'Cancel', 'callback', @(~,~) cancel_button()}, ...
        {'Style', 'pushbutton', 'string', 'Confirm', 'callback', @(~,~) confirm_selection()}, ...
    };
    
     
    % Call supergui with the existing figure handle
    supergui('fig', hFig, ...
             'geomhoriz', geomhoriz, ...
             'geomvert',  geomvert, ...
             'uilist',    uilist, ...
             'title',     'Load EEG Dataset(s)');
         
    % Bring window to front
    figure(hFig);

    % Variables to store directory paths
    outputDir = '';

%% ----------------------- NestedCallback Functions --------------------------

    % -- BROWSE FOR FILES --
    function browse_for_files(~,~)
        % File selection with multiselect enabled
        [files, path] = uigetfile( ...
            {'*.set', 'EEG dataset files (*.set)'}, ...
            'Select EEG Dataset(s) - MultiSelect Enabled', ...
            'MultiSelect', 'on');
        figure(hFig); % Bring GUI back to front

        if isequal(files, 0)
            return; % user canceled
        end
        
        if ischar(files)
            files = {files}; 
        end

        % Build full paths, check for duplicates
        new_paths = cellfun(@(f) fullfile(path, f), files, 'UniformOutput', false);
        duplicates = ismember(new_paths, selected_datasets);
        new_paths = new_paths(~duplicates);
        
        if any(duplicates)
            msgbox(sprintf('%d duplicate dataset(s) skipped.', sum(duplicates)), 'Duplicates Skipped', 'warn');
        end
        
        selected_datasets = [selected_datasets, new_paths];

        % Update the listbox
        set(findobj(hFig, 'tag', 'datasetList'), ...
            'string', selected_datasets, ...
            'value', 1);
    end

    % -- BROWSE FOR DIRECTORY --
    function browse_for_directory(~,~)
        % Directory selection
        dir_path = uigetdir('', 'Select Directory with EEG Datasets');
        figure(hFig); % Bring GUI back to front
        
        if isequal(dir_path, 0)
            return; % user canceled
        end
        
        % Find all .set files in the directory
        fileList = dir(fullfile(dir_path, '*.set'));
        
        if isempty(fileList)
            errordlg('No .set files found in the selected directory.', 'Error');
            return;
        end
        
        % Build full paths for all files in directory
        new_paths = cell(1, length(fileList));
        for i = 1:length(fileList)
            new_paths{i} = fullfile(dir_path, fileList(i).name);
        end
        
        % Replace selected_datasets with directory contents
        selected_datasets = new_paths;
        
        % Update the listbox
        set(findobj(hFig, 'tag', 'datasetList'), ...
            'string', selected_datasets, ...
            'value', 1);
    end

    % -- BROWSE FOR OUTPUT DIRECTORY --
    function browse_for_output(~,~)
        dir_path = uigetdir('', 'Select Output Directory for Processed Files');
        figure(hFig); % Bring GUI back to front
        
        if isequal(dir_path, 0)
            return; % user canceled
        end
        
        outputDir = dir_path;
        set(findobj(hFig, 'tag', 'outputDirList'), ...
            'string', {outputDir}, ...
            'value', 1);
    end

    % -- REMOVE SELECTED DATASET(S) --
    function remove_dataset(~,~)
        hList = findobj(hFig, 'tag', 'datasetList');
        idxToRemove = get(hList, 'value');
        if isempty(idxToRemove), return; end

        % Remove from selected_datasets
        selected_datasets(idxToRemove) = [];

        % Update listbox
        set(hList, 'string', selected_datasets, 'value', 1);
    end

    % -- CLEAR ALL DATASETS --
    function clear_all_datasets(~,~)
        selected_datasets = {};
        hList = findobj(hFig, 'tag', 'datasetList');
        set(hList, 'string', {}, 'value', 1);
    end

    % -- REMOVE OUTPUT DIRECTORY --
    function remove_output_directory(~,~)
        outputDir = '';
        hList = findobj(hFig, 'tag', 'outputDirList');
        set(hList, 'string', {}, 'value', 1);
    end

    % -- CANCEL BUTTON --
    function cancel_button(~,~)
        close(hFig);
        disp('User selected cancel. No datasets loaded.');
    end

    % -- CONFIRM SELECTION --
    function confirm_selection(~,~)
        % Check if datasets selected
        if isempty(selected_datasets)
            errordlg('No datasets selected. Please select at least one dataset.', 'Error');
            return;
        end
        
        % Check if output directory is selected (required for all modes)
        if isempty(outputDir)
            errordlg('Output directory is required. Please select an output directory where processed datasets will be saved.', 'Error');
            return;
        end
        
        % Determine mode based on number of datasets
        num_datasets = numel(selected_datasets);

        % Retrieve ALLEEG, CURRENTSET from base if they exist
        try
            ALLEEG    = evalin('base', 'ALLEEG'); 
            CURRENTSET= evalin('base', 'CURRENTSET');
        catch
            % If not found, initialize them
            ALLEEG    = [];
            CURRENTSET= 0;
        end

        % BATCH MODE: 2+ datasets
        if num_datasets >= 2
            % Store only file paths and metadata (memory efficient!)
            batchFilePaths = selected_datasets;
            batchFileNames = cell(1, num_datasets);
            for i = 1:num_datasets
                [~, name, ext] = fileparts(selected_datasets{i});
                batchFileNames{i} = [name ext];
            end
            
            assignin('base', 'eyesort_batch_file_paths', batchFilePaths);
            assignin('base', 'eyesort_batch_filenames', batchFileNames);
            assignin('base', 'eyesort_batch_output_dir', outputDir);
            assignin('base', 'eyesort_batch_mode', true);
            
            % Load only the first dataset for GUI display
            try
                firstEEG = pop_loadset('filename', batchFilePaths{1});
                if ~isfield(firstEEG, 'saved')
                    firstEEG.saved = 'no';
                end
                assignin('base', 'EEG', firstEEG);
                fprintf('Loaded first dataset for GUI display: %s\n', batchFileNames{1});
            catch ME
                warning('EYESORT:LoadError', 'Could not load first dataset for display: %s', ME.message);
                assignin('base', 'EEG', eeg_emptyset);
            end
            
            % Build command string for history
            com = sprintf('EEG = pop_load_datasets(EEG); %% Prepared %d datasets for batch processing', num_datasets);
            
            % Calculate approximate memory usage
            est_memory_mb = num_datasets * 200;
            memory_warning = '';
            if est_memory_mb > 2000
                memory_warning = sprintf('\n\nNote: Processing %d large datasets will be done one-at-a-time\nto avoid memory issues (estimated ~%.1f GB total).', num_datasets, est_memory_mb/1000);
            end
            
            % Success message
            msgbox(sprintf(['Successfully prepared %d datasets for batch processing!%s\n\n'...
                           'Next steps:\n'...
                           '1. Configure Text Interest Areas (step 2)\n'...
                           '2. Configure and Apply Eye-Event Labels (step 3)\n\n'...
                           'Each step will process datasets one-at-a-time for memory efficiency.'], num_datasets, memory_warning), 'Batch Setup Complete');
            
        % SINGLE DATASET MODE: 1 dataset
        else
            % Clear any existing batch mode
            try
                evalin('base', 'clear eyesort_batch_file_paths eyesort_batch_filenames eyesort_batch_output_dir eyesort_batch_mode');
            catch
                % Variables might not exist, which is fine
            end
            
            % Store output directory (required for auto-save after labeling)
            assignin('base', 'eyesort_single_output_dir', outputDir);
            
            % Load the single dataset into ALLEEG
            dataset_path = selected_datasets{1};
            try
                EEG = pop_loadset('filename', dataset_path);

                if isempty(EEG.data)
                    errordlg('Dataset is empty.', 'Error');
                    return;
                end

                % Validate EEG structure
                if ~isfield(EEG, 'srate') || isempty(EEG.srate)
                    errordlg('Dataset missing sampling rate.', 'Error');
                    return;
                end

                % Check for event data
                if ~isfield(EEG, 'event') || isempty(EEG.event)
                    warning('Dataset has no events. This may cause issues with interest area calculations.');
                else
                    fprintf('Successfully loaded dataset with %d events.\n', length(EEG.event));
                end

                % Store in ALLEEG
                [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0);
                
                % Assign to base workspace
                assignin('base', 'ALLEEG', ALLEEG);
                assignin('base', 'EEG', EEG);
                assignin('base', 'CURRENTSET', CURRENTSET);

                % Build command string for history
                com = 'EEG = pop_load_datasets(EEG);';

                % Show success message
                msgbox(sprintf(['Success: Dataset loaded into EEGLAB.\n\n', ...
                    'Output directory: %s\n\n'...
                    'Processed dataset will be auto-saved after labeling.\n\n'...
                    'Next steps:\n'...
                    '1. Configure Text Interest Areas (step 2)\n'...
                    '2. Configure and Apply Eye-Event Labels (step 3)\n'], outputDir));
                
            catch ME
                errordlg(['Failed to load dataset: ' ME.message], 'Error');
                return;
            end
        end
        
        close(hFig);
    end
end