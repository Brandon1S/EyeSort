%% batch_processing.m
% This script loads multiple EEG .set files, processes each with text interest
% area definitions and trial labeling, then uses a filter GUI to capture filter 
% parameters and applies filtering across all datasets (potentially multiple times).
% Finally, it saves all filtered datasets in a designated folder.

clear;
clc;

% --- Step 0: Check that EEGLAB is available ---
if ~exist('eeglab', 'file')
    error('EEGLAB not found in path. Please run EEGLAB first.');
end
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
%close(gcf);  % Close the EEGLAB GUI window

%% Step 1: Load all datasets from the specified folder
datasetDir = '/Users/brandon/Datasets/Electric_Datasets/electric_eyel_small';
datasetFiles = dir(fullfile(datasetDir, '*.set'));
if isempty(datasetFiles)
    error('No .set files found in %s', datasetDir);
end

fprintf('Loading %d datasets...\n', length(datasetFiles));
processedEEGs = cell(1, length(datasetFiles));  % Use a cell array for processed EEGs

for i = 1:length(datasetFiles)
    filename = datasetFiles(i).name;
    filepath = datasetFiles(i).folder;
    fprintf('Loading dataset %d of %d: %s\n', i, length(datasetFiles), filename);
    try
        EEG = pop_loadset('filename', filename, 'filepath', filepath);
        processedEEGs{i} = EEG;
        fprintf('Successfully loaded dataset %d.\n', i);
    catch ME
        fprintf('Error loading dataset %s: %s\n', filename, ME.message);
        fprintf('Skipping this dataset...\n');
    end
end

%% Step 2: Process each dataset with text interest areas and trial labeling
txtFilePath = '/Users/brandon/Datasets/Electric_Eyel_V2_Datasource_IAs.txt';
offset = 488;                  % Pixel offset
pxPerChar = 11;                % Pixels per character
numRegions = 4;                % Number of regions
regionNames = {'Beginning', 'PreTarget', 'Target_word', 'Ending'};

conditionColNames = {'trigcondition', '$trigcondition'};
itemColNames      = {'trigitem', '$trigitem'};

startCode          = 'S254';   % Start trigger code
endCode            = 'S255';   % End trigger code
conditionTriggers  = {'S211','S213','S221','S223'};
itemTriggers       = arrayfun(@(x) ['S' num2str(x)], 1:112, 'UniformOutput', false);

% Define eyetracking field names - required parameters
fixationType = 'R_fixation';                % The event type for fixations
fixationXField = 'fix_avgpos_x';            % The field containing x-coordinate for fixations
saccadeType = 'R_saccade';                  % The event type for saccades
saccadeStartXField = 'sac_startpos_x';      % The field containing saccade start x-coordinate
saccadeEndXField = 'sac_endpos_x';          % The field containing saccade end x-coordinate

% --- Determine actual column names from the text file ---
try
    opts = detectImportOptions(txtFilePath, 'Delimiter', '\t');
    opts.VariableNamingRule = 'preserve';
    data = readtable(txtFilePath, opts);
    fprintf('Available columns in text file:\n');
    disp(data.Properties.VariableNames);
    
    conditionColName = '';
    for k = 1:length(conditionColNames)
        if ismember(conditionColNames{k}, data.Properties.VariableNames)
            conditionColName = conditionColNames{k};
            fprintf('Using condition column: %s\n', conditionColName);
            break;
        end
    end
    
    itemColName = '';
    for k = 1:length(itemColNames)
        if ismember(itemColNames{k}, data.Properties.VariableNames)
            itemColName = itemColNames{k};
            fprintf('Using item column: %s\n', itemColName);
            break;
        end
    end
    
    if isempty(conditionColName) || isempty(itemColName)
        error('Could not determine proper column names from text file.');
    end
catch ME
    error('Error checking text file: %s', ME.message);
end

fprintf('\nStep 2: Processing datasets with text interest areas...\n');
for i = 1:length(processedEEGs)
    try
        EEG = processedEEGs{i};
        fprintf('Processing dataset %d of %d...\n', i, length(processedEEGs));
        
        EEG = new_combined_compute_text_based_ia(EEG, txtFilePath, offset, pxPerChar, ...
                          numRegions, regionNames, conditionColName, itemColName, ...
                          startCode, endCode, conditionTriggers, itemTriggers, ...
                          fixationType, fixationXField, saccadeType, saccadeStartXField, saccadeEndXField);
        
        % No need to call new_trial_labelling separately, it's now called inside new_combined_compute_text_based_ia
        
        processedEEGs{i} = EEG;
        fprintf('Dataset %d processed successfully.\n', i);
    catch ME
        fprintf('Error processing dataset %d: %s\n', i, ME.message);
        fprintf('Skipping this dataset...\n');
    end
end

fprintf('\nAll datasets processed with regions and trial labeling.\n');

%% Step 3: Interactive Filtering Across All Datasets (Multiple Passes)
% Transfer processed datasets to ALLEEG structure
for i = 1:length(processedEEGs)
    if ~isempty(processedEEGs{i})
        [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, processedEEGs{i}, i);
    end
end

% Diagnostic print to check initial dataset state
fprintf('Initial dataset state in ALLEEG:\n');
for i = 1:length(ALLEEG)
    if ~isempty(ALLEEG(i)) && isfield(ALLEEG(i), 'event') && ~isempty(ALLEEG(i).event)
        fprintf('Dataset %d: %s, Event count: %d\n', i, ALLEEG(i).setname, length(ALLEEG(i).event));
        % Check for specific filtering fields
        if isfield(ALLEEG(i), 'eyesort_field_names')
            fprintf('  Has field name definitions: Yes\n');
            fprintf('  Fixation Type: %s, X Field: %s\n', ALLEEG(i).eyesort_field_names.fixationType, ALLEEG(i).eyesort_field_names.fixationXField);
        else
            fprintf('  Has field name definitions: No\n');
        end
        if isfield(ALLEEG(i), 'eyesort_filter_descriptions')
            fprintf('  Has filter descriptions: Yes\n');
        else
            fprintf('  Has filter descriptions: No\n');
        end
    end
end

% Find a valid dataset (with region boundaries) to use for launching the filter GUI.
validDatasetIdx = [];
for i = 1:length(ALLEEG)
    if isfield(ALLEEG(i), 'event') && ~isempty(ALLEEG(i).event) && isfield(ALLEEG(i), 'eyesort_field_names')
        % Check if any event in this dataset has non-empty regionBoundaries
        if any(arrayfun(@(ev) isfield(ev, 'regionBoundaries') && ~isempty(ev.regionBoundaries), ALLEEG(i).event))
            validDatasetIdx(end+1) = i;
        end
    end
end

if isempty(validDatasetIdx)
    error('No valid dataset with region boundaries and field name definitions found. Please check processing.');
end

fprintf('\n--- Starting Interactive Filtering Session ---\n');
fprintf('Using dataset %d as the filter template. The filter will be applied to all datasets.\n', validDatasetIdx(1));
fprintf('You can apply multiple filters in sequence using the new filter GUI.\n');
fprintf('- Use the "Apply Filter" button to apply a filter and set up another one\n');
fprintf('- Use the "Finish" button when you are done with all filtering\n');
fprintf('- Use the "Cancel" button to cancel the entire filtering process\n\n');

% Use one valid dataset (the first one in validDatasetIdx) to launch the filter GUI.
tempEEG = ALLEEG(validDatasetIdx(1));

% Launch the filter dialog - now with Apply/Finish/Cancel options
[tempEEG, com] = pop_filter_datasets(tempEEG);
drawnow; % Ensure GUI updates are processed

% Check if filtering was applied or cancelled
if isempty(com)
    fprintf('\nFiltering was cancelled. No filters were applied.\n');
else
    % Safely update the valid dataset with the filtered EEG
    % Use field-by-field copying to avoid structure mismatch errors
    try
        fprintf('Updating dataset with filter results...\n');
        
        % Check if the structures have different fields
        tempFields = fieldnames(tempEEG);
        alleegFields = fieldnames(ALLEEG(validDatasetIdx(1)));
        
        % Find fields that exist in tempEEG but not in ALLEEG(validDatasetIdx(1))
        newFields = setdiff(tempFields, alleegFields);
        if ~isempty(newFields)
            fprintf('Adding %d new fields to ALLEEG structure...\n', length(newFields));
        end
        
        % Copy all fields from tempEEG to ALLEEG
        for i = 1:length(tempFields)
            fieldName = tempFields{i};
            ALLEEG(validDatasetIdx(1)).(fieldName) = tempEEG.(fieldName);
        end
        
        fprintf('Dataset successfully updated with filter results.\n');
    catch ME
        fprintf('Warning: Error updating dataset: %s\n', ME.message);
        fprintf('Will continue processing with the original filter parameters.\n');
    end
    
    % Check if any filters were applied
    if isfield(tempEEG, 'eyesort_filter_descriptions') && ~isempty(tempEEG.eyesort_filter_descriptions)
        fprintf('\nApplying all filters to all datasets...\n');
        % Get the number of filters that were applied
        numFilters = length(tempEEG.eyesort_filter_descriptions);
        fprintf('Total filters to apply: %d\n', numFilters);
        
        % Reset filter descriptions in all datasets to ensure consistency
        fprintf('Resetting filter descriptions in all datasets for consistent filtering...\n');
        for i = 1:length(ALLEEG)
            if isfield(ALLEEG(i), 'eyesort_filter_descriptions')
                fprintf('Clearing previous filter descriptions from dataset %d\n', i);
                ALLEEG(i).eyesort_filter_descriptions = {};
            end
            if isfield(ALLEEG(i), 'eyesort_filter_count')
                ALLEEG(i).eyesort_filter_count = 0;
            end
        end
        
        % Apply each filter to all datasets
        for filterIdx = 1:numFilters
            fprintf('\n--- Applying Filter #%d to all datasets ---\n', filterIdx);
            filterDesc = tempEEG.eyesort_filter_descriptions{filterIdx};
            
            % Prep filter parameters
            filter_params = struct();
            filter_params.timeLockedRegions = filterDesc.regions;
            
            % Extract pass options from either old or new format
            if isfield(filterDesc, 'pass_options')
                filter_params.pass_options = filterDesc.pass_options;
            elseif isfield(filterDesc, 'passIndex')
                filter_params.pass_options = filterDesc.passIndex;
            end
            
            % Extract previous region(s) from either old or new format
            if isfield(filterDesc, 'prev_regions')
                filter_params.prev_regions = filterDesc.prev_regions;
            elseif isfield(filterDesc, 'prev_region')
                filter_params.prev_regions = {filterDesc.prev_region};
            end
            
            % Extract next region(s) from either old or new format
            if isfield(filterDesc, 'next_regions')
                filter_params.next_regions = filterDesc.next_regions;
            elseif isfield(filterDesc, 'next_region')
                filter_params.next_regions = {filterDesc.next_region};
            end
            
            % Extract fixation options from either old or new format
            if isfield(filterDesc, 'fixation_options')
                filter_params.fixation_options = filterDesc.fixation_options;
            elseif isfield(filterDesc, 'fixationType')
                filter_params.fixation_options = filterDesc.fixationType;
            end
            
            % Extract saccade in options from either old or new format
            if isfield(filterDesc, 'saccade_in_options')
                filter_params.saccade_in_options = filterDesc.saccade_in_options;
            elseif isfield(filterDesc, 'saccadeInDirection')
                filter_params.saccade_in_options = filterDesc.saccadeInDirection;
            end
            
            % Extract saccade out options from either old or new format
            if isfield(filterDesc, 'saccade_out_options')
                filter_params.saccade_out_options = filterDesc.saccade_out_options;
            elseif isfield(filterDesc, 'saccadeOutDirection')
                filter_params.saccade_out_options = filterDesc.saccadeOutDirection;
            end
            
            filter_params.filterCount = filterIdx;
            
            % Set filter code to be 1-indexed (01, 02, 03, etc.)
            filterCode = sprintf('%02d', filterIdx);
            filter_params.forceFilterCode = filterCode;
            
            fprintf('Setting filter code to "%s" for all datasets in this batch\n', filterCode);
            
            % Apply the filter to all datasets
            for i = 1:length(ALLEEG)
                if isfield(ALLEEG(i), 'event') && ~isempty(ALLEEG(i).event)
                    fprintf('Applying filter #%d (code: %s) to dataset %d...\n', filterIdx, filter_params.forceFilterCode, i);
                    try
                        % Get filtered version of this dataset
                        filteredEEG = batch_filter_dataset(ALLEEG(i), filter_params);
                        
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
        
        fprintf('\nAll filters have been applied to all datasets.\n');
        
        % Verify filter consistency across datasets
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
        fprintf('\nNo filters were applied during the filtering session.\n');
    end
end

% After filtering loop, check the status of filtered datasets
fprintf('\nFiltered dataset state in ALLEEG:\n');
for i = 1:length(ALLEEG)
    if ~isempty(ALLEEG(i)) && isfield(ALLEEG(i), 'event') && ~isempty(ALLEEG(i).event)
        fprintf('Dataset %d: %s, Event count: %d\n', i, ALLEEG(i).setname, length(ALLEEG(i).event));
        % Check for filtering fields
        if isfield(ALLEEG(i), 'eyesort_filter_descriptions')
            fprintf('  Has filter descriptions: Yes (%d filters)\n', length(ALLEEG(i).eyesort_filter_descriptions));
            % Check if events have trial_acceptance_code
            if any(arrayfun(@(ev) isfield(ev, 'trial_acceptance_code'), ALLEEG(i).event))
                fprintf('  Has trial acceptance codes: Yes\n');
                
                % Print the first 5 trial acceptance codes as a sample
                codes = {ALLEEG(i).event(arrayfun(@(ev) isfield(ev, 'trial_acceptance_code'), ALLEEG(i).event)).trial_acceptance_code};
                if ~isempty(codes)
                    fprintf('  Sample codes: %s\n', strjoin(unique(codes(1:min(5,length(codes)))), ', '));
                end
            else
                fprintf('  Has trial acceptance codes: No\n');
            end
        else
            fprintf('  Has filter descriptions: No\n');
        end
    end
end

% Modified code for transferring from ALLEEG to processedEEGs
fprintf('\nTransferring filtered datasets from ALLEEG to processedEEGs...\n');
for i = 1:length(ALLEEG)
    if ~isempty(ALLEEG(i))
        % Check if this ALLEEG dataset has filter descriptions
        if isfield(ALLEEG(i), 'eyesort_filter_descriptions') && ~isempty(ALLEEG(i).eyesort_filter_descriptions)
            fprintf('Dataset %d has filter descriptions, transferring to processedEEGs\n', i);
            
            % Safe field-by-field copying to avoid structure mismatch errors
            if ~isempty(processedEEGs{i})
                alleegFields = fieldnames(ALLEEG(i));
                for fIdx = 1:length(alleegFields)
                    fieldName = alleegFields{fIdx};
                    processedEEGs{i}.(fieldName) = ALLEEG(i).(fieldName);
                end
            else
                % If processedEEGs{i} is empty, we need to create a new structure
                processedEEGs{i} = ALLEEG(i);
            end
            
            fprintf('Successfully transferred dataset %d\n', i);
        else
            fprintf('Dataset %d has no filter descriptions\n', i);
        end
    end
end

fprintf('\nFiltering complete. Proceeding to save all processed datasets.\n');

%% Step 4: Save All Processed Datasets
outputDir = fullfile(datasetDir, 'electric_eyel_processed');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
    fprintf('Created output directory: %s\n', outputDir);
end

fprintf('Saving all processed datasets...\n');

% Now save the datasets with verification of filter codes
for i = 1:length(processedEEGs)
    try
        EEG = processedEEGs{i};
        if isempty(EEG) || ~isfield(EEG, 'event') || isempty(EEG.event)
            fprintf('Skipping dataset %d (no events)...\n', i);
            continue;
        end
        
        % Check for region boundaries and filter codes
        hasRegionBoundaries = any(arrayfun(@(ev) isfield(ev, 'regionBoundaries') && ~isempty(ev.regionBoundaries), EEG.event));
        hasFilterCodes = isfield(EEG, 'eyesort_filter_descriptions') && ~isempty(EEG.eyesort_filter_descriptions);
        
        fprintf('Dataset %d: Has region boundaries: %s, Has filter codes: %s\n', i, string(hasRegionBoundaries), string(hasFilterCodes));
        
        if ~hasRegionBoundaries
            fprintf('  Skipping dataset %d (no region boundaries)...\n', i);
            continue;
        end
        
        % Use original filename with "_processed" suffix
        [~, basename, ~] = fileparts(EEG.filename);
        newFilename = [basename '_processed.set'];
        
        fprintf('Saving dataset %d: %s\n', i, newFilename);
        EEG = pop_saveset(EEG, 'filename', newFilename, 'filepath', outputDir);
        fprintf('Dataset %d saved successfully.\n', i);
    catch ME
        fprintf('Error saving dataset %d: %s\n', i, ME.message);
    end
end

fprintf('\nAll processed datasets have been saved to: %s\n', outputDir);
disp('Batch processing is complete!');
