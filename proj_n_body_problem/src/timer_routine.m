function timer_routine(this_tm,~,main_axes,output_table)
%TIMER_ROUTINE - Main  routine of the running simulation
%structure of table_const = [AU_const G_const theta_const t_step max_lines_traj 
%draw_traj min_dist_traj draw_table up_table_frame]

%structure of this_tm.UserData = this_tm.UserData = {Body_dyn, Body_dyn_old, Body_mass
% lines_traj, body_mark, table_const, traj_lines, up_table_flag}

%retrieve data for UserData
Body_dyn = this_tm.UserData{1};
Body_dyn_old = this_tm.UserData{2};
Body_mass = this_tm.UserData{3};
body_mark = this_tm.UserData{4};
table_const = this_tm.UserData{5};
traj_lines = this_tm.UserData{6};
up_table_flag = this_tm.UserData{7};

%retrieve constants
AU_const = table_const(1);
G_const = table_const(2);
theta_const = table_const(3);
t_step = table_const(4);
max_lines_traj = table_const(5);
draw_traj = table_const(6);
min_dist_traj = table_const(7);
draw_table = table_const(8);
up_table_frame = table_const(9);


up_table_flag = up_table_flag + 1; %increment flag

%start computations
[Body_dyn, Body_dyn_old] = comp_routine(Body_dyn,Body_dyn_old,Body_mass,...
    G_const,theta_const,t_step);

%update plot data
for index = 1:size(body_mark,2)
   delete(body_mark(index));
   body_mark(index) = line(main_axes,...
           [Body_dyn(index,1) Body_dyn(index,1)],...
           [Body_dyn(index,2) Body_dyn(index,2)],...
           'Linestyle', 'none', 'Marker', 'o', 'Color',[1 0 0]);
       if norm([Body_dyn(index,1:2) - Body_dyn_old(index,1:2)]) < min_dist_traj || ~draw_traj 
           %if change in position is too small, trajectory won't be updated
             %if flag draw_traj is not set, trajectory won't be drawn
            continue;
       else
            addpoints(traj_lines(index),Body_dyn(index,1),Body_dyn(index,2));
       end          
       
end

for index = 1:size(body_mark,2)
    
    if ~mod(up_table_flag,up_table_frame) && norm([Body_dyn(index,1:2) - Body_dyn_old(index,1:2)]) > min_dist_traj && draw_table
        %if change in position is too small, table won't be updated
        %if flag draw_table is not set, table won't be updated
        %table will be updated on certain frames        
        output_table.Data(index,2:end) = num2cell(Body_dyn(index,:)/AU_const);
    end
    %update output table
    
end

%redraw plot data
drawnow limitrate;


%update data
this_tm.UserData = {Body_dyn, Body_dyn_old, Body_mass,...
         body_mark, table_const, traj_lines, up_table_flag};
    

end

