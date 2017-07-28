#!/usr/bin/env python
import s3p_openstack_tools as s3p

debug_mode=False
def main():
    print("Obtaining credentials")
    conn = s3p.get_openstack_connection()    	
    network_name="super-cool-net"

    if not(debug_mode):
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


    print("Done")

if __name__ == '__main__':
    main()

