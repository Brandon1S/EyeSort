function EEG = compute_text_based_ia(EEG, varargin)
    %% COMPUTE_TEXT_BASED_IA - Computes text-based interest areas from a text file and integrates them with EEG data
    %
    % This function takes a text file containing reading stimuli organized by regions and maps
    % those regions onto EEG event data, allowing for region-based analysis of eye movement data.
    %
    % USAGE:
    %   Method 1 - Using config file:
    %   EEG = compute_text_based_ia(EEG, 'config_file', 'path/to/config.m')
    %   EEG = compute_text_based_ia(EEG, configFilePath)  % If first arg is .m file
    %
    %   Method 2 - Using individual parameters:
    %   EEG = compute_text_based_ia(EEG, txtFilePath, offset, pxPerChar, ...)
    %
    % INPUTS:
    %   EEG               - EEGLAB EEG structure or array of structures
    %   
    %   For config file method:
    %   configFilePath    - Path to .m config file containing all parameters
    %
    %   For individual parameters method:
    %   txtFilePath       - Path to tab-delimited text file containing reading stimuli
    %   offset            - Pixel offset for the start of text (e.g., screen margin in pixels)
    %   pxPerChar         - Pixels per character (used to calculate region widths)
    %   numRegions        - Number of regions in each stimulus
    %   regionNames       - Cell array of region names matching columns in text file
    %   conditionColName  - Name of condition column in text file
    %   itemColName       - Name of item column in text file
    %   startCode         - Event code that marks the start of a trial
    %   endCode           - Event code that marks the end of a trial
    %   conditionTriggers - Cell array of condition trigger codes
    %   itemTriggers      - Cell array of item trigger codes
    %   fixationType      - Type identifier for fixation events
    %   fixationXField    - Field name containing fixation X position
    %   saccadeType       - Type identifier for saccade events
    %   saccadeStartXField- Field name containing saccade start X position
    %   saccadeEndXField  - Field name containing saccade end X position
    %
    % OPTIONAL PARAMETERS:
    %   'batch_mode'      - true/false (default: false)
    %
    % OUTPUTS:
    %   EEG               - EEGLAB EEG structure with added interest area information
    
    % Determine if first argument is a config file or individual parameters
    if ~isempty(varargin)
        % Check if first argument is a config file (.m or .mat)
        if ischar(varargin{1}) && (endsWith(varargin{1}, '.m') || endsWith(varargin{1}, '.mat')) && exist(varargin{1}, 'file')
            % Config file method
            config_file = varargin{1};
            config = load_eyesort_config(config_file);
            
            % Extract parameters from config
            txtFilePath = config.txtFileList;
            if iscell(txtFilePath)
                txtFilePath = txtFilePath{1};
            end
            offset = str2double(config.offset);
            pxPerChar = str2double(config.pxPerChar);
            numRegions = str2double(config.numRegions);
            regionNames = config.regionNames;
            if ischar(regionNames)
                regionNames = strsplit(regionNames, ',');
                regionNames = strtrim(regionNames); % Remove whitespace
            end
            conditionColName = config.conditionColName;
            conditionTypeColName = config.conditionTypeColName;
            % Parse comma-separated condition type column names
            if ischar(conditionTypeColName)
                conditionTypeColName = strtrim(strsplit(conditionTypeColName, ','));
            end
            itemColName = config.itemColName;
            startCode = config.startCode;
            endCode = config.endCode;
            conditionTriggers = config.condTriggers;
            itemTriggers = config.itemTriggers;
            fixationType = config.fixationType;
            fixationXField = config.fixationXField;
            saccadeType = config.saccadeType;
            saccadeStartXField = config.saccadeStartXField;
            saccadeEndXField = config.saccadeEndXField;
            sentenceStartCode = config.sentenceStartCode;
            sentenceEndCode = config.sentenceEndCode;
            
            % Ensure trigger arrays are cell arrays - use helper only for complex ranges
            if ~iscell(conditionTriggers)
                conditionTriggers = expand_trigger_ranges(conditionTriggers);
            end
            if ~iscell(itemTriggers)
                itemTriggers = expand_trigger_ranges(itemTriggers);
            end
            
            % Ensure region names is a cell array
            if ~iscell(regionNames)
                if ischar(regionNames) || isstring(regionNames)
                    regionNames = strsplit(string(regionNames), ',');
                    regionNames = strtrim(regionNames);
                    regionNames = cellstr(regionNames); % Convert to cell array of chars
                end
            end
            
            % Parse any remaining optional parameters
            remaining_args = varargin(2:end);
            p = inputParser;
            addParameter(p, 'batch_mode', false, @islogical);
            parse(p, remaining_args{:});
            batch_mode = p.Results.batch_mode;
            
        else
            % Individual parameters method (original)
            if length(varargin) < 18
                error('compute_text_based_ia: Not enough input arguments. Either provide a config file or all individual parameters.');
            end
            
            txtFilePath = varargin{1};
            offset = varargin{2};
            pxPerChar = varargin{3};
            numRegions = varargin{4};
            regionNames = varargin{5};
            conditionColName = varargin{6};
            itemColName = varargin{7};
            startCode = varargin{8};
            endCode = varargin{9};
            conditionTriggers = varargin{10};
            itemTriggers = varargin{11};
            fixationType = varargin{12};
            fixationXField = varargin{13};
            saccadeType = varargin{14};
            saccadeStartXField = varargin{15};
            saccadeEndXField = varargin{16};
            sentenceStartCode = varargin{17};
            sentenceEndCode = varargin{18};
            conditionTypeColName = varargin{19};
            
            % Parse optional parameters
            remaining_args = varargin(20:end);
            p = inputParser;
            addParameter(p, 'batch_mode', false, @islogical);
            parse(p, remaining_args{:});
            batch_mode = p.Results.batch_mode;
        end
    else
        error('compute_text_based_ia: Either config file path or individual parameters must be provided.');
    end
    
    % Handle multiple datasets case - process each one individually
    if numel(EEG) > 1
        for idx = 1:numel(EEG)
            fprintf('\nProcessing dataset %d of %d...\n', idx, numel(EEG));
            currentEEG = EEG(idx); % Work with a single dataset
            
            % Process the current dataset
            currentEEG = process_single_dataset(currentEEG, txtFilePath, offset, pxPerChar, ...
                                              numRegions, regionNames, conditionColName, itemColName, ...
                                              startCode, endCode, conditionTriggers, itemTriggers, ...
                                              fixationType, fixationXField, saccadeType, saccadeStartXField, saccadeEndXField, ...
                                              sentenceStartCode, sentenceEndCode, conditionTypeColName);
            
            % Store back in the array - NO SAVING
            EEG(idx) = currentEEG;
        end
        fprintf('\nAll %d datasets processed successfully!\n', numel(EEG));
        return;
    end
    
    % Otherwise, process a single dataset
    EEG = process_single_dataset(EEG, txtFilePath, offset, pxPerChar, ...
                                              numRegions, regionNames, conditionColName, itemColName, ...
                                              startCode, endCode, conditionTriggers, itemTriggers, ...
                                              fixationType, fixationXField, saccadeType, saccadeStartXField, saccadeEndXField, ...
                                              sentenceStartCode, sentenceEndCode, conditionTypeColName);
end

function EEG = process_single_dataset(EEG, txtFilePath, offset, pxPerChar, ...
                                              numRegions, regionNames, conditionColName, itemColName, ...
                                              startCode, endCode, conditionTriggers, itemTriggers, ...
                                              fixationType, fixationXField, saccadeType, saccadeStartXField, saccadeEndXField, ...
                                              sentenceStartCode, sentenceEndCode, conditionTypeColName)
    %% PROCESS_SINGLE_DATASET - Core processing function for interest areas
    %
    % This function processes a single EEG dataset, performing the following steps:
    % 1. Validates input parameters
    % 2. Reads and parses the text file containing stimuli
    % 3. Computes region and word boundaries based on character count
    % 4. Assigns these boundaries to EEG events
    % 5. Labels trials and fixations with region information
    % 6. Stores metadata in the EEG structure for later use
    
    %% Step 1: Validate inputs and read the interest area text file
    if nargin < 20
        error('compute_text_based_ia_word_level: Not enough input arguments. Field names and sentence codes must be specified.');
    end
    
    % No default values - all field names must be provided by the user
    
    % Check if input file exists
    if ~exist(txtFilePath, 'file')
        error('The file "%s" does not exist.', txtFilePath);
    end

    % Check if region names match the specified number of regions
    if length(regionNames) ~= numRegions
        error('Number of regionNames (%d) does not match numRegions (%d).', ...
               length(regionNames), numRegions);
    end

    % Display the input parameters for verification
    fprintf('Input Parameters:\n');
    fprintf('Offset: %d, Pixels per char: %d\n', offset, pxPerChar);
    fprintf('Number of regions: %d\n', numRegions);
    fprintf('Region names: %s\n', strjoin(regionNames, ', '));
    fprintf('Condition column: %s, Item column: %s\n', conditionColName, itemColName);
    fprintf('Fixation event type: %s, X position field: %s\n', fixationType, fixationXField);
    fprintf('Saccade event type: %s, Start X field: %s, End X field: %s\n', saccadeType, saccadeStartXField, saccadeEndXField);

    %% Step 2: Read the text file and prepare the data
    % Set up import options for the tab-delimited file
    opts = detectImportOptions(txtFilePath, 'Delimiter', '\t');
    opts.VariableNamingRule = 'preserve';
    
    % Preserve whitespace in regions - important for word boundary detection
    for i = 1:length(regionNames)
        opts = setvaropts(opts, regionNames{i}, 'WhitespaceRule', 'preserve');
    end

    % Display detected columns for debugging
    fprintf('\nDetected column names in file:\n');
    disp(opts.VariableNames);
    
    % Read the data table
    data = readtable(txtFilePath, opts);
    fprintf('\nActual table column names after import:\n');
    disp(data.Properties.VariableNames);

    % Check for the condition and item columns, with flexible matching
    [conditionColName, foundCondCol] = findBestColumnMatch(data.Properties.VariableNames, conditionColName);
    [itemColName, foundItemCol] = findBestColumnMatch(data.Properties.VariableNames, itemColName);
    
    % Display helpful error information if columns are not found
    if ~foundCondCol
        fprintf('Could not find condition column "%s". Available columns:\n', conditionColName);
        disp(data.Properties.VariableNames);
        error('Condition column not found. Please check the column name.');
    end
    if ~foundItemCol
        fprintf('Could not find item column "%s". Available columns:\n', itemColName);
        disp(data.Properties.VariableNames);
        error('Item column not found. Please check the column name.');
    end

    fprintf('Using condition column: %s\n', conditionColName);
    fprintf('Using item column: %s\n', itemColName);



    %% Step 3: Calculate region and word boundaries for each stimulus
    % Create containers to store region and word boundary information
    % These maps use condition_item as keys to retrieve boundaries for specific trials
    boundaryMap = containers.Map('KeyType', 'char', 'ValueType', 'any');        % For region boundaries
    wordBoundaryMap = containers.Map('KeyType', 'char', 'ValueType', 'any');    % For word boundaries within regions
    regionWordsMap = containers.Map('KeyType', 'char', 'ValueType', 'any');     % For storing actual words in each region
    conditionDescMap = struct();   % For condition descriptions (BDF)
    conditionDescLookup = containers.Map(); % String descriptions by numeric code

    % Process each row (stimulus) in the text file
    fprintf('Processing %d rows of data...\n', height(data));
    
    % Add validation flag for space checking
    spaceValidationPassed = true;
    spaceValidationErrors = {};
    
    for iRow = 1:height(data)
        try
            % Create a unique key based on condition and item numbers
            key = sprintf('%d_%d', data.(conditionColName)(iRow), data.(itemColName)(iRow));
            
            % Initialize variables for this row
            currentPosition = offset;  % Start at the specified screen offset
            regionBoundaries = zeros(numRegions, 2);  % [start, end] for each region
            wordBoundaries = containers.Map('KeyType', 'char', 'ValueType', 'any');
            regionWords = struct();
            
            % Validate region spacing before processing boundaries
            for r = 1:numRegions
                % Get the text for this region
                regionText = data.(regionNames{r}){iRow};
                if iscell(regionText)
                    regionText = char(regionText);
                end
                
                % Check space requirement: all regions except the first should start with a space
                if r > 1 && ~isempty(regionText) && ~startsWith(regionText, ' ')
                    spaceValidationPassed = false;
                    errorMsg = sprintf('Row %d, Region %d (%s): Missing leading space. Text starts with "%s"', ...
                                     iRow, r, regionNames{r}, regionText(1:min(10, length(regionText))));
                    spaceValidationErrors{end+1} = errorMsg;
                elseif r == 1 && ~isempty(regionText) && startsWith(regionText, ' ')
                    spaceValidationPassed = false;
                    errorMsg = sprintf('Row %d, Region %d (%s): First region should not start with a space. Text starts with space', ...
                                     iRow, r, regionNames{r});
                    spaceValidationErrors{end+1} = errorMsg;
                end
            end
            
            % Process each region in the stimulus
            for r = 1:numRegions
                % Mark the start of this region
                regionStart = currentPosition;
                
                % Get the text for this region
                regionText = data.(regionNames{r}){iRow};
                if iscell(regionText)
                    regionText = char(regionText);
                end
                
                % Calculate region width in pixels based on character count
                regionWidth = pxPerChar * length(regionText);
                currentPosition = regionStart + regionWidth;
                
                % Store the region boundaries
                regionBoundaries(r,:) = [regionStart, currentPosition];
                
                % Extract words from the region text using regular expressions
                % This finds all sequences of non-whitespace with any preceding whitespace
                [wordStarts, wordEnds] = regexp(regionText, '(\s*\S+)', 'start', 'end');
                wordsInRegion = regexp(regionText, '(\s*\S+)', 'match');
                
                % Store the words in the region
                regionWords.(sprintf('region%d_words', r)) = wordsInRegion;
                
                % Calculate and store the boundary of each word in pixels
                for idx = 1:length(wordStarts)
                    wordKey = sprintf('%d.%d', r, idx);  % Format: "region.word_number"
                    
                    % Convert character positions to pixel positions
                    wordPixelStart = regionStart + (wordStarts(idx) - 1) * pxPerChar;
                    wordPixelEnd   = regionStart + wordEnds(idx) * pxPerChar;
                    
                    % Store the word boundaries
                    wordBoundaries(wordKey) = [wordPixelStart, wordPixelEnd];
                end
            end
            
            % Store all the calculated information for this stimulus
            boundaryMap(key) = regionBoundaries;
            wordBoundaryMap(key) = wordBoundaries;
            regionWordsMap(key) = regionWords;
            
            % Store condition description for BDF generation
            % Handle multiple condition columns (comma-separated)
            if iscell(conditionTypeColName)
                conditionColNames = conditionTypeColName;
            else
                conditionColNames = {conditionTypeColName};
            end
            
            condDescParts = {};
            for colIdx = 1:length(conditionColNames)
                colName = conditionColNames{colIdx};
                if isfield(data, colName)
                    colVal = data.(colName)(iRow);
                    if iscell(colVal), colVal = colVal{1}; end
                    condDescParts{end+1} = char(string(colVal));
                end
            end
            condDesc = strjoin(condDescParts, '_');
            % Get condition number for numeric storage
            conditionNum = data.(conditionColName)(iRow);
            if iscell(conditionNum), conditionNum = conditionNum{1}; end
            % Store numeric code instead of string to avoid 7.3 format
            validKey = matlab.lang.makeValidName(['k_' key]);
            conditionDescMap.(validKey) = conditionNum; % Store numeric code
            % Keep string lookup separate
            conditionDescLookup(num2str(conditionNum)) = condDesc;
        catch ME
            warning('Error processing row %d: %s', iRow, ME.message);
        end
    end
    
    % Check if space validation passed and report errors if any
    if ~spaceValidationPassed
        fprintf('\n=== REGION SPACING VALIDATION ERRORS ===\n');
        fprintf('Found %d spacing errors in the interest area text file:\n\n', length(spaceValidationErrors));
        for i = 1:length(spaceValidationErrors)
            fprintf('%d. %s\n', i, spaceValidationErrors{i});
        end
        fprintf('\nREQUIREMENT: All regions except the first should start with a space.\n');
        fprintf('The first region should NOT start with a space.\n');
        fprintf('Please fix these spacing issues in your text file and try again.\n');
        
        % Create detailed error message for the error dialog
        errorMsg = sprintf(['REGION SPACING VALIDATION ERRORS\n\n' ...
                           'Found %d spacing errors in the interest area text file:\n\n'], ...
                           length(spaceValidationErrors));
        
        % Add first few errors to the dialog (limit to avoid overly long dialogs)
        maxErrorsToShow = min(5, length(spaceValidationErrors));
        for i = 1:maxErrorsToShow
            errorMsg = [errorMsg sprintf('%d. %s\n', i, spaceValidationErrors{i})];
        end
        
        if length(spaceValidationErrors) > maxErrorsToShow
            errorMsg = [errorMsg sprintf('\n... and %d more errors (see command window for full list)\n', ...
                       length(spaceValidationErrors) - maxErrorsToShow)];
        end
        
        errorMsg = [errorMsg sprintf(['\nREQUIREMENT:\n' ...
                                     '• First region should NOT start with a space\n' ...
                                     '• All other regions SHOULD start with a space\n\n' ...
                                     'Please fix these spacing issues in your text file and try again.'])];
        
        error(errorMsg);
    end
    
    fprintf('Processed %d rows\n', height(data));

    %% Step 4: Assign region boundaries to EEG events
    % Initialize region and word boundary fields in all events
    [EEG.event.regionBoundaries] = deal([]);
    [EEG.event.word_boundaries] = deal([]);
    
    % Initialize region-specific fields in all events
    for r = 1:numRegions
        [EEG.event.(sprintf('region%d_start', r))] = deal(0);
        [EEG.event.(sprintf('region%d_end', r))] = deal(0);
        [EEG.event.(sprintf('region%d_name', r))] = deal('');
        [EEG.event.(sprintf('region%d_words', r))] = deal([]);
    end

    % Process EEG events to assign boundaries
    fprintf('Processing EEG events for boundary assignment...\n');
    numAssigned = 0;
    
    % Variables to track the current trial context
    currentItem = [];
    currentCond = [];
    trialRunning = false;
    lastValidKey = '';

    % Remove spaces from trigger codes for more flexible matching
    conditionTriggersNoSpace = cellfun(@(x) strrep(x, ' ', ''), conditionTriggers, 'UniformOutput', false);
    itemTriggersNoSpace = cellfun(@(x) strrep(x, ' ', ''), itemTriggers, 'UniformOutput', false);

    % Process each event in the EEG structure
    for iEvt = 1:length(EEG.event)
        eventType = EEG.event(iEvt).type;
        eventTypeNoSpace = strrep(eventType, ' ', '');
        
        % Check for trial start/end markers or trigger events
        if strcmp(eventTypeNoSpace, strrep(startCode, ' ', ''))
            % Trial start - reset tracking variables
            trialRunning = true;
            currentItem = [];
            currentCond = [];
            lastValidKey = '';
        elseif strcmp(eventTypeNoSpace, strrep(endCode, ' ', ''))
            % Trial end
            trialRunning = false;
        elseif trialRunning && startsWith(eventType, 'S')
            % This is a stimulus trigger event during an active trial
            
            % Check if it's an item trigger
            if any(strcmp(eventTypeNoSpace, itemTriggersNoSpace))
                currentItem = str2double(regexp(eventTypeNoSpace, '\d+', 'match', 'once'));
            % Check if it's a condition trigger
            elseif any(strcmp(eventTypeNoSpace, conditionTriggersNoSpace))
                currentCond = str2double(regexp(eventTypeNoSpace, '\d+', 'match', 'once'));
            end
            
            % If we have both condition and item, create a valid lookup key
            if ~isempty(currentItem) && ~isempty(currentCond)
                lastValidKey = sprintf('%d_%d', currentCond, currentItem);
            end
        end

                % If we're in a valid trial with a known stimulus, assign boundaries to events
        if trialRunning && ~isempty(lastValidKey)
            % Assign region boundaries if available for this stimulus
            if isKey(boundaryMap, lastValidKey)
                regionBoundaries = boundaryMap(lastValidKey);
                

                
                % Store the complete region boundaries matrix
                EEG.event(iEvt).regionBoundaries = regionBoundaries;
                
                % Store individual region boundaries for easier access
                for r = 1:numRegions
                    EEG.event(iEvt).(sprintf('region%d_start', r)) = regionBoundaries(r, 1);
                    EEG.event(iEvt).(sprintf('region%d_end', r)) = regionBoundaries(r, 2);
                    EEG.event(iEvt).(sprintf('region%d_name', r)) = regionNames{r};
                end
                
                % For fixation events, determine which region they fall within
                if startsWith(EEG.event(iEvt).type, 'R_fixation')
                    % Get the fixation position, trying different possible field names
                    if isfield(EEG.event(iEvt), 'fix_avgpos_x')
                        fix_pos_x = EEG.event(iEvt).fix_avgpos_x;
                    elseif isfield(EEG.event(iEvt), 'px')
                        fix_pos_x = EEG.event(iEvt).px;
                    else
                        warning('No x position field found for event %d. Skipping region assignment.', iEvt);
                        continue;
                    end
                    
                    % Handle different data types for position
                    if iscell(fix_pos_x)
                        fix_pos_x = fix_pos_x{1};
                    end
                    if ischar(fix_pos_x)
                        fix_pos_x = str2double(fix_pos_x);
                    end
                    if ~isnumeric(fix_pos_x) || isnan(fix_pos_x)
                        warning('Invalid fix_avgpos_x at event %d. Skipping event.', iEvt);
                        continue;
                    end
                    
                    % Determine which region contains this fixation position
                    for r = 1:numRegions
                        region_start = regionBoundaries(r, 1);
                        region_end = regionBoundaries(r, 2);
                        if fix_pos_x >= region_start && fix_pos_x <= region_end
                            EEG.event(iEvt).current_region = r;
                            break;
                        end
                    end
                end
                numAssigned = numAssigned + 1;
            end

            % Assign region words if available
            if isKey(regionWordsMap, lastValidKey)
                regionWords = regionWordsMap(lastValidKey);
                for r = 1:numRegions
                    EEG.event(iEvt).(sprintf('region%d_words', r)) = regionWords.(sprintf('region%d_words', r));
                end
            end

            % Assign word boundaries if available
            if isKey(wordBoundaryMap, lastValidKey)
                wordBounds = struct();
                wordKeys = wordBoundaryMap(lastValidKey).keys;
                for j = 1:length(wordKeys)
                    currentKey = wordKeys{j};
                    validField = matlab.lang.makeValidName(currentKey);
                    currentMap = wordBoundaryMap(lastValidKey);
                    currentBounds = currentMap(currentKey);
                    wordBounds.(validField) = currentBounds;
                end
                EEG.event(iEvt).word_boundaries = wordBounds;
            end
        end
    end

    fprintf('Finished processing EEG events. Assigned boundaries to %d events.\n', numAssigned);

    %% Step 5: Perform detailed trial labeling
    % This calls trial_labeling function to identify first-pass reading, regressions, etc.
    fprintf('Performing trial labeling (identifying first-pass reading, regressions, etc.)...\n');
    EEG = trial_labeling(EEG, startCode, endCode, conditionTriggers, itemTriggers, ...
                             fixationType, fixationXField, saccadeType, saccadeStartXField, saccadeEndXField, ...
                             sentenceStartCode, sentenceEndCode);

    %% Step 6: Store metadata for use by other functions
    % Store field names in the EEG structure
    EEG.eyesort_field_names = struct();
    EEG.eyesort_field_names.fixationType = fixationType;
    EEG.eyesort_field_names.fixationXField = fixationXField;
    EEG.eyesort_field_names.saccadeType = saccadeType;
    EEG.eyesort_field_names.saccadeStartXField = saccadeStartXField;
    EEG.eyesort_field_names.saccadeEndXField = saccadeEndXField;
    
    % Store the region names for use by other functions
    EEG.region_names = regionNames;
    
    % Store condition description struct for BDF generation during labeling
    EEG.eyesort_condition_descriptions = conditionDescMap;
    EEG.eyesort_condition_lookup = conditionDescLookup;

    % Add a custom field to track processing status
    EEG.eyesort_processed = true;
    
    % Ensure EEG structure has required fields for EEGLAB compatibility
    if ~isfield(EEG, 'saved')
        EEG.saved = 'no';
    end
    if ~isfield(EEG, 'filename')
        EEG.filename = '';
    end
    if ~isfield(EEG, 'filepath')
        EEG.filepath = '';
    end
    
    fprintf('\nProcessing complete! You can now Label the dataset using the Label Datasets option in the EyeSort menu.\n');
end

%% Helper function: findBestColumnMatch
function [bestMatch, found] = findBestColumnMatch(availableColumns, requestedColumn)
    % FINDBESTCOLUMNMATCH - Finds the best match for a column name in a dataset
    %
    % This function tries to match a requested column name with available columns,
    % handling case differences and special characters like '$'.
    %
    % INPUTS:
    %   availableColumns - Cell array of available column names
    %   requestedColumn  - String with the requested column name
    %
    % OUTPUTS:
    %   bestMatch - The best matching column name found
    %   found     - Boolean indicating if a match was found
    
    % Check for exact match first
    if ismember(requestedColumn, availableColumns)
        bestMatch = requestedColumn;
        found = true;
        return;
    end
    
    % Check for match with/without '$' prefix
    if startsWith(requestedColumn, '$')
        altColumn = requestedColumn(2:end);
    else
        altColumn = ['$' requestedColumn];
    end
    if ismember(altColumn, availableColumns)
        bestMatch = altColumn;
        found = true;
        return;
    end
    
    % Check for case-insensitive match
    for i = 1:length(availableColumns)
        if strcmpi(requestedColumn, availableColumns{i})
            bestMatch = availableColumns{i};
            found = true;
            return;
        end
    end
    
    % No match found
    bestMatch = requestedColumn;
    found = false;
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
