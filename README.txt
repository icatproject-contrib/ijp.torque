ijp.r92: Job Connector for IJP
------------------------------

General installation instructions are at http://code.google.com/p/icatproject/wiki/Installation

Specific installation instructions are at http://www.icatproject.org/mvn/site/ijp/r92/${project.version}/installation.html

All documentation on ids.server may be found at http://www.icatproject.org/mvn/site/ijp/server/${project.version}



First install like any other ICAT component then do the puppet bit ...


Setting up the ijp.r92 job connector with Puppet
================================================

All machines should have Ubuntu 12.04 or 14.04 installed and you must have ssh root access 
either directly or using sudo from another account. Choose one machine as the server - this should 
have enough disk space to run the ICAT Data Server and also acts as the "Puppet Master". All other machines 
(referred to as worker nodes) require little disk space.

Puppet is used to do most of the work. This runs every half an hour and tries to bring each machine 
into the correct state. You can initiate a run by "puppet agent -t" on the machine which you 
want updating. This also applies to the server machine which contacts itself to do updates - that is 
it acts both as a puppet client and the "puppet master". There will be log files in the /var/log/puppet 
directory. The file master.log will be found only on the master and this contains an entry each time 
it is contacted by a client. Typically it only reports errors if the puppet configuration is wrong. 
Each machine has an agent.log which lists what changes have been made to the machine. If you have
problems run "puppet agent -t" to get diagnostic information on the screen - there is an interlock 
so that it will not run while it is in one of its half hourly runs.

Networking
----------

Make sure that these networking instructions are followed carefully otherwise strange errors will occur which 
are difficult to recover from.

You should ensure that on all machines the command "hostname -f" works and gives the fqdn. If not try making 
/etc/resolv.conf a file rather than a link with:

domain esc.rl.ac.uk
search esc.rl.ac.uk rl.ac.uk
nameserver 130.246.8.13
nameserver 130.246.72.21

Also make sure that the proxy files are set up in the /etc/environment file (both http_proxy and https_proxy)

To access the control panel use gnome-control-center

On master
---------

Unpack the distro and cd to it

apt-get install unzip
ntpdate time.rl.ac.uk
puppet/scripts/setup-master.sh

If you make a mistake entering passwords you can run the setup-master.sh script again. Passwords will 
not be reset.

It should report at the end a few errors from the Torque::server (because it has no clients yet) for example:

   Wed Jan 30 08:55:43 +0000 2013 /Stage[main]/Torque::Server/Concat[/var/spool/torque/server_priv/nodes]/Exec[concat_/var/spool/torque/server_priv/nodes]/returns 
                                  (notice): The fragments directory is empty, cowardly refusing to make empty config files
   ...
   Wed Jan 30 08:55:43 +0000 2013 /Stage[main]/Torque::Server/Service[torque-server] (warning): Skipping because of failed dependencies
   Wed Jan 30 08:55:44 +0000 2013 Puppet (notice): Finished catalog run in 2.10 seconds

Now move on to the client machines.


On all other machines
---------------------

unpack the distro and cd to it

apt-get install unzip
ntpdate time.rl.ac.uk
puppet/scripts/setup-agent.sh <full server name>

Then go to server and: 

puppet cert list
puppet cert sign --all

the first command will list all the certificates that need signing and the second command will sign 
them. At the end the command puppet cert list should output nothing. 

then back on the other machine:

puppet agent -t


Notes
-----

If you reinstall the master no worker node will connect. For each worker you would need:

rm -rf /var/lib/puppet/ssl
service puppet restart