function update_output_check_routine(this_check,~,output_table,main_tm)
main_tm.UserData{5}(8) = this_check.Value;
if this_check.Value
    output_table.Enable = 'on';
else
    output_table.Enable = 'off';
end

end

