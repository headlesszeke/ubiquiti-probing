# Ubiquiti Device Probing
This is my attempt at making a Ubiquiti device discovery tool. If you send "\x01\x00\x00\x00" to udp port 10001 on either broadcast or unicast, Ubiquiti devices respond with very descriptive information about themselves. So far, I have only tested against an AirCam, so...probably doesn't work very well...
### Example output:
```
$ ./scan.rb
sending discover request
waiting 5 seconds for responses...

----192.168.1.100----
MAC:	dc:9f:db:81:9b:57
IP:	192.168.1.100
PROD:	AirCam
NAME:	AirCam
VER:	AirCam.GM8126.v3.1.4.39.7e42364.160301.0153
---------------------
done
```