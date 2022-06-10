function G_const_knob_routine(this_knob,~,main_tm)
new_value = this_knob.Value;
main_tm.UserData{5}(2) = new_value;
end

