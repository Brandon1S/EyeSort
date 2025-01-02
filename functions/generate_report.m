function generate_report(eventinfo, bins)
    fprintf('\nBINNING REPORT:\n');
    for b = 1:length(bins)
        count = sum([eventinfo.bini] == bins(b).bin_number);
        fprintf('Bin %d: %s - %d events assigned\n', bins(b).bin_number, bins(b).label, count);
    end
end