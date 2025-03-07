function EEG = compute_pixel_based_ia(EEG, txtFilePath, ...
                                      numRegions, regionNames, ...
                                      regionStartNames, regionWidthNames, ...
                                      regionYTopNames, regionYBottomNames, ...
                                      conditionColName, itemColName)
% COMPUTE_PIXEL_BASED_IA - Load pre-calculated pixel-based regions of interest (ROIs)
%                          for each condition and item, then attach them to EEG.event.
%
% Usage:
%   >> EEG = compute_pixel_based_ia(EEG, txtFilePath, ...
%                                   numRegions, regionNames, ...
%                                   regionStartNames, regionWidthNames, ...
%                                   regionYTopNames, regionYBottomNames, ...
%                                   conditionColName, itemColName);
%
% Inputs:
%   EEG                - EEGLAB EEG structure to be updated (contains EEG.event)
%   txtFilePath        - Path to the .txt/.csv file with pixel IA definitions
%   numRegions         - Number of pixel-defined regions for each trial
%   regionNames        - Cell array of region labels (e.g. {'R1','R2','R3',...})
%   regionStartNames   - Cell array of col names for region left X (start positions)
%   regionWidthNames   - Cell array of col names for region widths (so right = left + width)
%   regionYTopNames    - Cell array of col names for region top Y
%   regionYBottomNames - Cell array of col names for region bottom Y
%   conditionColName   - Name of the condition column in the file (e.g. 'trigcondition')
%   itemColName        - Name of the item column in the file (e.g. 'trigitem')
%
% Outputs:
%   EEG - Updated EEG structure with new fields in EEG.event for each
%         fixation/saccade (or whichever events you choose) to indicate the
%         pixel boundaries of the interest areas:
%          - regionBoundaries  (Nx4 matrix)
%          - region1_start, region1_end, region1_name
%          - region2_start, region2_end, region2_name
%          - etc.

% -------------------------------
% 1) Validate inputs
% -------------------------------
if nargin < 10
    error(['compute_pixel_based_ia: Not enough input arguments. ', ...
           'Check the function signature.']);
end
if isempty(EEG)
    error('EEG is empty. Cannot proceed.');
end
if ~isfield(EEG, 'event') || isempty(EEG.event)
    error('EEG.event is missing or empty. Cannot proceed without event data.');
end

% Check file existence
if ~exist(txtFilePath, 'file')
    error('The file "%s" does not exist.', txtFilePath);
end

% Check region name counts
if length(regionNames) ~= numRegions
    error(['Number of regionNames (%d) does not match numRegions (%d).'], ...
           length(regionNames), numRegions);
end
if length(regionStartNames) ~= numRegions
    error('Length of regionStartNames must match numRegions.');
end
if length(regionWidthNames) ~= numRegions
    error('Length of regionWidthNames must match numRegions.');
end
% Y top/bottom may be optional, but if you are including them, they must match
if length(regionYTopNames) ~= numRegions
    error('Length of regionYTopNames must match numRegions.');
end
if length(regionYBottomNames) ~= numRegions
    error('Length of regionYBottomNames must match numRegions.');
end

% -------------------------------
% 2) Read IA definitions file
% -------------------------------
fprintf('Step 1: Reading IA file and defining regions...\n');

try
    % Read table with preserved variable names
    opts = detectImportOptions(txtFilePath);
    opts.VariableNamingRule = 'preserve';
    dataTable = readtable(txtFilePath, opts);

    % Convert trigger values to numbers and create all possible combinations
    if iscell(dataTable.trigcondition) && iscell(dataTable.trigitem)
        % Extract numbers from conditions and items
        conditions = cellfun(@(x) str2double(regexp(char(x), '\d+', 'match')), ...
                           dataTable.trigcondition, 'UniformOutput', false);
        items = cellfun(@(x) str2double(regexp(regexprep(char(x), '\s+', ''), '\d+', 'match')), ...
                       dataTable.trigitem, 'UniformOutput', false);
        
        % Create expanded table with all condition-item combinations
        expandedTable = create_all_combinations(dataTable, conditions, items);
        dataTable = expandedTable;
    end

    % Validate required columns
    requiredCols = [ {conditionColName}, {itemColName}, ...
                     regionStartNames, regionWidthNames, ...
                     regionYTopNames, regionYBottomNames ];
    missingCols = setdiff(requiredCols, dataTable.Properties.VariableNames);
    if ~isempty(missingCols)
        error('Missing required columns: %s', strjoin(missingCols, ', '));
    end

    % Build boundaryMap
    boundaryMap = buildBoundaryMap(dataTable, numRegions, regionStartNames, regionWidthNames, ...
                                   regionYTopNames, regionYBottomNames, ...
                                   conditionColName, itemColName);

catch ME
    warning(ME.identifier, '%s', ME.message);
end

% -------------------------------
% 2) Prompt User for Trial and Trigger Information
% -------------------------------
fprintf('Step 2: Prompting user for trial and trigger information...\n');

% Create GUI pop-up to collect Start and End Trial Triggers, Condition Triggers, and Item Triggers
userInput = inputdlg({'Start Trial Trigger:', ...
                      'End Trial Trigger:', ...
                      'Condition Triggers (comma-separated):', ...
                      'Item Triggers (comma-separated):'}, ...
                     'Input Trial/Trigger Information', ...
                     [1 50; 1 50; 1 50; 1 50], ...
                     {'S254', 'S255', 'S224, S213, S221', 'S39, S8, S152'});

if isempty(userInput)
    error('compute_pixel_based_ia: User cancelled input. Exiting function.');
end

startCode = userInput{1};
endCode = userInput{2};
conditionTriggers = strsplit(userInput{3}, ',');
itemTriggers = strsplit(userInput{4}, ',');

% -------------------------------
% 3) Process events and assign boundaries
% -------------------------------
fprintf('Step 3: Processing events and assigning boundaries...\n');

nEvents = length(EEG.event);
trialRunning = false;
currentItem = [];
currentCond = [];
numAssigned = 0;

for iEvt = 1:nEvents
    eventType = EEG.event(iEvt).type;
    
    % Convert numeric event types to strings
    if isnumeric(eventType)
        eventType = num2str(eventType);
    end
    
    % Detect start of trial
    if strcmp(eventType, startCode)
        trialRunning = true;
        currentItem = [];
        currentCond = [];
        continue;
    end
    
    % Detect end of trial
    if strcmp(eventType, endCode)
        trialRunning = false;
        continue;
    end
    
    % Process events within a trial
    if trialRunning
        % Remove all spaces for comparison
        eventTypeNoSpace = regexprep(eventType, '\s+', '');
        itemTriggersNoSpace = cellfun(@(x) regexprep(x, '\s+', ''), itemTriggers, 'UniformOutput', false);
        conditionTriggersNoSpace = cellfun(@(x) regexprep(x, '\s+', ''), conditionTriggers, 'UniformOutput', false);
        
        % Compare without spaces
        if any(strcmp(eventTypeNoSpace, itemTriggersNoSpace))
            % Extract just the number
            currentItem = str2double(regexp(eventTypeNoSpace, '\d+', 'match', 'once'));
        
        elseif any(strcmp(eventTypeNoSpace, conditionTriggersNoSpace))
            % Extract just the number
            currentCond = str2double(regexp(eventTypeNoSpace, '\d+', 'match', 'once'));
        
        elseif startsWith(eventType, 'R_fixation') || startsWith(eventType, 'R_saccade')
            % Assign pixel boundaries if both condition and item are known
            if ~isempty(currentItem) && ~isempty(currentCond)
                key = sprintf('%d_%d', currentCond, currentItem);
                
                if isKey(boundaryMap, key)
                    regionBoundaries = boundaryMap(key);
                    
                    % Store the full boundaries matrix
                    EEG.event(iEvt).regionBoundaries = regionBoundaries;
                    
                    % Store individual region information
                    for r = 1:numRegions
                        % Store x coordinates
                        EEG.event(iEvt).(sprintf('region%d_start', r)) = regionBoundaries(r,1);  % xStart
                        EEG.event(iEvt).(sprintf('region%d_end', r)) = regionBoundaries(r,2);    % xEnd
                        
                        % Store y coordinates
                        EEG.event(iEvt).(sprintf('region%d_top', r)) = regionBoundaries(r,3);    % yTop
                        EEG.event(iEvt).(sprintf('region%d_bottom', r)) = regionBoundaries(r,4); % yBottom
                        
                        % Store region name
                        EEG.event(iEvt).(sprintf('region%d_name', r)) = regionNames{r};
                    end
                    
                    numAssigned = numAssigned + 1;
                end
            end
        end
    end
end

fprintf('Done. Assigned boundaries to %d events.\n', numAssigned);

% Label trials with first-pass reading information
try
    EEG = trial_labeling(EEG, startCode, endCode, conditionTriggers, itemTriggers);
catch ME
    warning('Error in trial labeling: %s', ME.message);
end

% Optionally, rename the dataset or run eeg_checkset
% EEG.setname = [EEG.setname, '_pixel_IA'];
% EEG = eeg_checkset(EEG);

end % compute_pixel_based_ia


% -------------------------------------------------------------------------
% Helper Function: Build boundary map from the data table
%   key = "cond_item", value = Nx4 matrix of [left, right, top, bottom]
% -------------------------------------------------------------------------
function boundaryMap = buildBoundaryMap(dataTable, numRegions, ...
                                        regionStartNames, regionWidthNames, ...
                                        regionYTopNames, regionYBottomNames, ...
                                        conditionColName, itemColName)
    boundaryMap = containers.Map('KeyType','char','ValueType','any');
    
    for iRow = 1:height(dataTable)
        condCode = convertToNumeric(dataTable{iRow, conditionColName});
        itemCode = convertToNumeric(dataTable{iRow, itemColName});

        if isnan(condCode) || isnan(itemCode)
            continue;
        end

        regionMatrix = zeros(numRegions,4);
        for r = 1:numRegions
            % Extract X coordinate from location string like "(281.00, 514.00)"
            locStr = dataTable{iRow, regionStartNames{r}};
            leftX = extractXCoordinate(locStr);
            width = convertToNumeric(dataTable{iRow, regionWidthNames{r}});
            topY = convertToNumeric(dataTable{iRow, regionYTopNames{r}});
            botY = convertToNumeric(dataTable{iRow, regionYBottomNames{r}});

            if any(isnan([leftX, width, topY, botY]))
                fprintf('Row %d, Region %d has invalid data:\n', iRow, r);
                fprintf('  Left X: %s\n', mat2str(locStr));
                fprintf('  Width: %s\n', mat2str(dataTable{iRow, regionWidthNames{r}}));
                fprintf('  Top Y: %s\n', mat2str(dataTable{iRow, regionYTopNames{r}}));
                fprintf('  Bottom Y: %s\n', mat2str(dataTable{iRow, regionYBottomNames{r}}));
                continue;
            end

            rightX = leftX + width;
            regionMatrix(r,:) = [leftX, rightX, topY, botY];
        end

        key = sprintf('%d_%d', condCode, itemCode);
        boundaryMap(key) = regionMatrix;
    end
end

function val = convertToNumeric(input)
    if iscell(input)
        input = input{1};
    end
    if isnumeric(input)
        val = input;
    else
        val = str2double(input);
    end
    if isempty(val) || isnan(val)
        val = NaN;
    end
end

function xCoord = extractXCoordinate(locString)
    if iscell(locString)
        locString = locString{1};
    end
    
    % Handle string format "(X.XX, Y.YY)"
    try
        % Extract first number from the string
        numbers = regexp(locString, '[-\d.]+', 'match');
        if ~isempty(numbers)
            xCoord = str2double(numbers{1});
        else
            xCoord = NaN;
        end
    catch
        xCoord = NaN;
    end
end

% Helper function to create all possible condition-item combinations
function expandedTable = create_all_combinations(table, conditions, items)
    % Calculate total number of combinations
    totalCombos = sum(cellfun(@length, conditions) .* cellfun(@length, items));
    
    % Preallocate array
    allRows = cell(totalCombos, 1);
    currentRow = 1;
    
    % For each row in the original table
    for i = 1:height(table)
        rowConditions = conditions{i};
        rowItems = items{i};
        
        % Create all possible combinations for this row
        for j = 1:length(rowConditions)
            for k = 1:length(rowItems)
                % Copy the entire row
                newRow = table(i,:);
                % Update condition and item
                newRow.trigcondition = rowConditions(j);
                newRow.trigitem = rowItems(k);
                % Store the new row
                allRows{currentRow} = newRow;
                currentRow = currentRow + 1;
            end
        end
    end
    
    % Combine all rows into a new table
    expandedTable = vertcat(allRows{:});
end
