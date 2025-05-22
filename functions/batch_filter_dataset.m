% Helper function for non-interactive batch filtering
function EEG = batch_filter_dataset(EEG, params)
    % Check and extract various parameters
    if ~isfield(params, 'timeLockedRegions')
        error('Required parameter timeLockedRegions missing from batch parameters');
    end
    
    timeLockedRegions = params.timeLockedRegions;
    
    % Handle pass_options (allow both old and new formats)
    if isfield(params, 'pass_options')
        pass_options = params.pass_options;
    elseif isfield(params, 'passIndices')
        % Convert old single value to array if needed
        if ~isempty(params.passIndices)
            pass_options = params.passIndices;
        else
            pass_options = 1; % Default to any pass
        end
    else
        pass_options = 1; % Default to any pass
    end
    
    % Handle prev_regions (allow both old and new formats)
    if isfield(params, 'prev_regions') && ~isempty(params.prev_regions)
        prevRegions = params.prev_regions;
    elseif isfield(params, 'prevRegion') && ~isempty(params.prevRegion)
        prevRegions = {params.prevRegion}; % Convert old single value to cell array
    else
        prevRegions = {}; % Default to no previous region filter
    end
    
    % Handle next_regions (allow both old and new formats)
    if isfield(params, 'next_regions') && ~isempty(params.next_regions)
        nextRegions = params.next_regions;
    elseif isfield(params, 'nextRegion') && ~isempty(params.nextRegion)
        nextRegions = {params.nextRegion}; % Convert old single value to cell array
    else
        nextRegions = {}; % Default to no next region filter
    end
    
    % Handle fixation_options (allow both old and new formats)
    if isfield(params, 'fixation_options')
        fixation_options = params.fixation_options;
    elseif isfield(params, 'fixationType')
        % Convert old single value to array if needed
        if ~isempty(params.fixationType)
            fixation_options = params.fixationType;
        else
            fixation_options = 1; % Default to any fixation
        end
    else
        fixation_options = 1; % Default to any fixation
    end
    
    % Handle saccade_in_options (allow both old and new formats)
    if isfield(params, 'saccade_in_options')
        saccade_in_options = params.saccade_in_options;
    elseif isfield(params, 'saccadeInDirection')
        % Convert old single value to array if needed
        if ~isempty(params.saccadeInDirection)
            saccade_in_options = params.saccadeInDirection;
        else
            saccade_in_options = 1; % Default to any direction
        end
    else
        saccade_in_options = 1; % Default to any direction
    end
    
    % Handle saccade_out_options (allow both old and new formats)
    if isfield(params, 'saccade_out_options')
        saccade_out_options = params.saccade_out_options;
    elseif isfield(params, 'saccadeOutDirection')
        % Convert old single value to array if needed
        if ~isempty(params.saccadeOutDirection)
            saccade_out_options = params.saccadeOutDirection;
        else
            saccade_out_options = 1; % Default to any direction
        end
    else
        saccade_out_options = 1; % Default to any direction
    end
    
    % Extract eyetracking field names from the EEG structure
    if ~isfield(EEG, 'eyesort_field_names')
        error('EEG structure is missing required eyesort_field_names. Please process the dataset first.');
    end
    
    fixationType = EEG.eyesort_field_names.fixationType;
    fixationXField = EEG.eyesort_field_names.fixationXField;
    saccadeType = EEG.eyesort_field_names.saccadeType;
    saccadeStartXField = EEG.eyesort_field_names.saccadeStartXField;
    saccadeEndXField = EEG.eyesort_field_names.saccadeEndXField;
    
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
    
    % Copy from pop_filter_datasets.m's subfunction with modifications for multiple options:
    
    % Create a copy of the EEG structure
    filteredEEG = EEG;
    
    % Create a tracking count for matched events (not for filtering, just for reporting)
    matchedEventCount = 0;
    
    % Create region code mapping - map region names to 2-digit codes
    regionCodeMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
    
    % Check if we have a field specifying region order in the EEG structure
    if isfield(EEG, 'region_names') && ~isempty(EEG.region_names)
        fprintf('\nUsing region_names field from EEG structure for ordered regions\n');
        orderedRegions = EEG.region_names;
        if ischar(orderedRegions)
            orderedRegions = {orderedRegions}; % Convert to cell array if it's a string
        end
        
        % Assign codes based on the user-defined order
        for ii = 1:length(orderedRegions)
            regionCodeMap(orderedRegions{ii}) = sprintf('%02d', ii);
            fprintf('  Region "%s" = Code %s (from region_names)\n', orderedRegions{ii}, sprintf('%02d', ii));
        end
    else
        % Fall back to the order regions appear in the events
        seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
        orderedRegions = {};
        
        % Get regions in order of first appearance
        uniqueRegions = unique({EEG.event.current_region});
        for ii = 1:length(EEG.event)
            if isfield(EEG.event(ii), 'current_region') && ~isempty(EEG.event(ii).current_region)
                regionName = EEG.event(ii).current_region;
                if ~isKey(seen, regionName)
                    seen(regionName) = true;
                    orderedRegions{end+1} = regionName;
                end
            end
        end
        
        % Assign codes based on the order of appearance
        for ii = 1:length(orderedRegions)
            regionCodeMap(orderedRegions{ii}) = sprintf('%02d', ii);
            fprintf('  Region "%s" = Code %s (from event order)\n', orderedRegions{ii}, sprintf('%02d', ii));
        end
    end
    
    % Add any remaining regions that weren't in the ordered list
    uniqueRegions = unique({EEG.event.current_region});
    nextCode = length(regionCodeMap) + 1;
    for ii = 1:length(uniqueRegions)
        regionName = uniqueRegions{ii};
        if ~isempty(regionName) && ~isKey(regionCodeMap, regionName)
            regionCodeMap(regionName) = sprintf('%02d', nextCode);
            fprintf('  Region "%s" = Code %s (added later)\n', regionName, sprintf('%02d', nextCode));
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
        if ~startsWith(evt.type, fixationType)
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
        
        % Pass index filtering - modified to handle multiple selection options
        passesPassIndex = false;
        
        % Handle the case where pass_options is a single value (backward compatibility)
        if isscalar(pass_options)
            if pass_options == 1 % Any pass
                passesPassIndex = true;
            elseif pass_options == 2 && isfield(evt, 'region_pass_number') % First pass only
                passesPassIndex = evt.region_pass_number == 1;
            elseif pass_options == 3 && isfield(evt, 'region_pass_number') % Second pass only
                passesPassIndex = evt.region_pass_number == 2;
            elseif pass_options == 4 && isfield(evt, 'region_pass_number') % Third pass and beyond
                passesPassIndex = evt.region_pass_number >= 3;
            else
                passesPassIndex = true; % Default to true if no valid option or field
            end
        else
            % Handle the case where pass_options is an array of multiple options
            if isempty(pass_options) || any(pass_options == 1) % Any pass included
                passesPassIndex = true;
            else
                % Check each option
                for opt = pass_options
                    if opt == 2 && isfield(evt, 'region_pass_number') && evt.region_pass_number == 1
                        passesPassIndex = true;
                        break;
                    elseif opt == 3 && isfield(evt, 'region_pass_number') && evt.region_pass_number == 2
                        passesPassIndex = true;
                        break;
                    elseif opt == 4 && isfield(evt, 'region_pass_number') && evt.region_pass_number >= 3
                        passesPassIndex = true;
                        break;
                    end
                end
            end
        end
        
        % Previous region filtering
        passesPrevRegion = true;
        if ~isempty(prevRegions)
            passesPrevRegion = any(strcmp(evt.last_region_visited, prevRegions));
        end
        
        % Next region filtering (requires looking ahead)
        passesNextRegion = true;
        if ~isempty(nextRegions)
            % Look ahead to find the next fixation event in a different region
            nextDifferentRegionFound = false;
            currentRegion = evt.current_region;
            
            for jj = i+1:length(EEG.event)
                if startsWith(EEG.event(jj).type, fixationType) && isfield(EEG.event(jj), 'current_region')
                    % Only consider fixations in a different region than the current one
                    if ~strcmp(EEG.event(jj).current_region, currentRegion)
                        nextDifferentRegionFound = true;
                        passesNextRegion = any(strcmp(EEG.event(jj).current_region, nextRegions));
                        break; % Stop after finding the next fixation in a different region
                    end
                end
            end
            
            % If no next fixation in a different region was found, this can't pass the next region filter
            if ~nextDifferentRegionFound
                passesNextRegion = false;
            end
        end
        
        % Fixation type filtering - modified to handle multiple selection options
        passesFixationType = false;
        
        % Handle the case where fixation_options is a single value (backward compatibility)
        if isscalar(fixation_options)
            if fixation_options == 1 % Any fixation
                passesFixationType = true;
            elseif fixation_options == 2 && isfield(evt, 'fixation_in_pass') % First in region
                passesFixationType = evt.fixation_in_pass == 1;
            elseif fixation_options == 3 && isfield(evt, 'fixation_in_pass') % Single fixation
                % Single fixation means it's both first and last in pass
                passesFixationType = evt.fixation_in_pass == 1 && ...
                    ~any([EEG.event.trial_number] == evt.trial_number & ...
                         strcmp({EEG.event.current_region}, evt.current_region) & ...
                         [EEG.event.region_pass_number] == evt.region_pass_number & ...
                         [EEG.event.fixation_in_pass] > 1);
            elseif fixation_options == 4 && isfield(evt, 'fixation_in_pass') % Second of multiple
                passesFixationType = evt.fixation_in_pass == 2;
            elseif fixation_options == 5 && isfield(evt, 'fixation_in_pass') % All subsequent fixations
                passesFixationType = evt.fixation_in_pass > 2;
            elseif fixation_options == 6 && isfield(evt, 'fixation_in_pass') % Last in region
                % Find all fixations in this region, trial, and pass
                sameRegionFixations = find([EEG.event.trial_number] == evt.trial_number & ...
                                           strcmp({EEG.event.current_region}, evt.current_region) & ...
                                           [EEG.event.region_pass_number] == evt.region_pass_number);
                % It's the last fixation if it has the highest fixation_in_pass value
                if ~isempty(sameRegionFixations)
                    maxFixInPass = max([EEG.event(sameRegionFixations).fixation_in_pass]);
                    passesFixationType = evt.fixation_in_pass == maxFixInPass;
                end
            else
                passesFixationType = true; % Default to true if no valid option or field
            end
        else
            % Handle the case where fixation_options is an array of multiple options
            if isempty(fixation_options) || any(fixation_options == 1) % Any fixation included
                passesFixationType = true;
            else
                % Check each option
                for opt = fixation_options
                    if opt == 2 && isfield(evt, 'fixation_in_pass') && evt.fixation_in_pass == 1
                        passesFixationType = true;
                        break;
                    elseif opt == 3 && isfield(evt, 'fixation_in_pass') && ...
                           evt.fixation_in_pass == 1 && ...
                           ~any([EEG.event.trial_number] == evt.trial_number & ...
                                strcmp({EEG.event.current_region}, evt.current_region) & ...
                                [EEG.event.region_pass_number] == evt.region_pass_number & ...
                                [EEG.event.fixation_in_pass] > 1)
                        passesFixationType = true;
                        break;
                    elseif opt == 4 && isfield(evt, 'fixation_in_pass') && evt.fixation_in_pass == 2
                        passesFixationType = true;
                        break;
                    elseif opt == 5 && isfield(evt, 'fixation_in_pass') && evt.fixation_in_pass > 2
                        passesFixationType = true;
                        break;
                    elseif opt == 6 && isfield(evt, 'fixation_in_pass')
                        % Find all fixations in this region, trial, and pass
                        sameRegionFixations = find([EEG.event.trial_number] == evt.trial_number & ...
                                                   strcmp({EEG.event.current_region}, evt.current_region) & ...
                                                   [EEG.event.region_pass_number] == evt.region_pass_number);
                        % It's the last fixation if it has the highest fixation_in_pass value
                        if ~isempty(sameRegionFixations)
                            maxFixInPass = max([EEG.event(sameRegionFixations).fixation_in_pass]);
                            if evt.fixation_in_pass == maxFixInPass
                                passesFixationType = true;
                                break;
                            end
                        end
                    end
                end
            end
        end
        
        % Saccade in direction filtering - modified to handle multiple selection options
        passesSaccadeInDirection = false;
        
        % Handle the case where saccade_in_options is a single value (backward compatibility)
        if isscalar(saccade_in_options)
            if saccade_in_options == 1 % Any direction
                passesSaccadeInDirection = true;
            else
                % Find the saccade that led to this fixation
                inSaccadeFound = false;
                for jj = i-1:-1:1
                    if strcmp(EEG.event(jj).type, saccadeType)
                        inSaccadeFound = true;
                        % Calculate X-direction movement using saccade position data
                        xChange = EEG.event(jj).(saccadeEndXField) - EEG.event(jj).(saccadeStartXField);
                        isForward = xChange > 0;
                        
                        % Check against filter options
                        if saccade_in_options == 2 % Forward only
                            passesSaccadeInDirection = isForward && abs(xChange) > 10; % Threshold to ignore tiny movements
                        elseif saccade_in_options == 3 % Backward only
                            passesSaccadeInDirection = ~isForward && abs(xChange) > 10;
                        elseif saccade_in_options == 4 % Both
                            passesSaccadeInDirection = abs(xChange) > 10;
                        end
                        break;
                    end
                end
                if ~inSaccadeFound && saccade_in_options < 4
                    passesSaccadeInDirection = false;
                end
            end
        else
            % Handle the case where saccade_in_options is an array of multiple options
            if isempty(saccade_in_options) || any(saccade_in_options == 1) % Any direction included
                passesSaccadeInDirection = true;
            else
                % Find the saccade that led to this fixation
                inSaccadeFound = false;
                xChange = 0;
                isForward = false;
                
                for jj = i-1:-1:1
                    if strcmp(EEG.event(jj).type, saccadeType)
                        inSaccadeFound = true;
                        % Calculate X-direction movement using saccade position data
                        xChange = EEG.event(jj).(saccadeEndXField) - EEG.event(jj).(saccadeStartXField);
                        isForward = xChange > 0;
                        break;
                    end
                end
                
                if inSaccadeFound && abs(xChange) > 10
                    % Check each option
                    for opt = saccade_in_options
                        if opt == 2 && isForward % Forward only
                            passesSaccadeInDirection = true;
                            break;
                        elseif opt == 3 && ~isForward % Backward only
                            passesSaccadeInDirection = true;
                            break;
                        elseif opt == 4 % Both
                            passesSaccadeInDirection = true;
                            break;
                        end
                    end
                end
            end
        end
        
        % Saccade out direction filtering - modified to handle multiple selection options
        passesSaccadeOutDirection = false;
        
        % Handle the case where saccade_out_options is a single value (backward compatibility)
        if isscalar(saccade_out_options)
            if saccade_out_options == 1 % Any direction
                passesSaccadeOutDirection = true;
            else
                % Look ahead to find the next saccade event
                outSaccadeFound = false;
                for jj = i+1:length(EEG.event)
                    if strcmp(EEG.event(jj).type, saccadeType)
                        outSaccadeFound = true;
                        % Calculate X-direction movement using saccade position data
                        xChange = EEG.event(jj).(saccadeEndXField) - EEG.event(jj).(saccadeStartXField);
                        isForward = xChange > 0;
                        
                        % Check against filter options
                        if saccade_out_options == 2 % Forward only
                            passesSaccadeOutDirection = isForward && abs(xChange) > 10;
                        elseif saccade_out_options == 3 % Backward only
                            passesSaccadeOutDirection = ~isForward && abs(xChange) > 10;
                        elseif saccade_out_options == 4 % Both
                            passesSaccadeOutDirection = abs(xChange) > 10;
                        end
                        break;
                    end
                end
                % If no next saccade was found and we're filtering for specific direction
                if ~outSaccadeFound && saccade_out_options > 1 && saccade_out_options < 4
                    passesSaccadeOutDirection = false;
                end
            end
        else
            % Handle the case where saccade_out_options is an array of multiple options
            if isempty(saccade_out_options) || any(saccade_out_options == 1) % Any direction included
                passesSaccadeOutDirection = true;
            else
                % Look ahead to find the next saccade event
                outSaccadeFound = false;
                xChange = 0;
                isForward = false;
                
                for jj = i+1:length(EEG.event)
                    if strcmp(EEG.event(jj).type, saccadeType)
                        outSaccadeFound = true;
                        % Calculate X-direction movement using saccade position data
                        xChange = EEG.event(jj).(saccadeEndXField) - EEG.event(jj).(saccadeStartXField);
                        isForward = xChange > 0;
                        break;
                    end
                end
                
                if outSaccadeFound && abs(xChange) > 10
                    % Check each option
                    for opt = saccade_out_options
                        if opt == 2 && isForward % Forward only
                            passesSaccadeOutDirection = true;
                            break;
                        elseif opt == 3 && ~isForward % Backward only
                            passesSaccadeOutDirection = true;
                            break;
                        elseif opt == 4 % Both
                            passesSaccadeOutDirection = true;
                            break;
                        end
                    end
                end
            end
        end
        
        % Check if the event passes all filters
        passes = passesPassIndex && passesPrevRegion && passesNextRegion && ...
                 passesFixationType && passesSaccadeInDirection && passesSaccadeOutDirection;
        
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
            fprintf('  Passes Saccade In Direction: %s\n', mat2str(passesSaccadeInDirection));
            fprintf('  Passes Saccade Out Direction: %s\n', mat2str(passesSaccadeOutDirection));
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
    filterDesc.pass_options = pass_options;
    filterDesc.prev_regions = prevRegions;
    filterDesc.next_regions = nextRegions;
    filterDesc.fixation_options = fixation_options;
    filterDesc.saccade_in_options = saccade_in_options;
    filterDesc.saccade_out_options = saccade_out_options;
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