function [EEG, com] = pop_load_text_ia(EEG)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %                          Option 1:                              %            
    %         Text based sentence contents for each interest area.    %
    %                (For single line reading studies)                %
    %                                                                 %
    %                                                                 %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Initialize outputs (good practice for pop functions)
    com = '';
    if nargin < 1
        EEG = eeg_emptyset;
    end
    
    txtFileList = {};
    
    geomhoriz = { ...
        [1 0.5]
        1
        1
        [2 1] 
        [2 1]
        [2 1]
        [0.4 1]
        [2 1]
        [2 1]
        [2 1]       % New line for Start Code
        [2 1]       % New line for End Code
        [2 1]       % New line for Condition Triggers
        [2 1]       % New line for Item Triggers
        1
        [0.5 0.2 0.2]
    };

    % Labels and dropdown menu
    uilist = { ...
        
        {'Style','text','String','Text File:'}, ...
        {'Style','pushbutton','String','Browse','callback', @browseTxtFile}, ...
        ...
        {'Style', 'listbox', 'tag', 'datasetList', 'string', {}, 'Max', 10, 'Min', 1, 'HorizontalAlignment', 'left'}, ...
        ...
        {}, ...
        ... 
        {'Style','text','String','Offset (pixels):'}, ...
        {'Style','edit','String','281','tag','edtOffset'}, ...
        ...
        {'Style','text','String','Pixels per char:' }, ...
        {'Style','edit','String','14','tag','edtPxPerChar'}, ...
        ...
        {'Style','text','String','Number of regions:'}, ...
        {'Style','edit','String','4','tag','edtNumRegions'}, ...
        ...
        {'Style','text','String','Region Names (separate by comma):'}, ...
        {'Style','edit','String','Beginning,PreTarget,Target_word,Ending','tag','edtRegionNames'}, ...
        ...
        {'Style','text','String','Condition Column Name:'}, ...
        {'Style','edit','String','trigcondition','tag','edtCondName'}, ...
        ...
        {'Style','text','String','Item Column Name:'}, ...
        {'Style','edit','String','trigitem','tag','edtItemName'}, ...
        ...
        {'Style','text','String','Start Trial Code:'}, ...
        {'Style','edit','String','S254','tag','edtStartCode'}, ...
        ...
        {'Style','text','String','End Trial Code:'}, ...
        {'Style','edit','String','S255','tag','edtEndCode'}, ...
        ...
        {'Style','text','String','Condition Triggers (comma-separated):'}, ...
        {'Style','edit','String','S211, S213, S221, S223','tag','edtCondTriggers'}, ...
        ...
        {'Style','text','String','Item Triggers (comma-separated):'}, ...
        {'Style','edit','String','S1:S112','tag','edtItemTriggers'}, ...
        ...
        {}, ...
        ...
        {}, ...
        {'Style', 'pushbutton', 'String', 'Cancel', 'callback', @(~,~) cancel_button}, ...
        {'Style', 'pushbutton', 'String', 'Confirm', 'callback', @(~,~) confirm_button}, ...
    };

     [~, ~, ~, ~] = supergui('geomhoriz', geomhoriz, 'uilist', uilist, 'title', 'Load Text IA');

     % ---------- Nested Callback Functions -----------------
    % We'll store the chosen file path in a variable:
    

    function browseTxtFile(~,~)
        [fname, fpath] = uigetfile({'*.txt';'*.csv'}, 'Select IA Text File');
        if isequal(fname,0)
            return; % user cancelled
        end
        filePath = fullfile(fpath,fname);

        txtFileList = { filePath };

        set(findobj(gcf, 'tag','datasetList'), 'string', txtFileList, 'value',1);
        % Optionally, show the filename in the GUI somewhere if you like.
    end

    function cancel_button(~,~)
        close(gcf);
        disp('User selected cancel: No text file for text interest areas');
    end

    function confirm_button(~,~)
        % Get current EEG from base workspace
        try
            EEG = evalin('base', 'EEG');
            %{
            fprintf('Debug: Retrieved EEG from base workspace\n');
            fprintf('Debug: Number of events in retrieved EEG: %d\n', length(EEG.event));
            %}
        catch ME
            %fprintf('Debug: Error retrieving EEG: %s\n', ME.message);
            errordlg('No EEG dataset loaded in EEGLAB.', 'Error');
            return;
        end
        
        % Gather parameters from GUI and ensure proper type conversion
        offsetStr = get(findobj('tag','edtOffset'), 'String');
        pxPerCharStr = get(findobj('tag','edtPxPerChar'), 'String');
        numRegionsStr = get(findobj('tag','edtNumRegions'), 'String');
        
        % Convert cell arrays to strings if necessary
        if iscell(offsetStr), offsetStr = offsetStr{1}; end
        if iscell(pxPerCharStr), pxPerCharStr = pxPerCharStr{1}; end
        if iscell(numRegionsStr), numRegionsStr = numRegionsStr{1}; end

        %{
        % Debug raw values
        fprintf('Debug: Raw input values:\n');
        fprintf('offsetStr: %s\n', offsetStr);
        fprintf('pxPerCharStr: %s\n', pxPerCharStr);
        fprintf('numRegionsStr: %s\n', numRegionsStr);
        %}
        
        % Convert to numbers and validate
        offset = str2double(offsetStr);
        pxPerChar = str2double(pxPerCharStr);
        numRegions = str2double(numRegionsStr);
        
        % Validate numeric conversions
        if any(isnan([offset, pxPerChar, numRegions])) || ...
           ~isscalar(offset) || ~isscalar(pxPerChar) || ~isscalar(numRegions)
            errordlg('Invalid numeric input for offset, pixels per char, or number of regions', 'Invalid Input');
            return;
        end
        
        % Ensure numRegions is a positive integer
        numRegions = floor(abs(numRegions));
        if numRegions <= 0
            errordlg('Number of regions must be positive', 'Invalid Input');
            return;
        end

        %{
        % Debug the numeric values
        fprintf('Debug: Converted numeric values:\n');
        fprintf('offset: %d (class: %s)\n', offset, class(offset));
        fprintf('pxPerChar: %d (class: %s)\n', pxPerChar, class(pxPerChar));
        fprintf('numRegions: %d (class: %s)\n', numRegions, class(numRegions));
        %}
        
        regionNamesStr = get(findobj('tag','edtRegionNames'), 'String');
        conditionColName = get(findobj('tag','edtCondName'), 'String');
        itemColName = get(findobj('tag','edtItemName'), 'String');
        
        % Convert cell arrays to strings if necessary
        if iscell(regionNamesStr), regionNamesStr = regionNamesStr{1}; end
        if iscell(conditionColName), conditionColName = conditionColName{1}; end
        if iscell(itemColName), itemColName = itemColName{1}; end
        
        % Process region names
        if ischar(regionNamesStr)
            regionNames = strtrim(strsplit(regionNamesStr, ','));
            %{
            fprintf('Debug: Split into %d region names\n', length(regionNames));
            fprintf('Debug: Region names: %s\n', strjoin(regionNames, ', '));
            %}
        else
            errordlg('Region names must be a comma-separated string.', 'Invalid Input');
            return;
        end
        
        % Validate region names match number of regions
        if length(regionNames) ~= numRegions
            errordlg(sprintf('Number of region names (%d) does not match number of regions (%d)', ...
                    length(regionNames), numRegions), 'Invalid Input');
            return;
        end

        % Validate the user selected a file
        if isempty(txtFileList)
            errordlg('No text file selected. Please browse for a file.','File Missing');
            return;
        end

        % If only one file is expected, take the first cell
        txtFilePath = txtFileList{1};

        %{
        fprintf('Debug: About to call compute_text_based_ia\n');
        fprintf('Debug: Number of events before call: %d\n', length(EEG.event));
        %}

        % Get new parameters from GUI
        startCodeStr = get(findobj('tag','edtStartCode'), 'String');
        endCodeStr = get(findobj('tag','edtEndCode'), 'String');
        condTriggersStr = get(findobj('tag','edtCondTriggers'), 'String');
        itemTriggersStr = get(findobj('tag','edtItemTriggers'), 'String');
        
        % Convert cell arrays to strings if necessary
        if iscell(startCodeStr), startCodeStr = startCodeStr{1}; end
        if iscell(endCodeStr), endCodeStr = endCodeStr{1}; end
        if iscell(condTriggersStr), condTriggersStr = condTriggersStr{1}; end
        if iscell(itemTriggersStr), itemTriggersStr = itemTriggersStr{1}; end
        
        % Parse comma-separated lists into cell arrays
        condTriggers = strtrim(strsplit(condTriggersStr, ','));
        
        % Special handling for item triggers with range notation (e.g., "S1:S112")
        itemTriggers = {};
        itemParts = strtrim(strsplit(itemTriggersStr, ','));
        
        for i = 1:length(itemParts)
            currentPart = itemParts{i};
            
            % Check if this part contains a range (e.g., "S1:S112")
            if contains(currentPart, ':')
                rangeParts = strsplit(currentPart, ':');
                if length(rangeParts) == 2
                    % Extract the numeric parts from the range (e.g., "1" and "112" from "S1:S112")
                    startStr = rangeParts{1};
                    endStr = rangeParts{2};
                    
                    % Extract the prefix (e.g., "S") and the numbers
                    startPrefix = regexp(startStr, '^[^0-9]*', 'match', 'once');
                    endPrefix = regexp(endStr, '^[^0-9]*', 'match', 'once');
                    
                    startNum = str2double(regexp(startStr, '[0-9]+', 'match', 'once'));
                    endNum = str2double(regexp(endStr, '[0-9]+', 'match', 'once'));
                    
                    % Validate the range
                    if isnan(startNum) || isnan(endNum) || startNum > endNum
                        errordlg(['Invalid item range: ' currentPart], 'Invalid Input');
                        return;
                    end
                    
                    % Use the prefix from the start if both have prefixes
                    prefix = startPrefix;
                    if isempty(prefix) && ~isempty(endPrefix)
                        prefix = endPrefix;
                    end
                    
                    % Generate all items in the range
                    for j = startNum:endNum
                        itemTriggers{end+1} = [prefix num2str(j)];
                    end
                    
                    fprintf('Expanded range %s to %d item triggers\n', currentPart, endNum-startNum+1);
                else
                    % Invalid range format
                    errordlg(['Invalid range format: ' currentPart], 'Invalid Input');
                    return;
                end
            else
                % Not a range, add as is
                itemTriggers{end+1} = currentPart;
            end
        end
        
        % Display the expanded item triggers for verification
        if length(itemTriggers) > 10
            fprintf('Generated %d item triggers: %s ... %s\n', length(itemTriggers), ...
                    strjoin(itemTriggers(1:5), ', '), strjoin(itemTriggers(end-4:end), ', '));
        else
            fprintf('Generated item triggers: %s\n', strjoin(itemTriggers, ', '));
        end

        % Call the computational function with all parameters
        try
            processedEEG = new_combined_compute_text_based_ia(EEG, txtFilePath, offset, pxPerChar, ...
                                      numRegions, regionNames, conditionColName, ...
                                      itemColName, startCodeStr, endCodeStr, condTriggers, itemTriggers);
            
            % Store processed data back to base workspace
            assignin('base', 'EEG', processedEEG);
            EEG = processedEEG; % Keep a local copy for passing to filter GUI

            % Update command string for history
            com = sprintf('EEG = pop_loadTextIA(EEG); %% file=%s offset=%g px=%g',...
                     txtFilePath, offset, pxPerChar);

            % Close GUI
            close(gcf);
            
            % Redraw EEGLAB to reflect changes
            eeglab('redraw');
            
        catch ME
            errordlg(['Error: ' ME.message], 'Error');
            return;
        end
    end
end




