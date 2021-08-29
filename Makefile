all:
#	service
	rm -rf ebin *_ebin lgh *.lgh;
	mkdir ebin;
	erlc -I ../interfaces -o ebin src/*.erl;
	erlc -I ../interfaces -o ebin ../kube_pod/src/*.erl;
	rm -rf ebin src/*.beam *.beam  test_src/*.beam test_ebin;
	rm -rf  *~ */*~  erl_cra*;
	rm -rf *_specs *_config *.log;
	echo Done
unit_test:
	rm -rf rm lgh_ebin;
	rm -rf src/*.beam *.beam test_src/*.beam test_ebin;
	rm -rf  *~ */*~  erl_cra*;
	mkdir lgh_ebin;
	mkdir test_ebin;
#	interface
	erlc -I ../interfaces -o lgh_ebin ../interfaces/*.erl;
#	support
	cp ../applications/support/src/*.app lgh_ebin;
	erlc -I ../interfaces -o lgh_ebin ../kube_support/src/*.erl;
	erlc -I ../interfaces -o lgh_ebin ../applications/support/src/*.erl;
#	etcd
	cp ../applications/etcd/src/*.app lgh_ebin;
	erlc -I ../interfaces -o lgh_ebin ../kube_dbase/src/*.erl;
	erlc -I ../interfaces -o lgh_ebin ../applications/etcd/src/*.erl;
#	kubelet
	cp ../applications/kubelet/src/*.app lgh_ebin;
	erlc -I ../interfaces -o lgh_ebin ../node/src/*.erl;
	erlc -I ../interfaces -o lgh_ebin ../applications/kubelet/src/*.erl;
#	kube_pod
	erlc -I ../interfaces -o lgh_ebin 	../kube_pod/src/*.erl;
#	test application
	cp test_src/*.app test_ebin;
	erlc -I ../interfaces -o test_ebin test_src/*.erl;
	erl -pa lgh_ebin -pa test_ebin\
	    -setcookie lgh_cookie\
	    -sname pod_lgh\
	    -unit_test monitor_node pod_lgh\
	    -unit_test cluster_id lgh\
	    -unit_test cookie lgh_cookie\
	    -run unit_test start_test test_src/test.config
