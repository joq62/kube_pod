%%% -------------------------------------------------------------------
%%% Author  : uabjle
%%% Description : dbase using dets 
%%% 
%%% Created : 10 dec 2012
%%% --------------------------------------------------------------------
-module(container).  
   
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("kube_logger.hrl").
%% --------------------------------------------------------------------

% New final ?

-export([
	 load_start/3,
	 stop_unload/3
	]).

%% ====================================================================
%% External functions
%% ====================================================================
%% --------------------------------------------------------------------
%% Function:start
%% Description: List of test cases 
%% Returns: non
%% -------------------------------------------------------------------


load_start(WorkerPod,{AppId,AppVsn,GitPath,AppEnv},Dir)->
    Result=case load(AppId,AppVsn,GitPath,AppEnv,WorkerPod,Dir) of
	       {error,Reason}->
		   {error,Reason};
	       ok ->
		   ?PrintLog(log,"Loaded  ",[WorkerPod,AppId,Dir,?FUNCTION_NAME,?MODULE,?LINE]),
		   case start(AppId,WorkerPod) of
		       {error,Reason}->
			   {error,Reason};
		       ok->
			   ok
		   end
	   end,
    Result.
    
load(AppId,_AppVsn,GitPath,AppEnv,Pod,Dir)->
    Result = case rpc:call(Pod,application,which_applications,[],5*1000) of
		 {badrpc,Reason}->
		     ?PrintLog(ticket,"badrpc ",[Reason,Pod,AppId,?FUNCTION_NAME,?MODULE,?LINE]),
		     {error,[badrpc,Reason,?FUNCTION_NAME,?MODULE,?LINE]};
		 LoadedApps->
		     case lists:keymember(list_to_atom(AppId),1,LoadedApps) of
			 true->
			     ?PrintLog(ticket,'Already loaded',[AppId,Pod,?FUNCTION_NAME,?MODULE,?LINE]),
			     {error,['Already loaded',AppId,Pod]};
			 false ->
			     AppDir=filename:join(Dir,AppId),
			     AppEbin=filename:join(AppDir,"ebin"),
			     App=list_to_atom(AppId),
			     rpc:call(Pod,os,cmd,["rm -rf "++AppId],25*1000),
			     _GitResult=rpc:call(Pod,os,cmd,["git clone "++GitPath],25*1000),
				%	   ?PrintLog(log,"GitResult",[PodNode,GitPath,GitResult,?FUNCTION_NAME,?MODULE,?LINE]),
			     _MVResult=rpc:call(Pod,os,cmd,["mv "++AppId++" "++AppDir],25*1000),
				%	   ?PrintLog(log,"MVResult",[AppId,AppDir,MVResult,?FUNCTION_NAME,?MODULE,?LINE]),
			     true=rpc:call(Pod,code,add_patha,[AppEbin],22*1000),
			     ok=rpc:call(Pod,application,set_env,[[{App,AppEnv}]]),		       
			     ok
		     end
	     end,
    Result.

start(AppId,Pod)->
    App=list_to_atom(AppId),
    ?PrintLog(debug,"App,Pod",[App,Pod,?FUNCTION_NAME,?MODULE,?LINE]),
    Result=case rpc:call(Pod,application,start,[App],2*60*1000) of
	       ok->
		   ?PrintLog(log,"Started ",[AppId,Pod,?FUNCTION_NAME,?MODULE,?LINE]),
		   ok;
	       {error,{already_started}}->
		   ?PrintLog(ticket,"already_started ",[AppId,Pod,?FUNCTION_NAME,?MODULE,?LINE]),
		   ok;
	       {Error,Reason}->
		   ?PrintLog(ticket,"Failed ",[Error,Reason,AppId,Pod,?FUNCTION_NAME,?MODULE,?LINE]),
		   {Error,[Reason,application,Pod,start,App,?FUNCTION_NAME,?MODULE,?LINE]}
	   end,
    Result.

    
%% --------------------------------------------------------------------
%% Function:start
%% Description: List of test cases 
%% Returns: non
%% --------------------------------------------------------------------
stop_unload(Pod,{AppId,_AppVsn,_GitPath,_AppEnv},Dir)->
    AppDir=filename:join(Dir,AppId),
    App=list_to_atom(AppId),
    rpc:call(Pod,application,stop,[App],5*1000),
    rpc:call(Pod,application,unload,[App],5*1000),
    rpc:call(Pod,os,cmd,["rm -rf "++AppDir],3*1000),
    rpc:call(Pod,code,del_path,[filename:join([AppDir,"ebin"])],5*1000),
    ?PrintLog(log,"Stopped ",[AppId,Pod,?FUNCTION_NAME,?MODULE,?LINE]),
    ok.
    
%% --------------------------------------------------------------------
%% Function:start
%% Description: List of test cases 
%% Returns: non
%% --------------------------------------------------------------------
