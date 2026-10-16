# Static Ip Configuratino in Truenas requires configuration activation

Observation:
-Editing the ens18 interface to disable DHCP and configure a static IP correclt updated the TrueNas configuration database (midclt intreface.query)
-The running linux stack continued using the previous DHCP lease until the VM was rebooted
-After reboot, the interface correctly adopted the configured statis address

Lesson:
Verify both the stored configuration and the active network configuration. If they differ, determine why before making manual changes to the running systme.
