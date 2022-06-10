function draw_traj_check_routine(this_check,~,main_tm)
main_tm.UserData{5}(6) = this_check.Value;
    for index = 1:size(main_tm.UserData{6},2)
        clearpoints(main_tm.UserData{6}(index));    %clear all drawn trajectories
    end
drawnow;
end

