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
    Result=case sd:call(etcd,db_host_info,read,[Alias],4*1000) of
	       []->
		   ?PrintLog(ticket,"eexists ",[Alias,NodeName,?FUNCTION_NAME,?MODULE,?LINE]),
		   {error,[eexists,Alias,?FUNCTION_NAME,?MODULE,?LINE]};
	       [{Alias,HostId,Ip,SshPort,UId,Pwd}]->
		   Pod=list_to_atom(NodeName++"@"++HostId),
		  
		   true=erlang:set_cookie(Pod,list_to_atom(Cookie)),
		   true=erlang:set_cookie(node(),list_to_atom(Cookie)),
		   ok=stop_node(Pod),

		   ErlCmd="erl_call -s "++"-sname "++NodeName++" "++"-c "++Cookie,
		   SshCmd="nohup "++ErlCmd++" &",
		   ErlcCmdResult=rpc:call(node(),my_ssh,ssh_send,[Ip,SshPort,UId,Pwd,SshCmd,2*5000],3*5000),
		   case node_started(Pod) of
		       false->
			   ?PrintLog(ticket,"Failed ",[Pod,Alias,NodeName,ErlcCmdResult,?FUNCTION_NAME,?MODULE,?LINE]),
			   {error,['failed to start', Pod,Alias,ErlcCmdResult,?FUNCTION_NAME,?MODULE,?LINE]};
		       true->
			   ?PrintLog(log,"Started ",[Pod,Alias,NodeName,ErlcCmdResult,?FUNCTION_NAME,?MODULE,?LINE]),
			   {ok,Pod}
		   end
	   end,
    Result.
    
stop_node(Pod)->
    rpc:call(Pod,init,stop,[],5*1000),		   
    Result=case node_stopped(Pod) of
	       false->
		   ?PrintLog(ticket,"Failed to stop node ",[Pod,?FUNCTION_NAME,?MODULE,?LINE]),
		   {error,["node not stopped",Pod,?FUNCTION_NAME,?MODULE,?LINE]};
	       true->
		   ?PrintLog(log,"Stopped ",[Pod,?FUNCTION_NAME,?MODULE,?LINE]),
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
    ClusterId=sd:call(etcd,db_cluster_info,cluster,[],4*1000),
    Cookie=atom_to_list(erlang:get_cookie()),
    NodeName=ClusterId++"_"++HostId++"_"++PodId,
    Pod=list_to_atom(NodeName++"@"++HostId),
    Dir=PodId++"."++ClusterId,
    ErlCallArgs="-c "++Cookie++" "++"-sname "++NodeName,
    ErlCmd="erl_call -s "++ErlCallArgs, 
    ErlCmdResult=os:cmd(ErlCmd),
    Result=case node_started(Pod) of
	       false->
		   ?PrintLog(ticket,"Failed to start  ",[PodId,Pod,Dir,NodeName,ErlCmd,?FUNCTION_NAME,?MODULE,?LINE]),
		   {error,[not_started,Pod,ErlCmdResult,?FUNCTION_NAME,?MODULE,?LINE]};
	       true ->
		   os:cmd("rm -rf "++Dir),
		   timer:sleep(200),
		   case file:make_dir(Dir) of
		       {error,Reason}->
			   ?PrintLog(ticket,"Failed make dir ",[Reason,PodId,Pod,Dir,NodeName,ErlCmd,?FUNCTION_NAME,?MODULE,?LINE]),
			   {error,[Reason,Pod,Dir,?FUNCTION_NAME,?MODULE,?LINE]};
		       ok->
			   case sd:call(etcd,db_kubelet,member,[PodId,HostId,ClusterId],3*1000) of
			       true->
				   ?PrintLog(ticket,"Already exists ",[PodId,HostId,ClusterId,?FUNCTION_NAME,?MODULE,?LINE]),
				   {error,['already exists',PodId,HostId,ClusterId,?FUNCTION_NAME,?MODULE,?LINE]};
			       false->
				   case sd:call(etcd,db_kubelet,create,[PodId,HostId,ClusterId,Pod,Dir,node(),Cookie,[]],5*1000) of
				       {atomic,ok}->
					   ?PrintLog(log,"Started ",[PodId,Pod,HostId,ClusterId,Pod,Dir,?FUNCTION_NAME,?MODULE,?LINE]),
					   {ok,Pod};
				       Reason ->
					   ?PrintLog(ticket,"Failed ",[Reason,PodId,HostId,ClusterId,?FUNCTION_NAME,?MODULE,?LINE]),
					   {error,[Reason,PodId,HostId,ClusterId,?FUNCTION_NAME,?MODULE,?LINE]}
				   end
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
    ClusterId=sd:call(etcd,db_cluster_info,cluster,[],5*1000),
    NodeName=ClusterId++"_"++HostId++"_"++Id,
    Pod=list_to_atom(NodeName++"@"++HostId),
    Dir=Id++"."++ClusterId,
    Result=case sd:call(etcd,db_kubelet,member,[Id,HostId,ClusterId],5*1000) of
	       false->
		   ok;
	       true->
		   delete_pod(Pod,Dir);
	       Reason ->
		   ?PrintLog(ticket,"Failed ",[Reason,Id,HostId,ClusterId,?FUNCTION_NAME,?MODULE,?LINE]),
		   {error,[Reason,Id,HostId,ClusterId,?FUNCTION_NAME,?MODULE,?LINE]}
	   end,
    Result.

delete_pod(Pod,Dir)->
    rpc:call(Pod,os,cmd,["rm -rf "++Dir],5*1000),
    rpc:call(Pod,init,stop,[],5*1000),		   
    Result=case node_stopped(Pod) of
	       false->
		   {error,["node not stopped",Pod,?FUNCTION_NAME,?MODULE,?LINE]};
	       true->
		   case sd:call(etcd,db_kubelet,delete,[Pod],5*1000) of
		       {atomic,ok}->
			   ?PrintLog(log,"Deleted ",[Pod,Dir,?FUNCTION_NAME,?MODULE,?LINE]),
			   ok;
		       Reason ->
			   ?PrintLog(ticket,"Failed ",[Reason,Pod,Dir,?FUNCTION_NAME,?MODULE,?LINE]),
			   {error,[Reason,Pod,Dir,?FUNCTION_NAME,?MODULE,?LINE]}
		   end
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

