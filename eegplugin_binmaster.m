function currvers = eegplugin_myplugin(fig, trystrs, catchstrs)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %    BinMaster Plugin for EEGLAB      %
    %        Main setup function          %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % intialize global variables
    binmaster_default_values;
    
     % Retrieve the version for display
    currvers = ['BinMaster v' binmasterver];
    
    if nargin < 3
        error('eegplugin_binmaster requires 3 arguments');
    end

    % Add the BinMaster folder to the MATLAB path
    p = which('eegplugin_binmaster', '-all');
    if length(p) > 1
        fprintf('\nBinMaster WARNING: More than one BinMaster folder was found.\n\n');
    end
    p = p{1};
    p = p(1:findstr(p, 'eegplugin_binmaster.m') - 1);
    addpath(genpath(p));

   % Check if the BinMaster menu already exists
    menuEEGLAB = findobj(fig, 'tag', 'EEGLAB'); % Find EEGLAB main menu
    existingMenu = findobj(menuEEGLAB, 'tag', 'BinMaster'); % Check for existing BinMaster menu

    if isempty(existingMenu)
        % Add BinMaster to the EEGLAB menu
        submenu = uimenu(menuEEGLAB, 'Label', 'BinMaster', 'tag', 'BinMaster', 'separator', 'on', ...
                         'userdata', 'startup:on;continuous:on;epoch:on;study:on;erpset:on');
        
        % Add version display at the top of the menu
        uimenu(submenu, 'Label', ['*** BinMaster v' binmasterver ' ***'], 'tag', 'binmasterver', ...
               'separator', 'off', 'userdata', 'startup:off;continuous:off;epoch:off;study:off;erpset:off');

        % Add sub-menu items to the new menu
        uimenu(submenu, 'label', 'Filter Setup', 'separator', 'on', 'callback', 'main_supergui();');
        uimenu(submenu, 'label', 'Load Data', 'callback', @loadData);
        uimenu(submenu, 'label', 'Filter Setup', 'callback', @filterSetup);
        uimenu(submenu, 'label', 'Export Data', 'callback', @exportData);
    else
        fprintf('BinMaster menu already exists. Skipping creation.\n');
    end
end

function loadData(~, ~)
    disp('Load Data selected.');
    % To do
end

function filterSetup(~, ~)
    disp('Filter Setup selected.');
    % To do
end

function exportData(~, ~)
    disp('Export Data selected.');
    % To do
end


