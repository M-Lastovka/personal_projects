function [u_lines_traj,u_body_mark] = plot_routine(draw_traj,min_dist_traj,body_pos_new,body_pos_old,lines_traj,body_mark,main_axes)
%this routine plots the bodies and draws trajectories
%OBSOLETE
    for index_row = 1:size(lines_traj,1)
        
        if norm([body_pos_new(index_row,:) - body_pos_old(index_row,:)]) < min_dist_traj || ~draw_traj 
            %if change in position is too small, trajectory won't be drawn
             %if flag draw_traj is not set, trajectory won't be drawn
            continue
        else
             i = 1;
            for index_col = 1:size(lines_traj,2) %loops through lines_traj
                 i = index_col;
                 if ~isgraphics(lines_traj(index_row, index_col))
                     break;
                end
            end
 
             if i == size(lines_traj,2) %first in, last out
                 lines_traj(index_row,:) = circshift(lines_traj(index_row,:),-1,2);                 delete(lines_traj(index_row,i))
             end
 
             lines_traj(index_row,i) = line(main_axes,[body_pos_new(index_row,1) body_pos_old(index_row,1)],...
                 [body_pos_new(index_row,2) body_pos_old(index_row,2)],...
                'Linestyle', '-', 'Color',[0 1 0]); %TODO: make variable color trajectories %adds new lines
            %adds new lines, remapps old lines
        
        end
 
        
    end
   
    
    for index_row = 1:size(lines_traj,1)
        %delete existing markers
        delete(body_mark(index_row));

        
    body_mark(index_row) = line(main_axes,...
           [body_pos_new(index_row,1) body_pos_new(index_row,1)],...
           [body_pos_new(index_row,2) body_pos_new(index_row,2)],...
           'Linestyle', 'none', 'Marker', 'o', 'Color',[1 0 0]); % remapps planet markers
    end

    u_lines_traj = lines_traj;
    u_body_mark = body_mark;
    
        
end

