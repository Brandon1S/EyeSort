function [EEG, com] = pop_load_pixel_ia(EEG)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %                          Option 2:                              %            
    %         Interest Area pixel locations for each interest area    %
    %                                                                 %
    %                                                                 %
    %                                                                 %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Initialize outputs (good practice for pop functions)
    com = '';
    if nargin < 1
        EEG = [];
    end
    
    txtFileList = {};

    % Creates the figure
    hFig = figure('Name','Load pixel IA', ...
                  'NumberTitle','off', ...
                  'MenuBar','none', ...
                  'ToolBar','none', ...
                  'Color',[0.94 0.94 0.94], ...
                  'Resize', 'off');
    
    geomhoriz = { ...
        [1 0.5] % Load text file with IA pixel boundaries: and browse button
        1       % String for pixel location file selected
        1       % List box for text file
        [1 1 1]   % Remove selected and clear all
        1
        [1 1]
        [0.4 1]
        [0.4 1]
        [0.4 1]
        [0.4 1]
        [0.4 1]
        [1 1]
        [1 1]
        1
        [0.5 0.2 0.2]
    };

    
    uilist = { ...
        
        {'Style','text','String','Load text file with IA pixel boundaries:'}, ...
        {'Style','pushbutton','String','Browse','callback', @browseTxtFile}, ...
        ...
        {'Style','text','String','Pixel location file selected:'}, ...
        ...
        {'Style', 'listbox', 'tag', 'iaTextFile', 'string', {}, 'Max', 10, 'Min', 1, 'HorizontalAlignment', 'left'}, ...
        ...
        {'Style', 'pushbutton', 'string', 'Remove Selected', 'callback', @remove_selected}, ...
        {}, {}, ...
        ...
        {}, ...
        ... 
        {'Style','text','String','Number of regions:'}, ...
        {'Style','edit','String','4','tag','NumRegions'}, ...
        ...
        {'Style','text','String','Region names:'}, ...
        {'Style', 'edit', 'String', 'Beginning, PreTarget, Target_word, Ending', 'tag', 'regionNames'}, ...
        ...
        {'Style','text','String','Region start (left) names:' }, ...
        {'Style','edit','String','Reg1Loc, Reg2Loc, Reg3Loc, Reg4Loc','tag','pixelStart'}, ...    
        ...
        {'Style','text','String','Region width names:'}, ...
        {'Style','edit','String','Reg1Width, Reg2Width, Reg3Width, Reg4Width','tag','pixelWidth'}, ...
        ...
        {'Style','text','String','Region Y top names (optional):'}, ...
        {'Style','edit','String','Reg1_upper_y, Reg2_upper_y, Reg3_upper_y, Reg4_upper_y','tag','pixelTop'}, ...
        ...
        {'Style','text','String','Region Y bottom names (optional):'}, ...
        {'Style','edit','String','Reg1_bottom_y, Reg2_bottom_y, Reg3_bottom_y, Reg4_bottom_y','tag','pixelBottom'}, ...
        ...
        {'Style','text','String','Condition Column Name:'}, ...
        {'Style','edit','String','trigcondition','tag','edtCondName'}, ...
        ...
        {'Style','text','String','Item Column Name:'}, ...
        {'Style','edit','String','trigitem','tag','edtItemName'}, ...
        ...
        {}, ...
        ... 
        {}, ...
        {'Style', 'pushbutton', 'String', 'Cancel', 'callback', @cancel_button}, ...
        {'Style', 'pushbutton', 'String', 'Confirm', 'callback', @confirm_button}, ...
    };

    supergui('fig', hFig, 'geomhoriz', geomhoriz, 'uilist', uilist, 'title', 'Load Pixel IA');

     % ---------- Nested Callback Functions -----------------
    
    function browseTxtFile(~,~)
        [fname, fpath] = uigetfile({'*.txt';'*.csv'}, 'Select IA Text File');
        if isequal(fname,0)
            return; % user cancelled
        end
        filePath = fullfile(fpath,fname);
        
        % Update the txtFileList in the parent scope
        txtFileList{1} = filePath;  % Changed from local txtFile to parent txtFileList
        
        % Update the listbox
        hList = findobj(gcf, 'tag', 'iaTextFile');
        set(hList, 'string', txtFileList, 'value', 1);
    end

    % -- REMOVE LOADED TEXT FILE --
    function remove_selected(~,~)
        % Update listbox
        hList = findobj(hFig, 'tag', 'iaTextFile');
        set(hList, 'string', {}, 'value', 1);
    end

    function cancel_button(~,~)
        close(gcf);
        disp('User selected cancel: No text file for pixel locations');
    end

    function confirm_button(~,~)
        % Get current EEG from base workspace
        try
            EEG = evalin('base', 'EEG');
        catch ME
            errordlg('No EEG dataset loaded in EEGLAB.', 'Error');
            return;
        end

        % Get and validate numRegions
        numRegionsStr = get(findobj('tag','NumRegions'), 'String');
        if iscell(numRegionsStr)
            numRegionsStr = numRegionsStr{1};
        end
        numRegions = str2double(numRegionsStr);
        
        % Validate numRegions is a positive scalar
        if ~isscalar(numRegions) || ~isnumeric(numRegions) || numRegions <= 0
            errordlg('Number of regions must be a positive scalar number.', 'Invalid Input');
            return;
        end
        
        % Convert to double to ensure consistency
        numRegions = double(numRegions);
        
        % Get region names and ensure it's a cell array of strings
        regionNamesStr = get(findobj('tag','regionNames'), 'String');
        if iscell(regionNamesStr)
            regionNamesStr = regionNamesStr{1};
        end
        regionNames = strsplit(regionNamesStr, ',');
        regionNames = cellfun(@strtrim, regionNames, 'UniformOutput', false);
        
        % Get other parameters with same cell array handling
        regionStartStr = get(findobj('tag','pixelStart'), 'String');
        if iscell(regionStartStr)
            regionStartStr = regionStartStr{1};
        end
        regionStartNames = strsplit(regionStartStr, ',');
        regionStartNames = cellfun(@strtrim, regionStartNames, 'UniformOutput', false);
        
        regionWidthStr = get(findobj('tag','pixelWidth'), 'String');
        if iscell(regionWidthStr)
            regionWidthStr = regionWidthStr{1};
        end
        regionWidthNames = strsplit(regionWidthStr, ',');
        regionWidthNames = cellfun(@strtrim, regionWidthNames, 'UniformOutput', false);
        
        regionYTopStr = get(findobj('tag','pixelTop'), 'String');
        if iscell(regionYTopStr)
            regionYTopStr = regionYTopStr{1};
        end
        regionYTopNames = strsplit(regionYTopStr, ',');
        regionYTopNames = cellfun(@strtrim, regionYTopNames, 'UniformOutput', false);
        
        regionYBottomStr = get(findobj('tag','pixelBottom'), 'String');
        if iscell(regionYBottomStr)
            regionYBottomStr = regionYBottomStr{1};
        end
        regionYBottomNames = strsplit(regionYBottomStr, ',');
        regionYBottomNames = cellfun(@strtrim, regionYBottomNames, 'UniformOutput', false);
        
        % Get column names (these should be single strings, not cell arrays)
        conditionColName = get(findobj('tag','edtCondName'), 'String');
        if iscell(conditionColName)
            conditionColName = conditionColName{1};
        end
        conditionColName = strtrim(conditionColName);
        
        itemColName = get(findobj('tag','edtItemName'), 'String');
        if iscell(itemColName)
            itemColName = itemColName{1};
        end
        itemColName = strtrim(itemColName);

        % Validate number of regions matches the input arrays
        if any([length(regionNames), length(regionStartNames), length(regionWidthNames), ...
                length(regionYTopNames), length(regionYBottomNames)] ~= numRegions)
            errordlg('Number of regions does not match the number of entries in one or more fields.', 'Validation Error');
            return;
        end

        % Validate the user selected a file
        if isempty(txtFileList)
            errordlg('No text file selected. Please browse for a file.','File Missing');
            return;
        end

        txtFilePath = txtFileList{1};

        % Call compute_pixel_based_ia with validated inputs
        try
            EEG = compute_pixel_based_ia(EEG, txtFilePath, numRegions, regionNames, ...
                                     regionStartNames, regionWidthNames, regionYTopNames, ...
                                     regionYBottomNames, conditionColName, itemColName);
                                     
            % Store back to base workspace
            assignin('base', 'EEG', EEG);
            
            % Close GUI and redraw EEGLAB
            close(gcf);
            eeglab('redraw');
        catch ME
            errordlg(['Error in compute_pixel_based_ia: ' ME.message], 'Error');
            return;
        end
    end
end




