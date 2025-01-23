function [EEG, com] = pop_load_datasets(EEG)

% pop_load_datasets() - A "pop" function to load multiple EEG .set files
%                       via a GUI dialog, then store them in ALLEEG.
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
    };
    
    geomvert = [0.5, 0.5, 3, 0.5, 0.7, 0.7];
    
    uilist = { ...
        % Row 1: Input EEG datasets
        {'Style', 'text', 'string', 'Load trial EEG Datasets:', 'FontSize', 12}, ...
        {}, ...
        {}, ...
        {'Style', 'pushbutton', 'string', 'Browse', 'callback', @(~,~) browse_for_datasets()}, ...
        ... Row 2: Selected Datasets label
        {'Style', 'text', 'string', 'Selected Datasets:', 'FontSize', 10, 'HorizontalAlignment', 'left'}, ...
        {}, ...
        ... Row 3: 
        {'Style', 'listbox', 'tag', 'datasetList', 'string', selected_datasets, 'Max', 10, 'Min', 1, 'HorizontalAlignment', 'left'}, ...
        ... Row 4:
        {'Style', 'pushbutton', 'string', 'Remove Selected', 'callback', @(~,~) remove_dataset()}, ...
        {'Style', 'pushbutton', 'string', 'Clear All', 'callback', @(~,~) clear_all_datasets()}, ...
        {}, {}, ...
        ... Row 5:
        {}, ...
        ... Row 6:
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
        if isempty(selected_datasets)
            errordlg('No datasets selected. Please browse and select datasets.', 'Error');
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
        close(hFig);
    end
end