function [up_Body_dyn,up_Body_dyn_old] = comp_routine(Body_dyn_t,Body_dyn_old_t,Body_mass,G_const,theta_const,t_step)
%COMP_ROUTINE - Main computational routine of the program

  %save previous position
        Body_dyn_old_t = Body_dyn_t(1:end,1:2);
        
  % update position
        Body_dyn_t(1:end,1:2) = Body_dyn_t(1:end,1:2) + Body_dyn_t(1:end,3:4)*t_step; 
        
        Body_dyn_t(1:end,3:4) = Body_dyn_t(1:end,3:4)/(t_step*G_const);

for index_k = 1:size(Body_dyn_t,1)

        %update velocity
        for index_j = 1:size(Body_dyn_t,1)
            if index_j ~= index_k            
                      Body_dyn_t(index_k,3:4) = Body_dyn_t(index_k,3:4) + (Body_mass(index_j)*(Body_dyn_t(index_j,1:2)-Body_dyn_t(index_k,1:2))) ...
                    /((norm(Body_dyn_t(index_j,1:2)-Body_dyn_t(index_k,1:2))^3) + theta_const^3);
            end
        end

end

        Body_dyn_t(1:end,3:4) = Body_dyn_t(1:end,3:4)*(t_step*G_const);


up_Body_dyn = Body_dyn_t;
up_Body_dyn_old = Body_dyn_old_t;

end

