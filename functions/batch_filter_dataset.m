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
    
    % Initialize filter count if needed
    if ~isfield(EEG, 'eyesort_filter_count')
        EEG.eyesort_filter_count = 0;
    end
    EEG.eyesort_filter_count = EEG.eyesort_filter_count + 1;
    currentFilterCount = EEG.eyesort_filter_count;
    
    % Call the filter_dataset function directly to avoid GUI
    % This function is internal to pop_filter_datasets.m but we're accessing it
    % Copy from pop_filter_datasets.m's subfunction:
    
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
            filterStr = sprintf('%02d', currentFilterCount);
            
            % Combine to create the 6-digit code
            newType = sprintf('%s%s%s', condStr, regionStr, filterStr);
            
            % Update the event type
            filteredEEG.event(i).type = newType;
            
            % Also store the filter information in a more accessible format
            filteredEEG.event(i).eyesort_condition_code = condStr;
            filteredEEG.event(i).eyesort_region_code = regionStr;
            filteredEEG.event(i).eyesort_filter_code = filterStr;
            filteredEEG.event(i).eyesort_full_code = newType;
            
            % Debug prints
            fprintf('Event %d passed all filters:\n', i);
            fprintf('  Condition code: %s\n', condStr);
            fprintf('  Region code: %s\n', regionStr);
            fprintf('  Filter code: %s\n', filterStr);
            fprintf('  New type code: %s\n', newType);
            fprintf('  Original event type: %s\n', evt.type);
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
    filterDesc.filter_code = sprintf('%02d', currentFilterCount);
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
    
    % Right before the "EEG = filteredEEG;" line:
    fprintf('Added filter description to dataset. Now has %d filter descriptions.\n', ...
        length(filteredEEG.eyesort_filter_descriptions));
    
    % Return the filtered dataset
    EEG = filteredEEG;
end 