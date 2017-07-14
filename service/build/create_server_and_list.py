#!/usr/bin/env python

from openstack import connection
import errno
import os

FLAVOR_NAME='cirros256'
SEC_GRP_NAME='s3p_secgrp'
IMAGE_NAME='cirros-0.3.4-x86_64-uec'
NETWORK_NAME='private'
debug_mode=False 
COMPUTE='compute-8-12'
project_id='85b9377a24064cc9a7e13e1a519e0b01'
SERVER_NAME='test'
SECURITY_GROUP='default'

"""
List resources from the Compute service.

For a full guide see TODO(etoews):link to docs on developer.openstack.org
"""
def list_servers(conn):
    print("List Servers:")
    for server in conn.compute.servers():
        print(server)

def list_security_groups(conn):
    print("List security groups:")
    for sec_grp in conn.network.security_group():
        print(sec_grp)

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

def list_networks(conn):
    print("List networks: ")
    for network in conn.compute.servers():
        print(network)

def list_availability_zones(conn):
    print("List availability zones:")
    print(conn.compute).availability_zones

def create_server(conn,compute_host):
    print("Create Server:")
    image = conn.compute.find_image(IMAGE_NAME)
    print("Image ID for Image {0} = {1}".format(IMAGE_NAME,image.id))
    flavor = conn.compute.find_flavor(FLAVOR_NAME)
    print("Flavor ID for flavor {0} = {1}".format(FLAVOR_NAME,flavor.id))
    network = conn.network.find_network(NETWORK_NAME)
    print("Network ID for network {0} = {1}".format(NETWORK_NAME,network.id))
    compute_host= conn.compute.find_hypervisor(COMPUTE)
    server = conn.compute.create_server(
        name=SERVER_NAME, image_id=image.id, flavor_id=flavor.id,
        hypervisor=COMPUTE,
        security_group=SECURITY_GROUP,
        networks=[{"uuid": network.id}]) 
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
    print("Obtaining credentials")
    conn = get_openstack_connection()
    print("Listing Images: ")
    list_images(conn)
    print("Listing servers")
    list_servers(conn)
    print("Creating server...")
    create_server(conn,COMPUTE)
    print("Listing servers")
    list_servers(conn)
    print("Listing hypervisors...")
    list_hypervisors(conn)
    print("avaiablity zones")
    list_availability_zones(conn)
    print("Listing networks..")
    list_networks(conn)
    print("Listing projects..")
    list_project_id(conn)
    print("Listing Flavors..")
    list_flavors(conn)
    print("Listing keypairs..")
    list_keypairs(conn)
    print("Done")
    print("auth: {0}\n".format( conn.auth_url))
    print("project_name: {0}\n".format( conn.project_name))
    print("username: {0}\n".format( conn.username))
    print("password: {0}\n".format( conn.password))

if __name__ == '__main__':
    main()

# vim: set ai et sw=4 ts=4 :

