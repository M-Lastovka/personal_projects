function  main()
%author: Martin Lastovka, contact at lastoma4@fel.cvut.cz
%simulation is based on leapfrog numerical integration

%system constants
run_state = 0; %0 - is not running, 1 - runs, 2 - pauses

%physical constants
AU_const = 149597870700; % astronomical unit in meters
G_const = 6.67408E-11; % gravitational constant in SI units
theta_const = 0.0426*AU_const;   % correctional constant for extremely short distances, 
%equal to 1000x Earth's radius in AU

t_step = 47; % in days, don't confuse with timer_period

n_bod_def = 2; % number of bodies, default value

%these variables may be reshaped in stop_start_pause_routine, according to
%input
Body_dyn = nan(n_bod_def,4); % structure of Body_dyn - x position, y positon,
%x velocity, y velocity
Body_dyn_old = nan(n_bod_def,2); %stores previous position of bodies, used for
%drawing trajectories
Body_mass = nan(1,n_bod_def); %stores mass of bodies

%GUI constants
bod_lim = 30; %maximum number of bodies
max_lines_traj = 250;   %maximum number of lines in a trajectory
main_fig_size = [1250, 800];
min_dist_traj = 0.01*AU_const; % minimum trajectory length drawing distance
def_axis_lim = [0 40]; %default axis limit
up_table_frame = 24; %updates table every 24 frames

%GUI variables
draw_traj = true;
draw_table = false;
body_mark = gobjects(1,n_bod_def); %marks current body position, object type line
traj_lines = gobjects(1,n_bod_def); %preallocated array that will store object type animated line, 
%which will draw out our trajectory


%GUI elements
screen_size = get(groot, 'ScreenSize');

main_fig = uifigure('color',[0.8    0.8    0.8],'Name','N-body problem',...
    'Position',[(screen_size(3:4) - main_fig_size)/2 main_fig_size]);

main_grid = uigridlayout(main_fig,...
    'ColumnWidth',[main_fig_size(1,1)/5,main_fig_size(1,1)*(3/5),main_fig_size(1,1)/5],...
    'RowHeight',[main_fig_size(1,2)*(3/4)]);

input_table = uitable(main_grid, 'Data', ...
{'secondary body',3,3,-0.6e-7,1e-7,6e+24,'';
'primary body', 0,0,0e-8,0e-7,2e+30, ''},...        %default conditions are of an elliptical orbit
'ColumnName', ...
{'Name', 'x(0) [AU]', 'y(0) [AU]','Vx(0) [AU/s]', 'Vy(0) [AU/s]','Mass [kg]','Trajectory Color'},...
'ColumnFormat', ({'char', 'numeric', 'numeric', 'numeric','numeric','numeric','char'}), ...
'ColumnWidth', {75,70,70,70,70,70,100}, ...
'FontSize',15,...
'ColumnEditable', true(1, 6));
input_table.UserData = nan(2,3); % here are stored the colors of individual rows (trajectories)


main_axes = uiaxes(main_grid, 'XLim',def_axis_lim*AU_const,...  %where animation takes place
    'YLim',def_axis_lim*AU_const,'color','#808080',...
    'XGrid','on','YGrid','on','GridLineStyle','-.');

output_table = uitable(main_grid,...    %monitoring system variables, will decrease performance
'ColumnName', ...
{'Name', 'x(0) [AU]', 'y(0) [AU]','Vx(0) [AU/s]', 'Vy(0) [AU/s]','Mass [kg]'},...
'ColumnFormat', ({'char', 'numeric', 'numeric', 'numeric','numeric','numeric'}), ...
'ColumnWidth', {75,70,70,70,70,70}, ...
'FontSize',15);
output_table.Data = input_table.DisplayData(1:end,1:5); %set default
output_table.Enable = 'off';

stop_start_pause_butt = uibutton(main_fig, 'Text', 'Start', ...     %control the state of simulation
'Position', [main_fig_size(1,1)/4.15,main_fig_size(1,1)/25, 120, 80], ...
'FontWeight', 'bold','BackGroundColor',[0 1 0],...
'ToolTip', 'Click to start simulation!');

add_body_butt = uibutton(main_fig, 'Text', 'Add', ...   %add a body
'Position', [main_fig_size(1,1)/35,main_fig_size(1,1)/25, 120, 80], ...
'FontWeight', 'bold','BackGroundColor',[1 0 0],...
'ToolTip', 'Click to add a new body!');

delete_body_butt = uibutton(main_fig, 'Text', 'Delete', ... %delete a body
'Position', [main_fig_size(1,1)/7.5,main_fig_size(1,1)/25, 120, 80], ...
'FontWeight', 'bold','BackGroundColor',[0 0 1],...
'ToolTip', 'Click to delete the last added body!');

t_step_knob = uiknob(main_fig,...   %control time step
'Position', [main_fig_size(1,1)/1.5, main_fig_size(1,1)/22, 80, 100], ...
'Value', t_step, ...
'Limits', [11, 110]); %range from 11 to 110 days

G_const_knob = uiknob(main_fig,...  %control G const
'Position', [main_fig_size(1,1)/1.18, main_fig_size(1,1)/22, 80, 100], ...
'Value', G_const, ...
'Limits', [1.67408E-11, 22.67408E-11]); 

preset_list = uidropdown(main_fig,...   %bunch of presets
    'Position', [main_fig_size(1,1)/2.3, main_fig_size(1,1)/12, 150, 50], ...
'Items', {'Eliptical Orbit','Hyberbolic encounter',...
'General two body problem','Periodic five body solution'});
preset_list.ItemsData = [1 2 3 4];

draw_traj_check = uicheckbox(main_fig, ...
'Text', 'Draw trajectory','Value', true, ...
 'Position', [main_fig_size(1,1)/2.3, main_fig_size(1,1)/22, 150, 50], ...
'Tooltip', 'Can decrease performance!');

update_output_check = uicheckbox(main_fig, ...
'Text', 'Update output table','Value', false, ...
 'Position', [main_fig_size(1,1)/2.3, main_fig_size(1,1)/35, 150, 50], ...
'Tooltip', 'Can decrease performance!');

G_const_label = uilabel(main_fig,...
    'Position',[main_fig_size(1,1)/1.22, 20, 150, 20],...
    'Text','G constant [m^3/kg*s^2]','FontColor',[0.2784 0.4706 0.9608],...
    'FontWeight','bold');

time_step_label = uilabel(main_fig,...
    'Position',[main_fig_size(1,1)/1.50, 20, 150, 20],...
    'Text','time step [day]','FontColor',[0.2784 0.4706 0.9608],...
    'FontWeight','bold');

main_label = uilabel(main_fig,...
    'Position',[main_fig_size(1,1)/2.30, 20, 200, 20],...
    'Text','CTU FEL PRAGUE','FontColor',[0.2784 0.4706 0.9608],...
    'FontWeight','bold','FontSize',18);


%main timer, executes main computational and GUI routine
main_tm = timer;
main_tm.StartDelay = 0.5;
main_tm.Period =  0.042;
main_tm.ExecutionMode = 'fixedSpacing'; % spacing

 
 %declaration of callback functions
 main_tm.TimerFcn = {@timer_routine,main_axes,output_table}; %TODO: one of inputs is handle to time gauge
 
 stop_start_pause_butt.ButtonPushedFcn = {@stop_start_pause_routine,...
     main_tm,main_fig,main_axes,input_table,output_table,t_step_knob,...
     G_const_knob,draw_traj_check,update_output_check}; 
 
 input_table.CellSelectionCallback = {@cell_select_color,main_fig};
 
 add_body_butt.ButtonPushedFcn = {@add_body_routine,input_table,bod_lim,main_fig};
 
 delete_body_butt.ButtonPushedFcn = {@delete_body_routine,input_table};
 
 t_step_knob.ValueChangedFcn = {@t_step_knob_routine,main_tm};
 
 G_const_knob.ValueChangedFcn = {@G_const_knob_routine,main_tm};
 
 preset_list.ValueChangedFcn = {@preset_list_routine,input_table,main_fig};
 
 draw_traj_check.ValueChangedFcn = {@draw_traj_check_routine,main_tm};
 
 update_output_check.ValueChangedFcn = {@update_output_check_routine,output_table,main_tm};
 
 main_fig.CloseRequestFcn = {@close_request_routine,main_tm};
 
 %store all constants in a matrix
table_const = [AU_const G_const theta_const t_step max_lines_traj...
    draw_traj min_dist_traj draw_table up_table_frame].';
 
setappdata(stop_start_pause_butt,'run_flag',run_state);
setappdata(stop_start_pause_butt,'Body_dyn_ptr',Body_dyn);
setappdata(stop_start_pause_butt,'Body_dyn_old_ptr',Body_dyn_old);
setappdata(stop_start_pause_butt,'Body_mass_ptr',Body_mass);
setappdata(stop_start_pause_butt,'body_mark_ptr',body_mark);
setappdata(stop_start_pause_butt,'table_const_ptr',table_const);
setappdata(stop_start_pause_butt,'traj_lines_ptr',traj_lines);


end

