function [EEG, com] = pop_filter_datasets(EEG)
    % Initialize output
    com = '';
    
    % If no EEG input, try to get it from base workspace
    if nargin < 1
        try
            EEG = evalin('base', 'EEG');
            fprintf('Retrieved EEG from EEGLAB base workspace.\n');
        catch ME
            error('Failed to retrieve EEG dataset from base workspace: %s', ME.message);
        end
    end
    
    % Validate input
    if isempty(EEG)
        error('pop_filter_datasets requires a non-empty EEG dataset');
    end
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        errordlg('EEG data does not contain any events.', 'Error');
        return;
    end
    if ~isfield(EEG.event(1), 'regionBoundaries')
        errordlg('EEG data is not properly processed with region information. Please process with the Text Interest Areas function first.', 'Error');
        return;
    end
    if ~isfield(EEG, 'eyesort_filter_count')
        % Initialize filter count to 0, so first filter will be 01
        EEG.eyesort_filter_count = 0;
    end
    
    % Get event type field names from EEG structure - these must exist
    if ~isfield(EEG, 'eyesort_field_names')
        errordlg('EEG data does not contain field name information. Please process with the Text Interest Areas function first.', 'Error');
        return;
    end
    
    fixationType = EEG.eyesort_field_names.fixationType;
    fixationXField = EEG.eyesort_field_names.fixationXField;
    saccadeType = EEG.eyesort_field_names.saccadeType;
    saccadeStartXField = EEG.eyesort_field_names.saccadeStartXField;
    saccadeEndXField = EEG.eyesort_field_names.saccadeEndXField;
    
    % Extract available filtering options from EEG events
    conditionSet = [];
    itemSet = [];
    regionNames = {};
    
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
    
    % Extract region names, maintaining user-specified order
    if isfield(EEG, 'region_names') && ~isempty(EEG.region_names)
        % If the dataset has explicitly defined region order, use it
        fprintf('Using region_names field from EEG structure for ordered regions\n');
        regionNames = EEG.region_names;
        if ischar(regionNames)
            regionNames = {regionNames}; % Convert to cell array if it's a string
        end
    else
        % Otherwise extract from events but preserve order of first appearance
        fprintf('No region_names field found, extracting from events and preserving order\n');
        seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
        if isfield(EEG.event, 'current_region')
            for ii = 1:length(EEG.event)
                if isfield(EEG.event(ii), 'current_region') && ~isempty(EEG.event(ii).current_region)
                    regionName = EEG.event(ii).current_region;
                    % Only add each region once, preserving order of first appearance
                    if ~isKey(seen, regionName)
                        seen(regionName) = true;
                        regionNames{end+1} = regionName;
                    end
                end
            end
        end
    end
    
    if isempty(regionNames)
        regionNames = {'No regions found'};
    end
    
    % Print regions in order for verification
    fprintf('\nRegions in order (as will be displayed in listbox):\n');
    for i = 1:length(regionNames)
        fprintf('%d. %s\n', i, regionNames{i});
    end
    
    % Create the figure for the GUI
    hFig = figure('Name','Filter EEG Dataset',...
                  'NumberTitle','off',...
                  'MenuBar','none',...
                  'ToolBar','none',...
                  'Color',[0.94 0.94 0.94], ...
                  'Resize', 'off');
    
    % Define the layout (geomhoriz) and UI controls (uilist)
    geomhoriz = { ...
        1, ...
        [2 1], ...
        [2 1], ...
        [2 1], ...
        [2 1], ...
        [2 1], ...
        [2 1], ...
        [2 1], ...
        1, ...
        [0.3 0.2 0.2 0.2] ...
    };
    
    uilist = { ...
        {'Style','text','String','Filter Dataset Options', 'FontWeight', 'bold'}, ...
        {'Style','text','String','Time-Locked Region (Select Primary Region):'}, ...
        {'Style','listbox','String', regionNames, 'Max', length(regionNames), 'Min', 0, 'tag','lstTimeLocked'}, ...
        {'Style','text','String','Pass Index:'}, ...
        {'Style','popupmenu','String',{'Any pass', 'First pass only', 'Not first pass'}, 'tag','popPassIndex'}, ...
        {'Style','text','String','Previous Region:'}, ...
        {'Style','popupmenu','String',['Any region', regionNames], 'tag','popPrevRegion'}, ...
        {'Style','text','String','Next Region:'}, ...
        {'Style','popupmenu','String',['Any region', regionNames], 'tag','popNextRegion'}, ...
        {'Style','text','String','Fixation Type:'}, ...
        {'Style','popupmenu','String',{'Any fixation', 'First in region', 'Single fixation', 'Multiple fixations'}, 'tag','popFixationType'}, ...
        {'Style','text','String','Saccade In Direction:'}, ...
        {'Style','popupmenu','String',{'Any direction', 'Forward only', 'Backward only', 'Both'}, 'tag','popSaccadeInDirection'}, ...
        {'Style','text','String','Saccade Out Direction:'}, ...
        {'Style','popupmenu','String',{'Any direction', 'Forward only', 'Backward only', 'Both'}, 'tag','popSaccadeOutDirection'}, ...
        {}, ...
        {}, ...
        {'Style', 'pushbutton', 'String', 'Cancel', 'callback', @(~,~) cancel_button}, ...
        {'Style', 'pushbutton', 'String', 'Apply Filter', 'callback', @(~,~) apply_filter}, ...
        {'Style', 'pushbutton', 'String', 'Finish', 'callback', @(~,~) finish_filtering} ...
    };
    
    % Create the GUI using supergui
    [~, ~, ~, ~] = supergui('fig', hFig, 'geomhoriz', geomhoriz, 'uilist', uilist, 'title', 'Filter Dataset');
    
    % *** Modification: Pause execution until user interaction is complete ***
    uiwait(hFig);  % This will pause the function until uiresume is called

    % Callback for the Cancel button
    function cancel_button(~,~)
        % Set the command to empty to indicate cancellation
        com = '';
        uiresume(gcf);  % Resume execution (release uiwait)
        close(gcf);
    end

    % Callback for the Finish button
    function finish_filtering(~,~)
        % Apply the current filter if any and then signal completion
        if isempty(get(findobj('tag','lstTimeLocked'), 'Value'))
            % If no regions selected, just finish without applying a filter
            com = sprintf('EEG = pop_filter_datasets(EEG); %% Filtering completed');
            uiresume(gcf);  % Resume execution (release uiwait)
            close(gcf);
        else
            % Apply the current filter and then finish
            apply_filter_internal(true);
        end
    end

    % Callback for the Apply Filter button
    function apply_filter(~,~)
        % Apply the filter but keep the GUI open for further filtering
        apply_filter_internal(false);
    end

    % Shared function to apply filters
    function apply_filter_internal(shouldClose)
        % Retrieve filter selections from the GUI
        selectedTimeLockedRegions = get(findobj('tag','lstTimeLocked'), 'Value');
        if iscell(selectedTimeLockedRegions)
            selectedTimeLockedRegions = cell2mat(selectedTimeLockedRegions);
        end
        
        passIndexOption = get(findobj('tag','popPassIndex'), 'Value');
        prevRegionOption = get(findobj('tag','popPrevRegion'), 'Value');
        nextRegionOption = get(findobj('tag','popNextRegion'), 'Value');
        fixationTypeOption = get(findobj('tag','popFixationType'), 'Value');
        saccadeInDirectionOption = get(findobj('tag','popSaccadeInDirection'), 'Value');
        saccadeOutDirectionOption = get(findobj('tag','popSaccadeOutDirection'), 'Value');
        
        % Check for valid region data
        if strcmp(regionNames{1}, 'No regions found')
            errordlg('Cannot apply filter: Missing region data in current EEG structure.', 'Error');
            return;
        end
        
        % Convert selections to actual values
        timeLockedRegionValues = cell(1, length(selectedTimeLockedRegions));
        for j = 1:length(selectedTimeLockedRegions)
            timeLockedRegionValues{j} = regionNames{selectedTimeLockedRegions(j)};
        end
        
        % Get previous/next region values (if any)
        prevRegion = '';
        if prevRegionOption > 1
            prevRegion = regionNames{prevRegionOption-1};
        end
        
        nextRegion = '';
        if nextRegionOption > 1
            nextRegion = regionNames{nextRegionOption-1};
        end
        
        % Increment filter count and update EEG
        EEG.eyesort_filter_count = EEG.eyesort_filter_count + 1;
        currentFilterCount = EEG.eyesort_filter_count;
        
        try
            filteredEEG = filter_dataset(EEG, conditionSet, itemSet, timeLockedRegionValues, ...
                                         passIndexOption, prevRegion, nextRegion, ...
                                         fixationTypeOption, saccadeInDirectionOption, saccadeOutDirectionOption, currentFilterCount, ...
                                         fixationType, fixationXField, saccadeType, ...
                                         saccadeStartXField, saccadeEndXField);
            filteredEEG.eyesort_filter_count = currentFilterCount;
            if ~isfield(filteredEEG, 'eyesort_filter_descriptions')
                filteredEEG.eyesort_filter_descriptions = {};
            end
            % Build filter description structure
            filterDesc = struct();
            filterDesc.filter_number = currentFilterCount;
            filterDesc.filter_code = sprintf('%02d', currentFilterCount);
            filterDesc.regions = timeLockedRegionValues;
            filterDesc.pass_type = get(findobj('tag','popPassIndex'), 'String');
            filterDesc.pass_value = passIndexOption;
            filterDesc.prev_region = prevRegion;
            filterDesc.next_region = nextRegion;
            filterDesc.fixation_type = get(findobj('tag','popFixationType'), 'String');
            filterDesc.fixation_value = fixationTypeOption;
            filterDesc.saccade_in_dir = get(findobj('tag','popSaccadeInDirection'), 'String');
            filterDesc.saccade_in_value = saccadeInDirectionOption;
            filterDesc.saccade_out_dir = get(findobj('tag','popSaccadeOutDirection'), 'String');
            filterDesc.saccade_out_value = saccadeOutDirectionOption;
            filterDesc.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            
            filteredEEG.eyesort_filter_descriptions{end+1} = filterDesc;
            EEG = filteredEEG;  % Update the EEG variable directly
            
            % Ensure we're not causing structure mismatches
            % (This is just a check, though the actual fix is in the batch script)
            if ~isequal(fieldnames(EEG), fieldnames(filteredEEG))
                fprintf('Warning: Field structure mismatch detected in filtered EEG. The batch script will handle this.\n');
            end
            
            assignin('base', 'EEG', filteredEEG);
            com = sprintf('EEG = pop_filter_datasets(EEG); %% Applied filter #%d', currentFilterCount);
            
            % Display a message box with filter results
            msgStr = sprintf(['Filter #%d applied successfully!\n\n',...
                              'Identified %d events matching your filter criteria.\n\n',...
                              'These events have been labeled with a 6-digit code: CCRRFF\n',...
                              'Where: CC = condition code, RR = region code, FF = filter code (%02d)\n\n',...
                              '%s'],...
                              currentFilterCount, filteredEEG.eyesort_last_filter_matched_count, currentFilterCount, ...
                              iif(shouldClose, 'Filtering complete!', 'You can now apply another filter or click Finish when done.'));
            
            hMsg = msgbox(msgStr, sprintf('Filter #%d Applied', currentFilterCount), 'help');
            hBtn = findobj(hMsg, 'Type', 'UIControl', 'Style', 'pushbutton');
            if ~isempty(hBtn)
                set(hBtn, 'FontWeight', 'bold', 'FontSize', 10);
            end
            
            % Wait for user to click OK instead of auto-closing
            waitfor(hMsg);
            
            if shouldClose
                uiresume(gcf);  % Resume execution to let uiwait finish
                close(gcf);
            else
                % Reset the time-locked region selection for the next filter
                % but keep other settings
                set(findobj('tag','lstTimeLocked'), 'Value', []);
            end
        catch ME
            errordlg(['Error applying filter: ' ME.message], 'Error');
        end
    end

    % Helper function to create an inline if statement (ternary operator)
    function result = iif(condition, trueVal, falseVal)
        if condition
            result = trueVal;
        else
            result = falseVal;
        end
    end
end

function filteredEEG = filter_dataset(EEG, conditions, items, timeLockedRegions, ...
                                     passIndexOption, prevRegion, nextRegion, ...
                                     fixationTypeOption, saccadeInDirectionOption, ...
                                     saccadeOutDirectionOption, filterCount, ...
                                     fixationType, fixationXField, saccadeType, ...
                                     saccadeStartXField, saccadeEndXField)
    % Create a copy of the EEG structure
    filteredEEG = EEG;
    
    % Create a tracking count for matched events (not for filtering, just for reporting)
    matchedEventCount = 0;
    
    % Ensure filter count is at least 1 for 1-indexed filter codes
    if filterCount < 1
        filterCount = 1;
    end
    
    % Pre-compute the filter code (always 2 digits, 01-99)
    filterCode = sprintf('%02d', filterCount);
    fprintf('Filter code for this batch: %s\n', filterCode);
    
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
        if ~startsWith(evt.type, fixationType)
            continue;
        end
        
        % Check if event passes all filtering conditions
        
        % Check for condition and item - these are pre-defined filters from previous GUI
        % We only include events that match the previously selected conditions and items
        passesCondition = true;
        if ~isempty(conditions) && isfield(evt, 'condition_number')
            passesCondition = any(evt.condition_number == conditions);
        end
                          
        passesItem = true;
        if ~isempty(items) && isfield(evt, 'item_number')
            passesItem = any(evt.item_number == items);
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
                if startsWith(EEG.event(jj).type, fixationType) && isfield(EEG.event(jj), 'current_region')
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
        
        % Saccade in direction filtering (looking at actual saccade before current fixation)
        passesSaccadeInDirection = true;
        if saccadeInDirectionOption > 1
            % Find the saccade that led to this fixation
            inSaccadeFound = false;
            for jj = i-1:-1:1
                if strcmp(EEG.event(jj).type, saccadeType)
                    inSaccadeFound = true;
                    % Calculate X-direction movement using saccade position data
                    xChange = EEG.event(jj).(saccadeEndXField) - EEG.event(jj).(saccadeStartXField);
                    isForward = xChange > 0;
                    
                    % Check against filter options
                    if saccadeInDirectionOption == 2 % Forward only
                        passesSaccadeInDirection = isForward && abs(xChange) > 10; % Threshold to ignore tiny movements
                    elseif saccadeInDirectionOption == 3 % Backward only
                        passesSaccadeInDirection = ~isForward && abs(xChange) > 10;
                    end
                    break;
                end
            end
            if ~inSaccadeFound && saccadeInDirectionOption < 4
                passesSaccadeInDirection = false;
            end
        end
        
        % Saccade out direction filtering (looking at actual saccade after current fixation)
        passesSaccadeOutDirection = true;
        if saccadeOutDirectionOption > 1
            % Find the saccade that followed this fixation
            outSaccadeFound = false;
            for jj = i+1:length(EEG.event)
                if strcmp(EEG.event(jj).type, saccadeType)
                    outSaccadeFound = true;
                    % Calculate X-direction movement using saccade position data
                    xChange = EEG.event(jj).(saccadeEndXField) - EEG.event(jj).(saccadeStartXField);
                    isForward = xChange > 0;
                    
                    % Check against filter options
                    if saccadeOutDirectionOption == 2 % Forward only
                        passesSaccadeOutDirection = isForward && abs(xChange) > 10;
                    elseif saccadeOutDirectionOption == 3 % Backward only
                        passesSaccadeOutDirection = ~isForward && abs(xChange) > 10;
                    end
                    break;
                end
            end
            if ~outSaccadeFound && saccadeOutDirectionOption < 4
                passesSaccadeOutDirection = false;
            end
        end
        
        % Check if the event passes all filters
        passes = passesPassIndex && passesPrevRegion && passesNextRegion && ...
                 passesFixationType && passesSaccadeInDirection && passesSaccadeOutDirection;
        
        % Add debug information for important events
        if isfield(evt, 'current_region') && any(strcmp(evt.current_region, timeLockedRegions))
            fprintf('\nDebug Info for Event %d (type: %s):\n', i, evt.type);
            fprintf('  Region: %s\n', evt.current_region);
            if isfield(evt, 'is_first_pass_region')
                fprintf('  First Pass: %s\n', mat2str(evt.is_first_pass_region));
            end
            if isfield(evt, 'total_fixations_in_region')
                fprintf('  Total Fixations in Region: %d\n', evt.total_fixations_in_region);
            end
            if isfield(evt, 'previous_region')
                fprintf('  Previous Region: %s\n', evt.previous_region);
            end
            
            % Find the next fixation and report it
            nextFixRegion = 'None';
            for jj = i+1:length(EEG.event)
                if startsWith(EEG.event(jj).type, fixationType) && isfield(EEG.event(jj), 'current_region')
                    nextFixRegion = EEG.event(jj).current_region;
                    fprintf('  Next Fixation: Event %d in region %s\n', jj, nextFixRegion);
                    break;
                end
            end
            
            % Report filter status
            fprintf('  Filter Results:\n');
            fprintf('    Passes Time-Locked Region: %s\n', mat2str(passesTimeLockedRegion));
            fprintf('    Passes Pass Index: %s\n', mat2str(passesPassIndex));
            fprintf('    Passes Previous Region: %s\n', mat2str(passesPrevRegion));
            fprintf('    Passes Next Region: %s\n', mat2str(passesNextRegion));
            fprintf('    Passes Fixation Type: %s\n', mat2str(passesFixationType));
            fprintf('    Passes Saccade In Direction: %s\n', mat2str(passesSaccadeInDirection));
            fprintf('    Passes Saccade Out Direction: %s\n', mat2str(passesSaccadeOutDirection));
            fprintf('    Overall Result: %s\n', mat2str(passes));
        end
        
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
            filterStr = filterCode;
            
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
    
    % Return the filtered dataset with all events intact
    return;
end 