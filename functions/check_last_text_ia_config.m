function has_last_config = check_last_text_ia_config()
    % CHECK_LAST_TEXT_IA_CONFIG - Check if last Text IA config exists
    has_last_config = exist('last_text_ia_config.mat', 'file') == 2;
end 