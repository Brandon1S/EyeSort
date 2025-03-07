function EEG = new_trial_labelling(EEG, startCode, endCode, conditionTriggers, itemTriggers)
    
    % Verify inputs
    if nargin < 5
        error('trial_labeling_word_level_sara: Not enough input arguments.');
    end

    if ~isfield(EEG, 'event') || isempty(EEG.event)
        error('trial_labeling_word_level_sara: EEG.event is empty or missing.');
    end

    % Print verification of inputs
    fprintf('Start code: %s\n', startCode);
    fprintf('End code: %s\n', endCode);
    fprintf('Condition triggers: %s\n', strjoin(conditionTriggers, ', '));
    fprintf('Item triggers: %s\n', strjoin(itemTriggers, ', '));
    
    % Initialize trial tracking variables
    % Trial tracking level
    currentTrial = 0;
    currentItem = [];
    currentCond = [];

    % For tracking regression status and fixations in the Ending region:
    % inEndRegion is true once we enter the "Ending" region.
    % Store indices of fixations (in EEG.event) that occur in the Ending region.
    trialRegressionMap = containers.Map('KeyType', 'double', 'ValueType', 'logical');
    inEndRegion = false;
    endRegionFixations = [];  
    endRegionFixationCount = 0;  % number of fixations stored in Ending region

    % - Word and region tracking maps
    % These track visited words/regions and count fixations for first-pass detection
    visitedWords = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    wordFixationCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');
    visitedRegions = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    regionFixationCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');
    previousWord = '';
    previousRegion = '';

    % Initialize new fields for all events
    [EEG.event.current_region] = deal('');
    [EEG.event.previous_region] = deal('');
    [EEG.event.current_word] = deal('');
    [EEG.event.previous_word] = deal('');
    [EEG.event.is_first_pass_region] = deal(false);
    [EEG.event.is_first_pass_word] = deal(false);
    [EEG.event.is_regression_trial] = deal(false);
    [EEG.event.is_region_regression] = deal(false);
    [EEG.event.is_word_regression] = deal(false);
    [EEG.event.total_fixations_in_word] = deal(0);
    [EEG.event.total_fixations_in_region] = deal(0);
    [EEG.event.trial_number] = deal(0);
    [EEG.event.item_number] = deal(0);
    [EEG.event.condition_number] = deal(0);

    % Count events for verification
    numFixations = 0;
    numWithBoundaries = 0;
    numProcessed = 0;

    % Add this flag at the initialization section (around line 20)
    hasRegressionBeenFound = containers.Map('KeyType', 'double', 'ValueType', 'logical');

    % Event processing loop
    for iEvt = 1:length(EEG.event)
        eventType = EEG.event(iEvt).type;
        if isnumeric(eventType)
            eventType = num2str(eventType);
        end
        
        % Debug trigger detection
        if startsWith(eventType, 'S')
            fprintf('Found trigger: %s\n', eventType);
        end

        % Remove spaces from event type and triggers for comparison
        eventTypeNoSpace = strrep(eventType, ' ', '');
        conditionTriggersNoSpace = cellfun(@(x) strrep(x, ' ', ''), conditionTriggers, 'UniformOutput', false);
        itemTriggersNoSpace = cellfun(@(x) strrep(x, ' ', ''), itemTriggers, 'UniformOutput', false);
        
        %%%%%%%%%%%%%%%   
        % Trial start %
        %%%%%%%%%%%%%%% 
        % This section is responsible for resetting the trial-level tracking variables
        if strcmp(eventTypeNoSpace, strrep(startCode, ' ', ''))
            currentTrial = currentTrial + 1;
            hasRegressionBeenFound(currentTrial) = false;  % Initialize flag for new trial
            % Reset word and region tracking for new tria
            visitedWords = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            wordFixationCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');
            visitedRegions = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            regionFixationCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');
            previousWord = '';
            previousRegion = '';
            % Also, clear any ending region storage from previous trial:
            inEndRegion = false;
            endRegionFixations = [];
            endRegionFixationCount = 0;
            fprintf('Starting trial %d\n', currentTrial);

        %%%%%%%%%%%%%%   
        % Trial end  %
        %%%%%%%%%%%%%% 
        % Check for trial end
        elseif strcmp(eventType, endCode)
            % At the end of the trial, if we are still in the Ending region and no regression was flagged,
            % mark all stored fixations as non-regression (Behavior 01).
            if inEndRegion && ~hasRegressionBeenFound(currentTrial)
                for j = 1:endRegionFixationCount
                    fixIdx = endRegionFixations(j);
                    condStr = sprintf('%02d', mod(EEG.event(fixIdx).condition_number, 100));
                    EEG.event(fixIdx).type = sprintf('%s0401', condStr);
                end
            end
            % Clear the Ending-region storage.
            inEndRegion = false;
            endRegionFixationCount = 0;
            endRegionFixations = [];
        
            % Reset trial-level item and condition numbers
            currentItem = [];
            currentCond = [];
        
        % Check for condition trigger
        elseif any(strcmp(eventTypeNoSpace, conditionTriggersNoSpace))
            % Extract the numeric value from the trigger (e.g., '224' from 'S224')
            currentCond = str2double(regexp(eventTypeNoSpace, '\d+', 'match', 'once'));
            fprintf('Setting condition to %d from trigger %s\n', currentCond, eventType);
            EEG.event(iEvt).condition_number = currentCond;
        
        % Check for item trigger
        elseif any(strcmp(eventTypeNoSpace, itemTriggersNoSpace))
            % Extract the numeric value from the trigger (e.g., '39' from 'S39')
            currentItem = str2double(regexp(eventTypeNoSpace, '\d+', 'match', 'once'));
            fprintf('Setting item to %d from trigger %s\n', currentItem, eventType);
            EEG.event(iEvt).item_number = currentItem;
        
        % Process fixation events
        elseif startsWith(eventType, 'R_fixation')
            numFixations = numFixations + 1;
            fprintf('Processing fixation %d, current item: %d, current condition: %d\n', ...
                    numFixations, currentItem, currentCond);
            
            if isfield(EEG.event(iEvt), 'word_boundaries')
                numWithBoundaries = numWithBoundaries + 1;
                fprintf('  Has word boundaries\n');
                
                if ~isempty(currentItem) && ~isempty(currentCond)
                    numProcessed = numProcessed + 1;
                    currentWord = determine_word_region(EEG.event(iEvt));
                    fprintf('  Determined word: %s\n', currentWord);
                    
                    if ~isempty(currentWord)
                        % Update word-related fields
                        EEG.event(iEvt).current_word = currentWord;
                        EEG.event(iEvt).previous_word = previousWord;
                        
                        % Update word fixation counts
                        if ~isKey(wordFixationCounts, currentWord)
                            wordFixationCounts(currentWord) = 1;
                        else
                            wordFixationCounts(currentWord) = wordFixationCounts(currentWord) + 1;
                        end
                        
                        % Update first-pass word information
                        EEG.event(iEvt).is_first_pass_word = ~isKey(visitedWords, currentWord);
                        visitedWords(currentWord) = true;
                        
                        % Parse current word into region
                        [curr_region, curr_word_num] = parse_word_region(currentWord);
                        % Get region name from the event's region fields (e.g., 'Ending' etc.)
                        regionName = EEG.event(iEvt).(sprintf('region%d_name', curr_region));
                        
                        % Update region-related fields
                        EEG.event(iEvt).current_region = regionName;
                        EEG.event(iEvt).previous_region = previousRegion;
                        
                        % Update region fixation counts (using region number as key)
                        regionKey = num2str(curr_region);
                        if ~isKey(regionFixationCounts, regionKey)
                            regionFixationCounts(regionKey) = 1;
                        else
                            regionFixationCounts(regionKey) = regionFixationCounts(regionKey) + 1;
                        end
                        
                        % Update first-pass region information
                        EEG.event(iEvt).is_first_pass_region = ~isKey(visitedRegions, regionKey);
                        visitedRegions(regionKey) = true;
                        
                        % Store fixation counts
                        EEG.event(iEvt).total_fixations_in_word = wordFixationCounts(currentWord);
                        EEG.event(iEvt).total_fixations_in_region = regionFixationCounts(regionKey);
                        
                        % Check for regressions (for regions other than our Ending-specific definition)
                        if ~isempty(previousWord)
                            [prev_region, prev_word_num] = parse_word_region(previousWord);
                            EEG.event(iEvt).is_region_regression = (curr_region < prev_region);
                            if curr_region == prev_region
                                EEG.event(iEvt).is_word_regression = (curr_word_num < prev_word_num);
                            else
                                EEG.event(iEvt).is_word_regression = (curr_region < prev_region);
                            end
                        end
                        
                        % Store trial metadata
                        EEG.event(iEvt).trial_number = currentTrial;
                        EEG.event(iEvt).item_number = currentItem;
                        EEG.event(iEvt).condition_number = currentCond;

                        %% ======= Handle the ENDING region behavior codes =======
                        if strcmp(EEG.event(iEvt).current_region, 'Ending')
                            % (A) We are in the Ending region: add this fixation to our storage.
                            if ~inEndRegion
                                inEndRegion = true;
                                endRegionFixationCount = 0;
                                endRegionFixations = [];
                            end
                            endRegionFixationCount = endRegionFixationCount + 1;
                            endRegionFixations(endRegionFixationCount) = iEvt;
                            
                            % Check if this fixation shows a word-level regression:
                            % Compare current fixation's word number with the previous fixation's word number
                            if ~isempty(EEG.event(iEvt).previous_word) && ~hasRegressionBeenFound(currentTrial)
                                [~, curr_word_num] = parse_word_region(EEG.event(iEvt).current_word);
                                [~, prev_word_num] = parse_word_region(EEG.event(iEvt).previous_word);
                                if curr_word_num < prev_word_num
                                    % Word-level regression detected in the Ending region.
                                    hasRegressionBeenFound(currentTrial) = true;
                                    trialRegressionMap(currentTrial) = true;
                                    % Mark all events in this trial as regression trials.
                                    for k = 1:length(EEG.event)
                                        if EEG.event(k).trial_number == currentTrial
                                            EEG.event(k).is_regression_trial = true;
                                        end
                                    end
                                    
                                    % For word-level regressions, we want to label the fixation immediately 
                                    % preceding the trigger as Behavior 03. If more than one fixation was stored,
                                    % label fixations 1 to (N-1) accordingly.
                                    if endRegionFixationCount > 1
                                        % Label earlier fixations in the Ending region:
                                        for j = 1:(endRegionFixationCount - 1)
                                            fixIdx = endRegionFixations(j);
                                            condStr = sprintf('%02d', mod(EEG.event(fixIdx).condition_number, 100));
                                            if j == (endRegionFixationCount - 1)
                                                % The fixation immediately before the triggering fixation gets Behavior 03.
                                                EEG.event(fixIdx).type = sprintf('%s0403', condStr);
                                            else
                                                % All earlier fixations get Behavior 02.
                                                EEG.event(fixIdx).type = sprintf('%s0402', condStr);
                                            end
                                        end
                                    else
                                        % Only one fixation is stored, so assign it directly as Behavior 03.
                                        fixIdx = endRegionFixations(1);
                                        condStr = sprintf('%02d', mod(EEG.event(fixIdx).condition_number, 100));
                                        EEG.event(fixIdx).type = sprintf('%s0403', condStr);
                                    end
                                    
                                    % Clear the Ending-region storage now that the regression has been processed.
                                    inEndRegion = false;
                                    endRegionFixationCount = 0;
                                    endRegionFixations = [];
                                end
                            end
                        else
                            % (B) The current fixation is not in Ending.
                            % If we were collecting Ending-region fixations and no regression was yet flagged,
                            % then a regression out of the Ending region has occurred.
                            if inEndRegion && ~hasRegressionBeenFound(currentTrial)
                                hasRegressionBeenFound(currentTrial) = true;
                                trialRegressionMap(currentTrial) = true;
                                for k = 1:length(EEG.event)
                                    if EEG.event(k).trial_number == currentTrial
                                        EEG.event(k).is_regression_trial = true;
                                    end
                                end
                                % Label the stored Ending-region fixations:
                                for j = 1:endRegionFixationCount
                                    fixIdx = endRegionFixations(j);
                                    condStr = sprintf('%02d', mod(EEG.event(fixIdx).condition_number, 100));
                                    if j == endRegionFixationCount
                                        EEG.event(fixIdx).type = sprintf('%s0403', condStr);
                                    else
                                        EEG.event(fixIdx).type = sprintf('%s0402', condStr);
                                    end
                                end
                                % Clear the Ending-region storage.
                                inEndRegion = false;
                                endRegionFixationCount = 0;
                                endRegionFixations = [];
                            end
                        end
                        %% ======= End of ENDING region behavior coding =======

                        % Now update the previous trackers AFTER handling the Ending region behavior.
                        previousWord = currentWord;
                        previousRegion = regionName;
                    end
                end
            end
        end
    end
    EEG.saved = 'yes';

end

% Parses word region identifiers into region number and word number
% Handles two formats:
% - "4.2" -> region 4, word 2
% - "x1_1" -> region 1, word 1
function [major, minor] = parse_word_region(word_region)
    % Parses a word region string (e.g., "4.2" or "x1_1") into its major (region) and minor (word) parts.
    if contains(word_region, '.')
        parts = split(word_region, '.');
        major = str2double(parts{1});
        minor = str2double(parts{2});
    elseif contains(word_region, '_')
        parts = split(word_region, '_');
        % Remove 'x' from the first part if it exists
        region_part = regexprep(parts{1}, '^x', '');
        major = str2double(region_part);
        minor = str2double(parts{2});
    else
        error('Unknown word region format: %s', word_region);
    end
    
    if isnan(major) || isnan(minor)
        error('Failed to parse word region: %s', word_region);
    end
end


% Determines which word a fixation falls into based on x-coordinate
% Handles multiple possible position field names and data formats
% Returns the word identifier or empty string if no match found
function currentWord = determine_word_region(event)
    currentWord = '';
    
    % Get x position - check all possible field names
    if isfield(event, 'position_x')
        x = event.position_x;
    elseif isfield(event, 'fix_avgpos_x')
        x = event.fix_avgpos_x;
    elseif isfield(event, 'px')
        x = event.px;
    else
        fprintf('Warning: No position data found in event\n');
        return;
    end
    
    % Handle different data types for x position
    if ischar(x)
        % Handle coordinate string format "(X.XX, Y.YY)"
        numbers = regexp(x, '[-\d.]+', 'match');
        if ~isempty(numbers)
            x = str2double(numbers{1});
        else
            x = str2double(x);
        end
    elseif iscell(x)
        if ~isempty(x)
            if ischar(x{1})
                numbers = regexp(x{1}, '[-\d.]+', 'match');
                if ~isempty(numbers)
                    x = str2double(numbers{1});
                else
                    x = str2double(x{1});
                end
            else
                x = x{1};
            end
        else
            x = NaN;
        end
    end
    
    % Verify numeric conversion worked
    if isnan(x)
        fprintf('Warning: Could not convert x position to number\n');
        return;
    end
    
    % Check word boundaries
    if ~isfield(event, 'word_boundaries') || isempty(event.word_boundaries)
        return;
    end
    
    word_bounds = event.word_boundaries;
    field_names = fieldnames(word_bounds);
    
    % Loop through each field (word) in the word_bounds structure
    for i = 1:length(field_names)
        % Get the boundary coordinates for the current word
        bounds = word_bounds.(field_names{i});
        
        % Check if the fixation x-coordinate falls within this word's boundaries
        % bounds(1) is left edge, bounds(2) is right edge of word
        if x >= bounds(1) && x <= bounds(2)
            % If match found, store the word identifier
            currentWord = field_names{i};
            
            % Debug output: print word match details
            % Shows which word was matched and the exact coordinates
            fprintf('  Found word %s for x=%f (bounds: %f to %f)\n', ...
                    currentWord, x, bounds(1), bounds(2));
            
            % Exit loop since matching word found
            break;
        end
    end
end
