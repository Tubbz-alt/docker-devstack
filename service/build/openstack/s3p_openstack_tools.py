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
SEC_GRP_NAME='s3p_secgrp'
IMAGE_NAME='cirros-0.3.4-x86_64-uec'
NETWORK_NAME='private'
debug_mode=False


"""
List resources from the Compute service.

For a full guide see TODO(etoews):link to docs on developer.openstack.org
"""
def list_servers(conn):
    print("List Servers:")
    for server in conn.compute.servers():
        print(server)


def list_images(conn):
    print("List Images:")
    for image in conn.compute.images():
        print(image)


def list_flavors(conn):
    print("List Flavors:")
    for flavor in conn.compute.flavors():
        print(flavor)


def list_keypairs(conn):
    print("List Keypairs:")
    for keypair in conn.compute.keypairs():
        print(keypair)

def list_comp_availability_zones(conn):
    print("List availability zones:")
    pass
    # the following results in:  KeyError: ''
    # for zone in conn.compute.availability_zones():
    #     print(zone)

"""
List resources from the network service.
"""
def list_networks(conn):
    print("List Networks:")
    for network in conn.network.networks():
        print(network)

def list_subnets(conn):
    print("List Subnets:")
    for subnet in conn.network.subnets():
        print(subnet)

def list_ports(conn):
    print("List Ports:")
    for port in conn.network.ports():
        print(port)

def list_security_groups(conn):
    print("List Security Groups:")
    for port in conn.network.security_groups():
        print(port)

def list_network_agents(conn):
    print("List Network Agents:")
    for agent in conn.network.agents():
        print(agent)

def list_net_availability_zones(conn):
    print("List availability zones:")
    for zone in conn.network.availability_zones():
        print(zone)

"""
Create a project network and subnet.
This network can be used when creating a server and allows the server to 
communicate with others servers on the same project network.
"""
def create_network(conn, network_name):
    print("Create Network:")

    example_network = conn.network.create_network(
        name=network_name)

    print(example_network)

    example_subnet = conn.network.create_subnet(
        name=network_name+'-subnet',
        network_id=example_network.id,
        ip_version='4',
        cidr='10.0.2.0/24',
        gateway_ip='10.0.2.1')

    print(example_subnet)


def delete_network(conn, network_name):
    print("Delete Network:")

    example_network = conn.network.find_network(
        network_name)

    for example_subnet in example_network.subnet_ids:
        conn.network.delete_subnet(example_subnet, ignore_missing=False)

    conn.network.delete_network(example_network, ignore_missing=False)

"""
Create resources
"""

def create_server(conn, SERVER_NAME, compute_host):
    print("Create Server:")
    image = conn.compute.find_image(IMAGE_NAME)
    print("Image ID for Image {0} = {1}".format(IMAGE_NAME,image.id))
    flavor = conn.compute.find_flavor(FLAVOR_NAME)
    print("Flavor ID for flavor {0} = {1}".format(FLAVOR_NAME,flavor.id))
    network = conn.network.find_network(NETWORK_NAME)
    print("Network ID for network {0} = {1}".format(NETWORK_NAME,network.id))
    secgrp = conn.network.find_security_group(SEC_GRP_NAME)
    print("Security Group ID for '{0}' = {1}".format(SEC_GRP_NAME, secgrp.id))
    # keypair = create_keypair(conn)

    if not(debug_mode):
        if compute_host != None:
            # TODO: check that compute_host is a valid hypervisor
            zone="nova:"+compute_host
        print(zone)
        server = conn.compute.create_server(
            name=SERVER_NAME, image_id=image.id, flavor_id=flavor.id,
            networks=[{"uuid": network.id}]) 
            # availability_zone=compute_host )
            #,security_groups=secgrp.id)
        # , key_name=keypair.name)

        server = conn.compute.wait_for_server(server)

        print("Server IP address={ip}".format(ip=server.addresses))

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
    list_images(conn)

    print("Listing servers")
    list_servers(conn)
    # print("Creating server...")
    # create_server(conn)
    print("Listing servers")
    list_servers(conn)
    # list_servers(conn)
    # list_images(conn)
    # list_flavors(conn)
    # list_keypairs(conn)
    print("Done")
    # print("auth: {0}\n".format( conn.auth_url))
    # print("project_name: {0}\n".format( conn.project_name))
    # print("username: {0}\n".format( conn.username))
    # print("password: {0}\n".format( conn.password))

if __name__ == '__main__':
    main()

# vim: set ai et sw=4 ts=4 :

