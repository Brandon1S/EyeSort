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
        {'Style','edit','String','50','tag','edtOffset'}, ...
        ...
        {'Style','text','String','Pixels per char:' }, ...
        {'Style','edit','String','10','tag','edtPxPerChar'}, ...
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
        {}, ...
        ... % Cancel and Enter buttons
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

        % Call compute_text_based_ia with validated inputs
        try
            EEG = compute_text_based_ia(EEG, txtFilePath, offset, pxPerChar, ...
                                      numRegions, regionNames, conditionColName, ...
                                      itemColName);
        catch ME
            errordlg(['Error in compute_text_based_ia: ' ME.message], 'Error');
            return;
        end

        % Store back to base workspace
        assignin('base', 'EEG', EEG);
        %fprintf('Debug: Stored updated EEG back to workspace\n');

        % Build command string for history
        com = sprintf('EEG = pop_loadTextIA(EEG); %% file=%s offset=%g px=%g',...
                     txtFilePath, offset, pxPerChar);

        % Close GUI, redraw EEGLAB
        close(gcf);
        eeglab('redraw');
    end
end




