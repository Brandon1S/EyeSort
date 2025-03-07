function EEG = trial_labeling_word_level_sara(EEG, startCode, endCode, conditionTriggers, itemTriggers)
    % trial_labeling_word_level_sara() - Labels trials with first-pass reading information
    %
    % Usage:
    %   >> EEG = trial_labeling_word_level_sara(EEG, startCode, endCode, conditionTriggers, itemTriggers);
    %
    % (See original header for details.)
    
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
    currentTrial = 0;
    currentItem = [];
    currentCond = [];

    % For tracking regression status and fixations in the Ending region:
    trialRegressionMap = containers.Map('KeyType', 'double', 'ValueType', 'logical');
    % inEndRegion is true once we enter the "Ending" region.
    inEndRegion = false;
    % Store indices of fixations (in EEG.event) that occur in the Ending region.
    endRegionFixations = [];  
    endRegionFixationCount = 0;  % number of fixations stored in Ending region

    % Initialize word tracking (as in original code)
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

    % Process each event
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
        
        % Check for trial start
        if strcmp(eventTypeNoSpace, strrep(startCode, ' ', ''))
            currentTrial = currentTrial + 1;
            % (Reset word and region tracking for new trial.)
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

        % Check for trial end – note that we use the end trigger here.
        elseif strcmp(eventType, endCode)
            % If we are still in the Ending region (i.e. no regression was detected),
            % mark all collected fixations as non-regression (Behavior 1).
            if inEndRegion
                for j = 1:endRegionFixationCount
                    fixIdx = endRegionFixations(j);
                    condStr = sprintf('%02d', mod(EEG.event(fixIdx).condition_number, 100));
                    % Behavior 1: non-regression trial ending fixations
                    EEG.event(fixIdx).type = sprintf('%s0401', condStr);
                end
                % Reset the Ending-region storage
                inEndRegion = false;
                endRegionFixationCount = 0;
                endRegionFixations = [];
            end
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
                        
                        % Update previous trackers
                        previousWord = currentWord;
                        previousRegion = regionName;
                        
                        % Store trial metadata
                        EEG.event(iEvt).trial_number = currentTrial;
                        EEG.event(iEvt).item_number = currentItem;
                        EEG.event(iEvt).condition_number = currentCond;

                        %% ======= Handle the ENDING region behavior codes =======
                        % We are only interested in the special behavior coding for fixations in
                        % the 'Ending' region. (Recall: only regressions out of this region count.)
                        if strcmp(EEG.event(iEvt).current_region, 'Ending')
                            % If we are in the Ending region, add this fixation index to our list.
                            if ~inEndRegion
                                % Starting a new sequence of Ending-region fixations.
                                inEndRegion = true;
                                endRegionFixationCount = 0;  % reset count
                                endRegionFixations = [];
                            end
                            endRegionFixationCount = endRegionFixationCount + 1;
                            endRegionFixations(endRegionFixationCount) = iEvt;
                            % (Do not immediately set the event type here; we wait in case a regression occurs.)
                        else
                            % If the current fixation is NOT in the Ending region but we were collecting
                            % Ending region fixations, then a regression out of the Ending region has occurred.
                            if inEndRegion
                                % Mark the trial as a regression trial.
                                trialRegressionMap(currentTrial) = true;
                                % (Also, mark all events of this trial as regression trials if desired.)
                                for k = 1:length(EEG.event)
                                    if EEG.event(k).trial_number == currentTrial
                                        EEG.event(k).is_regression_trial = true;
                                    end
                                end
                                
                                % Update behavior codes for the stored Ending-region fixations:
                                % * For all fixations except the last one, use Behavior 02.
                                % * For the very last fixation (immediately before regression), use Behavior 03.
                                for j = 1:endRegionFixationCount
                                    fixIdx = endRegionFixations(j);
                                    condStr = sprintf('%02d', mod(EEG.event(fixIdx).condition_number, 100));
                                    if j == endRegionFixationCount
                                        % Behavior 3: immediately before regression
                                        EEG.event(fixIdx).type = sprintf('%s0403', condStr);
                                    else
                                        % Behavior 2: regression trial fixations leading up to the immediate one
                                        EEG.event(fixIdx).type = sprintf('%s0402', condStr);
                                    end
                                end
                                % Reset the Ending-region storage now that it has been processed.
                                inEndRegion = false;
                                endRegionFixationCount = 0;
                                endRegionFixations = [];
                            end
                        end
                        %% ======= End of ENDING region behavior coding =======

                    end
                end
            end
        end
    end
end

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

function currentWord = determine_word_region(event)
    % Determines which word label applies based on fixation x-coordinate and word boundaries.
    currentWord = '';
    if isfield(event, 'fix_avgpos_x')
        x = event.fix_avgpos_x;
        % Handle scientific notation and ensure numeric conversion
        if ischar(x)
            x = str2double(x);
        elseif iscell(x)
            x = str2double(x{1});
        end
    elseif isfield(event, 'px')
        x = event.px;
        if ischar(x)
            x = str2double(x);
        elseif iscell(x)
            x = str2double(x{1});
        end
    else
        return;
    end
    
    % Verify numeric conversion worked
    if isnan(x)
        fprintf('Warning: Could not convert x position to number: %s\n', mat2str(event.fix_avgpos_x));
        return;
    end
    
    word_bounds = event.word_boundaries;
    field_names = fieldnames(word_bounds);
    for i = 1:length(field_names)
        bounds = word_bounds.(field_names{i});
        if x >= bounds(1) && x <= bounds(2)
            currentWord = field_names{i};
            fprintf('  Found word %s for x=%f (bounds: %f to %f)\n', ...
                    currentWord, x, bounds(1), bounds(2));
            break;
        end
    end
end
