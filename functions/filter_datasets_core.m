function [filteredEEG, com] = filter_datasets_core(EEG, varargin)
% FILTER_DATASETS_CORE - Core filtering function for EEG datasets
%
% Usage:
%   [filteredEEG, com] = filter_datasets_core(EEG, 'param', value, ...)
%
% Required Input:
%   EEG - EEGLAB dataset structure
%
% Optional Parameters (name-value pairs):
%   'timeLockedRegions'    - Cell array of region names to filter on
%   'passOptions'          - Array of pass type options (1=any, 2=first, 3=second, 4=third+)
%   'prevRegions'          - Cell array of previous region names
%   'nextRegions'          - Cell array of next region names  
%   'fixationOptions'      - Array of fixation type options (1=any, 2=first, 3=single, 4=second, 5=subsequent, 6=last)
%   'saccadeInOptions'     - Array of saccade in direction options (1=any, 2=forward, 3=backward)
%   'saccadeOutOptions'    - Array of saccade out direction options (1=any, 2=forward, 3=backward)
%   'conditions'           - Array of condition numbers to include
%   'items'                - Array of item numbers to include
%   'filterCount'          - Filter number (auto-incremented if not provided)
%
% Outputs:
%   filteredEEG - Filtered EEG dataset
%   com         - Command string for EEGLAB history

% Initialize output
com = '';

% Parse input arguments
p = inputParser;
addRequired(p, 'EEG', @isstruct);
addParameter(p, 'timeLockedRegions', {}, @iscell);
addParameter(p, 'passOptions', 1, @isnumeric);
addParameter(p, 'prevRegions', {}, @iscell);
addParameter(p, 'nextRegions', {}, @iscell);
addParameter(p, 'fixationOptions', 1, @isnumeric);
addParameter(p, 'saccadeInOptions', 1, @isnumeric);
addParameter(p, 'saccadeOutOptions', 1, @isnumeric);
addParameter(p, 'conditions', [], @isnumeric);
addParameter(p, 'items', [], @isnumeric);
addParameter(p, 'filterCount', [], @isnumeric);

parse(p, EEG, varargin{:});

% Extract parsed parameters
timeLockedRegions = p.Results.timeLockedRegions;
passOptions = p.Results.passOptions;
prevRegions = p.Results.prevRegions;
nextRegions = p.Results.nextRegions;
fixationOptions = p.Results.fixationOptions;
saccadeInOptions = p.Results.saccadeInOptions;
saccadeOutOptions = p.Results.saccadeOutOptions;
conditions = p.Results.conditions;
items = p.Results.items;
filterCount = p.Results.filterCount;

% Validate input EEG structure
if isempty(EEG)
    error('filter_datasets_core requires a non-empty EEG dataset');
end
if ~isfield(EEG, 'event') || isempty(EEG.event)
    error('EEG data does not contain any events.');
end
if ~isfield(EEG.event(1), 'regionBoundaries')
    error('EEG data is not properly processed with region information. Please process with the Text Interest Areas function first.');
end
if ~isfield(EEG, 'eyesort_field_names')
    error('EEG data does not contain field name information. Please process with the Text Interest Areas function first.');
end

% Initialize filter count if not provided
if ~isfield(EEG, 'eyesort_filter_count')
    EEG.eyesort_filter_count = 0;
end

if isempty(filterCount)
    EEG.eyesort_filter_count = EEG.eyesort_filter_count + 1;
    filterCount = EEG.eyesort_filter_count;
end

% Get event type field names from EEG structure
fixationType = EEG.eyesort_field_names.fixationType;
fixationXField = EEG.eyesort_field_names.fixationXField;
saccadeType = EEG.eyesort_field_names.saccadeType;
saccadeStartXField = EEG.eyesort_field_names.saccadeStartXField;
saccadeEndXField = EEG.eyesort_field_names.saccadeEndXField;

% Extract conditions and items if not provided
if isempty(conditions) && isfield(EEG.event, 'condition_number')
    condVals = zeros(1, length(EEG.event));
    for kk = 1:length(EEG.event)
        if isfield(EEG.event(kk), 'condition_number') && ~isempty(EEG.event(kk).condition_number)
            condVals(kk) = EEG.event(kk).condition_number;
        else
            condVals(kk) = NaN;
        end
    end
    conditions = unique(condVals(~isnan(condVals) & condVals > 0));
end

if isempty(items) && isfield(EEG.event, 'item_number')
    itemVals = zeros(1, length(EEG.event));
    for kk = 1:length(EEG.event)
        if isfield(EEG.event(kk), 'item_number') && ~isempty(EEG.event(kk).item_number)
            itemVals(kk) = EEG.event(kk).item_number;
        else
            itemVals(kk) = NaN;
        end
    end
    items = unique(itemVals(~isnan(itemVals) & itemVals > 0));
end

% Validate that at least one time-locked region is specified
if isempty(timeLockedRegions)
    error('At least one time-locked region must be specified for filtering');
end

% Ensure timeLockedRegions is a cell array
if ischar(timeLockedRegions)
    timeLockedRegions = {timeLockedRegions};
elseif ~iscell(timeLockedRegions)
    error('timeLockedRegions must be a cell array of strings or a single string');
end

% Apply the filtering
try
    filteredEEG = filter_dataset_internal(EEG, conditions, items, timeLockedRegions, ...
                                         passOptions, prevRegions, nextRegions, ...
                                         fixationOptions, saccadeInOptions, saccadeOutOptions, filterCount, ...
                                         fixationType, fixationXField, saccadeType, ...
                                         saccadeStartXField, saccadeEndXField);
    
    % Update filter count and descriptions
    filteredEEG.eyesort_filter_count = filterCount;
    if ~isfield(filteredEEG, 'eyesort_filter_descriptions')
        filteredEEG.eyesort_filter_descriptions = {};
    end
    
    % Build filter description structure
    filterDesc = struct();
    filterDesc.filter_number = filterCount;
    filterDesc.filter_code = sprintf('%02d', filterCount);
    filterDesc.regions = timeLockedRegions;
    filterDesc.pass_options = passOptions;
    filterDesc.prev_regions = prevRegions;
    filterDesc.next_regions = nextRegions;
    filterDesc.fixation_options = fixationOptions;
    filterDesc.saccade_in_options = saccadeInOptions;
    filterDesc.saccade_out_options = saccadeOutOptions;
    filterDesc.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    
    filteredEEG.eyesort_filter_descriptions{end+1} = filterDesc;
    
    % Generate command string
    if iscell(timeLockedRegions)
        % Create cell array string representation manually for compatibility
        if length(timeLockedRegions) == 1
            regionStr = sprintf('{''%s''}', timeLockedRegions{1});
        else
            regionStr = sprintf('{''%s''}', strjoin(timeLockedRegions, ''', '''));
        end
    else
        regionStr = mat2str(timeLockedRegions);
    end
    com = sprintf('EEG = filter_datasets_core(EEG, ''timeLockedRegions'', %s, ''filterCount'', %d);', ...
                  regionStr, filterCount);
    
catch ME
    % Provide more detailed error information
    if contains(ME.message, 'mat2str') || contains(ME.message, 'Input matrix must be')
        error('Error in command string generation. This may be due to incompatible data types in filter parameters. Original error: %s', ME.message);
    else
        error('Error applying filter: %s', ME.message);
    end
end

end

function filteredEEG = filter_dataset_internal(EEG, conditions, items, timeLockedRegions, ...
                                              passOptions, prevRegions, nextRegions, ...
                                              fixationOptions, saccadeInOptions, ...
                                              saccadeOutOptions, filterCount, ...
                                              fixationType, fixationXField, saccadeType, ...
                                              saccadeStartXField, saccadeEndXField)
    % Internal filtering implementation
    
    % Create a copy of the EEG structure
    filteredEEG = EEG;
    
    % Create a tracking count for matched events
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
    
    % Get the unique region names from the EEG events
    if isfield(EEG, 'region_names') && ~isempty(EEG.region_names)
        regionList = EEG.region_names;
        if ischar(regionList)
            regionList = {regionList};
        end
    else
        % Extract region names safely, handling empty/missing fields
        regionNames = {};
        for i = 1:length(EEG.event)
            if isfield(EEG.event(i), 'current_region') && ~isempty(EEG.event(i).current_region) && ischar(EEG.event(i).current_region)
                regionNames{end+1} = EEG.event(i).current_region;
            end
        end
        regionList = unique(regionNames);
    end
    
    % Map each region to a 2-digit code
    for kk = 1:length(regionList)
        if ~isempty(regionList{kk}) && ischar(regionList{kk})
            regionCodeMap(regionList{kk}) = sprintf('%02d', kk);
        end
    end
    
    % Print the region code mapping for verification
    fprintf('\n============ REGION CODE MAPPING ============\n');
    if ~isempty(regionCodeMap) && regionCodeMap.Count > 0
        for kk = 1:length(regionList)
            if ~isempty(regionList{kk}) && ischar(regionList{kk}) && isKey(regionCodeMap, regionList{kk})
                fprintf('  Region "%s" = Code %s\n', regionList{kk}, regionCodeMap(regionList{kk}));
            end
        end
    else
        fprintf('  No regions found to map\n');
    end
    fprintf('=============================================\n\n');
    
    % Track events with conflicting codes
    conflictingEvents = {};
    
    % Apply filtering criteria
    for mm = 1:length(EEG.event)
        evt = EEG.event(mm);
        
        % Check if this is a fixation event or a previously coded fixation event
        isFixation = false;
        
        if ischar(evt.type) && startsWith(evt.type, fixationType)
            isFixation = true;
        elseif isfield(evt, 'original_type') && ischar(evt.original_type) && startsWith(evt.original_type, fixationType)
            isFixation = true;
        elseif ischar(evt.type) && length(evt.type) == 6 && isfield(evt, 'eyesort_full_code')
            isFixation = true;
        end
        
        if ~isFixation
            continue;
        end
        
        % Check for condition and item filters
        passesCondition = true;
        if ~isempty(conditions) && isfield(evt, 'condition_number')
            passesCondition = any(evt.condition_number == conditions);
        end
                          
        passesItem = true;
        if ~isempty(items) && isfield(evt, 'item_number')
            passesItem = any(evt.item_number == items);
        end
        
        if ~passesCondition || ~passesItem
            continue;
        end
        
        % Time-locked region filter
        passesTimeLockedRegion = true;
        if ~isempty(timeLockedRegions) && isfield(evt, 'current_region')
            passesTimeLockedRegion = any(strcmp(evt.current_region, timeLockedRegions));
        end
        
        if ~passesTimeLockedRegion
            continue;
        end
        
        % Pass index filtering
        passesPassIndex = false;
        if isscalar(passOptions)
            if passOptions == 1
                passesPassIndex = true;
            elseif passOptions == 2 && isfield(evt, 'is_first_pass_region')
                passesPassIndex = evt.is_first_pass_region;
            elseif passOptions == 3 && isfield(evt, 'is_first_pass_region')
                passesPassIndex = ~evt.is_first_pass_region;
            else
                passesPassIndex = true;
            end
        else
            if isempty(passOptions) || any(passOptions == 1)
                passesPassIndex = true;
            else
                for opt = passOptions
                    if opt == 2 && isfield(evt, 'is_first_pass_region') && evt.is_first_pass_region
                        passesPassIndex = true;
                        break;
                    elseif opt == 3 && isfield(evt, 'is_first_pass_region') && ~evt.is_first_pass_region
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
        
        % Next region filtering
        passesNextRegion = true;
        if ~isempty(nextRegions)
            nextDifferentRegionFound = false;
            currentRegion = evt.current_region;
            
            for jj = mm+1:length(EEG.event)
                nextEvt = EEG.event(jj);
                isNextFixation = false;
                
                if ischar(nextEvt.type) && startsWith(nextEvt.type, fixationType)
                    isNextFixation = true;
                elseif isfield(nextEvt, 'original_type') && ischar(nextEvt.original_type) && startsWith(nextEvt.original_type, fixationType)
                    isNextFixation = true;
                elseif ischar(nextEvt.type) && length(nextEvt.type) == 6 && isfield(nextEvt, 'eyesort_full_code')
                    isNextFixation = true;
                end
                
                if isNextFixation && isfield(nextEvt, 'current_region')
                    if ~strcmp(nextEvt.current_region, currentRegion)
                        nextDifferentRegionFound = true;
                        passesNextRegion = any(strcmp(nextEvt.current_region, nextRegions));
                        break;
                    end
                end
            end
            if ~nextDifferentRegionFound
                passesNextRegion = false;
            end
        end
        
        % Fixation type filtering
        passesFixationType = false;
        if isscalar(fixationOptions)
            if fixationOptions == 1
                passesFixationType = true;
            elseif fixationOptions == 2 && isfield(evt, 'total_fixations_in_region')
                passesFixationType = evt.total_fixations_in_region == 1;
            elseif fixationOptions == 3 && isfield(evt, 'total_fixations_in_region')
                passesFixationType = evt.total_fixations_in_region == 1 && ...
                                    (~isfield(evt, 'total_fixations_in_word') || evt.total_fixations_in_word == 1);
            elseif fixationOptions == 4 && isfield(evt, 'total_fixations_in_region')
                passesFixationType = evt.total_fixations_in_region > 1;
            elseif fixationOptions == 5 && isfield(evt, 'total_fixations_in_region')
                passesFixationType = evt.total_fixations_in_region == 1 && ...
                                    (~isfield(evt, 'total_fixations_in_word') || evt.total_fixations_in_word == 1);
            else
                passesFixationType = true;
            end
        else
            if isempty(fixationOptions) || any(fixationOptions == 1)
                passesFixationType = true;
            else
                for opt = fixationOptions
                    if opt == 2 && isfield(evt, 'total_fixations_in_region') && evt.total_fixations_in_region == 1
                        passesFixationType = true;
                        break;
                    elseif opt == 3 && isfield(evt, 'total_fixations_in_region') && evt.total_fixations_in_region == 1 && ...
                            (~isfield(evt, 'total_fixations_in_word') || evt.total_fixations_in_word == 1)
                        passesFixationType = true;
                        break;
                    elseif opt == 4 && isfield(evt, 'total_fixations_in_region') && evt.total_fixations_in_region > 1
                        passesFixationType = true;
                        break;
                    elseif opt == 5 && isfield(evt, 'total_fixations_in_region') && evt.total_fixations_in_region == 1 && ...
                            (~isfield(evt, 'total_fixations_in_word') || evt.total_fixations_in_word == 1)
                        passesFixationType = true;
                        break;
                    end
                end
            end
        end
        
        % Saccade in direction filtering
        passesSaccadeInDirection = false;
        if isscalar(saccadeInOptions)
            if saccadeInOptions == 1
                passesSaccadeInDirection = true;
            else
                inSaccadeFound = false;
                for jj = mm-1:-1:1
                    if strcmp(EEG.event(jj).type, saccadeType)
                        inSaccadeFound = true;
                        xChange = EEG.event(jj).(saccadeEndXField) - EEG.event(jj).(saccadeStartXField);
                        isForward = xChange > 0;
                        
                        if saccadeInOptions == 2
                            passesSaccadeInDirection = isForward && abs(xChange) > 10;
                        elseif saccadeInOptions == 3
                            passesSaccadeInDirection = ~isForward && abs(xChange) > 10;
                        elseif saccadeInOptions == 4
                            passesSaccadeInDirection = abs(xChange) > 10;
                        end
                        break;
                    end
                end
                if ~inSaccadeFound && saccadeInOptions < 4
                    passesSaccadeInDirection = false;
                end
            end
        else
            if isempty(saccadeInOptions) || any(saccadeInOptions == 1)
                passesSaccadeInDirection = true;
            else
                inSaccadeFound = false;
                xChange = 0;
                isForward = false;
                
                for jj = mm-1:-1:1
                    if strcmp(EEG.event(jj).type, saccadeType)
                        inSaccadeFound = true;
                        xChange = EEG.event(jj).(saccadeEndXField) - EEG.event(jj).(saccadeStartXField);
                        isForward = xChange > 0;
                        break;
                    end
                end
                
                if inSaccadeFound && abs(xChange) > 10
                    for opt = saccadeInOptions
                        if opt == 2 && isForward
                            passesSaccadeInDirection = true;
                            break;
                        elseif opt == 3 && ~isForward
                            passesSaccadeInDirection = true;
                            break;
                        elseif opt == 4
                            passesSaccadeInDirection = true;
                            break;
                        end
                    end
                end
            end
        end
        
        % Saccade out direction filtering
        passesSaccadeOutDirection = false;
        if isscalar(saccadeOutOptions)
            if saccadeOutOptions == 1
                passesSaccadeOutDirection = true;
            else
                outSaccadeFound = false;
                for jj = mm+1:length(EEG.event)
                    if strcmp(EEG.event(jj).type, saccadeType)
                        outSaccadeFound = true;
                        xChange = EEG.event(jj).(saccadeEndXField) - EEG.event(jj).(saccadeStartXField);
                        isForward = xChange > 0;
                        
                        if saccadeOutOptions == 2
                            passesSaccadeOutDirection = isForward && abs(xChange) > 10;
                        elseif saccadeOutOptions == 3
                            passesSaccadeOutDirection = ~isForward && abs(xChange) > 10;
                        elseif saccadeOutOptions == 4
                            passesSaccadeOutDirection = abs(xChange) > 10;
                        end
                        break;
                    end
                end
                if ~outSaccadeFound && saccadeOutOptions > 1 && saccadeOutOptions < 4
                    passesSaccadeOutDirection = false;
                end
            end
        else
            if isempty(saccadeOutOptions) || any(saccadeOutOptions == 1)
                passesSaccadeOutDirection = true;
            else
                outSaccadeFound = false;
                xChange = 0;
                isForward = false;
                
                for jj = mm+1:length(EEG.event)
                    if strcmp(EEG.event(jj).type, saccadeType)
                        outSaccadeFound = true;
                        xChange = EEG.event(jj).(saccadeEndXField) - EEG.event(jj).(saccadeStartXField);
                        isForward = xChange > 0;
                        break;
                    end
                end
                
                if outSaccadeFound && abs(xChange) > 10
                    for opt = saccadeOutOptions
                        if opt == 2 && isForward
                            passesSaccadeOutDirection = true;
                            break;
                        elseif opt == 3 && ~isForward
                            passesSaccadeOutDirection = true;
                            break;
                        elseif opt == 4
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
            
            % Generate the 6-digit event code
            condStr = '';
            if isfield(evt, 'condition_number') && ~isempty(evt.condition_number)
                condNum = evt.condition_number;
                condStr = sprintf('%02d', mod(condNum, 100));
            else
                condStr = '00';
            end
            
            regionStr = '';
            if isfield(evt, 'current_region') && ~isempty(evt.current_region) && isKey(regionCodeMap, evt.current_region)
                regionStr = regionCodeMap(evt.current_region);
            else
                regionStr = '00';
            end
            
            filterStr = filterCode;
            newType = sprintf('%s%s%s', condStr, regionStr, filterStr);
            
            % Store the original type if this is the first time we're coding this event
            if ~isfield(evt, 'original_type')
                filteredEEG.event(mm).original_type = evt.type;
            end
            
            % Check for existing code in the event
            if isfield(evt, 'eyesort_full_code') && ~isempty(evt.eyesort_full_code)
                conflictingEvents{end+1} = struct(...
                    'event_index', mm, ...
                    'existing_code', evt.eyesort_full_code, ...
                    'new_code', newType, ...
                    'condition', evt.condition_number, ...
                    'region', evt.current_region);
            end
            
            % Update the event type and related fields
            filteredEEG.event(mm).type = newType;
            filteredEEG.event(mm).eyesort_condition_code = condStr;
            filteredEEG.event(mm).eyesort_region_code = regionStr;
            filteredEEG.event(mm).eyesort_filter_code = filterStr;
            filteredEEG.event(mm).eyesort_full_code = newType;
        end
    end
    
    % Handle conflicting events if any were found
    if ~isempty(conflictingEvents)
        conflictPercentage = (length(conflictingEvents) / matchedEventCount) * 100;
        
        fprintf('Warning: Found %d events with conflicting codes (%.1f%% of matched events).\n', ...
                length(conflictingEvents), conflictPercentage);
        fprintf('These events match multiple filter criteria.\n');
        fprintf('Keeping new codes by default. Use GUI for interactive conflict resolution.\n');
    end
    
    % Store the number of matched events for reference
    filteredEEG.eyesort_last_filter_matched_count = matchedEventCount;
    
    % Display results
    if matchedEventCount == 0
        fprintf('Warning: No events matched your filter criteria!\n');
    else
        fprintf('Filter applied successfully! Identified %d events matching filter criteria.\n', matchedEventCount);
    end
    
end 