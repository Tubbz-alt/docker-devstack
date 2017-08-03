#!/usr/bin/env python


from openstack import connection
import errno
import os
import hashlib

FLAVOR_NAME='cirros256'
SEC_GRP_NAME='s3p_secgrp'
IMAGE_NAME='cirros-0.3.4-x86_64-uec'
debug_mode=False
default_image=""
default_flavor=""
default_secgrp=""

""" Utilities """
def debug_print(stringIn=''):
    """ prints only when global debug_mode is set to True"""
    global debug_mode
    if debug_mode:
        print(stringIn)

""" Print lists of resources """
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

def print_hypervisor_list(conn):
    print("List hypervisor:")
    for hypervisor in conn.compute.hypervisors():
        print(hypervisor)

def print_project_id_list(conn):
    print("List project id's:")
    for project in conn.identityv2.projects():
        print(project)

def print_network_list(conn):
    print("List Networks:")
    for network in conn.network.networks():
        print(network)

def print_subnet_list(conn):
    print("List Subnets:")
    for subnet in conn.network.subnets():
        print(subnet)

def print_port_list(conn):
    print("List Ports:")
    for port in conn.network.ports():
        print(port)

def print_security_group_list(conn):
    print("List Security Groups:")
    for port in conn.network.security_groups():
        print(port)

def print_network_agent_list(conn):
    print("List Network Agents:")
    for agent in conn.network.agents():
        print(agent)

def print_net_availability_zones_list(conn):
    print("List availability zones:")
    for zone in conn.network.availability_zones():
        print(zone)

""" List resources from the Compute service """
def list_hypervisors_by_name(conn):
    """Returns a list of active hypervisors by name"""
    hypervisor_list=[]
    for hypervisor in conn.compute.hypervisors():
        debug_print(hypervisor.name)
        hypervisor_list.append(hypervisor.name)
    return hypervisor_list

def get_hypervisor_hostId(conn, project_id, hypervisor_hostname):
    """ determines the hostID for server creation
        An undocumented "feature" of the SDK is that specifying a server's
        target host cannot be done with 'hypervisor_hostname=hypervisor_hostname'
        or by specifying the availability zone as in the CLI, the server's
        intended destination may be specified as a hostId which is a hash
        of the project ID and the hypervisor hostname
        https://ask.openstack.org/en/question/6477/what-is-the-hostid-parameter-in-server-details/
    """
    sha_hash = hashlib.sha224(project_id + hypervisor_hostname)
    return sha_hash.hexdigest()

def get_hypervisor_set(conn, prefix=''):
    """ Returns the set of hypervisors matching a name prefix """
    hypervisor_set = { hypervisor.name for hypervisor in conn.compute.hypervisors()
        if prefix in hypervisor.name }
    return hypervisor_set

def list_servers_by_name(conn, namefilter=''):
    """ returns a list of servers in the cloud """
    server_list = [ server.name for server in conn.compute.servers()
            if namefilter in server.name ]
    return server_list

def get_server_set(conn, namefilter=''):
    """ returns a set of servers in the cloud (assumes no duplicate names) """
    server_set = { server.name for server in conn.compute.servers()
            if namefilter in server.name }
    return server_set

def get_server_detail(conn, server_name):
    """ Returs an os_ServerDetail if name matches"""
    os_server_list=[ server for server in  conn.compute.servers(details=True, name=server_name) ]
    if len(os_server_list) == 1:
        os_server = os_server_list[0]
    else:
        logprint("ERROR: server named '{0}' not found".format(server_name))
        os_server = None
    return os_server

""" List resources from the network service """
def get_os_router(conn, router_name):
    """ function wraps conn.network.find_router() """
    return conn.network.find_router(router_name)

def get_network_id(conn, network_name):
    os_network = conn.network.find_network(network_name)
    return os_network.id

def get_network_name(conn, network_id):
    os_network = conn.network.find_network(network_id)
    return os_network.name

def get_network_set(conn, namefilter=''):
    """ Returns a set of the networks in the cloud with namefilter matching """
    net_set = { net.name for net in conn.network.networks()
            if namefilter in net.name }
    return net_set

def get_subnet_set(conn, namefilter=''):
    """ Returns a set of the subnets in the cloud with namefilter matching """
    subnet_set = { subnet.name for subnet in conn.network.subnets()
            if namefilter in subnet.name }
    return subnet_set

def list_networks_by_name(conn):
    netlist=[]
    for network in conn.network.networks():
        netlist.append(network.name)
    return netlist

"""
Create a project network and subnet.
This network can be used when creating a server and allows the server to
communicate with others servers on the same project network.
"""
def create_network_raw(conn, network_name):
    """creates a network based on a network name - no checking for existing"""
    os_network = conn.network.create_network(
        name=network_name)
    return os_network

def create_subnet_raw(conn, subnet_name, parent_network_id, subnet_cidr, gateway):
    """creates a subnet without checking for existing subnets"""
    os_subnet = conn.network.create_subnet(
        name=subnet_name,
        network_id=parent_network_id,
        ip_version='4',
        cidr=subnet_cidr,
        gateway_ip=gateway)
    return os_subnet

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

def router_add_subnet(conn, os_router, subnet_id):
    """ function wraps conn.network.router_add_interface() """
    conn.network.router_add_interface( os_router, subnet_id )

def router_remove_subnet(conn, os_router, subnet_id):
    """ function wraps conn.network.router_remove_interface() """
    print("Removing subnet id {0} from router '{1}'".format(
        subnet_id, os_router.name))
    try:
        conn.network.router_remove_interface(os_router, subnet_id)
    except :
        print("WARNING: Subnet id {0} has no interface on {1}".format(subnet_id, os_router.name))

def remove_subnet_ports_from_router(conn, os_router, subnet_id):
    """ remove network ports (subnet interfaces) from router """
    ports_to_remove = [ port for port in conn.network.ports()
        if ((port.device_owner == 'network:router_interface') &
            (port['fixed_ips'][0]['subnet_id'] == subnet_id)) ]

    if len(ports_to_remove) > 0:
        print("Removing router port {1} from router {0}".format(os_router.name, port.id))
        router_remove_subnet( conn, os_router, subnet_id )

def delete_network(conn, os_network, router_name='router1'):
    debug_print("Delete Network:")
    os_router = conn.network.find_router(router_name)
    # remove subnet interfaces from router and delete subnets
    for subnet_id in os_network.subnet_ids:
        router_remove_subnet(conn, os_router, subnet_id)
        conn.network.delete_subnet(subnet_id, ignore_missing=False)
    conn.network.delete_network(os_network, ignore_missing=False)

"""
Create resources
"""
def create_server_raw(conn, attrs, wait_for_server=True):
    """ method wraps the conn.compute.create_server() method """
    os_server = conn.compute.create_server(**attrs)
    if wait_for_server:
        os_server = conn.compute.wait_for_server(os_server)
    return os_server

def create_server(conn,
        server_name,
        image_id,
        flavor_id,
        network_id,
        secgrp_name='',
        hypervisor_name='',
        project_id=''):
    """ Creates a server instance with the supplied properties.
        WIP: If a hypervisor hostname is supplied, OpenStack is asked to
        place the server on that hypervisor."""
    attrs = {
            'name': server_name,
            'image_id': image_id,
            'flavor_id': flavor_id,
            'networks':[{"uuid": network_id}]
            }
    if secgrp_name != '':
        attrs['security_groups'] = [{'name': secgrp_name}]

    if hypervisor_name != '':
        print("Creating server on {0}".format(hypervisor_name))
        os_hypervisor = conn.compute.find_hypervisor(hypervisor_name)
        hostId = get_hypervisor_hostId(conn, project_id, hypervisor_name)
        print(hostId)
        print(os_hypervisor.id)
        if not(os_hypervisor.name == hypervisor_name):
            print("ERROR: found wrong hypervisor:")
            print("hypervisor_name = {0}".format(hypervisor_name))
            print("hypervisor found: {0}".format(os_hypervisor.name))
            print("hypervisor detail: {0}".format(os_hypervisor))
        """ the server params in the following dict cause a
            "Bad Request (400)" exception """
        bad_attrs = {'project_id': project_id,'hostId': os_hypervisor.id }
        # add "hostId" to attrs
        attrs['hostId'] = hostId
 
    os_server = create_server_raw(conn, attrs)
    return os_server


def create_server_old(conn, s3p_server_name, s3p_hypervisor, s3p_network):
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
        # print("Server IP address={ip}".format(ip=server.addresses))

def delete_server_id(conn, server_id):
    """  deletes a server based on its ID """
    if not(debug_mode):
        server = conn.compute.find_server(server_id)
        conn.compute.delete_server(server)

def delete_server(conn, server_name):
    """deletes a server from the cluster"""
    if not(debug_mode):
        server = conn.compute.find_server(server_name)
        conn.compute.delete_server(server)

def get_openstack_connection_raw(auth_args):
    """obtains an OpenStack connection from a supplied dictionary of auth args"""
    print("Connecting to Openstack at {0}".format(auth_args['auth_url']))
    conn = connection.Connection(**auth_args)
    return conn

def get_openstack_connection():
    service_host_ip = os.getenv('SERVICE_HOST')
    auth_args = {
        'auth_url': 'http://' + service_host_ip + ':5000/v2.0',
        'project_name': 'demo',
        'username': 'admin',
        'password': 'secret',
    }
    return get_openstack_connection_raw(auth_args)

def create_security_group(conn, secgrp_name, project_id_in):
    """ create a security group from a name """
    os_security_group = conn.network.create_security_group(
            name = secgrp_name,
            description = "S3P secgrp: Allow ICMP + SSH",
            project_id = project_id_in
            )
    return os_security_group

def add_security_group_rules_ssh(conn, sec_grp_id):
    ssh_ingress = conn.network.create_security_group_rule(
            security_group_id = sec_grp_id,
            protocol = 'tcp',
            direction = 'ingress',
            port_range_min = 22, port_range_max = 22,
            description = "Allow SSH ingress on port 22"
            )
    ssh_egress = conn.network.create_security_group_rule(
            security_group_id = sec_grp_id,
            protocol = 'tcp',
            direction = 'egress',
            port_range_min = 22, port_range_max = 22,
            description = "Allow SSH egress on port 22"
            )
    return ssh_ingress, ssh_egress

def add_security_group_rules_icmp(conn, sec_grp_id):
    icmp_ingress = conn.network.create_security_group_rule(
            security_group_id = sec_grp_id,
            protocol = 'icmp',
            direction = 'ingress',
            description = "Allow ICMP ingress"
            )
    icmp_egress = conn.network.create_security_group_rule(
            security_group_id = sec_grp_id,
            protocol = 'icmp',
            direction = 'egress',
            description = "Allow ICMP egress"
            )
    return icmp_ingress, icmp_egress

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

    print_server_list(conn)
    print_images_list(conn)
    print_flavor_list(conn)
    print_keypair_list(conn)
    print("Done")

    """ end main() """

if __name__ == '__main__':
    main()

# vim: set ai et sw=4 ts=4 :

