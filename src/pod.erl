%%% -------------------------------------------------------------------
%%% Author  : uabjle
%%% Description : dbase using dets 
%%% 
%%% Created : 10 dec 2012
%%% --------------------------------------------------------------------
-module(pod).  
   
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("kube_logger.hrl").
%% --------------------------------------------------------------------

% New final ?

-export([
	 create_node/3,
	 stop_node/1,

	 create_pods/1,
	 delete_pods/1,
	 create_pod/1,
	 delete_pod/1,
	 delete_pod/2
	]).

%% ====================================================================
%% External functions
%% ====================================================================


%% --------------------------------------------------------------------
%% Function:start
%% Description: List of test cases 
%% Returns: non
%% --------------------------------------------------------------------
create_pods(Num)->
    create_pods(Num,[]).
create_pods(0,StartResult)->
    StartResult;
create_pods(N,Acc) ->
    R=create_pod(integer_to_list(N)),
    create_pods(N-1,[R|Acc]).

%% --------------------------------------------------------------------
%% Function:start
%% Description: List of test cases 
%% Returns: non
%% --------------------------------------------------------------------
delete_pods(Num)->
    delete_pods(Num,[]).
delete_pods(0,StartResult)->
    StartResult;
delete_pods(N,Acc) ->
    R=delete_pod(integer_to_list(N)),
    delete_pods(N-1,[R|Acc]).
%% --------------------------------------------------------------------
%% Function:start
%% Description: List of test cases 
%% Returns: non
%% --------------------------------------------------------------------
create_node(Alias,NodeName,Cookie)->
    ssh:start(),
    Result=case db_host_info:read(Alias) of
	       []->
		   {error,[eexists,Alias,?FUNCTION_NAME,?MODULE,?LINE]};
	       [{Alias,HostId,Ip,SshPort,UId,Pwd}]->
		   Pod=list_to_atom(NodeName++"@"++HostId),
		  
		   true=erlang:set_cookie(Pod,list_to_atom(Cookie)),
		   true=erlang:set_cookie(node(),list_to_atom(Cookie)),
		   ok=stop_node(Pod),

		   ErlCmd="erl_call -s "++"-sname "++NodeName++" "++"-c "++Cookie,
		   SshCmd="nohup "++ErlCmd++" &",
		   ErlcCmdResult=rpc:call(node(),my_ssh,ssh_send,[Ip,SshPort,UId,Pwd,SshCmd,2*5000],3*5000),
		   ?PrintLog(debug,"ErlcCmdResult",[ErlcCmdResult,?FUNCTION_NAME,?MODULE,?LINE]),
		   case node_started(Pod) of
		       false->
			   {error,['failed to start', Pod,Alias,?FUNCTION_NAME,?MODULE,?LINE]};
		       true->
			   {ok,Pod}
		   end
	   end,
    Result.
    
stop_node(Pod)->
    rpc:call(Pod,init,stop,[],5*1000),		   
    Result=case node_stopped(Pod) of
	       false->
		   {error,["node not stopped",Pod,?FUNCTION_NAME,?MODULE,?LINE]};
	       true->
		   ok
	   end,
    Result.

   
%% --------------------------------------------------------------------
%% Function:start
%% Description: List of test cases 
%% Returns: non
%% --------------------------------------------------------------------
create_pod(PodId)->
    ok=delete_pod(PodId),
    {ok,HostId}=inet:gethostname(),
    {ok,ClusterId_X}=application:get_env(cluster_id),
    ClusterId=case is_atom(ClusterId_X) of
		  true->
		      atom_to_list(ClusterId_X);
		  false->
		      ClusterId_X
	      end,
    Cookie=atom_to_list(erlang:get_cookie()),
    NodeName=ClusterId++"_"++HostId++"_"++PodId,
    Pod=list_to_atom(NodeName++"@"++HostId),
    Dir=PodId++"."++ClusterId,
    
    %ok=delete_pod(Pod,Dir),

    ErlCallArgs="-c "++Cookie++" "++"-sname "++NodeName,
    ErlCmd="erl_call -s "++ErlCallArgs, 
    ErlCmdResult=os:cmd(ErlCmd),
    Result=case node_started(Pod) of
	       false->
		   {error,[not_started,Pod,ErlCmdResult,?FUNCTION_NAME,?MODULE,?LINE]};
	       true ->
		  
		   case file:make_dir(Dir) of
		       {error,Reason}->
			   {error,[Reason,Pod,Dir,?FUNCTION_NAME,?MODULE,?LINE]};
		       ok->
			   case db_kubelet:member(PodId,HostId,ClusterId) of
				       true->
					   {error,['already exists',PodId,HostId,ClusterId,?FUNCTION_NAME,?MODULE,?LINE]};
				       false->
					   {atomic,ok}=db_kubelet:create(PodId,HostId,ClusterId,Pod,Dir,node(),Cookie,[]),
					   {ok,Pod}
				   end
		   end
	   end,
    Result.
%% --------------------------------------------------------------------
%% Function:start
%% Description: List of test cases 
%% Returns: non
%% --------------------------------------------------------------------

delete_pod(Id)->
    {ok,HostId}=inet:gethostname(),
    {ok,ClusterId_X}=application:get_env(cluster_id),
    ClusterId=case is_atom(ClusterId_X) of
		  true->
		      atom_to_list(ClusterId_X);
		  false->
		      ClusterId_X
	      end,
    NodeName=ClusterId++"_"++HostId++"_"++Id,
    Pod=list_to_atom(NodeName++"@"++HostId),
    Dir=Id++"."++ClusterId,
    delete_pod(Pod,Dir).

delete_pod(Pod,Dir)->
    rpc:call(Pod,os,cmd,["rm -rf "++Dir],5*1000),
    rpc:call(Pod,init,stop,[],5*1000),		   
    Result=case node_stopped(Pod) of
	       false->
		   {error,["node not stopped",Pod,?FUNCTION_NAME,?MODULE,?LINE]};
	       true->
		   db_kubelet:delete(Pod),
		   ok
	   end,
    Result.

    
    
%% --------------------------------------------------------------------
%% Function:start
%% Description: List of test cases 
%% Returns: non
%% --------------------------------------------------------------------
	      
node_started(Node)->
    check_started(100,Node,50,false).
    
check_started(_N,_Vm,_SleepTime,true)->
   true;
check_started(0,_Vm,_SleepTime,Result)->
    Result;
check_started(N,Vm,SleepTime,_Result)->
 %   io:format("net_Adm ~p~n",[net_adm:ping(Vm)]),
    NewResult= case net_adm:ping(Vm) of
	%case rpc:call(node(),net_adm,ping,[Vm],1000) of
		  pong->
		     true;
		  pang->
		       timer:sleep(SleepTime),
		       false;
		   {badrpc,_}->
		       timer:sleep(SleepTime),
		       false
	      end,
    check_started(N-1,Vm,SleepTime,NewResult).

%% --------------------------------------------------------------------
%% Function:start
%% Description: List of test cases 
%% Returns: non
%% --------------------------------------------------------------------

node_stopped(Node)->
    check_stopped(100,Node,50,false).
    
check_stopped(_N,_Vm,_SleepTime,true)->
   true;
check_stopped(0,_Vm,_SleepTime,Result)->
    Result;
check_stopped(N,Vm,SleepTime,_Result)->
 %   io:format("net_Adm ~p~n",[net_adm:ping(Vm)]),
    NewResult= case net_adm:ping(Vm) of
	%case rpc:call(node(),net_adm,ping,[Vm],1000) of
		  pang->
		     true;
		  pong->
		       timer:sleep(SleepTime),
		       false;
		   {badrpc,_}->
		       true
	       end,
    check_stopped(N-1,Vm,SleepTime,NewResult).

