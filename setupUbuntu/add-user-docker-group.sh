#!/bin/bash
echo "Adding ${USER} to docker group."
sudo usermod -aG docker ${USER}
su - {$USER}
