function stop_start_pause_routine(this_butt,~,this_tm,main_fig,main_axes,input_table,output_table,...
t_step_knob,G_const_knob,draw_traj_check,update_output_check)
%STOP_START_ROUTINE
%starts timer, loads data from input table to timer

%structure of table_const = [AU_const G_const theta_const t_step max_lines_traj 
%draw_traj min_dist_traj draw_table up_table_frame]

flag = getappdata(this_butt,'run_flag');
Body_dyn = getappdata(this_butt,'Body_dyn_ptr');
Body_dyn_old = getappdata(this_butt,'Body_dyn_old_ptr');
Body_mass = getappdata(this_butt,'Body_mass_ptr');
body_mark = getappdata(this_butt,'body_mark_ptr');
traj_lines = getappdata(this_butt,'traj_lines_ptr');
table_const = getappdata(this_butt,'table_const_ptr');




AU_const = table_const(1);
flag = mod(flag+1,3);

    if flag == 1
        %simulation starts
        
    % load data to start simulation
    
    %set default values to knobs and checkbox
    t_step_knob.Value = table_const(4); 
    G_const_knob.Value = table_const(2); 
    draw_traj_check.Value = table_const(6);
    update_output_check.Value = table_const(8);
    table_const(4) = table_const(4)*86400;
    n_bod = size(input_table.DisplayData,1); %body count
    
    if sum(isnan(cell2mat(input_table.DisplayData(:,2:6))),'all') 
          uialert(main_fig,'Invalid input value!','Error');
        error('Invalid input value!');   
    else
        %reset flag
        
        %resize 
         traj_lines = gobjects(1,n_bod);
         body_mark = gobjects(1,n_bod);
         Body_mass = nan(1,n_bod);
         Body_dyn = nan(n_bod,4);
         Body_dyn_old = nan(n_bod,2);
         input_table.UserData = [input_table.UserData; nan(n_bod - size(input_table.UserData,1),3)]
    
     Body_mass = cell2mat(input_table.DisplayData(:,6)).';
     Body_dyn = cell2mat(input_table.DisplayData(:,2:5))*AU_const;
     Body_dyn_old = Body_dyn(:,1:2);
     
    output_table.Data = input_table.DisplayData(1:end,1:5); %set 
  
    end
     
     for index = 1:n_bod
     traj_lines(1,index) = animatedline(main_axes, 'MaximumNumPoints', table_const(5));
        if isnan(input_table.UserData(index,:))
            traj_lines(1,index).Color = [rand rand rand]; %if color isn't user specified, assign random
        else
            traj_lines(1,index).Color = input_table.UserData(index,:);
        end
     end
           up_table_flag = 0; %flag that indicates whether output table is to be updated
        this_tm.UserData = {Body_dyn, Body_dyn_old, Body_mass,...
             body_mark, table_const, traj_lines, up_table_flag}; %load all data into timer routine

        this_butt.BackgroundColor = [1 0 0];
        this_butt.Text = 'Stop';
        
        %recenter axes
      
        main_axes.XLim = main_axes.XLim  + Body_dyn(1,1) - (main_axes.XLim(1) + main_axes.XLim(2))/2;
        main_axes.YLim = main_axes.YLim + Body_dyn(1,2) -  (main_axes.YLim(1) + main_axes.YLim(2))/2;

        input_table.Enable = 'off';
        start(this_tm);

    elseif flag == 0 
        %simulation ends
        this_butt.BackgroundColor = [0 1 0];
        this_butt.Text = 'Start';
        
        output_table.Enable = 'off';
        
        delete(this_tm.UserData{4});
        delete(this_tm.UserData{6});
        input_table.Enable = 'on';

    else
        %simulation is paused
        this_butt.BackgroundColor = [0 0 1];
        this_butt.Text = 'Pause';
        stop(this_tm);
    end

setappdata(this_butt,'run_flag',flag);
end

