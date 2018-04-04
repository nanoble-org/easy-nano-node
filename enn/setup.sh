#!/bin/bash

# goto script dir
cd "$(dirname "$0")"

echo "== Cloning Nano Node Monitor"
git -C /opt/nanoNodeMonitor pull || git clone https://github.com/nanotools/nanoNodeMonitor.git /opt/nanoNodeMonitor

echo "== Updating Docker images"
sudo docker pull nanocurrency/nano
sudo docker pull php:7.2-apache

echo "== Starting Docker containers"
sudo docker-compose up -d

echo "== Take a deep breath..."
# we need this as the node is crashing if we go on too fast
sleep 5s

if [ -f /opt/nanoNodeMonitor/modules/config.php ]; then

  echo "== Nano node directory exists, skipping initialization..."

else

  if [[ -z "${GOOGLE_DRIVE_FILE_ID}" ]]; then
    echo "== Getting quick bootstrap ledger"
	  apt install p7zip-full
	  wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id='"$GOOGLE_DRIVE_FILE_ID"'' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=$GOOGLE_DRIVE_FILE_ID" -O snap.7z && rm -rf /tmp/cookies.txt
	  mv ~/RaiBlocks/data.ldb ~/RaiBlocks/data.ldb.bak
	  7z x snap.7z -o~/RaiBlocks/
	  sudo docker restart enn_nanonode_1
  fi
  
  echo "== Creating wallet"
  wallet=$(docker exec enn_nanonode_1 /usr/bin/rai_node --wallet_create)

  echo "== Creating account"
  account=$(docker exec enn_nanonode_1 /usr/bin/rai_node --account_create --wallet=$wallet | cut -d ' ' -f2)

  echo "== Creating monitor config"
  cp /opt/nanoNodeMonitor/modules/config.sample.php /opt/nanoNodeMonitor/modules/config.php

  echo "== Modifying the monitor config"

  # uncomment account
  sed -i -e 's#// $nanoNodeAccount#$nanoNodeAccount#g' /opt/nanoNodeMonitor/modules/config.php

  # replace account
  sed -i -e "s/xrb_1f56swb9qtpy3yoxiscq9799nerek153w43yjc9atoaeg3e91cc9zfr89ehj/$account/g" /opt/nanoNodeMonitor/modules/config.php

  # uncomment ip
  sed -i -e 's#// $nanoNodeRPCIP#$nanoNodeRPCIP#g' /opt/nanoNodeMonitor/modules/config.php

  # replace ip
  sed -i -e 's#\[::1\]#enn_nanonode_1#g' /opt/nanoNodeMonitor/modules/config.php

  echo "== Disabling RPC logging"
  sed -i -e 's#"log_rpc": "true"#"log_rpc": "false"#g' ~/RaiBlocks/config.json

  echo "== Opening Nano Node Port"
  sudo ufw allow 7075

  echo "== Restarting Nano node container"
  sudo docker restart enn_nanonode_1

  echo "== Just some final magic..."
  # restart because we changed the config.json
  # and the node might be unresponsive at first
  sleep 5s

  echo ""

  echo -e "=== \e[31mYOUR WALLET SEED\e[39m ==="
  echo "Please write down your wallet seed to a piece of paper and store it safely!"
  docker exec enn_nanonode_1 /usr/bin/rai_node --wallet_decrypt_unsafe --wallet=$wallet
  echo -e "=== \e[31mYOUR WALLET SEED\e[39m ==="

fi

serverip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -vE '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|127\.0\.0\.1)')

echo ""
echo "All done! *yay*"
echo "View your Nano Node Monitor at http://$serverip"
echo ""
