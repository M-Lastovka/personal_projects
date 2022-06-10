function t_step_knob_routine(this_knob,~,main_tm)
new_value = this_knob.Value;  
main_tm.UserData{5}(4) = new_value*86400;   %convert from days to seconds
end

