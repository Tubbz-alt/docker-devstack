#!/usr/bin/env python


from openstack import connection
import errno
import os

FLAVOR_NAME='cirros256'
SEC_GRP_NAME='s3p_secgrp'
IMAGE_NAME='cirros-0.3.4-x86_64-uec'
debug_mode=False
default_image=""
default_flavor=""
default_secgrp=""


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

def list_hypervisors(conn):
    print("List hypervisor:")
    for hypervisor in conn.compute.hypervisors():
        print(hypervisor)

def list_project_id(conn):
    print("List project id's:")
    for project in conn.identityv2.projects():
        print(project)

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
def create_network(conn, network_index):
    basename="s3p-net-"
    network_name=basename+str(network_index)
    print("Create Network:")

    example_network = conn.network.create_network(
        name=network_name)

    print(example_network)

    example_subnet = conn.network.create_subnet(
        name=network_name+'-sub',
        network_id=example_network.id,
        ip_version='4',
        cidr='10.0.'+str(network_index)+'.0/24',
        gateway_ip='10.0.'+str(network_index)+'.1')

    print(example_subnet)
    return example_network


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

def create_server(conn, s3p_server_name, s3p_hypervisor, s3p_network):
    global default_image
    global default_flavor
    global default_secgrp
    print("Image ID for Image {0} = {1}".format(IMAGE_NAME,default_image.id))
    print("Flavor ID for flavor {0} = {1}".format(FLAVOR_NAME,default_flavor.id))
    print("Security Group ID for '{0}' = {1}".format(SEC_GRP_NAME, default_secgrp.id))


    # keypair = create_keypair(conn)

    if not(debug_mode):
        compute_host = conn.compute.find_hypervisor(s3p_hypervisor)
        print("compute_host={0}".format(compute_host))
        server = conn.compute.create_server(
            name=s3p_server_name, image_id=default_image.id, flavor_id=default_flavor.id,
            hypervisor=compute_host,
            security_groups=[{"name":default_secgrp.name}],
            networks=[{"uuid": s3p_network.id}])
        server = conn.compute.wait_for_server(server)
        print("Server IP address={ip}".format(ip=server.addresses))

def get_openstack_connection():
    auth_args = {
        'auth_url': 'http://10.129.18.2:5000/v2.0',
        'project_name': 'demo',
        'username': 'admin',
        'password': 'secret',
    }
    print("Connecting to Openstack at {0}".format(auth_args['auth_url']))
    conn = connection.Connection(**auth_args)
    return conn

def main():
    global default_image
    global default_flavor
    global default_secgrp
    print("Obtaining credentials")
    conn = get_openstack_connection()

    # get defaults
    default_image = conn.compute.find_image(IMAGE_NAME)
    print(default_image)
    print("Image ID for Image {0} = {1}".format(IMAGE_NAME,default_image.id))
    default_flavor = conn.compute.find_flavor(FLAVOR_NAME)
    print(default_flavor)
    print("Flavor ID for flavor {0} = {1}".format(FLAVOR_NAME,default_flavor.id))
    default_secgrp = conn.network.find_security_group(SEC_GRP_NAME)
    print("Security Group ID for '{0}' = {1}".format(SEC_GRP_NAME, default_secgrp.id))

    # create networks
    print("creating network")
    for ix in range(1,7):
        network=create_network(conn,ix)
        hypervisor="compute-8-"+str(ix+10)
        server_name="s3p-"+hypervisor+"-1"
        print("Creating server {0}".format(server_name))
        create_server(conn, server_name, hypervisor, network )
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

