Weather Pi
=========

Raspberry Pi powered WS 300 PC II

###Work in progress
The webfrontend and installationscript isn't public by now but will follow asap.

Screenshots
========
Asap i will put some screenshots here in my blog http://nerd42.de/portal/weather-pi-raspberry-pi-powered-ws-300-pc-ii/

Installation
========

WeatherPi works on Raspbian.
Boot your Raspberry as normal and open console or connect via ssh.
######Type 
	tail -f /var/log/messages
and check if your device will be found.
######Type
	lsub
to get your vendor and product ids
######Output
	Bus 003 Device 004: ID c006:1b1f Future Technology Devices International, Ltd
In this case vendor is c006 and product is 1b1f
 
######Create & insert /etc/udev/rules.d/99-custom.rules
	SYSFS{idProduct}=="c006", SYSFS{idVendor}=="1b1f", RUN+="/sbin/modprobe -q ftdi_sio product=0xc006 vendor=0x1b1f"
	
#### Now install some tools
	sudo su
	apt-get install perl mysql-common mysql-server libdevice-serialport-perl libapache-dbi-perl libaprutil1-dbd-mysql libio-all-perl
#### Now get rid of the message: 
##### insserv: warning: script 'mathkernel' missing LSB tags and overrides
	apt-get remove wolfram-engine

#### Now it's time to get this project
Wget or transfer the project
Simplest way: 	
wget https://github.com/mommel/weatherpi/archive/master.zip 

Unzip the archive to your home folder. 

Move www to /var/www 

	mv www /var/www
 
Move ws500-0.1.2.tar.bz2 to /usr/local/src and unpack it 

	cd ~/weatherpi/ws500
	mv ws500-0.1.2.tar.bz2 /usr/local/src/.
	cd /usr/local/src/
	tar xfvj ws500-0.1.2.tar.bz2 ws500-0.1.2
	ln -s ws500-0.1.2 ws500
	mkdir /var/log/Ws500
	mkdir /etc/ws500
	rm ws500-0.1.2.tar.bz2
	cd ws500
	mv ws500.pl ws500.pl.org
	
	
Move ws500.pl from ws300 to /usr/local/src/ws500/

	cd ~/weatherpi/ws300
	mv ws500.pl /usr/local/src/ws500/
	chmod +x /usr/local/src/ws500/ws500.pl
	ln -s /usr/local/src/ws500/ws500.pl /usr/local/bin

Configure your Device

	vi /etc/ws500/ws500.conf
	cat WS500_Wetter.cgi_Konfiguration > WS500_Wetter.cgi
	vi WS500_Wetter.cgi

You have to fill in your Mysql Credentials and copy the conf to your /etc/wd500 folder.

	cp /usr/local/src/ws500/etc/ws500.conf /etc/ws500

So far so good now lets create an autorun
	
	vi /etc/rc3.d/weather
with following content
	
	#!/bin/bash
	perl /usr/local/bin/ws500.pl > /dev/null &
Now make it runable

	chmod +x /etc/rc3.d/wetter
	
Now use a browser and connect to the Raspberry's IP. Run the installation script which installs the needed Tables to your mysql DB. 

When your done with the setup you get asked to reboot, so do so.

Now you can reconnect to your Raspberry PI and you are done.

Have fun 

Copyright and license
========
Creative Commons
Attribution-NonCommercial-ShareAlike 3.0 Unported 
(CC BY-NC-SA 3.0)
http://creativecommons.org/licenses/by-nc-sa/3.0/

##### Uses Thirdparty 
######WS 500 Program Package
	Copyright by Django, under same license 
http://dokuwiki.nausch.org/doku.php/wetter:ws500:start

######Carsten Wolf's modified ws500.pl 
	Copyright by Carsten Wolf, under same license
http://wiki.carsten-wolf.de

######JQuery
	MIT License
http://jquery.com
