.PHONY: all debug verbose cleanup_openstack clean
all: run.log

run.log: s3p_functions.py s3p_openstack_tools.py
	./s3p_functions.py | tee run.log

debug: s3p_functions.py s3p_openstack_tools.py
	./s3p_functions.py -d

verbose: s3p_functions.py s3p_openstack_tools.py
	./s3p_functions.py -d -v 1

cleanup_openstack: ./s3p_functions.py s3p_openstack_tools.py
	./s3p_functions.py -d -c

clean:
	rm -rf *.pyc run.log


