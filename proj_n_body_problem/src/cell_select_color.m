function cell_select_color(this_table,event_data,main_fig)
%CELL_SELECT_COLOR 
cell_index = event_data.Indices;

    if cell_index(1,2) == 7 %the column 'color' is selected
        new_color = uisetcolor();
         if new_color == 0
            uialert(main_fig,'Color will be set to black','Warning','Icon','Warning');
             new_color = [0 0 0];
         end
        this_table.UserData(cell_index(1,1),:) = new_color; %save color for later
        style = uistyle('BackgroundColor',new_color);
       addStyle(this_table,style,'cell',cell_index);
    end


end

