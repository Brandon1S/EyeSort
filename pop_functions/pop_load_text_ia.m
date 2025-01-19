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
        {'Style','edit','String','3','tag','edtNumRegions'}, ...
        ...
        {'Style','text','String','Region Names (separate by comma):'}, ...
        {'Style','edit','String','Region1,Region2,Region3','tag','edtRegionNames'}, ...
        ...
        {'Style','text','String','Condition Column Name:'}, ...
        {'Style','edit','String','Condition','tag','edtCondName'}, ...
        ...
        {'Style','text','String','Item Column Name:'}, ...
        {'Style','edit','String','Item','tag','edtItemName'}, ...
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
        % Gather other parameters from GUI
        offset         = str2double(get(findobj('tag','edtOffset'), 'String'));
        pxPerChar      = str2double(get(findobj('tag','edtPxPerChar'), 'String'));
        numRegions     = str2double(get(findobj('tag','edtNumRegions'), 'String'));
        regionNamesStr = get(findobj('tag','edtRegionNames'), 'String');
        conditionColName = get(findobj('tag','edtCondName'), 'String');
        itemColName      = get(findobj('tag','edtItemName'), 'String');
        regionNames = strtrim(strsplit(regionNamesStr, ','));

        % Validate the user selected a file
        if isempty(txtFileList)
            errordlg('No text file selected. Please browse for a file.','File Missing');
            return;
        end

        % If only one file is expected, take the first cell
        txtFilePath = txtFileList{1};

        % Now call your function that does the real work:
        EEG = computeTextBasedIA(EEG, txtFilePath, offset, pxPerChar, ...
                                 numRegions, regionNames, conditionColName, ...
                                 itemColName);

        % Build command string for history
        com = sprintf('EEG = pop_loadTextIA(EEG); %% file=%s offset=%g px=%g',...
                      txtFilePath, offset, pxPerChar);

        % Close GUI, redraw EEGLAB
        close(gcf);
        eeglab('redraw');
    end
end




