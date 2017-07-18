# docker-devstack

Dockerfile and supporting files for fully functional dockerized Openstack nodes for S3P Testing (scale, stability, performance, security) of OpenDaylight SDN controller used as network virtualization layer for OpenStack.
---
## Steps to set up an S3P cluster:
1. Identify physical hosts. More is better for scale testing, but a single physical system can run all of the containers simultaneously
  - service node (OpenStack infrastructure and control node)
  - compute nodes (OpenStack compute nodes)
2. Install Ubuntu 16.04 and docker on physical hosts
3. Create linux bridges on hosts named br_mgmt and br_data
  - deployment on a single physical server can leave the bridges with no physical interfaces
    - multiple containers on one host may share the bridge
  - for deployment on multiple physical servers, bond these bridges to network interfaces for management and tenant data, respectively
4. Build the systemd container:
  - `cd docker-devstack/systemd`
  - `./build_systemd.sh`
5. Build the service node container:
  - `cd docker-devstack/service`
  - edit `build_service.sh` to reflect your docker image registry
  - `./build_service.sh [tag name]`
6. Run the service node
  - `./run_service.sh`
  - the script `docker-devstack/docker/connect_container_to_networks.sh` will create veth links from the container's net-namespace to the bridges created earlier.  It will rename the container network interfaces, assign MAC & IP addresses to them.
  - Once the service node is running, a shell should be open at the prompt `stack@service-node: $`
7. Start stacking on the service node
  - edit `/home/stack/service.odl.local.conf` as needed
  - run `./start.sh`
    - devstack will download Linux packages and pip will install necessary components, OpenStack services will be set up and after about 10-20 minutes, the OpenStack control node should be running all required OpenStack services.
8. While the service node is stacking, build the compute node:
  - `cd docker-devstack/compute`
  - `./build_compute.sh`
9. Run the compute node(s)
  - `./run_compute.sh` to launch a compute node with default name
  - alternatively, create variables in your shell to reflect the correct values for:
    - `IMAGE_REGISTRY`
    - `IMAGE_REPO`
    - `IMAGE_TAG`
    - `HOST_ID` (an integer representing the physical host)
    - `COMP_ID` (an integer  > 11 representing the compute host)
      - the COMP_ID should be greater than 11 because it will also be encoded in the IP and MAC addresses
10. Once the service node has finished devstack, begin stacking in the compute hosts
  - `/home/stack/start.sh`
  - The first time a compute host has stacked, it should take more than 10 minutes
  - After a successful stacking, uncomment the `OFFLINE=True` and  `RECLONE=False` directives in compute.odl.local.conf
    - subsequent restarts (`/home/stack/restart.sh`) should only require about 20 seconds
11. Clean the containers after a successful stack
  - `docker-devstack/service/stop_and_clean_container.sh <Node name>`
    - <Node name> here is the name of the container e.g. service-node or compute-10-22
12. Commit a stacked and cleaned container for faster deployment
  - See https://docs.docker.com/engine/reference/commandline/commit/
  - `docker commit [OPTIONS] CONTAINER [REPOSITORY[:TAG]]`
13. Interact with the OpenStack Horizon GUI
  - through a docker port map at http://<physical_host_IP>:50080/dashboard
  - on the command line of any openstack node
