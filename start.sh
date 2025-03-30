# Client side
docker run -it --rm --ipc=host --cap-add=NET_ADMIN -v $(pwd)/guest-dir:/mnt/host vpn:client /bin/bash
docker run -it --rm --ipc=host --cap-add=NET_ADMIN -v $(pwd)/guest-dir:/mnt/host vpn:server /mnt/host/client.sh

# Server side
docker run -it --rm --ipc=host --cap-add=NET_ADMIN -v $(pwd)/guest-dir:/mnt/host vpn:server /bin/bash
docker run -it --rm --ipc=host --cap-add=NET_ADMIN -v $(pwd)/guest-dir:/mnt/host vpn:server /mnt/host/run_custom_server.sh



# get the ip address
