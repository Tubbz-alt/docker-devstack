#!/usr/bin/env python
import s3p_openstack_tools as s3p
from datetime import datetime
import argparse
import sys
import os
import pdb
from time import sleep

debug_mode=False
verbosity_level=0
# cloud test control: check main() for definition of cloud_info using these
validate_existing = True
attach_to_router=True
pin_instances = True

network_list=[]
subnet_list=[]
hypervisor_list=[]
hypervisor_set=set()
server_set = set()

def isodate():
    """prints the date in a pseudo-ISO format (Y-M-D H:M:S)"""
    d = datetime.now()
    return d.isoformat()

def debug_print(stringIn='', dbg_level=0):
    """docstring for dbgPrint"""
    global verbosity_level
    if debug_mode & (dbg_level <= verbosity_level):
        print("[{2}] DEBUG({1}): {0}".format( stringIn, dbg_level, isodate()))

def logprint(message):
    """prints a message in 'log format' like '[date] message' """
    print("[{0}] {1}".format(isodate(), message))

def get_auth_args_openstackrc():
    """ This function should source an openstackrc file for auth_args """
    pass

def get_auth_args():
    service_host_ip = os.getenv('SERVICE_HOST')
    auth_args = {
        'auth_url': 'http://' + service_host_ip + ':5000/v2.0',
        'project_name': 'demo',
        'username': 'admin',
        'password': 'secret',
    }
    return auth_args

def create_instance(conn, instance_name, hypervisor_name, network_id,
        resource_ids, smoketest=True):
    """
    Creates an S3P server (OpenStack tenant instance) on the specified
    hypervisor, attached to a specific network
    """
    global validate_existing
    debug_print("validate_existing = {0}".format(validate_existing), 2)
    global server_set
    global cloud_info
    """ check if instance is already created """
    if not(instance_name in server_set):
        # create instance
        network_name = s3p.get_network_name(conn, network_id)
        logmsg = "Creating server {0} on network {1}".format(
                instance_name, network_name)
        if not(cloud_info['pin_instances']):
            # unset the hypervisor hostname if don't need to pin instances to hosts
            hypervisor_name=''
        else:
            logmsg = logmsg + ", on host {0} with CLI library".format(hypervisor_name)
        logprint(logmsg)
        t1=datetime.now()
        os_instance = s3p.create_server(conn,
                instance_name,
                resource_ids['image_id'],
                resource_ids['flavor_id'],
                network_id,
                cloud_info['secgrp_name'],
                hypervisor_name,
                resource_ids['project_id']
                )
        t2=datetime.now()
        debug_print( "os_instance = {0}".format(os_instance) , 3)
        debug_print( "type(os_instance) = {0}".format(type(os_instance)) , 3)

        if type(os_instance) == type(None):
            logprint("ERROR: Server creation failed for:\nserver name: {0}".format(
                instance_name))
            sys.exit(1)
        else:
            logprint("Server Creation took {0} seconds".format((t2-t1).total_seconds()))
            server_set.add(os_instance.name)
    else:
        os_instance = s3p.get_server_detail(conn, instance_name)
        debug_print("Type of os_instance = {0}".format(type(os_instance)), 3)
        debug_print("os_instance = {0}".format(os_instance), 3)
        debug_print("WARNING: an OpenStack instance with name '{0}' ({1})".format(os_instance.name, instance_name) +
            "already exists, skipping creation", 1)
        smoketest = validate_existing

    if smoketest:
        os_network = conn.network.find_network(network_id)
        debug_print("os_instance = {0}".format(os_instance), 3)
        os_instance = s3p.get_server_detail(conn, instance_name)
        smoke_test_server(conn, os_instance, os_network)

def smoke_test_server(conn, os_instance, os_network):
    """
    Smoke Test == ping new OpenStack tenant instance until it responds
    a.k.a. wait_for_tenant
    This smoke test enters the DHCP network namespace (netns) on the service
    host that corresponds to the server's network
    """
    debug_print("os_instance = {0}".format(os_instance), 3)
    logprint("Waiting for instance {0} to respond to ping on network {1}...".format(
        os_instance.name, os_network.name))
    debug_print("os_instance = {0}".format(os_instance), 3)
    ip_addr = os_instance.addresses[os_network.name][0]['addr']
    """ timing: get instance IP address and network_id """
    NETNS = 'qdhcp-' + os_network.id
    logprint("Server '{0}' obtained IPV4 address: {1}".format(os_instance.name, ip_addr))
    """ enter netns and ping instance IP """
    command  = "sudo ip netns exec qdhcp-" + os_network.id + " ping -c 1 " + ip_addr
    debug_print("Smoke test: {0}".format(command), 2)
    """ TODO: This smoke test is very coarse - could be much better"""
    t1 =datetime.now()
    response = os.system(command)
    while response != 0:
        """ timing: enter netns & ping server until it responds """
        response = os.system(command)
        sleep(0.1)
    t2=datetime.now()
    """ print/accumulate timing info for server boot & smoke test """
    logprint("SmokeTest: {0} seconds for tenant '{1}' to respond to ping".format(
        (t2-t1).total_seconds(), os_instance.name))

def delete_instance(conn, instance_name):
    """ Deletes an S3P server (OpenStack tenant instance) """
    logprint("Deleting instance \"{0}\"".format(instance_name))
    s3p.delete_server(conn, instance_name)

"""  network management functions """
def determine_net_index(comp_id, num_networks, host_id, numberingType='one_net'):
    """Function determines which network will be used
        modulo_num_networks == modulous of number of networks (evenly distributed)
        one_per_physhost == one network per physical host,
                            all instances on that host are only on that network
                            i.e. comp-11-13 and comp-11-12 share a network
                            a.k.a. "Vertical networks"
        one_per_wave == one network common to each "wave" of compute hosts
                        i.e. comp-11-13 & comp-39-13 share a network
                        a.k.a. "Horizontal networks"
        """
    if numberingType == 'modulo_num_networks':
        networkIdx = int(comp_id) % num_networks
    elif numberingType == 'one_per_wave':
        networkIdx = int(comp_id)
    elif numberingType == 'one_per_physhost':
        networkIdx = int(host_id)
    else:
        """ one network to rule them all """
        networkIdx = 0
    return networkIdx

def create_security_group_and_rules(conn, secgrp_name, project_id):
    """creates s3p security group and adds rules for SSH and ICMP """
    os_security_group = conn.network.find_security_group(secgrp_name)
    if os_security_group == None:
        logprint("Creating security group {0}".format(secgrp_name))
        os_security_group = s3p.create_security_group(conn, secgrp_name, project_id)
        s3p.add_security_group_rules_ssh(conn, os_security_group.id)
        s3p.add_security_group_rules_icmp(conn, os_security_group.id)
    else:
        logprint("Using existing security group '{0}'".format(secgrp_name))
    return os_security_group

def create_network_and_subnet(conn, network_name, network_ix):
    """creates an openstack network and subnet"""
    global network_set
    global attach_to_router
    router_name = 'router1'
    network_set = s3p.get_network_set(conn)
    if network_name in network_set:
        debug_print("Using existing OpenStack network with name '{0}'".format(
            network_name), 1)
        os_network = conn.network.find_network(network_name)
    else:
        logprint("Creating OpenStack network with name: {0}".format(network_name))
        t1 = datetime.now()
        os_network = s3p.create_network_raw(conn, network_name)
        t2 = datetime.now()
        network_set.add(os_network.name)
        network_list.append(os_network.name)
        if os_network != None:
            logprint("Network Creation: {0} seconds".format((t2-t1).total_seconds()))
            subnet_name = network_name+'-sub'
            parent_network_id = os_network.id
            cidr = '10.0.'+str(network_ix)+'.0/24'
            gateway_ip = '10.0.'+str(network_ix)+'.1'
            logprint("Creating OpenStack subnet with name: {0}".format(network_name+"-sub"))
            t1 = datetime.now()
            os_subnet = s3p.create_subnet_raw(
                    conn,
                    subnet_name,
                    parent_network_id,
                    cidr,
                    gateway_ip)
            if attach_to_router:
                os_router = s3p.get_os_router(conn, router_name)
                s3p.router_add_subnet(conn, os_router, os_subnet.id)
            t2 = datetime.now()
            logprint("Subnet Creation: {0} seconds".format((t2-t1).total_seconds()))
        else:
            logprint("ERROR: Failed to create openstack network '{0}'".format(
                network_name))
            sys.exit(1)
    return os_network.id

def delete_network_and_subnet(conn, os_network):
    """
    Deletes a network and its associated subnets
    Each network should have a list of subnets associated with it through
    OpenStack or through a global variable herein
    """
    name = os_network.name
    logprint("Deleting network \"{0}\"".format(name))
    s3p.delete_network(conn, os_network)
    logprint("Network \"{0}\" Successfully deleted".format(name))

# cleanup
def cleanup(conn, cloud_info):
    """removes all allocated OpenStack resources incl. servers, networks, subnets"""
    global server_set
    global network_list
    global network_set
    logprint("Removing instances and networks from OpenStack Cloud...")
    # delete servers
    server_prefix = cloud_info['server_prefix']
    for server in conn.compute.servers():
        if server_prefix in server.name:
            delete_instance(conn, server.id)

    server_set = s3p.get_server_set(conn)

    # delete networks
    net_prefix = cloud_info['network_prefix']
    for network in conn.network.networks():
        if net_prefix in network.name:
            name = network.name
            delete_network_and_subnet(conn, network)
    network_list  = s3p.list_networks_by_name(conn)
    network_set = s3p.get_network_set(conn, cloud_info['network_prefix'])

# COMPLETED:
def unit_tests(conn):
    """ tests functions defined here or in s3p_openstack_tools """
    """
    The following functions are working:
    """
    s3p.print_images_list(conn)
    s3p.print_server_list(conn)
    node_id="21-11"
    compute_host="compute-"+node_id
    server_name="tenant-"+node_id+"-1"
    logprint("{0}, {1}".format(compute_host, server_name))
    s3p.create_server(conn, server_name, compute_host)

    # List network resources
    s3p.print_network_list(conn)
    print("")
    s3p.print_subnet_list(conn)
    print("")
    s3p.print_security_group_list(conn)
    print("")
    s3p.print_network_agent_list(conn)
    print("")
    s3p.list_net_availability_zones(conn)
    print("")
    s3p.list_comp_availability_zones(conn)
    print("")

    # create a network:
    s3p.create_network(conn, network_name)

    # delete a network & it's subnets:
    s3p.delete_network(conn, network_name)

def get_resource_ids(conn, names):
    """gets resource identifiers (OpenStack resource IDs) for default resources"""
    defaults = {}
    # get project id
    os_project = conn.identity.find_project(names['project_name'])
    defaults['project_id'] = os_project.id
    # get security group id
    os_secgrp = conn.network.find_security_group(names['secgrp_name'])
    defaults['secgrp_id'] = os_secgrp.id
    # get image id
    os_image = conn.compute.find_image(names['image_name'])
    defaults['image_id'] = os_image.id
    # get flavor id
    os_flavor = conn.compute.find_flavor(names['flavor_name'])
    defaults['flavor_id'] = os_flavor.id
    debug_print("S3P Resource IDs:", 2)
    debug_print("{0}: {1}".format(names['project_name'], defaults['project_id']), 2)
    debug_print("{0}: {1}".format(names['secgrp_name'], defaults['secgrp_id']), 2)
    debug_print("{0}: {1}".format(names['image_name'], defaults['image_id']), 2)
    debug_print("{0}: {1}".format(names['flavor_name'], defaults['flavor_id']), 2)
    return defaults

def parse_ids_from_hypervisor_name(hypervisor_name):
    """
    Returns component identifiers from a provided hyperfisor name
    example: for hypervisor 'compute-5-11', this function will return two
    strings: host_id=5 and comp_id=11
    """
    host_id = hypervisor_name.split('-')[1]
    comp_id = hypervisor_name.split('-')[2]
    return host_id, comp_id


"""
" main testing loop
"""
def main():
    global network_list
    global network_set
    global subnet_list
    global hypervisor_list
    global hypervisor_set
    global server_set

    global debug_mode
    global cloud_info
    global verbosity_level
    global attach_to_router
    verbosity_level=0

    """
    parse input args with argparse
    input args:
    --cleanup - deletes all s3p-created instances and networks
    --debug - enables debug_mode
    NOTE on verbosity level:
        0: prints only stats messages
        1: prints WARNING: messages
        2: prints control messages
        3: prints details of resource creation
        4: prints ???
    TODO:
    operation - arguments to describe how many networks, servers, etc are created
      operation['num_networks']
      operation['num_servers']
      operation['servers_per_host']
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("-c", "--cleanup",
        help="cleanup cluster by deleting all instances and networks",
        action="store_true")
    parser.add_argument("-d", "--debug",
        help="enable debug mode which increases output",
        action="store_true")
    parser.add_argument("-v", "--verbosity", type=int, choices=[0,1,2,3,4],
        help="verbosity level for prints in debug mode (must enable debug mode)")

    args = parser.parse_args()

    debug_mode = True
    debug_mode = args.debug
    debug_print("args.debug = {0}".format(debug_mode))
    verbosity_level = args.verbosity
    debug_print("args.verbosity = {0}".format(verbosity_level), 1)
    cleanup_mode = args.cleanup
    debug_print("args.cleanup = {0}".format(cleanup_mode), 1)


    logprint("Obtaining OpenStack credentials")
    conn = s3p.get_openstack_connection()

    cloud_info = {
            'project_name': 'demo',
            'secgrp_name': 's3p_secgrp',
            'image_name': 'cirros-0.3.4-x86_64-uec',
            'flavor_name': 'cirros256',
            'network_prefix': 's3p-net-',
            'server_prefix': 'tenant-',
            'attach_to_router': True,
            'pin_instances': True,
            'validate_existing': True
            }
    attach_to_router = cloud_info['attach_to_router']
    validate_existing = cloud_info['validate_existing']
    pin_instances = cloud_info['pin_instances']

    os_project = conn.identity.find_project(cloud_info['project_name'])
    # create security group if it doesn't yet exist
    os_secgrp = create_security_group_and_rules(conn,
            cloud_info['secgrp_name'], os_project.id)

    s3p_resource_ids = get_resource_ids(conn, cloud_info)


    if cleanup_mode:
        # cleanup resources
        # TODO: ask user if they REALLY want to delete all the servers and networks in the cluster
        # server_set = s3p.get_server_set(conn)
        # network_set = s3p.get_network_set(conn)
        print("WARNING:: You are about to remove\n" +
                "\tall server instances matching '{0}' \n".format(cloud_info['server_prefix']) +
                "\tall networks matching '{0}'\n".format(cloud_info['network_prefix']))
        answer = raw_input('Are you sure you want to proceed? ')
        if (answer == 'y') | (answer == 'Y' ):
            cleanup(conn, cloud_info)
        else:
            logprint("Cleanup operation aborted - no changes to cloud.")
    else:
        """ Assumptions:
            quotas and s3p_secgrp are alreay created
        """
        # get list of networks by name
        network_list = s3p.list_networks_by_name(conn)
        debug_print("Network list: {0}".format(network_list), 2)
        network_set = s3p.get_network_set(conn, cloud_info['network_prefix'])
        debug_print("Network set: {0}".format(network_set), 2)

        # get list of hypervisors by name
        hypervisor_list = s3p.list_hypervisors_by_name(conn)
        hypervisor_set = s3p.get_hypervisor_set(conn, prefix='compute-')
        debug_print("Hypervisor List: {0}".format(hypervisor_list), 2)
        debug_print("Hypervisor Set:  {0}".format(hypervisor_set ), 2)

        # get list of servers by name
        server_set = s3p.get_server_set(conn)

        debug_print("Server Set: {0}".format(server_set), 2)

        servers_per_host = 1
        max_networks = 6

        net_numbering_type = 'modulo_num_networks'

        # loop through hypervisors, creating tenants on each
        for hypervisor_name in hypervisor_list:
            phys_host_id, comp_id = parse_ids_from_hypervisor_name(hypervisor_name)

            network_ix = determine_net_index(
                comp_id,
                max_networks,
                phys_host_id,
                net_numbering_type)

            network_name = 's3p-net-' + str(network_ix)

            network_id = create_network_and_subnet(conn,
                network_name,
                network_ix)

            hypervisor_ID = phys_host_id + "-" + comp_id
            # only create one tenant per host for now
            instance_name = 'tenant-' + hypervisor_ID + "-1"
            t1 = datetime.now()
            create_instance(conn,
                instance_name,
                hypervisor_name,
                network_id,
                s3p_resource_ids,
		        smoketest=True)

            t2 = datetime.now()
            debug_print("Server and network creation took {0} s".format((t2-t1).total_seconds()), 1)

        # subnet_list = s3p.print_subnet_list(conn)
        # hypervisor_list = s3p.print_hypervisor_list(conn)

    logprint("Done")


if __name__ == '__main__':
    main()

# vim: set et sw=4 ts=4 ai :

