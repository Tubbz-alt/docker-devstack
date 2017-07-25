#!/usr/bin/env python
import s3p_openstack_tools as s3p

debug_mode=False
network_list=[]
subnet_list=[]
hypervisor_list=[]
server_list=[]

def isodate():
    """prints the date in a pseudo-ISO format (Y-M-D H:M:S"""
    pass

def debug_print(stringIn=''):
    """docstring for dbgPrint"""
    if debug_mode:
        print(stringIn)

def determine_net_index(comp_id, num_networks, host_id, numberingType='one_net'):
    """Function determines which network will be used"""
    if numberingType == 'modulo_num_networks':
        networkIdx = comp_id % num_networks
    elif numberingType == 'one_per_physhost':
        networkIdx = host_id
    else:
        networkIdx = 0
    return networkIdx

def create_instance(conn, instance_name, hypervisor_name, network_name):
    """
    Creates an S3P server (OpenStack tenant instance) on the specified
    hypervisor, attached to a specific network
    """
    pass

def smoke_test_server(conn):
    """Smoke Test == ping new OpenStack tenant instance until it responds"""
    """ a.k.a. wait_for_tenant """
    pass

def create_security_group(conn, secgrp_name):
    """creates s3p security group and rules for ICMP, SSH"""
    pass

def create_network_and_subnet(conn):
    """creates an openstack network and subnet"""
    pass

def set_quotas(conn):
    """sets OpenStack quotas for scale testing"""
    pass

def cleanup(conn):
    """removes all allocated OpenStack resources incl. servers, networks, subnets"""
    pass


# DONE:
def unit_tests(conn):
    """ tests functions defined here or in s3p_openstack_tools """
    """
    The following functions are working:
    """
    # List compute resources
    # s3p.list_servers(conn)
    # list_servers(conn)
    # list_images(conn)
    # s3p.list_flavors(conn)
    # list_keypairs(conn)
    s3p.list_images(conn)
    s3p.list_servers(conn)
    node_id="21-11"
    compute_host="compute-"+node_id
    server_name="tenant-"+node_id+"-1"
    print("{0}, {1}".format(compute_host, server_name))
    s3p.create_server(conn, server_name, compute_host)

    # List network resources
    s3p.list_networks(conn)
    print("")
    s3p.list_subnets(conn)
    print("")
    s3p.list_security_groups(conn)
    print("")
    s3p.list_network_agents(conn)
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
    """sets resource identifiers (OpenStack resource IDs) for default resources"""
    # get security group id
    defaults = {'secgrp_id': None, 'image_id': None, 'flavor_id': None}
    os_secgrp = conn.network.find_security_group(names['secgrp_name'])
    defaults['secgrp_id'] = os_secgrp.id
    # get image id
    os_image = conn.compute.find_image(names['image_name'])
    defaults['image_id'] = os_image.id
    # get flavor id
    os_flavor = conn.compute.find_flavor(names['flavor_name'])
    defaults['flavor_id'] = os_flavor.id

    if debug_mode:
        print("{0}: {1}".format(names['secgrp_name'], defaults['secgrp_id']))
        print("{0}: {1}".format(names['image_name'], defaults['image_id']))
        print("{0}: {1}".format(names['flavor_name'], defaults['flavor_id']))
    return defaults

def main():
    global network_list
    global subnet_list
    global hypervisor_list
    global server_list

    print("Obtaining credentials")
    conn = s3p.get_openstack_connection()    	

    s3p_defaults = {'secgrp_name': 's3p_secgrp',
            'image_name': 'cirros-0.3.4-x86_64-uec',
            'flavor_name': 'cirros256'
            }

    s3p_resource_ids = get_resource_ids(conn, s3p_defaults)

    if False:
        # cleanup resources
        cleanup(conn)
    else:
        """ Assumptions: 
            quotas and s3p_secgrp are alreay created 
        set_quotas(conn)
        create_security_group(conn, s3p_defaults.secgrp_name)
        """
        # network_list = s3p.list_networks(conn)
        instance_name = 'foo123'
        hypervisor_name = 'compute-5-11'
        network_name = 's3p_net_5'
        create_instance(conn, instance_name, hypervisor_name, network_name)

        # subnet_list = s3p.list_subnets(conn)
        # hypervisor_list = s3p.list_hypervisors(conn)
        # server_list = s3p.list_servers(conn)

    print("Done")


if __name__ == '__main__':
    main()

