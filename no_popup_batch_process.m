function [ALLEEG, EEG, CURRENTSET] = no_popup_batch_process(datasetFiles, txtFilePath, ...
                                           offset, pxPerChar, numRegions, regionNames, ...
                                           conditionColName, itemColName, startCode, endCode, ...
                                           conditionTriggers, itemTriggers, applyFilter, saveOutput)
% NO_POPUP_BATCH_PROCESS - Process multiple EEG datasets without triggering save dialogs
%
% Usage:
%   >> [ALLEEG, EEG, CURRENTSET] = no_popup_batch_process(datasetFiles, txtFilePath, ...
%                                           offset, pxPerChar, numRegions, regionNames, ...
%                                           conditionColName, itemColName, startCode, endCode, ...
%                                           conditionTriggers, itemTriggers, applyFilter, saveOutput);
%
% Inputs:
%   datasetFiles     - Cell array of full paths to EEG dataset files (or struct array from dir())
%   txtFilePath      - Path to text file containing interest area definitions
%   offset           - Pixel offset (e.g., 281)
%   pxPerChar        - Pixels per character (e.g., 14)
%   numRegions       - Number of regions (e.g., 4)
%   regionNames      - Cell array of region names (e.g., {'Beginning','PreTarget','Target_word','Ending'})
%   conditionColName - Name of condition column in text file (e.g., 'trigcondition')
%   itemColName      - Name of item column in text file (e.g., 'trigitem')
%   startCode        - Start trial code (e.g., 'S254')
%   endCode          - End trial code (e.g., 'S255')
%   conditionTriggers- Cell array of condition triggers (e.g., {'S211','S213','S221','S223'})
%   itemTriggers     - Cell array of item triggers (e.g., {'S1','S2',...'S112'})
%   applyFilter      - [0|1] Whether to apply filtering (default: 1)
%   saveOutput       - [0|1] Whether to save output datasets (default: 0)
%
% Outputs:
%   ALLEEG     - Updated EEGLAB ALLEEG structure
%   EEG        - Current EEG dataset structure
%   CURRENTSET - Current dataset index
%
% Notes:
%   This function disables EEGLAB's automatic save prompts during processing
%   and optionally saves datasets at the end of processing.

% Process input arguments
if nargin < 13
    applyFilter = 1; % Default to applying filter
end
if nargin < 14
    saveOutput = 0; % Default to not saving
end

% Initialize EEGLAB if not already started
if ~exist('ALLCOM', 'var')
    [ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
    close(gcf); % Close the EEGLAB GUI window
else
    % Get EEGLAB structures from base workspace
    evalin('base', 'eeglab redraw');
    ALLEEG = evalin('base', 'ALLEEG');
    EEG = evalin('base', 'EEG');
    CURRENTSET = evalin('base', 'CURRENTSET');
end

% Convert struct array from dir() to cell array of full paths if needed
if isstruct(datasetFiles)
    fileStruct = datasetFiles;
    datasetFiles = cell(1, length(fileStruct));
    for i = 1:length(fileStruct)
        datasetFiles{i} = fullfile(fileStruct(i).folder, fileStruct(i).name);
    end
end

% Display processing information
fprintf('\n==== Starting Batch Processing ====\n');
fprintf('Number of datasets to process: %d\n', length(datasetFiles));
fprintf('Text file path: %s\n', txtFilePath);
fprintf('Number of regions: %d\n', numRegions);
fprintf('Region names: %s\n', strjoin(regionNames, ', '));
fprintf('Will apply filtering: %s\n', iif(applyFilter, 'Yes', 'No'));
fprintf('Will save outputs: %s\n', iif(saveOutput, 'Yes', 'No'));
fprintf('================================\n\n');

% Disable EEGLAB's automatic save prompts
fprintf('Disabling EEGLAB auto-save dialogs...\n');
toggle_eeglab_autosave('disable');

try
    % Step 1: Load all datasets
    fprintf('\nStep 1: Loading %d datasets...\n', length(datasetFiles));
    loadedEEGs = cell(1, length(datasetFiles));
    
    for i = 1:length(datasetFiles)
        try
            % Get filename from path
            [~, filename, ext] = fileparts(datasetFiles{i});
            fprintf('Loading dataset %d of %d: %s%s\n', i, length(datasetFiles), filename, ext);
            
            % Load dataset
            tmpEEG = pop_loadset('filename', datasetFiles{i});
            fprintf('Successfully loaded dataset with %d events\n', length(tmpEEG.event));
            
            % Store in cell array
            loadedEEGs{i} = tmpEEG;
        catch ME
            fprintf('Error loading dataset %s: %s\n', datasetFiles{i}, ME.message);
            fprintf('Skipping this dataset...\n');
        end
    end
    
    % Step 2: Process each dataset with text interest areas
    fprintf('\nStep 2: Processing datasets with text interest areas...\n');
    for i = 1:length(loadedEEGs)
        if ~isempty(loadedEEGs{i})
            try
                fprintf('Processing dataset %d of %d...\n', i, length(loadedEEGs));
                
                % Apply text interest area processing
                loadedEEGs{i} = new_combined_compute_text_based_ia(loadedEEGs{i}, txtFilePath, offset, pxPerChar, ...
                                            numRegions, regionNames, conditionColName, itemColName, ...
                                            startCode, endCode, conditionTriggers, itemTriggers);
                
                fprintf('Successfully processed dataset %d\n', i);
            catch ME
                fprintf('Error processing dataset %d: %s\n', i, ME.message);
                fprintf('Skipping this dataset...\n');
            end
        end
    end
    
    % Step 3: Transfer to ALLEEG for filtering
    fprintf('\nStep 3: Transferring to ALLEEG for filtering...\n');
    ALLEEG = []; % Reset ALLEEG
    EEG = eeg_emptyset; % Reset EEG
    CURRENTSET = 0;
    
    for i = 1:length(loadedEEGs)
        if ~isempty(loadedEEGs{i})
            % Store with auto-save disabled
            [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, loadedEEGs{i}, i);
            fprintf('Dataset %d stored in ALLEEG\n', i);
        end
    end
    
    % Step 4: Apply filtering if requested
    if applyFilter && ~isempty(ALLEEG)
        fprintf('\nStep 4: Applying filtering...\n');
        
        % Find valid dataset to use for filter GUI
        validDatasetIdx = [];
        for i = 1:length(ALLEEG)
            if isfield(ALLEEG(i), 'event') && ~isempty(ALLEEG(i).event)
                if any(arrayfun(@(ev) isfield(ev, 'regionBoundaries') && ~isempty(ev.regionBoundaries), ALLEEG(i).event))
                    validDatasetIdx(end+1) = i;
                end
            end
        end
        
        if isempty(validDatasetIdx)
            error('No valid dataset with region boundaries found. Please check processing.');
        end
        
        fprintf('Using dataset %d as the filter template.\n', validDatasetIdx(1));
        fprintf('The filter will be applied to all datasets.\n');
        
        % Reset filter descriptions in all datasets to ensure consistency
        fprintf('Resetting filter descriptions in all datasets...\n');
        for i = 1:length(ALLEEG)
            if isfield(ALLEEG(i), 'eyesort_filter_descriptions')
                fprintf('Clearing previous filter descriptions from dataset %d\n', i);
                ALLEEG(i).eyesort_filter_descriptions = {};
            end
            if isfield(ALLEEG(i), 'eyesort_filter_count')
                ALLEEG(i).eyesort_filter_count = 0;
            end
        end
        
        % Launch the filter dialog
        tempEEG = ALLEEG(validDatasetIdx(1));
        [tempEEG, filterCom] = pop_filter_datasets(tempEEG);
        
        % Check if filtering was applied
        if ~isempty(filterCom) && isfield(tempEEG, 'eyesort_filter_descriptions') && ~isempty(tempEEG.eyesort_filter_descriptions)
            % Update the template dataset
            ALLEEG(validDatasetIdx(1)) = tempEEG;
            
            % Get the number of filters
            numFilters = length(tempEEG.eyesort_filter_descriptions);
            fprintf('Applying %d filters to all datasets...\n', numFilters);
            
            % Apply each filter to all datasets
            for filterIdx = 1:numFilters
                fprintf('\n--- Applying Filter #%d to all datasets ---\n', filterIdx);
                filterDesc = tempEEG.eyesort_filter_descriptions{filterIdx};
                
                % Extract filter parameters
                filterParams = struct();
                filterParams.timeLockedRegions = filterDesc.regions;
                filterParams.passIndex = filterDesc.pass_value;
                filterParams.prevRegion = filterDesc.prev_region;
                filterParams.nextRegion = filterDesc.next_region;
                filterParams.fixationType = filterDesc.fixation_value;
                filterParams.saccadeDirection = filterDesc.saccade_value;
                filterParams.filterCount = filterIdx;
                
                % Set filter code to be 1-indexed (01, 02, 03, etc.)
                filterCode = sprintf('%02d', filterIdx);
                filterParams.forceFilterCode = filterCode;
                
                fprintf('Setting filter code to "%s" for all datasets\n', filterCode);
                
                % Apply the filter to all datasets
                for i = 1:length(ALLEEG)
                    if isfield(ALLEEG(i), 'event') && ~isempty(ALLEEG(i).event)
                        fprintf('Applying filter #%d (code: %s) to dataset %d...\n', filterIdx, filterParams.forceFilterCode, i);
                        try
                            % Get filtered version of this dataset
                            filteredEEG = batch_filter_dataset(ALLEEG(i), filterParams);
                            
                            % Safe field-by-field copying to avoid structure mismatch errors
                            filteredFields = fieldnames(filteredEEG);
                            for fIdx = 1:length(filteredFields)
                                fieldName = filteredFields{fIdx};
                                ALLEEG(i).(fieldName) = filteredEEG.(fieldName);
                            end
                            
                            fprintf('Successfully applied filter to dataset %d\n', i);
                        catch ME
                            fprintf('Error applying filter to dataset %d: %s\n', i, ME.message);
                        end
                    else
                        fprintf('Skipping dataset %d (missing event information).\n', i);
                    end
                end
            end
            
            % Verify filter consistency
            fprintf('\nVerifying filter consistency across datasets...\n');
            referenceFilterCount = 0;
            allConsistent = true;
            
            for i = 1:length(ALLEEG)
                if ~isempty(ALLEEG(i)) && isfield(ALLEEG(i), 'eyesort_filter_descriptions')
                    filterCount = length(ALLEEG(i).eyesort_filter_descriptions);
                    
                    if i == 1
                        referenceFilterCount = filterCount;
                        fprintf('Reference dataset has %d filters\n', referenceFilterCount);
                    else
                        if filterCount ~= referenceFilterCount
                            fprintf('WARNING: Dataset %d has %d filters (expected %d)\n', i, filterCount, referenceFilterCount);
                            allConsistent = false;
                        else
                            fprintf('Dataset %d has %d filters (consistent)\n', i, filterCount);
                        end
                    end
                end
            end
            
            if allConsistent
                fprintf('All datasets have consistent filter counts (%d filters each)\n', referenceFilterCount);
            else
                fprintf('WARNING: Filter counts are inconsistent across datasets. This may cause issues with analysis.\n');
            end
        else
            fprintf('No filters were applied or filtering was cancelled.\n');
        end
    end
    
    % Step 5: Save filtered datasets if requested
    if saveOutput
        fprintf('\nStep 5: Saving processed datasets...\n');
        
        % Create output directory if it doesn't exist
        [filepath, ~, ~] = fileparts(datasetFiles{1});
        outputDir = fullfile(filepath, 'processed');
        if ~exist(outputDir, 'dir')
            mkdir(outputDir);
            fprintf('Created output directory: %s\n', outputDir);
        end
        
        % Save each dataset
        for i = 1:length(ALLEEG)
            if ~isempty(ALLEEG(i))
                try
                    % Use original filename with "_processed" suffix
                    [~, basename, ~] = fileparts(ALLEEG(i).filename);
                    newFilename = [basename '_processed.set'];
                    
                    fprintf('Saving dataset %d: %s\n', i, newFilename);
                    
                    % Manually save without prompts
                    ALLEEG(i) = pop_saveset(ALLEEG(i), 'filename', newFilename, 'filepath', outputDir, 'savemode', 'onefile');
                    
                    fprintf('Dataset %d saved successfully.\n', i);
                catch ME
                    fprintf('Error saving dataset %d: %s\n', i, ME.message);
                end
            end
        end
        
        fprintf('\nAll processed datasets have been saved to: %s\n', outputDir);
    end
    
    % Final report
    fprintf('\n==== Batch Processing Complete ====\n');
    fprintf('Processed %d datasets\n', length(ALLEEG));
    if applyFilter
        fprintf('Applied %d filters\n', numFilters);
    end
    fprintf('==================================\n');
    
    % Return current set if available
    if ~isempty(ALLEEG)
        EEG = ALLEEG(end);
        CURRENTSET = length(ALLEEG);
    end
    
    % Update EEGLAB
    assignin('base', 'ALLEEG', ALLEEG);
    assignin('base', 'EEG', EEG);
    assignin('base', 'CURRENTSET', CURRENTSET);
    evalin('base', 'eeglab redraw');
    
catch ME
    % Re-enable EEGLAB's automatic save prompts before rethrowing error
    toggle_eeglab_autosave('enable');
    rethrow(ME);
end

% Re-enable EEGLAB's automatic save prompts
toggle_eeglab_autosave('enable');

end

% Helper function for ternary operator
function result = iif(condition, trueVal, falseVal)
    if condition
        result = trueVal;
    else
        result = falseVal;
    end
end 