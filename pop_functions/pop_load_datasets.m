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

    % supergui geometry
    geomhoriz = { ...
        1,          ... Row 1: Single Dataset Pipeline
        [1 0.5], ... Row 1
        1,          ... Row 3
        [0.5 1],          ... Row 4: Remove Selected button for individual datasets
        1,          ... Row 5: Spacer          ... Row 6: Spacer
        1,          ... Row 7: Spacer
        [1 0.5], ... Row 8
        1,          ... Row 9 (directory listbox)
        [0.5 1],          ... Row 10: Remove Selected button for batch directory
        1,          ... Row 11: Spacer
        [1 0.5], ... Row 11
        1,          ... Row 12 (output directory listbox)
        [0.5 1],          ... Row 13: Remove Selected button for output directory
        1,          ... Row 14: Spacer
        [1 0.5 0.5], ... Row 15: Control buttons
    };
    
    geomvert = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
    
    uilist = { ...
        {'Style', 'text', 'string', '──────────Single Dataset Pipeline───────────────────────────────────', 'FontWeight', 'bold', 'HorizontalAlignment', 'center'}, ... Row 1: Single Dataset Pipeline
        ...
        {'Style', 'text', 'string', 'Load individual dataset:', 'FontSize', 12}, ...
        {'Style', 'pushbutton', 'string', 'Browse Files', 'callback', @(~,~) browse_for_datasets()}, ...
        ... Row 3: 
        {'Style', 'listbox', 'tag', 'datasetList', 'string', selected_datasets, 'Max', 10, 'Min', 1, 'HorizontalAlignment', 'left'}, ...
        ... Row 4:
        {'Style', 'pushbutton', 'string', 'Remove Selected', 'callback', @(~,~) remove_dataset()}, ...
        {}, ...
        ...
        {}, ... 
        ... Row 5: Separator
        {'Style', 'text', 'string', '──────────Multiple Datasets Pipeline───────────────────────────────────', 'FontWeight', 'bold', 'HorizontalAlignment', 'center'}, ...
        ... Row 6: Directory selection option
        {'Style', 'text', 'string', 'Select the Input Directory containing the datasets:', 'FontSize', 12}, ...
        {'Style', 'pushbutton', 'string', 'Browse Dataset(s) Directory', 'callback', @(~,~) browse_for_directory()}, ...
        ... Row 9: Selected directory listbox
        {'Style', 'listbox', 'tag', 'batchDirList', 'string', {}, 'Max', 1, 'Min', 1, 'HorizontalAlignment', 'left'}, ...
        ... Row 10: Remove Selected button for batch directory
        {'Style', 'pushbutton', 'string', 'Remove Selected', 'callback', @(~,~) remove_batch_directory()}, ...
        {}, ...
        ...
        {}, ...
        ... Row 9: Output directory selection
        {'Style', 'text', 'string', 'Select the Output Directory where the processed datasets will be saved:', 'FontSize', 12}, ...
        {'Style', 'pushbutton', 'string', 'Browse Output Directory', 'callback', @(~,~) browse_for_output()}, ...
        ... Row 12: Selected output directory listbox
        {'Style', 'listbox', 'tag', 'outputDirList', 'string', {}, 'Max', 1, 'Min', 1, 'HorizontalAlignment', 'left'}, ...
        ... Row 13: Remove Selected button for output directory
        {'Style', 'pushbutton', 'string', 'Remove Selected', 'callback', @(~,~) remove_output_directory()}, ...
        {}, ...
        ... Row 14: Spacer
        {}, ...
        ... Row 15: Control buttons
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
    selectedDir = '';
    outputDir = '';

%% ----------------------- NestedCallback Functions --------------------------

    % -- BROWSE FOR DATASETS --
    function browse_for_datasets(~,~)
        [files, path] = uigetfile( ...
            {'*.set', 'EEG dataset files (*.set)'}, ...
            'Select EEG Dataset', ...
            'MultiSelect', 'off');
        figure(hFig); % Bring GUI back to front

        if isequal(files, 0)
            return; % user canceled
        end
        
        if ischar(files)
            files = {files}; 
        end

        % Build full paths, append to selected_datasets
        new_paths = cellfun(@(f) fullfile(path, f), files, 'UniformOutput', false);
        selected_datasets = [selected_datasets, new_paths];

        % Update the listbox
        set(findobj(hFig, 'tag', 'datasetList'), ...
            'string', selected_datasets, ...
            'value', 1);
            
        % Clear any previously selected directory since we're using individual files
        selectedDir = '';
        set(findobj(hFig, 'tag', 'batchDirList'), 'string', {}, 'value', 1);
    end

    % -- BROWSE FOR DIRECTORY --
    function browse_for_directory(~,~)
        dir_path = uigetdir('', 'Select Directory with EEG Datasets');
        figure(hFig); % Bring GUI back to front
        
        if isequal(dir_path, 0)
            return; % user canceled
        end
        
        selectedDir = dir_path;
        set(findobj(hFig, 'tag', 'batchDirList'), ...
            'string', {selectedDir}, ...
            'value', 1);
            
        % Clear individually selected datasets since we're using directory mode
        selected_datasets = {};
        set(findobj(hFig, 'tag', 'datasetList'), 'string', {}, 'value', 1);
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

    % -- REMOVE BATCH DIRECTORY --
    function remove_batch_directory(~,~)
        selectedDir = '';
        hList = findobj(hFig, 'tag', 'batchDirList');
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
        % Check if either individual datasets or a directory is selected
        if isempty(selected_datasets) && isempty(selectedDir)
            errordlg('No datasets or directory selected. Please select datasets or a directory.', 'Error');
            return;
        end
        
        % Check if output directory is selected when using batch processing
        if ~isempty(selectedDir) && isempty(outputDir)
            errordlg('Please select an output directory for batch processing.', 'Error');
            return;
        end
        
        % Check for mutually exclusive pipeline selection
        if ~isempty(selected_datasets) && (~isempty(selectedDir) || ~isempty(outputDir))
            errordlg('Cannot use both single dataset and batch processing pipelines simultaneously. Please clear one before proceeding.', 'Error');
            return;
        end

        % Retrieve ALLEEG, CURRENTSET from base if they exist
        try
            ALLEEG    = evalin('base', 'ALLEEG'); 
            CURRENTSET= evalin('base', 'CURRENTSET');
        catch
            % If not found, initialize them
            ALLEEG    = [];
            CURRENTSET= 0;
        end

        % DIRECTORY-BASED BATCH LOADING
        if ~isempty(selectedDir)
            % Get all .set files in the directory
            fileList = dir(fullfile(selectedDir, '*.set'));
            
            if isempty(fileList)
                errordlg('No .set files found in the selected directory.', 'Error');
                return;
            end
            
            % Create a progress bar
            h = waitbar(0, 'Loading datasets for batch processing...', 'Name', 'Loading Datasets');
            
            try
                batchFilePaths = {};
                batchFileNames = {};
                valid_count = 0;
                
                % Validate each dataset file (quick check without full loading)
                for i = 1:length(fileList)
                    file_path = fullfile(selectedDir, fileList(i).name);
                    waitbar(i/length(fileList), h, sprintf('Validating %d of %d: %s', i, length(fileList), fileList(i).name));
                    
                    try
                        % Quick validation - just check if file can be opened
                        if exist(file_path, 'file')
                            valid_count = valid_count + 1;
                            batchFilePaths{valid_count} = file_path;
                            batchFileNames{valid_count} = fileList(i).name;
                            fprintf('Validated dataset %d/%d: %s\n', valid_count, length(fileList), fileList(i).name);
                        else
                            warning('File not found: %s', file_path);
                        end
                        
                    catch ME
                        warning('Failed to validate dataset %s:\n%s', file_path, ME.message);
                    end
                end
                
                % Close progress bar
                delete(h);
                
                if valid_count > 0
                    % Store only file paths and metadata (memory efficient!)
                    assignin('base', 'eyesort_batch_file_paths', batchFilePaths);
                    assignin('base', 'eyesort_batch_filenames', batchFileNames);
                    assignin('base', 'eyesort_batch_output_dir', outputDir);
                    assignin('base', 'eyesort_batch_mode', true);
                    
                    % Load only the first dataset for GUI display
                    try
                        firstEEG = pop_loadset('filename', batchFilePaths{1});
                        % Ensure EEG structure is properly formatted for EEGLAB
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
                    com = sprintf('EEG = pop_load_datasets(EEG); %% Prepared %d datasets for batch processing', valid_count);
                    
                    % Calculate approximate memory usage
                    if valid_count > 1
                        est_memory_mb = valid_count * 200; % Rough estimate
                        memory_warning = '';
                        if est_memory_mb > 2000
                            memory_warning = sprintf('\n\nNote: Processing %d large datasets will be done one-at-a-time\nto avoid memory issues (estimated ~%.1f GB total).', valid_count, est_memory_mb/1000);
                        end
                    else
                        memory_warning = '';
                    end
                    
                    % Success message
                    msgbox(sprintf(['Successfully prepared %d datasets for batch processing!%s\n\n'...
                                   'Next steps:\n'...
                                   '1. Configure Text Interest Areas (step 2)\n'...
                                   '2. Configure and Apply Eye-Event Labels (step 3)\n\n'...
                                   'Each step will process datasets one-at-a-time for memory efficiency.'], valid_count, memory_warning), 'Batch Setup Complete');
                else
                    errordlg('No valid datasets were found.', 'Validation Failed');
                end
                
            catch ME
                % Close progress bar if there was an error
                if exist('h', 'var') && ishandle(h)
                    delete(h);
                end
                errordlg(['Error during batch loading: ' ME.message], 'Error');
            end
            
        % INDIVIDUAL DATASETS PROCESSING
        else
            % Clear any existing batch mode when loading individual datasets
            try
                evalin('base', 'clear eyesort_batch_file_paths eyesort_batch_filenames eyesort_batch_output_dir eyesort_batch_mode');
            catch
                % Variables might not exist, which is fine
            end
            
            % Loop through selected datasets and load them
            for i = 1:numel(selected_datasets)
                dataset_path = selected_datasets{i};
                try
                    % pop_loadset returns a single EEG structure
                    EEG = pop_loadset('filename', dataset_path);

                    if isempty(EEG.data)
                        warning('Dataset %s is empty. Skipping...', dataset_path);
                        continue;
                    end

                    % Validate EEG structure and events
                    if ~isfield(EEG, 'srate') || isempty(EEG.srate)
                        warning('Dataset %s missing sampling rate. Skipping...', dataset_path);
                        continue;
                    end

                    % Check for event data
                    if ~isfield(EEG, 'event') || isempty(EEG.event)
                        warning('Dataset %s has no events. This may cause issues with interest area calculations.', dataset_path);
                        fprintf('Loading dataset anyway, but please verify event data exists in the original file.\n');
                    else
                        fprintf('Successfully loaded dataset with %d events.\n', length(EEG.event));
                        % Add detailed event information
                        fprintf('First event type: %s\n', EEG.event(1).type);
                        fprintf('Event field names: %s\n', strjoin(fieldnames(EEG.event), ', '));
                    end

                    % Add verification before storage
                    fprintf('Before storage - Dataset has %d events\n', length(EEG.event));
                    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0);
                    fprintf('After storage - Dataset has %d events\n', length(EEG.event));
                    
                    % Save to output directory if specified
                    if ~isempty(outputDir)
                        [~, fileName, ~] = fileparts(dataset_path);
                        output_path = fullfile(outputDir, [fileName '_processed.set']);
                        pop_saveset(EEG, 'filename', output_path, 'savemode', 'twofiles');
                    end
                    
                catch ME
                    warning('Failed to load dataset %s:\n%s\nStack trace:\n%s', ...
                            dataset_path, ME.message, getReport(ME, 'basic'));
                end
            end

            % Add verification before closing
            fprintf('Final EEG structure has %d events\n', length(EEG.event));
            
            % Assign updated ALLEEG, EEG, CURRENTSET to base workspace
            assignin('base', 'ALLEEG', ALLEEG);
            assignin('base', 'EEG', EEG);
            assignin('base', 'CURRENTSET', CURRENTSET);

            % Note: Avoiding eeglab('redraw') to prevent GUI issues

            % Build the command string for EEGLAB history
            com = 'EEG = pop_load_datasets(EEG);';

            % Show success message
            msgbox(sprintf(['Success: Dataset loaded successfully into EEGLAB.\n\n', ...
            'Next steps:\n'...
            '1. Configure Text Interest Areas (step 2)\n'...
            '2. Configure and Apply Eye-Event Labels (step 3)\n']));
        end
        
        close(hFig);
    end
end