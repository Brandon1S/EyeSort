function EEG = process_multiple_datasets(EEG, txtFilePath, offset, pxPerChar, ...
                                    numRegions, regionNames, ...
                                    conditionColName, itemColName, startCode, endCode, conditionTriggers, itemTriggers, ...
                                    applyFilter, filterParams)
% PROCESS_MULTIPLE_DATASETS - Process and optionally filter multiple datasets without triggering save dialogs
%
% Usage:
%   >> EEG = process_multiple_datasets(EEG, txtFilePath, offset, pxPerChar, ...
%                                    numRegions, regionNames, ...
%                                    conditionColName, itemColName, startCode, endCode, conditionTriggers, itemTriggers, ...
%                                    applyFilter, filterParams);
%
% Inputs:
%   EEG         - EEG dataset structure, or array of EEG structures.
%   txtFilePath - Path to the text file containing interest area definitions
%   offset      - Pixel offset for interest area calculations
%   pxPerChar   - Pixels per character for text display
%   numRegions  - Number of text regions
%   regionNames - Cell array of region names
%   conditionColName - Name of column containing condition codes
%   itemColName - Name of column containing item codes
%   startCode   - Event code marking trial start
%   endCode     - Event code marking trial end
%   conditionTriggers - Cell array of triggers that mark conditions
%   itemTriggers - Cell array of triggers that mark items
%   applyFilter - [0|1] Whether to apply filtering after processing (default: 0)
%   filterParams - Structure with filter parameters (optional):
%                  .timeLockedRegions - Cell array of region names to use as time-locked regions
%                  .passIndex - [1,2,3] 1=Any pass, 2=First pass only, 3=Not first pass
%                  .prevRegion - Previous region name (or '' for any)
%                  .nextRegion - Next region name (or '' for any)
%                  .fixationType - [1,2,3,4] 1=Any, 2=First in region, 3=Single fixation, 4=Multiple fixations
%                  .saccadeDirection - [1,2,3] 1=Any, 2=Forward only, 3=Backward only
%
% Outputs:
%   EEG  - Updated EEG structure(s) after processing and optional filtering.
%
% Note: This function processes multiple datasets without triggering save dialogs,
%       allowing batch processing of multiple datasets with the same parameters.
%

% Default: don't apply filter
if nargin < 13
    applyFilter = 0;
end

% Check if we have multiple datasets
if numel(EEG) < 1
    error('No datasets provided for processing');
end

% Show information about processing
fprintf('\n====== PROCESSING MULTIPLE DATASETS ======\n');
fprintf('Number of datasets to process: %d\n', numel(EEG));
fprintf('Text file path: %s\n', txtFilePath);
fprintf('Number of regions: %d\n', numRegions);
fprintf('Region names: %s\n', strjoin(regionNames, ', '));
fprintf('========================================\n\n');

% Process each dataset with region labeling
fprintf('Step 1: Processing datasets with text interest areas...\n');
EEG = new_combined_compute_text_based_ia(EEG, txtFilePath, offset, pxPerChar, ...
                                       numRegions, regionNames, ...
                                       conditionColName, itemColName, ...
                                       startCode, endCode, conditionTriggers, itemTriggers);

fprintf('\nText interest area processing complete for all datasets.\n');

% Apply filter if requested
if applyFilter
    fprintf('\nStep 2: Applying filters to datasets...\n');
    
    % Handle filter parameters if provided
    if nargin >= 14 && ~isempty(filterParams) && isstruct(filterParams)
        fprintf('Applying filters with provided parameters (non-interactive)...\n');
        
        % Process each dataset individually for filtering
        for idx = 1:numel(EEG)
            fprintf('Filtering dataset %d of %d...\n', idx, numel(EEG));
            currentEEG = EEG(idx);
            
            % Apply batch filtering function (non-interactive)
            currentEEG = batch_filter_dataset(currentEEG, filterParams);
            
            % Store back in the array
            EEG(idx) = currentEEG;
        end
        
        fprintf('Non-interactive filtering complete.\n');
    else
        % Use the standard filtering GUI (just once for all datasets)
        fprintf('Applying filters with the filter dialog...\n');
        EEG = pop_filter_datasets(EEG);
    end
    
    fprintf('\nFiltering complete for all datasets.\n');
end

fprintf('\nAll processing complete! Datasets are ready for further analysis.\n');
fprintf('Note: Changes have NOT been saved to disk. Use pop_saveset() to save if needed.\n\n');

end

% Helper function for non-interactive batch filtering
function EEG = batch_filter_dataset(EEG, params)
    % Extract parameters from the params structure
    if isfield(params, 'timeLockedRegions')
        timeLockedRegions = params.timeLockedRegions;
    else
        % Default to first available region
        allRegions = unique({EEG.event.current_region});
        timeLockedRegions = {allRegions{1}};
    end
    
    if isfield(params, 'passIndex')
        passIndexOption = params.passIndex;
    else
        passIndexOption = 1; % Any pass (default)
    end
    
    if isfield(params, 'prevRegion')
        prevRegion = params.prevRegion;
    else
        prevRegion = ''; % Any region (default)
    end
    
    if isfield(params, 'nextRegion')
        nextRegion = params.nextRegion;
    else
        nextRegion = ''; % Any region (default)
    end
    
    if isfield(params, 'fixationType')
        fixationTypeOption = params.fixationType;
    else
        fixationTypeOption = 1; % Any fixation (default)
    end
    
    if isfield(params, 'saccadeDirection')
        saccadeDirectionOption = params.saccadeDirection;
    else
        saccadeDirectionOption = 1; % Any direction (default)
    end
    
    % Initialize or use provided filter count
    currentFilterCount = 1;
    if isfield(params, 'filterCount')
        currentFilterCount = params.filterCount;
    elseif isfield(EEG, 'eyesort_filter_count')
        EEG.eyesort_filter_count = EEG.eyesort_filter_count + 1;
        currentFilterCount = EEG.eyesort_filter_count;
    else
        EEG.eyesort_filter_count = 1;
    end
    
    fprintf('Applying filter #%d with parameters:\n', currentFilterCount);
    fprintf('  - Time-locked regions: %s\n', strjoin(timeLockedRegions, ', '));
    fprintf('  - Pass index option: %d\n', passIndexOption);
    if ~isempty(prevRegion)
        fprintf('  - Previous region: %s\n', prevRegion);
    end
    if ~isempty(nextRegion)
        fprintf('  - Next region: %s\n', nextRegion);
    end
    fprintf('  - Fixation type: %d\n', fixationTypeOption);
    fprintf('  - Saccade direction: %d\n', saccadeDirectionOption);
    
    % Extract condition and item sets from EEG
    conditionSet = [];
    itemSet = [];
    
    % Extract condition numbers
    if isfield(EEG.event, 'condition_number')
        condVals = zeros(1, length(EEG.event));
        for ii = 1:length(EEG.event)
            if isfield(EEG.event(ii), 'condition_number') && ~isempty(EEG.event(ii).condition_number)
                condVals(ii) = EEG.event(ii).condition_number;
            else
                condVals(ii) = NaN;
            end
        end
        conditionSet = unique(condVals(~isnan(condVals) & condVals > 0));
    end
    
    % Extract item numbers
    if isfield(EEG.event, 'item_number')
        itemVals = zeros(1, length(EEG.event));
        for ii = 1:length(EEG.event)
            if isfield(EEG.event(ii), 'item_number') && ~isempty(EEG.event(ii).item_number)
                itemVals(ii) = EEG.event(ii).item_number;
            else
                itemVals(ii) = NaN;
            end
        end
        itemSet = unique(itemVals(~isnan(itemVals) & itemVals > 0));
    end
    
    % Create a copy of the EEG structure
    filteredEEG = EEG;
    
    % Create a tracking count for matched events (not for filtering, just for reporting)
    matchedEventCount = 0;
    
    % Create region code mapping - map region names to 2-digit codes
    regionCodeMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
    uniqueRegions = unique({EEG.event.current_region});
    
    % Define standard region order with fixed numbering
    standardRegions = {'Beginning', 'PreTarget', 'Target_word', 'Ending'};
    for ii = 1:length(standardRegions)
        regionCodeMap(standardRegions{ii}) = sprintf('%02d', ii);
    end
    
    % Add any additional regions that weren't in the standard list
    nextCode = length(standardRegions) + 1;
    for ii = 1:length(uniqueRegions)
        regionName = uniqueRegions{ii};
        if ~isempty(regionName) && ~isKey(regionCodeMap, regionName)
            regionCodeMap(regionName) = sprintf('%02d', nextCode);
            nextCode = nextCode + 1;
        end
    end
    
    % Print the region code mapping for verification
    fprintf('\n============ REGION CODE MAPPING ============\n');
    allRegions = keys(regionCodeMap);
    for ii = 1:length(allRegions)
        fprintf('  Region "%s" = Code %s\n', allRegions{ii}, regionCodeMap(allRegions{ii}));
    end
    fprintf('=============================================\n\n');
    
    % Apply filtering criteria
    for i = 1:length(EEG.event)
        evt = EEG.event(i);
        
        % Only process fixation events for potential code updates
        % Non-fixation events remain unchanged
        if ~startsWith(evt.type, 'R_fixation')
            continue;
        end
        
        % Check if event passes all filtering conditions
        
        % Check for condition and item
        passesCondition = true;
        if ~isempty(conditionSet) && isfield(evt, 'condition_number')
            passesCondition = any(evt.condition_number == conditionSet);
        end
                          
        passesItem = true;
        if ~isempty(itemSet) && isfield(evt, 'item_number')
            passesItem = any(evt.item_number == itemSet);
        end
        
        % Skip to next event if it doesn't match condition/item criteria
        if ~passesCondition || ~passesItem
            continue;
        end
        
        % Time-locked region filter (primary filter)
        passesTimeLockedRegion = true;
        if ~isempty(timeLockedRegions) && isfield(evt, 'current_region')
            passesTimeLockedRegion = any(strcmp(evt.current_region, timeLockedRegions));
        end
        
        % Skip to next event if it doesn't match time-locked region
        if ~passesTimeLockedRegion
            continue;
        end
        
        % Pass index filtering
        passesPassIndex = true;
        if passIndexOption > 1 && isfield(evt, 'is_first_pass_region')
            if passIndexOption == 2 % First pass only
                passesPassIndex = evt.is_first_pass_region;
            elseif passIndexOption == 3 % Not first pass
                passesPassIndex = ~evt.is_first_pass_region;
            end
        end
        
        % Previous region filtering
        passesPrevRegion = true;
        if ~isempty(prevRegion) && isfield(evt, 'previous_region')
            passesPrevRegion = strcmp(evt.previous_region, prevRegion);
        end
        
        % Next region filtering (requires looking ahead)
        passesNextRegion = true;
        if ~isempty(nextRegion)
            % Look ahead to find the next fixation event, not just the next event
            nextFixationFound = false;
            for jj = i+1:length(EEG.event)
                if startsWith(EEG.event(jj).type, 'R_fixation') && isfield(EEG.event(jj), 'current_region')
                    nextFixationFound = true;
                    passesNextRegion = strcmp(EEG.event(jj).current_region, nextRegion);
                    break; % Stop after finding the next fixation
                end
            end
            % If no next fixation was found, this can't pass the next region filter
            if ~nextFixationFound
                passesNextRegion = false;
            end
        end
        
        % Fixation type filtering
        passesFixationType = true;
        if fixationTypeOption > 1 && isfield(evt, 'total_fixations_in_region')
            if fixationTypeOption == 2 % First in region
                passesFixationType = evt.total_fixations_in_region == 1;
            elseif fixationTypeOption == 3 % Single fixation
                passesFixationType = evt.total_fixations_in_region == 1 && ...
                                    (~isfield(evt, 'total_fixations_in_word') || evt.total_fixations_in_word == 1);
            elseif fixationTypeOption == 4 % Multiple fixations
                passesFixationType = evt.total_fixations_in_region > 1;
            end
        end
        
        % Saccade direction filtering
        passesSaccadeDirection = true;
        if saccadeDirectionOption > 1 && isfield(evt, 'is_word_regression')
            if saccadeDirectionOption == 2 % Forward only
                passesSaccadeDirection = ~evt.is_word_regression;
            elseif saccadeDirectionOption == 3 % Backward only
                passesSaccadeDirection = evt.is_word_regression;
            end
        end
        
        % Check if the event passes all filters
        passes = passesPassIndex && passesPrevRegion && passesNextRegion && ...
                 passesFixationType && passesSaccadeDirection;
        
        % If the event passes all filters, update its type code
        if passes
            matchedEventCount = matchedEventCount + 1;
            
            % Generate the 6-digit event code:
            
            % 1. First 2 digits: Last two digits of the condition number
            condStr = '';
            if isfield(evt, 'condition_number') && ~isempty(evt.condition_number)
                condNum = evt.condition_number;
                % Extract last two digits (or pad with zeros if needed)
                condStr = sprintf('%02d', mod(condNum, 100));
            else
                condStr = '00'; % Default if no condition number
            end
            
            % 2. Middle 2 digits: Region code
            regionStr = '';
            if isfield(evt, 'current_region') && ~isempty(evt.current_region) && isKey(regionCodeMap, evt.current_region)
                regionStr = regionCodeMap(evt.current_region);
            else
                regionStr = '00'; % Default if no region
            end
            
            % 3. Last 2 digits: Filter code (using the current filter count)
            filterStr = '';
            % Force debug output of params to diagnose the issue
            fprintf('DEBUG: Checking for forceFilterCode parameter\n');
            if isfield(params, 'forceFilterCode')
                fprintf('DEBUG: Found forceFilterCode = %s\n', params.forceFilterCode);
                % Use the forced filter code (from batch processing)
                filterStr = params.forceFilterCode;
            else
                fprintf('DEBUG: forceFilterCode not found in params\n');
                % Use the current filter count
                filterStr = sprintf('%02d', currentFilterCount);
            end
            
            fprintf('Using filter code: %s for event %d\n', filterStr, i);
            
            % Combine to create the 6-digit code
            newType = sprintf('%s%s%s', condStr, regionStr, filterStr);
            
            % Update the event type
            filteredEEG.event(i).type = newType;
            
            % Also store the filter information in a more accessible format
            filteredEEG.event(i).eyesort_condition_code = condStr;
            filteredEEG.event(i).eyesort_region_code = regionStr;
            filteredEEG.event(i).eyesort_filter_code = filterStr;
            filteredEEG.event(i).eyesort_full_code = newType;
        end
    end
    
    % Store the number of matched events for reference
    filteredEEG.eyesort_last_filter_matched_count = matchedEventCount;
    
    % Store filter description info
    if ~isfield(filteredEEG, 'eyesort_filter_descriptions')
        filteredEEG.eyesort_filter_descriptions = {};
    end
    
    % Build a description of this filter
    filterDesc = struct();
    filterDesc.filter_number = currentFilterCount;
    
    % Use the forced filter code if provided
    if isfield(params, 'forceFilterCode') && ~isempty(params.forceFilterCode)
        filterDesc.filter_code = params.forceFilterCode;
    else
        filterDesc.filter_code = sprintf('%02d', currentFilterCount);
    end
    
    filterDesc.regions = timeLockedRegions;
    filterDesc.pass_value = passIndexOption;
    filterDesc.prev_region = prevRegion;
    filterDesc.next_region = nextRegion;
    filterDesc.fixation_value = fixationTypeOption;
    filterDesc.saccade_value = saccadeDirectionOption;
    filterDesc.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    % Append to the filter descriptions
    filteredEEG.eyesort_filter_descriptions{end+1} = filterDesc;
    
    % Print results
    fprintf('Filter #%d applied successfully!\n', currentFilterCount);
    fprintf('Identified %d events matching the filter criteria.\n', matchedEventCount);
    
    % Return the filtered dataset
    EEG = filteredEEG;
end 