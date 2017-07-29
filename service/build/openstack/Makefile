.PHONY: all
all: run.log

run.log: s3p_functions.py s3p_openstack_tools.py
	./s3p_functions.py | tee run

debug: s3p_functions.py s3p_openstack_tools.py
	./s3p_functions.py -d

cleanup_openstack: ./s3p_functions.py s3p_openstack_tools.py
	./s3p_functions.py -d -c

clean:
	rm -rf *.pyc run.log


