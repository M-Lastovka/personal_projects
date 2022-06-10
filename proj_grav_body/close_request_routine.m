function close_request_routine(this_fig,~,main_tm)
stop(main_tm);
delete(main_tm);
delete(this_fig);
end

