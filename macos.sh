#!/bin/bash

#**************************************************************************************************
# WebPageTest agent installation script for MacOS systems.

echo "Installing and configuring WebPageTest agent..."
echo

#**************************************************************************************************
# Configure Defaults
#**************************************************************************************************

set -eu
: ${WPT_SERVER:=''}
: ${WPT_LOCATION:=''}
: ${WPT_KEY:=''}
: ${AGENT_MODE:='desktop'}
: ${WPT_UPDATE_OS:='y'}
: ${WPT_UPDATE_OS_NOW:='y'}
: ${WPT_UPDATE_AGENT:='y'}

while [[ $WPT_SERVER == '' ]]
do
read -p "WebPageTest server (i.e. www.webpagetest.org): " WPT_SERVER
done
while [[ $WPT_LOCATION == '' ]]
do
read -p "Location ID (i.e. Dulles): " WPT_LOCATION
done
while [[ $WPT_KEY == '' ]]
do
read -p "Location Key (if required): " WPT_KEY
done

# Pre-prompt for the sudo authorization so it doesn't prompt later
sudo date

#**************************************************************************************************
# System Update
#**************************************************************************************************

if [ $WPT_UPDATE_OS_NOW == 'y' ]; then
softwareupdate --install --recommended
fi

#**************************************************************************************************
# Agent code
#**************************************************************************************************

cd ~
rm -rf wptagent
until git clone --depth 1 --branch=release https://github.com/WPO-Foundation/wptagent.git
do
    sleep 1
done

#**************************************************************************************************
# Software Install
#**************************************************************************************************

# Grant sudo permission without prompting
echo "${USER} ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/wptagent"

# Install homebrew
arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install the cli libraries
arch -x86_64 brew install libvpx ffmpeg imagemagick geckodriver ios-webkit-debug-proxy node git

# Install the python dependencies
pip3 install PyObjC ujson dnspython monotonic pillow psutil requests tornado wsaccel brotli fonttools selenium future usbmuxwrapper

# Install lighthouse
npm -g install lighthouse

#**************************************************************************************************
# Agent Script
#**************************************************************************************************

# build the agent script
KEY_OPTION=''
if [ $WPT_KEY != '' ]; then
  KEY_OPTION="--key $WPT_KEY"
fi
echo '#!/bin/zsh' > ~/agent.sh
echo 'cd $HOME' >> ~/agent.sh

# Wait for networking to become available and update the package list
echo 'sleep 10' >> ~/agent.sh

# OS Update
if [ $WPT_UPDATE_OS == 'y' ]; then
    echo 'echo "Updating OS"' >> ~/agent.sh
    echo 'sudo softwareupdate --install --recommended --restart' >> ~/agent.sh

# Lighthouse Update
if [ $WPT_UPDATE_AGENT == 'y' ]; then
    echo 'sudo npm i -g lighthouse' >> ~/agent.sh
fi

echo 'for i in `seq 1 24`' >> ~/agent.sh
echo 'do' >> ~/agent.sh

if [ $WPT_UPDATE_AGENT == 'y' ]; then
    echo '    git pull origin release' >> ~/agent.sh
fi

# Agent invocation (depending on config)
if [ $AGENT_MODE == 'android' ]; then
    echo "    python3 $HOME/wptagent/wptagent.py -vvvv --location $WPT_LOCATION $KEY_OPTION --server \"http://$WPT_SERVER/work/\" --android --exit 60 --alive /tmp/wptagent" >> ~/agent.sh
fi
if [ $AGENT_MODE == 'ios' ]; then
    echo "    python3 $HOME/wptagent/wptagent.py -vvvv --location $WPT_LOCATION $KEY_OPTION --server \"http://$WPT_SERVER/work/\" --iOS --exit 60 --alive /tmp/wptagent" >> ~/agent.sh
fi
if [ $AGENT_MODE == 'desktop' ]; then
    echo "    python3 $HOME/wptagent/wptagent.py -vvvv --location $WPT_LOCATION $KEY_OPTION --server \"http://$WPT_SERVER/work/\" --exit 60 --alive /tmp/wptagent" >> ~/agent.sh
fi

echo '    echo "Exited, restarting"' >> ~/agent.sh
echo '    sleep 10' >> ~/agent.sh
echo 'done' >> ~/agent.sh
echo 'sudo reboot' >> ~/agent.sh
chmod +x ~/agent.sh

#**************************************************************************************************
# Startup Script
#**************************************************************************************************
echo '<?xml version="1.0" encoding="UTF-8"?>' > ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '<plist version="1.0">' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '<dict>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '    <key>Label</key>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '    <string>org.webpagetest.wptagent</string>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '    <key>ProgramArguments</key>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '    <array>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo "        <string>$HOME/agent.sh</string>" >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '    </array>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '    <key>RunAtLoad</key>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '    <true/>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '</dict>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '</plist>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist

#**************************************************************************************************
# Done
#**************************************************************************************************

echo "Done. Permissions will need to be added manually (see install docs)"
