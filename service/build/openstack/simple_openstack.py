#!/usr/bin/env python


from openstack import connection
import errno
import os

# TODO: replace these variables in the "create server" section
#  from examples.connect import FLAVOR_NAME
#  from examples.connect import IMAGE_NAME
#  from examples.connect import KEYPAIR_NAME
#  from examples.connect import NETWORK_NAME
#  from examples.connect import PRIVATE_KEYPAIR_FILE
#  from examples.connect import SERVER_NAME
#  from examples.connect import SSH_DIR

FLAVOR_NAME='cirros256'
IMAGE_NAME='cirros-0.3.4-x86_64-uec'
NETWORK_NAME='private'
SERVER_NAME='foo-123'


"""
List resources from the Compute service.

For a full guide see TODO(etoews):link to docs on developer.openstack.org
"""
def print_server_list(conn):
    print("List Servers:")
    for server in conn.compute.servers():
        print(server)


def print_images_list(conn):
    print("List Images:")
    for image in conn.compute.images():
        print(image)


def print_flavor_list(conn):
    print("List Flavors:")
    for flavor in conn.compute.flavors():
        print(flavor)


def print_keypair_list(conn):
    print("List Keypairs:")
    for keypair in conn.compute.keypairs():
        print(keypair)

def create_server(conn):
    print("Create Server:")
    image = conn.compute.find_image(IMAGE_NAME)
    print image.id
    flavor = conn.compute.find_flavor(FLAVOR_NAME)
    print flavor.id
    network = conn.network.find_network(NETWORK_NAME)
    print network.id
    # keypair = create_keypair(conn)

    server = conn.compute.create_server(
        name=SERVER_NAME, image_id=image.id, flavor_id=flavor.id,
        networks=[{"uuid": network.id}])
    # , key_name=keypair.name)

    server = conn.compute.wait_for_server(server)

    print("Server IP address={ip}".format(ip=server.access_ipv4))

#     print("ssh -i {key} root@{ip}".format(
#         key=PRIVATE_KEYPAIR_FILE,
#         ip=server.access_ipv4))

def get_openstack_connection():
    auth_args = {
        'auth_url': 'http://10.129.20.2:5000/v2.0',
        'project_name': 'demo',
        'username': 'admin',
        'password': 'secret',
    }
    print("Connecting to Openstack at {0}".format(auth_args['auth_url']))
    conn = connection.Connection(**auth_args)
    return conn

def main():
    print("Obtaining credentials")
    conn = get_openstack_connection()    	
    print("Listing Images: ")
    print_images_list(conn)

    print("Listing servers")
    print_server_list(conn)
    # print("Creating server...")
    # create_server(conn)
    print("Listing servers")
    print_server_list(conn)
    # print_server_list(conn)
    # print_images_list(conn)
    # print_flavor_list(conn)
    # print_keypair_list(conn)
    print("Done")
    # print("auth: {0}\n".format( conn.auth_url))
    # print("project_name: {0}\n".format( conn.project_name))
    # print("username: {0}\n".format( conn.username))
    # print("password: {0}\n".format( conn.password))

if __name__ == '__main__':
    main()

# vim: set ai et sw=4 ts=4 :

