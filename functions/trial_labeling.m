function EEG = trial_labeling(EEG, startCode, endCode, conditionTriggers, itemTriggers, ...
                            fixationType, fixationXField, saccadeType, saccadeStartXField, saccadeEndXField, ...
                            sentenceStartCode, sentenceEndCode)
    
    % Verify inputs
    if nargin < 12
        error('trial_labeling: Not enough input arguments. All field names and sentence codes must be specified.');
    end
    
    % No default values - all field names are required
    
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        error('trial_labeling: EEG.event is empty or missing.');
    end

    % Check if sentence codes are provided (optional feature)
    useSentenceCodes = ~isempty(sentenceStartCode) && ~isempty(sentenceEndCode) && ...
                       ~strcmp(strtrim(sentenceStartCode), '') && ~strcmp(strtrim(sentenceEndCode), '');


    
    % Print verification of inputs
    fprintf('Start code: %s\n', startCode);
    fprintf('End code: %s\n', endCode);
    fprintf('Condition triggers: %s\n', strjoin(conditionTriggers, ', '));
    fprintf('Item triggers: %s\n', strjoin(itemTriggers, ', '));
    fprintf('Fixation event type: %s, X position field: %s\n', fixationType, fixationXField);
    fprintf('Saccade event type: %s, Start X field: %s, End X field: %s\n', saccadeType, saccadeStartXField, saccadeEndXField);
    
    if useSentenceCodes
        fprintf('Sentence start code: %s, Sentence end code: %s\n', sentenceStartCode, sentenceEndCode);
    else
        fprintf('Sentence codes not provided - processing all events within trials\n');
    end
    
    % Initialize trial tracking variables
    % Trial tracking level
    currentTrial = 0;
    currentItem = [];
    currentCond = [];
    sentenceActive = ~useSentenceCodes;  % If no sentence codes, always active within trials

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

    % New maps for tracking region passes and fixation counts within passes
    regionPassCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');       % Tracks number of passes through each region
    currentPassFixationCounts = containers.Map('KeyType', 'char', 'ValueType', 'double'); % Tracks fixation count in current pass
    lastRegionVisited = '';  % Tracks the actual last region visited (different from previousRegion which tracks the previous fixation)

    % Initialize new fields for all events
    [EEG.event.current_region] = deal('');
    [EEG.event.previous_region] = deal('');
    [EEG.event.last_region_visited] = deal('');  % New: tracks the actual last region visited (different from previousRegion which tracks the previous fixation)
    [EEG.event.next_region_visited] = deal('');  % New: tracks the next different region that will be visited after this fixation
    [EEG.event.region_pass_number] = deal(0);       % New: which pass through this region (1st, 2nd, etc.)
    [EEG.event.fixation_in_pass] = deal(0);         % New: which fixation in the current pass (1st, 2nd, etc.)
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
            % Reset pass tracking variables
            regionPassCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');
            currentPassFixationCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');
            lastRegionVisited = '';
            previousWord = '';
            previousRegion = '';
            sentenceActive = ~useSentenceCodes;  % Reset sentence state for new trial
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
            % Reset tracking at the end of the trial
            inEndRegion = false;
            endRegionFixationCount = 0;
            endRegionFixations = [];
        
            % Reset trial-level item and condition numbers
            currentItem = [];
            currentCond = [];
            sentenceActive = ~useSentenceCodes;
        
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
        
        % Check for sentence start/end codes
        elseif useSentenceCodes
            if strcmp(eventTypeNoSpace, strrep(sentenceStartCode, ' ', ''))
                sentenceActive = true;
                fprintf('Sentence presentation started\n');
            elseif strcmp(eventTypeNoSpace, strrep(sentenceEndCode, ' ', ''))
                sentenceActive = false;
                fprintf('Sentence presentation ended\n');
            end
        end
        
        % Process fixation events
        if startsWith(eventType, fixationType) && sentenceActive
            numFixations = numFixations + 1;
            fprintf('Processing fixation %d, current item: %d, current condition: %d\n', ...
                    numFixations, currentItem, currentCond);
            
            if isfield(EEG.event(iEvt), 'word_boundaries')
                numWithBoundaries = numWithBoundaries + 1;
                fprintf('  Has word boundaries\n');
                
                if ~isempty(currentItem) && ~isempty(currentCond)
                    numProcessed = numProcessed + 1;
                    currentWord = determine_word_region(EEG.event(iEvt), fixationXField);
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
                        
                        % Parse current word into region and word number
                        [curr_region, curr_word_num] = parse_word_region(currentWord);
                        
                        % Update first-pass word information
                        % A word is only first-pass if:
                        % 1. This is the first visit to this word AND
                        % 2. We haven't visited any words with a higher number in the same region
                        regionKey = num2str(curr_region);

                        % First, check if any later region has been visited
                        hasVisitedLaterRegion = false;
                        regionKeys = visitedRegions.keys();
                        for k = 1:length(regionKeys)
                            visitedRegionNum = str2double(regionKeys{k});
                            if visitedRegionNum > curr_region
                                hasVisitedLaterRegion = true;
                                break;
                            end
                        end

                        % Only proceed with word-level checks if no later region was visited
                        isFirstPassPossible = ~hasVisitedLaterRegion;
                        if isFirstPassPossible
                            % Then check if this specific word hasn't been visited
                            isFirstVisitToWord = ~isKey(visitedWords, currentWord);
                            
                            % Finally check if any later word in the same region was visited
                            hasVisitedLaterWord = false;
                            if isFirstVisitToWord
                                wordKeys = visitedWords.keys();
                                for k = 1:length(wordKeys)
                                    [word_region, word_num] = parse_word_region(wordKeys{k});
                                    if word_region == curr_region && word_num > curr_word_num
                                        hasVisitedLaterWord = true;
                                        break;
                                    end
                                end
                            end
                            
                            % Only mark as first pass if all conditions are met
                            EEG.event(iEvt).is_first_pass_word = isFirstVisitToWord && ~hasVisitedLaterWord;
                        else
                            % If a later region was already visited, this can't be first-pass
                            EEG.event(iEvt).is_first_pass_word = false;
                        end

                        visitedWords(currentWord) = true;
                        
                        % Get region name from the event's region fields (e.g., 'Ending' etc.)
                        regionName = EEG.event(iEvt).(sprintf('region%d_name', curr_region));
                        
                        % Update region-related fields
                        EEG.event(iEvt).current_region = regionName;
                        EEG.event(iEvt).previous_region = previousRegion;
                        
                        % Update region fixation counts (using region number as key)
                        if ~isKey(regionFixationCounts, regionKey)
                            regionFixationCounts(regionKey) = 1;
                        else
                            regionFixationCounts(regionKey) = regionFixationCounts(regionKey) + 1;
                        end
                        
                        % ======= NEW PASS TRACKING LOGIC =======
                        % If this is our first fixation in any region, initialize pass tracking
                        if isempty(lastRegionVisited)
                            lastRegionVisited = regionName;
                            regionPassCounts(regionName) = 1;
                            currentPassFixationCounts(regionName) = 1;
                            EEG.event(iEvt).region_pass_number = 1;
                            EEG.event(iEvt).fixation_in_pass = 1;
                            % First fixation has no last region visited
                            EEG.event(iEvt).last_region_visited = '';
                        else
                            % Check if we're in the same region as before
                            if strcmp(regionName, previousRegion)
                                % Same region, increment fixation count in current pass
                                currentPassFixationCounts(regionName) = currentPassFixationCounts(regionName) + 1;
                                EEG.event(iEvt).region_pass_number = regionPassCounts(regionName); 
                                EEG.event(iEvt).fixation_in_pass = currentPassFixationCounts(regionName);
                                % When still in the same region, last_region_visited should be the 
                                % last different region visited before entering this region
                                if iEvt > 1 && isfield(EEG.event(iEvt-1), 'last_region_visited') && ~isempty(EEG.event(iEvt-1).last_region_visited)
                                    EEG.event(iEvt).last_region_visited = EEG.event(iEvt-1).last_region_visited;
                                else
                                    % Find the last non-empty last_region_visited looking backwards
                                    lastVisitedFound = false;
                                    for lookBack = iEvt-1:-1:1
                                        if isfield(EEG.event(lookBack), 'last_region_visited') && ...
                                           ~isempty(EEG.event(lookBack).last_region_visited)
                                            EEG.event(iEvt).last_region_visited = EEG.event(lookBack).last_region_visited;
                                            lastVisitedFound = true;
                                            break;
                                        end
                                    end
                                    if ~lastVisitedFound
                                        % If we can't find any, use an empty string
                                        EEG.event(iEvt).last_region_visited = '';
                                    end
                                end
                            else
                                % Moving to a different region
                                % Update last region visited - it's the region we're coming from
                                EEG.event(iEvt).last_region_visited = previousRegion;
                                lastRegionVisited = previousRegion; % Previous fixation's region becomes the last one visited
                                
                                % Check if we've been to this region before during this trial
                                if isKey(regionPassCounts, regionName)
                                    % Been here before, increment pass counter
                                    regionPassCounts(regionName) = regionPassCounts(regionName) + 1;
                                    % Reset fixation counter for new pass
                                    currentPassFixationCounts(regionName) = 1;
                                else
                                    % First time in this region
                                    regionPassCounts(regionName) = 1;
                                    currentPassFixationCounts(regionName) = 1;
                                end
                                
                                % Store the pass information in the event
                                EEG.event(iEvt).region_pass_number = regionPassCounts(regionName);
                                EEG.event(iEvt).fixation_in_pass = 1; % First fixation in this pass
                            end
                        end
                        % ======= END NEW PASS TRACKING LOGIC =======
                        
                        % Update first-pass region information
                        % Only mark as first pass if:
                        % 1. This is the first visit to this region AND
                        % 2. We haven't visited any regions with a higher number
                        isFirstVisit = ~isKey(visitedRegions, regionKey);
                        hasVisitedLaterRegion = false;
                        
                        % Check if any region with a higher number has been visited
                        if isFirstVisit
                            regionKeys = visitedRegions.keys();
                            for k = 1:length(regionKeys)
                                visitedRegionNum = str2double(regionKeys{k});
                                if visitedRegionNum > curr_region
                                    hasVisitedLaterRegion = true;
                                    break;
                                end
                            end
                        end
                        
                        % Only mark as first pass if both conditions are met
                        EEG.event(iEvt).is_first_pass_region = isFirstVisit && ~hasVisitedLaterRegion;
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

                        %% ======= Track ENDING region regression information =======
                        if strcmp(EEG.event(iEvt).current_region, 'Ending')
                            % We are in the Ending region: add this fixation to our storage.
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
                                end
                            end
                        else
                            % The current fixation is not in Ending.
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
                                
                                % Clear the Ending-region storage.
                                inEndRegion = false;
                                endRegionFixationCount = 0;
                                endRegionFixations = [];
                            end
                        end
                        %% ======= End of ENDING region regression tracking =======

                        % Now update the previous trackers AFTER handling the Ending region behavior.
                        previousWord = currentWord;
                        previousRegion = regionName;
                    end
                end
            end
        end
    end
    
    % Second pass to compute next_region_visited field - this requires knowing all future fixations
    fprintf('Computing next_region_visited field...\n');
    for iTrial = 1:max([EEG.event.trial_number])
        % Get all fixation events for this trial
        trialFixations = find([EEG.event.trial_number] == iTrial & startsWith({EEG.event.type}, fixationType));
        
        % Process each fixation in the trial
        for iFixIdx = 1:length(trialFixations)
            iEvt = trialFixations(iFixIdx);
            currentRegion = EEG.event(iEvt).current_region;
            
            % Look ahead to find the next fixation in a different region
            nextDifferentRegion = '';
            
            % Search forward through remaining fixations in this trial
            for jFixIdx = iFixIdx+1:length(trialFixations)
                jEvt = trialFixations(jFixIdx);
                nextRegion = EEG.event(jEvt).current_region;
                
                % Found a fixation in a different region
                if ~strcmp(nextRegion, currentRegion) && ~isempty(nextRegion)
                    nextDifferentRegion = nextRegion;
                    break;
                end
            end
            
            % Store the next different region
            EEG.event(iEvt).next_region_visited = nextDifferentRegion;
        end
    end
    fprintf('Done computing next_region_visited field.\n');
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
% Returns the word identifier or empty string if no match found
function currentWord = determine_word_region(event, fixationXField)
    currentWord = '';
    
    % Get x position - check all possible field names
    if isfield(event, fixationXField)
        x = event.(fixationXField);
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
