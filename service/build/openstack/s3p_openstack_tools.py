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
"""
def debug_print(stringIn=''):
    """docstring for dbgPrint"""
    if debug_mode:
        print(stringIn)

def get_servers(conn):
    return conn.compute.servers()

def list_servers(conn):
    print("List Servers:")
    for server in conn.compute.servers():
        print(server)


def list_servers_by_name(conn):
    server_list = []
    for server in conn.compute.servers():
        server_list.append(server.name)
    return server_list

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

def list_hypervisors_by_name(conn):
    """Returns a list of active hypervisors by name"""
    hypervisor_list=[]
    for hypervisor in conn.compute.hypervisors():
        debug_print(hypervisor.name)
        hypervisor_list.append(hypervisor.name)
    return hypervisor_list

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

def list_networks_by_name(conn):
    netlist=[]
    for network in conn.network.networks():
        netlist.append(network.name)
    return netlist


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
def create_network_raw(conn, network_name):
    """creates a network based on a network name - no checking for existing"""
    new_network = conn.network.create_network(
        name=network_name)
    return new_network
    
def create_subnet_raw(conn, subnet_name, parent_network_id, subnet_cidr, gateway):
    """creates a subnet without checking for existing subnets"""
    new_subnet = conn.network.create_subnet(
        name=subnet_name,
        network_id=parent_network_id,
        ip_version='4',
        cidr=subnet_cidr,
        gateway_ip=gateway)
    return new_subnet

def create_network(conn, network_index):
    basename="s3p-net-"
    network_name=basename+str(network_index)
    debug_print("Create Network:")
    example_network = create_network_raw(conn, network_name)
    debug_print(example_network)
    subnet_name = network_name+'-sub'
    network_id = example_network.id
    cidr = '10.0.'+str(network_index)+'.0/24'
    gateway_ip = '10.0.'+str(network_index)+'.1'
    example_subnet = create_subnet_raw(conn, subnet_name, network_id, cidr, gateway_ip)
    debug_print(example_subnet)
    return example_network


def delete_network(conn, network_name, router_name='router1'):
    debug_print("Delete Network:")
    os_router = conn.network.find_router(router_name)
    os_network = conn.network.find_network(
        network_name)
    # remove subnet interfaces from router and delete subnets
    for subnet_id in os_network.subnet_ids:
        # TODO: the following line throws exceptions if the subnet has not been attached to it yet
        conn.network.router_remove_interface(os_router, subnet_id)
        conn.network.delete_subnet(subnet_id, ignore_missing=False)
    conn.network.delete_network(os_network, ignore_missing=False)

"""
Create resources
"""

def create_server(conn, s3p_server_name, s3p_hypervisor, s3p_network):
    global default_image
    global default_flavor
    global default_secgrp
    if debug_mode:
        print("Image ID for Image {0} = {1}".format(IMAGE_NAME,default_image.id))
        print("Flavor ID for flavor {0} = {1}".format(FLAVOR_NAME,default_flavor.id))
        print("Security Group ID for '{0}' = {1}".format(SEC_GRP_NAME, default_secgrp.id))

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

def delete_server(conn, server_name):
    """deletes a server from the cluster"""
    if not(debug_mode):
        server = conn.compute.find_server(server_name)
        conn.compute.delete_server(server)

def get_openstack_connection():
    service_host_ip = os.getenv('SERVICE_HOST')
    auth_args = {
        'auth_url': 'http://' + service_host_ip + ':5000/v2.0',
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

