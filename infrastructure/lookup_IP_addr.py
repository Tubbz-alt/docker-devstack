#!/usr/bin/env python

import sys

def main():
    if len(sys.argv) > 1:
        hostname=sys.argv[1]
        rackID, rackPos = getIDFromHostname(hostname)

        if len(sys.argv) > 2:
            # integer to select from the list above
            adapterNum=int(sys.argv[2])
            print(getIPAddr(rackID, adapterNum, rackPos))
            if len(sys.argv) > 3:
                # [1]/0 to select netmask on ouput
                if sys.argv[3] == "0":
                    ## TODO: change netmask?  global?
                    pass
        else:
            #assume user wanted ALL addresses:
            print("Hostname = {0}\nRackID = {1}\nrackPos = {2}".format(hostname, rackID, rackPos))
            print("0) 1Gbe  0: 10.166.32.0/23 (DHCP)")
            print("1) 1Gbe  1: {0}".format(getIPAddr(rackID,1,rackPos)))
            print("2) 10Gbe 0: {0}".format(getIPAddr(rackID,2,rackPos)))
            print("3) 10Gbe 1: {0}".format(getIPAddr(rackID,3,rackPos)))
    else:
        print("Error: a valid hostname of the form ax11-YY must be supplied.")
        rackID,rackPos = getIDFromHostname(getHostname)

        exit

def getIDFromHostname(hostname):
    """returns dict of rackID and rackPos from hostname"""
    rackID=hostname[0:4].lower()
    rackPos=hostname[5:7]
    return rackID, rackPos

def getHostname():
    """get the hostname"""
    from platform import node as nodeName
    hostname=nodeName()
    return hostname

def getIPAddr(rackID, adapterNum, rackPos):
    netmask=22
    return getSubnet(rackID, adapterNum)+"."+str(rackPos)+"/"+str(netmask)

def getSubnet(rackID, adapterNum):
    """looks up a subnet based on a map of rack to subnet"""
    # 0) I Gbe  #0: Intel LAN (mgmt) : 10.166.x.y
    # 1) 1 Gbe  #1: Lab LAN (data)   : 10.11.20.ID/22
    # 2) I0 Gbe #0: 10G mgmt LAN     : 10.11.24.ID/22
    # 3) 10 Gbe #1: 10G data LAN     : 10.11.124.ID/22
    subnetDict=dict({'ap11':[0,21,24,124], 'ao11':[0,22,25,125], 'an11':[0,23,26,126] })
    baseSubnet="10.11."
    return baseSubnet+str(subnetDict[rackID][adapterNum])


if __name__ == '__main__':
    main()

# vim: set et sw=4 ts=4 :

