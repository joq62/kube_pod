%%% -------------------------------------------------------------------
%%% Author  : uabjle
%%% Description :  
%%% 
%%% Created : 10 dec 2012
%%% -------------------------------------------------------------------
-module(pod_test).   
   
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
%-include_lib("eunit/include/eunit.hrl").
%% --------------------------------------------------------------------

%% External exports
-export([start/0]). 


%% ====================================================================
%% External functions
%% ====================================================================


%% --------------------------------------------------------------------
%% Function:tes cases
%% Description: List of test cases 
%% Returns: non
%% --------------------------------------------------------------------
start()->
    io:format("~p~n",[{"Start setup",?MODULE,?FUNCTION_NAME,?LINE}]),
    ok=setup(),
    io:format("~p~n",[{"Stop setup",?MODULE,?FUNCTION_NAME,?LINE}]),

    io:format("~p~n",[{"Start pass_0()",?MODULE,?FUNCTION_NAME,?LINE}]),
    ok=pass_0(),
    io:format("~p~n",[{"Stop pass_0()",?MODULE,?FUNCTION_NAME,?LINE}]),

    io:format("~p~n",[{"Start pass_1()",?MODULE,?FUNCTION_NAME,?LINE}]),
    ok=pass_1(),
    io:format("~p~n",[{"Stop pass_1()",?MODULE,?FUNCTION_NAME,?LINE}]),

    io:format("~p~n",[{"Start pass_2()",?MODULE,?FUNCTION_NAME,?LINE}]),
    ok=pass_2(),
    io:format("~p~n",[{"Stop pass_2()",?MODULE,?FUNCTION_NAME,?LINE}]),

%    io:format("~p~n",[{"Start pass_3()",?MODULE,?FUNCTION_NAME,?LINE}]),
%    ok=pass_3(),
%    io:format("~p~n",[{"Stop pass_3()",?MODULE,?FUNCTION_NAME,?LINE}]),

  %  io:format("~p~n",[{"Start pass_4()",?MODULE,?FUNCTION_NAME,?LINE}]),
  %  ok=pass_4(),
  %  io:format("~p~n",[{"Stop pass_4()",?MODULE,?FUNCTION_NAME,?LINE}]),

  %  io:format("~p~n",[{"Start pass_5()",?MODULE,?FUNCTION_NAME,?LINE}]),
  %  ok=pass_5(),
  %  io:format("~p~n",[{"Stop pass_5()",?MODULE,?FUNCTION_NAME,?LINE}]),
 
    
   
      %% End application tests
    io:format("~p~n",[{"Start cleanup",?MODULE,?FUNCTION_NAME,?LINE}]),
    ok=cleanup(),
    io:format("~p~n",[{"Stop cleaup",?MODULE,?FUNCTION_NAME,?LINE}]),
   
    io:format("------>"++atom_to_list(?MODULE)++" ENDED SUCCESSFUL ---------"),
    ok.


%% --------------------------------------------------------------------
%% Function:start/0 
%% Description: Initiate the eunit tests, set upp needed processes etc
%% Returns: non
%% --------------------------------------------------------------------
pass_0()->
    {ok,ClusterId_X}=application:get_env(cluster_id),
    ClusterId=case is_atom(ClusterId_X) of
		  true->
		      atom_to_list(ClusterId_X);
		  false->
		      ClusterId_X
	      end,
    CreatedPods=pod:create_pods(5),
    io:format(" CreatedPods ~p~n",[{CreatedPods,?MODULE,?LINE}]),
    
    ok.

%% --------------------------------------------------------------------
%% Function:start/0 
%% Description: Initiate the eunit tests, set upp needed processes etc
%% Returns: non
%% --------------------------------------------------------------------
pass_1()->
       {ok,ClusterId_X}=application:get_env(cluster_id),
    ClusterId=case is_atom(ClusterId_X) of
		  true->
		      atom_to_list(ClusterId_X);
		  false->
		      ClusterId_X
	      end,
    PodsList=[Pods||{_DeploymentId,_Vsn,Pods,_ClusterId}<-db_deployment_spec:key_cluster_id(ClusterId)],
    ContainersList=[db_pod_spec:containers(PodId)||[{PodId,_Vsn,_Num}]<-PodsList],
    ContainersToStart=lists:append(ContainersList),
    StartResult=[start_container(Container)||Container<-ContainersToStart],
    
    io:format(" StartResult ~p~n",[{StartResult,?MODULE,?LINE}]),
    
    io:format("1. sd:all() ~p~n",[{sd:all(),?MODULE,?LINE}]),
    
    StopList=[stop_node(Pod,Container,Dir)||{ok,Pod,Container,Dir}<-StartResult],
    io:format("2. sd:all() ~p~n",[{sd:all(),?MODULE,?LINE}]),
    ok.

start_container(Container)->
    Pods=nodes(),
    NumPods=lists:flatlength(Pods),
    N=rand:uniform(NumPods),
    WorkerPod=lists:nth(N,Pods),
    Dir=db_kubelet:dir(WorkerPod),
    R=container:load_start(WorkerPod,Container,Dir),
    {R,WorkerPod,Container,Dir}.
    


			   
%% --------------------------------------------------------------------
%% Function:start/0 
%% Description: Initiate the eunit tests, set upp needed processes etc
%% Returns: non
%% --------------------------------------------------------------------
pass_2()->
    Alias="c0_lgh",
    ClusterId="x",
    PodId="ssh_node_1",
    NodeName=PodId,
    Dir="ssh_node_1",
    Cookie="ssh_node_1_cookie",
  
    % Create a node
    {ok,Pod}=create_node(Alias,ClusterId,PodId,NodeName,Dir,Cookie),
    Date=date(),
    Date=rpc:call(Pod,erlang,date,[],3*1000),
    io:format("1. ls ~p~n",[{rpc:call(Pod,file,list_dir,["."],3*1000),?MODULE,?LINE}]),

    % load _Start pod
    PodName="mymath",
    Containers=db_pod_spec:containers(PodName),
    AppStartResult=[load_start(Pod,Container,Dir)||Container<-Containers],
    io:format(" sd:get(mymath)  ~p~n",[{sd:get(mymath),?MODULE,?LINE}]),
    [Mymath|_]=sd:get(mymath),
    42=sd_call(mymath,mymath,add,[20,22],3*1000),

    
    StopResult=[stop_node(Pod,Container,Dir)||Container<-Containers],
    io:format(" StopResult ~p~n",[{StopResult,?MODULE,?LINE}]),
    {badrpc,_}=rpc:call(Pod,erlang,date,[],3*1000),
    io:format(" sd:get(mymath)  ~p~n",[{sd:get(mymath),?MODULE,?LINE}]),
    {error,_}=sd_call(mymath,mymath,add,[20,22],3*1000),
    ok.

sd_call(App,M,F,A,TimeOut)->
    Result=case sd:get(App) of
	       []->
	    {error,[eexists,App,?FUNCTION_NAME,?MODULE,?LINE]};
	       [Node|_]->
		   rpc:call(Node,M,F,A,TimeOut)
	   end,
    Result.

create_node(Alias,ClusterId,PodId,NodeName,Dir,Cookie)->
    Result=case pod:create_node(Alias,NodeName,Cookie) of
	       {error,Reason}->
		   {error,Reason};
	       {ok,Pod}->
		   HostId=db_host_info:host_id(Alias),
		   {atomic,ok}=db_kubelet:create(PodId,HostId,ClusterId,Pod,Dir,Pod,Cookie,[]),
		   rpc:call(Pod,os,cmd,["rm -rf "++Dir],3*1000),
		   case rpc:call(Pod,file,make_dir,[Dir],5*1000) of
		       {error,Reason}->
			   {error,Reason};
		       {badrpc,Reason}->
			   {error,[badrpc,Reason,Pod,Alias,?FUNCTION_NAME,?MODULE,?LINE]};
		       ok->
			   case db_kubelet:create(PodId,HostId,ClusterId,Pod,Dir,na,Cookie,[]) of
			       {atomic,ok}->
				   {ok,Pod};
			       Error ->
				   {error,[Error,PodId,HostId,ClusterId,Pod,Dir,na,Cookie,[],?FUNCTION_NAME,?MODULE,?LINE]}
			   end
		   end
	   end,
    Result.
stop_node(Pod,Container,Dir)->
    {AppId,_Vsn,_GitPath,_Env}=Container,
   % AppIds=[AppId||{AppId,_Vsn,_GitPath,_Env}<-Containers],
    rpc:call(Pod,application,stop,[list_to_atom(AppId)],5*1000),
    rpc:call(Pod,application,unload,[list_to_atom(AppId)],5*1000),
    rpc:call(Pod,code,del_path,[filename:join([Dir,AppId,"ebin"])],5*1000),
        
   % [rpc:call(Pod,application,stop,[list_to_atom(AppId)],5*1000)||AppId<-AppIds],
  %  [{rpc:call(Pod,application,unload,[list_to_atom(AppId)],5*1000),
  %    rpc:call(Pod,code,del_path,[filename:join([Dir,AppId,"ebin"])],5*1000)}||AppId<-AppIds],
     
    Result=case rpc:call(Pod,os,cmd,["rm -rf "++Dir],3*1000) of
	       {badrpc,Reason}->
		   {error,[badrpc,Reason,Pod,Dir,?FUNCTION_NAME,?MODULE,?LINE]};
	       _->
		   case pod:stop_node(Pod) of
		       {error,Reason}->
			   {error,Reason};
		       ok ->
			   case db_kubelet:delete_container(Pod,Container) of
			       {atomic,ok}->
				   ok;
			       Reason->
				   {error,[Reason,Pod,Container,Dir,?FUNCTION_NAME,?MODULE,?LINE]}			       
			   end
		   end
	   end,
    Result.


		   
load_start(Pod,Container,Dir)->
    Result=case container:load_start(Pod,Container,Dir) of
	       {error,Reason}->
		   {error,Reason};
	       ok->
		   case db_kubelet:add_container(Pod,Container) of
		       {atomic,ok}->
			   ok;
		       {Error,Reason}->
			   {Error,[Reason,Pod,Container,?FUNCTION_NAME,?MODULE,?LINE]}
		   end
	   end,
    Result.	    
%% --------------------------------------------------------------------
%% Function:start/0 
%% Description: Initiate the eunit tests, set upp needed processes etc
%% Returns: non
%% --------------------------------------------------------------------
pass_3()->
  
    ok.

%% --------------------------------------------------------------------
%% Function:start/0 
%% Description: Initiate the eunit tests, set upp needed processes etc
%% Returns: non
%% --------------------------------------------------------------------
pass_4()->
  
    ok.


%% --------------------------------------------------------------------
%% Function:start/0 
%% Description: Initiate the eunit tests, set upp needed processes etc
%% Returns: non
%% --------------------------------------------------------------------
pass_5()->
  
    
    ok.


%% --------------------------------------------------------------------
%% Function:start/0 
%% Description: Initiate the eunit tests, set upp needed processes etc
%% Returns: non
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% Function:start/0 
%% Description: Initiate the eunit tests, set upp needed processes etc
%% Returns: non
%% --------------------------------------------------------------------
 
setup()->
   
    ok.


%% --------------------------------------------------------------------
%% Function:start/0 
%% Description: Initiate the eunit tests, set upp needed processes etc
%% Returns: non
%% -------------------------------------------------------------------    

cleanup()->
  
    ok.
%% --------------------------------------------------------------------
%% Function:start/0 
%% Description: Initiate the eunit tests, set upp needed processes etc
%% Returns: non
%% --------------------------------------------------------------------
