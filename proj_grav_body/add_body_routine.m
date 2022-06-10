function add_body_routine(this_butt,~,input_table,bod_lim,main_fig)

    if size(input_table.DisplayData,1) >= bod_lim
         uialert(main_fig,'Body limit reached!','Error');
        error('Body limit reached!');  
    else
        new_data = {strjoin({'planet',num2str(1+size(input_table.DisplayData,1))}),0,0,0,0,1,''};
        input_table.Data = [input_table.Data; new_data];
    end

end

