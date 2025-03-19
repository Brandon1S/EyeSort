function [EEG, com] = pop_load_datasets(EEG)

% pop_load_datasets() - A "pop" function to load multiple EEG .set files
%                       via a GUI dialog, then store them in ALLEEG.
%                       Now supports directory-based batch processing.
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
    hFig = figure('Name','Load EEG Datasets',...
                  'NumberTitle','off',...
                  'MenuBar','none',...
                  'ToolBar','none',...
                  'Color',[0.94 0.94 0.94], ...
                  'Resize', 'off'); 

    % supergui geometry
    geomhoriz = { ...
        [1 1 1 1.26], ... Row 1
        [1 1],        ... Row 2
        [1],          ... Row 3
        [1 1 1 1],    ... Row 4
        1,            ... Row 5 
        [1 1 1 1.26], ... Row 6
        1,            ... Row 7
        [1 1 1 1.26], ... Row 8
        1,            ... Row 9
        [1 1 1 1.26], ... Row 10
    };
    
    geomvert = [0.5, 0.5, 0.5, 0.5, 0.5, 0.7, 0.3, 0.7, 0.3, 0.7];
    
    uilist = { ...
        % Row 1: Input EEG datasets
        {'Style', 'text', 'string', 'Load individual dataset:', 'FontSize', 12}, ...
        {}, ...
        {}, ...
        {'Style', 'pushbutton', 'string', 'Browse Files', 'callback', @(~,~) browse_for_datasets()}, ...
        ... Row 2: Selected Datasets label
        {'Style', 'text', 'string', 'Selected Dataset:', 'FontSize', 10, 'HorizontalAlignment', 'left'}, ...
        {}, ...
        ... Row 3: 
        {'Style', 'listbox', 'tag', 'datasetList', 'string', selected_datasets, 'Max', 10, 'Min', 1, 'HorizontalAlignment', 'left'}, ...
        ... Row 4:
        {'Style', 'pushbutton', 'string', 'Remove Selected', 'callback', @(~,~) remove_dataset()}, ...
        {'Style', 'pushbutton', 'string', 'Clear All', 'callback', @(~,~) clear_all_datasets()}, ...
        {}, {}, ...
        ... Row 5: Separator
        {'Style', 'text', 'string', '-- OR --', 'FontWeight', 'bold', 'HorizontalAlignment', 'center'}, ...
        ... Row 6: Directory selection option
        {'Style', 'text', 'string', 'Batch process all datasets in directory:', 'FontSize', 12}, ...
        {}, ...
        {}, ...
        {'Style', 'pushbutton', 'string', 'Browse Directory', 'callback', @(~,~) browse_for_directory()}, ...
        ... Row 7: Selected directory text
        {'Style', 'text', 'string', '', 'tag', 'txtSelectedDir', 'FontSize', 10, 'HorizontalAlignment', 'left'}, ...
        ... Row 8: Output directory selection
        {'Style', 'text', 'string', 'Output Directory (for processed files):', 'FontSize', 12}, ...
        {}, ...
        {}, ...
        {'Style', 'pushbutton', 'string', 'Browse Output', 'callback', @(~,~) browse_for_output()}, ...
        ... Row 9: Selected output directory text
        {'Style', 'text', 'string', '', 'tag', 'txtOutputDir', 'FontSize', 10, 'HorizontalAlignment', 'left'}, ...
        ... Row 10: Control buttons
        {'Style', 'pushbutton', 'string', 'Cancel', 'callback', @(~,~) cancel_button()}, ...
        {}, ...
        {}, ...
        {'Style', 'pushbutton', 'string', 'Confirm', 'callback', @(~,~) confirm_selection()}, ...
    };
    
     
    % Call supergui with the existing figure handle
    supergui('fig', hFig, ...
             'geomhoriz', geomhoriz, ...
             'geomvert',  geomvert, ...
             'uilist',    uilist, ...
             'title',     'Load EEG Datasets');

    % Variables to store directory paths
    selectedDir = '';
    outputDir = '';

%% ----------------------- Callback Functions --------------------------

    % -- BROWSE FOR DATASETS --
    function browse_for_datasets(~,~)
        [files, path] = uigetfile( ...
            {'*.set', 'EEG dataset files (*.set)'}, ...
            'Select EEG Datasets', ...
            'MultiSelect', 'on');

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
        set(findobj(hFig, 'tag', 'txtSelectedDir'), 'string', '');
    end

    % -- BROWSE FOR DIRECTORY --
    function browse_for_directory(~,~)
        dir_path = uigetdir('', 'Select Directory with EEG Datasets');
        
        if isequal(dir_path, 0)
            return; % user canceled
        end
        
        selectedDir = dir_path;
        set(findobj(hFig, 'tag', 'txtSelectedDir'), ...
            'string', ['Selected: ' selectedDir]);
            
        % Clear individually selected datasets since we're using directory mode
        selected_datasets = {};
        set(findobj(hFig, 'tag', 'datasetList'), 'string', {}, 'value', 1);
    end
    
    % -- BROWSE FOR OUTPUT DIRECTORY --
    function browse_for_output(~,~)
        dir_path = uigetdir('', 'Select Output Directory for Processed Files');
        
        if isequal(dir_path, 0)
            return; % user canceled
        end
        
        outputDir = dir_path;
        set(findobj(hFig, 'tag', 'txtOutputDir'), ...
            'string', ['Output: ' outputDir]);
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
        set(hList, 'string', selected_datasets, 'value', 1);
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

        % Retrieve ALLEEG, CURRENTSET from base if they exist
        try
            ALLEEG    = evalin('base', 'ALLEEG'); 
            CURRENTSET= evalin('base', 'CURRENTSET');
        catch
            % If not found, initialize them
            ALLEEG    = [];
            CURRENTSET= 0;
        end

        % DIRECTORY-BASED BATCH PROCESSING
        if ~isempty(selectedDir)
            % Get all .set files in the directory
            fileList = dir(fullfile(selectedDir, '*.set'));
            
            if isempty(fileList)
                errordlg('No .set files found in the selected directory.', 'Error');
                return;
            end
            
            % Create a progress bar
            h = waitbar(0, 'Processing datasets...', 'Name', 'Batch Processing');
            
            try
                % Process each dataset
                for i = 1:length(fileList)
                    file_path = fullfile(selectedDir, fileList(i).name);
                    waitbar(i/length(fileList), h, sprintf('Processing %d of %d: %s', i, length(fileList), fileList(i).name));
                    
                    try
                        % Load dataset
                        currentEEG = pop_loadset('filename', file_path);
                        
                        if isempty(currentEEG.data)
                            warning('Dataset %s is empty. Skipping...', file_path);
                            continue;
                        end
                        
                        % Process using text interest areas & trial labeling would happen in later steps
                        % We're just loading the datasets here
                        
                        % Save the processed dataset to the output directory
                        [~, fileName, ~] = fileparts(fileList(i).name);
                        output_path = fullfile(outputDir, [fileName '_processed.set']);
                        
                        % Save without dialogs - use only supported parameters
                        pop_saveset(currentEEG, 'filename', output_path, 'savemode', 'onefile');
                        
                        fprintf('Processed dataset %d/%d: %s\n', i, length(fileList), fileList(i).name);
                        
                    catch ME
                        warning('Failed to process dataset %s:\n%s', file_path, ME.message);
                    end
                end
                
                % Close progress bar
                delete(h);
                
                % For batch processing, we don't load anything into ALLEEG
                % This avoids EEGLAB detecting changes in the event structure
                
                % Build command string for history
                com = sprintf('EEG = pop_load_datasets(EEG); %% Batch processed %d datasets', length(fileList));
                
                % Success message
                msgbox(sprintf('Batch processing complete! %d datasets processed and saved to output directory.\nNote: These files were not loaded into EEGLAB to avoid event structure conflicts.', length(fileList)), 'Success');
                
            catch ME
                % Close progress bar if there was an error
                if exist('h', 'var') && ishandle(h)
                    delete(h);
                end
                errordlg(['Error during batch processing: ' ME.message], 'Error');
            end
            
        % INDIVIDUAL DATASETS PROCESSING (original method)
        else
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
                        pop_saveset(EEG, 'filename', output_path, 'savemode', 'onefile');
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

            % Refresh EEGLAB GUI
            eeglab('redraw');

            % Build the command string for EEGLAB history
            com = 'EEG = pop_load_datasets(EEG);';

            % Show success message
            msgbox('Datasets loaded successfully into EEGLAB.', 'Success');
        end
        
        close(hFig);
    end
end