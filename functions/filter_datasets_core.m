function [filteredEEG, com] = filter_datasets_core(EEG, varargin)
% FILTER_DATASETS_CORE - Core filtering function for EEG datasets
%
% Usage:
%   Method 1 - Using config file:
%   [filteredEEG, com] = filter_datasets_core(EEG, configFilePath)
%   [filteredEEG, com] = filter_datasets_core(EEG, 'config_file', configFilePath)
%
%   Method 2 - Using individual parameters:
%   [filteredEEG, com] = filter_datasets_core(EEG, 'param', value, ...)
%
% Required Input:
%   EEG - EEGLAB dataset structure
%
% For config file method:
%   configFilePath - Path to .m config file containing filter parameters
%
% For individual parameters method (name-value pairs):
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

% Check if first argument is a config file
if ~isempty(varargin) && ischar(varargin{1}) && (endsWith(varargin{1}, '.m') || endsWith(varargin{1}, '.mat')) && exist(varargin{1}, 'file')
    % Config file method
    config_file = varargin{1};
    config = load_eyesort_config(config_file);
    
    % Extract parameters from config
    timeLockedRegions = get_config_value(config, 'timeLockedRegions', []);
    % Map GUI field name to expected parameter name
    if isempty(timeLockedRegions)
        timeLockedRegions = get_config_value(config, 'selectedRegions', []);
    end
    
    % Check if filtering is enabled AFTER field mapping
    if isempty(timeLockedRegions)
        % No filtering requested
        filteredEEG = EEG;
        com = '';
        fprintf('No time_locked_regions specified in config - skipping filtering\n');
        return;
    end
    
    passOptions = get_config_value(config, 'passOptions', 1);
    % Map GUI pass fields to passOptions array
    if isempty(passOptions) || passOptions == 1
        passArray = [];
        if get_config_value(config, 'passFirstPass', 0), passArray(end+1) = 2; end
        if get_config_value(config, 'passSecondPass', 0), passArray(end+1) = 3; end
        if get_config_value(config, 'passThirdBeyond', 0), passArray(end+1) = 4; end
        if ~isempty(passArray), passOptions = passArray; end
    end
    
    prevRegions = get_config_value(config, 'prevRegions', {});
    if isempty(prevRegions)
        prevRegions = get_config_value(config, 'selectedPrevRegions', {});
    end
    
    nextRegions = get_config_value(config, 'nextRegions', {});
    if isempty(nextRegions)
        nextRegions = get_config_value(config, 'selectedNextRegions', {});
    end
    
    fixationOptions = get_config_value(config, 'fixationOptions', 1);
    % Map GUI fixation fields to fixationOptions array  
    if isempty(fixationOptions) || fixationOptions == 1
        fixArray = [];
        if get_config_value(config, 'fixFirstInRegion', 0), fixArray(end+1) = 2; end
        if get_config_value(config, 'fixSingleFixation', 0), fixArray(end+1) = 3; end
        if get_config_value(config, 'fixSecondMulti', 0), fixArray(end+1) = 4; end
        if get_config_value(config, 'fixAllSubsequent', 0), fixArray(end+1) = 5; end
        if get_config_value(config, 'fixLastInRegion', 0), fixArray(end+1) = 6; end
        if ~isempty(fixArray), fixationOptions = fixArray; end
    end
    
    saccadeInOptions = get_config_value(config, 'saccadeInOptions', 1);
    % Map GUI saccade in fields
    if isempty(saccadeInOptions) || saccadeInOptions == 1
        saccInArray = [];
        if get_config_value(config, 'saccadeInForward', 0), saccInArray(end+1) = 2; end
        if get_config_value(config, 'saccadeInBackward', 0), saccInArray(end+1) = 3; end
        if ~isempty(saccInArray), saccadeInOptions = saccInArray; end
    end
    
    saccadeOutOptions = get_config_value(config, 'saccadeOutOptions', 1);
    % Map GUI saccade out fields  
    if isempty(saccadeOutOptions) || saccadeOutOptions == 1
        saccOutArray = [];
        if get_config_value(config, 'saccadeOutForward', 0), saccOutArray(end+1) = 2; end
        if get_config_value(config, 'saccadeOutBackward', 0), saccOutArray(end+1) = 3; end
        if ~isempty(saccOutArray), saccadeOutOptions = saccOutArray; end
    end
    
    conditions = get_config_value(config, 'conditions', []);
    items = get_config_value(config, 'items', []);
    filterCount = get_config_value(config, 'filterCount', []);
    filterDescription = get_config_value(config, 'filterDescription', '');
    
else
    % Individual parameters method (original)
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
    addParameter(p, 'filterDescription', '', @ischar);
    
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
    filterDescription = p.Results.filterDescription;
end

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
                                         saccadeStartXField, saccadeEndXField, filterDescription);
    
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
                                              saccadeStartXField, saccadeEndXField, filterDescription)
    % Optimized internal filtering implementation with O(n) complexity
    
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
    
    % ========== PERFORMANCE OPTIMIZATION: PRE-COMPUTE ALL INDICES ==========
    fprintf('Pre-computing event indices for optimized filtering...\n');
    
    % Pre-extract all event fields for vectorized operations
    nEvents = length(EEG.event);
    eventTypes = cell(nEvents, 1);
    originalTypes = cell(nEvents, 1);
    currentRegions = cell(nEvents, 1);
    lastRegionVisited = cell(nEvents, 1);
    trialNumbers = zeros(nEvents, 1);
    regionPassNumbers = zeros(nEvents, 1);
    fixationInPass = zeros(nEvents, 1);
    conditionNumbers = zeros(nEvents, 1);
    itemNumbers = zeros(nEvents, 1);
    
    % Extract all fields in one pass
    for i = 1:nEvents
        evt = EEG.event(i);
        eventTypes{i} = evt.type;
        if isfield(evt, 'original_type')
            originalTypes{i} = evt.original_type;
        else
            originalTypes{i} = '';
        end
        if isfield(evt, 'current_region')
            currentRegions{i} = evt.current_region;
        else
            currentRegions{i} = '';
        end
        if isfield(evt, 'last_region_visited')
            lastRegionVisited{i} = evt.last_region_visited;
        else
            lastRegionVisited{i} = '';
        end
        if isfield(evt, 'trial_number')
            trialNumbers(i) = evt.trial_number;
        end
        if isfield(evt, 'region_pass_number')
            regionPassNumbers(i) = evt.region_pass_number;
        end
        if isfield(evt, 'fixation_in_pass')
            fixationInPass(i) = evt.fixation_in_pass;
        end
        if isfield(evt, 'condition_number')
            conditionNumbers(i) = evt.condition_number;
        end
        if isfield(evt, 'item_number')
            itemNumbers(i) = evt.item_number;
        end
    end
    
    % Identify fixation events (vectorized)
    isFixation = false(nEvents, 1);
    for i = 1:nEvents
        if ischar(eventTypes{i}) && startsWith(eventTypes{i}, fixationType)
            isFixation(i) = true;
        elseif ~isempty(originalTypes{i}) && ischar(originalTypes{i}) && startsWith(originalTypes{i}, fixationType)
            isFixation(i) = true;
        elseif ischar(eventTypes{i}) && length(eventTypes{i}) == 6 && isfield(EEG.event(i), 'eyesort_full_code')
            isFixation(i) = true;
        end
    end
    
    % Get fixation indices
    fixationIndices = find(isFixation);
    
    % Pre-compute next region relationships (vectorized)
    nextRegionMap = containers.Map('KeyType', 'int32', 'ValueType', 'any');
    for i = 1:length(fixationIndices)
        idx = fixationIndices(i);
        currentReg = currentRegions{idx};
        if isempty(currentReg), continue; end
        
        % Find next different region among remaining fixations
        nextRegion = '';
        for j = i+1:length(fixationIndices)
            nextIdx = fixationIndices(j);
            nextReg = currentRegions{nextIdx};
            if ~isempty(nextReg) && ~strcmp(nextReg, currentReg)
                nextRegion = nextReg;
                break;
            end
        end
        nextRegionMap(idx) = nextRegion;
    end
    
    % Pre-compute fixation groupings by trial/region/pass
    fixationGroups = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for i = 1:length(fixationIndices)
        idx = fixationIndices(i);
        if trialNumbers(idx) == 0 || isempty(currentRegions{idx}) || regionPassNumbers(idx) == 0
            continue;
        end
        
        key = sprintf('%d_%s_%d', trialNumbers(idx), currentRegions{idx}, regionPassNumbers(idx));
        if isKey(fixationGroups, key)
            groupIndices = fixationGroups(key);
            groupIndices(end+1) = idx;
            fixationGroups(key) = groupIndices;
        else
            fixationGroups(key) = idx;
        end
    end
    
    % Pre-compute saccade relationships
    saccadeIndices = find(strcmp(eventTypes, saccadeType));
    prevSaccadeMap = containers.Map('KeyType', 'int32', 'ValueType', 'any');
    nextSaccadeMap = containers.Map('KeyType', 'int32', 'ValueType', 'any');
    
    for i = 1:length(fixationIndices)
        idx = fixationIndices(i);
        
        % Find previous saccade
        prevSaccade = [];
        for j = 1:length(saccadeIndices)
            if saccadeIndices(j) < idx
                prevSaccade = saccadeIndices(j);
            else
                break;
            end
        end
        if ~isempty(prevSaccade)
            prevSaccadeMap(idx) = prevSaccade;
        end
        
        % Find next saccade
        nextSaccade = [];
        for j = 1:length(saccadeIndices)
            if saccadeIndices(j) > idx
                nextSaccade = saccadeIndices(j);
                break;
            end
        end
        if ~isempty(nextSaccade)
            nextSaccadeMap(idx) = nextSaccade;
        end
    end
    
    fprintf('Pre-computation complete. Processing %d fixation events...\n', length(fixationIndices));
    
    % ========== OPTIMIZED FILTERING LOOP ==========
    for i = 1:length(fixationIndices)
        mm = fixationIndices(i);
        evt = EEG.event(mm);
        
        % Check basic filters first (fastest)
        % Check if this is a fixation event or a previously coded fixation event
        if ~isFixation(mm)
            continue;
        end
        
        % Check for condition and item filters (vectorized)
        if ~isempty(conditions) && conditionNumbers(mm) > 0
            if ~any(conditionNumbers(mm) == conditions)
                continue;
            end
        end
        
        if ~isempty(items) && itemNumbers(mm) > 0
            if ~any(itemNumbers(mm) == items)
                continue;
            end
        end
        
        % Time-locked region filter (vectorized)
        if ~isempty(timeLockedRegions) && ~isempty(currentRegions{mm})
            if ~any(strcmp(currentRegions{mm}, timeLockedRegions))
                continue;
            end
        end
        
        % Pass index filtering (optimized)
        passesPassIndex = false;
        if isscalar(passOptions)
            if passOptions == 1
                passesPassIndex = true;
            elseif passOptions == 2
                passesPassIndex = (regionPassNumbers(mm) == 1);
            elseif passOptions == 3
                passesPassIndex = (regionPassNumbers(mm) == 2);
            elseif passOptions == 4
                passesPassIndex = (regionPassNumbers(mm) >= 3);
            else
                passesPassIndex = true;
            end
        else
            if isempty(passOptions) || any(passOptions == 1)
                passesPassIndex = true;
            else
                for opt = passOptions
                    if opt == 2 && regionPassNumbers(mm) == 1
                        passesPassIndex = true;
                        break;
                    elseif opt == 3 && regionPassNumbers(mm) == 2
                        passesPassIndex = true;
                        break;
                    elseif opt == 4 && regionPassNumbers(mm) >= 3
                        passesPassIndex = true;
                        break;
                    end
                end
            end
        end
        
        if ~passesPassIndex
            continue;
        end
        
        % Previous region filtering (optimized)
        if ~isempty(prevRegions)
            if isempty(lastRegionVisited{mm}) || ~any(strcmp(lastRegionVisited{mm}, prevRegions))
                continue;
            end
        end
        
        % Next region filtering (optimized with pre-computed map)
        if ~isempty(nextRegions)
            if ~isKey(nextRegionMap, mm)
                continue;
            end
            nextReg = nextRegionMap(mm);
            if isempty(nextReg) || ~any(strcmp(nextReg, nextRegions))
                continue;
            end
        end
        
        % Fixation type filtering (optimized with pre-computed groups)
        passesFixationType = false;
        if isscalar(fixationOptions)
            if fixationOptions == 0
                passesFixationType = true;
            elseif fixationOptions == 1
                % Single fixation - check group size
                if trialNumbers(mm) > 0 && ~isempty(currentRegions{mm}) && regionPassNumbers(mm) > 0
                    key = sprintf('%d_%s_%d', trialNumbers(mm), currentRegions{mm}, regionPassNumbers(mm));
                    if isKey(fixationGroups, key)
                        groupIndices = fixationGroups(key);
                        passesFixationType = (length(groupIndices) == 1);
                    end
                end
            elseif fixationOptions == 2
                % First of multiple
                if trialNumbers(mm) > 0 && ~isempty(currentRegions{mm}) && regionPassNumbers(mm) > 0
                    key = sprintf('%d_%s_%d', trialNumbers(mm), currentRegions{mm}, regionPassNumbers(mm));
                    if isKey(fixationGroups, key)
                        groupIndices = fixationGroups(key);
                        passesFixationType = (fixationInPass(mm) == 1 && length(groupIndices) > 1);
                    end
                end
            elseif fixationOptions == 3
                passesFixationType = (fixationInPass(mm) == 2);
            elseif fixationOptions == 4
                passesFixationType = (fixationInPass(mm) > 2);
            elseif fixationOptions == 5
                % Last in region
                if trialNumbers(mm) > 0 && ~isempty(currentRegions{mm}) && regionPassNumbers(mm) > 0
                    key = sprintf('%d_%s_%d', trialNumbers(mm), currentRegions{mm}, regionPassNumbers(mm));
                    if isKey(fixationGroups, key)
                        groupIndices = fixationGroups(key);
                        maxFixInPass = max(fixationInPass(groupIndices));
                        passesFixationType = (fixationInPass(mm) == maxFixInPass);
                    end
                end
            else
                passesFixationType = true;
            end
        else
            if isempty(fixationOptions) || any(fixationOptions == 0)
                passesFixationType = true;
            else
                for opt = fixationOptions
                    if opt == 1 && trialNumbers(mm) > 0 && ~isempty(currentRegions{mm}) && regionPassNumbers(mm) > 0
                        key = sprintf('%d_%s_%d', trialNumbers(mm), currentRegions{mm}, regionPassNumbers(mm));
                        if isKey(fixationGroups, key)
                            groupIndices = fixationGroups(key);
                            if length(groupIndices) == 1
                                passesFixationType = true;
                                break;
                            end
                        end
                    elseif opt == 2 && trialNumbers(mm) > 0 && ~isempty(currentRegions{mm}) && regionPassNumbers(mm) > 0
                        key = sprintf('%d_%s_%d', trialNumbers(mm), currentRegions{mm}, regionPassNumbers(mm));
                        if isKey(fixationGroups, key)
                            groupIndices = fixationGroups(key);
                            if fixationInPass(mm) == 1 && length(groupIndices) > 1
                                passesFixationType = true;
                                break;
                            end
                        end
                    elseif opt == 3 && fixationInPass(mm) == 2
                        passesFixationType = true;
                        break;
                    elseif opt == 4 && fixationInPass(mm) > 2
                        passesFixationType = true;
                        break;
                    elseif opt == 5 && trialNumbers(mm) > 0 && ~isempty(currentRegions{mm}) && regionPassNumbers(mm) > 0
                        key = sprintf('%d_%s_%d', trialNumbers(mm), currentRegions{mm}, regionPassNumbers(mm));
                        if isKey(fixationGroups, key)
                            groupIndices = fixationGroups(key);
                            maxFixInPass = max(fixationInPass(groupIndices));
                            if fixationInPass(mm) == maxFixInPass
                                passesFixationType = true;
                                break;
                            end
                        end
                    end
                end
            end
        end
        
        if ~passesFixationType
            continue;
        end
        
        % Saccade in direction filtering (optimized with pre-computed map)
        passesSaccadeInDirection = false;
        if isscalar(saccadeInOptions)
            if saccadeInOptions == 1
                passesSaccadeInDirection = true;
            else
                if isKey(prevSaccadeMap, mm)
                    prevSaccadeIdx = prevSaccadeMap(mm);
                    xChange = EEG.event(prevSaccadeIdx).(saccadeEndXField) - EEG.event(prevSaccadeIdx).(saccadeStartXField);
                    isForward = xChange > 0;
                    
                    if saccadeInOptions == 2
                        passesSaccadeInDirection = isForward && abs(xChange) > 10;
                    elseif saccadeInOptions == 3
                        passesSaccadeInDirection = ~isForward && abs(xChange) > 10;
                    elseif saccadeInOptions == 4
                        passesSaccadeInDirection = abs(xChange) > 10;
                    end
                                 else
                     if saccadeInOptions == 4
                         passesSaccadeInDirection = true;
                     else
                         passesSaccadeInDirection = false;
                     end
                 end
            end
        else
            if isempty(saccadeInOptions) || any(saccadeInOptions == 1)
                passesSaccadeInDirection = true;
            else
                if isKey(prevSaccadeMap, mm)
                    prevSaccadeIdx = prevSaccadeMap(mm);
                    xChange = EEG.event(prevSaccadeIdx).(saccadeEndXField) - EEG.event(prevSaccadeIdx).(saccadeStartXField);
                    isForward = xChange > 0;
                    
                    if abs(xChange) > 10
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
        end
        
        if ~passesSaccadeInDirection
            continue;
        end
        
        % Saccade out direction filtering (optimized with pre-computed map)
        passesSaccadeOutDirection = false;
        if isscalar(saccadeOutOptions)
            if saccadeOutOptions == 1
                passesSaccadeOutDirection = true;
            else
                if isKey(nextSaccadeMap, mm)
                    nextSaccadeIdx = nextSaccadeMap(mm);
                    xChange = EEG.event(nextSaccadeIdx).(saccadeEndXField) - EEG.event(nextSaccadeIdx).(saccadeStartXField);
                    isForward = xChange > 0;
                    
                    if saccadeOutOptions == 2
                        passesSaccadeOutDirection = isForward && abs(xChange) > 10;
                    elseif saccadeOutOptions == 3
                        passesSaccadeOutDirection = ~isForward && abs(xChange) > 10;
                    elseif saccadeOutOptions == 4
                        passesSaccadeOutDirection = abs(xChange) > 10;
                    end
                                 else
                     if saccadeOutOptions > 1 && saccadeOutOptions < 4
                         passesSaccadeOutDirection = false;
                     else
                         passesSaccadeOutDirection = true;
                     end
                 end
            end
        else
            if isempty(saccadeOutOptions) || any(saccadeOutOptions == 1)
                passesSaccadeOutDirection = true;
            else
                if isKey(nextSaccadeMap, mm)
                    nextSaccadeIdx = nextSaccadeMap(mm);
                    xChange = EEG.event(nextSaccadeIdx).(saccadeEndXField) - EEG.event(nextSaccadeIdx).(saccadeStartXField);
                    isForward = xChange > 0;
                    
                    if abs(xChange) > 10
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
        end
        
        if ~passesSaccadeOutDirection
            continue;
        end
        
        % If we reach here, the event passes all filters
        matchedEventCount = matchedEventCount + 1;
        
        % Generate the 6-digit event code
        condStr = '';
        if conditionNumbers(mm) > 0
            condStr = sprintf('%02d', mod(conditionNumbers(mm), 100));
        else
            condStr = '00';
        end
        
        regionStr = '';
        if ~isempty(currentRegions{mm}) && isKey(regionCodeMap, currentRegions{mm})
            regionStr = regionCodeMap(currentRegions{mm});
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
                'condition', conditionNumbers(mm), ...
                'region', currentRegions{mm});
            continue; % Skip this event instead of overwriting
        end
        
        % Update the event type and related fields
        filteredEEG.event(mm).type = newType;
        filteredEEG.event(mm).eyesort_condition_code = condStr;
        filteredEEG.event(mm).eyesort_region_code = regionStr;
        filteredEEG.event(mm).eyesort_filter_code = filterStr;
        filteredEEG.event(mm).eyesort_full_code = newType;
        
        % Add BDF description columns directly (only to filtered events to minimize 7.3 risk)
        if ~isempty(filterDescription)
            % Get condition description string from lookup
            conditionDesc = '';
            if isfield(filteredEEG, 'eyesort_condition_descriptions') && ...
               isfield(filteredEEG, 'eyesort_condition_lookup') && ...
               conditionNumbers(mm) > 0 && itemNumbers(mm) > 0
                key = sprintf('%d_%d', conditionNumbers(mm), itemNumbers(mm));
                validKey = matlab.lang.makeValidName(['k_' key]);
                condStruct = filteredEEG.eyesort_condition_descriptions;
                if isfield(condStruct, validKey)
                    conditionNum = condStruct.(validKey); % This is numeric
                    % Convert back to string using lookup
                    if isKey(filteredEEG.eyesort_condition_lookup, num2str(conditionNum))
                        conditionDesc = filteredEEG.eyesort_condition_lookup(num2str(conditionNum));
                    end
                end
            end
            
            % Store actual strings in dataset (only on filtered events)
            filteredEEG.event(mm).bdf_condition_description = char(conditionDesc);
            filteredEEG.event(mm).bdf_filter_description = char(filterDescription);
            filteredEEG.event(mm).bdf_full_description = strcat(char(conditionDesc), '_', char(filterDescription));
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

%% Helper function: load_eyesort_config
function config = load_eyesort_config(configPath)
    % LOAD_EYESORT_CONFIG - Load configuration from MATLAB script or MAT file
    %
    % INPUTS:
    %   configPath - Path to .m config file or .mat file
    %
    % OUTPUTS:
    %   config - Struct containing all variables from config file
    
    if ~exist(configPath, 'file')
        error('Configuration file not found: %s', configPath);
    end
    
    [~, ~, ext] = fileparts(configPath);
    if strcmp(ext, '.mat')
        % Load MAT file
        try
            loaded_data = load(configPath);
            % Check if config is nested inside a 'config' field
            if isfield(loaded_data, 'config')
                config = loaded_data.config;
            else
                config = loaded_data;
            end
        catch ME
            error('Error loading MAT config file %s: %s', configPath, ME.message);
        end
    elseif strcmp(ext, '.m')
        % Run M file script
        try
            % Run the config file and capture variables
            run(configPath);
            
            % Capture all variables from workspace
            config = struct();
            vars = whos;
            for i = 1:length(vars)
                if ~strcmp(vars(i).name, 'config') && ~strcmp(vars(i).name, 'configPath')
                    config.(vars(i).name) = eval(vars(i).name);
                end
            end
        catch ME
            error('Error loading M config file %s: %s', configPath, ME.message);
        end
    else
        error('Config file must be a .m or .mat file: %s', configPath);
    end
end

%% Helper function: get_config_value
function value = get_config_value(config, field_name, default_value)
    % GET_CONFIG_VALUE - Get a value from config with default fallback
    %
    % INPUTS:
    %   config - Config struct
    %   field_name - Name of field to get
    %   default_value - Default value if field doesn't exist
    %
    % OUTPUTS:
    %   value - Field value or default
    
    if isfield(config, field_name) && ~isempty(config.(field_name))
        value = config.(field_name);
    else
        value = default_value;
    end
end 