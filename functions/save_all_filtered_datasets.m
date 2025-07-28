function save_all_filtered_datasets
% SAVE_ALL_FILTERED_DATASETS - Saves filtered datasets using standard save dialog
%
% This function identifies filtered datasets in the EEGLAB EEG and ALLEEG structures
% and allows users to save them through the standard EEGLAB save dialog.
%
% Usage:
%   >> save_all_filtered_datasets;
%
% Inputs:
%   None - retrieves EEG and ALLEEG from the base workspace
%
% Outputs:
%   None - saves datasets to disk
%
% See also: pop_filter_datasets, pop_saveset

    % Initialize datasets to save
    datasetsToSave = {};
    datasetLabels = {};
    
    % First check the current EEG dataset
    try
        EEG = evalin('base', 'EEG');
        if ~isempty(EEG) && isfield(EEG, 'event') && ~isempty(EEG.event)
            % Check if this dataset has been filtered
            if isFilteredDataset(EEG)
                datasetsToSave{end+1} = EEG;
                % Create a label for the dataset
                if isfield(EEG, 'setname') && ~isempty(EEG.setname)
                    datasetLabels{end+1} = EEG.setname;
                elseif isfield(EEG, 'filename') && ~isempty(EEG.filename)
                    datasetLabels{end+1} = EEG.filename;
                else
                    datasetLabels{end+1} = 'Current Dataset';
                end
            end
        end
    catch
        % If EEG isn't available, continue checking ALLEEG
    end
    
    % Then check ALLEEG for additional filtered datasets
    try
        ALLEEG = evalin('base', 'ALLEEG');
        if ~isempty(ALLEEG)
            for i = 1:length(ALLEEG)
                if ~isempty(ALLEEG(i)) && isfield(ALLEEG(i), 'event') && ~isempty(ALLEEG(i).event)
                    % Check if this dataset has been filtered
                    if isFilteredDataset(ALLEEG(i))
                        datasetsToSave{end+1} = ALLEEG(i);
                        % Create a label for the dataset
                        if isfield(ALLEEG(i), 'setname') && ~isempty(ALLEEG(i).setname)
                            datasetLabels{end+1} = sprintf('%s (Dataset %d)', ALLEEG(i).setname, i);
                        elseif isfield(ALLEEG(i), 'filename') && ~isempty(ALLEEG(i).filename)
                            datasetLabels{end+1} = sprintf('%s (Dataset %d)', ALLEEG(i).filename, i);
                        else
                            datasetLabels{end+1} = sprintf('Dataset %d', i);
                        end
                    end
                end
            end
        end
    catch
        % If ALLEEG isn't available, continue with whatever we found in EEG
    end
    
    % Check if we found any filtered datasets
    if isempty(datasetsToSave)
        msgbox('No filtered datasets found. Please run filtering first.', 'No Datasets');
        return;
    end
    
    % If we have multiple datasets, let the user select which one to save
    selectedIndex = 1;
    if length(datasetsToSave) > 1
        [selectedIndex, ok] = listdlg('PromptString', 'Select dataset to save:', ...
                                    'SelectionMode', 'single', ...
                                    'ListString', datasetLabels, ...
                                    'Name', 'Save Filtered Dataset');
        if ~ok || isempty(selectedIndex)
            % User cancelled
            return;
        end
    end
    
    % Get the selected dataset
    selectedEEG = datasetsToSave{selectedIndex};
    
    % Add filter info to setname if it exists
    if isfield(selectedEEG, 'eyesort_filter_descriptions') && ~isempty(selectedEEG.eyesort_filter_descriptions)
        % Get the filter code from the last filter description
        filterDescs = selectedEEG.eyesort_filter_descriptions;
        filterCode = filterDescs{end}.filter_code;
        
        % Add filter code to setname if it doesn't already have it
        if isfield(selectedEEG, 'setname') && ~isempty(selectedEEG.setname)
            if ~contains(selectedEEG.setname, ['filtered_' filterCode])
                selectedEEG.setname = [selectedEEG.setname '_filtered_' filterCode];
            end
        end
    end
    
    % Show save dialog for the dataset
    fprintf('Please save the filtered dataset...\n');
    try
        % Get the original filename and filepath if available
        saveFilename = '';
        savePath = '';
        
        if isfield(selectedEEG, 'filename') && ~isempty(selectedEEG.filename)
            [filepath, baseName, ~] = fileparts(selectedEEG.filename);
            if isfield(selectedEEG, 'eyesort_filter_descriptions') && ~isempty(selectedEEG.eyesort_filter_descriptions)
                filterCode = selectedEEG.eyesort_filter_descriptions{end}.filter_code;
                saveFilename = [baseName '_filtered_' filterCode '.set'];
            else
                saveFilename = [baseName '_filtered.set'];
            end
            
            % Use dataset filepath if available, otherwise current directory
            if isfield(selectedEEG, 'filepath') && ~isempty(selectedEEG.filepath)
                savePath = selectedEEG.filepath;
            elseif ~isempty(filepath)
                savePath = filepath;
            end
        end
        
        % If there's no filename yet, use direct UI approach
        if isempty(saveFilename)
            [selectedEEG, cancelFlag] = pop_saveset(selectedEEG);
        else
            % Use direct file picking approach to show the UI with the 
            % correct default filename - this works around limitations in pop_saveset
            [filename, filepath, filterindex] = uiputfile({'*.set','EEGLAB Dataset file (*.set)'},...
                'Save dataset with .set extension', fullfile(savePath, saveFilename));
            
            if filename ~= 0
                % User chose a file
                selectedEEG.filename = filename;
                selectedEEG.filepath = filepath;
                
                % Now save the dataset with the chosen filename
                [selectedEEG, cancelFlag] = pop_saveset(selectedEEG, 'filename', filename, 'filepath', filepath, 'savemode', 'twofiles');
            else
                % User cancelled
                cancelFlag = 1;
            end
        end
        
        if ~cancelFlag
            fprintf('Dataset saved successfully.\n');
        else
            fprintf('Save cancelled by user.\n');
        end
    catch ME
        errordlg(['Error during save: ' ME.message], 'Save Failed');
        fprintf('Warning: Failed to save dataset: %s\n', ME.message);
    end
end

% Helper function to check if a dataset has been filtered
function result = isFilteredDataset(EEG)
    result = false;
    
    % Method 1: Check for eyesort_filter_descriptions field (ideal case)
    if isfield(EEG, 'eyesort_filter_descriptions') && ~isempty(EEG.eyesort_filter_descriptions)
        result = true;
        return;
    end
    
    % Method 2: Check for eyesort_filter_count field
    if isfield(EEG, 'eyesort_filter_count') && EEG.eyesort_filter_count > 0
        result = true;
        return;
    end
    
    % Method 3: Check for 6-digit event types (backup method)
    for j = 1:length(EEG.event)
        if isfield(EEG.event(j), 'type') && ischar(EEG.event(j).type) && ...
           length(EEG.event(j).type) == 6 && all(isstrprop(EEG.event(j).type, 'digit'))
            result = true;
            return;
        end
    end
end 