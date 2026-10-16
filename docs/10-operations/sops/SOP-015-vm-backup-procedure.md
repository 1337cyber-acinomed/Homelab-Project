Step 1 – Create the mount point (if needed)
mkdir -p /mnt/storage01
Step 2 – Mount the Storage01 SMB share
mount -t cifs \
  //192.168.10.4/Backups \
  /mnt/storage01 \
  -o username=lab-admin

Enter your SMB password when prompted.

Note: We are intentionally using the IP address (192.168.10.4) instead of the hostname. Earlier we found that the Proxmox host could not resolve storage.polaris.home.arpa because it is not yet using the internal DNS that will come later in the roadmap.

Step 3 – Verify the mount
df -h | grep storage01

or

mount | grep storage01

You should see:

//192.168.10.4/Backups on /mnt/storage01
Step 4 – Verify you can see the backup structure
ls -lah /mnt/storage01/Backups/Infrastructure/Proxmox/

You should see directories similar to:

Host
VM-Backups
Network
Step 5 – Run the Docker01 backup
vzdump 103 \
  --mode snapshot \
  --compress zstd \
  --dumpdir /mnt/storage01/Backups/Infrastructure/Proxmox/VM-Backups/Docker01
Step 6 – Verify the backup
ls -lh /mnt/storage01/Backups/Infrastructure/Proxmox/VM-Backups/Docker01

Expected:

vzdump-qemu-103-<date>.vma.zst
vzdump-qemu-103-<date>.log
Step 7 – Validate Docker01

Once the backup finishes, verify:

Docker01 VM is still running.
Vaultwarden is accessible.
Forgejo is accessible.
Nginx Proxy Manager is accessible.
Homepage loads.
Uptime Kuma is healthy.
Portainer is reachable.
