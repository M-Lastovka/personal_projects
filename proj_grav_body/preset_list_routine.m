function preset_list_routine(this_dropdown,~,input_table,main_fig)


presets = {{'secondary body' 3 3 -0.6e-7 1e-7 6e+24 '';...
   'primary body' 0 0 0e-8 0e-7 2e+30 ''};...   %elliptical orbit
   {'secondary body' 2.5 0 0.6e-7 1.5e-7 6e+24 '';
   'primary body' 9 10 0e-8 0e-7 2e+30 ''}; %hyperbolic encounter
   {'planet 1' 6 6 -0.6e-7 1e-7 1.2e+30 '';...
   'planet 2' 3 3 0e-8 0e-7 2e+30 ''}   %two body problem
   {'planet A' 0 0 5e-8 0 4e25 '';...
   'planet B' 5 0 0 5e-8 4e25 '';...
   'planet C' 5 5 -5e-8 0 4e25 '';
   'planet D' 0 5 0 -5e-8 4e25 '';
   'central planet' 2.5 2.5 0 0 4e29 ''}}; %periodic 5 body solution


    if strcmp(input_table.Enable, 'off')
          uialert(main_fig,'Simulation has to be stopped first!','Error');
            error('Simulation has to be stopped first!');  
    else
       input_table.Data = presets{this_dropdown.Value};
    end

end

