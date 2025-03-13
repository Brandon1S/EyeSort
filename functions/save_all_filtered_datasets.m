function save_all_filtered_datasets
% SAVE_ALL_FILTERED_DATASETS - Saves all filtered datasets in ALLEEG 
%
% This function saves all datasets in the EEGLAB ALLEEG structure to their
% respective filepath/filename locations. It's designed to be run after using
% the pop_filter_datasets function to filter multiple datasets.
%
% Usage:
%   >> save_all_filtered_datasets;
%
% Inputs:
%   None - retrieves ALLEEG from the base workspace
%
% Outputs:
%   None - saves datasets to disk
%
% See also: pop_filter_datasets, pop_saveset

    % Retrieve ALLEEG from base workspace
    try
        ALLEEG = evalin('base', 'ALLEEG');
        if isempty(ALLEEG)
            errordlg('No datasets found in EEGLAB workspace.', 'Error');
            return;
        end
    catch
        errordlg('Could not access ALLEEG. Make sure EEGLAB is running.', 'Error');
        return;
    end
    
    % Count how many datasets need saving
    saveCount = 0;
    filteredDatasetIndices = [];
    
    for i = 1:length(ALLEEG)
        if ~isempty(ALLEEG(i)) && isfield(ALLEEG(i), 'event') && ~isempty(ALLEEG(i).event)
            % Method 1: Check for eyesort_filter_descriptions field (ideal case)
            if isfield(ALLEEG(i), 'eyesort_filter_descriptions') && ~isempty(ALLEEG(i).eyesort_filter_descriptions)
                saveCount = saveCount + 1;
                filteredDatasetIndices(end+1) = i;
                continue;
            end
            
            % Method 2: Check for 6-digit event types (backup method)
            hasFilteredEvents = false;
            for j = 1:length(ALLEEG(i).event)
                if isfield(ALLEEG(i).event(j), 'type') && ischar(ALLEEG(i).event(j).type) && ...
                   length(ALLEEG(i).event(j).type) == 6 && all(isstrprop(ALLEEG(i).event(j).type, 'digit'))
                    hasFilteredEvents = true;
                    break;
                end
            end
            
            if hasFilteredEvents
                saveCount = saveCount + 1;
                filteredDatasetIndices(end+1) = i;
                fprintf('Found dataset %d with filtered events but no filter descriptions. Will save anyway.\n', i);
            end
        end
    end
    
    if saveCount == 0
        msgbox('No filtered datasets found. Please run filtering first.', 'No Datasets');
        return;
    end
    
    % Ask user for output directory
    outputDir = uigetdir(pwd, 'Select directory to save filtered datasets');
    if outputDir == 0
        % User cancelled
        return;
    end
    
    % Create progress bar
    h = waitbar(0, 'Saving filtered datasets...', 'Name', 'Saving Datasets');
    
    try
        % Count of successfully saved datasets
        saved = 0;
        
        % Save each filtered dataset
        for idx = 1:length(filteredDatasetIndices)
            i = filteredDatasetIndices(idx);
            waitbar(saved/saveCount, h, sprintf('Saving dataset %d of %d...', saved+1, saveCount));
            
            % Get filename
            [~, baseName, ~] = fileparts(ALLEEG(i).filename);
            
            % Create filename - check if we have filter descriptions
            if isfield(ALLEEG(i), 'eyesort_filter_descriptions') && ~isempty(ALLEEG(i).eyesort_filter_descriptions)
                % If filename already has 'filtered' in it, use as is
                if contains(baseName, 'filtered')
                    filename = ALLEEG(i).filename;
                else
                    % Get the filter code from the last filter description
                    filterDescs = ALLEEG(i).eyesort_filter_descriptions;
                    filterCode = filterDescs{end}.filter_code;
                    filename = sprintf('%s_filtered_%s.set', baseName, filterCode);
                end
            else
                % No filter descriptions, just use generic filtered suffix
                if contains(baseName, 'filtered')
                    filename = ALLEEG(i).filename;
                else
                    filename = sprintf('%s_filtered.set', baseName);
                end
            end
            
            % Save the dataset
            fprintf('Saving dataset %d to %s...\n', i, fullfile(outputDir, filename));
            try
                % Use pop_saveset but don't update ALLEEG to avoid structure issues
                EEG_temp = ALLEEG(i);
                EEG_temp = pop_saveset(EEG_temp, 'filename', filename, 'filepath', outputDir);
                
                % Update the saved status in ALLEEG
                ALLEEG(i).saved = 'yes';
                saved = saved + 1;
            catch ME
                fprintf('Warning: Failed to save dataset %d: %s\n', i, ME.message);
            end
            
            % Update progress
            waitbar(saved/saveCount, h);
        end
        
        % Update ALLEEG in the base workspace
        assignin('base', 'ALLEEG', ALLEEG);
        
        % Close progress bar
        close(h);
        
        % Show summary
        if saved > 0
            msgbox(sprintf('Successfully saved %d of %d filtered datasets to:\n%s', saved, saveCount, outputDir), 'Save Complete');
        else
            errordlg('Failed to save any datasets. Check the MATLAB console for errors.', 'Save Failed');
        end
        
    catch ME
        % Close progress bar if there's an error
        if exist('h', 'var') && ishandle(h)
            close(h);
        end
        errordlg(['Error during save: ' ME.message], 'Error');
    end
end 