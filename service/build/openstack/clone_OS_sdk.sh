#!/bin/bash
function build_docs_and_serve {
	cd $DEST/doc
	make html
	cd $DEST/doc/build/html
	echo "You can now access the SDK docs at <PHYS_HOST_IP>:58000/index.html"
	python -m SimpleHTTPServer 8000 
}

TAG=$(/home/stack/devstack/tools/info.sh | grep openstacksdk | cut -d'|' -f3)
DEST=/home/stack/openstacksdk
git clone https://github.com/openstack/python-openstacksdk.git $DEST
cd $DEST
git checkout -b s3ptestdev tags/0.9.5

read -p "Would you like to build the documentation as HTML ans serve it as a webpage?" -1 input
if [ "$input" == "y" ]; then
	build_docs_and_serve
fi
